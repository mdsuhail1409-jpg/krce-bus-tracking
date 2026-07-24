"""
KRCE Bus Tracking System — Emergency breakdown and Intelligent backup bus router.
"""

import uuid
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException

from app.auth import current_user, security
from app.state import live_buses, ws_pool
from app.utils import today, now_str, haversine
from app import database as db_module
from app.gps import trigger_system_alert
from app.config import logger, STOP_COORDS

router = APIRouter()


class BreakdownReport(BaseModel):
    lat: float
    lon: float
    emergency_type: str = "breakdown"
    bus_id: Optional[str] = "B01"


class AssignmentApproval(BaseModel):
    backup_bus_id: str


@router.post("/api/driver/breakdown")
async def report_breakdown(req: BreakdownReport, u: Optional[dict] = Depends(security)):
    bus_id = req.bus_id or "B01"
    driver_name = "Hardware Driver / Driver"
    if u and isinstance(u, dict):
        bus_id = u.get("bus_id") or bus_id
        driver_name = u.get("name", driver_name)

    db = db_module.db
    bus = await db.buses.find_one({"id": bus_id})
    if not bus:
        bus = {"id": bus_id, "number": bus_id, "stops": []}

    td = today()
    bus_number = bus.get("number", bus_id)
    # Guard: driver_name already set above; only override if logged-in user
    if u and isinstance(u, dict):
        driver_name = u.get("name", driver_name)


    # Calculate stops info based on current GPS
    stops = bus.get("stops", [])
    current_stop = "KRCE Campus"
    next_stop = "KRCE Campus"
    remaining_stops = []

    if stops:
        # Find stop closest to current GPS
        min_dist = float("inf")
        nearest_idx = 0
        for idx, stop_name in enumerate(stops):
            coords = STOP_COORDS.get(stop_name)
            if coords:
                d = haversine(req.lat, req.lon, coords[0], coords[1])
                if d < min_dist:
                    min_dist = d
                    nearest_idx = idx
        current_stop = stops[nearest_idx]
        if nearest_idx + 1 < len(stops):
            next_stop = stops[nearest_idx + 1]
            remaining_stops = stops[nearest_idx + 1:]
        else:
            next_stop = stops[-1]
            remaining_stops = [stops[-1]]

    # Get students currently onboard (last tap today is boarded)
    cursor = db.attendance.find({"bus_id": bus_id, "date": td})
    records = await cursor.to_list(length=None)
    records = sorted(records, key=lambda x: x.get("tap_time", ""))
    last_taps = {}
    for rec in records:
        last_taps[rec["user_id"]] = rec
    students_onboard = [uid for uid, rec in last_taps.items() if rec["tap_type"] == "boarded"]

    # --- Intelligent Backup Bus Selection Algorithm ---
    # 1. Fetch all buses
    cursor = db.buses.find({"is_active": 1})
    all_buses = await cursor.to_list(length=None)
    candidates = []

    for b in all_buses:
        # Skip broken bus
        if b["id"] == bus_id:
            continue

        # Skip if bus is not online (not in live_buses or marked offline)
        live = live_buses.get(b["id"])
        if not live or live.get("status") == "offline":
            continue

        # Skip if already handling another emergency
        active_emerg = await db.emergencies.find_one({
            "backup_bus_id": b["id"],
            "status": {"$in": ["assigned", "accepted"]}
        })
        if active_emerg:
            continue

        # Calculate current capacity and onboard count of candidate bus
        cursor = db.attendance.find({"bus_id": b["id"], "date": td})
        cand_records = await cursor.to_list(length=None)
        cand_records = sorted(cand_records, key=lambda x: x.get("tap_time", ""))
        cand_last_taps = {}
        for rec in cand_records:
            cand_last_taps[rec["user_id"]] = rec
        cand_onboard_count = sum(1 for rec in cand_last_taps.values() if rec["tap_type"] == "boarded")

        available_seats = max(0, b.get("capacity", 50) - cand_onboard_count)

        # Distance to broken bus
        dist = haversine(live["lat"], live["lon"], req.lat, req.lon)
        # ETA in minutes (avg speed 30km/h = 500m/min)
        eta = int(dist / 500) + 1

        candidates.append({
            "bus_id": b["id"],
            "bus_number": b["number"],
            "driver_id": b.get("driver_id"),
            "driver_name": live.get("driver_name", "Unknown"),
            "distance_km": round(dist / 1000.0, 2),
            "eta_minutes": eta,
            "available_seats": available_seats,
            "status": live.get("status", "moving"),
            "has_enough_seats": available_seats >= len(students_onboard)
        })

    # Sort recommendations: capacity match first, then shortest distance
    candidates.sort(key=lambda x: (not x["has_enough_seats"], x["distance_km"]))
    recommendations = candidates[:3]

    # Save emergency document
    emerg_id = str(uuid.uuid4())[:8]
    timeline = [
        {"status": "Emergency Reported", "ts": now_str(), "msg": f"Bus {bus_number} reported breakdown near {current_stop}."},
        {"status": "Admin Notified", "ts": now_str(), "msg": "Emergency alerts dispatched to Transport Committee."},
        {"status": "Backup Suggested", "ts": now_str(), "msg": f"Selection algorithm computed {len(recommendations)} backup recommendations."}
    ]

    emerg_doc = {
        "id": emerg_id,
        "bus_id": bus_id,
        "bus_number": bus_number,
        "driver_id": (u.get("sub") if u and isinstance(u, dict) else None) or "hw_node",
        "driver_name": driver_name,
        "gps": {"lat": req.lat, "lon": req.lon},
        "route_name": bus.get("route_name", ""),
        "current_stop": current_stop,
        "next_stop": next_stop,
        "remaining_stops": remaining_stops,
        "trip_id": str(uuid.uuid4())[:8],
        "students_onboard": students_onboard,
        "emergency_time": now_str(),
        "emergency_type": req.emergency_type,
        "status": "recommended",
        "backup_bus_id": None,
        "backup_bus_number": None,
        "backup_driver_name": None,
        "backup_driver_phone": None,
        "eta_minutes": None,
        "recommendations": recommendations,
        "timeline": timeline
    }

    await db.emergencies.insert_one(emerg_doc)

    # Immediately notify admins via system alert (WS broadcast)
    await trigger_system_alert(
        title="🚨 Bus Breakdown Emergency",
        message=f"Bus {bus_number} (Driver: {driver_name}) has experienced a breakdown near {current_stop}!",
        alert_type="danger",
        target_bus=bus_id
    )

    # Broadcast emergency-specific event to WebSocket connections
    import json
    ws_payload = json.dumps({"type": "emergency_reported", "id": emerg_id})
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {"status": "ok", "emergency_id": emerg_id}


