"""
KRCE Bus Tracking System — AI/ML prediction utilities.
ETA, demand, and occupancy prediction.
"""

from datetime import datetime
from app.state import live_buses
from app.utils import haversine


def predict_eta_delay(bus_id: str, stop_lat: float, stop_lon: float, speed: float) -> dict:
    """Predict ETA and delay for a bus reaching a stop."""
    live = live_buses.get(bus_id)
    if not live:
        return {"eta": "—", "delay": "—", "duration": 0}

    d = haversine(live["lat"], live["lon"], stop_lat, stop_lon)

    # Speed baseline heuristics (approx 30km/h average in case of stationary state)
    est_speed = max(speed, 8.3)
    if est_speed < 5:
        est_speed = 8.3

    duration_secs = d / est_speed

    # Rush Hour Multipliers
    hour = datetime.now().hour
    multiplier = 1.0
    if 8 <= hour <= 9 or 16 <= hour <= 18:
        multiplier = 1.4

    predicted_duration = duration_secs * multiplier
    baseline_duration = d / 11.1  # 40 km/h baseline

    delay_secs = max(0.0, predicted_duration - baseline_duration)
    delay_mins = int(delay_secs / 60)
    delay_text = f"{delay_mins} mins" if delay_mins > 2 else "No Delay"

    eta_mins = max(1, int(predicted_duration / 60))
    return {
        "eta": f"{eta_mins} mins",
        "delay": delay_text,
        "duration": eta_mins,
        "distance": f"{(d / 1000.0):.1f} km"
    }


def predict_student_demand(bus_id: str, stop_name: str) -> int:
    """Predict student demand at a stop (heuristic-based)."""
    import random
    random.seed(len(stop_name))
    base_demand = random.randint(3, 12)
    day_of_week = datetime.now().weekday()
    if day_of_week in (0, 4):  # Mon/Fri peak
        return int(base_demand * 1.3)
    return base_demand


def predict_occupancy(bus_id: str, capacity: int, current_pax: int) -> str:
    """Predict occupancy status string."""
    fill_ratio = current_pax / max(capacity, 1)
    if fill_ratio > 0.9:
        return "Critical (Near Capacity)"
    elif fill_ratio > 0.7:
        return "High (Few Seats Available)"
    elif fill_ratio > 0.3:
        return "Moderate"
    else:
        return "Low (Many Seats Available)"
