-- ====================================================================
-- WebSocket Negative Tests - Error Handling & Edge Cases
-- ====================================================================
-- This file contains negative test cases for WebSocket functionality:
-- - Invalid channel subscriptions
-- - Malformed messages
-- - Invalid instrument names
-- - Connection timeout scenarios
-- - Unsubscribe to non-existent channels
-- ====================================================================

BEGIN;

-- ====================================================================
-- Test Case 1: Invalid Channel Subscription
-- ====================================================================

INSERT INTO api_auto_cases (
    name,
    description,
    service,
    module,
    component,
    tags,
    author,
    parameters
) VALUES (
    'WebSocket Invalid Channel Subscription',
    'Test WebSocket behavior with invalid channel names',
    'exchange_svc',
    'Market Data - WebSocket',
    'Error Handling',
    ARRAY['p2', 'websocket', 'negative'],
    'test_team',
    '{
      "steps": [
        {
          "step_order": 1,
          "description": "Connect to WebSocket server",
          "protocol": "websocket",
          "action": "connect",
          "url": "wss://uat-stream.3ona.co/exchange/v1/market",
          "timeout": 10
        },
        {
          "step_order": 2,
          "description": "Subscribe to invalid channel",
          "protocol": "websocket",
          "action": "send",
          "message": {
            "id": 1,
            "method": "subscribe",
            "params": {
              "channels": ["{{@invalid_channel}}"]
            },
            "nonce": 1587523073344
          }
        },
        {
          "step_order": 3,
          "description": "Wait for error response",
          "protocol": "websocket",
          "action": "wait",
          "message_count": 1,
          "timeout": 10,
          "validations": {
            "notNull": ["$.id", "$.method", "$.code"],
            "body": {
              "method": "subscribe"
            }
          }
        },
        {
          "step_order": 4,
          "description": "Disconnect WebSocket",
          "protocol": "websocket",
          "action": "disconnect"
        }
      ]
    }'::jsonb
);

-- Insert data sets for invalid channel test
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
SELECT
    ac.id,
    ds.data_set_name,
    ds.variables::jsonb,
    ds.validations_override::jsonb,
    ds.environments,
    ds.tags,
    ds.is_active
FROM api_auto_cases ac,
(VALUES
    -- Test 1.1: Completely invalid channel format
    (
        'Invalid channel - random string',
        '{"invalid_channel": "totally_invalid_channel_name"}',
        '{
          "3": {
            "notNull": ["$.code"],
            "body": {
              "method": "subscribe",
              "code": 10004
            }
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'invalid_channel'],
        true
    ),
    -- Test 1.2: Invalid channel type (wrong prefix)
    (
        'Invalid channel - wrong type',
        '{"invalid_channel": "invalid_type.BTCUSD-PERP"}',
        '{
          "3": {
            "notNull": ["$.code"],
            "body": {
              "method": "subscribe",
              "code": 10004
            }
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'invalid_channel'],
        true
    ),
    -- Test 1.3: Empty channel name
    (
        'Invalid channel - empty string',
        '{"invalid_channel": ""}',
        '{
          "3": {
            "notNull": ["$.code"],
            "body": {
              "method": "subscribe"
            }
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'edge_case'],
        true
    )
) AS ds(data_set_name, variables, validations_override, environments, tags, is_active)
WHERE ac.name = 'WebSocket Invalid Channel Subscription';

-- ====================================================================
-- Test Case 2: Invalid Instrument Subscription
-- ====================================================================

INSERT INTO api_auto_cases (
    name,
    description,
    service,
    module,
    component,
    tags,
    author,
    parameters
) VALUES (
    'WebSocket Invalid Instrument',
    'Test WebSocket behavior with non-existent instrument names',
    'exchange_svc',
    'Market Data - WebSocket',
    'Error Handling',
    ARRAY['p2', 'websocket', 'negative'],
    'test_team',
    '{
      "steps": [
        {
          "step_order": 1,
          "description": "Connect to WebSocket server",
          "protocol": "websocket",
          "action": "connect",
          "url": "wss://uat-stream.3ona.co/exchange/v1/market",
          "timeout": 10
        },
        {
          "step_order": 2,
          "description": "Subscribe to ticker with invalid instrument",
          "protocol": "websocket",
          "action": "send",
          "message": {
            "id": 2,
            "method": "subscribe",
            "params": {
              "channels": ["ticker.{{@instrument}}"]
            },
            "nonce": 1587523073344
          }
        },
        {
          "step_order": 3,
          "description": "Wait for error or subscription response",
          "protocol": "websocket",
          "action": "wait",
          "message_count": 1,
          "timeout": 10,
          "validations": {
            "notNull": ["$.id", "$.method", "$.code"]
          }
        },
        {
          "step_order": 4,
          "description": "Disconnect WebSocket",
          "protocol": "websocket",
          "action": "disconnect"
        }
      ]
    }'::jsonb
);

