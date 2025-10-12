-- ====================================================================
-- Example: Get Candlestick API - One-Click Execution
-- ====================================================================
-- This is a complete, ready-to-run example for the Get Candlestick API
-- Simply execute this entire file to create the test case
-- ====================================================================

BEGIN;

-- Step 1: Create the test case
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
        'Get Candlestick Data',
        'Test the public candlestick API for historical OHLCV data',
        'exchange_svc',
        'Market Data',
        'Candlestick API',
        ARRAY['p1', 'smoke', 'market_data'],
        'test_team',
        '{
          "steps": [
            {
              "order": 1,
              "description": "Get candlestick data from exchange API",
              "path": "/exchange/v1/public/get-candlestick",
              "method": "GET",
              "request": {
                "params": {
                  "instrument_name": "{{@instrument}}",
                  "timeframe": "{{@timeframe}}"
                },
                "headers": {
                  "Content-Type": "application/json"
                },
                "body": null
              },
              "validations": {
                "expectedStatusCode": 200,
                "notNull": [
                  "$.code",
                  "$.result",
                  "$.result.data"
                ],
                "body": {
                  "code": 0,
                  "method": "public/get-candlestick",
                  "result": {
                    "instrument_name": "{{@instrument}}"
                  }
                }
              },
              "outputs": [
                {
                  "variable_name": "latest_candle",
                  "source": "response_body",
                  "json_path": "result.data[0]"
                },
                {
                  "variable_name": "open_price",
                  "source": "response_body",
                  "json_path": "result.data[0].o"
                },
                {
                  "variable_name": "close_price",
                  "source": "response_body",
                  "json_path": "result.data[0].c"
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
            }
          ]
        }'::jsonb
    )
    RETURNING id
)

-- Step 2: Create all data sets
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
        -- Positive Test Case 1: BTC_USD Daily
        (
            'Valid request - BTC_USD Daily (D1)',
            '{
              "instrument": "BTC_USD",
              "timeframe": "D1"
            }',
            null,
            ARRAY['exchange_uat'],
            'PROJ-3001',
            ARRAY['smoke', 'positive'],
            true
        ),
        -- Positive Test Case 2: ETH_USD Hourly
        (
            'Valid request - ETH_USD Hourly (H1)',
            '{
              "instrument": "ETH_USD",
              "timeframe": "H1"
            }',
            null,
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['smoke', 'positive'],
            true
        ),
        -- Positive Test Case 3: BTC_USD 5-minute
        (
            'Valid request - BTC_USD 5-minute (M5)',
            '{
              "instrument": "BTC_USD",
              "timeframe": "M5"
            }',
            null,
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['positive'],
            true
        ),
        -- Positive Test Case 4: Missing timeframe (uses default)
        (
            'Valid request - Missing timeframe (uses default)',
            '{
              "instrument": "BTC_USD",
              "timeframe": ""
            }',
            '{
              "1": {
                "expectedStatusCode": 200,
                "body": {
                  "code": 0,
                  "method": "public/get-candlestick"
                },
                "notNull": ["$.code", "$.result", "$.result.data"]
              }
            }',
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['positive', 'edge_case'],
            true
        ),
        -- Negative Test Case 1: Invalid instrument
        (
            'Invalid instrument_name',
            '{
              "instrument": "INVALID_PAIR",
              "timeframe": "H1"
            }',
            '{
              "1": {
                "expectedStatusCode": 400,
                "body": {
                  "code": 40004,
                  "message": "Invalid instrument_name"
                },
                "notNull": ["$.code", "$.message"]
              }
            }',
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['negative'],
            true
        ),
        -- Negative Test Case 2: Invalid timeframe
        (
            'Invalid timeframe',
            '{
              "instrument": "BTC_USD",
              "timeframe": "INVALID"
            }',
            '{
              "1": {
                "expectedStatusCode": 400,
                "body": {
                  "code": 40003,
                  "message": "Invalid timeframe"
                },
                "notNull": ["$.code", "$.message"]
              }
            }',
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['negative'],
            true
        ),
        -- Negative Test Case 3: Lowercase instrument (case-sensitive)
        (
            'Case-sensitive instrument_name - lowercase rejected',
            '{
              "instrument": "btc_usd",
              "timeframe": "H1"
            }',
            '{
              "1": {
                "expectedStatusCode": 400,
                "body": {
                  "code": 40004,
                  "message": "Invalid instrument_name"
                },
                "notNull": ["$.code", "$.message"]
              }
            }',
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['negative', 'edge_case'],
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

-- Step 3: Verify creation
SELECT
    ac.id AS case_id,
    ac.name AS case_name,
    ac.service,
    COUNT(cds.id) AS dataset_count,
    STRING_AGG(cds.data_set_name, ', ' ORDER BY cds.id) AS datasets
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
WHERE ac.name = 'Get Candlestick Data'
GROUP BY ac.id, ac.name, ac.service;

COMMIT;

-- ====================================================================
-- How to run this test
-- ====================================================================

-- 1. Get the case_id from the verification output above, or run:
-- SELECT id, name FROM api_auto_cases WHERE name = 'Get Candlestick Data';

-- 2. Execute all data sets:
-- python run.py --env exchange_uat --id <case_id>

-- 3. Execute specific tags:
-- python run.py --env exchange_uat --tags smoke
-- python run.py --env exchange_uat --tags negative

-- 4. View the Allure report:
-- http://127.0.0.1:8889

-- ====================================================================
-- API Response Structure
-- ====================================================================

-- {
--   "code": 0,
--   "method": "public/get-candlestick",
--   "result": {
--     "instrument_name": "BTC_USD",
--     "interval": "D1",
--     "data": [
--       {
--         "t": 1760272680000,  // timestamp (ms)
--         "o": "114000.5",     // open price
--         "h": "115500.2",     // high price
--         "l": "113800.1",     // low price
--         "c": "114405.1",     // close price
--         "v": "1250.5"        // volume
--       },
--       // ... more candles
--     ]
--   }
-- }

-- ====================================================================
-- Supported Timeframes
-- ====================================================================

-- M1  - 1 minute
-- M5  - 5 minutes
-- M15 - 15 minutes
-- M30 - 30 minutes
-- H1  - 1 hour
-- H4  - 4 hours
-- D1  - 1 day
-- W1  - 1 week

-- ====================================================================
-- Test Coverage
-- ====================================================================

-- ✅ Positive Cases (4):
--    - BTC_USD Daily (D1): Standard daily candles
--    - ETH_USD Hourly (H1): Standard hourly candles
--    - BTC_USD 5-minute (M5): Intraday candles
--    - Missing timeframe: API uses default value
--
-- ❌ Negative Cases (3):
--    - Invalid instrument_name → 400, code 40004
--    - Invalid timeframe → 400, code 40003
--    - Case-sensitive instrument_name → 400, code 40004

-- ====================================================================
-- Key Learning Points
-- ====================================================================

-- 1. Validation Override Usage:
--    - Data sets 4-7 use validations_override to test error scenarios
--    - Override completely replaces default validation for that step
--    - Keyed by step order as string: "1", "2", etc.

-- 2. Variable Usage:
--    - {{@instrument}} and {{@timeframe}} are data set variables
--    - Different data sets test different combinations
--    - Empty string ("") tests missing parameter behavior

-- 3. Output Variables:
--    - Extracted values can be used in subsequent steps
--    - Useful for multi-step E2E workflows
--    - Example: Extract prices for comparison in next step

-- ====================================================================
