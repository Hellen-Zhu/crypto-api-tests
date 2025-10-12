-- ====================================================================
-- 通用测试用例模板
-- ====================================================================
-- 使用说明：
-- 1. 复制此文件
-- 2. 搜索并替换所有 【修改】 标记的内容
-- 3. 根据实际 API 调整验证规则
-- 4. 执行 SQL
-- ====================================================================

BEGIN;

-- ====================================================================
-- 步骤 1: 创建测试用例模板
-- ====================================================================

INSERT INTO api_auto_cases (
    name,                                  -- 测试用例名称
    description,                           -- 详细描述
    service,                              -- 服务名称
    module,                               -- 模块名称
    component,                            -- 组件名称（可选）
    tags,                                 -- 标签数组
    author,                               -- 作者
    parameters                            -- 测试步骤（JSONB）
) VALUES (
    '【修改】测试用例名称',                -- 例如: 'Get Order Details'
    '【修改】测试用例描述',                -- 例如: 'Test order details retrieval API'
    '【修改】服务名称',                    -- 例如: 'order_svc', 'user_svc', 'exchange_svc'
    '【修改】模块名称',                    -- 例如: 'Order Management', 'User Management'
    '【修改】组件名称',                    -- 例如: 'Order Query', 'User Login' (可为 null)
    ARRAY['【修改】标签1', '【修改】标签2'],  -- 例如: ARRAY['p0', 'smoke', 'order']
    '【修改】作者',                        -- 例如: 'test_team', 'qa_team'
    '{
      "steps": [                          -- 步骤数组（必需）
        {
          "order": 1,                     -- 步骤顺序（必需，从1开始）
          "description": "【修改】步骤描述",  -- 例如: "Get order details by order_id"
          "path": "【修改】API路径",        -- 例如: "/api/v1/orders/{{@order_id}}"
          "method": "【修改】HTTP方法",     -- GET, POST, PUT, DELETE, PATCH
          "request": {
            "params": {                   -- GET 请求参数（如果是 POST 可设为 null）
              "【修改】参数名1": "{{@变量名1}}",
              "【修改】参数名2": "{{@变量名2}}"
            },
            "headers": {                  -- 请求头（必需）
              "Content-Type": "application/json",
              "【修改】其他头": "{{@header_value}}"  -- 例如: "Authorization": "Bearer {{@token}}"
            },
            "body": {                     -- 请求体（GET 请求设为 null）
              "【修改】字段名1": "{{@变量名1}}",
              "【修改】字段名2": "{{@变量名2}}"
            }
          },
          "validations": {                -- 验证规则（必需）
            "expectedStatusCode": 200,    -- 期望状态码
            "notNull": [                  -- JSONPath 非空验证
              "$.code",
              "$.data",
              "$.data.【修改】字段名"
            ],
            "body": {                     -- 响应体匹配
              "code": 0,
              "data": {
                "【修改】字段名": "{{@expected_value}}"
              }
            }
          },
          "outputs": [                    -- 输出变量（可选，用于步骤间传递）
            {
              "variable_name": "【修改】变量名",  -- 例如: "token", "order_id"
              "source": "response_body",   -- 或 "response_headers"
              "json_path": "【修改】JSONPath"  -- 例如: "data.token", "data.order_id"
            }
          ]
        }

        -- 如果需要多个步骤，继续添加：
        -- ,{
        --   "order": 2,
        --   "description": "第二步描述",
        --   ...
        -- }
      ]
    }'::jsonb
)
RETURNING id;  -- 👈 记录返回的 ID，用于步骤 2

-- ====================================================================
-- 步骤 2: 创建数据集
-- ====================================================================

-- 数据集 1: 正常场景
INSERT INTO case_data_sets (
    case_id,                              -- 使用步骤 1 返回的 ID
    data_set_name,                        -- 数据集名称
    variables,                            -- 变量（JSONB）
    validations_override,                 -- 验证规则覆盖（可选）
    environments,                         -- 运行环境（数组）
    jira_id,                             -- Jira ID（可选）
    tags,                                -- 标签（数组）
    is_active                            -- 是否激活
) VALUES (
    【填入步骤1返回的case_id】,           -- 👈 填入 case_id
    '【修改】数据集名称 - 正常场景',       -- 例如: 'Valid order - Success'
    '{
      "【修改】变量名1": "【修改】变量值1",  -- 例如: "order_id": "ORD123456"
      "【修改】变量名2": "【修改】变量值2"   -- 例如: "token": "test_token"
    }'::jsonb,
    null,                                 -- 使用默认验证规则（不覆盖）
    ARRAY['【修改】环境1', '【修改】环境2'],  -- 例如: ARRAY['uat', 'dev']
    '【修改】JIRA-ID',                     -- 例如: 'PROJ-1001' (可为 null)
    ARRAY['【修改】标签'],                 -- 例如: ARRAY['smoke', 'positive']
    true                                  -- true=激活, false=禁用
);

