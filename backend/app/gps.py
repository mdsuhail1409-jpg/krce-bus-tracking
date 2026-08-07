"""
KRCE Bus Tracking System — GPS processing, geofencing, safety checks.
"""

import asyncio
import json
import time
import uuid

from app.config import COLLEGE_LAT, COLLEGE_LON, STOP_COORDS, VEHICLE_TTL, VEHICLE_WARN_TTL, logger
from app.state import live_buses, ws_pool, last_seen, geofence_states
from app.utils import haversine, fetch_osrm_route, today, now_str
from app import database as db_module


async def trigger_system_alert(title: str, message: str, alert_type: str = "info", target_bus: str = None):
    """Create a system alert and broadcast to all WebSocket clients."""
    db = db_module.db
    aid = str(uuid.uuid4())[:8]
    alert_doc = {
        "id": aid,
        "title": title,
        "message": message,
        "alert_type": alert_type,
        "target_role": "all",
        "target_bus": target_bus,
        "sent_by": "system",
        "sent_at": now_str(),
        "is_resolved": 0
    }
    await db.alerts.insert_one(alert_doc)

    payload = json.dumps({
        "type": "alert",
        "id": aid,
        "title": title,
        "message": message,
        "alert_type": alert_type,
        "target_bus": target_bus
    })
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(payload)
        except Exception:
            pass


async def initialize_route_geometry(bus_id: str, start_lat: float, start_lon: float):
    """Fetch OSRM route from start position to college campus."""
    route_data = await fetch_osrm_route(start_lat, start_lon, COLLEGE_LAT, COLLEGE_LON)
    if route_data and "routes" in route_data:
        routes = route_data["routes"]
        if routes:
            geometry = routes[0].get("geometry", {})
            coordinates = geometry.get("coordinates", [])  # list of [lon, lat]
            geom_points = [(c[1], c[0]) for c in coordinates]
            if bus_id in live_buses:
                live_buses[bus_id]["route_geometry"] = geom_points


async def run_geofencing_check(bus_id: str, lat: float, lon: float):
    """Check if bus has entered/exited any stop geofences."""
    db = db_module.db
    bus = await db.buses.find_one({"id": bus_id})
    if not bus:
        return
    stops = bus.get("stops", [])

    if bus_id not in geofence_states:
        geofence_states[bus_id] = {}

    bus_state = geofence_states[bus_id]
    bus_number = bus.get("number", bus_id)

    for stop_name in stops:
        coords = STOP_COORDS.get(stop_name)
        if not coords:
            continue
        stop_lat, stop_lon = coords
        d = haversine(lat, lon, stop_lat, stop_lon)

        prev_status = bus_state.get(stop_name, "outside")

        # Enters geofence (within 150m)
        if d <= 150 and prev_status == "outside":
            bus_state[stop_name] = "inside"
            title = f"Bus Reached {stop_name}" if stop_name != "KRCE Campus" else "Bus Reached College"
            msg = f"Bus {bus_number} has arrived at {stop_name}."
            await trigger_system_alert(title, msg, alert_type="info", target_bus=bus_id)

        # Leaves geofence (exceeds 250m)
        elif d > 250 and prev_status == "inside":
            bus_state[stop_name] = "outside"
            title = f"Bus Departed {stop_name}" if stop_name != "KRCE Campus" else "Bus Left College"
            msg = f"Bus {bus_number} has departed from {stop_name}."
            await trigger_system_alert(title, msg, alert_type="info", target_bus=bus_id)


