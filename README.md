# 🚀 Crypto API Test Framework

**Enterprise-grade Data-Driven API Automation Testing Framework** - Designed for cryptocurrency exchanges, supporting both HTTP REST API and WebSocket real-time data stream testing.

## 📋 Table of Contents

- [Framework Overview](#-framework-overview)
- [Installation Guide](#️-installation-guide)
- [Usage Guide](#-usage-guide)
- [Project Structure](#-project-structure)
- [Technology Stack](#-technology-stack)
- [Author](#-author)

## ✨ Framework Overview

### 🎯 Core Features

- **Data-Driven Design** - Complete separation of test logic and test data, configuration as test
- **Dual-Table Design** - Uses PostgreSQL JSONB to store flexible test steps, no frequent schema changes needed
- **Zero-Invasion Extension** - Seamlessly supports HTTP and WebSocket via `protocol` field
- **Enterprise Connection Pool** - Optimized database connection pool (20 base + 10 overflow)

### 🔧 Powerful Capabilities

- ✅ **HTTP REST API Testing** - Complete request/response validation
- ✅ **WebSocket Real-time Testing** - Subscription and push message validation
- ✅ **Database Validation** - Direct query verification for data consistency
- ✅ **Parallel Execution** - pytest-xdist support for multi-process parallelism
- ✅ **Multi-Environment Support** - Flexible environment configuration and routing
- ✅ **Allure Reports** - Professional visual test reporting

## 🛠️ Installation Guide

### 1. Prerequisites

- Python 3.8+
- PostgreSQL 14+
- Virtual environment (recommended)

### 2. Installation Steps

#### 2.1 Clone repository

```bash
git clone https://github.com/Hellen-Zhu/crypto-api-tests.git
cd crypto-api-tests
```

#### 2.2 Create virtual environment

```bash
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

#### 2.3 Install dependencies

```bash
pip install -r requirements.txt
```

## 🚀 Usage Guide

### Basic Commands

```bash
# Run all tests
python run.py

# Run tests for specific environment
python run.py --env uat

# Parallel execution
python run.py --env uat -n 4

# Filter by service
python run.py --env uat --service "exhange_svc"

# Filter by tags
python run.py --env uat --tags "P0,smoke"

# Run specific test case
python run.py --env uat --id 1

# Debug mode
python run.py --env uat --debug-mode
```

### View Test Reports

```bash
# Generate and open Allure report
allure serve reports/allure-report

# Or generate report manually
allure generate reports/allure-results -o reports/allure-report --clean
allure open reports/allure-report -p 8889
```

Report URL: `http://127.0.0.1:8889`

### Advanced Usage

```bash
# Auto-detect CPU cores for parallel execution
python run.py --env uat -n auto

# Combine filter conditions
python run.py --env uat --service "exhange_svc" --tags "P0" --module "authentication"

# Run tests associated with specific Jira
python run.py --env uat --jira "PROJ-123"
```

## 📁 Project Structure

```text
crypto-api-tests/
├── src/                          # Core source code
│   ├── client/                   # Client layer
│   │   ├── api_client.py         # API client
│   │   ├── http_client.py        # HTTP client
│   │   └── websocket_client.py   # WebSocket client
│   ├── database/                 # Data access layer
│   │   ├── handler.py            # Database handler
│   │   ├── models.py             # Data models
│   │   └── result_writer.py     # Result writer
│   ├── engine/                   # Core engine
│   │   ├── assertion_engine.py  # Assertion engine
│   │   ├── context_manager.py   # Context manager
│   │   ├── function_registry.py # Function registry
│   │   └── placeholder_resolver.py # Placeholder resolver
│   └── common/                   # Common components
│       └── logger.py             # Logger configuration
├── tests/                        # Test entry point
│   ├── conftest.py               # Pytest configuration
│   └── test_main.py              # Main test file
├── reports/                      # Test reports
│   ├── allure-results/          # Allure raw data
│   └── allure-report/           # Allure HTML report
├── logs/                         # Log files
├── run.py                        # Main entry point
├── requirements.txt              # Dependencies
└── README.md                     # This document
```

## 🔧 Technology Stack

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

## 👥 Author

**Hellen Zhu** - [GitHub](https://github.com/Hellen-Zhu)
