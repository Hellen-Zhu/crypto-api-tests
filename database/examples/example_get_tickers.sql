-- ====================================================================
-- Example: Get Tickers API - One-Click Execution
-- ====================================================================
-- This is a complete, ready-to-run example for the Get Tickers API
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
        'Get Tickers',
        'Test the public tickers API for cryptocurrency instruments',
        'exchange_svc',
        'Market Data',
        'Ticker API',
        ARRAY['p1', 'smoke', 'market_data'],
        'test_team',
        '{
          "steps": [
            {
              "order": 1,
              "description": "Get ticker data for specified instrument",
              "path": "/exchange/v1/public/get-tickers",
              "method": "GET",
              "request": {
                "params": {
                  "instrument_name": "{{@instrument}}"
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
                  "$.result.data",
                  "$.result.data[0].i",
                  "$.result.data[0].h",
                  "$.result.data[0].l",
                  "$.result.data[0].a"
                ],
                "body": {
                  "code": 0,
                  "method": "public/get-tickers",
                  "result": {
                    "data": [
                      {
                        "i": "{{@instrument}}"
                      }
                    ]
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
        -- Positive Test Case 1: BTCUSD-PERP
        (
            'Valid request - BTCUSD-PERP',
            '{
              "instrument": "BTCUSD-PERP"
            }',
            null,
            ARRAY['exchange_uat'],
            'PROJ-2001',
            ARRAY['smoke', 'positive'],
            true
        ),
        -- Positive Test Case 2: ETHUSD-PERP
        (
            'Valid request - ETHUSD-PERP',
            '{
              "instrument": "ETHUSD-PERP"
            }',
            null,
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['smoke', 'positive'],
            true
        ),
        -- Negative Test Case 1: Invalid instrument
        (
            'Invalid instrument_name',
            '{
              "instrument": "INVALID"
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
        -- Negative Test Case 2: Missing instrument
        (
            'Missing instrument_name parameter',
            '{
              "instrument": ""
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
WHERE ac.name = 'Get Tickers'
GROUP BY ac.id, ac.name, ac.service;

COMMIT;

-- ====================================================================
-- How to run this test
-- ====================================================================

-- 1. Get the case_id from the verification output above, or run:
-- SELECT id, name FROM api_auto_cases WHERE name = 'Get Tickers';

-- 2. Execute the test:
-- python run.py --env exchange_uat --id <case_id>

-- 3. View the Allure report:
-- http://127.0.0.1:8889

-- ====================================================================
-- API Response Structure
-- ====================================================================

-- {
--   "code": 0,
--   "method": "public/get-tickers",
--   "result": {
--     "data": [
--       {
--         "i": "BTCUSD-PERP",    // instrument_name
--         "h": "114405.1",       // 24h high price
--         "l": "114405.1",       // 24h low price
--         "a": "114405.1",       // latest/ask price
--         "v": "0",              // 24h volume
--         "vv": "0",             // 24h volume value
--         "c": "0",              // 24h change percentage
--         "b": null,             // bid price
--         "k": null,             // (unknown field)
--         "oi": "24555.4872",    // open interest
--         "t": 1760272680118     // timestamp
--       }
--     ]
--   }
-- }

-- ====================================================================
-- Test Coverage
-- ====================================================================

-- ✅ Positive Cases (2):
--    - BTCUSD-PERP: Valid perpetual contract
--    - ETHUSD-PERP: Valid perpetual contract
--
-- ❌ Negative Cases (2):
--    - Invalid instrument_name → 400, code 40004
--    - Missing instrument_name → 400, code 40004

-- ====================================================================
