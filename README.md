# 🚀 Crypto API Test Framework

[![Python](https://img.shields.io/badge/Python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![Pytest](https://img.shields.io/badge/Pytest-7.4.3-green.svg)](https://pytest.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)]()

**企业级数据驱动API自动化测试框架** - 专为加密货币交易所设计，支持 HTTP REST API 和 WebSocket 实时数据流测试。

## 📋 目录

- [核心特性](#-核心特性)
- [架构设计](#-架构设计)
- [快速开始](#-快速开始)
- [使用指南](#-使用指南)
- [测试用例管理](#-测试用例管理)
- [WebSocket测试](#-websocket测试)
- [高级功能](#-高级功能)
- [项目结构](#-项目结构)
- [性能优化](#-性能优化)
- [文档资源](#-文档资源)
- [贡献指南](#-贡献指南)

## ✨ 核心特性

### 🎯 创新架构
- **数据驱动设计** - 测试逻辑与测试数据完全分离，配置即测试
- **2表设计** - 使用 PostgreSQL JSONB 存储灵活的测试步骤，无需频繁修改表结构
- **零侵入扩展** - 通过 `protocol` 字段无缝支持 HTTP 和 WebSocket
- **企业级连接池** - 优化的数据库连接池（20基础+10溢出）

### 🔧 强大功能
- ✅ **HTTP REST API 测试** - 完整的请求/响应验证
- ✅ **WebSocket 实时测试** - 订阅、推送消息验证
- ✅ **数据库验证** - 直接查询验证数据一致性
- ✅ **E2E 流程测试** - 跨步骤变量传递和状态管理
- ✅ **并行执行** - pytest-xdist 支持多进程并行
- ✅ **多环境支持** - 灵活的环境配置和路由
- ✅ **Allure 报告** - 专业的可视化测试报告

### 📊 验证引擎
支持多种验证类型：
- `expectedStatusCode` - HTTP 状态码验证
- `body` - JSON 响应体字段验证
- `notNull` / `notExist` - 字段存在性验证
- `containsText` - 文本包含验证
- `dbValidation` - 数据库查询验证
- `validation override` - 数据集级别的验证覆盖

### 🌟 智能特性
- **占位符解析** - `{{@variable}}` 数据集变量，`{{step_X.response.body.field}}` 步骤间传递
- **变量提取** - JSONPath 提取响应数据供后续步骤使用
- **日志系统** - Loguru 彩色日志，自动轮转，错误单独存储
- **调试模式** - 详细的审计日志写入数据库

## 🏗️ 架构设计

### 核心理念

```
┌─────────────────────────────────────────────────────────┐
│                   PostgreSQL Database                    │
│  ┌─────────────────┐  ┌──────────────────────────────┐ │
│  │ api_auto_cases  │  │     case_data_sets          │ │
│  │                 │  │                              │ │
│  │ - id            │  │ - case_id (FK)              │ │
│  │ - name          │  │ - data_set_name             │ │
│  │ - service       │  │ - variables (JSONB)         │ │
│  │ - module        │  │ - validations_override      │ │
│  │ - tags[]        │  │ - environments[]            │ │
│  │ - parameters    │  │ - is_active                 │ │
│  │   (JSONB)       │  └──────────────────────────────┘ │
│  │   ├─ steps[]    │                                   │
│  │   │  ├─ protocol│           ┌─────────────────┐    │
│  │   │  ├─ method │           │ test_environments│    │
│  │   │  ├─ path   │           │                  │    │
│  │   │  ├─ params │           │ - name           │    │
│  │   │  ├─ body   │           │ - base_url       │    │
│  │   │  ├─ validations        │ - services[]     │    │
│  │   │  └─ outputs│           │ - is_active      │    │
│  └─────────────────┘           └─────────────────┘    │
└─────────────────────────────────────────────────────────┘
                           ↓
              ┌─────────────────────────┐
              │   Python Test Engine    │
              │                         │
              │  ┌──────────────────┐  │
              │  │  db_handler.py   │  │ - 数据库访问层
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │  api_client.py   │  │ - HTTP/WebSocket执行
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │ assertion_engine │  │ - 验证引擎
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │ context_manager  │  │ - 变量管理
              │  └──────────────────┘  │
              └─────────────────────────┘
                           ↓
                    Allure Reports
```

### 技术栈

| 组件 | 技术 | 版本 | 用途 |
|-----|------|------|------|
| **测试框架** | Pytest | 7.4.3 | 测试执行引擎 |
| **数据库** | PostgreSQL | 14+ | 测试数据存储 |
| **ORM** | SQLAlchemy | 2.0.23 | 数据库访问 |
| **HTTP客户端** | Requests | 2.31.0 | REST API调用 |
| **WebSocket** | websocket-client | 1.7.0 | WebSocket连接 |
| **报告** | Allure | 2.13.2 | 测试报告生成 |
| **日志** | Loguru | 0.7.2 | 日志系统 |
| **并行** | pytest-xdist | 3.8.0 | 并行执行 |

## 🚀 快速开始

### 1. 环境要求

- Python 3.12+
- PostgreSQL 14+
- Git

### 2. 安装步骤

```bash
# 克隆仓库
git clone https://github.com/Hellen-Zhu/crypto-api-tests.git
cd crypto-api-tests

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

### 3. 配置数据库

创建 `.env` 文件：

```bash
# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_NAME=apitest
DB_PASSWORD=your_password

# 连接池配置（可选）
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=3600

# 测试环境
TEST_ENV=uat
PYTEST_PARALLEL_WORKERS=2
```

### 4. 初始化数据库

```bash
# 执行数据库迁移脚本
psql -h localhost -p 5432 -U postgres -d apitest -f database/migrations/rebuild_test_environments_final.sql

# 导入示例测试用例
psql -h localhost -p 5432 -U postgres -d apitest -f database/examples/example_user_management.sql
psql -h localhost -p 5432 -U postgres -d apitest -f database/examples/example_get_candlestick.sql
psql -h localhost -p 5432 -U postgres -d apitest -f database/examples/example_websocket_ticker_mvp.sql
```

### 5. 运行测试

```bash
# 运行所有测试
python run.py

# 运行特定环境的测试
python run.py --env uat

# 并行执行
python run.py --env exchange_uat -n 4

# 查看测试报告
allure serve reports/allure-report
```

## 📖 使用指南

### 基本命令

```bash
# 按环境运行
python run.py --env uat                    # UAT环境
python run.py --env exchange_uat           # Exchange UAT环境

# 按服务/模块筛选
python run.py --env uat --service "user_svc"
python run.py --env exchange_uat --module "Market Data"

# 按标签筛选
python run.py --env uat --tags "P0,smoke"        # P0 和 smoke 标签
python run.py --env exchange_uat --tags "negative"  # 负面测试

# 运行特定测试用例
python run.py --env uat --id 1             # 运行 case_id=1
python run.py --env uat --jira "PROJ-123"  # 按Jira ID运行

# 并行执行
python run.py --env exchange_uat -n 4      # 4个worker
python run.py --env uat -n auto            # 自动检测CPU核心数

# Debug模式
python run.py --env uat --debug-mode       # 详细审计日志写入数据库
```

### 查看测试报告

测试执行完成后，Allure 报告自动生成：

```bash
# 方法1: 自动打开浏览器
allure serve reports/allure-report

# 方法2: 生成并手动打开
allure generate reports/allure-results -o reports/allure-report --clean
allure open reports/allure-report -p 8889
```

报告访问地址：`http://127.0.0.1:8889`

## 🗄️ 测试用例管理

### 创建新测试用例

#### 方法1: 使用 SQL 模板

```sql
-- 1. 创建测试用例
INSERT INTO api_auto_cases (name, service, module, component, tags, parameters)
VALUES (
    'User Login Test',
    'user_svc',
    'Authentication',
    'Login',
    ARRAY['P0', 'smoke'],
    '{
      "steps": [
        {
          "step_order": 1,
          "protocol": "http",
          "method": "POST",
          "path": "/api/user/login",
          "headers": {"Content-Type": "application/json"},
          "body": {
            "username": "{{@username}}",
            "password": "{{@password}}"
          },
          "validations": {
            "expectedStatusCode": 200,
            "notNull": ["$.token", "$.userId"],
            "body": {"success": true}
          },
          "outputs": [
            {
              "variable_name": "auth_token",
              "source": "response_body",
              "json_path": "$.token"
            }
          ]
        }
      ]
    }'::jsonb
) RETURNING id;

-- 2. 创建数据集
INSERT INTO case_data_sets (case_id, data_set_name, variables, environments, is_active)
VALUES (
    1,  -- 替换为上面返回的id
    'Valid Admin Login',
    '{"username": "admin", "password": "admin123"}'::jsonb,
    ARRAY['uat', 'dev'],
    true
);
```

#### 方法2: 使用 Python 脚本

参考 `scripts/` 目录下的示例脚本。

### 管理测试数据

```bash
# 导出测试用例到 Excel
python scripts/export_candlestick_to_excel.py

# 清理重复测试
python scripts/remove_duplicate_tests.py

# 合并测试用例
python scripts/merge_candlestick_cases.py

# 查看测试统计
python scripts/final_stats.py
```

### SQL 快速查询

```sql
-- 查看所有测试用例
SELECT id, name, service, module, tags 
FROM api_auto_cases 
ORDER BY id;

-- 查看测试数据集
SELECT 
    ac.id as case_id,
    ac.name as case_name,
    cds.id as dataset_id,
    cds.data_set_name,
    cds.variables,
    cds.is_active
FROM api_auto_cases ac
JOIN case_data_sets cds ON cds.case_id = ac.id
ORDER BY ac.id, cds.id;

-- 查看环境配置
SELECT name, base_url, services 
FROM test_environments 
WHERE is_active = true;

-- 按标签筛选
SELECT id, name, tags 
FROM api_auto_cases 
WHERE tags @> ARRAY['P0'];
```

## 🌐 WebSocket测试

框架完整支持 WebSocket 实时数据流测试。

### WebSocket 测试示例

```sql
INSERT INTO api_auto_cases (name, service, module, tags, parameters)
VALUES (
    'WebSocket Ticker Subscription',
    'exchange_svc',
    'Market Data - WebSocket',
    ARRAY['P1', 'websocket', 'smoke'],
    '{
      "steps": [
        {
          "step_order": 1,
          "protocol": "websocket",
          "action": "connect",
          "url": "wss://uat-stream.3ona.co/exchange/v1/market",
          "timeout": 10
        },
        {
          "step_order": 2,
          "protocol": "websocket",
          "action": "send",
          "message": {
            "id": 1,
            "method": "subscribe",
            "params": {
              "channels": ["ticker.{{@instrument}}"]
            }
          }
        },
        {
          "step_order": 3,
          "protocol": "websocket",
          "action": "wait",
          "message_count": 1,
          "timeout": 30,
          "validations": {
            "notNull": ["$.code", "$.result"],
            "body": {"code": 0, "method": "subscribe"}
          },
          "outputs": [
            {
              "variable_name": "latest_price",
              "source": "response_body",
              "json_path": "$.result.data[0].a"
            }
          ]
        },
        {
          "step_order": 4,
          "protocol": "websocket",
          "action": "disconnect"
        }
      ]
    }'::jsonb
);
```

### WebSocket 支持的操作

| Action | 说明 | 参数 |
|--------|------|------|
| `connect` | 建立WebSocket连接 | `url`, `timeout` |
| `send` | 发送消息 | `message` (JSON) |
| `wait` | 等待接收消息 | `message_count`, `timeout`, `validations`, `outputs` |
| `disconnect` | 断开连接 | 无 |

### 运行 WebSocket 测试

```bash
# 运行所有WebSocket测试
python run.py --env exchange_uat --tags websocket

# 运行正面测试
python run.py --env exchange_uat --tags websocket,smoke

# 运行负面测试
python run.py --env exchange_uat --tags websocket,negative
```

## 🎯 高级功能

### 1. 变量传递机制

#### 数据集变量
```json
{
  "variables": {
    "username": "admin",
    "password": "admin123"
  }
}
```
使用：`{{@username}}`

#### 步骤间传递
```json
{
  "outputs": [
    {
      "variable_name": "user_id",
      "source": "response_body",
      "json_path": "$.data.userId"
    }
  ]
}
```
使用：`{{step_1.response.body.data.userId}}`

### 2. Validation Override

在数据集中覆盖默认验证规则：

```json
{
  "validations_override": {
    "1": {
      "expectedStatusCode": 400,
      "body": {"code": 10001}
    }
  }
}
```

### 3. 数据库验证

```json
{
  "validations": {
    "dbValidation": [
      {
        "query": "SELECT * FROM users WHERE username = '{{@username}}'",
        "expected": {"count": 1}
      }
    ]
  }
}
```

### 4. 混合协议测试

单个测试用例可同时包含 HTTP 和 WebSocket 步骤：

```json
{
  "steps": [
    {
      "step_order": 1,
      "protocol": "http",
      "method": "POST",
      "path": "/api/login",
      ...
    },
    {
      "step_order": 2,
      "protocol": "websocket",
      "action": "connect",
      ...
    }
  ]
}
```

## 📁 项目结构

```
crypto-api-tests/
├── core/                          # 核心引擎
│   ├── api_client.py             # HTTP/WebSocket执行引擎
│   ├── websocket_client.py       # WebSocket客户端
│   ├── assertion_engine.py       # 验证引擎
│   ├── context_manager.py        # 变量上下文管理
│   ├── db_handler.py             # 数据库访问层
│   ├── result_writer.py          # 结果写入
│   └── logger_config.py          # 日志配置
│
├── tests/                         # 测试入口
│   ├── conftest.py               # Pytest配置和fixtures
│   └── test_main.py              # 主测试文件
│
├── models/                        # 数据模型
│   └── tables.py                 # SQLAlchemy ORM模型
│
├── utils/                         # 工具函数
│   └── placeholder_parser.py     # 占位符解析
│
├── database/                      # 数据库相关
│   ├── examples/                 # SQL示例
│   │   ├── example_user_management.sql
│   │   ├── example_get_candlestick.sql
│   │   └── example_websocket_ticker_mvp.sql
│   ├── migrations/               # 数据库迁移
│   ├── templates/                # SQL模板
│   └── README.md                 # 数据库文档
│
├── scripts/                       # 辅助脚本
│   ├── export_candlestick_to_excel.py
│   ├── merge_candlestick_cases.py
│   ├── remove_duplicate_tests.py
│   └── final_stats.py
│
├── docs/                          # 文档
│   ├── FINAL_COMPLETION_REPORT.md
│   ├── DB_POOL_OPTIMIZATION.md
│   ├── ENVIRONMENT_SERVICE_ROUTING_IMPLEMENTATION.md
│   └── candlestick_test_design.md
│
├── reports/                       # 测试报告
│   ├── allure-results/           # Allure原始数据
│   └── allure-report/            # Allure HTML报告
│
├── logs/                          # 日志文件
│   ├── framework_*.log           # 框架日志
│   └── errors_*.log              # 错误日志
│
├── run.py                         # 主入口
├── requirements.txt               # Python依赖
├── .env                          # 环境配置（需创建）
└── README.md                     # 本文档
```

## ⚡ 性能优化

### 数据库连接池优化

框架使用优化的连接池配置：

```python
# 默认配置
pool_size = 20              # 基础连接数
max_overflow = 10           # 最大溢出连接
pool_timeout = 30           # 获取连接超时(秒)
pool_recycle = 3600         # 连接回收时间(秒)
pool_pre_ping = True        # 连接前检测
```

可通过环境变量调整：

```bash
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=3600
```

### 并行执行优化

```bash
# 根据CPU核心数自动调整
python run.py -n auto

# 指定worker数量
python run.py -n 4

# 建议配置
# - 小规模测试(< 20个): -n 2
# - 中规模测试(20-100个): -n 4
# - 大规模测试(> 100个): -n 8 或 auto
```

### 性能指标

| 指标 | 数值 |
|-----|------|
| 单个HTTP测试 | ~0.1-0.3s |
| 单个WebSocket测试 | ~0.4s |
| 16个测试并行执行 | ~5.4s |
| 数据库连接池利用率 | ~20% |
| 并发worker推荐 | 2-8 |

## 📚 文档资源

### 核心文档
- [数据库使用指南](database/README.md)
- [测试框架完成报告](docs/FINAL_COMPLETION_REPORT.md)
- [数据库连接池优化](docs/DB_POOL_OPTIMIZATION.md)
- [环境服务路由实现](docs/ENVIRONMENT_SERVICE_ROUTING_IMPLEMENTATION.md)
- [Candlestick测试设计](docs/candlestick_test_design.md)

### SQL示例
- [用户管理测试](database/examples/example_user_management.sql)
- [K线数据测试](database/examples/example_get_candlestick.sql)
- [WebSocket Ticker测试](database/examples/example_websocket_ticker_mvp.sql)
- [WebSocket负面测试](database/examples/example_websocket_negative_tests.sql)

### 快速参考
- [SQL快速参考](database/quick_reference.sql)
- [测试用例模板](database/templates/new_test_case_template.sql)

## 🎓 最佳实践

### 1. 测试用例设计
- ✅ 使用清晰的命名约定
- ✅ 合理使用标签分类（P0/P1/P2, smoke/regression）
- ✅ 正面测试和负面测试分离
- ✅ 边界值测试覆盖

### 2. 数据集管理
- ✅ 一个测试用例对应多个数据集
- ✅ 使用 `is_active` 控制数据集启用/禁用
- ✅ 使用 `environments` 关联测试环境
- ✅ 使用 `validations_override` 覆盖特定场景的验证

### 3. 环境配置
- ✅ 不同服务使用不同环境
- ✅ base_url 精确到服务级别
- ✅ 使用环境变量管理敏感信息

### 4. 验证规则
- ✅ 基于实际API行为配置验证
- ✅ 先测试后配置，避免假设
- ✅ 使用curl验证边界场景

### 5. 调试技巧
- ✅ 使用 `--debug-mode` 查看详细日志
- ✅ 检查 `logs/` 目录的日志文件
- ✅ 查看 Allure 报告的请求/响应详情
- ✅ 在数据库中查询测试结果审计

## 🤝 贡献指南

### 分支管理

- `main` - 稳定版本
- `websocket` - WebSocket功能开发
- `feature/*` - 新功能开发
- `bugfix/*` - Bug修复

### 提交规范

```bash
# 功能开发
git commit -m "✨ feat: 添加新功能描述"

# Bug修复
git commit -m "🐛 fix: 修复问题描述"

# 文档更新
git commit -m "📝 docs: 更新文档"

# 性能优化
git commit -m "⚡ perf: 性能优化描述"

# 代码重构
git commit -m "♻️ refactor: 重构描述"
```

### 开发流程

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m '✨ feat: Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📊 测试覆盖

### 当前测试统计

- **总测试用例**: 20+
- **HTTP测试**: 15+
- **WebSocket测试**: 12+
- **通过率**: 100%
- **覆盖的API端点**: 10+

### 测试场景

| 类型 | 数量 | 说明 |
|-----|------|------|
| 正常流程测试 | 8 | Happy Path |
| 负面测试 | 10 | 错误处理 |
| 边界测试 | 5 | Edge Cases |
| E2E测试 | 3 | 端到端流程 |

## 🔍 故障排查

### 常见问题

**Q: 数据库连接失败**
```bash
# 检查环境变量
cat .env

# 测试数据库连接
psql -h localhost -p 5432 -U postgres -d apitest
```

**Q: 测试无法找到**
```sql
-- 检查数据集是否激活
SELECT * FROM case_data_sets WHERE is_active = false;

-- 检查环境配置
SELECT * FROM test_environments;
```

**Q: WebSocket连接超时**
```bash
# 检查网络连接
curl -I wss://uat-stream.3ona.co/exchange/v1/market

# 增加超时时间
# 在步骤中设置更大的 timeout 值
```

**Q: 并行执行失败**
```bash
# 减少worker数量
python run.py -n 2

# 检查数据库连接池配置
# 确保 DB_POOL_SIZE >= worker数量
```

## 📝 更新日志

### v2.0.0 (2025-10-13) - WebSocket 支持
- ✨ 新增 WebSocket 测试支持
- ✨ 实现环境服务路由
- 🔧 优化数据库连接池
- 📚 完善文档体系

### v1.0.0 (2025-10-12) - 初始版本
- ✨ 从 Behave 迁移到 Pytest
- ✨ 实现 2表设计架构
- ✨ 集成 Allure 报告
- ✨ 添加 Loguru 日志系统

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 作者

**Hellen Zhu** - [GitHub](https://github.com/Hellen-Zhu)

## 🙏 致谢

- Pytest 社区
- Allure 报告系统
- SQLAlchemy 团队
- 所有贡献者

## 📞 联系方式

- 项目主页: https://github.com/Hellen-Zhu/crypto-api-tests
- 问题反馈: https://github.com/Hellen-Zhu/crypto-api-tests/issues

---

⭐ 如果这个项目对您有帮助，请给我们一个 Star！

