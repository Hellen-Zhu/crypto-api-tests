# 📊 Database Schema and Test Data

This directory contains SQL scripts for initializing the PostgreSQL database for the Crypto API Test Framework.

## 📁 Files

| File | Description |
|------|-------------|
| [schema.sql](schema.sql) | **Database schema definition** - CREATE TABLE statements for all 5 tables with indexes, constraints, and triggers |
| [test_data.sql](test_data.sql) | **Sample test data** - INSERT statements with 10 example test cases covering HTTP, WebSocket, and mixed protocols |

## 🗄️ Database Schema Overview

### Tables

The framework uses **5 main tables**:

#### 1. `api_auto_cases` - Test Case Definition
- **Purpose**: Stores all test case configurations (HTTP and WebSocket)
- **Key Feature**: Uses JSONB column `test_config` to store flexible test steps
- **Design**: Single-table design - each row is a complete, independent test case

```sql
-- Key columns:
id              SERIAL PRIMARY KEY
name            VARCHAR(255)           -- Test case name
service         VARCHAR(100)           -- Service: exchange_svc, websocket_svc, etc.
module          VARCHAR(100)           -- Module: market_data, trading, etc.
component       VARCHAR(100)           -- Component: candlestick, ticker, etc.
tags            TEXT[]                 -- Tags: ['P0', 'smoke', 'regression']
environments    TEXT[]                 -- Target envs: ['dev', 'uat'], NULL = all
test_config     JSONB NOT NULL         -- Test steps, variables, validations
enable          BOOLEAN DEFAULT TRUE
```

#### 2. `test_environments` - Environment Configuration
- **Purpose**: Maps environment names to service base URLs
- **Design**: Multi-service per environment (e.g., dev can have multiple services)

```sql
-- Key columns:
id          SERIAL PRIMARY KEY
name        VARCHAR(50)      -- Environment: dev, uat, prod
service     VARCHAR(50)      -- Service name: exchange_svc, websocket_svc
base_url    VARCHAR(255)     -- Service URL (HTTP or WebSocket)
is_active   BOOLEAN
```

#### 3. `auto_progress` - Test Run Summary
- **Purpose**: Stores aggregated statistics for each test execution session
- **Usage**: One row per test run (identified by `runid`)

```sql
-- Key columns:
id            SERIAL PRIMARY KEY
runid         VARCHAR(50) UNIQUE  -- UUID for test run
total_cases   INTEGER             -- Total test cases executed
passes        INTEGER             -- Number of passed tests
failures      INTEGER             -- Number of failed tests
skips         INTEGER             -- Number of skipped tests
begin_time    TIMESTAMP
end_time      TIMESTAMP
```

#### 4. `auto_case_audit` - Test Case Execution Record
- **Purpose**: Lightweight summary of each test case execution
- **Relationship**: One row per test case per run

```sql
-- Key columns:
id               SERIAL PRIMARY KEY
runid            VARCHAR(50)    -- Links to auto_progress
case_id          INTEGER        -- Links to api_auto_cases
run_status       VARCHAR(20)    -- passed, failed, skipped
duration         REAL           -- Execution time in seconds
error_message    TEXT
input_variables  JSONB          -- Test input data
```

#### 5. `auto_test_audit` - Detailed Step Logs
- **Purpose**: Stores detailed request/response for each step (debug mode only)
- **Relationship**: Foreign key to `auto_case_audit` with CASCADE DELETE

```sql
-- Key columns:
id                SERIAL PRIMARY KEY
audit_case_id     INTEGER        -- FK to auto_case_audit (CASCADE DELETE)
step_order        INTEGER
action_description TEXT
request_details   JSONB          -- Full request data
response_details  JSONB          -- Full response data
step_status       VARCHAR(20)
step_duration     REAL
```

## 🚀 Quick Start

### 1. Create Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE apitest;

# Connect to the database
\c apitest
```

### 2. Run Schema Script

```bash
# Method 1: Using psql command
psql -U postgres -d apitest -f database/schema.sql

