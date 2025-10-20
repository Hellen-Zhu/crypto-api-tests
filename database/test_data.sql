-- =====================================================================
-- Crypto API Test Framework - Test Data
-- =====================================================================
-- Description: Sample test data for initializing the test framework
-- Author: Hellen Zhu
-- Database: PostgreSQL 14+
-- Usage: Run this after schema.sql to populate initial test data
-- =====================================================================

-- Set timezone
SET timezone = 'Asia/Shanghai';

-- =====================================================================
-- 1. ENVIRONMENT CONFIGURATIONS
-- =====================================================================

-- Clear existing environment data (optional - comment out if you want to preserve data)
-- TRUNCATE TABLE test_environments CASCADE;

-- Dev environment configurations
INSERT INTO test_environments (name, service, base_url, description, is_active) VALUES
('dev', 'exchange_svc', 'http://127.0.0.1:8788', 'Local development environment for exchange service', true),
('dev', 'user_svc', 'http://127.0.0.1:8789', 'Local development environment for user service', true),
('dev', 'websocket_svc', 'ws://127.0.0.1:8790/market', 'Local development WebSocket service', true);

-- UAT environment configurations
INSERT INTO test_environments (name, service, base_url, description, is_active) VALUES
('uat', 'exchange_svc', 'https://uat-api.3ona.co', 'UAT environment for exchange service', true),
('uat', 'user_svc', 'https://uat-api.3ona.co', 'UAT environment for user service', true),
('uat', 'websocket_svc', 'wss://uat-stream.3ona.co/exchange/v1/market', 'UAT WebSocket service for market data', true);

-- Production environment configurations (disabled by default for safety)
INSERT INTO test_environments (name, service, base_url, description, is_active) VALUES
('prod', 'exchange_svc', 'https://api.3ona.co', 'Production environment for exchange service', false),
('prod', 'websocket_svc', 'wss://stream.3ona.co/exchange/v1/market', 'Production WebSocket service', false);

-- =====================================================================
-- 2. HTTP TEST CASES
-- =====================================================================

-- Test Case 1: Get Candlestick Data (Valid Request)
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'Get Candlestick - Valid Request',
    'Test retrieving candlestick data with valid parameters',
    'exchange_svc',
    'market_data',
    'candlestick',
    ARRAY['P0', 'smoke', 'regression'],
    ARRAY['dev', 'uat'],
    'CRYPTO-101',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "instrument": "BTC_USD",
            "timeframe": "1h",
            "count": 10
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-candlestick",
                "description": "Retrieve candlestick data for BTC_USD",
                "params": {
                    "instrument_name": "${instrument}",
                    "timeframe": "${timeframe}",
                    "count": "${count}"
                },
                "headers": {
                    "Content-Type": "application/json"
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "body.code": 0,
                    "notNull": ["result.data", "result.instrument_name"],
                    "body.result.instrument_name": "${instrument}"
                }
            }
        ]
    }'::jsonb
);

-- Test Case 2: Get Candlestick - Invalid Count (Negative Testing)
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'Get Candlestick - Invalid Count',
    'Test candlestick API with invalid count parameter (negative value)',
    'exchange_svc',
    'market_data',
    'candlestick',
    ARRAY['P1', 'negative', 'regression'],
    ARRAY['uat'],
    'CRYPTO-102',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "instrument": "BTC_USD",
            "timeframe": "1h",
            "count": -1
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-candlestick",
                "description": "Test with invalid count parameter",
                "params": {
                    "instrument_name": "${instrument}",
                    "timeframe": "${timeframe}",
                    "count": "${count}"
                },
                "headers": {
                    "Content-Type": "application/json"
                },
                "validations": {
                    "expectedStatusCode": 400,
                    "body.code": {
                        "!=": 0
                    }
                }
            }
        ]
    }'::jsonb
);

-- Test Case 3: Get Tickers - Valid Request
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'Get Tickers - BTCUSD Perpetual',
    'Test retrieving ticker data for BTCUSD perpetual contract',
    'exchange_svc',
    'market_data',
    'ticker',
    ARRAY['P0', 'smoke'],
    ARRAY['dev', 'uat'],
    'CRYPTO-103',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "instrument": "BTCUSD-PERP"
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-tickers",
                "description": "Get ticker for BTCUSD perpetual",
                "params": {
                    "instrument_name": "${instrument}"
                },
                "headers": {
                    "Content-Type": "application/json"
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "body.code": 0,
                    "notNull": [
                        "result.data.instrument_name",
                        "result.data.last_price",
                        "result.data.best_bid_price",
                        "result.data.best_ask_price"
                    ],
                    "body.result.data.last_price": {
                        ">": 0
                    }
                }
            }
        ]
    }'::jsonb
);

