# tests/test_main.py

import pytest
import allure
from core.db_handler import get_test_cases_by_filter, get_case_details
from core.api_client import ApiClient

def pytest_generate_tests(metafunc):
    """
    在测试收集阶段，从数据库动态加载所有需要运行的测试场景。
    """
    if "test_case_run_data" in metafunc.fixturenames:
        session_factory = getattr(metafunc.config, 'db_session_factory', None)
        if not session_factory:
            # 在工作进程中，尝试重新初始化数据库会话工厂
            try:
                from core import db_handler
                session_factory = db_handler.initialize_session()
                metafunc.config.db_session_factory = session_factory
            except Exception:
                pytest.skip("数据库会话工厂不可用，跳过测试收集")
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
            pytest.skip(f"在环境 '{env}' 下没有根据筛选条件找到任何测试用例")

        metafunc.parametrize(
            "test_case_run_data",
            test_cases_to_run,
            ids=[row[2] for row in test_cases_to_run]
        )

@allure.epic("API Test Suite")
class TestApi:
    """
    所有数据驱动的API测试都通过这个类来执行。
    """
    def test_run_case(self, test_case_run_data, api_client, app_db_connection, db_session_factory):
        """
        这是一个测试模板方法，会被 pytest_generate_tests 多次调用。
        """
        case_id, data_set_id, case_display_name, jira_id = test_case_run_data

        with allure.step(f"Executing Case: {case_display_name}"):
            with db_session_factory() as session:
                full_case_details = get_case_details(session, case_id, data_set_id)

            if not full_case_details:
                pytest.fail(f"无法找到 Case ID: {case_id} / DataSet ID: {data_set_id} 的详细信息")

            api_client.execute_steps(full_case_details, app_db_conn=app_db_connection)
