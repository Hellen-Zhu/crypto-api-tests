# core/websocket_client.py

import json
import time
import threading
import ssl
from typing import List, Dict, Any, Optional
import websocket
from src.common.logger import logger


class WebSocketClient:
    """
    Lightweight WebSocket client for API testing (MVP version).

    Supports:
    - Connect to WebSocket server
    - Send subscription messages
    - Receive and buffer messages asynchronously
    - Thread-safe message queue
    - Timeout control

    MVP Limitations:
    - Single connection only (no connection pool)
    - No automatic reconnection
    - No heartbeat/ping-pong support
    """

    def __init__(self):
        """Initialize WebSocket client."""
        self.ws = None
        self.is_connected = False
        self.messages = []  # Thread-safe message buffer
        self.lock = threading.Lock()  # Protect message queue
        self.connection_thread = None
        self.url = None

    def connect(self, url: str, timeout: int = 10) -> bool:
        """
        Connect to WebSocket server.

        Args:
            url: WebSocket URL (e.g., wss://example.com/ws)
            timeout: Connection timeout in seconds

        Returns:
            bool: True if connection successful, False otherwise

        Raises:
            Exception: If connection fails
        """
        try:
            self.url = url
            logger.info(f"🔌 Connecting to WebSocket: {url}")

            # Create WebSocketApp instance
            self.ws = websocket.WebSocketApp(
                url,
                on_open=self._on_open,
                on_message=self._on_message,
                on_error=self._on_error,
                on_close=self._on_close
            )

            # Configure SSL to skip certificate verification for testing
            ssl_context = ssl.create_default_context()
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE

            # Start WebSocket in separate thread
            self.connection_thread = threading.Thread(
                target=self.ws.run_forever,
                kwargs={'sslopt': {"cert_reqs": ssl.CERT_NONE}}
            )
            self.connection_thread.daemon = True
            self.connection_thread.start()

            # Wait for connection to establish
            start_time = time.time()
            while not self.is_connected and (time.time() - start_time) < timeout:
                time.sleep(0.1)

            if self.is_connected:
                logger.success(f"✅ WebSocket connected successfully: {url}")
                return True
            else:
                logger.error(f"❌ WebSocket connection timeout after {timeout}s")
                return False

        except Exception as e:
            logger.error(f"❌ WebSocket connection failed: {e}")
            raise

    def send_message(self, message: Dict[str, Any]) -> bool:
        """
        Send a message to WebSocket server.

        Args:
            message: Message dictionary to send (will be JSON-encoded)

        Returns:
            bool: True if sent successfully, False otherwise

        Raises:
            Exception: If not connected or send fails
        """
        if not self.is_connected:
            raise ConnectionError("WebSocket is not connected")

        try:
            message_str = json.dumps(message)
            logger.info(f"📤 Sending WebSocket message: {message_str}")
            self.ws.send(message_str)
            logger.success("✅ Message sent successfully")
            return True

        except Exception as e:
            logger.error(f"❌ Failed to send WebSocket message: {e}")
            raise

    def wait_for_messages(self, count: int = 1, timeout: int = 30) -> List[Dict[str, Any]]:
        """
        Wait for a specific number of messages to be received.

        Args:
            count: Number of messages to wait for
            timeout: Maximum wait time in seconds

        Returns:
            List of received messages

        Raises:
            TimeoutError: If messages not received within timeout
        """
        logger.info(f"⏳ Waiting for {count} WebSocket message(s), timeout: {timeout}s")

        start_time = time.time()
        initial_count = len(self.messages)
        target_count = initial_count + count

        while (time.time() - start_time) < timeout:
            with self.lock:
                current_count = len(self.messages)
                if current_count >= target_count:
                    logger.success(f"✅ Received {count} message(s), total: {current_count}")
                    return self.messages.copy()
            time.sleep(0.1)

        # Timeout reached
        with self.lock:
            received_count = len(self.messages) - initial_count

        error_msg = f"⏱️ Timeout waiting for WebSocket messages. Expected: {count}, Received: {received_count}"
        logger.error(error_msg)
        raise TimeoutError(error_msg)

    def get_all_messages(self) -> List[Dict[str, Any]]:
        """
        Get all received messages.

        Returns:
            List of all messages received so far
        """
        with self.lock:
            return self.messages.copy()

    def get_latest_message(self) -> Optional[Dict[str, Any]]:
        """
        Get the most recent message.

        Returns:
            Latest message or None if no messages
        """
        with self.lock:
            return self.messages[-1] if self.messages else None

    def clear_messages(self):
        """Clear all buffered messages."""
        with self.lock:
            message_count = len(self.messages)
            self.messages.clear()
            logger.info(f"🗑️ Cleared {message_count} buffered messages")

    def disconnect(self):
        """Close WebSocket connection and cleanup resources."""
        if self.ws:
            try:
                logger.info("🔌 Disconnecting WebSocket...")
                self.ws.close()

                # Wait for thread to finish (with timeout)
                if self.connection_thread and self.connection_thread.is_alive():
                    self.connection_thread.join(timeout=2)

                self.is_connected = False
                logger.success("✅ WebSocket disconnected successfully")

            except Exception as e:
                logger.warning(f"⚠️ Error during WebSocket disconnect: {e}")

    # ============================================================
    # Internal callback methods (called by websocket library)
    # ============================================================

    def _on_open(self, ws):
        """Callback when WebSocket connection is opened."""
        self.is_connected = True
        logger.info(f"🔓 WebSocket connection opened: {self.url}")

    def _on_message(self, ws, message):
        """Callback when a message is received from server."""
        try:
            # Parse JSON message
            data = json.loads(message)
            logger.info(f"📥 Received WebSocket message: {json.dumps(data, ensure_ascii=False)[:200]}...")

            # Add to buffer (thread-safe)
            with self.lock:
                self.messages.append(data)

        except json.JSONDecodeError as e:
            logger.error(f"❌ Failed to parse WebSocket message as JSON: {e}")
            logger.debug(f"Raw message: {message}")

            # Store raw message with error marker
            with self.lock:
                self.messages.append({
                    "_parse_error": True,
                    "_raw_message": message,
                    "_error": str(e)
                })

    def _on_error(self, ws, error):
        """Callback when WebSocket error occurs."""
        logger.error(f"❌ WebSocket error: {error}")

    def _on_close(self, ws, close_status_code, close_msg):
        """Callback when WebSocket connection is closed."""
        self.is_connected = False
        logger.info(f"🔒 WebSocket connection closed: code={close_status_code}, msg={close_msg}")