-- Test Case 4: Multi-Step Test with Variable Extraction
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'Multi-Step: Get Ticker and Validate Candlestick',
    'Test multi-step workflow: get current ticker, then validate candlestick data contains recent price',
    'exchange_svc',
    'market_data',
    'integration',
    ARRAY['P1', 'integration'],
    ARRAY['uat'],
    'CRYPTO-104',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "instrument": "BTC_USD"
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-tickers",
                "description": "Step 1: Get current ticker",
                "params": {
                    "instrument_name": "${instrument}"
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "body.code": 0
                },
                "outputs": {
                    "current_price": "result.data.last_price"
                }
            },
            {
                "step_order": 2,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-candlestick",
                "description": "Step 2: Get candlestick and verify it contains recent data",
                "params": {
                    "instrument_name": "${instrument}",
                    "timeframe": "1h",
                    "count": 5
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "body.code": 0,
                    "notNull": ["result.data"],
                    "body.result.data": {
                        "length": 5
                    }
                }
            }
        ]
    }'::jsonb
);

-- =====================================================================
-- 3. WEBSOCKET TEST CASES
-- =====================================================================

-- Test Case 5: WebSocket - Basic Subscription Test
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'WebSocket - Ticker Subscription',
    'Test WebSocket ticker subscription and message validation',
    'websocket_svc',
    'market_data',
    'websocket',
    ARRAY['P0', 'websocket', 'realtime'],
    ARRAY['uat'],
    'CRYPTO-201',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "symbol": "BTC-USD",
            "expected_count": 3
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "websocket",
                "action": "connect",
                "description": "Connect to WebSocket market data stream",
                "request": {
                    "url": "${base_url}",
                    "timeout": 10
                }
            },
            {
                "step_order": 2,
                "protocol": "websocket",
                "action": "send",
                "description": "Subscribe to BTC-USD ticker",
                "request": {
                    "body": {
                        "method": "subscribe",
                        "params": {
                            "channels": ["ticker.${symbol}"]
                        },
                        "id": 1
                    }
                }
            },
            {
                "step_order": 3,
                "protocol": "websocket",
                "action": "wait",
                "description": "Wait for ticker push messages",
                "request": {
                    "count": "${expected_count}",
                    "timeout": 30
                },
                "validations": {
                    "notNull": [
                        "data.price",
                        "data.volume",
                        "data.timestamp"
                    ],
                    "body.channel": "ticker.${symbol}",
                    "body.data.price": {
                        ">": 0
                    }
                }
            },
            {
                "step_order": 4,
                "protocol": "websocket",
                "action": "disconnect",
                "description": "Disconnect from WebSocket"
            }
        ]
    }'::jsonb
);

-- Test Case 6: WebSocket - Multiple Subscriptions
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'WebSocket - Multiple Channel Subscriptions',
    'Test subscribing to multiple channels and validating different message types',
    'websocket_svc',
    'market_data',
    'websocket',
    ARRAY['P1', 'websocket', 'regression'],
    ARRAY['uat'],
    'CRYPTO-202',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "btc_symbol": "BTC-USD",
            "eth_symbol": "ETH-USD"
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "websocket",
                "action": "connect",
                "description": "Connect to WebSocket server",
                "request": {
                    "url": "${base_url}",
                    "timeout": 10
                }
            },
            {
                "step_order": 2,
                "protocol": "websocket",
                "action": "send",
                "description": "Subscribe to BTC ticker",
                "request": {
                    "body": {
                        "method": "subscribe",
                        "params": {
                            "channels": ["ticker.${btc_symbol}"]
                        },
                        "id": 1
                    }
                }
            },
            {
                "step_order": 3,
                "protocol": "websocket",
                "action": "send",
                "description": "Subscribe to ETH ticker",
                "request": {
                    "body": {
                        "method": "subscribe",
                        "params": {
                            "channels": ["ticker.${eth_symbol}"]
                        },
                        "id": 2
                    }
                }
            },
            {
                "step_order": 4,
                "protocol": "websocket",
                "action": "wait",
                "description": "Wait for messages from both channels",
                "request": {
                    "count": 5,
                    "timeout": 45
                },
                "validations": {
                    "notNull": ["data.price", "channel"]
                }
            },
            {
                "step_order": 5,
                "protocol": "websocket",
                "action": "disconnect",
                "description": "Clean up connection"
            }
        ]
    }'::jsonb
);

-- =====================================================================
-- 4. MIXED PROTOCOL TEST CASES (HTTP + WebSocket)
-- =====================================================================

