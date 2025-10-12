# tests/conftest.py

import pytest
import uuid
import datetime
import os
from sqlalchemy import create_engine

from core import db_handler
from core import result_writer
from models.tables import Environment
from core.api_client import ApiClient
from core.logger_config import logger

# =================================================================
# 1. Pytest Hooks
# Manage the lifecycle of the entire test session
# =================================================================

def is_master_process(session):
    """Determine if currently in pytest-xdist master process"""
    return not hasattr(session.config, 'workerinput')

def pytest_sessionstart(session):
    """
    At session start, master process is responsible for initializing database,
    determining RUN_ID, and creating initial summary record.
    """
    # Only master process handles initialization and creates initial records
    if is_master_process(session):
        session.start_time = datetime.datetime.now()

        run_id_from_cmd = session.config.getoption("--run-id")
        # Attach RUN_ID to config object so all worker processes can access it
        session.config.run_id = run_id_from_cmd or str(uuid.uuid4())

        logger.info(f"Test session started at {session.start_time} (RUN_ID: {session.config.run_id})")

        # Set environment variable in master process so workers can access it
        import os
        os.environ['FRAMEWORK_RUN_ID'] = session.config.run_id

        try:
            # Initialize session factory and attach to config object
            session.config.db_session_factory = db_handler.initialize_session()
            logger.info("Framework DB session factory initialized successfully")

            # Create initial summary record
            env_info = {
                "env": session.config.getoption("--env"),
                "component": session.config.getoption("--component"),
                "tags": session.config.getoption("--tags"),
            }
            with session.config.db_session_factory() as db_sess:
                result_writer.create_run_progress(db_sess, session.config.run_id, env_info)

        except Exception as e:
            pytest.exit(f"Database initialization or initial record creation failed: {e}", returncode=2)

def pytest_sessionfinish(session, exitstatus):
    """At session end, only master process handles summarization and final report update"""
    if is_master_process(session):
        end_time = datetime.datetime.now()
        logger.info(f"Test session finished at {end_time}")

        # Ensure database session factory is available
        session_factory = getattr(session.config, 'db_session_factory', None)
        if not session_factory:
            try:
                session_factory = db_handler.initialize_session()
            except Exception as e:
                logger.error(f"Failed to initialize database session in sessionfinish: {e}")
                return

        try:
            with session_factory() as db_sess:
                result_writer.update_run_summary(
                    session=db_sess,
                    run_id=session.config.run_id,
                    end_time=end_time,
                    status="FAILED" if exitstatus != 0 else "PASSED"
                )
        except Exception as e:
            logger.error(f"Failed to update run summary in sessionfinish: {e}")

@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """
    After each test execution, worker process writes individual case audit,
    and writes detailed steps in debug mode.
    """
    outcome = yield
    report = outcome.get_result()

    if report.when == 'call':
        try:
            run_data = item.callspec.params.get('test_case_run_data')
            if not run_data: return

            case_id, data_set_id, display_name, jira_id = run_data

            # Get run_id: priority from config, then environment variable, then command line
            run_id = getattr(item.config, 'run_id', None)
            if not run_id:
                import os
                run_id = os.environ.get('FRAMEWORK_RUN_ID') or item.config.getoption("--run-id", default=None)
            client_instance = item.funcargs.get('api_client')
            session_factory = getattr(item.config, 'db_session_factory', None)

            # If no session factory in worker process, reinitialize
            if not session_factory:
                try:
                    session_factory = db_handler.initialize_session()
                    item.config.db_session_factory = session_factory
                except Exception as e:
                    logger.error(f"Failed to initialize session factory in worker: {e}")
                    return

            if run_id and client_instance and session_factory:
                # Get resolved variables used in this run
                variables = client_instance.resolved_data_set_variables

                with session_factory() as db_sess:
                    # Write individual case audit and get its ID
                    audit_case_id = result_writer.write_case_audit(
                        db_sess, run_id, case_id, data_set_id, jira_id,
                        display_name, variables, report
                    )

                    # If in debug mode, write detailed steps
                    is_debug = item.config.getoption("--debug-mode")
                    if is_debug and audit_case_id and client_instance.audit_trail:
                        result_writer.write_debug_log(
                            db_sess, audit_case_id, client_instance.audit_trail
                        )
        except Exception as e:
            logger.error(f"Failed to write result for item {item.name}: {e}")

def pytest_addoption(parser):
    """Register all custom parameters to pytest command line"""
    parser.addoption("--env", action="store", required=True, help="Specify runtime environment: dev, uat")
    parser.addoption("--service", action="store", default=None)
    parser.addoption("--module", action="store", default=None)
    parser.addoption("--component", action="store", default=None)
    parser.addoption("--tags", action="store", default=None)
    parser.addoption("--jira", action="store", default=None)
    parser.addoption("--id", action="store", default=None)
    parser.addoption("--run-id", action="store", default=None)

    parser.addoption("--debug-mode", action="store_true", default=False)

# =================================================================
# 3. Pytest Fixtures
# Provide reusable resources for test functions
# =================================================================

@pytest.fixture(scope="session")
def db_session_factory(request):
    """Provide a session-level database session factory"""
    factory = getattr(request.config, 'db_session_factory', None)
    if not factory:
        # In worker process, reinitialize database session factory
        try:
            factory = db_handler.initialize_session()
            request.config.db_session_factory = factory
        except Exception as e:
            pytest.fail(f"Database session factory initialization failed: {e}")
    return factory

@pytest.fixture(scope="session")
def test_environment(request, db_session_factory):
    """Load complete Environment configuration object from database based on --env parameter."""
    env_name = request.config.getoption("--env")
    with db_session_factory() as session:
        env_config = session.query(Environment).filter(
            Environment.name == env_name, Environment.is_active == True
        ).first()

    if not env_config:
        pytest.fail(f"Active environment configuration named '{env_name}' not found in test_environments table")

    logger.info(f"Running tests against Environment: '{env_name}'")
    return env_config

@pytest.fixture(scope="session")
def base_url(test_environment):
    """Get base_url from test_environment fixture"""
    logger.info(f"Using base_url: {test_environment.base_url}")
    return test_environment.base_url

@pytest.fixture(scope="session")
def app_db_connection(test_environment):
    """Create and provide connection to application database based on current test environment."""
    conn_string = test_environment.app_db_connection_string
    if not conn_string:
        yield None
        return

    engine, connection = None, None
    try:
        engine = create_engine(conn_string)
        connection = engine.connect()
        logger.info(f"Successfully connected to application DB for env '{test_environment.name}'")
        yield connection
    except Exception as e:
        pytest.fail(f"Unable to connect to application database: {e}", pytrace=False)
    finally:
        if connection: connection.close()
        if engine: engine.dispose()
        logger.info("Application DB connection closed")

@pytest.fixture
def api_client(base_url):
    """
    Function-level fixture that creates an independent ApiClient instance for each test case.
    """
    return ApiClient(base_url)
