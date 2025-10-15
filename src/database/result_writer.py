# core/result_writer.py

import datetime
import os
from sqlalchemy import func, case
from src.database.models import AutoProgress, AutoCaseAudit, AutoTestAudit
from src.common.logger import logger

# China timezone (UTC+8)
CHINA_TZ = datetime.timezone(datetime.timedelta(hours=8))

def create_run_progress(session, run_id, env_info):
    """
    Create an initial progress record at the start of the test run.
    :param session: SQLAlchemy session object.
    :param run_id: The unique ID for this test run.
    :param env_info: A dict containing env, component, tags.
    """
    progress_record = AutoProgress(
        runid=run_id,
        task_status='RUNNING',
        begin_time=datetime.datetime.now(CHINA_TZ),
        profile=env_info.get("env"),
        label=env_info.get("tags"),
        component=env_info.get("component"),
        run_by=os.getenv('USER', os.getenv('USERNAME', 'unknown'))
        # created_at and updated_at will be auto-populated by server_default
    )
    try:
        session.add(progress_record)
        session.commit()
    except Exception as e:
        logger.error(f"Failed to create initial progress record: {e}")
        session.rollback()

def write_case_audit(session, run_id, case_id, jira_id, input_variables, report):
    """
    Write test case execution summary to auto_case_audit table.

    This function stores lightweight summary information only:
    - Test execution status and timing
    - Input variables (dataset parameters)
    - Error message if failed

    Detailed request/response data is stored separately in auto_test_audit.

    :param session: SQLAlchemy session object.
    :param run_id: Unique test run identifier.
    :param case_id: Test case ID.
    :param jira_id: Associated JIRA ticket ID.
    :param input_variables: Test input parameters (dataset variables).
    :param report: Pytest TestReport object.
    :return: The ID of the newly created audit record, or None on failure.
    """
    error_message = report.longreprtext if report.failed else None

    audit_record = AutoCaseAudit(
        runid=run_id,
        case_id=case_id,
        issue_key=jira_id,
        input_variables=input_variables,
        run_status=report.outcome, # 'passed', 'failed', 'skipped'
        duration=report.duration,
        error_message=error_message
    )
    try:
        session.add(audit_record)
        session.commit()
        return audit_record.id # Return the ID of the newly created record
    except Exception as e:
        logger.error(f"Failed to write case audit result: {e}")
        session.rollback()
        return None

def write_debug_log(session, audit_case_id, audit_trail, save_all=False):
    """
    Write detailed step audit logs to auto_test_audit table.

    Strategy (Layered Storage):
    - Debug mode (--debug-mode): Save ALL steps for ALL tests
    - Normal mode: Save steps ONLY for FAILED tests (auto-diagnostic)
    - Passed tests: No detailed logs unless debug mode

    This approach provides automatic failure diagnostics without overwhelming the database.

    :param session: SQLAlchemy session object.
    :param audit_case_id: The primary key of the parent auto_case_audit record.
    :param audit_trail: A list of step dictionaries from ApiClient.
    :param save_all: If True, save all steps; if False, save only failed steps.
    """
    if not audit_case_id or not audit_trail:
        return

    try:
        records_to_add = []

        for step_log in audit_trail:
            step_status = step_log.get("step_status")

            # Save all steps if requested, otherwise only save failed steps
            if save_all or step_status == 'failed':
                records_to_add.append(AutoTestAudit(
                    audit_case_id=audit_case_id,
                    step_order=step_log.get("step_order"),
                    action_description=step_log.get("action_description"),
                    request_details=step_log.get("request_details"),
                    response_details=step_log.get("response_details"),
                    step_status=step_status,
                    step_duration=step_log.get("step_duration")  # Now populated
                ))

        if records_to_add:
            session.bulk_save_objects(records_to_add)
            session.commit()
            logger.debug(f"Saved {len(records_to_add)} step logs to auto_test_audit")

    except Exception as e:
        logger.error(f"Failed to write debug audit log: {e}")
        session.rollback()

def update_run_summary(session, run_id, end_time, status):
    """
    Aggregate data from auto_case_audit table and update auto_progress table.
    :param session: SQLAlchemy session object.
    :param run_id: The unique ID for this test run.
    :param end_time: The timestamp when the session finished.
    :param status: The final status ('PASSED' or 'FAILED').
    """
    try:
        # 1. Perform aggregation query from detailed result table
        stats = session.query(
            func.count(AutoCaseAudit.id).label("total"),
            func.sum(case((AutoCaseAudit.run_status == 'passed', 1), else_=0)).label("passed"),
            func.sum(case((AutoCaseAudit.run_status == 'failed', 1), else_=0)).label("failed"),
            func.sum(case((AutoCaseAudit.run_status == 'skipped', 1), else_=0)).label("skipped")
        ).filter(AutoCaseAudit.runid == run_id).one()

        # 2. Find and update the progress record
        progress_record = session.query(AutoProgress).filter_by(runid=run_id).first()
        if progress_record:
            progress_record.total_cases = stats.total
            progress_record.passes = stats.passed or 0
            progress_record.failures = stats.failed or 0
            progress_record.skips = stats.skipped or 0
            progress_record.end_time = end_time
            progress_record.task_status = status
            # updated_at will be auto-updated by onupdate=func.now()
            session.commit()
            logger.info(f"Test run summary successfully updated in database (runid: {run_id})")
        else:
            logger.warning(f"Could not find progress record with runid '{run_id}' to update summary.")
    except Exception as e:
        logger.error(f"Failed to update run summary: {e}")
        session.rollback()
