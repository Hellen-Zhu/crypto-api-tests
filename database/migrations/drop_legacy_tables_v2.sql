-- ====================================================================
-- Drop Legacy Tables (4-Table Design Cleanup)
-- ====================================================================
-- This migration removes the legacy api_actions and shared_actions tables
-- that were part of the 4-table design. All test cases have been migrated
-- to the 2-table design using the parameters JSONB column.
--
-- Migration Date: 2025-10-13
-- Safe to execute: Yes (all test cases migrated to 2-table design)
-- Reversible: No (unless you have a backup)
-- ====================================================================

BEGIN;

-- ====================================================================
-- Step 1: Verify Migration Status
-- ====================================================================

DO $$
DECLARE
    legacy_count INTEGER;
    total_count INTEGER;
BEGIN
    -- Count test cases using 4-table design (no parameters)
    SELECT COUNT(*) INTO legacy_count
    FROM api_auto_cases
    WHERE parameters IS NULL OR parameters = 'null'::jsonb;

    -- Count total test cases
    SELECT COUNT(*) INTO total_count
    FROM api_auto_cases;

    -- Output migration status
    RAISE NOTICE 'Migration Status Check:';
    RAISE NOTICE '  Total test cases: %', total_count;
    RAISE NOTICE '  Legacy cases (4-table): %', legacy_count;
    RAISE NOTICE '  Migrated cases (2-table): %', total_count - legacy_count;

    IF legacy_count > 0 THEN
        RAISE WARNING 'Found % test cases still using 4-table design!', legacy_count;
        RAISE WARNING 'Please migrate them before proceeding.';
        RAISE EXCEPTION 'Migration incomplete - aborting table drop';
    ELSE
        RAISE NOTICE '✅ All test cases migrated to 2-table design';
    END IF;
END $$;


-- ====================================================================
-- Step 2: Backup Data (Optional - for audit trail)
-- ====================================================================

DO $$
DECLARE
    actions_count INTEGER;
    shared_count INTEGER;
BEGIN
    -- Create backup tables with timestamp
    EXECUTE 'CREATE TABLE IF NOT EXISTS api_actions_backup_20251013 AS SELECT * FROM api_actions';
    EXECUTE 'CREATE TABLE IF NOT EXISTS shared_actions_backup_20251013 AS SELECT * FROM shared_actions';

    -- Count backup rows
    SELECT COUNT(*) INTO actions_count FROM api_actions_backup_20251013;
    SELECT COUNT(*) INTO shared_count FROM shared_actions_backup_20251013;

    RAISE NOTICE 'Backup Tables Created:';
    RAISE NOTICE '  api_actions_backup_20251013: % rows', actions_count;
    RAISE NOTICE '  shared_actions_backup_20251013: % rows', shared_count;
END $$;


-- ====================================================================
-- Step 3: Drop Foreign Key Constraints & Tables
-- ====================================================================

DO $$
BEGIN
    -- Drop foreign key from api_actions to shared_actions
    ALTER TABLE api_actions DROP CONSTRAINT IF EXISTS api_actions_shared_action_ref_fkey;
    RAISE NOTICE '✅ Dropped foreign key constraint: api_actions_shared_action_ref_fkey';

    -- Drop foreign key from api_actions to api_auto_cases
    ALTER TABLE api_actions DROP CONSTRAINT IF EXISTS api_actions_case_id_fkey;
    RAISE NOTICE '✅ Dropped foreign key constraint: api_actions_case_id_fkey';

    -- Drop api_actions table first (has FK to shared_actions)
    DROP TABLE IF EXISTS api_actions CASCADE;
    RAISE NOTICE '✅ Dropped table: api_actions';

    -- Drop shared_actions table
    DROP TABLE IF EXISTS shared_actions CASCADE;
    RAISE NOTICE '✅ Dropped table: shared_actions';

    -- Drop auto-increment sequences
    DROP SEQUENCE IF EXISTS api_actions_id_seq CASCADE;
    RAISE NOTICE '✅ Dropped sequence: api_actions_id_seq';

    DROP SEQUENCE IF EXISTS shared_actions_id_seq CASCADE;
    RAISE NOTICE '✅ Dropped sequence: shared_actions_id_seq';
END $$;


-- ====================================================================
-- Step 4: Final Summary
-- ====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================================';
    RAISE NOTICE 'Migration Complete!';
    RAISE NOTICE '====================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Dropped Tables:';
    RAISE NOTICE '  ❌ api_actions (legacy 4-table design)';
    RAISE NOTICE '  ❌ shared_actions (legacy 4-table design)';
    RAISE NOTICE '';
    RAISE NOTICE 'Backup Tables (for audit trail):';
    RAISE NOTICE '  📦 api_actions_backup_20251013';
    RAISE NOTICE '  📦 shared_actions_backup_20251013';
    RAISE NOTICE '';
    RAISE NOTICE 'Current Design:';
    RAISE NOTICE '  ✅ 2-table design (api_auto_cases.parameters JSONB)';
    RAISE NOTICE '';
    RAISE NOTICE 'All test cases continue to work without changes!';
    RAISE NOTICE '====================================================================';
END $$;

COMMIT;

-- ====================================================================
-- Verification Query - List All Tables
-- ====================================================================

SELECT
    tablename,
    CASE
        WHEN tablename LIKE '%backup%' THEN '📦 Backup'
        WHEN tablename IN ('api_auto_cases', 'case_data_sets', 'test_environments') THEN '✅ Active (2-table)'
        WHEN tablename LIKE 'auto_%' THEN '📊 Test Results'
        ELSE '📊 Other'
    END as status,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
AND (
    tablename LIKE 'api_%'
    OR tablename LIKE 'shared_%'
    OR tablename LIKE 'case_%'
    OR tablename LIKE 'test_%'
    OR tablename LIKE 'auto_%'
)
ORDER BY
    CASE
        WHEN tablename LIKE '%backup%' THEN 3
        WHEN tablename IN ('api_auto_cases', 'case_data_sets') THEN 1
        ELSE 2
    END,
    tablename;


-- ====================================================================
-- Cleanup Backup Tables (Optional - Uncomment to Remove Backups)
-- ====================================================================
--
-- If you're confident and want to remove the backup tables:
--
-- BEGIN;
-- DROP TABLE IF EXISTS api_actions_backup_20251013;
-- DROP TABLE IF EXISTS shared_actions_backup_20251013;
-- RAISE NOTICE 'Backup tables removed';
-- COMMIT;
--
-- ====================================================================
