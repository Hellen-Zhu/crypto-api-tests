-- =====================================================================
-- Crypto API Test Framework - Database Schema
-- =====================================================================
-- Description: PostgreSQL database schema for configuration-driven API testing framework
-- Author: Hellen Zhu
-- Database: PostgreSQL 14+
-- Features: JSONB for flexible test configuration, ARRAY for tags/environments
-- =====================================================================

-- Set timezone to Asia/Shanghai for all timestamp operations
SET timezone = 'Asia/Shanghai';

-- =====================================================================
-- 1. TEST CASE DEFINITION TABLES
-- =====================================================================

-- Table: api_auto_cases
-- Description: Unified test case definition table (single-table design)
--              Each row represents a complete, independent test case
--              Supports both HTTP and WebSocket protocols via test_config JSONB column
CREATE TABLE IF NOT EXISTS api_auto_cases (
    -- Primary key
    id SERIAL PRIMARY KEY,

    -- Basic information
    name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Classification fields (for filtering and organization)
    service VARCHAR(100) NOT NULL,  -- Service name: exchange_svc, websocket_svc, user_svc, etc.
    module VARCHAR(100),             -- Module name: market_data, authentication, trading, etc.
    component VARCHAR(100),          -- Component name: candlestick, ticker, websocket, etc.
    tags TEXT[],                     -- Tags array: ['P0', 'smoke', 'regression'], etc.

    -- Environment targeting
    environments TEXT[],             -- Target environments: ['dev', 'uat', 'prod'], NULL = all environments

    -- External references
    jira_id VARCHAR(50) UNIQUE,     -- Associated Jira ticket ID
    author VARCHAR(50),              -- Test case author

    -- Core test configuration (consolidated in JSONB)
    -- Structure: {
    --   "variables": {...},         -- Test variables (data-driven)
    --   "steps": [...],             -- Test steps (HTTP/WebSocket actions)
    --   "validations": {...}        -- Global validations
    -- }
    test_config JSONB NOT NULL,

    -- Status and metadata
    enable BOOLEAN DEFAULT TRUE,     -- Is test case enabled?
    created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai'),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai')
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_api_auto_cases_service ON api_auto_cases(service);
CREATE INDEX IF NOT EXISTS idx_api_auto_cases_module ON api_auto_cases(module);
CREATE INDEX IF NOT EXISTS idx_api_auto_cases_component ON api_auto_cases(component);
CREATE INDEX IF NOT EXISTS idx_api_auto_cases_tags ON api_auto_cases USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_api_auto_cases_environments ON api_auto_cases USING GIN(environments);
CREATE INDEX IF NOT EXISTS idx_api_auto_cases_jira_id ON api_auto_cases(jira_id);

-- Comment for documentation
COMMENT ON TABLE api_auto_cases IS 'Unified test case definition table supporting HTTP and WebSocket protocols';
COMMENT ON COLUMN api_auto_cases.test_config IS 'JSONB column storing test steps, variables, and validations';
COMMENT ON COLUMN api_auto_cases.tags IS 'Array of tags for filtering (e.g., P0, smoke, regression)';
COMMENT ON COLUMN api_auto_cases.environments IS 'Array of target environments, NULL means all environments';

-- =====================================================================
-- 2. TEST CONFIGURATION TABLES
-- =====================================================================

-- Table: test_environments
-- Description: Test environment configuration table
--              Each row represents a specific service in a specific environment
--              Supports multiple services per environment (e.g., dev can have user_svc, exchange_svc, websocket_svc)
CREATE TABLE IF NOT EXISTS test_environments (
    -- Primary key
    id SERIAL PRIMARY KEY,

    -- Environment identification
    name VARCHAR(50) NOT NULL,      -- Environment name: dev, uat, prod, etc.
    service VARCHAR(50) NOT NULL,   -- Service name: user_svc, exchange_svc, websocket_svc, etc.

    -- Service configuration
    base_url VARCHAR(255) NOT NULL, -- Service-specific base URL (HTTP) or full WebSocket URL
    description TEXT,                -- Optional description
    is_active BOOLEAN DEFAULT TRUE   -- Is this environment configuration active?
);

-- Create composite unique constraint on (name, service)
CREATE UNIQUE INDEX IF NOT EXISTS idx_test_environments_name_service ON test_environments(name, service);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_test_environments_name ON test_environments(name);
CREATE INDEX IF NOT EXISTS idx_test_environments_service ON test_environments(service);

-- Comment for documentation
COMMENT ON TABLE test_environments IS 'Environment configuration table supporting multiple services per environment';
COMMENT ON COLUMN test_environments.base_url IS 'Base URL for HTTP services or full WebSocket URL';

-- =====================================================================
-- 3. TEST RESULT TABLES
-- =====================================================================

-- Table: auto_progress
-- Description: Test run summary information table
--              Each row represents one test execution session with aggregated statistics
CREATE TABLE IF NOT EXISTS auto_progress (
    -- Primary key
    id SERIAL PRIMARY KEY,

    -- Run identification
    runid VARCHAR(50) UNIQUE NOT NULL, -- Unique run ID (UUID format)
    version_id VARCHAR(35),             -- Version or build ID
    component VARCHAR(50),              -- Component being tested

    -- Statistics
    total_cases INTEGER DEFAULT 0,      -- Total number of test cases
    passes INTEGER DEFAULT 0,           -- Number of passed tests
    failures INTEGER DEFAULT 0,         -- Number of failed tests
    skips INTEGER DEFAULT 0,            -- Number of skipped tests

    -- Timing
    begin_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,

    -- Additional metadata
    releaseversion VARCHAR(200),        -- Release version
    task_status VARCHAR(25),            -- Task status: running, completed, failed
    run_by VARCHAR(50),                 -- User who triggered the run
    label VARCHAR(1000),                -- Labels or tags for the run
    runmode VARCHAR(255),               -- Run mode: local, ci, scheduled, etc.
    profile VARCHAR(200),               -- Test profile: smoke, regression, full, etc.

    -- Timestamp fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai'),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai')
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_auto_progress_runid ON auto_progress(runid);
CREATE INDEX IF NOT EXISTS idx_auto_progress_task_status ON auto_progress(task_status);

