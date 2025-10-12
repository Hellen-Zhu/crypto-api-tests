# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an enterprise-grade, data-driven API automation testing framework built with Python, Pytest, SQLAlchemy, and PostgreSQL. The framework follows a unique architecture where test logic, test flows, and test data are completely separated and stored in a database, enabling "configuration-as-test" capabilities.

## Key Commands

### Environment Setup
```bash
# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure database connection
# Edit .env file to set DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME

```

### Running Tests
```bash
# Basic test execution
python run.py 

# Run by service/module/component
python run.py  --service "User Management" --module "Authentication"

# Run by tags (comma-separated)
python run.py  --tags "P0,smoke"

# Run specific test case by ID
python run.py  --id 123

# Run by Jira ID
python run.py  --jira "PROJ-456"

# Run with parallel execution
python run.py  -n 4
python run.py  -n auto

# Run with debug mode (writes detailed step logs to database)
python run.py  --debug-mode

# View Allure report (generated automatically after test run)
allure serve reports/allure-report
```

### Direct Pytest Execution
```bash
# Run tests directory (not recommended - use run.py instead)
pytest tests/test_main.py -v --env=dev --alluredir=reports/allure-results

# Generate Allure report manually
allure generate reports/allure-results -o reports/allure-report --clean
```

## Architecture Overview

### Data-Driven Design Philosophy

The framework follows a **database-first** approach where all test configurations are stored in PostgreSQL using a **2-table design**:

1. **Test Templates** (`api_auto_cases`): Define the high-level test case structure (service, module, tags) and all test steps in a JSONB `parameters` column
2. **Data Sets** (`case_data_sets`): Parameterization layer providing input variables and validation overrides
3. **Test Environments** (`test_environments`): Environment-specific configurations (base_url, db connections)

### 2-Table Design Architecture

All test steps are stored directly in the `api_auto_cases.parameters` JSONB column, which contains:
- `steps`: Array of step objects, each with request details (method, path, headers, params, body), validations, and outputs
- Each step is self-contained with no external references

The `db_handler.get_case_details()` function reads the test case and data set, then returns a unified structure for execution.

### Core Components

**[core/db_handler.py](core/db_handler.py)**: Database access layer
- `initialize_session()`: Creates SQLAlchemy session factory
- `get_test_cases_by_filter()`: Queries test cases based on CLI filters
- `get_case_details()`: Assembles complete test case from database (2-table design)

**[core/api_client.py](core/api_client.py)**: Test execution engine (stateful class)
- `execute_steps()`: Main orchestration method that drives test workflow
- Maintains `self.session` (requests.Session) for TCP connection reuse
- Maintains `self.audit_trail` list for debug logging
- Handles placeholder resolution, request sending, validation routing, and variable extraction

**[core/assertion_engine.py](core/assertion_engine.py)**: Keyword-driven validation engine (stateful class)
- `execute_assertions()`: Main dispatcher that routes to specific assertion methods
- Supports: `expectedStatusCode`, `body`, `containsText`, `notNull`, `notExist`, `dbValidation`
- Performs "just-in-time parsing" of placeholders in validation rules

**[core/context_manager.py](core/context_manager.py)**: Inter-step variable storage (stateful class)
- `TestContext` class maintains `self.storage` dictionary for passing data between steps
- Supports JSONPath-based variable extraction

**[utils/placeholder_parser.py](utils/placeholder_parser.py)**: Variable resolution utility (stateless functions)
- Resolves three types of placeholders in correct priority order:
  1. `{{$randomUser}}` - Dynamic variables (generated once and cached in context)
  2. `{{@variableName}}` - Data set variables (from `case_data_sets.variables`)
  3. `{{step_1.body.token}}` - Inter-step variables (from context)

**[core/result_writer.py](core/result_writer.py)**: Database result persistence
- Writes test results to `auto_progress`, `auto_case_audit`, `auto_test_audit` tables