-- 数据集 2: 负面场景（覆盖验证规则）
INSERT INTO case_data_sets (
    case_id,
    data_set_name,
    variables,
    validations_override,                 -- 👈 覆盖默认验证规则
    environments,
    jira_id,
    tags,
    is_active
) VALUES (
    【填入步骤1返回的case_id】,
    '【修改】数据集名称 - 负面场景',       -- 例如: 'Invalid order - Not found'
    '{
      "【修改】变量名1": "【修改】无效值1",
      "【修改】变量名2": "【修改】无效值2"
    }'::jsonb,
    '{
      "1": {                              -- "1" 表示覆盖第 1 步的验证
        "expectedStatusCode": 【修改】错误状态码,  -- 例如: 404, 400
        "body": {
          "code": 【修改】错误码,          -- 例如: 10001
          "message": "【修改】错误消息"     -- 例如: "Order not found"
        },
        "notNull": [
          "$.code",
          "$.message"
        ]
      }
    }'::jsonb,
    ARRAY['【修改】环境'],
    null,
    ARRAY['negative'],
    true
);

-- ====================================================================
-- 步骤 3: 验证创建结果
-- ====================================================================

SELECT
    ac.id AS case_id,
    ac.name AS case_name,
    ac.service,
    ac.module,
    COUNT(cds.id) AS dataset_count,
    STRING_AGG(cds.data_set_name, ', ') AS datasets
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
WHERE ac.name = '【填入测试用例名称】'  -- 👈 填入步骤 1 的测试用例名称
GROUP BY ac.id, ac.name, ac.service, ac.module;

COMMIT;

-- ====================================================================
-- 步骤 4: 运行测试
-- ====================================================================

-- 获取 case_id
-- SELECT id FROM api_auto_cases WHERE name = '【测试用例名称】';

-- 运行测试命令（在终端执行）：
-- python run.py --env uat --id <case_id>

-- 查看 Allure 报告：
-- http://127.0.0.1:8889

-- ====================================================================
-- 📝 常用配置示例
-- ====================================================================

-- 示例 1: GET 请求（带查询参数）
-- "request": {
--   "params": {
--     "user_id": "{{@user_id}}",
--     "page": "{{@page}}"
--   },
--   "headers": {"Content-Type": "application/json"},
--   "body": null
-- }

-- 示例 2: POST 请求（带 JSON 请求体）
-- "request": {
--   "params": null,
--   "headers": {"Content-Type": "application/json"},
--   "body": {
--     "username": "{{@username}}",
--     "password": "{{@password}}"
--   }
-- }

-- 示例 3: 带 Authorization 的请求
-- "request": {
--   "params": null,
--   "headers": {
--     "Content-Type": "application/json",
--     "Authorization": "Bearer {{@token}}"  -- 或使用步骤间变量: "Bearer {{step_1.token}}"
--   },
--   "body": {...}
-- }

-- 示例 4: 数据库验证
-- "validations": {
--   "expectedStatusCode": 200,
--   "dbValidation": {
--     "query": "SELECT COUNT(*) as count FROM users WHERE id = {{@user_id}}",
--     "expected": [{"count": 1}]
--   }
-- }

-- 示例 5: 多步骤测试（E2E）
-- "steps": [
--   {
--     "order": 1,
--     "description": "Login to get token",
--     "path": "/api/v1/login",
--     "method": "POST",
--     "request": {...},
--     "validations": {...},
--     "outputs": [{
--       "variable_name": "token",
--       "source": "response_body",
--       "json_path": "data.token"
--     }]
--   },
--   {
--     "order": 2,
--     "description": "Use token to access protected resource",
--     "path": "/api/v1/profile",
--     "method": "GET",
--     "request": {
--       "params": null,
--       "headers": {
--         "Content-Type": "application/json",
--         "Authorization": "Bearer {{token}}"  -- 使用步骤 1 的输出
--       },
--       "body": null
--     },
--     "validations": {...},
--     "outputs": null
--   }
-- ]

-- ====================================================================
-- 🎨 变量使用说明
-- ====================================================================

-- 1. 数据集变量: {{@变量名}}
--    来源: case_data_sets.variables
--    用法: "username": "{{@username}}"
--
-- 2. 动态变量: {{$函数名}}
--    可用函数:
--    - {{$randomUser}}          - 随机用户名
--    - {{$randomPassword(16)}}  - 16位随机密码
--    - {{$randomPhone}}         - 随机手机号
--    - {{$randomInt(6)}}        - 6位随机数字
--    - {{$randomEmail}}         - 随机邮箱
--
-- 3. 步骤间变量: {{变量名}}
--    来源: 前一步骤的 outputs
--    用法: "Authorization": "Bearer {{token}}"

-- ====================================================================
-- ⚠️ 注意事项
-- ====================================================================

-- 1. parameters 字段必须包含 "steps" 数组
-- 2. 每个步骤必须有 order, description, path, method, request, validations
-- 3. request 必须包含 params, headers, body（即使为 null）
-- 4. validations 必须包含 expectedStatusCode
-- 5. 数据集中的变量名必须与 parameters 中的占位符匹配
-- 6. environments 数组中的环境名必须存在于 test_environments 表中
-- 7. 如果使用 validations_override，key 必须是字符串类型的步骤序号（如 "1", "2"）

-- ====================================================================
