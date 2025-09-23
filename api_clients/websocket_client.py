"""
通用WebSocket客户端
支持通过JSON配置动态调用WebSocket API
"""

import json
import time
import threading
import ssl
from typing import Dict, Any, List, Optional
import websocket
from utils.config import Config
from utils.assertion_engine import ResponseValidator


class WebSocketClient:
    """WebSocket客户端"""

    def __init__(self, api_definitions_file: str = "data/websocket_api_definitions.json"):
        """
        初始化WebSocket客户端

        Args:
            api_definitions_file: WebSocket API定义文件路径
        """
        self.ws = None
        self.is_connected = False
        self.received_messages = []
        self.subscription_confirmations = []
        self.error_messages = []
        self.connection_thread = None
        self.message_lock = threading.Lock()
        self.api_definitions = self._load_api_definitions(api_definitions_file)
        self.active_subscriptions = {}  # 记录活动订阅

    def _load_api_definitions(self, file_path: str) -> Dict[str, Any]:
        """
        加载API定义文件

        Args:
            file_path: 文件路径

        Returns:
            Dict: API定义
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"加载API定义文件失败: {e}")
            return {}

    def connect(self) -> bool:
        """
        连接到WebSocket服务器

        Returns:
            bool: 连接是否成功
        """
        try:
            websocket_url = Config.get_websocket_url()
            print(f"连接到WebSocket服务器: {websocket_url}")

            self.ws = websocket.WebSocketApp(
                websocket_url,
                on_open=self._on_open,
                on_message=self._on_message,
                on_error=self._on_error,
                on_close=self._on_close
            )

            # Configure SSL to skip certificate verification for testing
            ssl_context = ssl.create_default_context()
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE

            self.connection_thread = threading.Thread(
                target=self.ws.run_forever,
                kwargs={'sslopt': {"cert_reqs": ssl.CERT_NONE}}
            )
            self.connection_thread.daemon = True
            self.connection_thread.start()

            # 等待连接建立
            timeout = Config.WS_CONNECT_TIMEOUT
            start_time = time.time()
            while not self.is_connected and (time.time() - start_time) < timeout:
                time.sleep(0.1)

            if self.is_connected:
                print("WebSocket连接成功建立")
            else:
                print("WebSocket连接超时")

            return self.is_connected

        except Exception as e:
            print(f"WebSocket连接失败: {e}")
            return False

    def disconnect(self):
        """断开WebSocket连接"""
        if self.ws:
            self.ws.close()
            print("WebSocket连接已断开")
        self.is_connected = False

    def call_websocket_api(self, api_key: str, **kwargs) -> bool:
        """
        通用WebSocket API调用

        Args:
            api_key: API定义的键名
            **kwargs: API参数

        Returns:
            bool: 是否发送成功
        """
        api_def = self.api_definitions.get(api_key)
        if not api_def:
            raise ValueError(f"未找到WebSocket API定义: {api_key}")

        if not self.is_connected:
            print("WebSocket未连接")
            return False

        # 验证必需参数
        param_config = api_def.get("parameters", {})
        required_params = param_config.get("required", [])
        for param in required_params:
            if param not in kwargs:
                raise ValueError(f"缺少必需参数: {param}")

        # 获取频道名称
        channel = kwargs.get("channel", "")

        # 构建消息
        message_format = api_def.get("message_format", {})
        message = self._build_message(message_format, channel)

        # 记录订阅信息
        self.active_subscriptions[api_key] = {
            "channel": channel,
            "params": kwargs,
            "api_definition": api_def
        }

        try:
            message_str = json.dumps(message)
            print(f"发送WebSocket消息: {message_str}")
            self.ws.send(message_str)
            print(f"WebSocket消息发送成功: {channel}")
            return True

        except Exception as e:
            print(f"发送WebSocket消息失败: {e}")
            return False

    def _build_channel(self, template: str, params: Dict[str, Any]) -> str:
        """
        构建频道名称

        Args:
            template: 频道模板
            params: 参数字典

        Returns:
            str: 构建后的频道名称
        """
        channel = template
        for key, value in params.items():
            placeholder = f"{{{key}}}"
            if placeholder in channel:
                channel = channel.replace(placeholder, str(value))
        return channel

    def _build_message(self, message_format: Dict[str, Any], channel: str) -> Dict[str, Any]:
        """
        构建WebSocket消息

        Args:
            message_format: 消息格式
            channel: 频道名称

        Returns:
            Dict: 构建后的消息
        """
        message = {}
        for key, value in message_format.items():
            if isinstance(value, str):
                if value == "{{channel}}":
                    message[key] = channel
                elif value == "{{timestamp}}":
                    message[key] = int(time.time() * 1000)  # nonce needs milliseconds
                else:
                    message[key] = value
            elif isinstance(value, int):
                message[key] = value
            elif isinstance(value, dict):
                message[key] = self._build_message(value, channel)
            elif isinstance(value, list):
                message[key] = []
                for item in value:
                    if isinstance(item, str) and item == "{{channel}}":
                        message[key].append(channel)
                    else:
                        message[key].append(item)
            else:
                message[key] = value
        return message

    def wait_for_message(self, timeout: int = None) -> bool:
        """
        等待接收消息

        Args:
            timeout: 超时时间（秒）

        Returns:
            bool: 是否在超时内收到消息
        """
        if timeout is None:
            timeout = Config.WS_MESSAGE_TIMEOUT

        start_time = time.time()
        initial_count = len(self.received_messages)

        print(f"等待WebSocket消息，超时时间: {timeout}秒")

        while (time.time() - start_time) < timeout:
            with self.message_lock:
                if len(self.received_messages) > initial_count:
                    print(f"收到新消息，总消息数: {len(self.received_messages)}")
                    return True
            time.sleep(0.1)

        print("等待WebSocket消息超时")
        return False

    def validate_websocket_response(self, api_key: str, message_type: str = "data_message") -> Dict[str, Any]:
        """
        验证WebSocket响应

        Args:
            api_key: API定义的键名
            message_type: 消息类型 (subscription_confirmation, data_message, etc.)

        Returns:
            Dict: 验证结果
        """
        if api_key not in self.active_subscriptions:
            raise ValueError(f"未找到活动订阅: {api_key}")

        subscription_info = self.active_subscriptions[api_key]
        api_def = subscription_info["api_definition"]

        # 获取相应类型的消息
        if message_type == "subscription_confirmation":
            # 查找订阅确认消息
            # 对于ticker API，包含result字段的也算是确认消息
            target_message = None
            for msg in self.received_messages:
                if isinstance(msg, dict) and msg.get('method') == 'subscribe':
                    # 如果是orderbook类型（不包含result），或者ticker类型（包含result）
                    if 'result' not in msg or 'result' in msg:
                        target_message = msg
                        break
        else:
            # 获取最新消息
            target_message = self.get_latest_message()

        if not target_message:
            return {
                "is_valid": False,
                "all_errors": [f"没有收到{message_type}类型的WebSocket消息"]
            }

        print(f"验证WebSocket消息类型: {message_type}")
        print(f"目标消息: {target_message}")

        # 获取断言配置
        assertions = api_def.get("assertions", {}).get(message_type, {})
        if not assertions:
            return {
                "is_valid": False,
                "all_errors": [f"未找到消息类型的断言配置: {message_type}"]
            }

        # 创建验证器并验证
        validator = ResponseValidator({"assertions": assertions})

        # 创建模拟响应对象
        class MockResponse:
            def __init__(self, data):
                self._data = data
                self.status_code = 200
                self.headers = {"Content-Type": "application/json"}

            def json(self):
                return self._data

        mock_response = MockResponse(target_message)
        request_data = {
            "channel": subscription_info["channel"],
            "depth": subscription_info["params"].get("depth", 0)
        }

        return validator.validate_success_response(mock_response, request_data)

    def get_received_messages(self) -> List[Dict[str, Any]]:
        """获取已接收的消息列表"""
        with self.message_lock:
            return self.received_messages.copy()

    def get_latest_message(self) -> Optional[Dict[str, Any]]:
        """获取最新的消息"""
        with self.message_lock:
            if self.received_messages:
                return self.received_messages[-1]
        return None

    def get_subscription_confirmations(self) -> List[Dict[str, Any]]:
        """获取订阅确认消息列表"""
        with self.message_lock:
            return self.subscription_confirmations.copy()

    def get_error_messages(self) -> List[Dict[str, Any]]:
        """获取错误消息列表"""
        with self.message_lock:
            return self.error_messages.copy()

    def clear_messages(self):
        """清空消息缓存"""
        with self.message_lock:
            self.received_messages.clear()
            self.subscription_confirmations.clear()
            self.error_messages.clear()
        print("WebSocket消息缓存已清空")

    def get_available_apis(self) -> list:
        """
        获取所有可用的WebSocket API列表

        Returns:
            list: API键名列表
        """
        return list(self.api_definitions.keys())

    def get_api_definition(self, api_key: str) -> Dict[str, Any]:
        """
        获取指定API的定义

        Args:
            api_key: API键名

        Returns:
            Dict: API定义
        """
        return self.api_definitions.get(api_key, {})

    def print_api_info(self, api_key: str):
        """
        打印WebSocket API信息

        Args:
            api_key: API键名
        """
        api_def = self.get_api_definition(api_key)
        if not api_def:
            print(f"WebSocket API '{api_key}' 不存在")
            return

        print(f"\n=== WebSocket API信息: {api_key} ===")
        print(f"名称: {api_def.get('name', 'N/A')}")
        print(f"动作: {api_def.get('action', 'N/A')}")
        print(f"频道模板: {api_def.get('channel_template', 'N/A')}")

        params = api_def.get("parameters", {})
        if params:
            print(f"必需参数: {params.get('required', [])}")

        print("=" * 40)

    def _on_open(self, ws):
        """WebSocket连接建立回调"""
        print("WebSocket连接已建立")
        self.is_connected = True

    def _on_message(self, ws, message):
        """WebSocket消息接收回调"""
        try:
            data = json.loads(message)
            print(f"收到WebSocket消息: {data}")

            with self.message_lock:
                self.received_messages.append(data)

                # 分类消息
                if 'result' in data or 'method' in data:
                    self.subscription_confirmations.append(data)
                elif 'error' in data:
                    self.error_messages.append(data)

        except json.JSONDecodeError as e:
            print(f"解析WebSocket消息JSON失败: {e}")
            with self.message_lock:
                self.error_messages.append({"error": "JSON解析失败", "raw_message": message})

    def _on_error(self, ws, error):
        """WebSocket错误回调"""
        print(f"WebSocket错误: {error}")
        with self.message_lock:
            self.error_messages.append({"error": str(error)})

    def _on_close(self, ws, close_status_code, close_msg):
        """WebSocket连接关闭回调"""
        print(f"WebSocket连接已关闭: {close_status_code} - {close_msg}")
        self.is_connected = False