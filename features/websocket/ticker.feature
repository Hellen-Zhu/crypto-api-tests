Feature: WebSocket Ticker Data Testing
    As a test engineer
    I want to test WebSocket ticker data subscription
    So that I can verify real-time ticker data streaming functionality

    Background:
        Given I have a WebSocket client

    Scenario Outline: Subscribe to ticker data for valid instruments
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_ticker" with channel "<channel>"
        Then WebSocket message should send successfully
        When I wait for WebSocket message
        Then should receive WebSocket message
        And WebSocket message should validate successfully
        Then I disconnect WebSocket connection

        Examples:
            | channel           |
            | ticker.BTCUSD-PERP |
            | ticker.ETHUSD-PERP |
            | ticker.AAVEUSD-PERP|

    Scenario Outline: Subscribe to ticker data with invalid parameters
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_ticker" with channel "<channel>"
        Then WebSocket message should send successfully
        When I wait for WebSocket message
        Then should receive WebSocket error message
        Then I disconnect WebSocket connection

        Examples:
            | channel         |
            | ticker.INVALID  |
            | invalid.format  |
            | ticker.BTC-USD  |