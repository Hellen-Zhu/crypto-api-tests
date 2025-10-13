-- ====================================================================
-- Update WebSocket Negative Test Validation Rules
-- ====================================================================
-- This script updates validation rules for WebSocket negative tests
-- to use precise body matching instead of just checking if code exists.
--
-- Changes:
-- - Remove simple "notNull": ["$.code"] validation
-- - Add precise "body" validation with expected error codes and messages
-- ====================================================================

BEGIN;

-- ====================================================================
-- 1. Invalid Channel Subscription Tests (code: 40003)
-- ====================================================================

-- Test Case 19: WebSocket Invalid Channel Subscription
-- DataSets: 27, 28, 29
-- Expected: code=40003, method="subscribe", error message about invalid channel

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003,
      "message": "Unrecognized channel"
    }
  }
}'::jsonb
WHERE id = 27 AND data_set_name = 'Invalid channel - random string';

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003,
      "message": "Unrecognized channel"
    }
  }
}'::jsonb
WHERE id = 28 AND data_set_name = 'Invalid channel - wrong type';

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 29 AND data_set_name = 'Invalid channel - empty string';


-- ====================================================================
-- 2. Invalid Instrument Tests (code: 40003)
-- ====================================================================

-- Test Case 20: WebSocket Invalid Instrument
-- DataSets: 30, 31, 32, 33
-- Expected: code=40003, method="subscribe"

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 30 AND data_set_name = 'Invalid instrument - does not exist';

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 31 AND data_set_name = 'Invalid instrument - missing suffix';

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 32 AND data_set_name = 'Invalid instrument - lowercase';

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 33 AND data_set_name = 'Invalid instrument - special characters';


-- ====================================================================
-- 3. Malformed Message Tests
-- ====================================================================

-- Test Case 21: WebSocket Malformed Message
-- DataSets: 34, 35, 36
-- Expected: Error code (might vary based on malformed type)

-- For malformed messages, the response structure might be different
-- We validate that an error code exists and is non-zero

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 34 AND data_set_name = 'Malformed - missing method field';

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 35 AND data_set_name = 'Malformed - missing params field';

UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "code": 40003
    }
  }
}'::jsonb
WHERE id = 36 AND data_set_name = 'Malformed - invalid method name';


-- ====================================================================
-- Verification Query
-- ====================================================================

-- Check updated validation rules
SELECT
    ds.id,
    c.name as test_case,
    ds.data_set_name,
    ds.validations_override->'3'->'body' as step3_body_validation
FROM case_data_sets ds
JOIN api_auto_cases c ON c.id = ds.case_id
WHERE ds.id BETWEEN 27 AND 36
ORDER BY ds.id;

COMMIT;

-- ====================================================================
-- Usage:
-- ====================================================================
-- Execute this script to update WebSocket negative test validations:
--
-- PGPASSWORD=postgres psql -h localhost -p 5435 -U postgres -d apitest \
--   -f database/examples/update_websocket_validations.sql
--
-- Then re-run tests to verify:
-- python run.py --env exchange_uat --tags websocket,negative
-- ====================================================================