async def run_safety_checks(bus_id: str, lat: float, lon: float, speed: float, now_ts: float):
    """Run overspeed, idle, and route deviation checks."""
    db = db_module.db
    bus = await db.buses.find_one({"id": bus_id})
    if not bus:
        return
    bus_number = bus.get("number", bus_id)

    # 1. Overspeed Alert (> 60 km/h)
    if speed > 60:
        last_overspeed = live_buses[bus_id].get("last_overspeed_alert", 0)
        if now_ts - last_overspeed > 180:
            live_buses[bus_id]["last_overspeed_alert"] = now_ts
            await trigger_system_alert(
                "Overspeed Alert",
                f"Bus {bus_number} is traveling at an unsafe speed of {speed:.1f} km/h!",
                alert_type="warning",
                target_bus=bus_id
            )

    # 2. Idle Detection (> 5 mins)
    if speed <= 1:
        idle_start = live_buses[bus_id].get("idle_start_time")
        if not idle_start:
            live_buses[bus_id]["idle_start_time"] = now_ts
        else:
            if now_ts - idle_start > 300:
                last_idle_alert = live_buses[bus_id].get("last_idle_alert", 0)
                if now_ts - last_idle_alert > 300:
                    live_buses[bus_id]["last_idle_alert"] = now_ts
                    await trigger_system_alert(
                        "Idle Alert",
                        f"Bus {bus_number} has been stationary for more than 5 minutes.",
                        alert_type="warning",
                        target_bus=bus_id
                    )
    else:
        live_buses[bus_id]["idle_start_time"] = None

    # 3. Route Deviation Alert (> 500m away from route coordinates)
    geom_points = live_buses[bus_id].get("route_geometry", [])
    if geom_points:
        min_dist = min(haversine(lat, lon, gp[0], gp[1]) for gp in geom_points)
        if min_dist > 500:
            last_deviation = live_buses[bus_id].get("last_deviation_alert", 0)
            if now_ts - last_deviation > 300:
                live_buses[bus_id]["last_deviation_alert"] = now_ts
                await trigger_system_alert(
                    "Route Deviation Alert",
                    f"Bus {bus_number} has deviated from its scheduled route path!",
                    alert_type="danger",
                    target_bus=bus_id
                )


