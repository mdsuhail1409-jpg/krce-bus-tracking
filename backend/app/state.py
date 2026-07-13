"""
KRCE Bus Tracking System — In-memory live state.
Shared across all route modules.
"""

from typing import Dict
from fastapi import WebSocket

# bus_id → GPS state dict
live_buses: Dict[str, dict] = {}

# user_id → WebSocket connection
ws_pool: Dict[str, WebSocket] = {}

# user_id → unix timestamp of last activity
last_seen: Dict[str, float] = {}

# bus_id → { stop_name → "inside"/"outside" }
geofence_states: Dict[str, Dict[str, str]] = {}
