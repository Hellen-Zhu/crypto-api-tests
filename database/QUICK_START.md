# 🚀 Quick Start - Database Setup (5 Minutes)

## Prerequisites
- PostgreSQL 14+ installed
- Database credentials ready

## Step 1: Create Database (30 seconds)

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE apitest;

# Exit psql
\q
```

## Step 2: Initialize Schema (1 minute)

```bash
# Run schema creation script
psql -U postgres -d apitest -f database/schema.sql
```

✅ **Expected**: You should see "Schema created successfully!" message

## Step 3: Load Test Data (1 minute)

```bash
# Load sample test cases
psql -U postgres -d apitest -f database/test_data.sql
```

✅ **Expected**: You should see summary with 10 test cases inserted

## Step 4: Configure Environment (30 seconds)

Edit `.env` file in project root:

```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=apitest
TEST_ENV=uat
```

## Step 5: Verify Setup (1 minute)

```bash
# Connect to database
psql -U postgres -d apitest

# Check tables
\dt

# Check test cases
SELECT id, name, service FROM api_auto_cases LIMIT 5;

# Exit
\q
```

## Step 6: Run Tests (1 minute)

```bash
# Run all tests
python run.py --env uat

# Run specific service
python run.py --env uat --service exchange_svc

# View report
allure serve reports/allure-report
```

---

## 🎯 What You Get

After completing these steps, you'll have:

- ✅ 5 database tables created
- ✅ 10 sample test cases (HTTP, WebSocket, Mixed)
- ✅ 8 environment configurations (dev, uat)
- ✅ Ready-to-run test framework

## 🔄 Reset Everything

```bash
# Drop database
psql -U postgres -c "DROP DATABASE IF EXISTS apitest;"

# Start over from Step 1
```

## 📚 Next Steps

- Read [README.md](README.md) for detailed documentation
- Check [schema.sql](schema.sql) to understand table structure
- Explore [test_data.sql](test_data.sql) for test case examples
- Run `python run.py --help` to see all available options

## ❓ Common Issues

### "database does not exist"
```bash
# Create the database first
psql -U postgres -c "CREATE DATABASE apitest;"
```

### "permission denied"
```bash
# Grant permissions
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE apitest TO your_user;"
```

### "psql: command not found"
```bash
# Install PostgreSQL client
# macOS: brew install postgresql
# Ubuntu: sudo apt-get install postgresql-client
```

---

**Time to production**: ~5 minutes! 🎉
