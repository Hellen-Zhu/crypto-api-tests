# 📚 测试用例 SQL 文档

本目录包含用于创建和管理 API 自动化测试用例的 SQL 脚本。

## 📁 目录结构

```
database/
├── README.md                          # 本文件 - SQL 使用总指南
├── quick_reference.sql                # 常用操作速查表
├── templates/                         # 模板文件夹
│   ├── new_test_case_template.sql    # 通用测试用例模板
│   └── ticker_api_example.sql        # Ticker API 完整示例
└── examples/                          # 示例文件夹
    ├── example_get_tickers.sql       # Get Tickers API 示例
    ├── example_get_candlestick.sql   # Get Candlestick API 示例
    └── example_user_management.sql   # 用户管理 E2E 示例
```

---

## 🎯 框架核心概念

### 2 表设计架构

本框架使用 **2 表设计**，数据存储简洁高效：

1. **`api_auto_cases`** - 测试用例模板表
   - 定义测试步骤（存储在 `parameters` JSONB 列）
   - 包含元数据（名称、描述、标签等）

2. **`case_data_sets`** - 数据集表
   - 提供测试数据（`variables` JSONB）
   - 可覆盖验证规则（`validations_override` JSONB）
   - 指定运行环境（`environments` 数组）

**关系**: 1 个测试用例 + N 个数据集 = N 个测试场景

---

## 🚀 快速开始

### 步骤 1: 选择模板

根据您的需求选择合适的模板：

- **简单 GET 请求** → 使用 `templates/ticker_api_example.sql`
- **POST 请求** → 参考 `examples/example_user_management.sql`
- **多步骤 E2E** → 参考 `examples/example_user_management.sql`
- **从头开始** → 使用 `templates/new_test_case_template.sql`

### 步骤 2: 修改模板

1. 复制模板文件
2. 修改标记为 `【修改】` 的部分
3. 根据实际 API 调整验证规则

### 步骤 3: 执行 SQL

```bash
# 方式 1: 使用 psql
psql -h localhost -U postgres -d apitest -f database/examples/example_get_tickers.sql

# 方式 2: 使用 DBeaver/pgAdmin
# 直接打开 SQL 文件并执行
```

### 步骤 4: 运行测试

```bash
# 获取新创建的 case_id
SELECT id, name FROM api_auto_cases ORDER BY id DESC LIMIT 1;

# 运行测试
python run.py --env exchange_uat --id <case_id>
```

---

## 📝 Parameters 字段结构

### 完整结构

```json
{
  "steps": [                              // 必需：步骤数组
    {
      "order": 1,                         // 必需：步骤顺序
      "description": "步骤描述",           // 必需：步骤说明
      "path": "/api/endpoint",            // 必需：API 路径
      "method": "GET",                    // 必需：HTTP 方法
      "request": {                        // 必需：请求配置
        "params": {...},                  // GET 参数（可为 null）
        "headers": {...},                 // 请求头
        "body": {...}                     // 请求体（可为 null）
      },
      "validations": {                    // 必需：验证规则
        "expectedStatusCode": 200,        // 期望状态码
        "notNull": [...],                 // 非空字段
        "body": {...}                     // 响应体匹配
      },
      "outputs": [...]                    // 可选：输出变量
    }
  ]
}
```

### Request 配置详解

```json
"request": {
  "params": {                             // GET 请求参数
    "key1": "{{@variable}}",              // 使用数据集变量
    "key2": "fixed_value"                 // 固定值
  },
  "headers": {                            // 请求头
    "Content-Type": "application/json",
    "Authorization": "Bearer {{@token}}"
  },
  "body": {                               // POST/PUT 请求体
    "field1": "{{@value1}}",
    "field2": 123
  }
}
```

### Validations 配置详解

```json
"validations": {
  "expectedStatusCode": 200,              // 期望状态码
  "notNull": [                            // JSONPath 非空验证
    "$.code",
    "$.data.id"
  ],
  "body": {                               // 响应体字段匹配
    "code": 0,
    "data": {
      "status": "{{@expected_status}}"    // 可使用变量
    }
  },
  "containsText": "success",              // 响应包含文本
  "dbValidation": {                       // 数据库验证（可选）
    "query": "SELECT * FROM users WHERE id = {{@user_id}}",
    "expected": [{"count": 1}]
  }
}
```

### Outputs 配置详解

```json
"outputs": [
  {
    "variable_name": "token",             // 变量名
    "source": "response_body",            // 来源：response_body 或 response_headers
    "json_path": "data.token"             // JSONPath 表达式
  }
]
```

