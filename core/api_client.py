# core/api_client.py

import requests
import allure
import json
from typing import Dict, Any

from core.context_manager import TestContext
from core.assertion_engine import AssertionEngine
from utils.placeholder_parser import resolve_placeholders



class ApiClient:
    """
    API client, the execution engine of the framework.
    Responsible for driving test workflow: parsing parameters, sending requests, calling assertions,
    extracting variables, and generating detailed reports.
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

    def execute_steps(self, case_details: Dict[str, Any], app_db_conn=None):
        """
        Execute all steps under a test case template and apply correct validation override logic.

        :param case_details: Complete case information obtained from db_handler.get_case_details.
        :param app_db_conn: (Optional) Connection to application database under test.
        """
        context = TestContext()
        data_set_variables = case_details.get('data_set_variables', {})
        validations_override = case_details.get('validations_override') or {}
        case_name = case_details.get('name', 'Unknown Case')
        all_steps = case_details.get('steps', [])

        allure.dynamic.title(case_name)

        for step in all_steps:
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
                            app_db_conn=app_db_conn,
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
