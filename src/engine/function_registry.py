# src/engine/function_registry.py

"""
Function Registry for V2 Placeholder System

Provides 30+ built-in functions for dynamic data generation.
Supports syntax: ${fn:function_name(args)}

Examples:
- ${fn:random_username()}
- ${fn:random_email()}
- ${fn:timestamp()}
- ${fn:uuid()}
"""

import random
import string
import uuid
import time
from datetime import datetime, timedelta
from typing import Any, Dict, Callable


class FunctionRegistry:
    """
    Registry of built-in functions for placeholder resolution.
    """

    def __init__(self):
        self._functions: Dict[str, Callable] = {}
        self._register_builtin_functions()

    def _register_builtin_functions(self):
        """Register all built-in functions"""

        # Random string generators
        self.register('random_username', self._random_username)
        self.register('random_email', self._random_email)
        self.register('random_string', self._random_string)
        self.register('random_password', self._random_password)
        self.register('random_digits', self._random_digits)
        self.register('random_letters', self._random_letters)

        # Random numbers
        self.register('random_int', self._random_int)
        self.register('random_float', self._random_float)
        self.register('random_price', self._random_price)

        # UUID generators
        self.register('uuid', self._uuid)
        self.register('uuid4', self._uuid4)

        # Timestamp functions
        self.register('timestamp', self._timestamp)
        self.register('timestamp_ms', self._timestamp_ms)
        self.register('timestamp_days_ago', self._timestamp_days_ago)
        self.register('timestamp_days_later', self._timestamp_days_later)
        self.register('datetime', self._datetime)
        self.register('date', self._date)
        self.register('time', self._time)

        # Date arithmetic
        self.register('date_add_days', self._date_add_days)
        self.register('date_sub_days', self._date_sub_days)

        # String operations
        self.register('upper', self._upper)
        self.register('lower', self._lower)
        self.register('concat', self._concat)

        # Numeric operations
        self.register('add', self._add)
        self.register('subtract', self._subtract)
        self.register('multiply', self._multiply)
        self.register('divide', self._divide)

        # Encoding/Decoding
        self.register('base64_encode', self._base64_encode)
        self.register('base64_decode', self._base64_decode)

        # Boolean functions
        self.register('random_bool', self._random_bool)

    def register(self, name: str, func: Callable):
        """Register a custom function"""
        self._functions[name] = func

    def get(self, name: str) -> Callable:
        """Get a registered function by name"""
        return self._functions.get(name)

    def execute(self, name: str, *args, **kwargs) -> Any:
        """Execute a registered function with arguments"""
        func = self.get(name)
        if not func:
            raise ValueError(f"Function '{name}' not found in registry")
        return func(*args, **kwargs)

    # ============= Random String Generators =============

    def _random_username(self, prefix: str = 'user', length: int = 8) -> str:
        """Generate random username"""
        suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))
        return f"{prefix}_{suffix}"

    def _random_email(self, domain: str = 'example.com') -> str:
        """Generate random email address"""
        username = ''.join(random.choices(string.ascii_lowercase, k=8))
        return f"{username}@{domain}"

    def _random_string(self, length: int = 10, charset: str = None) -> str:
        """Generate random string with optional charset"""
        if charset is None:
            charset = string.ascii_letters + string.digits
        return ''.join(random.choices(charset, k=int(length)))

    def _random_password(self, length: int = 12) -> str:
        """Generate random password with mixed characters"""
        chars = string.ascii_letters + string.digits + '!@#$%^&*'
        return ''.join(random.choices(chars, k=int(length)))

    def _random_digits(self, length: int = 6) -> str:
        """Generate random digit string"""
        return ''.join(random.choices(string.digits, k=int(length)))

    def _random_letters(self, length: int = 8) -> str:
        """Generate random letter string"""
        return ''.join(random.choices(string.ascii_letters, k=int(length)))

    # ============= Random Numbers =============

    def _random_int(self, min_val: int = 1, max_val: int = 1000) -> int:
        """Generate random integer"""
        return random.randint(int(min_val), int(max_val))

    def _random_float(self, min_val: float = 0.0, max_val: float = 1.0, decimals: int = 2) -> float:
        """Generate random float"""
        value = random.uniform(float(min_val), float(max_val))
        return round(value, int(decimals))

    def _random_price(self, min_val: float = 1.0, max_val: float = 1000.0) -> float:
        """Generate random price (2 decimal places)"""
        return round(random.uniform(float(min_val), float(max_val)), 2)

    # ============= UUID Generators =============

    def _uuid(self) -> str:
        """Generate UUID4"""
        return str(uuid.uuid4())

    def _uuid4(self) -> str:
        """Generate UUID4"""
        return str(uuid.uuid4())

    # ============= Timestamp Functions =============

    def _timestamp(self) -> int:
        """Get current Unix timestamp (milliseconds) - compatible with API requirements"""
        return int(time.time() * 1000)

    def _timestamp_ms(self) -> int:
        """Get current Unix timestamp (milliseconds)"""
        return int(time.time() * 1000)

    def _timestamp_days_ago(self, days: int) -> int:
        """Get Unix timestamp (milliseconds) for N days ago"""
        past_time = datetime.now() - timedelta(days=int(days))
        return int(past_time.timestamp() * 1000)

    def _timestamp_days_later(self, days: int) -> int:
        """Get Unix timestamp (milliseconds) for N days later"""
        future_time = datetime.now() + timedelta(days=int(days))
        return int(future_time.timestamp() * 1000)

    def _datetime(self, format: str = '%Y-%m-%d %H:%M:%S') -> str:
        """Get current datetime as formatted string"""
        return datetime.now().strftime(format)

    def _date(self, format: str = '%Y-%m-%d') -> str:
        """Get current date as formatted string"""
        return datetime.now().strftime(format)

    def _time(self, format: str = '%H:%M:%S') -> str:
        """Get current time as formatted string"""
        return datetime.now().strftime(format)

    # ============= Date Arithmetic =============

    def _date_add_days(self, days: int, format: str = '%Y-%m-%d') -> str:
        """Add days to current date"""
        future_date = datetime.now() + timedelta(days=int(days))
        return future_date.strftime(format)

    def _date_sub_days(self, days: int, format: str = '%Y-%m-%d') -> str:
        """Subtract days from current date"""
        past_date = datetime.now() - timedelta(days=int(days))
        return past_date.strftime(format)

    # ============= String Operations =============

    def _upper(self, text: str) -> str:
        """Convert to uppercase"""
        return str(text).upper()

    def _lower(self, text: str) -> str:
        """Convert to lowercase"""
        return str(text).lower()

    def _concat(self, *args) -> str:
        """Concatenate multiple strings"""
        return ''.join(str(arg) for arg in args)

    # ============= Numeric Operations =============

    def _add(self, a: float, b: float) -> float:
        """Add two numbers"""
        return float(a) + float(b)

    def _subtract(self, a: float, b: float) -> float:
        """Subtract two numbers"""
        return float(a) - float(b)

    def _multiply(self, a: float, b: float) -> float:
        """Multiply two numbers"""
        return float(a) * float(b)

    def _divide(self, a: float, b: float) -> float:
        """Divide two numbers"""
        return float(a) / float(b)

    # ============= Encoding/Decoding =============

    def _base64_encode(self, text: str) -> str:
        """Base64 encode a string"""
        import base64
        return base64.b64encode(text.encode()).decode()

    def _base64_decode(self, text: str) -> str:
        """Base64 decode a string"""
        import base64
        return base64.b64decode(text.encode()).decode()

    # ============= Boolean Functions =============

    def _random_bool(self) -> bool:
        """Generate random boolean"""
        return random.choice([True, False])


# Global function registry instance
_global_registry = FunctionRegistry()


def get_function_registry() -> FunctionRegistry:
    """Get the global function registry instance"""
    return _global_registry