---

## 🎨 变量使用说明

### 三种变量类型

#### 1. 数据集变量 `{{@变量名}}`
- **来源**: `case_data_sets.variables`
- **示例**: `{{@username}}`, `{{@order_id}}`
- **用途**: 参数化测试数据

```json
// 数据集中定义
{
  "variables": {
    "username": "testuser",
    "password": "Test@123"
  }
}

// 请求中使用
{
  "body": {
    "username": "{{@username}}",
    "password": "{{@password}}"
  }
}
```

#### 2. 动态变量 `{{$函数名}}`
- **来源**: 框架自动生成
- **示例**: `{{$randomUser}}`, `{{$randomPassword(16)}}`
- **用途**: 生成随机测试数据

**可用函数**:
- `{{$randomUser}}` - 随机用户名
- `{{$randomPassword(长度)}}` - 随机密码
- `{{$randomPhone}}` - 随机手机号
- `{{$randomInt(位数)}}` - 随机整数
- `{{$randomEmail}}` - 随机邮箱

#### 3. 步骤间变量 `{{步骤名.路径}}`
- **来源**: 前一步骤的 `outputs`
- **示例**: `{{step_1.data.token}}`
- **用途**: 步骤间传递数据

```json
// 步骤 1：提取 token
{
  "order": 1,
  "outputs": [{
    "variable_name": "token",
    "source": "response_body",
    "json_path": "data.token"
  }]
}

// 步骤 2：使用 token
{
  "order": 2,
  "request": {
    "headers": {
      "Authorization": "Bearer {{token}}"  // 使用步骤 1 的输出
    }
  }
}
```

---

## 🌍 环境配置

### 可用环境

查看所有环境：
```sql
SELECT id, name, base_url, is_active
FROM test_environments
ORDER BY id;
```

当前环境：
- `uat` - http://127.0.0.1:8787 (用户管理服务)
- `dev` - http://127.0.0.1:8788 (开发环境)
- `exchange_uat` - https://uat-api.3ona.co (Exchange API)

### 配置数据集环境

```sql
-- 单个环境
INSERT INTO case_data_sets (..., environments, ...)
VALUES (..., ARRAY['uat'], ...);

-- 多个环境
INSERT INTO case_data_sets (..., environments, ...)
VALUES (..., ARRAY['uat', 'dev'], ...);
```

### 运行指定环境

```bash
python run.py --env uat           # UAT 环境
python run.py --env exchange_uat  # Exchange UAT 环境
python run.py --env dev           # DEV 环境
```

---

## 🔧 验证规则覆盖

### 使用场景

当同一个测试步骤在不同场景下需要不同的验证规则时，使用 `validations_override`。

### 示例：正常 vs 异常场景

**测试用例**（默认验证 - 成功场景）:
```json
{
  "validations": {
    "expectedStatusCode": 200,
    "body": {"code": 0}
  }
}
```

**数据集 1**（使用默认验证）:
```sql
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override)
VALUES (
    100,
    'Valid login',
    '{"username": "admin", "password": "pass123"}'::jsonb,
    null  -- 使用默认验证
);
```

**数据集 2**（覆盖验证 - 失败场景）:
```sql
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override)
VALUES (
    100,
    'Invalid password',
    '{"username": "admin", "password": "wrong"}'::jsonb,
    '{
      "1": {
        "expectedStatusCode": 401,
        "body": {
          "code": 10001,
          "message": "Invalid credentials"
        }
      }
    }'::jsonb  -- 覆盖步骤 1 的验证规则
);
```

---

## 📋 常用操作

### 查询测试用例

```sql
-- 查询所有测试用例
SELECT id, name, service, module, tags
FROM api_auto_cases
ORDER BY id DESC;

-- 查询特定服务的测试用例
SELECT id, name, array_length(tags, 1) as tag_count
FROM api_auto_cases
WHERE service = 'exchange_svc';

-- 查看测试用例的数据集数量
SELECT
    ac.id,
    ac.name,
    COUNT(cds.id) as dataset_count
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
GROUP BY ac.id, ac.name
ORDER BY ac.id DESC;
```

### 复制测试用例

```sql
-- 复制测试用例（不含数据集）
INSERT INTO api_auto_cases (name, description, service, module, tags, author, parameters)
SELECT
    name || ' - Copy',
    description,
    service,
    module,
    tags,
    author,
    parameters
FROM api_auto_cases
WHERE id = 10
RETURNING id;

-- 复制数据集到新的测试用例
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
SELECT
    <新的case_id>,  -- 填入新的 case_id
    data_set_name,
    variables,
    validations_override,
    environments,
    tags,
    is_active
FROM case_data_sets
WHERE case_id = 10;
```

