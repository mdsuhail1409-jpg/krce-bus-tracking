"""
KRCE Bus Tracking System — Utility functions.
Haversine distance, OSRM routing, timestamp helpers.
"""

import asyncio
import json
import urllib.request
from datetime import datetime, date
from math import atan2, cos, radians, sin, sqrt
from typing import Optional

from app.config import logger


def haversine(lat1, lon1, lat2, lon2) -> float:
    """Calculate distance in meters between two lat/lon points."""
    R = 6_371_000
    φ1, φ2 = radians(lat1), radians(lat2)
    dφ, dλ = radians(lat2 - lat1), radians(lon2 - lon1)
    a = sin(dφ / 2) ** 2 + cos(φ1) * cos(φ2) * sin(dλ / 2) ** 2
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))


def today() -> str:
    """Return today's date as ISO string."""
    return date.today().isoformat()


def now_str() -> str:
    """Return current UTC datetime as ISO string."""
    return datetime.utcnow().isoformat()


def _fetch_osrm_sync(url: str) -> dict:
    """Synchronous OSRM HTTP fetch (runs in executor)."""
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "KRCE-BusTrack/4.0"}
    )
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.loads(response.read().decode('utf-8'))


async def fetch_osrm_route(lat1, lon1, lat2, lon2) -> Optional[dict]:
    """Async wrapper for OSRM route fetching."""
    url = f"http://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson"
    try:
        loop = asyncio.get_event_loop()
        res = await loop.run_in_executor(None, _fetch_osrm_sync, url)
        return res
    except Exception as e:
        logger.error(f"OSRM error: {e}")
        return None
