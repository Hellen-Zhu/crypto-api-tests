-- ============================================================
-- Migration: Add timestamp fields to audit tables
-- Date: 2025-10-15
-- Description: Add standardized created_at/updated_at fields
-- ============================================================

BEGIN;

-- 1. Update AutoProgress table
-- ------------------------------------------------------------
DO $$
BEGIN
    -- Add new timestamp columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='auto_progress' AND column_name='created_at') THEN
        ALTER TABLE auto_progress
            ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='auto_progress' AND column_name='updated_at') THEN
        ALTER TABLE auto_progress
            ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    -- Add unique constraint on runid if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'auto_progress_runid_unique') THEN
        ALTER TABLE auto_progress
            ADD CONSTRAINT auto_progress_runid_unique UNIQUE (runid);
    END IF;

    -- Set NOT NULL on runid if not already set
    ALTER TABLE auto_progress ALTER COLUMN runid SET NOT NULL;

    -- Add defaults for statistics columns
    ALTER TABLE auto_progress ALTER COLUMN total_cases SET DEFAULT 0;
    ALTER TABLE auto_progress ALTER COLUMN passes SET DEFAULT 0;
    ALTER TABLE auto_progress ALTER COLUMN failures SET DEFAULT 0;
    ALTER TABLE auto_progress ALTER COLUMN skips SET DEFAULT 0;

    -- Migrate data from old update_time to new updated_at
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name='auto_progress' AND column_name='update_time') THEN
        UPDATE auto_progress
        SET updated_at = update_time
        WHERE update_time IS NOT NULL AND updated_at IS NULL;

        -- Drop old column
        ALTER TABLE auto_progress DROP COLUMN update_time;
    END IF;
END $$;

-- Create trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_auto_progress_updated_at ON auto_progress;
DROP FUNCTION IF EXISTS update_auto_progress_updated_at();

CREATE OR REPLACE FUNCTION update_auto_progress_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_progress_updated_at
    BEFORE UPDATE ON auto_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_auto_progress_updated_at();


-- 2. Update AutoCaseAudit table
-- ------------------------------------------------------------
DO $$
BEGIN
    -- Rename existing column (fixing typo) if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name='auto_case_audit' AND column_name='update_at') THEN
        ALTER TABLE auto_case_audit RENAME COLUMN update_at TO updated_at;
    END IF;

    -- Add created_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='auto_case_audit' AND column_name='created_at') THEN
        ALTER TABLE auto_case_audit
            ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

        -- Use updated_at as initial value for existing records
        UPDATE auto_case_audit
        SET created_at = updated_at
        WHERE updated_at IS NOT NULL AND created_at IS NULL;
    END IF;
END $$;

-- Add indexes for query performance
CREATE INDEX IF NOT EXISTS idx_auto_case_audit_case_id ON auto_case_audit(case_id);
CREATE INDEX IF NOT EXISTS idx_auto_case_audit_issue_key ON auto_case_audit(issue_key);
CREATE INDEX IF NOT EXISTS idx_auto_case_audit_run_status ON auto_case_audit(run_status);

-- Create trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_auto_case_audit_updated_at ON auto_case_audit;
DROP FUNCTION IF EXISTS update_auto_case_audit_updated_at();

CREATE OR REPLACE FUNCTION update_auto_case_audit_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_case_audit_updated_at
    BEFORE UPDATE ON auto_case_audit
    FOR EACH ROW
    EXECUTE FUNCTION update_auto_case_audit_updated_at();


-- 3. Update AutoTestAudit table
-- ------------------------------------------------------------
DO $$
BEGIN
    -- Add new columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='auto_test_audit' AND column_name='created_at') THEN
        ALTER TABLE auto_test_audit
            ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='auto_test_audit' AND column_name='updated_at') THEN
        ALTER TABLE auto_test_audit
            ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='auto_test_audit' AND column_name='step_duration') THEN
        ALTER TABLE auto_test_audit
            ADD COLUMN step_duration REAL;
    END IF;
END $$;

-- Add index for query performance
CREATE INDEX IF NOT EXISTS idx_auto_test_audit_case_id ON auto_test_audit(audit_case_id);

-- Update foreign key constraint to include CASCADE delete
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (SELECT 1 FROM pg_constraint
               WHERE conname = 'auto_test_audit_audit_case_id_fkey') THEN
        ALTER TABLE auto_test_audit
            DROP CONSTRAINT auto_test_audit_audit_case_id_fkey;
    END IF;

    -- Add new constraint with CASCADE
    ALTER TABLE auto_test_audit
        ADD CONSTRAINT auto_test_audit_audit_case_id_fkey
            FOREIGN KEY (audit_case_id)
            REFERENCES auto_case_audit(id)
            ON DELETE CASCADE;
END $$;

-- Create trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_auto_test_audit_updated_at ON auto_test_audit;
DROP FUNCTION IF EXISTS update_auto_test_audit_updated_at();

CREATE OR REPLACE FUNCTION update_auto_test_audit_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_test_audit_updated_at
    BEFORE UPDATE ON auto_test_audit
    FOR EACH ROW
    EXECUTE FUNCTION update_auto_test_audit_updated_at();

COMMIT;

-- Print success message
DO $$
BEGIN
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'All three tables now have created_at and updated_at fields with auto-update triggers.';
END $$;