@router.get("/api/admin/emergencies")
async def get_emergencies(u=Depends(current_user)):
    if u["role"] not in ("admin", "committee"):
        raise HTTPException(403, "Admin/Committee only")
    db = db_module.db
    cursor = db.emergencies.find({}, {"_id": 0})
    return await cursor.to_list(length=None)


@router.post("/api/admin/emergencies/{emergency_id}/assign")
async def assign_backup(emergency_id: str, req: AssignmentApproval, u=Depends(current_user)):
    if u["role"] not in ("admin", "committee"):
        raise HTTPException(403, "Admin/Committee only")

    db = db_module.db
    emerg = await db.emergencies.find_one({"id": emergency_id})
    if not emerg:
        raise HTTPException(404, "Emergency not found")

    backup_bus = await db.buses.find_one({"id": req.backup_bus_id})
    if not backup_bus:
        raise HTTPException(404, "Backup bus not found")

    backup_driver = None
    if backup_bus.get("driver_id"):
        backup_driver = await db.users.find_one({"id": backup_bus["driver_id"]})

    # Calculate distance/ETA
    live_backup = live_buses.get(req.backup_bus_id, {})
    dist = haversine(
        live_backup.get("lat", 10.927669),
        live_backup.get("lon", 78.7410),
        emerg["gps"]["lat"],
        emerg["gps"]["lon"]
    )
    eta = int(dist / 500) + 1

    # Update emergency
    backup_driver_name = backup_driver["name"] if backup_driver else "Unknown Driver"
    backup_driver_phone = backup_driver["phone"] if backup_driver else "N/A"
    
    timeline_entry = {
        "status": "Backup Assigned",
        "ts": now_str(),
        "msg": f"Committee assigned Bus {backup_bus['number']} (Driver: {backup_driver_name}) as backup."
    }

    await db.emergencies.update_one(
        {"id": emergency_id},
        {"$set": {
            "status": "assigned",
            "backup_bus_id": req.backup_bus_id,
            "backup_bus_number": backup_bus["number"],
            "backup_driver_name": backup_driver_name,
            "backup_driver_phone": backup_driver_phone,
            "eta_minutes": eta
        }, "$push": {"timeline": timeline_entry}}
    )

    await trigger_system_alert(
        title="Backup Bus Assigned",
        message=f"Bus {backup_bus['number']} assigned to assist broken Bus {emerg['bus_number']}.",
        alert_type="info",
        target_bus=emerg["bus_id"]
    )

    # WS broadcast to update admin & driver views
    import json
    ws_payload = json.dumps({"type": "emergency_update", "id": emergency_id})
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {"status": "ok"}


