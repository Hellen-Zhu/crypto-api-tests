-- ====================================================================
-- Ticker API 完整示例
-- ====================================================================
-- API: GET /exchange/v1/public/get-tickers
-- 参数: instrument_name (必需)
-- 环境: exchange_uat (https://uat-api.3ona.co)
-- ====================================================================

BEGIN;

-- ====================================================================
-- 步骤 1: 创建测试用例模板
-- ====================================================================

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
        'Test the public tickers API for cryptocurrency instruments. Retrieves real-time market data including price, volume, and open interest.',
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

-- ====================================================================
-- 步骤 2: 创建所有数据集
-- ====================================================================

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
        -- 数据集 1: BTCUSD-PERP
        (
            'Valid request - BTCUSD-PERP',
            '{"instrument": "BTCUSD-PERP"}',
            null,
            ARRAY['exchange_uat'],
            'PROJ-2001',
            ARRAY['smoke', 'positive'],
            true
        ),
        -- 数据集 2: ETHUSD-PERP
        (
            'Valid request - ETHUSD-PERP',
            '{"instrument": "ETHUSD-PERP"}',
            null,
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['smoke', 'positive'],
            true
        ),
        -- 数据集 3: Invalid instrument
        (
            'Invalid instrument_name',
            '{"instrument": "INVALID_INSTRUMENT"}',
            '{"1": {"expectedStatusCode": 400, "body": {"code": 40004, "message": "Invalid instrument_name"}, "notNull": ["$.code", "$.message"]}}',
            ARRAY['exchange_uat'],
            null::varchar,
            ARRAY['negative'],
            true
        ),
        -- 数据集 4: Missing instrument
        (
            'Missing instrument_name parameter',
            '{"instrument": ""}',
            '{"1": {"expectedStatusCode": 400, "body": {"code": 40004, "message": "Invalid instrument_name"}, "notNull": ["$.code", "$.message"]}}',
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

-- ====================================================================
-- 步骤 3: 验证创建结果
-- ====================================================================

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
-- 运行测试
-- ====================================================================

-- 1. 获取 case_id
SELECT id, name FROM api_auto_cases WHERE name = 'Get Tickers';

-- 2. 运行测试（在终端执行）
-- python run.py --env exchange_uat --id <case_id>

-- 3. 查看 Allure 报告
-- http://127.0.0.1:8889

-- ====================================================================
-- 响应字段说明
-- ====================================================================

-- API 返回的 Ticker 数据结构：
-- {
--   "i": "BTCUSD-PERP",    // instrument_name - 交易对名称
--   "h": "114405.1",       // high - 24h最高价
--   "l": "114405.1",       // low - 24h最低价
--   "a": "114405.1",       // ask/latest - 最新价格
--   "v": "0",              // volume - 24h成交量
--   "vv": "0",             // volume value - 24h成交额
--   "c": "0",              // change - 24h涨跌幅
--   "b": null,             // bid - 买价
--   "k": null,             // (未知字段)
--   "oi": "24555.4872",    // open interest - 持仓量
--   "t": 1760272680118     // timestamp - 时间戳
-- }

-- ====================================================================
-- 测试覆盖范围
-- ====================================================================

-- ✅ 正常场景 (2个):
--    - BTCUSD-PERP
--    - ETHUSD-PERP
--
-- ❌ 负面场景 (2个):
--    - Invalid instrument_name → 400, code 40004
--    - Missing instrument_name → 400, code 40004

-- ====================================================================
-- 扩展示例：添加更多交易对
-- ====================================================================

-- 获取 case_id
-- DO $$
-- DECLARE
--     v_case_id INTEGER;
-- BEGIN
--     SELECT id INTO v_case_id FROM api_auto_cases WHERE name = 'Get Tickers';
--
--     -- 批量添加更多交易对
--     INSERT INTO case_data_sets (case_id, data_set_name, variables, environments, tags, is_active)
--     VALUES
--         (v_case_id, 'Valid request - SOLUSD-PERP', '{"instrument": "SOLUSD-PERP"}'::jsonb, ARRAY['exchange_uat'], ARRAY['smoke'], true),
--         (v_case_id, 'Valid request - ADAUSD-PERP', '{"instrument": "ADAUSD-PERP"}'::jsonb, ARRAY['exchange_uat'], ARRAY['smoke'], true),
--         (v_case_id, 'Valid request - DOTUSD-PERP', '{"instrument": "DOTUSD-PERP"}'::jsonb, ARRAY['exchange_uat'], ARRAY['smoke'], true);
-- END $$;

-- ====================================================================
