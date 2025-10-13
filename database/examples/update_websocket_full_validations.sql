-- ====================================================================
-- Update WebSocket Negative Test Validation Rules (Full Field Validation)
-- ====================================================================
-- This script updates validation rules to verify ALL fields in WebSocket
-- error responses, making maintenance simpler and validation more precise.
--
-- Based on actual API responses collected on 2025-10-13
-- ====================================================================

BEGIN;

-- ====================================================================
-- 1. Invalid Channel Subscription Tests
-- ====================================================================

-- Dataset 27: Invalid channel - random string
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "channel": "totally_invalid_channel_name", "message": "Unrecognized channel"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "channel": "{{@invalid_channel}}",
      "message": "Unrecognized channel"
    }
  }
}'::jsonb
WHERE id = 27 AND data_set_name = 'Invalid channel - random string';

-- Dataset 28: Invalid channel - wrong type
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "channel": "invalid_type.BTCUSD-PERP", "message": "Unrecognized channel"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "channel": "{{@invalid_channel}}",
      "message": "Unrecognized channel"
    }
  }
}'::jsonb
WHERE id = 28 AND data_set_name = 'Invalid channel - wrong type';

-- Dataset 29: Invalid channel - empty string
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "message": "Channels param empty"}
-- Note: No "channel" field in response for empty string
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "message": "Channels param empty"
    }
  }
}'::jsonb
WHERE id = 29 AND data_set_name = 'Invalid channel - empty string';


-- ====================================================================
-- 2. Invalid Instrument Tests
-- ====================================================================

-- Dataset 30: Invalid instrument - does not exist
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "channel": "ticker.FAKECOIN-PERP", "message": "Unknown symbol"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "channel": "ticker.{{@instrument}}",
      "message": "Unknown symbol"
    }
  }
}'::jsonb
WHERE id = 30 AND data_set_name = 'Invalid instrument - does not exist';

-- Dataset 31: Invalid instrument - missing suffix
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "channel": "ticker.BTCUSD", "message": "Unknown symbol"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "channel": "ticker.{{@instrument}}",
      "message": "Unknown symbol"
    }
  }
}'::jsonb
WHERE id = 31 AND data_set_name = 'Invalid instrument - missing suffix';

-- Dataset 32: Invalid instrument - lowercase
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "channel": "ticker.btcusd-perp", "message": "Unknown symbol"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "channel": "ticker.{{@instrument}}",
      "message": "Unknown symbol"
    }
  }
}'::jsonb
WHERE id = 32 AND data_set_name = 'Invalid instrument - lowercase';

-- Dataset 33: Invalid instrument - special characters
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "channel": "ticker.BTC@USD-PERP", "message": "Unknown symbol"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "channel": "ticker.{{@instrument}}",
      "message": "Unknown symbol"
    }
  }
}'::jsonb
WHERE id = 33 AND data_set_name = 'Invalid instrument - special characters';


-- ====================================================================
-- 3. Malformed Message Tests
-- ====================================================================

-- Dataset 34: Malformed - missing method field
-- Response: {"id": 1, "method": "", "code": 40003, "message": "No such method"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "",
      "code": 40003,
      "message": "No such method"
    }
  }
}'::jsonb
WHERE id = 34 AND data_set_name = 'Malformed - missing method field';

-- Dataset 35: Malformed - missing params field
-- Response: {"id": 1, "method": "subscribe", "code": 40003, "message": "Channels param empty"}
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "subscribe",
      "code": 40003,
      "message": "Channels param empty"
    }
  }
}'::jsonb
WHERE id = 35 AND data_set_name = 'Malformed - missing params field';

-- Dataset 36: Malformed - invalid method name
-- Response: {"id": 1, "method": "invalid_method", "code": 40003, "message": "No such method"}
-- The malformed_message variable contains: {"id": 5, "method": "invalid_method", ...}
-- So method is "invalid_method"
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "id": 1,
      "method": "invalid_method",
      "code": 40003,
      "message": "No such method"
    }
  }
}'::jsonb
WHERE id = 36 AND data_set_name = 'Malformed - invalid method name';


-- ====================================================================
-- Verification Query - Show Updated Validations
-- ====================================================================

SELECT
    ds.id,
    c.name as test_case,
    ds.data_set_name,
    ds.validations_override->'3'->'body' as step3_full_validation
FROM case_data_sets ds
JOIN api_auto_cases c ON c.id = ds.case_id
WHERE ds.id BETWEEN 27 AND 36
ORDER BY ds.id;

COMMIT;

-- ====================================================================
-- Notes:
-- ====================================================================
-- 1. All responses have 4 base fields: id, method, code, message
-- 2. Some responses have additional "channel" field (when channel is invalid but recognizable)
-- 3. Using placeholders like {{@invalid_channel}} for dynamic validation
-- 4. Empty method ("") for missing method field scenario
-- 5. This validates ALL fields, making it easier to maintain and understand
-- ====================================================================
