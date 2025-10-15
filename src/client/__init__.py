"""
Protocol Client Layer (Layer 2)

This package contains protocol-specific client implementations:
- ApiClient: Test orchestrator (coordinates HTTP and WebSocket)
- HttpClient: HTTP/REST protocol client
- WebSocketClient: WebSocket protocol client

Architecture: Strategy Pattern
Each protocol has its own client implementation, orchestrated by ApiClient.
"""

from src.client.api_client import ApiClient
from src.client.http_client import HttpClient
from src.client.websocket_client import WebSocketClient

__all__ = ['ApiClient', 'HttpClient', 'WebSocketClient']
