Feature: REST API Candlestick Data Testing
    As a test engineer
    I want to test candlestick data REST API
    So that I can verify API functionality and data accuracy

    Background:
        Given I have a REST API client

    Scenario Outline: Get candlestick data for valid instruments
        When I call REST API "get_candlestick" with instrument "<instrument>" and timeframe "<timeframe>"
        Then the response should validate successfully

        Examples:
            | instrument   | timeframe |
            | AAVEUSD-PERP | M5        |
            | BTCUSD-PERP  | H1        |
            | ETH_USD      | 1D        |

    Scenario Outline: Get candlestick data with invalid parameters
        When I call REST API "get_candlestick" with instrument "<instrument>" and timeframe "<timeframe>"
        Then the response should validate as error

        Examples:
            | instrument   | timeframe |
            | XXX_YYY      | M5        |
            | AAVEUSD-PERP | 3m        |