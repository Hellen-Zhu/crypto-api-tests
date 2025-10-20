# models/tables.py

import os
from sqlalchemy import (
    Column, Integer, String, Text, Boolean,
    ForeignKey, TIMESTAMP, REAL, text
)
from sqlalchemy.dialects.postgresql import JSONB, ARRAY
from sqlalchemy.orm import declarative_base, relationship

# Create base class for all ORM classes
Base = declarative_base()

# Helper function to get current time in configured timezone
def get_current_timestamp():
    """
    Returns current timestamp in the configured timezone.
    Timezone is read from DB_TIMEZONE environment variable (default: Asia/Shanghai)
    """
    db_timezone = os.getenv('DB_TIMEZONE', 'Asia/Shanghai')
    return text(f"(NOW() AT TIME ZONE 'UTC' AT TIME ZONE '{db_timezone}')")

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
    enable = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp(), onupdate=get_current_timestamp())

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
    """
    Test run summary information table
    Each row represents one test execution session with aggregated statistics
    """
    __tablename__ = 'auto_progress'
    id = Column(Integer, primary_key=True)
    runid = Column(String(50), unique=True, nullable=False, index=True)
    version_id = Column(String(35))
    component = Column(String(50))
    total_cases = Column(Integer, default=0)
    passes = Column(Integer, default=0)
    failures = Column(Integer, default=0)
    skips = Column(Integer, default=0)
    begin_time = Column(TIMESTAMP(timezone=True))
    end_time = Column(TIMESTAMP(timezone=True))
    releaseversion = Column(String(200))
    task_status = Column(String(25))
    run_by = Column(String(50))
    label = Column(String(1000))
    runmode = Column(String(255))
    profile = Column(String(200))

    # Timestamp fields (unified naming convention)
    created_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp(), onupdate=get_current_timestamp())

class AutoCaseAudit(Base):
    """
    Test case execution summary table.
    Each row represents one test case execution with its result and basic context.

    Design Philosophy (Layered Storage):
    - This table stores SUMMARY information only (lightweight)
    - Detailed step-by-step data stored in auto_test_audit (heavy)
    - Failed cases automatically get detailed logs even without debug mode
    """
    __tablename__ = 'auto_case_audit'
    id = Column(Integer, primary_key=True)
    runid = Column(String(50), nullable=False, index=True)
    case_id = Column(Integer, index=True)
    issue_key = Column(String(50), index=True)
    run_status = Column(String(20), index=True)  # 'passed', 'failed', 'skipped'
    duration = Column(REAL)
    error_message = Column(Text)

    # Lightweight execution context (input parameters only)
    # Stores only test input variables, not full request/response
    input_variables = Column(JSONB)

    # Timestamp fields (unified naming convention)
    created_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp(), onupdate=get_current_timestamp())

    # Relationships
    debug_logs = relationship("AutoTestAudit", back_populates="case_audit", cascade="all, delete-orphan")

class AutoTestAudit(Base):
    """
    Detailed step-by-step interaction log table for debug mode
    Each row represents one API request/response step within a test case
    Only populated when debug logging is enabled
    """
    __tablename__ = 'auto_test_audit'
    id = Column(Integer, primary_key=True)
    audit_case_id = Column(Integer, ForeignKey('auto_case_audit.id', ondelete='CASCADE'), nullable=False, index=True)
    step_order = Column(Integer)
    action_description = Column(Text)
    request_details = Column(JSONB)
    response_details = Column(JSONB)
    step_status = Column(String(20))
    step_duration = Column(REAL)  # Duration for this specific step in seconds

    # Timestamp fields (unified naming convention)
    created_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=get_current_timestamp(), onupdate=get_current_timestamp())

    # Relationships
    case_audit = relationship("AutoCaseAudit", back_populates="debug_logs")