### 更新验证规则

```sql
-- 更新特定数据集的验证规则
UPDATE case_data_sets
SET validations_override = '{
    "1": {
        "expectedStatusCode": 400,
        "body": {"code": 40004}
    }
}'::jsonb
WHERE id = 17;
```

### 批量操作

```sql
-- 批量禁用数据集
UPDATE case_data_sets
SET is_active = false
WHERE case_id = 100 AND tags && ARRAY['deprecated'];

-- 批量修改环境
UPDATE case_data_sets
SET environments = ARRAY['uat', 'dev']
WHERE case_id = 100;

-- 批量添加标签
UPDATE api_auto_cases
SET tags = tags || ARRAY['regression']
WHERE service = 'exchange_svc';
```

---

## 🎓 最佳实践

### 1. 命名规范

- **测试用例名称**: 描述性强，例如 `Get Tickers`, `E2E - Login and Query`
- **数据集名称**: 说明场景，例如 `Valid request - BTCUSD-PERP`, `Invalid password`
- **变量名称**: 见名知意，例如 `user_id`, `order_id`, `expected_status`

### 2. 标签策略

```sql
-- 优先级标签
tags = ARRAY['p0', 'smoke']     -- P0 + 冒烟测试
tags = ARRAY['p1', 'regression'] -- P1 + 回归测试

-- 功能标签
tags = ARRAY['order', 'payment']  -- 订单支付相关

-- 场景标签
tags = ARRAY['positive']          -- 正向场景
tags = ARRAY['negative']          -- 负向场景
tags = ARRAY['edge_case']         -- 边界场景
```

### 3. 验证规则

- 先测试实际 API 响应
- 根据实际响应编写验证规则
- 使用 `notNull` 验证必需字段
- 使用 `body` 精确匹配重要字段

### 4. 数据集设计

- 正常场景至少 2 个数据集（覆盖不同参数组合）
- 负面场景覆盖所有错误情况
- 边界场景测试临界值
- 使用描述性的 `data_set_name`

### 5. 多步骤测试

- 步骤间使用 `outputs` 传递数据
- 每个步骤都有清晰的 `description`
- 合理使用 `order` 确保执行顺序
- 避免步骤过多（建议 ≤ 5 步）

---

## 🐛 故障排查

### 常见错误

#### 1. `ValueError: Test case X does not have a 'parameters' column`
**原因**: parameters 字段为 null 或结构错误

**解决**:
```sql
-- 检查 parameters 结构
SELECT id, name,
       CASE WHEN parameters IS NULL THEN 'NULL'
            WHEN parameters ? 'steps' THEN 'OK'
            ELSE 'INVALID' END as status
FROM api_auto_cases
WHERE id = X;

-- 修复：确保有 steps 数组
UPDATE api_auto_cases
SET parameters = '{"steps": [...]}'::jsonb
WHERE id = X;
```

#### 2. `KeyError: 'variable_name'`
**原因**: 数据集缺少变量

**解决**:
```sql
-- 检查数据集变量
SELECT id, data_set_name, variables
FROM case_data_sets
WHERE case_id = X;

-- 添加缺失变量
UPDATE case_data_sets
SET variables = variables || '{"new_var": "value"}'::jsonb
WHERE id = Y;
```

#### 3. 验证失败
**原因**: 验证规则与实际 API 响应不匹配

**解决**:
```bash
# 先用 curl 测试 API
curl -X GET 'https://api.example.com/endpoint?param=value' | jq

# 根据实际响应更新验证规则
UPDATE case_data_sets
SET validations_override = '{...实际响应...}'::jsonb
WHERE id = Y;
```

---

## 📚 参考文档

- **[CLAUDE.md](../CLAUDE.md)** - 框架完整文档
- **[FINAL_COMPLETION_REPORT.md](../FINAL_COMPLETION_REPORT.md)** - 测试结果报告
- **[models/tables.py](../models/tables.py)** - 数据表结构定义

---

## 🆘 获取帮助

### 快速查询

```sql
-- 查看帮助文档
\i database/quick_reference.sql

-- 查看示例
\i database/examples/example_get_tickers.sql
```

### 联系支持

- 查看 GitHub Issues
- 阅读框架文档 CLAUDE.md
- 检查测试报告 http://127.0.0.1:8889
