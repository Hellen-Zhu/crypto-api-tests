Feature: REST API Ticker Data Testing
    As a test engineer
    I want to test ticker data REST API
    So that I can verify API functionality and data accuracy

    Background:
        Given I have a REST API client

    Scenario Outline: Get ticker data for valid instruments
        When I call REST API "get_tickers" with instrument "<instrument>"
        Then the response should validate successfully

        Examples:
            | instrument    |
            | BTCUSD-PERP   |
            | ETHUSD-PERP   |
            | AAVEUSD-PERP  |

    Scenario Outline: Get ticker data with invalid parameters
        When I call REST API "get_tickers" with instrument "<instrument>"
        Then the response should validate as error

        Examples:
            | instrument |
            | INVALID    |
            | BTC-USD    |
            | ETH        |