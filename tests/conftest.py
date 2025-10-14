# tests/conftest.py

import pytest
import uuid
import datetime
import os

from src.database import handler as db_handler
from src.database import result_writer
from src.client.api_client import ApiClient
from src.common.logger import logger

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
                variables = getattr(client_instance, 'resolved_data_set_variables', {})

                # Get audit trail
                audit_trail = getattr(client_instance, 'audit_trail', [])

                with session_factory() as db_sess:
                    # Write individual case audit and get its ID
                    audit_case_id = result_writer.write_case_audit(
                        db_sess, run_id, case_id, data_set_id, jira_id,
                        display_name, variables, report
                    )

                    # If in debug mode, write detailed steps
                    is_debug = item.config.getoption("--debug-mode")
                    if is_debug and audit_case_id and audit_trail:
                        result_writer.write_debug_log(
                            db_sess, audit_case_id, audit_trail
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
# 2. Cache Loading Helper Functions
# Load configurations into memory to avoid repeated database queries
# =================================================================

def _load_environment_configs(db_session_factory, env_name: str) -> dict:
    """
    Load all service configurations for specified environment into cache.

    This function queries the database once to load all service configurations
    for the current environment, then returns a dictionary for O(1) lookups.

    Args:
        db_session_factory: SQLAlchemy session factory
        env_name: Environment name (e.g., 'dev', 'uat')

    Returns:
        dict: {service_name: base_url} mapping
        Example: {'user_svc': 'http://127.0.0.1:8788',
                  'exchange_svc': 'https://uat-api.3ona.co',
                  'websocket_svc': 'wss://uat-stream.3ona.co/exchange/v1/market'}
    """
    import time
    from src.database.models import Environment

    start_time = time.time()

    with db_session_factory() as session:
        configs = session.query(Environment).filter(
            Environment.name == env_name,
            Environment.is_active == True
        ).all()

        cache = {config.service: config.base_url for config in configs}

    elapsed = time.time() - start_time
    logger.info(
        f"📦 Loaded environment config cache: "
        f"{len(cache)} services for '{env_name}' in {elapsed:.3f}s"
    )
    logger.debug(f"Available services: {list(cache.keys())}")

    return cache


def _load_case_service_mappings(db_session_factory) -> dict:
    """
    Load all test case to service mappings into cache.

    Single-table design: Directly query service from api_auto_cases.

    Args:
        db_session_factory: SQLAlchemy session factory

    Returns:
        dict: {case_id: service_name} mapping
        Example: {1: 'exchange_svc', 10: 'exchange_svc', 13: 'websocket_svc'}
    """
    import time
    from src.database.models import ApiAutoCase

    start_time = time.time()

    with db_session_factory() as session:
        cases = session.query(ApiAutoCase.id, ApiAutoCase.service)\
            .filter(ApiAutoCase.is_active == True).all()
        cache = {case_id: service for case_id, service in cases}

    elapsed = time.time() - start_time
    logger.info(
        f"📦 Loaded case-service mapping cache: "
        f"{len(cache)} test cases in {elapsed:.3f}s"
    )

    return cache

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
def test_environment(request):
    """
    Return environment name from --env parameter.
    """
    env_name = request.config.getoption("--env")
    logger.info(f"Running tests against Environment: '{env_name}'")
    return env_name

@pytest.fixture(scope="session")
def environment_config_cache(db_session_factory, test_environment):
    """
    Session-level cache of environment configurations.

    Loads once per worker process at startup, then all tests read from memory.
    Maps service names to their base URLs for the current environment.

    Performance Benefits:
    - Without cache: Each test queries database (e.g., 500 tests = 500 queries)
    - With cache: One query per worker at startup (e.g., 4 workers = 4 queries)
    - Improvement: ~99% reduction in database queries

    Parallel Execution:
    - Each worker process creates its own cache instance
    - No cache conflicts between workers (independent memory spaces)
    - Small overhead: N workers = N cache loads (acceptable for massive test savings)

    Returns:
        dict: {service_name: base_url}
        Example: {'user_svc': 'http://127.0.0.1:8788',
                  'exchange_svc': 'https://uat-api.3ona.co'}
    """
    logger.info(f"🔄 Initializing environment config cache for worker process...")
    return _load_environment_configs(db_session_factory, test_environment)


@pytest.fixture(scope="session")
def case_service_cache(db_session_factory):
    """
    Session-level cache of test case to service mappings.

    Single-table design: Maps test case IDs to their service names.
    Loads once per worker process at startup, then all tests read from memory.

    Performance Benefits:
    - Without cache: Each test queries database (e.g., 43 tests = 43 queries)
    - With cache: One query per worker at startup (e.g., 4 workers = 4 queries)
    - Improvement: ~90% reduction in database queries

    Parallel Execution:
    - Each worker process creates its own cache instance
    - No cache conflicts between workers (independent memory spaces)
    - Memory usage: Minimal (~50 bytes per test case)

    Returns:
        dict: {case_id: service_name}
        Example: {1: 'exchange_svc', 10: 'exchange_svc', 13: 'websocket_svc'}
    """
    logger.info(f"🔄 Initializing case-service mapping cache for worker process...")
    return _load_case_service_mappings(db_session_factory)


@pytest.fixture
def base_url(request, environment_config_cache, case_service_cache):
    """
    Dynamically get base_url for current test case based on its service.

    Single-table design: Uses session-level caches to avoid database queries.
    All data is read from memory after initial cache loading at worker startup.

    Execution Flow:
    1. Get case_id from test parameters
    2. Lookup service name from case_service_cache (memory, O(1))
    3. Lookup base_url from environment_config_cache (memory, O(1))
    4. Return base_url (zero database queries per test)

    Performance:
    - Database queries per test: 0 (after cache initialization)
    - Memory lookups per test: 2 (both O(1) dict operations)
    - Typical lookup time: <0.001ms

    Error Handling:
    - Missing test case: Provides total cached cases count for debugging
    - Missing service config: Lists available services to help troubleshooting

    Returns:
        str: Base URL for the service of current test case
    """
    # Get test case run data from the parametrized test
    test_case_run_data = request.node.callspec.params.get('test_case_run_data')

    if not test_case_run_data:
        # Fallback for non-parametrized tests (should not happen in normal flow)
        return "http://placeholder"

    case_id = test_case_run_data[0]

    # Step 1: Get service name from cache (no database query)
    service_name = case_service_cache.get(case_id)
    if not service_name:
        available_cases = len(case_service_cache)
        pytest.fail(
            f"Test case {case_id} not found in cache.\n"
            f"Total cached cases: {available_cases}\n"
            f"Please verify the test case exists in api_auto_cases table.",
            pytrace=False
        )

    # Step 2: Get base_url from cache (no database query)
    base_url_value = environment_config_cache.get(service_name)
    if not base_url_value:
        available_services = list(environment_config_cache.keys())
        pytest.fail(
            f"No active configuration found for service '{service_name}'.\n"
            f"Available services: {available_services}\n"
            f"Please check test_environments table for missing configuration.",
            pytrace=False
        )

    # Log cache hit (debug level to avoid noise in normal runs)
    logger.debug(
        f"[Cache Hit] case_id={case_id} → service={service_name} → url={base_url_value}"
    )

    return base_url_value

@pytest.fixture
def api_client(base_url):
    """
    Function-level fixture that creates an ApiClient instance for each test case.
    Base URL is automatically determined based on test case's service.

    Uses enhanced placeholder system with built-in functions.
    """
    return ApiClient(base_url)
