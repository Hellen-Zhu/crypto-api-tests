"""
REST API Client
Supports dynamic REST API calls through JSON configuration
"""

import json
from typing import Dict, Any, Optional
import requests
from utils.config import Config
from utils.assertion_engine import ResponseValidator


class RestClient:
    """REST API客户端"""

    def __init__(self, api_definitions_file: str = "data/api_definitions.json"):
        """
        初始化客户端

        Args:
            api_definitions_file: API定义文件路径
        """
        self.session = requests.Session()
        self.last_response = None
        self.last_request_data = None
        self.api_definitions = self._load_api_definitions(api_definitions_file)

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

    def call_api(self, api_key: str, **kwargs) -> requests.Response:
        """
        通用API调用方法

        Args:
            api_key: API定义的键名
            **kwargs: API参数

        Returns:
            requests.Response: 响应对象
        """
        api_def = self.api_definitions.get("rest_apis", {}).get(api_key)
        if not api_def:
            raise ValueError(f"API definition not found: {api_key}")

        # 构建请求URL
        endpoint = api_def["endpoint"]
        url = Config.get_rest_api_url(endpoint)

        # 准备请求参数
        method = api_def.get("method", "GET").upper()
        headers = api_def.get("headers", {})

        # 更新session headers
        self.session.headers.update(headers)

        # 处理参数
        params = None
        json_data = None
        request_data = kwargs.copy()

        param_config = api_def.get("parameters", {})
        param_type = param_config.get("type", "query")

        if param_type == "query":
            params = self._build_parameters(kwargs, param_config)
        elif param_type == "body":
            json_data = self._build_parameters(kwargs, param_config)

        # Save request data for subsequent validation
        self.last_request_data = request_data

        try:
            print(f"Sending REST API request: {method} {url}")
            print(f"Parameters: {params if params else json_data}")

            # Send request
            response = self.session.request(
                method=method,
                url=url,
                params=params,
                json=json_data,
                timeout=Config.REQUEST_TIMEOUT
            )

            self.last_response = response
            print(f"Response status code: {response.status_code}")
            return response

        except Exception as e:
            print(f"API request failed: {e}")
            raise

    def _build_parameters(self, kwargs: Dict[str, Any], param_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        构建请求参数

        Args:
            kwargs: 传入的参数
            param_config: 参数配置

        Returns:
            Dict: 构建后的参数
        """
        required_params = param_config.get("required", [])
        optional_params = param_config.get("optional", [])

        # 检查必需参数
        for param in required_params:
            if param not in kwargs:
                raise ValueError(f"Missing required parameter: {param}")

        # 构建参数字典
        params = {}
        for param in required_params + optional_params:
            if param in kwargs:
                params[param] = kwargs[param]

        return params

    def validate_response(self, api_key: str, expect_success: bool = True) -> Dict[str, Any]:
        """
        验证响应

        Args:
            api_key: API定义的键名
            expect_success: 是否期望成功响应

        Returns:
            Dict: 验证结果
        """
        if self.last_response is None:
            raise ValueError("No response data available")

        api_def = self.api_definitions.get("rest_apis", {}).get(api_key)
        if not api_def:
            raise ValueError(f"API definition not found: {api_key}")

        validator = ResponseValidator(api_def)

        print(f"Starting response validation, expect success: {expect_success}")

        if expect_success:
            return validator.validate_success_response(self.last_response, self.last_request_data)
        else:
            return validator.validate_error_response(self.last_response, self.last_request_data)

    def get_last_response(self) -> Optional[requests.Response]:
        """获取最后一次响应"""
        return self.last_response

    def get_response_json(self) -> Dict[str, Any]:
        """获取响应JSON数据"""
        if self.last_response is None:
            raise ValueError("No response data available")
        return self.last_response.json()

    def get_available_apis(self) -> list:
        """
        获取所有可用的API列表

        Returns:
            list: API键名列表
        """
        return list(self.api_definitions.get("rest_apis", {}).keys())

    def get_api_definition(self, api_key: str) -> Dict[str, Any]:
        """
        获取指定API的定义

        Args:
            api_key: API键名

        Returns:
            Dict: API定义
        """
        return self.api_definitions.get("rest_apis", {}).get(api_key, {})

    def print_api_info(self, api_key: str):
        """
        打印API信息

        Args:
            api_key: API键名
        """
        api_def = self.get_api_definition(api_key)
        if not api_def:
            print(f"API '{api_key}' 不存在")
            return

        print(f"\n=== API信息: {api_key} ===")
        print(f"名称: {api_def.get('name', 'N/A')}")
        print(f"方法: {api_def.get('method', 'GET')}")
        print(f"端点: {api_def.get('endpoint', 'N/A')}")

        params = api_def.get("parameters", {})
        if params:
            print(f"必需参数: {params.get('required', [])}")
            print(f"可选参数: {params.get('optional', [])}")

        print("=" * 30)