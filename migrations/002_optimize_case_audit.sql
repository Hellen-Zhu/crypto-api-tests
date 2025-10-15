-- Migration: Optimize auto_case_audit table structure
-- Purpose: Remove redundant fields and implement layered storage strategy
-- Date: 2025-10-15
-- Description:
--   1. Remove 'scenario' field (redundant - can be queried from api_auto_cases)
--   2. Rename 'variables' to 'input_variables' (clearer semantics)
--   3. Enhanced auto_test_audit to always capture failed test details

-- =====================================================
-- STEP 1: Backup existing data (SAFETY FIRST)
-- =====================================================
-- Note: Run this manually before applying migration if needed
-- pg_dump -U postgres -d apitest -t auto_case_audit > backup_auto_case_audit_$(date +%Y%m%d_%H%M%S).sql

-- =====================================================
-- STEP 2: Schema Changes
-- =====================================================

-- 2.1: Rename 'variables' column to 'input_variables' (more descriptive)
ALTER TABLE auto_case_audit
RENAME COLUMN variables TO input_variables;

-- 2.2: Drop 'scenario' column (redundant - stored in api_auto_cases.name)
-- This column duplicates data that can be retrieved via case_id FK lookup
ALTER TABLE auto_case_audit
DROP COLUMN IF EXISTS scenario;

-- =====================================================
-- STEP 3: Add comments for documentation
-- =====================================================

COMMENT ON TABLE auto_case_audit IS
'Test case execution summary table (Layered Storage Design).
- Stores lightweight summary: status, duration, error message
- Input variables only (no request/response details)
- Detailed step logs stored in auto_test_audit
- Failed tests automatically get detailed logs even without debug mode';

COMMENT ON COLUMN auto_case_audit.input_variables IS
'Test input parameters (dataset variables).
Stores only the input parameters used to run the test.
Does NOT store request/response details (those are in auto_test_audit).';

COMMENT ON COLUMN auto_case_audit.case_id IS
'Foreign key to api_auto_cases.id.
Use JOIN to retrieve scenario name instead of duplicating data.';

COMMENT ON TABLE auto_test_audit IS
'Detailed step-by-step execution log (Layered Storage Design).
- Debug mode: ALL steps for ALL tests
- Normal mode: ALL steps for FAILED tests only (auto-diagnostic)
- Normal mode + Passed: No logs (saves database space)';

-- =====================================================
-- STEP 4: Verification Queries
-- =====================================================

-- 4.1: Verify column changes
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'auto_case_audit'
ORDER BY ordinal_position;

-- 4.2: Verify data integrity (should show renamed column)
SELECT
    id,
    runid,
    case_id,
    run_status,
    input_variables,  -- Renamed from 'variables'
    created_at
FROM auto_case_audit
ORDER BY created_at DESC
LIMIT 5;

-- =====================================================
-- STEP 5: Performance Impact Analysis
-- =====================================================

-- 5.1: Check table size before/after (scenario column was TEXT type)
SELECT
    pg_size_pretty(pg_total_relation_size('auto_case_audit')) as total_size,
    pg_size_pretty(pg_relation_size('auto_case_audit')) as table_size,
    pg_size_pretty(pg_total_relation_size('auto_case_audit') - pg_relation_size('auto_case_audit')) as indexes_size;

-- 5.2: Show current data distribution
SELECT
    run_status,
    COUNT(*) as count,
    AVG(duration) as avg_duration_seconds
FROM auto_case_audit
GROUP BY run_status;

-- =====================================================
-- ROLLBACK SCRIPT (if needed)
-- =====================================================
-- Uncomment and run if you need to rollback this migration

-- ALTER TABLE auto_case_audit RENAME COLUMN input_variables TO variables;
-- ALTER TABLE auto_case_audit ADD COLUMN scenario TEXT;

-- Note: You'll need to restore 'scenario' data from backup if rolled back
