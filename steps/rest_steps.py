"""
REST API test step definitions
Dedicated to REST API related test scenarios
"""

from behave import given, when, then
from api_clients.rest_client import RestClient


@given('I have a REST API client')
def step_given_rest_client(context):
    """Initialize REST API client"""
    context.rest_client = RestClient()
    print("REST API client initialized")


@when('I call REST API "{api_key}"')
def step_when_call_rest_api(context, api_key):
    """
    Call REST API (get parameters from datatable)

    Example:
        When I call REST API "get_candlestick"
            | parameter       | value        |
            | instrument_name | BTCUSDT-PERP |
            | timeframe       | M5           |
    """
    # Get parameters from datatable
    params = {}
    if hasattr(context, 'table') and context.table:
        for row in context.table:
            params[row['parameter']] = row['value']

    print(f"Calling REST API: {api_key}, parameters: {params}")
    context.api_key = api_key
    context.api_params = params
    context.response = context.rest_client.call_api(api_key, **params)


@then('the response should validate successfully')
def step_then_response_should_validate_success(context):
    """Validate response successfully"""
    validation_result = context.rest_client.validate_response(context.api_key, expect_success=True)

    print(f"Validation result: {validation_result}")

    if not validation_result['is_valid']:
        errors = '\n'.join(validation_result['all_errors'])
        raise AssertionError(f"Response validation failed:\n{errors}")

    print("Response validation successful")


@then('the response should validate as error')
def step_then_response_should_validate_error(context):
    """Validate response as error"""
    validation_result = context.rest_client.validate_response(context.api_key, expect_success=False)

    print(f"Error validation result: {validation_result}")

    if not validation_result['is_valid']:
        errors = '\n'.join(validation_result['all_errors'])
        raise AssertionError(f"Error response validation failed:\n{errors}")

    print("Error response validation successful")