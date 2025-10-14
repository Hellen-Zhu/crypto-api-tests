# src/engine/placeholder_resolver.py

"""
Unified Placeholder Resolver

Supports multiple placeholder syntaxes:
1. ${variable} - Dataset variables
2. ${fn:function_name(args)} - Function calls
3. ${step.response.body.field} - Cross-step references
4. {{@variable}} - Legacy dataset variables (backward compatibility)
5. {{step.response.body.field}} - Legacy cross-step (backward compatibility)

This resolver provides a unified system that handles all placeholder types
and maintains backward compatibility with the old {{@variable}} syntax.
"""

import re
from typing import Any, Dict, Optional
from jsonpath_ng import parse as jsonpath_parse

from src.engine.function_registry import get_function_registry
from src.common.logger import logger


class PlaceholderResolver:
    """
    Unified Placeholder Resolver with enhanced syntax support.

    Handles:
    - Dataset variables: ${variable} or {{@variable}}
    - Function calls: ${fn:function_name(args)}
    - Cross-step references: ${step.response.body.field}
    - Legacy syntax for backward compatibility
    """

    def __init__(self, context=None, data_set_vars: Dict = None):
        """
        Initialize the resolver.

        Args:
            context: TestContext instance for cross-step variable access
            data_set_vars: Dataset variables from test case
        """
        self.context = context
        self.data_set_vars = data_set_vars or {}
        self.function_registry = get_function_registry()

        # Cache for generated function values (to maintain consistency)
        self._function_cache: Dict[str, Any] = {}

    def resolve(self, data: Any) -> Any:
        """
        Resolve all placeholders in the given data.

        Supports nested structures (dict, list, str).

        Args:
            data: Data containing placeholders

        Returns:
            Data with all placeholders resolved
        """
        if isinstance(data, dict):
            return {key: self.resolve(value) for key, value in data.items()}
        elif isinstance(data, list):
            return [self.resolve(item) for item in data]
        elif isinstance(data, str):
            return self._resolve_string(data)
        else:
            return data

    def _resolve_string(self, text: str) -> Any:
        """
        Resolve placeholders in a string.

        Handles both new ${...} and legacy {{...}} syntaxes.
        """
        if not isinstance(text, str):
            return text

        # Pattern for ${...} syntax (new V2 style)
        pattern_v2 = r'\$\{([^}]+)\}'

        # Pattern for {{...}} syntax (legacy style)
        pattern_legacy = r'\{\{([^}]+)\}\}'

        # Try V2 syntax first
        if '${' in text:
            matches = re.findall(pattern_v2, text)
            if matches:
                for match in matches:
                    placeholder = '${' + match + '}'
                    resolved_value = self._resolve_placeholder(match)

                    # If the entire string is just the placeholder, return the resolved value directly
                    if text == placeholder:
                        return resolved_value

                    # Otherwise, replace the placeholder in the string
                    text = text.replace(placeholder, str(resolved_value))
                return text

        # Try legacy syntax for backward compatibility
        if '{{' in text:
            matches = re.findall(pattern_legacy, text)
            if matches:
                for match in matches:
                    placeholder = '{{' + match + '}}'
                    resolved_value = self._resolve_legacy_placeholder(match)

                    # If the entire string is just the placeholder, return the resolved value directly
                    if text == placeholder:
                        return resolved_value

                    # Otherwise, replace the placeholder in the string
                    text = text.replace(placeholder, str(resolved_value))
                return text

        return text

    def _resolve_placeholder(self, content: str) -> Any:
        """
        Resolve a single placeholder (V2 syntax: ${...}).

        Determines the type of placeholder and resolves accordingly:
        1. fn:function_name(args) -> Function call
        2. @variable -> Dataset variable (legacy compatibility)
        3. step.response.body.field -> Cross-step reference
        4. variable -> Dataset variable (default)
        """
        content = content.strip()

        # 1. Function call: ${fn:function_name(args)}
        if content.startswith('fn:'):
            return self._resolve_function(content[3:])

        # 2. Legacy dataset variable: ${@variable}
        if content.startswith('@'):
            variable_name = content[1:]
            return self._resolve_dataset_variable(variable_name)

        # 3. Cross-step reference: ${step.response.body.field}
        if '.' in content and self.context:
            return self._resolve_cross_step(content)

        # 4. Default: Dataset variable: ${variable}
        return self._resolve_dataset_variable(content)

    def _resolve_legacy_placeholder(self, content: str) -> Any:
        """
        Resolve legacy placeholder syntax ({{...}}).

        Supports:
        - {{@variable}} -> Dataset variable
        - {{step.response.body.field}} -> Cross-step reference
        - {{$randomUser}} -> Dynamic variable (mapped to function)
        """
        content = content.strip()

        # Legacy dataset variable: {{@variable}}
        if content.startswith('@'):
            variable_name = content[1:]
            return self._resolve_dataset_variable(variable_name)

        # Legacy dynamic variable: {{$randomUser}} -> map to function
        if content.startswith('$'):
            return self._resolve_legacy_dynamic(content[1:])

        # Legacy cross-step: {{step.response.body.field}}
        if '.' in content and self.context:
            return self._resolve_cross_step(content)

        # Default: treat as dataset variable
        return self._resolve_dataset_variable(content)

    def _resolve_function(self, func_expr: str) -> Any:
        """
        Resolve a function call: function_name(args)

        Examples:
        - random_username()
        - random_int(1, 100)
        - date_add_days(7)
        """
        # Check cache first (for consistency in same test)
        if func_expr in self._function_cache:
            return self._function_cache[func_expr]

        # Parse function name and arguments
        match = re.match(r'(\w+)\((.*?)\)', func_expr)
        if not match:
            logger.warning(f"Invalid function syntax: {func_expr}")
            return f"${{fn:{func_expr}}}"  # Return original placeholder

        func_name = match.group(1)
        args_str = match.group(2).strip()

        # Parse arguments
        args = []
        if args_str:
            # Simple argument parsing (handles strings, numbers, booleans)
            for arg in args_str.split(','):
                arg = arg.strip()
                # Remove quotes from string arguments
                if (arg.startswith("'") and arg.endswith("'")) or \
                   (arg.startswith('"') and arg.endswith('"')):
                    args.append(arg[1:-1])
                # Convert numbers
                elif arg.isdigit():
                    args.append(int(arg))
                elif arg.replace('.', '', 1).isdigit():
                    args.append(float(arg))
                # Convert booleans
                elif arg.lower() == 'true':
                    args.append(True)
                elif arg.lower() == 'false':
                    args.append(False)
                else:
                    args.append(arg)

        try:
            # Execute function
            result = self.function_registry.execute(func_name, *args)

            # Cache the result
            self._function_cache[func_expr] = result

            logger.debug(f"Function resolved: {func_name}({args}) -> {result}")
            return result
        except Exception as e:
            logger.error(f"Error executing function '{func_name}': {e}")
            return f"${{fn:{func_expr}}}"  # Return original placeholder

    def _resolve_dataset_variable(self, variable_name: str) -> Any:
        """
        Resolve a dataset variable.

        Looks up the variable in data_set_vars.
        """
        value = self.data_set_vars.get(variable_name)

        if value is not None:
            logger.debug(f"Dataset variable resolved: {variable_name} -> {value}")
            return value
        else:
            logger.warning(f"Dataset variable not found: {variable_name}")
            return f"${{{variable_name}}}"  # Return original placeholder

    def _resolve_cross_step(self, path: str) -> Any:
        """
        Resolve a cross-step reference: step.response.body.field

        Uses TestContextV2 to retrieve values from previous steps.
        """
        if not self.context:
            logger.warning(f"No context available for cross-step reference: {path}")
            return f"${{{path}}}"

        # Parse path: step_name.source.data_source.json_path
        parts = path.split('.', 1)
        if len(parts) < 2:
            logger.warning(f"Invalid cross-step path: {path}")
            return f"${{{path}}}"

        step_name = parts[0]
        json_path = parts[1]

        # Get step response from context
        step_response = self.context.get_step_response(step_name)
        if not step_response:
            logger.warning(f"Step not found in context: {step_name}")
            return f"${{{path}}}"

        # Use JSONPath to extract value
        try:
            path_expr = jsonpath_parse(json_path)
            matches = path_expr.find(step_response)

            if matches:
                value = matches[0].value
                logger.debug(f"Cross-step resolved: {path} -> {value}")
                return value
            else:
                logger.warning(f"JSONPath not found: {json_path} in step {step_name}")
                return f"${{{path}}}"
        except Exception as e:
            logger.error(f"Error resolving cross-step reference '{path}': {e}")
            return f"${{{path}}}"

    def _resolve_legacy_dynamic(self, variable_name: str) -> Any:
        """
        Resolve legacy dynamic variables: {{$randomUser}}

        Maps old {{$...}} syntax to new function calls.
        """
        # Mapping of legacy dynamic variables to V2 functions
        legacy_mapping = {
            'randomUser': 'random_username()',
            'randomUsername': 'random_username()',
            'randomEmail': 'random_email()',
            'randomPassword': 'random_password()',
            'randomString': 'random_string()',
            'randomInt': 'random_int()',
            'timestamp': 'timestamp()',
            'uuid': 'uuid()',
        }

        func_expr = legacy_mapping.get(variable_name)
        if func_expr:
            logger.debug(f"Mapping legacy dynamic variable: {{{{${variable_name}}}}} -> {func_expr}")
            return self._resolve_function(func_expr)
        else:
            logger.warning(f"Unknown legacy dynamic variable: {{{{${variable_name}}}}}")
            return f"{{{{${variable_name}}}}}"


def resolve_placeholders(data: Any, context=None, data_set_vars: Dict = None) -> Any:
    """
    Convenience function to resolve placeholders.

    Args:
        data: Data containing placeholders
        context: TestContext instance (optional)
        data_set_vars: Dataset variables (optional)

    Returns:
        Data with all placeholders resolved
    """
    resolver = PlaceholderResolver(context=context, data_set_vars=data_set_vars)
    return resolver.resolve(data)