async def process_gps_update(bus_id: str, driver_id: str, driver_name: str, lat: float, lon: float, speed: float, heading: float, passengers: int):
    """Consolidated GPS processing — update state, persist, geofence, safety."""
    db = db_module.db
    now_ts = time.time()
    is_first_ping = bus_id not in live_buses
    
    current_pax = live_buses[bus_id].get("passengers", 0) if not is_first_ping else passengers

    # 1. Fetch Bus Route to determine progression
    bus = await db.buses.find_one({"id": bus_id})
    stops = bus.get("stops", []) if bus else []
    
    from app.config import STOP_COORDS
    # Dynamic route branching for Bus 6 (B06): Choose TVS Tollgate route vs SIT route based on proximity
    if bus_id == "B06":
        tvs_coord = STOP_COORDS.get("TVS Tollgate")
        sit_coord = STOP_COORDS.get("SIT")
        if tvs_coord and sit_coord:
            d_tvs = haversine(lat, lon, tvs_coord[0], tvs_coord[1])
            d_sit = haversine(lat, lon, sit_coord[0], sit_coord[1])
            if d_tvs <= d_sit:
                stops = ["KRCE Campus", "TVS Tollgate", "Ambigapuram", "Manjathidal", "Armory Gate", "Panjayat Office", "Kalkandar Kottai"]
                if is_first_ping or bus_id not in live_buses:
                    live_buses[bus_id]["active_variant"] = "TVS Tollgate Branch"
            else:
                stops = ["KRCE Campus", "SIT", "Ambigapuram", "Manjathidal", "Armory Gate", "Panjayat Office", "Kalkandar Kottai"]
                if is_first_ping or bus_id not in live_buses:
                    live_buses[bus_id]["active_variant"] = "SIT Branch"

    # 2. Find nearest stop index
    nearest_stop_idx = 0
    min_dist = float('inf')
    for idx, stop_name in enumerate(stops):
        coords = STOP_COORDS.get(stop_name)
        if coords:
            d = haversine(lat, lon, coords[0], coords[1])
            if d < min_dist:
                min_dist = d
                nearest_stop_idx = idx

    if is_first_ping:
        live_buses[bus_id] = {
            "bus_id": bus_id, "driver_id": driver_id, "driver_name": driver_name,
            "lat": lat, "lon": lon, "speed": speed, "heading": heading,
            "passengers": current_pax, "updated_at": now_ts,
            "status": "moving" if speed > 2 else "idle",
            "route_geometry": [],
            "last_active": now_ts,
            "recent_stop_indices": [nearest_stop_idx],
            "confirmed_stop_idx": nearest_stop_idx,
            "direction": "forward"
        }
        asyncio.create_task(initialize_route_geometry(bus_id, lat, lon))
    else:
        live_buses[bus_id].update({
            "lat": lat, "lon": lon, "speed": round(speed, 1),
            "heading": round(heading, 1),
            "updated_at": now_ts,
            "status": "moving" if speed > 2 else "idle",
            "last_active": now_ts
        })

    # 3. Debounce nearest stop index to avoid GPS noise
    recent = live_buses[bus_id].setdefault("recent_stop_indices", [])
    recent.append(nearest_stop_idx)
    if len(recent) > 3:
        recent.pop(0)
    
    if len(set(recent)) == 1:
        confirmed_idx = recent[0]
        prev_confirmed = live_buses[bus_id].get("confirmed_stop_idx")
        if prev_confirmed is not None and prev_confirmed != confirmed_idx:
            if confirmed_idx > prev_confirmed:
                live_buses[bus_id]["direction"] = "forward"
            elif confirmed_idx < prev_confirmed:
                live_buses[bus_id]["direction"] = "reverse"
        live_buses[bus_id]["confirmed_stop_idx"] = confirmed_idx

    # 4. Calculate dynamic destination and remaining stops
    direction = live_buses[bus_id].get("direction", "forward")
    confirmed_idx = live_buses[bus_id].get("confirmed_stop_idx", nearest_stop_idx)
    
    if direction == "forward":
        remaining_stops = stops[confirmed_idx:]
        dest_stop = stops[-1] if stops else None
    else:
        remaining_stops = stops[:confirmed_idx+1][::-1]
        dest_stop = stops[0] if stops else None

    live_buses[bus_id]["destination_stop"] = dest_stop
    if dest_stop and dest_stop in STOP_COORDS:
        coords = STOP_COORDS[dest_stop]
        live_buses[bus_id]["destination_lat"] = coords[0]
        live_buses[bus_id]["destination_lon"] = coords[1]
    live_buses[bus_id]["remaining_stops"] = remaining_stops

    # Log to history collection for playback
    await db.live_bus_positions_history.insert_one({
        "bus_id": bus_id, "lat": lat, "lon": lon, "speed": speed,
        "heading": heading, "passengers": current_pax, "ts": now_ts,
        "date": today()
    })

    # Persist live state to DB
    save_data = live_buses[bus_id].copy()
    save_data.pop("route_geometry", None)
    await db.live_bus_positions.update_one(
        {"bus_id": bus_id},
        {"$set": save_data},
        upsert=True
    )
    last_seen[driver_id] = now_ts

    # Perform geofencing and safety checks
    await run_geofencing_check(bus_id, lat, lon)
    await run_safety_checks(bus_id, lat, lon, speed, now_ts)


async def stale_cleaner():
    """Background task to detect offline drivers and hardware kits."""
    while True:
        await asyncio.sleep(10)
        now = time.time()
        stale = [k for k, v in list(last_seen.items()) if now - v > VEHICLE_TTL]
        for uid in stale:
            last_seen.pop(uid, None)
        
        db = db_module.db
        for bid, info in list(live_buses.items()):
            curr_status = info.get("status")
            if curr_status == "offline":
                continue
            
            bus_last_active = info.get("last_active") or info.get("updated_at", 0)
            elapsed = now - bus_last_active
            
            if elapsed > VEHICLE_TTL:
                info["status"] = "offline"
                save_data = info.copy()
                save_data.pop("route_geometry", None)
                await db.live_bus_positions.update_one(
                    {"bus_id": bid},
                    {"$set": {"status": "offline", "updated_at": now}},
                    upsert=True
                )
                await trigger_system_alert(
                    "Driver Offline",
                    f"Bus {bid} (Driver: {info.get('driver_name', 'Unknown')}) is offline.",
                    alert_type="warning",
                    target_bus=bid
                )
            elif elapsed > VEHICLE_WARN_TTL and curr_status != "signal_loss":
                info["status"] = "signal_loss"
                await db.live_bus_positions.update_one(
                    {"bus_id": bid},
                    {"$set": {"status": "signal_loss"}},
                    upsert=True
                )


