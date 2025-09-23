# 🚀 加密货币API自动化测试框架

一个基于 **Python + Pytest + Behave + Requests** 的专业级加密货币交易所API自动化测试框架，同时支持 **REST API** 和 **WebSocket** 接口测试。

## ✨ 框架特性

- 🎯 **BDD风格测试** - 使用Behave框架，业务人员也能理解的测试用例
- 🔀 **双协议支持** - 同时支持REST API和WebSocket实时数据测试
- 📊 **完整验证** - 状态码、响应头、数据结构、业务逻辑全面验证
- 🛡️ **错误处理** - 完善的异常场景测试和错误检测
- 🔧 **易于扩展** - 模块化设计，轻松添加新的API测试、

## 🏗️ 项目结构

```
crypto_api_test/
├── api_clients/                 # API客户端封装
│   ├── __init__.py
│   ├── rest_client.py          # REST API客户端
│   └── websocket_client.py     # WebSocket客户端
├── features/                    # BDD测试用例
│   ├── rest/
│   │   └── candlestick.feature # K线数据测试
│   └── websocket/
│       └── orderbook.feature   # 订单簿测试
├── steps/                       # 步骤定义
│   ├── __init__.py
│   ├── rest_steps.py           # REST API步骤实现
│   └── websocket_steps.py      # WebSocket步骤实现
├── utils/                       # 工具模块
│   ├── __init__.py
│   └── config.py               # 配置管理
├── data/                        # 测试数据
├── requirements.txt             # 项目依赖
├── behave.ini                  # Behave配置
└── README.md                   # 项目文档
```

## 📋 测试覆盖范围

### REST API测试
- ✅ **K线数据获取** (`/exchange/v1/public/get-candlestick`)
  - AAVE USD永续合约 M5/H1/1D 周期
  - 状态码、内容类型、数据结构验证
  - 错误场景：无效交易对、无效时间周期

### WebSocket测试
- ✅ **订单簿数据订阅** (`book.{instrument}.{depth}`)
  - BTC USDT 深度10订单簿
  - 连接管理、订阅确认、实时数据接收
  - 数据验证：bids、asks、深度限制
  - 错误场景：无效交易对、无效深度

## 🚀 快速开始

### 1. 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd crypto_api_test

# 创建虚拟环境
python -m venv venv

# 激活虚拟环境
# macOS/Linux:
source venv/bin/activate
# Windows:
venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

### 2. 运行测试

```bash
# 运行所有测试
behave

# 运行REST API测试
behave features/rest/

# 运行WebSocket测试
behave features/websocket/

# 详细输出模式
behave -v

# 生成HTML报告
behave -f html -o reports/behave_report.html
```


## 🔧 配置说明

### API配置 (`utils/config.py`)

```python
class Config:
    # API端点
    REST_API_BASE_URL = "https://uat-api.3ona.co"
    WEBSOCKET_URL = "wss://uat-stream.3ona.co/exchange/v1/market"
    
    # 超时设置
    REQUEST_TIMEOUT = 30
    WS_CONNECT_TIMEOUT = 10
    WS_MESSAGE_TIMEOUT = 5
    
    # 默认测试参数
    DEFAULT_INSTRUMENT = "AAVEUSD-PERP"
    DEFAULT_TIMEFRAME = "M5"
    DEFAULT_DEPTH = 10
```

### Behave配置 (`behave.ini`)

```ini
[behave]
default_format = pretty
show_source = true
show_timings = true
junit = true
junit_directory = reports
logging_level = INFO
```

## 📚 API接口说明

### REST API

#### 获取K线数据
- **端点**: `/exchange/v1/public/get-candlestick`
- **方法**: GET
- **参数**:
  - `instrument_name`: 交易对 (如: `AAVEUSD-PERP`)
  - `timeframe`: 时间周期 (如: `M5`, `H1`, `1D`)
- **响应**: JSON格式，包含 `code`, `method`, `result` 字段

### WebSocket API

#### 订阅订单簿数据
- **端点**: `wss://uat-stream.3ona.co/exchange/v1/market`
- **频道**: `book.{instrument_name}.{depth}`
- **示例**: `book.BTC_USDT.10`
- **响应**: 实时推送订单簿数据，包含 `bids`, `asks`, 时间戳

## 🔍 使用示例

### 添加新的REST API测试

1. **扩展客户端方法** (`api_clients/rest_client.py`):
```python
def get_ticker(self, instrument_name):
    """获取ticker数据"""
    endpoint = "/exchange/v1/public/get-ticker"
    url = Config.get_rest_api_url(endpoint)
    params = {'instrument_name': instrument_name}
    return self.session.get(url, params=params, timeout=Config.REQUEST_TIMEOUT)
```

2. **添加步骤定义** (`steps/rest_steps.py`):
```python
@when('I request ticker data for instrument "{instrument_name}"')
def step_when_request_ticker(context, instrument_name):
    context.response = context.rest_client.get_ticker(instrument_name)
```

3. **创建测试用例** (`features/rest/ticker.feature`):
```gherkin
Feature: Ticker Data Testing
  
  Scenario: Get ticker data for AAVE
    Given I have a REST API client
    When I request ticker data for instrument "AAVEUSD-PERP"
    Then response status code should be 200
```

### 添加新的WebSocket测试

1. **扩展客户端方法** (`api_clients/websocket_client.py`):
```python
def subscribe_ticker(self, instrument_name):
    """订阅ticker数据"""
    channel = f"ticker.{instrument_name}"
    subscribe_msg = {
        "method": "subscribe",
        "params": {"channels": [channel]},
        "id": int(time.time())
    }
    self.ws.send(json.dumps(subscribe_msg))
```

## 📄 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| Python | 3.9+ | 编程语言 |
| Behave | 1.2.6+ | BDD测试框架 |
| Requests | 2.31+ | HTTP客户端 |
| websocket-client | 1.6+ | WebSocket客户端 |
| PyYAML | 6.0+ | 配置管理 |
| Pytest | 7.4+ | 测试运行器 |
