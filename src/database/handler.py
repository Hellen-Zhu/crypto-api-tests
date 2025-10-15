# core/db_handler.py

import os
from sqlalchemy import create_engine, or_, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool
from src.database.models import ApiAutoCase, Environment
from src.common.logger import logger

def get_db_engine():
    """
    Create and return database engine with optimized connection pool configuration.

    Connection Pool Settings:
    - pool_size: 20 (base connection pool size, suitable for medium concurrency)
    - max_overflow: 10 (maximum of 10 additional temporary connections)
    - pool_timeout: 30 (maximum wait time for connection)
    - pool_recycle: 3600 (recycle connections after 1 hour to avoid database timeout)
    - pool_pre_ping: True (check connection validity before use)
    - echo_pool: False (do not output connection pool debug info)
    """
    required_vars = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_NAME', 'DB_PASSWORD']
    for var in required_vars:
        if not os.getenv(var):
            raise ValueError(f"Database connection environment variable '{var}' is not set")

    db_url = (
        f"postgresql+psycopg2://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@"
        f"{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
    )

    # Get connection pool configuration from environment variables, or use default values
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
            'connect_timeout': 10,  # Connection timeout
            'options': '-c timezone=Asia/Shanghai'  # Use local timezone for timestamps
        }
    )

    # Register connection pool event listeners (for debugging and monitoring)
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
    """
    Get the list of test cases to run based on all filter conditions.
    Single-table design: each row is an independent test case.
    """
    query = session.query(
        ApiAutoCase.id,
        ApiAutoCase.name,
        ApiAutoCase.jira_id
    ).filter(ApiAutoCase.enable == True)

    # Environment filter
    query = query.filter(
        or_(
            ApiAutoCase.environments == None,
            ApiAutoCase.environments == [],
            ApiAutoCase.environments.any(env)
        )
    )

    # Apply filters
    if service: query = query.filter(ApiAutoCase.service == service)
    if module: query = query.filter(ApiAutoCase.module == module)
    if component: query = query.filter(ApiAutoCase.component == component)
    if tags:
        tag_list = [tag.strip() for tag in tags.split(',')]
        query = query.filter(ApiAutoCase.tags.contains(tag_list))
    if jira_id: query = query.filter(ApiAutoCase.jira_id == jira_id)
    if case_id: query = query.filter(ApiAutoCase.id == case_id)

    results = query.all()
    # Return format: (case_id, display_name, jira_id)
    # Single-table design: each test case is independent
    return [(row.id, row.name, row.jira_id) for row in results]

def get_case_details(session, case_id):
    """
    Get complete detailed information for a single test case.

    Single-table design: all information (steps, variables, validations)
    is stored in the test_config JSONB column.
    """
    test_case = session.query(ApiAutoCase).filter(ApiAutoCase.id == case_id).first()

    if not test_case:
        return None

    # Validate that test case has test_config
    if not hasattr(test_case, 'test_config') or not test_case.test_config:
        raise ValueError(
            f"Test case {case_id} does not have a 'test_config' column. "
            "Please ensure the database migration to single-table design is complete."
        )

    # Extract configuration from test_config JSONB column
    test_config = test_case.test_config
    steps_list = test_config.get('steps', [])
    variables = test_config.get('variables', {})
    validations = test_config.get('validations', {})

    if not steps_list:
        raise ValueError(f"Test case {case_id} has no steps defined in test_config.steps")

    # Convert to the format expected by api_client
    # Support both HTTP and WebSocket protocols
    resolved_actions = []
    for step in steps_list:
        step_dict = {
            'step_order': step.get('order') or step.get('step_order'),
            'description': step.get('description', ''),
            'protocol': step.get('protocol', 'http'),  # Default to HTTP for backward compatibility
            'validations': step.get('validations'),
            'outputs': step.get('outputs')
        }

        # HTTP-specific fields
        if step_dict['protocol'] == 'http':
            step_dict.update({
                'method': step.get('method'),
                'path': step.get('path'),
                'headers': step.get('headers') or step.get('request', {}).get('headers'),
                'params': step.get('params') or step.get('request', {}).get('params'),
                'body': step.get('body') or step.get('request', {}).get('body')
            })

        # WebSocket-specific fields
        elif step_dict['protocol'] == 'websocket':
            step_dict.update({
                'action': step.get('action'),
                # Include the entire request object for WebSocket steps
                'request': step.get('request', {})
            })

        resolved_actions.append(step_dict)

    # Return unified structure (compatible with existing api_client interface)
    case_details = {
        "id": test_case.id,
        "name": test_case.name,
        "data_set_variables": variables,
        "validations_override": validations,
        "steps": resolved_actions
    }
    return case_details