-- Comment for documentation
COMMENT ON TABLE auto_progress IS 'Test run summary table with aggregated statistics';
COMMENT ON COLUMN auto_progress.runid IS 'Unique identifier for each test run session';

-- Table: auto_case_audit
-- Description: Test case execution summary table
--              Each row represents one test case execution with its result and basic context
--              Lightweight storage (summary only, detailed logs in auto_test_audit)
CREATE TABLE IF NOT EXISTS auto_case_audit (
    -- Primary key
    id SERIAL PRIMARY KEY,

    -- Run and case identification
    runid VARCHAR(50) NOT NULL,     -- Foreign key to auto_progress.runid
    case_id INTEGER,                 -- Foreign key to api_auto_cases.id
    issue_key VARCHAR(50),           -- Jira issue key (for quick reference)

    -- Execution result
    run_status VARCHAR(20),          -- Status: passed, failed, skipped
    duration REAL,                   -- Execution duration in seconds
    error_message TEXT,              -- Error message if failed

    -- Lightweight execution context
    -- Stores only test input variables, not full request/response
    input_variables JSONB,

    -- Timestamp fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai'),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai')
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_auto_case_audit_runid ON auto_case_audit(runid);
CREATE INDEX IF NOT EXISTS idx_auto_case_audit_case_id ON auto_case_audit(case_id);
CREATE INDEX IF NOT EXISTS idx_auto_case_audit_issue_key ON auto_case_audit(issue_key);
CREATE INDEX IF NOT EXISTS idx_auto_case_audit_run_status ON auto_case_audit(run_status);

-- Comment for documentation
COMMENT ON TABLE auto_case_audit IS 'Test case execution summary table (lightweight)';
COMMENT ON COLUMN auto_case_audit.input_variables IS 'JSONB storing test input variables only';

-- Table: auto_test_audit
-- Description: Detailed step-by-step interaction log table for debug mode
--              Each row represents one API request/response step within a test case
--              Only populated when debug logging is enabled
CREATE TABLE IF NOT EXISTS auto_test_audit (
    -- Primary key
    id SERIAL PRIMARY KEY,

    -- Foreign key to auto_case_audit
    audit_case_id INTEGER NOT NULL,  -- Foreign key to auto_case_audit.id

    -- Step information
    step_order INTEGER,              -- Step sequence number
    action_description TEXT,         -- Description of the action

    -- Request/Response details (stored as JSONB)
    request_details JSONB,           -- Full request details (method, URL, headers, body)
    response_details JSONB,          -- Full response details (status, headers, body)

    -- Step result
    step_status VARCHAR(20),         -- Status: passed, failed, skipped
    step_duration REAL,              -- Duration for this specific step in seconds

    -- Timestamp fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai'),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai'),

    -- Foreign key constraint with cascade delete
    CONSTRAINT fk_auto_test_audit_case_id
        FOREIGN KEY (audit_case_id)
        REFERENCES auto_case_audit(id)
        ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_auto_test_audit_audit_case_id ON auto_test_audit(audit_case_id);
CREATE INDEX IF NOT EXISTS idx_auto_test_audit_step_order ON auto_test_audit(step_order);

-- Comment for documentation
COMMENT ON TABLE auto_test_audit IS 'Detailed step-by-step log table for debug mode';
COMMENT ON COLUMN auto_test_audit.request_details IS 'JSONB storing full request details';
COMMENT ON COLUMN auto_test_audit.response_details IS 'JSONB storing full response details';

-- =====================================================================
-- TRIGGERS FOR AUTOMATIC TIMESTAMP UPDATES
-- =====================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW() AT TIME ZONE 'Asia/Shanghai';
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to api_auto_cases
DROP TRIGGER IF EXISTS update_api_auto_cases_updated_at ON api_auto_cases;
CREATE TRIGGER update_api_auto_cases_updated_at
    BEFORE UPDATE ON api_auto_cases
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to auto_progress
DROP TRIGGER IF EXISTS update_auto_progress_updated_at ON auto_progress;
CREATE TRIGGER update_auto_progress_updated_at
    BEFORE UPDATE ON auto_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to auto_case_audit
DROP TRIGGER IF EXISTS update_auto_case_audit_updated_at ON auto_case_audit;
CREATE TRIGGER update_auto_case_audit_updated_at
    BEFORE UPDATE ON auto_case_audit
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to auto_test_audit
DROP TRIGGER IF EXISTS update_auto_test_audit_updated_at ON auto_test_audit;
CREATE TRIGGER update_auto_test_audit_updated_at
    BEFORE UPDATE ON auto_test_audit
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================================
-- END OF SCHEMA
-- =====================================================================

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE 'Schema created successfully! Tables: api_auto_cases, test_environments, auto_progress, auto_case_audit, auto_test_audit';
END $$;
