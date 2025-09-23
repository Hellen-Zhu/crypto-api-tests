Feature: WebSocket Order Book Data Testing
    As a test engineer
    I want to test WebSocket order book data subscription
    So that I can verify real-time data streaming functionality

    Background:
        Given I have a WebSocket client

    Scenario Outline: Subscribe to order book data for valid instruments
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_orderbook" with channel "<channel>"
        Then WebSocket message should send successfully
        When I wait for WebSocket message
        Then should receive WebSocket message
        And WebSocket message should validate successfully
        Then I disconnect WebSocket connection

        Examples:
            | channel              |
            | book.BTCUSD-PERP.10  |
            | book.ETHUSD-PERP.50  |
            | book.AAVEUSD-PERP.10 |

    Scenario Outline: Subscribe to order book data with invalid parameters
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_orderbook" with channel "<channel>"
        Then WebSocket message should send successfully
        When I wait for WebSocket message
        Then should receive WebSocket error message
        Then I disconnect WebSocket connection

        Examples:
            | channel            |
            | book.INVALID.10    |
            | book.BTCUSD-PERP.0 |
            | invalid.format     |