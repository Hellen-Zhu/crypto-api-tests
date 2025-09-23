"""
配置管理模块
用于管理API的基础URL和配置参数
"""

class Config:
    """基础配置类"""
    
    # API配置
    REST_API_BASE_URL = "https://uat-api.3ona.co"
    WEBSOCKET_URL = "wss://uat-stream.3ona.co/exchange/v1/market"
    
    # 请求配置
    REQUEST_TIMEOUT = 30
    
    # 测试配置
    DEFAULT_INSTRUMENT = "AAVEUSD-PERP"
    DEFAULT_TIMEFRAME = "M5"
    DEFAULT_DEPTH = 10
    
    # WebSocket配置
    WS_CONNECT_TIMEOUT = 10
    WS_MESSAGE_TIMEOUT = 5
    
    @classmethod
    def get_rest_api_url(cls, endpoint):
        """获取完整的REST API URL"""
        return f"{cls.REST_API_BASE_URL}{endpoint}"
    
    @classmethod
    def get_websocket_url(cls):
        """获取WebSocket连接URL"""
        return cls.WEBSOCKET_URL
