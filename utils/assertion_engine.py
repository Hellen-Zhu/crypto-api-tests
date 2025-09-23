"""
动态断言引擎
根据JSON配置动态验证API响应
"""

import json
import re
from typing import Dict, Any, List, Union
from jsonschema import validate, ValidationError
from utils.config import Config


class AssertionEngine:
    """动态断言引擎类"""

    def __init__(self):
        """初始化断言引擎"""
        self.validation_errors = []
        self.business_rule_errors = []

    def clear_errors(self):
        """清空错误记录"""
        self.validation_errors.clear()
        self.business_rule_errors.clear()

    def validate_status_code(self, actual_code: int, expected_codes: Union[int, List[int]]) -> bool:
        """
        验证状态码

        Args:
            actual_code: 实际状态码
            expected_codes: 期望状态码（可以是单个值或列表）

        Returns:
            bool: 验证是否通过
        """
        if isinstance(expected_codes, int):
            expected_codes = [expected_codes]

        is_valid = actual_code in expected_codes
        if not is_valid:
            self.validation_errors.append(
                f"Status code validation failed: expected {expected_codes}, actual {actual_code}"
            )
        return is_valid

    def validate_headers(self, actual_headers: Dict[str, str], expected_headers: Dict[str, str]) -> bool:
        """
        验证响应头

        Args:
            actual_headers: 实际响应头
            expected_headers: 期望响应头

        Returns:
            bool: 验证是否通过
        """
        is_valid = True
        for key, expected_value in expected_headers.items():
            actual_value = actual_headers.get(key, "")
            if expected_value not in actual_value:
                self.validation_errors.append(
                    f"Header validation failed: {key} expected '{expected_value}', actual '{actual_value}'"
                )
                is_valid = False
        return is_valid

    def validate_json_schema(self, response_data: Dict[str, Any], schema: Dict[str, Any]) -> bool:
        """
        验证JSON schema

        Args:
            response_data: 响应数据
            schema: JSON schema定义

        Returns:
            bool: 验证是否通过
        """
        try:
            validate(instance=response_data, schema=schema)
            return True
        except ValidationError as e:
            self.validation_errors.append(f"JSON Schema validation failed: {e.message}")
            return False

    def validate_business_rules(self, response_data: Dict[str, Any], request_data: Dict[str, Any],
                              rules: List[Dict[str, str]]) -> bool:
        """
        验证业务规则

        Args:
            response_data: 响应数据
            request_data: 请求数据
            rules: 业务规则列表

        Returns:
            bool: 验证是否通过
        """
        is_valid = True

        for rule in rules:
            rule_expression = rule.get("rule", "")
            rule_description = rule.get("description", "")

            try:
                # 创建评估上下文
                context = {
                    "response": self._create_dict_accessor(response_data),
                    "request": self._create_dict_accessor(request_data),
                    "len": len
                }

                # 评估规则表达式
                result = eval(rule_expression, {"__builtins__": {}}, context)

                if not result:
                    self.business_rule_errors.append(
                        f"Business rule validation failed: {rule_description} - rule: {rule_expression}"
                    )
                    is_valid = False

            except Exception as e:
                self.business_rule_errors.append(
                    f"Business rule evaluation error: {rule_description} - error: {str(e)}"
                )
                is_valid = False

        return is_valid

    def _create_dict_accessor(self, data: Dict[str, Any]) -> 'DictAccessor':
        """
        创建字典访问器，支持点号访问

        Args:
            data: 字典数据

        Returns:
            DictAccessor: 字典访问器对象
        """
        return DictAccessor(data)

    def get_all_errors(self) -> List[str]:
        """
        获取所有错误信息

        Returns:
            List[str]: 错误信息列表
        """
        return self.validation_errors + self.business_rule_errors

    def get_validation_errors(self) -> List[str]:
        """
        获取验证错误信息

        Returns:
            List[str]: 验证错误列表
        """
        return self.validation_errors.copy()

    def get_business_rule_errors(self) -> List[str]:
        """
        获取业务规则错误信息

        Returns:
            List[str]: 业务规则错误列表
        """
        return self.business_rule_errors.copy()

    def is_valid(self) -> bool:
        """
        检查是否所有验证都通过

        Returns:
            bool: 是否所有验证都通过
        """
        return len(self.validation_errors) == 0 and len(self.business_rule_errors) == 0


