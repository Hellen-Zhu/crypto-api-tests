# src/client/http_client.py

"""
HTTP Client - Protocol-Specific Implementation

Responsibilities:
- HTTP request execution using requests library
- Session lifecycle management (connection pooling, keep-alive)
- Response standardization (JSON/text handling)
- HTTP-specific features (future: retries, auth, rate limiting)

This class is part of the Protocol Client Layer (Layer 2) following the Strategy Pattern.
It handles HTTP protocol details while ApiClient handles orchestration.
"""

import requests
import json
from typing import Dict, Any, Optional
from src.common.logger import logger


class HttpClient:
    """
    HTTP protocol client for REST API testing.

    Features:
    - Session management with connection pooling
    - Standardized request/response handling
    - JSON and text response support
    - Thread-safe for pytest-xdist parallel execution

    Design Pattern: Strategy Pattern (HTTP protocol strategy)
    """

    def __init__(self):
        """
        Initialize HTTP client with persistent session.

        Session benefits:
        - Connection pooling (reuses TCP connections)
        - Keep-alive support (reduces latency)
        - Cookie persistence across requests
        """
        self.session = requests.Session()

        # Disable environment variable proxy to avoid localhost issues
        # This is critical for testing local/internal APIs
        self.session.trust_env = False

        logger.debug("HttpClient initialized with persistent session")

    def send(
        self,
        method: str,
        url: str,
        headers: Optional[Dict[str, Any]] = None,
        params: Optional[Dict[str, Any]] = None,
        body: Optional[Dict[str, Any]] = None,
        timeout: int = 30
    ) -> Dict[str, Any]:
        """
        Send HTTP request and return standardized response.

        Args:
            method: HTTP method (GET, POST, PUT, DELETE, etc.)
            url: Complete URL including base_url and path
            headers: Request headers dictionary
            params: Query parameters dictionary
            body: Request body (will be JSON-encoded)
            timeout: Request timeout in seconds (default: 30)

        Returns:
            Standardized response dictionary:
            {
                'status_code': int,
                'headers': dict,
                'body': dict | str  (JSON object or text)
            }

        Raises:
            requests.RequestException: For network/HTTP errors
            requests.Timeout: If request exceeds timeout
        """
        logger.info(f"Sending {method} request to {url}")
        logger.debug(f"Request params: {params}, body: {body}")

        try:
            # Send HTTP request using session
            response = self.session.request(
                method=method,
                url=url,
                headers=headers,
                params=params,
                json=body,  # Automatically serializes to JSON
                timeout=timeout
            )

            logger.info(f"Received response with status code: {response.status_code}")

            # Standardize response format
            response_body = None
            try:
                # Try to parse as JSON first (most common for REST APIs)
                response_body = response.json()
            except json.JSONDecodeError:
                # Fallback to plain text if not valid JSON
                response_body = response.text
                logger.debug("Response is not JSON, storing as text")

            standardized_response = {
                'status_code': response.status_code,
                'headers': dict(response.headers),
                'body': response_body
            }

            logger.debug(f"Standardized response: {standardized_response}")
            return standardized_response

        except requests.Timeout as e:
            logger.error(f"Request timeout after {timeout}s: {url}")
            raise

        except requests.RequestException as e:
            logger.error(f"HTTP request failed: {type(e).__name__}: {e}")
            raise

