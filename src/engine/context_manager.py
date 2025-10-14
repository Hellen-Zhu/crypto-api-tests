# src/engine/context_manager.py

"""
Enhanced Test Context Manager

Key features:
- Auto-capture: Automatically stores all step responses
- Cross-step data access with JSONPath
- Better debugging support
- Cleaner API
"""

from typing import Any, Dict, Optional
from jsonpath_ng import parse as jsonpath_parse
from src.common.logger import logger


class TestContext:
    """
    Enhanced test context manager.

    Manages:
    - Step responses (auto-captured)
    - Cross-step data access
    """

    def __init__(self):
        """Initialize the test context"""
        # Store complete step responses: {step_name: response_data}
        self._step_responses: Dict[str, Dict[str, Any]] = {}

    def add_step_response(self, step_name: str, response_data: Dict[str, Any]):
        """
        Store a complete step response (auto-capture).

        Args:
            step_name: Name/identifier of the step (e.g., 'step_1', 'login')
            response_data: Complete response data (status_code, headers, body, etc.)
        """
        self._step_responses[step_name] = response_data
        logger.debug(f"[Context] Captured response for step: {step_name}")

    def get_step_response(self, step_name: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve a step's complete response.

        Args:
            step_name: Name of the step

        Returns:
            Complete response data or None if not found
        """
        return self._step_responses.get(step_name)


    def get_value_by_path(self, path: str) -> Any:
        """
        Get a value using a dotted path notation.

        Supports:
        - step.response.body.field -> Extract from step response

        Args:
            path: Dotted path to the value

        Returns:
            Extracted value or None
        """
        # Parse as step reference: step_name.source.field
        parts = path.split('.', 1)
        if len(parts) < 2:
            logger.warning(f"[Context] Invalid path format: {path}")
            return None

        step_name = parts[0]
        json_path = parts[1]

        step_response = self.get_step_response(step_name)
        if not step_response:
            logger.warning(f"[Context] Step '{step_name}' not found for path: {path}")
            return None

        # Use JSONPath to extract value
        try:
            path_expr = jsonpath_parse(json_path)
            matches = path_expr.find(step_response)

            if matches:
                return matches[0].value
            else:
                logger.warning(f"[Context] Path '{json_path}' not found in step '{step_name}'")
                return None

        except Exception as e:
            logger.error(f"[Context] Error extracting value by path '{path}': {e}")
            return None

    def has_step(self, step_name: str) -> bool:
        """
        Check if a step response exists.

        Args:
            step_name: Name of the step

        Returns:
            True if step exists, False otherwise
        """
        return step_name in self._step_responses

    def get_all_steps(self) -> Dict[str, Dict[str, Any]]:
        """
        Get all stored step responses.

        Returns:
            Dictionary of all step responses
        """
        return self._step_responses.copy()

    def clear(self):
        """Clear all stored data (for test isolation)"""
        self._step_responses.clear()
        logger.debug("[Context] Cleared all data")

    def __repr__(self):
        """String representation for debugging"""
        return (
            f"TestContext("
            f"steps={list(self._step_responses.keys())}"
            f")"
        )
