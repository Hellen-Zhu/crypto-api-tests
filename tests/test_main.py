# tests/test_main.py

import pytest
import allure
from src.database.handler import get_test_cases_by_filter, get_case_details

def pytest_generate_tests(metafunc):
    """
    Dynamically load all test scenarios from database during test collection phase.
    """
    if "test_case_run_data" in metafunc.fixturenames:
        session_factory = getattr(metafunc.config, 'db_session_factory', None)
        if not session_factory:
            # In worker process, try to re-initialize database session factory
            try:
                from src.database import handler as db_handler
                session_factory = db_handler.initialize_session()
                metafunc.config.db_session_factory = session_factory
            except Exception:
                pytest.skip("Database session factory not available, skipping test collection")
                return

        env = metafunc.config.getoption("--env")
        service = metafunc.config.getoption("--service")
        module = metafunc.config.getoption("--module")
        component = metafunc.config.getoption("--component")
        tags = metafunc.config.getoption("--tags")
        jira_id = metafunc.config.getoption("--jira")
        case_id = metafunc.config.getoption("--id")

        with session_factory() as session:
            test_cases_to_run = get_test_cases_by_filter(
                session=session, env=env, service=service, module=module,
                component=component, tags=tags, jira_id=jira_id, case_id=case_id
            )

        if not test_cases_to_run:
            pytest.skip(f"No test cases found in environment '{env}' with the given filter criteria")

        metafunc.parametrize(
            "test_case_run_data",
            test_cases_to_run,
            ids=[row[1] for row in test_cases_to_run]
        )

@allure.epic("API Test Suite")
class TestApi:
    """
    All data-driven API tests are executed through this class.
    """
    def test_run_case(self, test_case_run_data, api_client, db_session_factory):
        """
        This is a test template method that will be called multiple times by pytest_generate_tests.
        The api_client's base_url has been automatically set to the service URL corresponding to the current test case via fixture.
        """
        case_id, case_display_name, jira_id = test_case_run_data

        with allure.step(f"Executing Case: {case_display_name}"):
            with db_session_factory() as session:
                full_case_details = get_case_details(session, case_id)

            if not full_case_details:
                pytest.fail(f"Unable to find details for Case ID: {case_id}")

            # api_client.base_url has already been automatically set by base_url fixture
            # No need to manually query and set
            api_client.execute_steps(full_case_details)