class DictAccessor:
    """字典访问器，支持点号语法访问嵌套字典"""

    def __init__(self, data: Dict[str, Any]):
        self._data = data

    def __getattr__(self, name: str):
        if name in self._data:
            value = self._data[name]
            if isinstance(value, dict):
                return DictAccessor(value)
            return value
        raise AttributeError(f"'{type(self).__name__}' object has no attribute '{name}'")

    def __getitem__(self, key: str):
        return self.__getattr__(key)

    def __eq__(self, other):
        return self._data == other

    def __str__(self):
        return str(self._data)

    def __repr__(self):
        return repr(self._data)


class ResponseValidator:
    """响应验证器，整合所有验证逻辑"""

    def __init__(self, api_definition: Dict[str, Any]):
        """
        初始化响应验证器

        Args:
            api_definition: API定义
        """
        self.api_definition = api_definition
        self.assertion_engine = AssertionEngine()

    def validate_success_response(self, response, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        验证成功响应

        Args:
            response: HTTP响应对象
            request_data: 请求数据

        Returns:
            Dict: 验证结果
        """
        self.assertion_engine.clear_errors()
        assertions = self.api_definition.get("assertions", {})

        # 验证状态码
        expected_status = assertions.get("status_code", 200)
        self.assertion_engine.validate_status_code(response.status_code, expected_status)

        # 验证响应头
        if "headers" in assertions:
            response_headers = dict(response.headers)
            self.assertion_engine.validate_headers(response_headers, assertions["headers"])

        # 验证响应JSON结构
        try:
            response_data = response.json()
        except Exception as e:
            self.assertion_engine.validation_errors.append(f"Response JSON parsing failed: {str(e)}")
            return self._create_validation_result()

        if "response_schema" in assertions:
            self.assertion_engine.validate_json_schema(response_data, assertions["response_schema"])

        # 验证业务规则
        if "business_rules" in assertions:
            self.assertion_engine.validate_business_rules(
                response_data, request_data, assertions["business_rules"]
            )

        return self._create_validation_result()

    def validate_error_response(self, response, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        验证错误响应

        Args:
            response: HTTP响应对象
            request_data: 请求数据

        Returns:
            Dict: 验证结果
        """
        self.assertion_engine.clear_errors()
        error_assertions = self.api_definition.get("error_assertions", {})

        # 验证错误状态码
        if "status_code" in error_assertions:
            expected_status = error_assertions["status_code"]
            self.assertion_engine.validate_status_code(response.status_code, expected_status)

        # 验证错误响应JSON结构
        try:
            response_data = response.json()
        except Exception as e:
            self.assertion_engine.validation_errors.append(f"Error response JSON parsing failed: {str(e)}")
            return self._create_validation_result()

        if "response_schema" in error_assertions:
            self.assertion_engine.validate_json_schema(response_data, error_assertions["response_schema"])

        # 验证业务规则
        if "business_rules" in error_assertions:
            self.assertion_engine.validate_business_rules(
                response_data, request_data, error_assertions["business_rules"]
            )

        return self._create_validation_result()

    def _create_validation_result(self) -> Dict[str, Any]:
        """
        创建验证结果字典

        Returns:
            Dict: 验证结果
        """
        return {
            "is_valid": self.assertion_engine.is_valid(),
            "validation_errors": self.assertion_engine.get_validation_errors(),
            "business_rule_errors": self.assertion_engine.get_business_rule_errors(),
            "all_errors": self.assertion_engine.get_all_errors()
        }