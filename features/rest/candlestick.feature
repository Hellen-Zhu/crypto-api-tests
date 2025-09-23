Feature: REST API Candlestick Data Testing
    As a test engineer
    I want to test candlestick data REST API
    So that I can verify API functionality and data accuracy

    Background:
        Given I have a REST API client

    Scenario: Get AAVE USD perpetual M5 timeframe candlestick data
        When I call REST API "get_candlestick"
            | parameter       | value        |
            | instrument_name | AAVEUSD-PERP |
            | timeframe       | M5           |
        Then the response should validate successfully

    Scenario: Get BTC USDT perpetual H1 timeframe candlestick data
        When I call REST API "get_candlestick"
            | parameter       | value         |
            | instrument_name | BTCUSD-PERP   |
            | timeframe       | H1            |
        Then the response should validate successfully

    Scenario: Get ETH USD 1D timeframe candlestick data
        When I call REST API "get_candlestick"
            | parameter       | value         |
            | instrument_name | ETH_USD      |
            | timeframe       | 1D            |
        Then the response should validate successfully

    Scenario: Get candlestick data with invalid instrument
        When I call REST API "get_candlestick"
            | parameter       | value     |
            | instrument_name | XXX_YYY   |
            | timeframe       | M5        |
        Then the response should validate as error

    Scenario: Get candlestick data with invalid timeframe
        When I call REST API "get_candlestick"
            | parameter       | value        |
            | instrument_name | AAVEUSD-PERP |
            | timeframe       | 3m           |
        Then the response should validate as error