# Method 2: Inside psql
\i database/schema.sql
```

**Expected Output:**
```
CREATE TABLE
CREATE INDEX
CREATE TRIGGER
...
NOTICE:  Schema created successfully! Tables: api_auto_cases, test_environments, auto_progress, auto_case_audit, auto_test_audit
```

### 3. Load Test Data

```bash
# Method 1: Using psql command
psql -U postgres -d apitest -f database/test_data.sql

# Method 2: Inside psql
\i database/test_data.sql
```

**Expected Output:**
```
INSERT 0 8
INSERT 0 10
...
NOTICE:  ========================================
NOTICE:  Test Data Inserted Successfully!
NOTICE:  ========================================
NOTICE:  Environment Configurations: 8
NOTICE:  Total Test Cases: 10
NOTICE:    - HTTP Test Cases: 4
NOTICE:    - WebSocket Test Cases: 3
NOTICE:    - Mixed Protocol Cases: 3
NOTICE:  ========================================
```

### 4. Verify Installation

```sql
-- Check tables
\dt

-- Check test cases
SELECT id, name, service, module, component, tags
FROM api_auto_cases
ORDER BY id;

-- Check environments
SELECT name, service, base_url
FROM test_environments
WHERE is_active = true
ORDER BY name, service;

-- Check JSONB structure
SELECT name, test_config->'steps'->0->>'protocol' AS protocol
FROM api_auto_cases
LIMIT 5;
```

## 📝 Sample Test Cases Included

The `test_data.sql` includes **10 comprehensive test cases**:

### HTTP Test Cases (4)
1. **Get Candlestick - Valid Request** (`CRYPTO-101`)
   - Basic HTTP GET with query parameters
   - Validates response structure and data types

2. **Get Candlestick - Invalid Count** (`CRYPTO-102`)
   - Negative testing with invalid parameter
   - Expects 400 error response

3. **Get Tickers - BTCUSD Perpetual** (`CRYPTO-103`)
   - Ticker data retrieval
   - Validates price fields are positive numbers

4. **Multi-Step: Get Ticker and Validate Candlestick** (`CRYPTO-104`)
   - Multi-step workflow with variable extraction
   - Demonstrates step output and input chaining

### WebSocket Test Cases (3)
5. **WebSocket - Ticker Subscription** (`CRYPTO-201`)
   - Basic WebSocket workflow: connect → subscribe → wait → disconnect
   - Validates real-time push messages

6. **WebSocket - Multiple Channel Subscriptions** (`CRYPTO-202`)
   - Subscribe to multiple channels (BTC and ETH)
   - Tests concurrent message handling

7. **WebSocket Connection Failure Test** (`CRYPTO-502`)
   - Negative test with invalid URL
   - Uses `expect_failure: true`

### Mixed Protocol Test Cases (3)
8. **Mixed Protocol - HTTP Snapshot + WebSocket Real-time** (`CRYPTO-301`)
   - Combines HTTP and WebSocket in one test
   - Gets HTTP snapshot, then subscribes to WebSocket updates

9. **Negative Test - Invalid Instrument Name** (`CRYPTO-501`)
   - Tests error handling for invalid data

10. **API + Database Consistency Check** (`CRYPTO-401`)
    - Placeholder for future database validation feature

## 🔧 Customization

### Modify Environment URLs

Edit the base URLs in `test_data.sql` before running:

```sql
-- Example: Change UAT environment URL
INSERT INTO test_environments (name, service, base_url, description, is_active) VALUES
('uat', 'exchange_svc', 'https://your-uat-url.com', 'UAT environment', true);
```

### Add Your Own Test Cases

Use the existing test cases as templates. Key JSONB structure for `test_config`:

```json
{
  "variables": {
    "var_name": "var_value"
  },
  "steps": [
    {
      "step_order": 1,
      "protocol": "http",  // or "websocket"
      "method": "GET",     // for HTTP
      "path": "/api/endpoint",
      "params": {...},
      "validations": {...}
    }
  ]
}
```

### WebSocket Step Structure

```json
{
  "step_order": 1,
  "protocol": "websocket",
  "action": "connect",  // connect, send, wait, disconnect
  "request": {
    "url": "${base_url}",
    "timeout": 10
  }
}
```

## 🔍 Useful Queries

### Find Test Cases by Tag

```sql
SELECT id, name, tags, service
FROM api_auto_cases
WHERE 'P0' = ANY(tags);
```

### Find Test Cases for Specific Environment

```sql
SELECT id, name, service, environments
FROM api_auto_cases
WHERE 'uat' = ANY(environments)
   OR environments IS NULL;