**[models/tables.py](models/tables.py)**: SQLAlchemy ORM definitions for all database tables

**[tests/conftest.py](tests/conftest.py)**: Pytest configuration and fixtures
- `pytest_sessionstart()`: Initializes database and creates run summary record
- `pytest_generate_tests()`: This is where test discovery happens - do NOT modify this hook lightly
- `pytest_runtest_makereport()`: Writes individual test results to database
- Fixtures: `db_session_factory`, `test_environment`, `base_url`, `app_db_connection`, `api_client`

**[tests/test_main.py](tests/test_main.py)**: Single test template method
- `pytest_generate_tests()`: Queries database and parametrizes test cases dynamically
- `test_run_case()`: Template method that gets called once per data set

### Critical Execution Flow

1. User runs: `python run.py  --tags "smoke"`
2. `run.py` passes arguments to pytest via `pytest.main()`
3. `conftest.py::pytest_sessionstart()` initializes database session factory and creates run summary
4. `test_main.py::pytest_generate_tests()` queries database for matching test cases
5. Pytest parametrizes `test_run_case()` method with each (case_id, data_set_id) tuple
6. For each test:
   - `db_handler.get_case_details()` assembles complete test case
   - `api_client.execute_steps()` orchestrates execution:
     - `placeholder_parser.resolve_placeholders()` resolves variables
     - Sends HTTP request via `requests.Session`
     - Stores response in `TestContext`
     - Routes to correct validation rules (override vs default)
     - `assertion_engine.execute_assertions()` validates response
     - Extracts output variables to context for next steps
7. `conftest.py::pytest_runtest_makereport()` writes results to database
8. `conftest.py::pytest_sessionfinish()` updates run summary
9. `run.py` generates Allure report

### Validation Override Logic

The framework supports **scenario-specific validation overrides**:

- Default validations are stored in each step's `validations` field within `api_auto_cases.parameters.steps`
- Override validations are stored in `case_data_sets.validations_override` (keyed by step_order as string)
- In [core/api_client.py:98-108](core/api_client.py#L98-L108), the code checks if `validations_override[str(step_order)]` exists
- If override exists, it completely replaces the default validation for that step
- This enables testing the same API flow with different expected outcomes (success/failure paths)

### Placeholder Resolution Priority

Handled by [utils/placeholder_parser.py](utils/placeholder_parser.py):

1. **Dynamic variables** `{{$randomUser}}`, `{{$randomPassword(16)}}`, `{{$randomPhone}}`, `{{$randomInt(6)}}`
   - Generated once per test run and cached in TestContext
   - Use for generating test data that must remain consistent across steps
2. **Data set variables** `{{@username}}`, `{{@expectedStatus}}`
   - Injected from `case_data_sets.variables` JSONB column
   - Use for parameterizing test inputs and expected values
3. **Inter-step variables** `{{step_1.body.token}}`, `{{step_2.body.userId}}`
   - Extracted from previous step responses via `outputs` configuration
   - Use for passing data between dependent API calls (e.g., login token)

The parser recursively resolves nested placeholders and handles all data types (strings, dicts, lists).

## Important Implementation Notes

### When to Use Classes vs Functions

**Use classes** when the module needs to maintain state across multiple operations:
- `ApiClient`: Maintains `session`, `audit_trail`, `resolved_data_set_variables`
- `TestContext`: Maintains `storage` dictionary for inter-step variables
- `AssertionEngine`: Maintains configuration (currently minimal state)

**Use functions** when the module provides stateless utilities:
- `db_handler`: Stateless database query functions
- `placeholder_parser`: Pure text transformation functions
- `result_writer`: Stateless database write functions

### Pytest Parallel Execution

The framework supports parallel execution via `pytest-xdist`:
- Master process initializes database in `pytest_sessionstart()`
- Worker processes reinitialize session factory if not present
- `RUN_ID` is shared across processes via `os.environ['FRAMEWORK_RUN_ID']`
- Each test gets independent `api_client` fixture (function-scoped)

### Database Connections

The framework manages TWO separate database connections:
1. **Framework DB** (PostgreSQL): Stores test definitions and results
   - Configured via `.env` file: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
   - Accessed via `db_session_factory` fixture
2. **Application DB** (optional): The database of the application under test
   - Configured in `test_environments.app_db_connection_string`
   - Accessed via `app_db_connection` fixture
   - Used for `dbValidation` assertions

### Allure Reporting Integration

The framework uses Allure for rich HTML reports:
- `@allure.step()` decorators create hierarchical step views
- `allure.attach()` attaches request/response/validation details
- `allure.dynamic.title()` sets test case names
- Jira IDs in `case_data_sets.jira_id` are automatically linked in reports

### Environment Management

Test environments are stored in `test_environments` table:
- Each environment has `name`, `base_url`, `app_db_connection_string`, `is_active`
- Data sets can be restricted to specific environments via `case_data_sets.environments` array
- Use `--env` flag to select environment at runtime

## Common Development Patterns

### Adding a New Test Case (via database)

1. Insert test template into `api_auto_cases` with all steps defined in the `parameters` JSONB column
2. Insert data set(s) into `case_data_sets` with variables and optional validation overrides
3. Run test: `python run.py  --id <case_id>`

Example `parameters` structure:

```json
{
  "steps": [
    {
      "order": 1,
      "description": "Login",
      "method": "POST",
      "path": "/api/login",
      "request": {
        "headers": {"Content-Type": "application/json"},
        "body": {"username": "{{@username}}", "password": "{{@password}}"}
      },
      "validations": {"expectedStatusCode": 200},
      "outputs": [{"variable_name": "token", "source": "body", "json_path": "$.token"}]
    }
  ]
}
```

### Adding a New Assertion Type

1. Add new keyword to validation rules JSON schema
2. Add dispatcher method in `AssertionEngine._dispatch_*()`
3. Add helper assertion method in `AssertionEngine._assert_*()`
4. Ensure dispatcher calls `resolve_placeholders()` if needed

### Adding a New Dynamic Variable Type

1. Add generator function in [utils/placeholder_parser.py](utils/placeholder_parser.py) (e.g., `_generate_random_email()`)
2. Add handler in `replace_dynamic_var()` function (e.g., `elif func_name == '$randomEmail': ...`)
3. Use in test data: `{{$randomEmail}}`

### Modifying the Execution Flow

Be extremely careful when modifying these files:
- **[tests/conftest.py](tests/conftest.py)**: Contains critical pytest hooks that manage database lifecycle and parallel execution
- **[tests/test_main.py](tests/test_main.py)**: Contains test discovery logic - changes here affect all tests
- **[core/api_client.py:execute_steps()](core/api_client.py#L39)**: Core orchestration method - changes affect all test execution

### Debug Logging

Use `--debug-mode` flag to write detailed step-by-step audit logs to `auto_test_audit` table:
- Request details (method, url, headers, params, body)
- Response details (status_code, headers, body)
- Step status (passed/failed)

Query debug logs:
```sql
SELECT * FROM auto_test_audit
WHERE audit_case_id IN (
  SELECT id FROM auto_case_audit WHERE runid = '<your_run_id>'
)
ORDER BY step_order;
```

## Testing Philosophy

This framework is designed for **E2E API workflow testing** where:
- A single test case represents a complete business flow (e.g., user registration → login → profile update)
- Multiple data sets test different scenarios of the same flow (success, validation errors, permissions)
- All steps are self-contained within the test case's `parameters` JSONB column
- Database validation ensures API changes are persisted correctly

The framework is NOT optimized for:
- Unit testing individual functions
- Performance/load testing (though it can be extended with Locust integration)
- UI/browser testing