@router.post("/api/admin/emergencies/{emergency_id}/resolve")
async def resolve_emergency(emergency_id: str, u=Depends(current_user)):
    if u["role"] not in ("admin", "committee"):
        raise HTTPException(403, "Admin/Committee only")

    db = db_module.db
    emerg = await db.emergencies.find_one({"id": emergency_id})
    if not emerg:
        raise HTTPException(404, "Emergency not found")

    timeline_entry = {
        "status": "Emergency Resolved",
        "ts": now_str(),
        "msg": "Emergency situation resolved. Normal transit operations resumed."
    }

    await db.emergencies.update_one(
        {"id": emergency_id},
        {"$set": {"status": "resolved"}, "$push": {"timeline": timeline_entry}}
    )

    await trigger_system_alert(
        title="Emergency Resolved",
        message=f"Breakdown emergency for Bus {emerg['bus_number']} has been successfully resolved.",
        alert_type="success",
        target_bus=emerg["bus_id"]
    )

    import json
    ws_payload = json.dumps({"type": "emergency_update", "id": emergency_id})
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {"status": "ok"}


@router.get("/api/driver/emergency-assignment")
async def get_driver_assignment(u=Depends(current_user)):
    if u["role"] != "driver":
        raise HTTPException(403, "Drivers only")
    bus_id = u.get("bus_id")
    if not bus_id:
        return None

    db = db_module.db
    emerg = await db.emergencies.find_one({
        "backup_bus_id": bus_id,
        "status": "assigned"
    }, {"_id": 0})
    return emerg


