# 🚀 Crypto API Test Framework

[![Python](https://img.shields.io/badge/Python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![Pytest](https://img.shields.io/badge/Pytest-7.4.3-green.svg)](https://pytest.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success.svg)]()

**Enterprise-grade Data-Driven API Automation Testing Framework** - Designed for cryptocurrency exchanges, supporting both HTTP REST API and WebSocket real-time data stream testing.

## 📋 Table of Contents

- [Core Features](#-core-features)
- [Architecture Design](#-architecture-design)
- [Quick Start](#-quick-start)
- [Usage Guide](#-usage-guide)
- [Test Case Management](#-test-case-management)
- [WebSocket Testing](#-websocket-testing)
- [Advanced Features](#-advanced-features)
- [Project Structure](#-project-structure)
- [Performance Optimization](#-performance-optimization)
- [Documentation Resources](#-documentation-resources)
- [Contributing](#-contributing)

## ✨ Core Features

### 🎯 Innovative Architecture
- **Data-Driven Design** - Complete separation of test logic and test data, configuration as test
- **2-Table Design** - Uses PostgreSQL JSONB to store flexible test steps, no frequent schema changes needed
- **Zero-Invasion Extension** - Seamlessly supports HTTP and WebSocket via `protocol` field
- **Enterprise Connection Pool** - Optimized database connection pool (20 base + 10 overflow)

### 🔧 Powerful Capabilities
- ✅ **HTTP REST API Testing** - Complete request/response validation
- ✅ **WebSocket Real-time Testing** - Subscription and push message validation
- ✅ **Database Validation** - Direct query verification for data consistency
- ✅ **E2E Flow Testing** - Cross-step variable passing and state management
- ✅ **Parallel Execution** - pytest-xdist support for multi-process parallelism
- ✅ **Multi-Environment Support** - Flexible environment configuration and routing
- ✅ **Allure Reports** - Professional visual test reporting

### 📊 Validation Engine
Supports multiple validation types:
- `expectedStatusCode` - HTTP status code validation
- `body` - JSON response body field validation
- `notNull` / `notExist` - Field existence validation
- `containsText` - Text content validation
- `dbValidation` - Database query validation
- `validation override` - Dataset-level validation override

### 🌟 Smart Features
- **Placeholder Resolution** - `{{@variable}}` for dataset variables, `{{step_X.response.body.field}}` for inter-step passing
- **Variable Extraction** - JSONPath extraction of response data for subsequent steps
- **Logging System** - Loguru colored logs, auto-rotation, separate error storage
- **Debug Mode** - Detailed audit logs written to database

## 🏗️ Architecture Design

### Core Concept

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
              │  │  db_handler.py   │  │ - Database access layer
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │  api_client.py   │  │ - HTTP/WebSocket executor
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │ assertion_engine │  │ - Validation engine
              │  └──────────────────┘  │
              │  ┌──────────────────┐  │
              │  │ context_manager  │  │ - Variable manager
              │  └──────────────────┘  │
              └─────────────────────────┘
                           ↓
                    Allure Reports
```

### Tech Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Test Framework** | Pytest | 7.4.3 | Test execution engine |
| **Database** | PostgreSQL | 14+ | Test data storage |
| **ORM** | SQLAlchemy | 2.0.23 | Database access |
| **HTTP Client** | Requests | 2.31.0 | REST API calls |
| **WebSocket** | websocket-client | 1.7.0 | WebSocket connections |
| **Reporting** | Allure | 2.13.2 | Test report generation |
| **Logging** | Loguru | 0.7.2 | Logging system |
| **Parallel** | pytest-xdist | 3.8.0 | Parallel execution |

## 🚀 Quick Start

### 1. Requirements

- Python 3.12+
- PostgreSQL 14+
- Git

### 2. Installation

```bash
# Clone repository
git clone https://github.com/Hellen-Zhu/crypto-api-tests.git
cd crypto-api-tests

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Database Configuration

Create `.env` file:

```bash
# Database configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_NAME=apitest
DB_PASSWORD=your_password

# Connection pool configuration (optional)
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=3600

# Test environment
TEST_ENV=uat
PYTEST_PARALLEL_WORKERS=2
```

### 4. Initialize Database

```bash
# Execute database migration scripts
psql -h localhost -p 5432 -U postgres -d apitest -f database/migrations/rebuild_test_environments_final.sql

# Import sample test cases
psql -h localhost -p 5432 -U postgres -d apitest -f database/examples/example_user_management.sql
psql -h localhost -p 5432 -U postgres -d apitest -f database/examples/example_get_candlestick.sql
psql -h localhost -p 5432 -U postgres -d apitest -f database/examples/example_websocket_ticker_mvp.sql
```

### 5. Run Tests

```bash
# Run all tests
python run.py

# Run tests for specific environment
python run.py --env uat

# Parallel execution
python run.py --env exchange_uat -n 4

# View test report
allure serve reports/allure-report
```

## 📖 Usage Guide

### Basic Commands

```bash
# Run by environment
python run.py --env uat                    # UAT environment
python run.py --env exchange_uat           # Exchange UAT environment

# Filter by service/module
python run.py --env uat --service "user_svc"
python run.py --env exchange_uat --module "Market Data"

# Filter by tags
python run.py --env uat --tags "P0,smoke"        # P0 and smoke tags
python run.py --env exchange_uat --tags "negative"  # Negative tests

# Run specific test case
python run.py --env uat --id 1             # Run case_id=1
python run.py --env uat --jira "PROJ-123"  # Run by Jira ID

# Parallel execution
python run.py --env exchange_uat -n 4      # 4 workers
python run.py --env uat -n auto            # Auto-detect CPU cores

# Debug mode
python run.py --env uat --debug-mode       # Write detailed audit logs to database
```

### View Test Reports

After test execution, Allure report is automatically generated:

```bash
# Method 1: Auto-open browser
allure serve reports/allure-report

# Method 2: Generate and manually open
allure generate reports/allure-results -o reports/allure-report --clean
allure open reports/allure-report -p 8889
```

Report URL: `http://127.0.0.1:8889`

## 🗄️ Test Case Management

### Create New Test Case

#### Method 1: Using SQL Template

```sql
-- 1. Create test case
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

-- 2. Create dataset
INSERT INTO case_data_sets (case_id, data_set_name, variables, environments, is_active)
VALUES (
    1,  -- Replace with id returned above
    'Valid Admin Login',
    '{"username": "admin", "password": "admin123"}'::jsonb,
    ARRAY['uat', 'dev'],
    true
);
```

#### Method 2: Using Python Scripts

Refer to example scripts in `scripts/` directory.

### Manage Test Data

```bash
# Export test cases to Excel
python scripts/export_candlestick_to_excel.py

# Clean duplicate tests
python scripts/remove_duplicate_tests.py

# Merge test cases
python scripts/merge_candlestick_cases.py

# View test statistics
python scripts/final_stats.py
```

### SQL Quick Queries

```sql
-- View all test cases
SELECT id, name, service, module, tags 
FROM api_auto_cases 
ORDER BY id;

-- View test datasets
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

-- View environment configuration
SELECT name, base_url, services 
FROM test_environments 
WHERE is_active = true;

-- Filter by tags
SELECT id, name, tags 
FROM api_auto_cases 
WHERE tags @> ARRAY['P0'];
```

## 🌐 WebSocket Testing

Framework fully supports WebSocket real-time data stream testing.

### WebSocket Test Example

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

### WebSocket Supported Actions

| Action | Description | Parameters |
|--------|-------------|-----------|
| `connect` | Establish WebSocket connection | `url`, `timeout` |
| `send` | Send message | `message` (JSON) |
| `wait` | Wait for messages | `message_count`, `timeout`, `validations`, `outputs` |
| `disconnect` | Close connection | None |

### Run WebSocket Tests

```bash
# Run all WebSocket tests
python run.py --env exchange_uat --tags websocket

# Run positive tests
python run.py --env exchange_uat --tags websocket,smoke

# Run negative tests
python run.py --env exchange_uat --tags websocket,negative
```

## 🎯 Advanced Features

### 1. Variable Passing Mechanism

#### Dataset Variables
```json
{
  "variables": {
    "username": "admin",
    "password": "admin123"
  }
}
```
Usage: `{{@username}}`

#### Inter-Step Passing
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
Usage: `{{step_1.response.body.data.userId}}`

### 2. Validation Override

Override default validation rules in dataset:

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

### 3. Database Validation

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

### 4. Mixed Protocol Testing

Single test case can include both HTTP and WebSocket steps:

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

## 📁 Project Structure

```
crypto-api-tests/
├── core/                          # Core engine
│   ├── api_client.py             # HTTP/WebSocket executor
│   ├── websocket_client.py       # WebSocket client
│   ├── assertion_engine.py       # Validation engine
│   ├── context_manager.py        # Variable context manager
│   ├── db_handler.py             # Database access layer
│   ├── result_writer.py          # Result writer
│   └── logger_config.py          # Logging configuration
│
├── tests/                         # Test entry
│   ├── conftest.py               # Pytest config and fixtures
│   └── test_main.py              # Main test file
│
├── models/                        # Data models
│   └── tables.py                 # SQLAlchemy ORM models
│
├── utils/                         # Utility functions
│   └── placeholder_parser.py     # Placeholder resolver
│
├── database/                      # Database related
│   ├── examples/                 # SQL examples
│   │   ├── example_user_management.sql
│   │   ├── example_get_candlestick.sql
│   │   └── example_websocket_ticker_mvp.sql
│   ├── migrations/               # Database migrations
│   ├── templates/                # SQL templates
│   └── README.md                 # Database documentation
│
├── scripts/                       # Helper scripts
│   ├── export_candlestick_to_excel.py
│   ├── merge_candlestick_cases.py
│   ├── remove_duplicate_tests.py
│   └── final_stats.py
│
├── docs/                          # Documentation
│   ├── FINAL_COMPLETION_REPORT.md
│   ├── DB_POOL_OPTIMIZATION.md
│   ├── ENVIRONMENT_SERVICE_ROUTING_IMPLEMENTATION.md
│   └── candlestick_test_design.md
│
├── reports/                       # Test reports
│   ├── allure-results/           # Allure raw data
│   └── allure-report/            # Allure HTML report
│
├── logs/                          # Log files
│   ├── framework_*.log           # Framework logs
│   └── errors_*.log              # Error logs
│
├── run.py                         # Main entry point
├── requirements.txt               # Python dependencies
├── .env                          # Environment config (to be created)
└── README.md                     # This document
```

## ⚡ Performance Optimization

### Database Connection Pool Optimization

Framework uses optimized connection pool configuration:

```python
# Default configuration
pool_size = 20              # Base connections
max_overflow = 10           # Max overflow connections
pool_timeout = 30           # Connection timeout (seconds)
pool_recycle = 3600         # Connection recycle time (seconds)
pool_pre_ping = True        # Pre-ping before checkout
```

Configure via environment variables:

```bash
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=3600
```

### Parallel Execution Optimization

```bash
# Auto-adjust based on CPU cores
python run.py -n auto

# Specify worker count
python run.py -n 4

# Recommended configuration
# - Small scale (< 20 tests): -n 2
# - Medium scale (20-100 tests): -n 4
# - Large scale (> 100 tests): -n 8 or auto
```

### Performance Metrics

| Metric | Value |
|--------|-------|
| Single HTTP test | ~0.1-0.3s |
| Single WebSocket test | ~0.4s |
| 16 tests parallel execution | ~5.4s |
| DB connection pool utilization | ~20% |
| Recommended concurrent workers | 2-8 |

## 📚 Documentation Resources

### Core Documentation
- [Database Usage Guide](database/README.md)
- [Test Framework Completion Report](docs/FINAL_COMPLETION_REPORT.md)
- [Database Connection Pool Optimization](docs/DB_POOL_OPTIMIZATION.md)
- [Environment Service Routing](docs/ENVIRONMENT_SERVICE_ROUTING_IMPLEMENTATION.md)
- [Candlestick Test Design](docs/candlestick_test_design.md)

### SQL Examples
- [User Management Tests](database/examples/example_user_management.sql)
- [Candlestick Data Tests](database/examples/example_get_candlestick.sql)
- [WebSocket Ticker Tests](database/examples/example_websocket_ticker_mvp.sql)
- [WebSocket Negative Tests](database/examples/example_websocket_negative_tests.sql)

### Quick Reference
- [SQL Quick Reference](database/quick_reference.sql)
- [Test Case Template](database/templates/new_test_case_template.sql)

## 🎓 Best Practices

### 1. Test Case Design
- ✅ Use clear naming conventions
- ✅ Properly use tags for classification (P0/P1/P2, smoke/regression)
- ✅ Separate positive and negative tests
- ✅ Cover boundary value testing

### 2. Dataset Management
- ✅ One test case corresponds to multiple datasets
- ✅ Use `is_active` to control dataset enable/disable
- ✅ Use `environments` to associate test environments
- ✅ Use `validations_override` to override validations for specific scenarios

### 3. Environment Configuration
- ✅ Use different environments for different services
- ✅ Precise base_url to service level
- ✅ Manage sensitive info via environment variables

### 4. Validation Rules
- ✅ Configure validations based on actual API behavior
- ✅ Test first, then configure - avoid assumptions
- ✅ Use curl to verify boundary scenarios

### 5. Debugging Tips
- ✅ Use `--debug-mode` for detailed logs
- ✅ Check log files in `logs/` directory
- ✅ Review Allure report for request/response details
- ✅ Query test result audit in database

## 🤝 Contributing

### Branch Management

- `main` - Stable version
- `websocket` - WebSocket feature development
- `feature/*` - New feature development
- `bugfix/*` - Bug fixes

### Commit Convention

```bash
# Feature development
git commit -m "✨ feat: Add new feature description"

# Bug fix
git commit -m "🐛 fix: Fix issue description"

# Documentation update
git commit -m "📝 docs: Update documentation"

# Performance optimization
git commit -m "⚡ perf: Performance optimization description"

# Code refactoring
git commit -m "♻️ refactor: Refactoring description"
```

### Development Workflow

1. Fork the project
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m '✨ feat: Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

## 📊 Test Coverage

### Current Test Statistics

- **Total Test Cases**: 20+
- **HTTP Tests**: 15+
- **WebSocket Tests**: 12+
- **Pass Rate**: 100%
- **API Endpoints Covered**: 10+

### Test Scenarios

| Type | Count | Description |
|------|-------|-------------|
| Normal Flow Tests | 8 | Happy Path |
| Negative Tests | 10 | Error Handling |
| Boundary Tests | 5 | Edge Cases |
| E2E Tests | 3 | End-to-End Flow |

## 🔍 Troubleshooting

### Common Issues

**Q: Database connection failed**
```bash
# Check environment variables
cat .env

# Test database connection
psql -h localhost -p 5432 -U postgres -d apitest
```

**Q: Tests not found**
```sql
-- Check if datasets are active
SELECT * FROM case_data_sets WHERE is_active = false;

-- Check environment configuration
SELECT * FROM test_environments;
```

**Q: WebSocket connection timeout**
```bash
# Check network connection
curl -I wss://uat-stream.3ona.co/exchange/v1/market

# Increase timeout
# Set larger timeout value in step
```

**Q: Parallel execution failed**
```bash
# Reduce worker count
python run.py -n 2

# Check database connection pool config
# Ensure DB_POOL_SIZE >= worker count
```

## 📝 Changelog

### v2.0.0 (2025-10-13) - WebSocket Support
- ✨ Added WebSocket testing support
- ✨ Implemented environment service routing
- 🔧 Optimized database connection pool
- 📚 Enhanced documentation system

### v1.0.0 (2025-10-12) - Initial Release
- ✨ Migrated from Behave to Pytest
- ✨ Implemented 2-table design architecture
- ✨ Integrated Allure reporting
- ✨ Added Loguru logging system

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

**Hellen Zhu** - [GitHub](https://github.com/Hellen-Zhu)

## 🙏 Acknowledgments

- Pytest Community
- Allure Report System
- SQLAlchemy Team
- All Contributors

## 📞 Contact

- Project Homepage: https://github.com/Hellen-Zhu/crypto-api-tests
- Issue Tracker: https://github.com/Hellen-Zhu/crypto-api-tests/issues

---

⭐ If this project helps you, please give us a Star!
