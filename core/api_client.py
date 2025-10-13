# core/api_client.py

import requests
import allure
import json
from typing import Dict, Any

from core.context_manager import TestContext
from core.assertion_engine import AssertionEngine
from core.websocket_client import WebSocketClient
from utils.placeholder_parser import resolve_placeholders
from core.logger_config import logger



class ApiClient:
    """
    API client, the execution engine of the framework.
    Responsible for driving test workflow: parsing parameters, sending requests, calling assertions,
    extracting variables, and generating detailed reports.

    Supports both HTTP and WebSocket protocols.
    """
    def __init__(self, base_url: str):
        """
        Initialize the client.

        :param base_url: Base URL of the API, obtained from environment.
        """
        if not base_url:
            raise ValueError("API base_url cannot be empty")
        self.base_url = base_url
        self.session = requests.Session()

        # Disable environment variable proxy to avoid localhost requests going through proxy causing 502 errors
        self.session.trust_env = False

        self.assertion_engine = AssertionEngine()
        self.audit_trail = [] # Store audit trail for current test case execution
        # Store resolved data set variables used in current test case
        self.resolved_data_set_variables = {}

    def execute_steps(self, case_details: Dict[str, Any]):
        """
        Execute all steps under a test case template and apply correct validation override logic.

        :param case_details: Complete case information obtained from db_handler.get_case_details.
        """
        context = TestContext()
        data_set_variables = case_details.get('data_set_variables', {})
        validations_override = case_details.get('validations_override') or {}
        case_name = case_details.get('name', 'Unknown Case')
        all_steps = case_details.get('steps', [])

        allure.dynamic.title(case_name)

        # Lazy initialization: WebSocket client is only created when needed
        ws_client = None

        try:
            for step in all_steps:
                # Determine protocol (default to 'http' for backward compatibility)
                protocol = step.get('protocol', 'http')

                if protocol == 'http':
                    # Execute HTTP step (existing logic)
                    self._execute_http_step(step, context, data_set_variables, validations_override)

                elif protocol == 'websocket':
                    # Execute WebSocket step (new logic)
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

    def _execute_http_step(self, step: Dict[str, Any], context: TestContext, data_set_variables: Dict, validations_override: Dict):
        """
        Execute a single HTTP step (extracted from original execute_steps logic).

        :param step: Step configuration
        :param context: Test context for variable storage
        :param data_set_variables: Variables from data set
        :param validations_override: Validation overrides from data set
        """
        step_order = step.get('step_order')
        step_description = step.get('description', f'Step {step_order}')
        step_name = f"step_{step_order}"

        with allure.step(f"Step {step_order}: {step_description}"):
            step_status = 'passed'
            request_details_dict = {}
            response_data = {}

            try:
                # 1. Resolve all placeholders in request data
                api_url_path = resolve_placeholders(step.get('api_url_path', ''), context, data_set_variables)
                full_url = self.base_url + api_url_path

                headers = resolve_placeholders(step.get('headers'), context, data_set_variables)
                params = resolve_placeholders(step.get('params'), context, data_set_variables)
                body = resolve_placeholders(step.get('body'), context, data_set_variables)

                request_details_dict = {
                    "method": step.get('http_method'), "url": full_url,
                    "headers": headers, "params": params, "body": body
                }
                allure.attach(json.dumps(request_details_dict, indent=2, ensure_ascii=False), name="Request Details", attachment_type=allure.attachment_type.JSON)

                # 2. Send HTTP request
                response = self.session.request(
                    method=step.get('http_method'), url=full_url, headers=headers,
                    params=params, json=body, timeout=30
                )

                # 3. Standardize response data
                response_body = None
                try:
                    response_body = response.json()
                except json.JSONDecodeError:
                    response_body = response.text
                response_data = {'status_code': response.status_code, 'headers': dict(response.headers), 'body': response_body}

                allure.attach(json.dumps(response_data, indent=2, ensure_ascii=False), name="Response Details", attachment_type=allure.attachment_type.JSON)

                # 4. Store response in context
                context.add_step_response(step_name, response_data)

                # 5. Determine which validation rules to use (override or default)
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

                    # Pass raw validation rules and context required for parsing to assertion engine
                    self.assertion_engine.execute_assertions(
                        response_data,
                        final_validations,
                        context=context,
                        data_set_vars=data_set_variables
                    )

                    # Execute custom validations if present (e.g., for candlestick data)
                    if "customValidations" in final_validations:
                        self.assertion_engine.validate_candlestick_data(
                            response_data,
                            final_validations,
                            context=context,
                            data_set_vars=data_set_variables
                        )

                # 7. Extract and store output variables
                outputs = step.get('outputs')
                if outputs:
                    for output in outputs:
                        variable_name = output.get('variable_name')
                        if not variable_name: continue

                        context.extract_and_set_variable(
                            step_name, variable_name, output.get('source'), output.get('json_path')
                        )
                        extracted_value = context.get_variable(variable_name)
                        allure.attach(f"Extracted '{variable_name}' with value: {json.dumps(extracted_value)}", name="Variable Extraction", attachment_type=allure.attachment_type.TEXT)

            except Exception as e:
                step_status = 'failed'
                allure.attach(f"An error occurred during step execution:\n{type(e).__name__}: {e}", name="Step Execution Error", attachment_type=allure.attachment_type.TEXT)
                raise
            finally:
                # Record audit information regardless of success or failure
                self.audit_trail.append({
                    "step_order": step_order,
                    "action_description": step_description,
                    "request_details": request_details_dict,
                    "response_details": response_data,
                    "step_status": step_status
                })

    def _execute_websocket_step(self, step: Dict[str, Any], context: TestContext, data_set_variables: Dict, validations_override: Dict, ws_client: WebSocketClient):
        """
        Execute a single WebSocket step (MVP implementation).

        Supported actions:
        - connect: Establish WebSocket connection
        - send: Send a message to WebSocket server
        - wait: Wait for messages and validate
        - disconnect: Close WebSocket connection

        :param step: Step configuration
        :param context: Test context for variable storage
        :param data_set_variables: Variables from data set
        :param validations_override: Validation overrides from data set
        :param ws_client: WebSocket client instance
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
                if action == 'connect':
                    # Action: Connect to WebSocket server
                    url = resolve_placeholders(step.get('url'), context, data_set_variables)
                    timeout = step.get('timeout', 10)

                    request_details_dict = {"action": "connect", "url": url, "timeout": timeout}
                    allure.attach(json.dumps(request_details_dict, indent=2), name="WebSocket Connect", attachment_type=allure.attachment_type.JSON)

                    success = ws_client.connect(url, timeout)
                    if not success:
                        raise ConnectionError(f"Failed to connect to WebSocket: {url}")

                    response_data = {"connected": True, "url": url}

                elif action == 'send':
                    # Action: Send message to WebSocket
                    message = resolve_placeholders(step.get('message'), context, data_set_variables)

                    request_details_dict = {"action": "send", "message": message}
                    allure.attach(json.dumps(request_details_dict, indent=2, ensure_ascii=False), name="WebSocket Send", attachment_type=allure.attachment_type.JSON)

                    ws_client.send_message(message)
                    response_data = {"sent": True, "message": message}

                elif action == 'wait':
                    # Action: Wait for messages and validate
                    message_count = step.get('message_count', 1)
                    timeout = step.get('timeout', 30)

                    request_details_dict = {"action": "wait", "message_count": message_count, "timeout": timeout}
                    allure.attach(json.dumps(request_details_dict, indent=2), name="WebSocket Wait", attachment_type=allure.attachment_type.JSON)

                    # Wait for messages
                    messages = ws_client.wait_for_messages(message_count, timeout)
                    latest_message = messages[-1] if messages else None

                    response_data = {"messages": messages, "latest": latest_message, "count": len(messages)}
                    allure.attach(json.dumps(response_data, indent=2, ensure_ascii=False), name="WebSocket Messages", attachment_type=allure.attachment_type.JSON)

                    # Store messages in context (MVP: use latest message as 'body' for compatibility)
                    context.add_step_response(step_name, {'body': latest_message, 'messages': messages})

                    # Determine which validation rules to use
                    step_validations_override = validations_override.get(str(step_order))
                    final_validations = step_validations_override if step_validations_override is not None else step.get('validations')

                    # Execute validations on WebSocket messages
                    if final_validations:
                        source_message = "Using validation rules from 'case_data_sets' (override)." if step_validations_override else "Using default validation rules."
                        allure.attach(source_message, name="Validation Source")

                        # Use WebSocket-specific assertion method
                        self.assertion_engine.execute_websocket_assertions(
                            latest_message,
                            final_validations,
                            context=context,
                            data_set_vars=data_set_variables
                        )

                    # Extract output variables from latest message
                    outputs = step.get('outputs')
                    if outputs and latest_message:
                        for output in outputs:
                            variable_name = output.get('variable_name')
                            if not variable_name: continue

                            # Extract from latest message
                            json_path = output.get('json_path')
                            if json_path:
                                from jsonpath_ng import parse as jsonpath_parse
                                path_expr = jsonpath_parse(json_path)
                                matches = path_expr.find(latest_message)
                                if matches:
                                    value = matches[0].value
                                    context.set_variable(variable_name, value)
                                    allure.attach(f"Extracted '{variable_name}' with value: {json.dumps(value)}", name="Variable Extraction", attachment_type=allure.attachment_type.TEXT)

                elif action == 'disconnect':
                    # Action: Disconnect WebSocket
                    request_details_dict = {"action": "disconnect"}
                    allure.attach(json.dumps(request_details_dict, indent=2), name="WebSocket Disconnect", attachment_type=allure.attachment_type.JSON)

                    ws_client.disconnect()
                    response_data = {"disconnected": True}

                else:
                    raise ValueError(f"Unsupported WebSocket action: {action}. Must be 'connect', 'send', 'wait', or 'disconnect'.")

            except Exception as e:
                step_status = 'failed'
                allure.attach(f"An error occurred during WebSocket step execution:\n{type(e).__name__}: {e}", name="Step Execution Error", attachment_type=allure.attachment_type.TEXT)
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