@router.post("/api/driver/emergency-assignment/{emergency_id}/accept")
async def accept_assignment(emergency_id: str, u=Depends(current_user)):
    if u["role"] != "driver":
        raise HTTPException(403, "Drivers only")

    db = db_module.db
    emerg = await db.emergencies.find_one({"id": emergency_id})
    if not emerg:
        raise HTTPException(404, "Emergency not found")

    td = today()
    backup_bus_id = emerg["backup_bus_id"]
    students = emerg["students_onboard"]

    # 1. Update status and timeline
    timeline_entries = [
        {"status": "Driver Accepted", "ts": now_str(), "msg": f"Backup driver {u['name']} accepted pickup request."},
        {"status": "Students Boarded", "ts": now_str(), "msg": f"Transferred {len(students)} passengers to Bus {emerg['backup_bus_number']}."},
        {"status": "Trip Continued", "ts": now_str(), "msg": f"Commenced trip on Route: {emerg['route_name']}."}
    ]

    await db.emergencies.update_one(
        {"id": emergency_id},
        {"$set": {"status": "accepted"}, "$push": {"timeline": {"$each": timeline_entries}}}
    )

    # 2. Perform passenger database transfer
    if students:
        await db.attendance.update_many(
            {"user_id": {"$in": students}, "date": td},
            {"$set": {"bus_id": backup_bus_id}}
        )

    # 3. In-memory passengers count update
    if backup_bus_id in live_buses:
        live_buses[backup_bus_id]["passengers"] = live_buses[backup_bus_id].get("passengers", 0) + len(students)
    if emerg["bus_id"] in live_buses:
        live_buses[emerg["bus_id"]]["passengers"] = 0
        live_buses[emerg["bus_id"]]["status"] = "offline"

    # 4. Notify Students and Parents by inserting Alerts into the feed
    alert_students = {
        "id": str(uuid.uuid4())[:8],
        "title": "Assigned Bus Breakdown — Replacement Ready",
        "message": f"Your assigned Bus {emerg['bus_number']} has experienced a mechanical issue. Replacement Bus: {emerg['backup_bus_number']} (Driver: {emerg['backup_driver_name']}, ETA: {emerg['eta_minutes']} mins). Please remain at your current location.",
        "alert_type": "emergency",
        "target_role": "passenger",
        "target_bus": backup_bus_id,
        "sent_by": "system",
        "sent_at": now_str(),
        "is_resolved": 0
    }
    alert_parents = {
        "id": str(uuid.uuid4())[:8],
        "title": "Child's Bus Breakdown Alert",
        "message": f"Your child's assigned Bus {emerg['bus_number']} has encountered a breakdown. A replacement Bus: {emerg['backup_bus_number']} (Driver: {emerg['backup_driver_name']}, ETA: {emerg['eta_minutes']} mins) has been dispatched.",
        "alert_type": "emergency",
        "target_role": "parent",
        "target_bus": backup_bus_id,
        "sent_by": "system",
        "sent_at": now_str(),
        "is_resolved": 0
    }
    await db.alerts.insert_many([alert_students, alert_parents])

    await trigger_system_alert(
        title="Students Transferred",
        message=f"All passengers successfully transferred to backup Bus {emerg['backup_bus_number']}.",
        alert_type="success",
        target_bus=backup_bus_id
    )

    import json
    ws_payload = json.dumps({"type": "emergency_update", "id": emergency_id})
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {"status": "ok"}


@router.post("/api/driver/emergency-assignment/{emergency_id}/reject")
async def reject_assignment(emergency_id: str, u=Depends(current_user)):
    if u["role"] != "driver":
        raise HTTPException(403, "Drivers only")

    db = db_module.db
    emerg = await db.emergencies.find_one({"id": emergency_id})
    if not emerg:
        raise HTTPException(404, "Emergency not found")

    timeline_entry = {
        "status": "Driver Rejected",
        "ts": now_str(),
        "msg": f"Backup driver {u['name']} rejected pickup request."
    }

    # Reset assignment back to recommended
    await db.emergencies.update_one(
        {"id": emergency_id},
        {"$set": {
            "status": "recommended",
            "backup_bus_id": None,
            "backup_bus_number": None,
            "backup_driver_name": None,
            "backup_driver_phone": None,
            "eta_minutes": None
        }, "$push": {"timeline": timeline_entry}}
    )

    await trigger_system_alert(
        title="Backup Assignment Rejected",
        message=f"Driver of Bus {emerg['backup_bus_number']} rejected backup assignment.",
        alert_type="warning",
        target_bus=emerg["bus_id"]
    )

    import json
    ws_payload = json.dumps({"type": "emergency_update", "id": emergency_id})
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {"status": "ok"}


@router.get("/api/user/active-emergency")
async def get_active_emergency(u=Depends(current_user)):
    db = db_module.db
    role = u["role"]
    bus_id = u.get("bus_id")

    if role == "parent":
        parent_of = u.get("parent_of")
        if parent_of:
            child = await db.users.find_one({"college_id": parent_of}, {"_id": 0, "bus_id": 1})
            if child:
                bus_id = child.get("bus_id")

    if not bus_id:
        return None

    # Search for an active emergency affecting this bus (either as broken bus or backup bus)
    emerg = await db.emergencies.find_one({
        "$or": [
            {"bus_id": bus_id},
            {"backup_bus_id": bus_id}
        ],
        "status": {"$in": ["recommended", "assigned", "accepted"]}
    }, {"_id": 0})

    return emerg
