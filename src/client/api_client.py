# src/client/api_client.py

"""
API Client - Enhanced with Unified Placeholder System

Key features:
- Uses unified placeholder resolver (supports both ${} and {{}} syntax)
- Enhanced context manager with auto-capture
- Built-in function registry (30+ functions)
- Better error handling and debugging
- Full backward compatibility with legacy syntax
"""

import requests
import allure
import json
from typing import Dict, Any

from src.engine.context_manager import TestContext
from src.engine.assertion_engine import AssertionEngine
from src.client.websocket_client import WebSocketClient
from src.engine.placeholder_resolver import PlaceholderResolver
from src.common.logger import logger


class ApiClient:
    """
    Enhanced API client with unified placeholder system.

    Features:
    - Unified placeholder resolution (${} and {{}} syntax)
    - Function calls: ${fn:random_username()}
    - Dataset variables: ${variable} or {{@variable}}
    - Cross-step references: ${step.response.body.field}
    - Full backward compatibility with legacy test cases
    """

    def __init__(self, base_url: str):
        """
        Initialize the API client.

        Args:
            base_url: Base URL of the API, obtained from environment
        """
        if not base_url:
            raise ValueError("API base_url cannot be empty")

        self.base_url = base_url
        self.session = requests.Session()

        # Disable environment variable proxy to avoid localhost issues
        self.session.trust_env = False

        self.assertion_engine = AssertionEngine()
        self.audit_trail = []  # Store audit trail for current test case
        self.resolved_data_set_variables = {}  # Store resolved variables

    def execute_steps(self, case_details: Dict[str, Any]):
        """
        Execute all steps in a test case using enhanced system.

        Args:
            case_details: Complete case information from database
        """
        # Use enhanced context manager
        context = TestContext()

        data_set_variables = case_details.get('data_set_variables', {})
        validations_override = case_details.get('validations_override') or {}
        case_name = case_details.get('name', 'Unknown Case')
        all_steps = case_details.get('steps', [])

        allure.dynamic.title(case_name)

        # Store dataset variables for audit trail
        self.resolved_data_set_variables = data_set_variables.copy()

        # Lazy initialization: WebSocket client only created when needed
        ws_client = None

        try:
            for step in all_steps:
                # Determine protocol (default to 'http')
                protocol = step.get('protocol', 'http')

                if protocol == 'http':
                    self._execute_http_step(step, context, data_set_variables, validations_override)

                elif protocol == 'websocket':
                    if ws_client is None:
                        ws_client = WebSocketClient()
                    self._execute_websocket_step(step, context, data_set_variables, validations_override, ws_client)

                else:
                    raise ValueError(f"Unsupported protocol: {protocol}. Must be 'http' or 'websocket'.")

        finally:
            # Cleanup: ensure WebSocket connection is closed
            if ws_client:
                try:
                    ws_client.disconnect()
                except Exception as e:
                    logger.warning(f"Error during WebSocket cleanup: {e}")

    def _execute_http_step(
        self,
        step: Dict[str, Any],
        context: TestContext,
        data_set_variables: Dict,
        validations_override: Dict
    ):
        """
        Execute a single HTTP step using enhanced resolver.

        Args:
            step: Step configuration
            context: TestContext for variable storage
            data_set_variables: Dataset variables
            validations_override: Validation overrides
        """
        step_order = step.get('step_order')
        step_description = step.get('description', f'Step {step_order}')
        step_name = f"step_{step_order}"

        with allure.step(f"Step {step_order}: {step_description}"):
            step_status = 'passed'
            request_details_dict = {}
            response_data = {}

            try:
                # Initialize placeholder resolver
                resolver = PlaceholderResolver(
                    context=context,
                    data_set_vars=data_set_variables
                )

                # 1. Resolve all placeholders
                api_url_path = resolver.resolve(step.get('api_url_path', ''))
                full_url = self.base_url + api_url_path

                headers = resolver.resolve(step.get('headers'))
                params = resolver.resolve(step.get('params'))
                body = resolver.resolve(step.get('body'))

                request_details_dict = {
                    "method": step.get('http_method'),
                    "url": full_url,
                    "headers": headers,
                    "params": params,
                    "body": body
                }
                allure.attach(
                    json.dumps(request_details_dict, indent=2, ensure_ascii=False),
                    name="Request Details",
                    attachment_type=allure.attachment_type.JSON
                )

                # 2. Send HTTP request
                response = self.session.request(
                    method=step.get('http_method'),
                    url=full_url,
                    headers=headers,
                    params=params,
                    json=body,
                    timeout=30
                )

                # 3. Standardize response data
                response_body = None
                try:
                    response_body = response.json()
                except json.JSONDecodeError:
                    response_body = response.text

                response_data = {
                    'status_code': response.status_code,
                    'headers': dict(response.headers),
                    'body': response_body
                }

                allure.attach(
                    json.dumps(response_data, indent=2, ensure_ascii=False),
                    name="Response Details",
                    attachment_type=allure.attachment_type.JSON
                )

                # 4. Store response in context (auto-capture)
                context.add_step_response(step_name, response_data)

                # 5. Determine validation rules (override or default)
                final_validations = None
                step_validations_override = validations_override.get(str(step_order))
                default_validations = step.get('validations')

                if step_validations_override is not None:
                    final_validations = step_validations_override
                    source_message = "Using validation rules from 'case_data_sets' (override)."
                else:
                    final_validations = default_validations
                    source_message = "Using default validation rules from 'api_auto_cases.parameters'."

                # 6. Execute assertions
                if final_validations:
                    allure.attach(source_message, name="Validation Source")

                    # Pass to assertion engine
                    self.assertion_engine.execute_assertions(
                        response_data,
                        final_validations,
                        context=context,
                        data_set_vars=data_set_variables
                    )

                    # Execute custom validations if present
                    if "customValidations" in final_validations:
                        self.assertion_engine.validate_candlestick_data(
                            response_data,
                            final_validations,
                            context=context,
                            data_set_vars=data_set_variables
                        )

            except Exception as e:
                step_status = 'failed'
                allure.attach(
                    f"An error occurred during step execution:\n{type(e).__name__}: {e}",
                    name="Step Execution Error",
                    attachment_type=allure.attachment_type.TEXT
                )
                raise

            finally:
                # Record audit information
                self.audit_trail.append({
                    "step_order": step_order,
                    "action_description": step_description,
                    "request_details": request_details_dict,
                    "response_details": response_data,
                    "step_status": step_status
                })

    def _execute_websocket_step(
        self,
        step: Dict[str, Any],
        context: TestContext,
        data_set_variables: Dict,
        validations_override: Dict,
        ws_client: WebSocketClient
    ):
        """
        Execute a single WebSocket step using enhanced resolver.

        Args:
            step: Step configuration
            context: TestContext for variable storage
            data_set_variables: Dataset variables
            validations_override: Validation overrides
            ws_client: WebSocket client instance
        """
        step_order = step.get('step_order')
        step_description = step.get('description', f'Step {step_order}')
        step_name = f"step_{step_order}"
        action = step.get('action')

        if not action:
            raise ValueError(f"WebSocket step {step_order} missing 'action' field")

        with allure.step(f"Step {step_order}: {step_description}"):
            step_status = 'passed'
            request_details_dict = {}
            response_data = {}

            try:
                # Initialize placeholder resolver
                resolver = PlaceholderResolver(
                    context=context,
                    data_set_vars=data_set_variables
                )

                if action == 'connect':
                    # Action: Connect to WebSocket
                    request = step.get('request', {})
                    url = resolver.resolve(request.get('url'))
                    timeout = request.get('timeout', 10)

                    request_details_dict = {"action": "connect", "url": url, "timeout": timeout}
                    allure.attach(
                        json.dumps(request_details_dict, indent=2),
                        name="WebSocket Connect",
                        attachment_type=allure.attachment_type.JSON
                    )

                    success = ws_client.connect(url, timeout)
                    if not success:
                        raise ConnectionError(f"Failed to connect to WebSocket: {url}")

                    response_data = {"connected": True, "url": url}

                elif action == 'send':
                    # Action: Send message
                    request = step.get('request', {})
                    message = resolver.resolve(request.get('body'))

                    request_details_dict = {"action": "send", "message": message}
                    allure.attach(
                        json.dumps(request_details_dict, indent=2, ensure_ascii=False),
                        name="WebSocket Send",
                        attachment_type=allure.attachment_type.JSON
                    )

                    ws_client.send_message(message)
                    response_data = {"sent": True, "message": message}

                elif action == 'wait':
                    # Action: Wait for messages
                    request = step.get('request', {})
                    message_count = request.get('count', 1)
                    timeout = request.get('timeout', 30)

                    request_details_dict = {
                        "action": "wait",
                        "message_count": message_count,
                        "timeout": timeout
                    }
                    allure.attach(
                        json.dumps(request_details_dict, indent=2),
                        name="WebSocket Wait",
                        attachment_type=allure.attachment_type.JSON
                    )

                    messages = ws_client.wait_for_messages(message_count, timeout)
                    latest_message = messages[-1] if messages else None

                    response_data = {
                        "messages": messages,
                        "latest": latest_message,
                        "count": len(messages)
                    }
                    allure.attach(
                        json.dumps(response_data, indent=2, ensure_ascii=False),
                        name="WebSocket Messages",
                        attachment_type=allure.attachment_type.JSON
                    )

                    # Store in context
                    context.add_step_response(step_name, {
                        'body': latest_message,
                        'messages': messages
                    })

                    # Validations
                    step_validations_override = validations_override.get(str(step_order))
                    final_validations = (
                        step_validations_override
                        if step_validations_override is not None
                        else step.get('validations')
                    )

                    if final_validations:
                        source_message = (
                            "Using validation rules from 'case_data_sets' (override)."
                            if step_validations_override
                            else "Using default validation rules."
                        )
                        allure.attach(source_message, name="Validation Source")

                        self.assertion_engine.execute_websocket_assertions(
                            latest_message,
                            final_validations,
                            context=context,
                            data_set_vars=data_set_variables
                        )

                elif action == 'disconnect':
                    # Action: Disconnect
                    request_details_dict = {"action": "disconnect"}
                    allure.attach(
                        json.dumps(request_details_dict, indent=2),
                        name="WebSocket Disconnect",
                        attachment_type=allure.attachment_type.JSON
                    )

                    ws_client.disconnect()
                    response_data = {"disconnected": True}

                else:
                    raise ValueError(
                        f"Unsupported WebSocket action: {action}. "
                        f"Must be 'connect', 'send', 'wait', or 'disconnect'."
                    )

            except Exception as e:
                step_status = 'failed'
                allure.attach(
                    f"An error occurred during WebSocket step execution:\n{type(e).__name__}: {e}",
                    name="Step Execution Error",
                    attachment_type=allure.attachment_type.TEXT
                )
                raise

            finally:
                # Record audit information
                self.audit_trail.append({
                    "step_order": step_order,
                    "action_description": step_description,
                    "request_details": request_details_dict,
                    "response_details": response_data,
                    "step_status": step_status
                })
