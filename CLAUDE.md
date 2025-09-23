# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Python-based automated testing framework for cryptocurrency exchange APIs, supporting both REST API and WebSocket testing using Behave (BDD framework), Pytest, and Requests. The framework features a **generic API client architecture** with JSON-based configuration for dynamic API testing without code changes.

## Development Commands

### Environment Setup

```bash
# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # macOS/Linux
# or
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt
```

### Running Tests

```bash
# Run all tests
behave

# Run specific protocol tests
behave features/rest/           # REST API tests only
behave features/websocket/      # WebSocket tests only

# Run specific feature files
behave features/rest/candlestick.feature       # REST API tests
behave features/websocket/orderbook.feature    # WebSocket tests

# Run with verbose output
behave -v

# Generate HTML report
behave -f html -o reports/behave_report.html

# Generate JUnit XML report (configured in behave.ini)
behave  # Reports automatically saved to reports/ directory
```

### Code Quality Tools

```bash
# Format code
black .

# Lint code
flake8

# Type checking
mypy .
```

## Architecture Overview

### JSON-Driven API Client Architecture

**API Clients**:
- `api_clients/rest_client.py`: Universal REST API client (RestClient class) that reads API definitions from JSON
- `api_clients/websocket_client.py`: Universal WebSocket client (WebSocketClient class) with JSON-configured message formats
- **Clean Architecture**: Each protocol has its dedicated client for better readability and maintainability
- **No hardcoded API logic** - all endpoints, parameters, and validations are JSON-driven

**Dynamic Assertion Engine** (`utils/assertion_engine.py`):
- `AssertionEngine`: Validates responses against JSON schema definitions
- `ResponseValidator`: Orchestrates comprehensive response validation
- Supports dynamic business rule evaluation using Python expressions
- **Key Features**: Status code validation, header validation, JSON schema validation, custom business rules

**API Definitions** (`data/api_definitions.json`):
- **Centralized API configuration** in JSON format
- Defines endpoints, parameters, headers, message formats
- Contains comprehensive validation rules and business logic
- **No code changes needed** to add new APIs or modify validation rules

### Core Components

**Configuration** (`utils/config.py`):
- Centralized configuration management using `Config` class
- Contains API endpoints, timeouts, and default test parameters
- UAT environment endpoints: `https://uat-api.3ona.co` (REST), `wss://uat-stream.3ona.co/exchange/v1/market` (WebSocket)

**Test Steps**:
- `steps/rest_steps.py`: REST API专用步骤定义
- `steps/websocket_steps.py`: WebSocket API专用步骤定义
- JSON配置驱动的API测试

### Test Structure

**Features** (按协议组织):
- `features/rest/`: REST API测试场景
  - `candlestick.feature`: K线数据测试
- `features/websocket/`: WebSocket测试场景
  - `orderbook.feature`: 订单簿测试
- 所有测试使用JSON配置确保最大灵活性

**Data Management**:
- `data/api_definitions.json`: Complete API configuration including validation rules
- `data/test_data.json`: Test data and scenarios for reference

## Key Testing Patterns

### JSON-Driven API Testing

**REST API Pattern**:
```gherkin
When I call REST API "get_candlestick"
    | parameter       | value        |
    | instrument_name | BTCUSDT-PERP |
    | timeframe       | M5           |
Then the response should validate successfully
```

**WebSocket API Pattern**:
```gherkin
When I connect to WebSocket server
Then WebSocket should connect successfully
When I call WebSocket API "subscribe_orderbook"
    | parameter       | value     |
    | instrument_name | BTC_USDT  |
    | depth           | 10        |
Then WebSocket message should send successfully
```

### Dynamic Validation Features

**JSON Schema Validation**: Automatically validates response structure against predefined schemas

**Business Rule Validation**: Supports Python expressions for complex validations:
```json
{
  "rule": "response.result.instrument_name == request.instrument_name",
  "description": "Return instrument should match request"
}
```

**Multi-level Assertions**:
- Status code validation
- Header validation
- Response schema validation
- Custom business logic validation

## Development Guidelines

### Adding New APIs (Recommended: JSON Configuration)

1. **Add API Definition** to `data/api_definitions.json`:
   ```json
   "new_api_name": {
     "method": "GET",
     "endpoint": "/path/to/endpoint",
     "parameters": {...},
     "assertions": {...}
   }
   ```

2. **Use Generic Steps** in feature files:
   ```gherkin
   When I call REST API "new_api_name"
   ```

3. **No code changes required** - the generic client automatically handles new APIs

### Adding New WebSocket APIs

1. **Add WebSocket API Definition** to `data/api_definitions.json`:
   ```json
   "new_websocket_api": {
     "action": "subscribe",
     "channel_template": "channel.{param}.{value}",
     "message_format": {...},
     "assertions": {...}
   }
   ```

2. **Use Generic WebSocket Steps**:
   ```gherkin
   When I call WebSocket API "new_websocket_api"
   ```

### Custom Validation Rules

Add business rules to API definitions without coding:
```json
"business_rules": [
  {
    "rule": "len(response.result.data) > 0",
    "description": "Data should not be empty"
  },
  {
    "rule": "response.code == 0",
    "description": "Success response should have code 0"
  }
]
```

### Advanced Customization

For specialized needs beyond JSON configuration:

1. **Custom REST Clients**: Extend `RestClient` class in `api_clients/rest_client.py`
2. **Custom WebSocket Clients**: Extend `WebSocketClient` class in `api_clients/websocket_client.py`
3. **Custom REST Steps**: Add to `steps/rest_steps.py` for REST API usage
4. **Custom WebSocket Steps**: Add to `steps/websocket_steps.py` for WebSocket API usage
5. **Custom Validation Rules**: Add business rules to `data/api_definitions.json`

## Test Data and Environment

### API Endpoints
- **REST API**: `https://uat-api.3ona.co/exchange/v1/public/get-candlestick`
- **WebSocket**: `wss://uat-stream.3ona.co/exchange/v1/market`

### Supported APIs (Configured in JSON)
- **REST**: `get_candlestick` - K-line data retrieval
- **WebSocket**: `subscribe_orderbook`, `unsubscribe_orderbook` - Order book subscription management

### Validation Coverage
- **Comprehensive Schema Validation**: Automatic JSON structure validation
- **Dynamic Business Rules**: Python expression-based custom validations
- **Error Response Handling**: Configurable error assertion patterns
- **Protocol-specific Validation**: REST status codes, WebSocket message formats