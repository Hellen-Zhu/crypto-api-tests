# core/assertion_engine.py

import pytest
import json
import allure
from typing import Dict, List, Any
from jsonpath_ng import parse
from sqlalchemy import text
from src.engine.placeholder_resolver import resolve_placeholders
from src.common.logger import logger


class AssertionEngine:
    """
    Unified keyword-driven smart assertion engine.
    It receives raw validation rules and performs "just-in-time parsing" for each keyword internally.
    """
    def __init__(self):
        pass

    def execute_assertions(self, response: Dict[str, Any], validation_rules: Dict[str, Any], context=None, data_set_vars=None):
        """Execute all validation rules with Allure reporting."""
        with allure.step("Validations"):
            if not isinstance(validation_rules, dict):
                pytest.fail(f"Validation rules must be a JSON object, but got {type(validation_rules).__name__}", pytrace=False)

            failures = []

            # --- Dispatch center: pass context required for parsing to each dispatcher ---
            if "expectedStatusCode" in validation_rules:
                self._dispatch_status_code(response, validation_rules, failures, context, data_set_vars)

            if "body" in validation_rules:
                self._dispatch_body_match(response, validation_rules, failures, context, data_set_vars)

            if "containsText" in validation_rules:
                self._dispatch_contains_text(response, validation_rules, failures, context, data_set_vars)

            if "notNull" in validation_rules:
                self._dispatch_not_null(response, validation_rules, failures, context, data_set_vars)

            if "notExist" in validation_rules:
                self._dispatch_not_exist(response, validation_rules, failures, context, data_set_vars)

            # Note: dbValidation is deprecated since app_db_connection_string was removed
            if "dbValidation" in validation_rules:
                with allure.step("⚠️ SKIPPED: DB Validation (deprecated - app database connection no longer supported)"):
                    logger.warning("dbValidation is deprecated and has been skipped. Please remove from test cases.")

            if failures:
                pytest.fail("\n".join(failures), pytrace=False)

    # --- Dispatcher Methods ---

    def _dispatch_status_code(self, response, rules, failures, context, data_set_vars):
        resolved_status_code = resolve_placeholders(rules["expectedStatusCode"], context, data_set_vars)
        with allure.step(f"Assert: Status Code equals [{resolved_status_code}]"):
            try:
                self._assert_status_code(response['status_code'], resolved_status_code)
            except AssertionError as e: failures.append(str(e))

    def _dispatch_body_match(self, response, rules, failures, context, data_set_vars):
        with allure.step("Assert: Body partially matches expected JSON"):
            try:
                resolved_expected_json = resolve_placeholders(rules["body"], context, data_set_vars)
                if resolved_expected_json:
                    allure.attach(json.dumps(resolved_expected_json, indent=2, ensure_ascii=False), name="Expected Partial JSON (Resolved)", attachment_type=allure.attachment_type.JSON)
                    self._assert_partial_json_match(response['body'], resolved_expected_json)
            except AssertionError as e: failures.append(str(e))

    def _dispatch_contains_text(self, response, rules, failures, context, data_set_vars):
        resolved_text = resolve_placeholders(rules["containsText"], context, data_set_vars)
        with allure.step(f"Assert: Body contains text [{resolved_text[:50]}...]"):
            try:
                self._assert_body_contains_text(response['body'], resolved_text)
            except AssertionError as e: failures.append(str(e))

    def _dispatch_not_null(self, response, rules, failures, context, data_set_vars):
        json_paths = rules["notNull"]
        if not isinstance(json_paths, list):
            failures.append("Assertion Failed: 'notNull' value must be an array of JSONPaths.")
            return
        with allure.step(f"Assert: Paths are not null {json_paths}"):
            for path in json_paths:
                try:
                    self._assert_json_path_not_null(response['body'], path)
                except AssertionError as e: failures.append(str(e))

    def _dispatch_not_exist(self, response, rules, failures, context, data_set_vars):
        json_paths = rules["notExist"]
        if not isinstance(json_paths, list):
            failures.append("Assertion Failed: 'notExist' value must be an array of JSONPaths.")
            return
        with allure.step(f"Assert: Paths do not exist {json_paths}"):
            for path in json_paths:
                try:
                    self._assert_json_path_not_exist(response['body'], path)
                except AssertionError as e: failures.append(str(e))

    def _dispatch_db_validation(self, response, rules, db_conn, failures, context, data_set_vars):
        if not db_conn:
            allure.step("⚠️ SKIPPED: DB Validation (no application DB connection available)")
            return

        db_validation_rule = rules["dbValidation"]
        query = db_validation_rule.get("query")
        if not query:
            failures.append("Assertion Failed: 'dbValidation' is missing the 'query' key.")
            return

        resolved_query = resolve_placeholders(query, context, data_set_vars)
        with allure.step(f"Assert: Database validation with query [{resolved_query[:100]}...]"):
            try:
                self._assert_db_query(db_conn, resolved_query, db_validation_rule, response, context, data_set_vars)
            except Exception as e:
                failures.append(f"DB query or validation failed: {e}")

    # --- Helper Assertion Methods ---

    def _assert_db_query(self, db_conn, query, rule, response, context, data_set_vars):
        result = db_conn.execute(text(query))
        actual_rows = [dict(row._mapping) for row in result]
        allure.attach(json.dumps(actual_rows, indent=2, default=str), name="Actual DB Query Result", attachment_type=allure.attachment_type.JSON)

        if "expected" in rule:
            resolved_expected_rows = resolve_placeholders(rule["expected"], context, data_set_vars)
            allure.attach(json.dumps(resolved_expected_rows, indent=2), name="Expected DB Rows (Resolved)", attachment_type=allure.attachment_type.JSON)
            assert actual_rows == resolved_expected_rows, f"DB query result mismatch. Expected: {resolved_expected_rows}, Actual: {actual_rows}"
            logger.debug("DB query result matches expected static values.")

        elif "expectedFromResponse" in rule:
            expected_mappings = rule["expectedFromResponse"]
            assert len(actual_rows) > 0, "DB query returned no rows to validate against response."
            db_row = actual_rows[0]

            expected_from_response = {}
            for db_column, response_json_path in expected_mappings.items():
                matches = parse(response_json_path).find(response['body'])
                if matches:
                    expected_from_response[db_column] = matches[0].value
                else:
                    expected_from_response[db_column] = f"ERROR: JSONPath '{response_json_path}' not found!"
            allure.attach(json.dumps([expected_from_response], indent=2, default=str), name="Expected DB Rows (from API Response)", attachment_type=allure.attachment_type.JSON)

            for db_column, response_json_path in expected_mappings.items():
                assert db_column in db_row, f"Column '{db_column}' not found in DB query result."
                matches = parse(response_json_path).find(response['body'])
                assert len(matches) > 0, f"JSONPath '{response_json_path}' not found in API response."
                api_value = matches[0].value
                db_value = db_row[db_column]
                assert str(api_value) == str(db_value), f"Mismatch for DB column '{db_column}'. DB Value: '{db_value}', API Value (from {response_json_path}): '{api_value}'"
                logger.debug(f"DB column '{db_column}' value '{db_value}' matches API response.")

    def _assert_status_code(self, actual, expected):
        assert str(actual) == str(expected), f"Expected status code '{expected}', but got '{actual}'."
        logger.debug(f"Status code is '{actual}' as expected.")

    def _assert_partial_json_match(self, actual, expected, path="body"):
        if isinstance(expected, dict):
            assert isinstance(actual, dict), f"Type mismatch at path '{path}': expected dict, got {type(actual).__name__}"
            for key, expected_value in expected.items():
                current_path = f"{path}.{key}"
                assert key in actual, f"Missing key at path '{current_path}'"
                self._assert_partial_json_match(actual[key], expected_value, path=current_path)
        elif isinstance(expected, list):
            assert isinstance(actual, list), f"Type mismatch at path '{path}': expected list, got {type(actual).__name__}"
            assert len(actual) >= len(expected), f"Length mismatch at path '{path}': expected at least {len(expected)}, got {len(actual)}"
            for i, expected_item in enumerate(expected):
                current_path = f"{path}[{i}]"
                self._assert_partial_json_match(actual[i], expected_item, path=current_path)
        else:
            assert actual == expected, f"Value mismatch at path '{path}': expected '{expected}', got '{actual}'"

        if path == "body":
            logger.debug("Body partially matches the expectation.")

    def _assert_body_contains_text(self, body, text):
        assert text in str(body), f"Expected text '{text}' not found in response body."
        logger.debug(f"Response body contains the text '{text}'.")

    def _assert_json_path_not_null(self, body, json_path):
        matches = parse(json_path).find(body)
        assert len(matches) > 0, f"Path '{json_path}' not found (expected not null)."
        actual_value = matches[0].value
        assert actual_value is not None, f"Path '{json_path}' exists but its value is null."
        logger.debug(f"Path '{json_path}' exists and is not null.")

    def _assert_json_path_not_exist(self, body, json_path):
        matches = parse(json_path).find(body)
        assert len(matches) == 0, f"Path '{json_path}' was found, but was expected not to exist."
        logger.debug(f"Path '{json_path}' does not exist as expected.")

    # ============================================================
    # Candlestick-specific validation methods
    # ============================================================

    def validate_candlestick_data(self, response: Dict[str, Any], validation_rules: Dict[str, Any], context=None, data_set_vars=None):
        """
        Specialized validation for candlestick (K-line) data.
        Validates OHLC logic, timestamp sequences, and data count.
        """
        if "customValidations" not in validation_rules:
            return

        custom_validations = validation_rules.get("customValidations", [])
        failures = []

        for validation in custom_validations:
            validation_type = validation.get("type")

            if validation_type == "ohlc_logic":
                with allure.step("Assert: OHLC price relationships are valid"):
                    try:
                        self._validate_ohlc_logic(response['body'])
                    except AssertionError as e:
                        failures.append(str(e))

            elif validation_type == "timestamp_sequence":
                with allure.step("Assert: Timestamp intervals are correct"):
                    try:
                        timeframe = resolve_placeholders("{{@timeframe}}", context, data_set_vars)
                        self._validate_timestamp_sequence(response['body'], timeframe)
                    except AssertionError as e:
                        failures.append(str(e))

            elif validation_type == "data_count":
                with allure.step("Assert: Data count matches expected"):
                    try:
                        expected_count = resolve_placeholders("{{@count}}", context, data_set_vars)
                        self._validate_data_count(response['body'], expected_count)
                    except AssertionError as e:
                        failures.append(str(e))

        if failures:
            pytest.fail("\n".join(failures), pytrace=False)

    def _validate_ohlc_logic(self, body: Dict[str, Any]):
        """
        Validate OHLC (Open, High, Low, Close) price relationships.
        Rules:
        1. High >= Open, Close, Low
        2. Low <= Open, Close, High
        3. All prices should be positive numbers
        """
        data = body.get('result', {}).get('data', [])

        if not data:
            logger.warning("No candlestick data to validate OHLC logic")
            return

        for i, candle in enumerate(data):
            # Extract OHLC values
            open_price = float(candle.get('o', 0))
            high_price = float(candle.get('h', 0))
            low_price = float(candle.get('l', 0))
            close_price = float(candle.get('c', 0))
            volume = float(candle.get('v', 0))

            # Validate positive values
            assert open_price > 0, f"Candle {i}: Open price must be positive, got {open_price}"
            assert high_price > 0, f"Candle {i}: High price must be positive, got {high_price}"
            assert low_price > 0, f"Candle {i}: Low price must be positive, got {low_price}"
            assert close_price > 0, f"Candle {i}: Close price must be positive, got {close_price}"
            assert volume >= 0, f"Candle {i}: Volume must be non-negative, got {volume}"

            # Validate OHLC relationships
            assert high_price >= open_price, f"Candle {i}: High ({high_price}) must be >= Open ({open_price})"
            assert high_price >= close_price, f"Candle {i}: High ({high_price}) must be >= Close ({close_price})"
            assert high_price >= low_price, f"Candle {i}: High ({high_price}) must be >= Low ({low_price})"

            assert low_price <= open_price, f"Candle {i}: Low ({low_price}) must be <= Open ({open_price})"
            assert low_price <= close_price, f"Candle {i}: Low ({low_price}) must be <= Close ({close_price})"
            assert low_price <= high_price, f"Candle {i}: Low ({low_price}) must be <= High ({high_price})"

        logger.debug(f"OHLC logic validation passed for {len(data)} candles")

    def _validate_timestamp_sequence(self, body: Dict[str, Any], timeframe: str):
        """
        Validate that timestamps follow the correct interval based on timeframe.
        """
        data = body.get('result', {}).get('data', [])

        if not data or len(data) < 2:
            logger.warning("Insufficient data to validate timestamp sequence")
            return

        # Map timeframe to milliseconds
        timeframe_ms_map = {
            '1m': 60000,           # 1 minute
            '5m': 300000,          # 5 minutes
            '15m': 900000,         # 15 minutes
            '30m': 1800000,        # 30 minutes
            '1h': 3600000,         # 1 hour
            '2h': 7200000,         # 2 hours
            '4h': 14400000,        # 4 hours
            '12h': 43200000,       # 12 hours
            '1D': 86400000,        # 1 day
            '7D': 604800000,       # 7 days
            '14D': 1209600000,     # 14 days
            '1M': 2592000000,      # 30 days (approximate)
        }

        expected_interval = timeframe_ms_map.get(timeframe)

        if not expected_interval:
            logger.warning(f"Unknown timeframe '{timeframe}', skipping timestamp validation")
            return

        # Check timestamp sequence (should be in ascending order with correct intervals)
        prev_timestamp = None
        for i, candle in enumerate(data):
            timestamp = candle.get('t')

            assert timestamp is not None, f"Candle {i}: Missing timestamp"
            assert isinstance(timestamp, (int, float)), f"Candle {i}: Timestamp must be numeric, got {type(timestamp)}"

            if prev_timestamp is not None:
                # Timestamps should be in ascending order
                assert timestamp > prev_timestamp, f"Candle {i}: Timestamps not in ascending order ({prev_timestamp} -> {timestamp})"

                # For regular intervals (not 1M which can vary), check interval
                if timeframe != '1M':
                    interval = timestamp - prev_timestamp
                    # Allow small tolerance (5%) for potential gaps
                    tolerance = expected_interval * 0.05
                    assert abs(interval - expected_interval) <= tolerance or interval % expected_interval == 0, \
                        f"Candle {i}: Incorrect interval {interval}ms, expected {expected_interval}ms (±{tolerance}ms) for timeframe {timeframe}"

            prev_timestamp = timestamp

        logger.debug(f"Timestamp sequence validation passed for {len(data)} candles with timeframe {timeframe}")

    def _validate_data_count(self, body: Dict[str, Any], expected_count):
        """
        Validate that the returned data count matches expectations.
        """
        data = body.get('result', {}).get('data', [])
        actual_count = len(data)

        # Convert expected_count to int if it's a string
        if isinstance(expected_count, str):
            expected_count = int(expected_count)

        # For large requests, API might return less than requested (which is acceptable)
        if expected_count > 100:
            assert actual_count > 0 and actual_count <= expected_count, \
                f"Expected up to {expected_count} candles, got {actual_count}"
        else:
            # For small requests, we expect exact count (unless there's insufficient historical data)
            assert actual_count > 0, f"Expected at least 1 candle, got {actual_count}"
            # Note: We can't assert exact count as it depends on available historical data

        logger.debug(f"Data count validation passed: {actual_count} candles returned (requested: {expected_count})")

    # ============================================================
    # WebSocket-specific assertion methods (MVP)
    # ============================================================

    def execute_websocket_assertions(self, message: Dict[str, Any], validation_rules: Dict[str, Any], context=None, data_set_vars=None):
        """
        Execute assertions on WebSocket message (MVP version).

        Reuses existing HTTP validation methods (notNull, body, containsText) for consistency.
        WebSocket message is treated as a response body.

        :param message: WebSocket message (dict)
        :param validation_rules: Validation rules
        :param context: Test context for placeholder resolution
        :param data_set_vars: Data set variables for placeholder resolution
        """
        with allure.step("WebSocket Validations"):
            if not isinstance(validation_rules, dict):
                pytest.fail(f"Validation rules must be a JSON object, but got {type(validation_rules).__name__}", pytrace=False)

            if not message:
                pytest.fail("WebSocket message is empty, cannot validate", pytrace=False)

            failures = []

            # Wrap message in response structure for compatibility with existing validators
            websocket_response = {'body': message}

            # --- Dispatch to existing validators (reuse HTTP validation logic) ---

            if "notNull" in validation_rules:
                self._dispatch_not_null(websocket_response, validation_rules, failures, context, data_set_vars)

            if "body" in validation_rules:
                self._dispatch_body_match(websocket_response, validation_rules, failures, context, data_set_vars)

            if "containsText" in validation_rules:
                self._dispatch_contains_text(websocket_response, validation_rules, failures, context, data_set_vars)

            if "notExist" in validation_rules:
                self._dispatch_not_exist(websocket_response, validation_rules, failures, context, data_set_vars)

            # Note: expectedStatusCode and dbValidation are not applicable to WebSocket messages

            if failures:
                pytest.fail("\n".join(failures), pytrace=False)

            logger.debug("WebSocket message validation passed")
