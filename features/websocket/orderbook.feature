Feature: WebSocket Order Book Data Testing
    As a test engineer
    I want to test WebSocket order book data subscription
    So that I can verify real-time data streaming functionality

    Background:
        Given I have a WebSocket client

    Scenario: Subscribe to BTC USDT depth 10 order book data
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_orderbook"
            | parameter       | value     |
            | instrument_name | BTC_USDT  |
            | depth           | 10        |
        Then WebSocket message should send successfully
        When I wait for WebSocket message
        Then should receive WebSocket message
        And WebSocket message should validate successfully
        Then I disconnect WebSocket connection

    Scenario: Subscribe to ETH USDT depth 50 order book data
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_orderbook"
            | parameter       | value     |
            | instrument_name | ETH_USDT  |
            | depth           | 50        |
        Then WebSocket message should send successfully
        When I wait for WebSocket message
        Then should receive WebSocket message
        And WebSocket message should validate successfully
        Then I disconnect WebSocket connection

    Scenario: Subscribe to AAVE USDT depth 20 order book data
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_orderbook"
            | parameter       | value     |
            | instrument_name | AAVE_USDT |
            | depth           | 20        |
        Then WebSocket message should send successfully
        When I wait for WebSocket message
        Then should receive WebSocket message
        And WebSocket message should validate successfully
        Then I disconnect WebSocket connection

    Scenario: Subscribe to order book data with invalid instrument
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_orderbook"
            | parameter       | value     |
            | instrument_name | XXX_YYY   |
            | depth           | 10        |
        Then WebSocket message should send successfully
        Then I disconnect WebSocket connection

    Scenario: Subscribe to order book data with invalid depth
        When I connect to WebSocket server
        Then WebSocket should connect successfully
        When I call WebSocket API "subscribe_orderbook"
            | parameter       | value     |
            | instrument_name | BTC_USDT  |
            | depth           | 99        |
        Then WebSocket message should send successfully
        Then I disconnect WebSocket connection