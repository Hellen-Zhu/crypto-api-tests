# 🚀 Crypto API Test Framework

**Enterprise-grade Data-Driven API Automation Testing Framework** - Designed for cryptocurrency exchanges, supporting both HTTP REST API and WebSocket real-time data stream testing.

## 📋 Table of Contents

- [Core Features](#-core-features)
- [Architecture Design](#-architecture-design)
- [Quick Start](#-quick-start)
- [Usage Guide](#-usage-guide)
- [Project Structure](#-project-structure)

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
- ✅ **Parallel Execution** - pytest-xdist support for multi-process parallelism
- ✅ **Multi-Environment Support** - Flexible environment configuration and routing
- ✅ **Allure Reports** - Professional visual test reporting

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

### 1. Installation

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

### 2. Run Tests

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
python run.py --env uat --service "exchange_svc"

# Filter by tags
python run.py --env uat --tags "P0,smoke"        # P0 and smoke tags
python run.py --env exchange_uat --tags "negative"  # Negative tests

# Run specific test case
python run.py --env uat --id 1             # Run case_id=1

# Parallel execution
python run.py --env exchange_uat -n 4      # 4 workers
python run.py --env uat -n auto            # Auto-detect CPU cores

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
├── scripts/                       # Helper scripts
│   ├── export_candlestick_to_excel.py
│   ├── merge_candlestick_cases.py
│   ├── remove_duplicate_tests.py
│   └── final_stats.py
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

## 👥 Authors

**Hellen Zhu** - [GitHub](https://github.com/Hellen-Zhu)