```

### Find WebSocket Test Cases

```sql
SELECT id, name, service
FROM api_auto_cases
WHERE test_config->'steps'->0->>'protocol' = 'websocket';
```

### View Test Step Details

```sql
SELECT
    name,
    jsonb_array_length(test_config->'steps') as step_count,
    test_config->'steps' as steps
FROM api_auto_cases
WHERE id = 1;
```

### Get Recent Test Runs

```sql
SELECT
    runid,
    total_cases,
    passes,
    failures,
    begin_time,
    end_time,
    EXTRACT(EPOCH FROM (end_time - begin_time)) as duration_seconds
FROM auto_progress
ORDER BY created_at DESC
LIMIT 10;
```

## 🛠️ Maintenance

### Reset Test Data

```sql
-- Clear all test data (keeps schema)
TRUNCATE TABLE api_auto_cases CASCADE;
TRUNCATE TABLE test_environments CASCADE;
TRUNCATE TABLE auto_progress CASCADE;

-- Reload test data
\i database/test_data.sql
```

### Drop and Recreate Everything

```sql
-- Drop all tables
DROP TABLE IF EXISTS auto_test_audit CASCADE;
DROP TABLE IF EXISTS auto_case_audit CASCADE;
DROP TABLE IF EXISTS auto_progress CASCADE;
DROP TABLE IF EXISTS api_auto_cases CASCADE;
DROP TABLE IF EXISTS test_environments CASCADE;

-- Recreate schema and data
\i database/schema.sql
\i database/test_data.sql
```

### Backup Database

```bash
# Backup schema only
pg_dump -U postgres -d apitest --schema-only -f backup_schema.sql

# Backup data only
pg_dump -U postgres -d apitest --data-only -f backup_data.sql

# Backup everything
pg_dump -U postgres -d apitest -f backup_full.sql
```

## 📚 References

- **ORM Models**: See [src/database/models.py](../src/database/models.py) for SQLAlchemy definitions
- **Database Handler**: See [src/database/handler.py](../src/database/handler.py) for query functions
- **Framework README**: See [../README.md](../README.md) for overall framework documentation

## 💡 Tips

1. **JSONB Indexing**: If you have many test cases, consider adding GIN indexes on `test_config`:
   ```sql
   CREATE INDEX idx_test_config_protocol ON api_auto_cases
   USING GIN ((test_config->'steps'));
   ```

2. **Environment Variables**: Update your `.env` file with database credentials:
   ```env
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=postgres
   DB_PASSWORD=your_password
   DB_NAME=apitest
   ```

3. **PostgreSQL Version**: This schema requires PostgreSQL 14+ for full JSONB support.

4. **Timezone**: All timestamps use `Asia/Shanghai` timezone. Adjust in the SQL files if needed.

## 🐛 Troubleshooting

### Issue: "relation already exists"
**Solution**: Tables already exist. Drop them first or skip creation:
```sql
DROP TABLE IF EXISTS auto_test_audit CASCADE;
-- ... drop other tables
\i database/schema.sql
```

### Issue: "duplicate key value violates unique constraint"
**Solution**: Test data already loaded. Truncate first:
```sql
TRUNCATE TABLE api_auto_cases CASCADE;
\i database/test_data.sql
```

### Issue: JSONB syntax errors
**Solution**: Ensure PostgreSQL 14+:
```sql
SELECT version();  -- Should show PostgreSQL 14 or higher
```

---

**Need Help?** Check the main [README.md](../README.md) or open an issue on GitHub.
