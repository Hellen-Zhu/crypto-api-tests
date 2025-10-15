# api.py (Previously api/main.py)

import subprocess
import uuid
import os
import datetime
from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

# Import database handler and ORM models
import sys
# When this file is in project root, project root is the current file directory
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

from src.database import handler as db_handler
from src.database.models import AutoProgress
from dotenv import load_dotenv

# --- TaaS Service Environment Loading Logic ---
# TaaS service only loads the unique .env file from project root directory.
# This file defines how to connect to the central test framework database.
try:
    dotenv_path = os.path.join(project_root, '.env')
    if os.path.exists(dotenv_path):
        print(f"--- TaaS: Loading environment variables from: {dotenv_path} ---")
        load_dotenv(dotenv_path=dotenv_path)
    else:
        # If .env file not found, service cannot connect to database, throw exception
        raise FileNotFoundError(f"TaaS service startup failed: .env configuration file not found in root directory.")

    Session = db_handler.initialize_session()
    print("--- TaaS: Database session initialized successfully. ---")
except Exception as e:
    print(f"--- TaaS FATAL ERROR: Could not initialize database session: {e} ---")
    # In production environment, application process should exit here
    exit(1)


app = FastAPI(
    title="API Automation Test as a Service",
    description="API service for remotely triggering and monitoring automated tests",
    version="2.0"
)

# =================================================================
# 1. API Model Definitions (Pydantic Models)
# =================================================================

class TestRunRequest(BaseModel):
    """
    Request body for triggering test runs.
    All optional fields have default value None for smart filtering.
    """
    env: str = Field(..., description="Runtime environment, e.g., 'dev', 'uat'")
    parallel: Optional[str] = Field(None, description="Number of parallel workers, e.g., '4', 'auto'")
    service: Optional[str] = Field(None, description="Filter by service")
    module: Optional[str] = Field(None, description="Filter by module")
    component: Optional[str] = Field(None, description="Filter by component")
    tags: Optional[str] = Field(None, description="Filter by tags, e.g., 'P0,smoke'")
    jira: Optional[str] = Field(None, description="Filter by Jira ID")
    id: Optional[int] = Field(None, description="Filter by case template ID")
    debug_mode: Optional[bool] = Field(False, description="Enable debug mode")


class TestRunResponse(BaseModel):
    """Response body after triggering test"""
    message: str
    run_id: str
    status_url: str

class RunStatusResponse(BaseModel):
    """Response body for querying test status"""
    run_id: str
    status: Optional[str] = None
    total_cases: Optional[int] = None
    passes: Optional[int] = None
    failures: Optional[int] = None
    skips: Optional[int] = None
    begin_time: Optional[datetime.datetime] = None
    end_time: Optional[datetime.datetime] = None
    allure_report_url: Optional[str] = None # Hypothetical report URL

# =================================================================
# 2. Background Task Execution Functions
# =================================================================

def execute_pytest_in_background(run_id: str, command: list):
    """Execute pytest command in background thread and update database status"""

    # Update status to RUNNING
    try:
        with Session() as session:
            progress_record = session.query(AutoProgress).filter_by(runid=run_id).first()
            if progress_record:
                progress_record.task_status = 'RUNNING'
                progress_record.begin_time = datetime.datetime.now()
                session.commit()
    except Exception as e:
        print(f"Error updating status to RUNNING for run_id {run_id}: {e}")

    # Execute tests
    process = subprocess.Popen(
        command,
        cwd=project_root, # Execute in project root directory
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate()

    # After test ends, sessionfinish hook in conftest.py will automatically update final status
    # Print logs here for debugging
    print(f"--- Test run {run_id} finished ---")
    print(f"STDOUT:\n{stdout}")
    if stderr:
        print(f"STDERR:\n{stderr}")


# =================================================================
# 3. API Endpoints
# =================================================================

@app.post("/run-tests/", response_model=TestRunResponse, status_code=202)
async def trigger_test_run(request: TestRunRequest, background_tasks: BackgroundTasks):
    """
    Trigger a new automated test run.
    This is an asynchronous interface that immediately returns a run_id for subsequent queries.
    """
    run_id = str(uuid.uuid4())

    # Smart command line argument construction, ignore placeholders
    command = ['python', 'run.py']
    # Define placeholder values to ignore, auto-generated by API tools
    placeholders_to_ignore = ["string", 0]

    for field, value in request.model_dump().items():
        # Add condition: ignore meaningless placeholder values
        if value is not None and value is not False and value not in placeholders_to_ignore:
            arg_name = f"--{field.replace('_', '-')}"
            if isinstance(value, bool) and value is True:
                command.append(arg_name)
            else:
                command.extend([arg_name, str(value)])

    # Pre-create a PENDING record in database
    try:
        with Session() as session:
            progress_record = AutoProgress(
                runid=run_id,
                task_status='PENDING',
                profile=request.env,
                label=request.tags,
                component=request.component,
                run_by='TaaS_API'
                # created_at and updated_at will be auto-populated by server_default
            )
            session.add(progress_record)
            session.commit()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create progress record in database: {e}")

    # Use FastAPI's BackgroundTasks to safely execute background tasks
    background_tasks.add_task(execute_pytest_in_background, run_id, command)

    return {
        "message": "Test run accepted and scheduled.",
        "run_id": run_id,
        "status_url": f"/run-status/{run_id}"
    }

