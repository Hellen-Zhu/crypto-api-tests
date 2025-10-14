# models/tables.py

from sqlalchemy import (
    Column, Integer, String, Text, Boolean,
    ForeignKey, TIMESTAMP, func, REAL
)
from sqlalchemy.dialects.postgresql import JSONB, ARRAY
from sqlalchemy.orm import declarative_base, relationship

# Create base class for all ORM classes
Base = declarative_base()

# =================================================================
# 1. Test Case Definition Tables
# =================================================================

class ApiAutoCase(Base):
    """
    Unified test case definition table (single-table design)
    Each row represents a complete, independent test case
    """
    __tablename__ = 'api_auto_cases'

    id = Column(Integer, primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)

    # Classification fields
    service = Column(String(100), nullable=False, index=True)
    module = Column(String(100), index=True)
    component = Column(String(100), index=True)
    tags = Column(ARRAY(Text), index=True)

    # Environment targeting
    environments = Column(ARRAY(Text), index=True)

    # External references
    jira_id = Column(String(50), unique=True)
    author = Column(String(50))

    # Core test configuration (consolidated)
    # Structure: {"variables": {...}, "steps": [...], "validations": {...}}
    test_config = Column(JSONB, nullable=False)

    # Status and metadata
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

# =================================================================
# 2. Test Configuration Tables
# =================================================================

class Environment(Base):
    """
    Test environment configuration table.
    Each row represents a specific service in a specific environment.

    Example rows:
    - (dev, user_svc, http://127.0.0.1:8788)
    - (dev, exchange_svc, https://dev-api.3ona.co)
    - (uat, websocket_svc, wss://uat-stream.3ona.co/exchange/v1/market)
    """
    __tablename__ = 'test_environments'

    __table_args__ = (
        # Composite unique constraint on (name, service)
        # Allows multiple rows per environment, one for each service
        # e.g., dev can have user_svc, exchange_svc, websocket_svc
        {'extend_existing': True}
    )

    id = Column(Integer, primary_key=True)
    name = Column(String(50), nullable=False, index=True)  # Environment name: dev, uat
    service = Column(String(50), nullable=False, index=True)  # Service name: user_svc, exchange_svc, websocket_svc
    base_url = Column(String(255), nullable=False)  # Service-specific base URL or full WebSocket URL
    description = Column(Text)
    is_active = Column(Boolean, default=True)

# =================================================================
# 3. Test Result Tables
# =================================================================

class AutoProgress(Base):
    """Test run summary information table"""
    __tablename__ = 'auto_progress'
    id = Column(Integer, primary_key=True)
    runid = Column(String(50))
    version_id = Column(String(35))
    component = Column(String(50))
    total_cases = Column(Integer)
    passes = Column(Integer)
    failures = Column(Integer)
    skips = Column(Integer)
    begin_time = Column(TIMESTAMP)
    end_time = Column(TIMESTAMP)
    releaseversion = Column(String(200))
    task_status = Column(String(25))
    run_by = Column(String(50))
    label = Column(String(1000))
    runmode = Column(String(255))
    profile = Column(String(200))
    update_time = Column(TIMESTAMP)

class AutoCaseAudit(Base):
    """Detailed test case result audit table"""
    __tablename__ = 'auto_case_audit'
    id = Column(Integer, primary_key=True)
    runid = Column(String(50), nullable=False, index=True)
    case_id = Column(Integer)
    data_set_id = Column(Integer)
    scenario = Column(Text)
    issue_key = Column(String(50))
    run_status = Column(String(20))
    duration = Column(REAL)
    error_message = Column(Text)
    variables = Column(JSONB)
    update_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    debug_logs = relationship("AutoTestAudit", back_populates="case_audit", cascade="all, delete-orphan")

class AutoTestAudit(Base):
    """Detailed step-by-step interaction log table for debug mode"""
    __tablename__ = 'auto_test_audit'
    id = Column(Integer, primary_key=True)
    audit_case_id = Column(Integer, ForeignKey('auto_case_audit.id'), nullable=False)
    step_order = Column(Integer)
    action_description = Column(Text)
    request_details = Column(JSONB)
    response_details = Column(JSONB)
    step_status = Column(String(20))
    case_audit = relationship("AutoCaseAudit", back_populates="debug_logs")
