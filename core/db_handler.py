# core/db_handler.py

import os
from sqlalchemy import create_engine, or_, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool
from models.tables import ApiAutoCase, CaseDataSet, Environment
from core.logger_config import logger

def get_db_engine():
    """
    Create and return database engine with optimized connection pool configuration.

    Connection Pool Settings:
    - pool_size: 20 (基础连接池大小，适合中等并发)
    - max_overflow: 10 (最多额外创建10个临时连接)
    - pool_timeout: 30 (等待连接的最长时间)
    - pool_recycle: 3600 (1小时后回收连接，避免数据库超时)
    - pool_pre_ping: True (使用前检查连接有效性)
    - echo_pool: False (不输出连接池调试信息)
    """
    required_vars = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_NAME', 'DB_PASSWORD']
    for var in required_vars:
        if not os.getenv(var):
            raise ValueError(f"Database connection environment variable '{var}' is not set")

    db_url = (
        f"postgresql+psycopg2://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@"
        f"{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
    )

    # 从环境变量获取连接池配置，或使用默认值
    pool_size = int(os.getenv('DB_POOL_SIZE', 20))
    max_overflow = int(os.getenv('DB_MAX_OVERFLOW', 10))
    pool_timeout = int(os.getenv('DB_POOL_TIMEOUT', 30))
    pool_recycle = int(os.getenv('DB_POOL_RECYCLE', 3600))

    engine = create_engine(
        db_url,
        echo=False,
        poolclass=QueuePool,
        pool_size=pool_size,
        max_overflow=max_overflow,
        pool_timeout=pool_timeout,
        pool_recycle=pool_recycle,
        pool_pre_ping=True,
        echo_pool=False,
        connect_args={
            'connect_timeout': 10,  # 连接超时时间
        }
    )

    # 注册连接池事件监听器（用于调试和监控）
    @event.listens_for(engine, "connect")
    def receive_connect(dbapi_conn, connection_record):
        logger.debug(f"New database connection established: {id(dbapi_conn)}")

    @event.listens_for(engine, "checkout")
    def receive_checkout(dbapi_conn, connection_record, connection_proxy):
        logger.debug(f"Connection checked out from pool: {id(dbapi_conn)}")

    @event.listens_for(engine, "checkin")
    def receive_checkin(dbapi_conn, connection_record):
        logger.debug(f"Connection returned to pool: {id(dbapi_conn)}")

    logger.info(
        f"Database engine created with connection pool: "
        f"size={pool_size}, max_overflow={max_overflow}, "
        f"timeout={pool_timeout}s, recycle={pool_recycle}s"
    )

    return engine

def initialize_session():
    """Initialize and return a SQLAlchemy SessionMaker (session factory)."""
    engine = get_db_engine()
    return sessionmaker(bind=engine)

def get_pool_status(engine):
    """
    Get current connection pool status for monitoring and debugging.

    Returns:
        dict: Dictionary containing pool statistics
    """
    pool = engine.pool
    return {
        'pool_size': pool.size(),
        'checked_in_connections': pool.checkedin(),
        'checked_out_connections': pool.checkedout(),
        'overflow_connections': pool.overflow(),
        'total_connections': pool.checkedin() + pool.checkedout(),
    }

def get_test_cases_by_filter(session, env: str, service=None, module=None, component=None, tags=None, jira_id=None, case_id=None):
    """Get the list of test scenarios to run based on all filter conditions."""
    query = session.query(
        ApiAutoCase.id,
        CaseDataSet.id,
        ApiAutoCase.name,
        CaseDataSet.data_set_name,
        CaseDataSet.jira_id
    ).join(ApiAutoCase, ApiAutoCase.id == CaseDataSet.case_id).filter(CaseDataSet.is_active == True)

    query = query.filter(
        or_(
            CaseDataSet.environments == None,
            CaseDataSet.environments == [],
            CaseDataSet.environments.any(env)
        )
    )

    if service: query = query.filter(ApiAutoCase.service == service)
    if module: query = query.filter(ApiAutoCase.module == module)
    if component: query = query.filter(ApiAutoCase.component == component)
    if tags:
        tag_list = [tag.strip() for tag in tags.split(',')]
        query = query.filter(ApiAutoCase.tags.contains(tag_list))
    if jira_id: query = query.filter(CaseDataSet.jira_id == jira_id)
    if case_id: query = query.filter(ApiAutoCase.id == case_id)

    results = query.all()
    return [(row[0], row[1], f"{row[2]} [{row[3]}]", row[4]) for row in results]

def get_case_details(session, case_id, data_set_id):
    """
    Get complete detailed information for a single test scenario.

    Uses the 2-table design where steps are stored in api_auto_cases.parameters JSONB column.
    """
    test_case = session.query(ApiAutoCase).filter(ApiAutoCase.id == case_id).first()
    data_set = session.query(CaseDataSet).filter(CaseDataSet.id == data_set_id).first()

    if not test_case or not data_set:
        return None

    # Validate that test case has parameters
    if not hasattr(test_case, 'parameters') or not test_case.parameters:
        raise ValueError(
            f"Test case {case_id} does not have a 'parameters' column. "
            "Please ensure all test cases use the 2-table design with steps stored in JSONB."
        )

    # Extract steps from parameters JSONB column
    parameters = test_case.parameters
    steps_list = parameters.get('steps', [])

    if not steps_list:
        raise ValueError(f"Test case {case_id} has no steps defined in parameters.steps")

    # Convert to the format expected by api_client
    resolved_actions = []
    for step in steps_list:
        resolved_actions.append({
            'step_order': step.get('order'),
            'description': step.get('description', ''),
            'http_method': step.get('method'),
            'api_url_path': step.get('path'),
            'headers': step.get('request', {}).get('headers'),
            'params': step.get('request', {}).get('params'),
            'body': step.get('request', {}).get('body'),
            'validations': step.get('validations'),
            'outputs': step.get('outputs')
        })

    # Return unified structure
    case_details = {
        "id": test_case.id,
        "name": test_case.name,
        "data_set_variables": data_set.variables,
        "validations_override": data_set.validations_override,
        "steps": resolved_actions
    }
    return case_details
