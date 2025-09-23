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


@when('I call WebSocket API "{api_key}" with channel "{channel}"')
def step_when_call_websocket_api_with_channel(context, api_key, channel):
    """
    Call WebSocket API with specific channel

    Example:
        When I call WebSocket API "subscribe_orderbook" with channel "book.BTCUSD-PERP.10"
    """
    params = {
        'channel': channel
    }

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


@then('should receive WebSocket error message')
def step_then_should_receive_websocket_error_message(context):
    """Validate received WebSocket error message"""
    assert context.message_received, "No WebSocket message received"

    # Check if the latest message contains error information
    latest_message = context.ws_client.get_latest_message()
    if isinstance(latest_message, dict):
        # Check for error indicators
        has_error = (
            latest_message.get('code', 0) != 0 or
            'error' in latest_message or
            'message' in latest_message
        )
        assert has_error, f"Expected error message, but received: {latest_message}"

    print("WebSocket error message received as expected")


@then('WebSocket message should validate successfully')
def step_then_websocket_message_should_validate(context):
    """Validate WebSocket subscription confirmation message"""
    validation_result = context.ws_client.validate_websocket_response(
        context.ws_api_key, "subscription_confirmation"
    )

    print(f"WebSocket subscription confirmation validation result: {validation_result}")

    if not validation_result['is_valid']:
        errors = '\n'.join(validation_result['all_errors'])
        raise AssertionError(f"WebSocket subscription confirmation validation failed:\n{errors}")

    print("WebSocket subscription confirmation validation successful")


@then('I disconnect WebSocket connection')
def step_then_disconnect_websocket(context):
    """Disconnect WebSocket connection"""
    context.ws_client.disconnect()
    print("WebSocket connection disconnected")