-- Insert data sets for invalid instrument test
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
SELECT
    ac.id,
    ds.data_set_name,
    ds.variables::jsonb,
    ds.validations_override::jsonb,
    ds.environments,
    ds.tags,
    ds.is_active
FROM api_auto_cases ac,
(VALUES
    -- Test 2.1: Non-existent instrument
    (
        'Invalid instrument - does not exist',
        '{"instrument": "FAKECOIN-PERP"}',
        '{
          "3": {
            "notNull": ["$.code"],
            "body": {
              "method": "subscribe",
              "code": 10004
            }
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'invalid_instrument'],
        true
    ),
    -- Test 2.2: Malformed instrument name (missing -PERP)
    (
        'Invalid instrument - missing suffix',
        '{"instrument": "BTCUSD"}',
        '{
          "3": {
            "notNull": ["$.code"],
            "body": {
              "method": "subscribe",
              "code": 10004
            }
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'invalid_instrument'],
        true
    ),
    -- Test 2.3: Lowercase instrument (case-sensitive)
    (
        'Invalid instrument - lowercase',
        '{"instrument": "btcusd-perp"}',
        '{
          "3": {
            "notNull": ["$.code"],
            "body": {
              "method": "subscribe",
              "code": 10004
            }
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'case_sensitive'],
        true
    ),
    -- Test 2.4: Special characters in instrument
    (
        'Invalid instrument - special characters',
        '{"instrument": "BTC@USD-PERP"}',
        '{
          "3": {
            "notNull": ["$.code"],
            "body": {
              "method": "subscribe"
            }
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'edge_case'],
        true
    )
) AS ds(data_set_name, variables, validations_override, environments, tags, is_active)
WHERE ac.name = 'WebSocket Invalid Instrument';

-- ====================================================================
-- Test Case 3: Malformed Subscription Message
-- ====================================================================

INSERT INTO api_auto_cases (
    name,
    description,
    service,
    module,
    component,
    tags,
    author,
    parameters
) VALUES (
    'WebSocket Malformed Message',
    'Test WebSocket behavior with malformed subscription messages',
    'exchange_svc',
    'Market Data - WebSocket',
    'Error Handling',
    ARRAY['p2', 'websocket', 'negative'],
    'test_team',
    '{
      "steps": [
        {
          "step_order": 1,
          "description": "Connect to WebSocket server",
          "protocol": "websocket",
          "action": "connect",
          "url": "wss://uat-stream.3ona.co/exchange/v1/market",
          "timeout": 10
        },
        {
          "step_order": 2,
          "description": "Send malformed subscription message",
          "protocol": "websocket",
          "action": "send",
          "message": "{{@malformed_message}}"
        },
        {
          "step_order": 3,
          "description": "Wait for error response",
          "protocol": "websocket",
          "action": "wait",
          "message_count": 1,
          "timeout": 10,
          "validations": {
            "notNull": ["$.code"]
          }
        },
        {
          "step_order": 4,
          "description": "Disconnect WebSocket",
          "protocol": "websocket",
          "action": "disconnect"
        }
      ]
    }'::jsonb
);

-- Insert data sets for malformed message test
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
SELECT
    ac.id,
    ds.data_set_name,
    ds.variables::jsonb,
    ds.validations_override::jsonb,
    ds.environments,
    ds.tags,
    ds.is_active
FROM api_auto_cases ac,
(VALUES
    -- Test 3.1: Missing required field (method)
    (
        'Malformed - missing method field',
        '{
          "malformed_message": {
            "id": 3,
            "params": {
              "channels": ["ticker.BTCUSD-PERP"]
            }
          }
        }',
        '{
          "3": {
            "notNull": ["$.code"]
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'malformed'],
        true
    ),
    -- Test 3.2: Missing params field
    (
        'Malformed - missing params field',
        '{
          "malformed_message": {
            "id": 4,
            "method": "subscribe"
          }
        }',
        '{
          "3": {
            "notNull": ["$.code"]
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'malformed'],
        true
    ),
    -- Test 3.3: Invalid method name
    (
        'Malformed - invalid method name',
        '{
          "malformed_message": {
            "id": 5,
            "method": "invalid_method",
            "params": {
              "channels": ["ticker.BTCUSD-PERP"]
            }
          }
        }',
        '{
          "3": {
            "notNull": ["$.code"]
          }
        }',
        ARRAY['exchange_uat'],
        ARRAY['negative', 'invalid_method'],
        true
    )
) AS ds(data_set_name, variables, validations_override, environments, tags, is_active)
WHERE ac.name = 'WebSocket Malformed Message';

-- ====================================================================
-- Test Case 4: Connection Timeout Test (Optional - May Need Manual Setup)
-- ====================================================================
-- Note: This test requires a non-responsive WebSocket server for proper testing
-- It's marked as inactive by default and should be enabled manually when needed

