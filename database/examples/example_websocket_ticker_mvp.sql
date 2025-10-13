-- ====================================================================
-- WebSocket Ticker Subscription Test (MVP)
-- ====================================================================
-- This demonstrates the WebSocket MVP implementation for ticker data
-- subscription and real-time data validation.
--
-- Test Flow:
--   Step 1: Connect to WebSocket server
--   Step 2: Send subscription message
--   Step 3: Wait for messages and validate ticker data
--   Step 4: Disconnect WebSocket
-- ====================================================================

BEGIN;

-- Create WebSocket ticker test case
WITH new_case AS (
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
        'WebSocket Ticker Subscription',
        'Subscribe to ticker data via WebSocket and validate real-time updates (MVP)',
        'exchange_svc',
        'Market Data - WebSocket',
        'Ticker WebSocket API',
        ARRAY['p1', 'websocket', 'ticker', 'mvp'],
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
              "description": "Subscribe to ticker channel",
              "protocol": "websocket",
              "action": "send",
              "message": {
                "id": 1,
                "method": "subscribe",
                "params": {
                  "channels": ["ticker.{{@instrument}}"]
                },
                "nonce": 1587523073344
              }
            },
            {
              "step_order": 3,
              "description": "Wait for and validate ticker data",
              "protocol": "websocket",
              "action": "wait",
              "message_count": 2,
              "timeout": 30,
              "validations": {
                "notNull": [
                  "$.id",
                  "$.method",
                  "$.code",
                  "$.result",
                  "$.result.instrument_name",
                  "$.result.data[0].a",
                  "$.result.data[0].h",
                  "$.result.data[0].l"
                ],
                "body": {
                  "method": "subscribe",
                  "code": 0,
                  "result": {
                    "instrument_name": "{{@instrument}}",
                    "channel": "ticker"
                  }
                }
              },
              "outputs": [
                {
                  "variable_name": "latest_price",
                  "source": "response_body",
                  "json_path": "result.data[0].a"
                },
                {
                  "variable_name": "high_price",
                  "source": "response_body",
                  "json_path": "result.data[0].h"
                },
                {
                  "variable_name": "low_price",
                  "source": "response_body",
                  "json_path": "result.data[0].l"
                }
              ]
            },
            {
              "step_order": 4,
              "description": "Disconnect WebSocket",
              "protocol": "websocket",
              "action": "disconnect"
            }
          ]
        }'::jsonb
    )
    RETURNING id
)

-- Insert test data sets
INSERT INTO case_data_sets (
    case_id,
    data_set_name,
    variables,
    validations_override,
    environments,
    jira_id,
    tags,
    is_active
)
SELECT
    id,
    data_set_name,
    variables::jsonb,
    validations_override::jsonb,
    environments,
    jira_id,
    tags,
    is_active
FROM new_case, (
    VALUES
        -- Data Set 1: BTC Ticker
        (
            'Subscribe to BTCUSD-PERP ticker',
            '{"instrument": "BTCUSD-PERP"}'::text,
            null::text,
            ARRAY['exchange_uat'],
            'PROJ-WS-001'::varchar,
            ARRAY['smoke', 'websocket', 'btc'],
            true
        ),
        -- Data Set 2: ETH Ticker
        (
            'Subscribe to ETHUSD-PERP ticker',
            '{"instrument": "ETHUSD-PERP"}'::text,
            null::text,
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['smoke', 'websocket', 'eth'],
            true
        )
) AS datasets(
    data_set_name,
    variables,
    validations_override,
    environments,
    jira_id,
    tags,
    is_active
);

-- Verification query
SELECT
    ac.id AS case_id,
    ac.name AS case_name,
    ac.service,
    ac.module,
    COUNT(cds.id) AS dataset_count,
    STRING_AGG(cds.data_set_name, ' | ' ORDER BY cds.id) AS datasets
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
WHERE ac.name = 'WebSocket Ticker Subscription'
GROUP BY ac.id, ac.name, ac.service, ac.module;

COMMIT;

-- ====================================================================
-- How to execute this test
-- ====================================================================

-- 1. Get the case_id from verification query above or run:
-- SELECT id, name FROM api_auto_cases WHERE name = 'WebSocket Ticker Subscription';

-- 2. Run the WebSocket test:
-- python run.py --env exchange_uat --tags websocket

-- Or run by case ID:
-- python run.py --env exchange_uat --id <case_id>

-- 3. View the Allure report:
-- allure serve reports/allure-report

-- ====================================================================
-- Expected WebSocket Response Structure
-- ====================================================================

-- {
--   "id": 1,
--   "method": "subscribe",
--   "code": 0,
--   "result": {
--     "instrument_name": "BTCUSD-PERP",
--     "subscription": "ticker.BTCUSD-PERP",
--     "channel": "ticker",
--     "data": [
--       {
--         "h": "114405.1",      // 24h high price
--         "l": "114405.1",      // 24h low price
--         "a": "114405.1",      // latest ask price (extracted)
--         "c": "0",             // 24h change percentage
--         "b": null,            // bid price
--         "bs": null,           // bid size
--         "k": null,
--         "ks": null,
--         "i": "BTCUSD-PERP",   // instrument name
--         "v": "0",             // 24h volume
--         "vv": "0",            // 24h volume value
--         "oi": "24555.4872",   // open interest
--         "t": 1760274341584    // timestamp
--       }
--     ]
--   }
-- }

-- ====================================================================
-- Test Coverage
-- ====================================================================

-- ✅ WebSocket Connection Management:
--    - Establish connection with timeout
--    - Graceful disconnection
--
-- ✅ Message Sending:
--    - Send subscription message with placeholders
--    - Variable resolution ({{@instrument}})
--
-- ✅ Message Reception & Validation:
--    - Wait for multiple messages (count: 2)
--    - Timeout control (30s)
--    - Validate subscription confirmation
--    - Validate ticker data structure
--
-- ✅ Variable Extraction:
--    - Extract latest_price from WebSocket message
--    - Extract high_price and low_price
--    - Store in context for potential use in later steps
--
-- ✅ Allure Reporting:
--    - Detailed step-by-step execution
--    - WebSocket message attachments
--    - Validation results

-- ====================================================================
-- MVP Limitations
-- ====================================================================

-- ❌ Not Implemented in MVP:
--    - Multiple WebSocket connections (single connection only)
--    - Automatic reconnection on connection loss
--    - Heartbeat/ping-pong for long-lived connections
--    - Unsubscribe functionality
--    - Batch message validation (validates latest message only)
--    - Mixed HTTP + WebSocket E2E flows (can be added later)

-- ====================================================================
-- Next Steps (Future Enhancements)
-- ====================================================================

-- 1. Add WebSocket orderbook subscription test
-- 2. Add negative test cases (invalid channel, connection failure)
-- 3. Implement multi-connection support for parallel subscriptions
-- 4. Add private channel authentication (with HTTP login → WebSocket)
-- 5. Add message sequence validation (order, timestamps)

-- ====================================================================
