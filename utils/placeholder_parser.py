# utils/placeholder_parser.py

import re
import random
import string
from typing import Any, Dict
from core.context_manager import TestContext

# =================================================================
# 1. 动态变量生成函数 (Dynamic Variable Generators)
# =================================================================

def _generate_random_user() -> str:
    """生成一个 'testuser_' 前缀的随机用户名"""
    suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    return f"testuser_{suffix}"

def _generate_random_password(length: int = 12) -> str:
    """生成指定长度的、包含多种字符的随机密码"""
    if length < 4: length = 4
    chars = string.ascii_lowercase + string.ascii_uppercase + string.digits + "!@#$%^&*"
    password = [
        random.choice(string.ascii_lowercase),
        random.choice(string.ascii_uppercase),
        random.choice(string.digits),
        random.choice("!@#$%^&*"),
    ]
    password += random.choices(chars, k=length - 4)
    random.shuffle(password)
    return ''.join(password)

def _generate_random_phone() -> str:
    """生成一个11位的随机手机号码"""
    return '1' + ''.join(random.choices(string.digits, k=10))

def _generate_random_int(length: int = 6) -> int:
    """生成指定位数的随机整数"""
    if length <= 0: return 0
    start = 10**(length - 1)
    end = (10**length) - 1
    return random.randint(start, end)

# =================================================================
# 2. 核心解析逻辑  首次使用时生成并缓存
# =================================================================
def _resolve_single_string(data: str, context: 'TestContext', data_set_vars: Dict[str, Any]) -> str:
    """
    以正确的优先级顺序,循环解析单个字符串中的所有占位符,直到没有变化为止。
    动态变量 ({{$...}}) 会在首次使用时生成并存入 context。
    """
    if not isinstance(data, str):
        return data

    for _ in range(10): # 循环以处理嵌套
        original_data = data

        # --- Pass 1: 解析动态变量 ({{$...}}) ---
        def replace_dynamic_var(match):
            placeholder = match.group(0) # 完整的占位符, e.g., "{{$randomUser}}"

            # 检查上下文中是否已缓存
            memoized_value = context.get_variable(placeholder)
            if memoized_value is not None:
                return str(memoized_value)

            # 如果未缓存,则生成新值
            func_call_str = match.group(1) # 内部指令, e.g., "$randomUser"
            func_match = re.match(r'(\$\w+)(?:\((\d*)\))?', func_call_str)
            if not func_match: return placeholder
            func_name, arg_str = func_match.groups()

            generated_value = None
            if func_name == '$randomUser': generated_value = _generate_random_user()
            elif func_name == '$randomPassword': generated_value = _generate_random_password(int(arg_str) if arg_str else 12)
            elif func_name == '$randomPhone': generated_value = _generate_random_phone()
            elif func_name in ('$randomInt', '$randomID', '$randomId'): generated_value = str(_generate_random_int(int(arg_str) if arg_str else 6))

            if generated_value is not None:
                # 将新生成的值存入上下文进行缓存
                context.set_variable(placeholder, generated_value)
                return str(generated_value)

            return placeholder

        data = re.sub(r'\{\{(\$\w+(?:\(\d*\))?)\}\}', replace_dynamic_var, data)

        # --- Pass 2: 解析数据集变量 ({{@...}}) ---
        def replace_dataset_var(match):
            var_name = match.group(1)
            value = data_set_vars.get(var_name)
            return str(value) if value is not None else f"{{{{@{var_name}}}}}"

        data = re.sub(r'\{\{@(\w+)\}\}', replace_dataset_var, data)

        # --- Pass 3: 解析步骤间变量 ({{...}}) ---
        def replace_step_var(match):
            path_string = match.group(1)
            value = context.get_value_by_path(path_string)
            return str(value) if value is not None else f"{{{{{path_string}}}}}"

        data = re.sub(r'\{\{([^@$}][^}]+)\}\}', replace_step_var, data)

        if data == original_data:
            break

    return data

def resolve_placeholders(data_structure: Any, context: 'TestContext', data_set_vars: Dict[str, Any]) -> Any:
    """递归地解析数据结构（字典、列表、字符串）中的所有占位符。"""
    if isinstance(data_structure, dict):
        return {key: resolve_placeholders(value, context, data_set_vars) for key, value in data_structure.items()}
    elif isinstance(data_structure, list):
        return [resolve_placeholders(item, context, data_set_vars) for item in data_structure]
    else:
        return _resolve_single_string(data_structure, context, data_set_vars)