INSERT INTO api_auto_cases (
    name,
    description,
    service,
    module,
    component,
    tags,
    author,
    parameters
) VALUES (
    'WebSocket Connection Timeout',
    'Test WebSocket connection timeout handling (requires unreachable server)',
    'exchange_svc',
    'Market Data - WebSocket',
    'Connection Management',
    ARRAY['p3', 'websocket', 'negative', 'timeout'],
    'test_team',
    '{
      "steps": [
        {
          "step_order": 1,
          "description": "Attempt to connect to unreachable WebSocket server",
          "protocol": "websocket",
          "action": "connect",
          "url": "{{@ws_url}}",
          "timeout": 5
        }
      ]
    }'::jsonb
);

-- Insert data sets for connection timeout test (inactive by default)
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
SELECT
    ac.id,
    ds.data_set_name,
    ds.variables::jsonb,
    ds.validations_override::jsonb,
    ds.environments,
    ds.tags,
    ds.is_active
FROM api_auto_cases ac,
(VALUES
    -- Test 4.1: Invalid hostname
    (
        'Connection timeout - invalid hostname',
        '{"ws_url": "wss://non-existent-domain-12345.com/ws"}',
        null,
        ARRAY['exchange_uat'],
        ARRAY['negative', 'timeout', 'manual'],
        false  -- Inactive by default
    ),
    -- Test 4.2: Invalid port
    (
        'Connection timeout - invalid port',
        '{"ws_url": "wss://uat-stream.3ona.co:9999/exchange/v1/market"}',
        null,
        ARRAY['exchange_uat'],
        ARRAY['negative', 'timeout', 'manual'],
        false  -- Inactive by default
    )
) AS ds(data_set_name, variables, validations_override, environments, tags, is_active)
WHERE ac.name = 'WebSocket Connection Timeout';

-- ====================================================================
-- Verification Query
-- ====================================================================

SELECT
    ac.id AS case_id,
    ac.name AS case_name,
    ac.tags AS case_tags,
    COUNT(cds.id) AS total_datasets,
    COUNT(cds.id) FILTER (WHERE cds.is_active = true) AS active_datasets,
    COUNT(cds.id) FILTER (WHERE cds.is_active = false) AS inactive_datasets
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
WHERE ac.name IN (
    'WebSocket Invalid Channel Subscription',
    'WebSocket Invalid Instrument',
    'WebSocket Malformed Message',
    'WebSocket Connection Timeout'
)
GROUP BY ac.id, ac.name, ac.tags
ORDER BY ac.id;

COMMIT;

-- ====================================================================
-- How to Execute These Tests
-- ====================================================================

-- 1. Run all negative WebSocket tests:
-- python run.py --env exchange_uat --tags negative,websocket

-- 2. Run specific error type tests:
-- python run.py --env exchange_uat --tags invalid_channel
-- python run.py --env exchange_uat --tags invalid_instrument
-- python run.py --env exchange_uat --tags malformed

-- 3. Run by specific test case ID:
-- SELECT id, name FROM api_auto_cases WHERE tags @> ARRAY['websocket', 'negative'];
-- python run.py --env exchange_uat --id <case_id>

-- 4. Enable timeout tests (manually when needed):
-- UPDATE case_data_sets SET is_active = true
-- WHERE case_id IN (SELECT id FROM api_auto_cases WHERE ac.name = 'WebSocket Connection Timeout');

-- ====================================================================
-- Expected Error Codes (from Exchange API)
-- ====================================================================

-- 10004: Invalid channel/instrument name
-- 10001: Missing required parameter
-- 10002: Invalid parameter value
-- 10003: Invalid method name
-- Other codes: Refer to API documentation

-- ====================================================================
-- Test Coverage Summary
-- ====================================================================

-- ✅ Invalid Channel Tests (3 datasets):
--    - Random invalid channel name
--    - Wrong channel type prefix
--    - Empty channel string
--
-- ✅ Invalid Instrument Tests (4 datasets):
--    - Non-existent instrument (FAKECOIN-PERP)
--    - Malformed instrument (missing -PERP suffix)
--    - Case-sensitive test (lowercase)
--    - Special characters in instrument name
--
-- ✅ Malformed Message Tests (3 datasets):
--    - Missing 'method' field
--    - Missing 'params' field
--    - Invalid method name
--
-- ⚠️ Connection Timeout Tests (2 datasets - inactive):
--    - Invalid hostname (requires DNS failure)
--    - Invalid port (requires connection timeout)
--    Note: These tests are disabled by default as they require
--    network-level failures to properly test timeout handling

-- ====================================================================
-- Total Active Negative Tests: 10
-- Total Inactive Tests: 2 (timeout tests)
-- ====================================================================
