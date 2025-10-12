# core/assertion_engine.py

import pytest
import json
import allure
from typing import Dict, List, Any
from jsonpath_ng import parse
from sqlalchemy import text
from utils.placeholder_parser import resolve_placeholders
from core.logger_config import logger


class AssertionEngine:
    """
    Unified keyword-driven smart assertion engine.
    It receives raw validation rules and performs "just-in-time parsing" for each keyword internally.
    """
    def __init__(self):
        pass

    def execute_assertions(self, response: Dict[str, Any], validation_rules: Dict[str, Any], app_db_conn=None, context=None, data_set_vars=None):
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

        if "dbValidation" in validation_rules:
            self._dispatch_db_validation(response, validation_rules, app_db_conn, failures, context, data_set_vars)

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
