"""
WebSocket API test step definitions
Dedicated to WebSocket API related test scenarios
"""

from behave import given, when, then
from api_clients.websocket_client import WebSocketClient


@given('I have a WebSocket client')
def step_given_websocket_client(context):
    """Initialize WebSocket client"""
    context.ws_client = WebSocketClient()
    print("WebSocket client initialized")


@when('I connect to WebSocket server')
def step_when_connect_websocket(context):
    """Connect to WebSocket server"""
    print("Connecting to WebSocket server...")
    context.is_connected = context.ws_client.connect()


@when('I call WebSocket API "{api_key}"')
def step_when_call_websocket_api(context, api_key):
    """
    Call WebSocket API (get parameters from datatable)

    Example:
        When I call WebSocket API "subscribe_orderbook"
            | parameter       | value     |
            | instrument_name | BTC_USDT  |
            | depth           | 10        |
    """
    # Get parameters from datatable
    params = {}
    if hasattr(context, 'table') and context.table:
        for row in context.table:
            param_value = row['value']
            # Try to convert numeric types
            try:
                if param_value.isdigit():
                    param_value = int(param_value)
                elif param_value.replace('.', '', 1).isdigit():
                    param_value = float(param_value)
            except:
                pass
            params[row['parameter']] = param_value

    print(f"Calling WebSocket API: {api_key}, parameters: {params}")
    context.ws_api_key = api_key
    context.ws_api_params = params
    context.ws_send_success = context.ws_client.call_websocket_api(api_key, **params)


@when('I wait for WebSocket message')
def step_when_wait_websocket_message(context):
    """Wait for WebSocket message"""
    print("Waiting for WebSocket message...")
    context.message_received = context.ws_client.wait_for_message()


@then('WebSocket should connect successfully')
def step_then_websocket_should_connect(context):
    """Validate WebSocket connection successful"""
    assert context.is_connected, "WebSocket connection failed"
    print("WebSocket connected successfully")


@then('WebSocket message should send successfully')
def step_then_websocket_message_should_send(context):
    """Validate WebSocket message sent successfully"""
    assert context.ws_send_success, "WebSocket message send failed"
    print("WebSocket message sent successfully")


@then('should receive WebSocket message')
def step_then_should_receive_websocket_message(context):
    """Validate received WebSocket message"""
    assert context.message_received, "No WebSocket message received"
    print("WebSocket message received")


@then('WebSocket message should validate successfully')
def step_then_websocket_message_should_validate(context):
    """Validate WebSocket message content"""
    validation_result = context.ws_client.validate_websocket_response(
        context.ws_api_key, "data_message"
    )

    print(f"WebSocket message validation result: {validation_result}")

    if not validation_result['is_valid']:
        errors = '\n'.join(validation_result['all_errors'])
        raise AssertionError(f"WebSocket message validation failed:\n{errors}")

    print("WebSocket message validation successful")


@then('I disconnect WebSocket connection')
def step_then_disconnect_websocket(context):
    """Disconnect WebSocket connection"""
    context.ws_client.disconnect()
    print("WebSocket connection disconnected")