-- Test Case 7: Mixed Protocol - HTTP Query then WebSocket Subscribe
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'Mixed Protocol - HTTP Snapshot + WebSocket Real-time',
    'Test workflow: get HTTP snapshot, then verify WebSocket push has different price',
    'exchange_svc',
    'market_data',
    'integration',
    ARRAY['P1', 'integration', 'websocket'],
    ARRAY['uat'],
    'CRYPTO-301',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "instrument": "BTC-USD"
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-tickers",
                "description": "HTTP: Get current price snapshot",
                "params": {
                    "instrument_name": "${instrument}"
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "body.code": 0,
                    "notNull": ["result.data.last_price"]
                },
                "outputs": {
                    "snapshot_price": "result.data.last_price"
                }
            },
            {
                "step_order": 2,
                "protocol": "websocket",
                "action": "connect",
                "description": "WebSocket: Connect to real-time stream",
                "request": {
                    "url": "${base_url}",
                    "timeout": 10
                }
            },
            {
                "step_order": 3,
                "protocol": "websocket",
                "action": "send",
                "description": "WebSocket: Subscribe to ticker",
                "request": {
                    "body": {
                        "method": "subscribe",
                        "params": {
                            "channels": ["ticker.${instrument}"]
                        }
                    }
                }
            },
            {
                "step_order": 4,
                "protocol": "websocket",
                "action": "wait",
                "description": "WebSocket: Verify push data quality",
                "request": {
                    "count": 5,
                    "timeout": 60
                },
                "validations": {
                    "notNull": ["data.price"],
                    "body.data.price": {
                        ">": 0
                    }
                }
            },
            {
                "step_order": 5,
                "protocol": "websocket",
                "action": "disconnect",
                "description": "WebSocket: Cleanup"
            }
        ]
    }'::jsonb
);

-- =====================================================================
-- 5. DATABASE VALIDATION TEST CASES (Future Enhancement)
-- =====================================================================

-- Test Case 8: API + Database Validation
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'API + Database Consistency Check',
    'Verify API response matches database records (placeholder for future DB validation feature)',
    'exchange_svc',
    'market_data',
    'data_consistency',
    ARRAY['P2', 'database'],
    ARRAY['dev'],
    'CRYPTO-401',
    'Hellen Zhu',
    false,
    '{
        "variables": {
            "instrument": "BTC_USD"
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-tickers",
                "description": "Get ticker from API",
                "params": {
                    "instrument_name": "${instrument}"
                },
                "validations": {
                    "expectedStatusCode": 200,
                    "body.code": 0
                },
                "outputs": {
                    "api_price": "result.data.last_price"
                }
            }
        ],
        "validations": {
            "note": "Database validation step to be implemented in future version"
        }
    }'::jsonb
);

-- =====================================================================
-- 6. EDGE CASES AND NEGATIVE TESTS
-- =====================================================================

-- Test Case 9: Invalid Instrument Name
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'Negative Test - Invalid Instrument Name',
    'Test API behavior with non-existent instrument',
    'exchange_svc',
    'market_data',
    'ticker',
    ARRAY['P1', 'negative'],
    ARRAY['uat'],
    'CRYPTO-501',
    'Hellen Zhu',
    true,
    '{
        "variables": {
            "invalid_instrument": "INVALID_COIN_XYZ"
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "http",
                "method": "GET",
                "path": "/exchange/v1/public/get-tickers",
                "description": "Request ticker for invalid instrument",
                "params": {
                    "instrument_name": "${invalid_instrument}"
                },
                "headers": {
                    "Content-Type": "application/json"
                },
                "validations": {
                    "expectedStatusCode": 400,
                    "body.code": {
                        "!=": 0
                    }
                }
            }
        ]
    }'::jsonb
);

-- Test Case 10: WebSocket Connection Failure Test
INSERT INTO api_auto_cases (
    name, description, service, module, component, tags, environments, jira_id, author, enable, test_config
) VALUES (
    'Negative Test - WebSocket Invalid URL',
    'Test WebSocket connection failure with invalid URL',
    'websocket_svc',
    'market_data',
    'websocket',
    ARRAY['P2', 'negative', 'websocket'],
    ARRAY['dev'],
    'CRYPTO-502',
    'Hellen Zhu',
    false,
    '{
        "variables": {
            "invalid_url": "wss://invalid-domain-that-does-not-exist.com/ws"
        },
        "steps": [
            {
                "step_order": 1,
                "protocol": "websocket",
                "action": "connect",
                "description": "Attempt connection to invalid URL",
                "request": {
                    "url": "${invalid_url}",
                    "timeout": 5
                },
                "expect_failure": true
            }
        ]
    }'::jsonb
);

-- =====================================================================
-- DISPLAY SUMMARY
-- =====================================================================

-- Count and display inserted test cases
DO $$
DECLARE
    env_count INTEGER;
    case_count INTEGER;
    http_count INTEGER;
    ws_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO env_count FROM test_environments;
    SELECT COUNT(*) INTO case_count FROM api_auto_cases;
    SELECT COUNT(*) INTO http_count FROM api_auto_cases WHERE test_config->'steps'->0->>'protocol' = 'http';
    SELECT COUNT(*) INTO ws_count FROM api_auto_cases WHERE test_config->'steps'->0->>'protocol' = 'websocket';

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Test Data Inserted Successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Environment Configurations: %', env_count;
    RAISE NOTICE 'Total Test Cases: %', case_count;
    RAISE NOTICE '  - HTTP Test Cases: %', http_count;
    RAISE NOTICE '  - WebSocket Test Cases: %', ws_count;
    RAISE NOTICE '  - Mixed Protocol Cases: %', (case_count - http_count - ws_count);
    RAISE NOTICE '========================================';
END $$;
