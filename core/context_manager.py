# core/context_manager.py
from jsonpath_ng import parse
from core.logger_config import logger

class TestContext:
    def __init__(self):
        self.storage = {}

    def set(self, key, value):
        self.storage[key] = value

    def get(self, key):
        return self.storage.get(key)

    def get_variable(self, variable_name):
        """获取已存储的变量值"""
        return self.storage.get(variable_name)

    def set_variable(self, variable_name, value):
        """直接设置变量值"""
        self.storage[variable_name] = value

    def add_step_response(self, step_name, response_data):
        """
        将一个步骤的完整响应数据存入上下文。
        """
        self.storage[step_name] = {'response': response_data}

    def get_value_by_path(self, path_string):
        """
        根据 "response.body" 这样的路径字符串从 context 中取值
        """
        try:
            # 首先检查是否是直接的变量引用
            if '.' not in path_string:
                return self.get_variable(path_string)

            parts = path_string.split('.')
            step_name, source_type, data_source, *json_path_parts = parts

            data = self.storage[step_name][source_type][data_source]

            json_path_expr = parse('.'.join(json_path_parts))
            match = json_path_expr.find(data)

            return match[0].value if match else None
        except (KeyError, IndexError) as e:
            logger.error(f"Error resolving path '{path_string}': {e}")
            return None
    def extract_and_set_variable(self, step_name, variable_name, source, json_path):
        """从指定步骤的响应中提取并设置变量"""
        # source 可能是 'response_body' 或 'response_headers'
        data_source = 'body' if source == 'response_body' else 'headers'

        path_string = f"{step_name}.response.{data_source}.{json_path}"
        value = self.get_value_by_path(path_string)
        if value is None:
            raise ValueError(f"无法从路径 '{path_string}' 提取到值")

        self.set_variable(variable_name, value)