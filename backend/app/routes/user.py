"""
KRCE Bus Tracking System — User routes.
GET  /api/my/attendance, /api/my/child-attendance, /api/my/eta
POST /api/my/change-password
GET  /api/alerts (user-facing)
"""

from fastapi import APIRouter, Depends, HTTPException

from app.auth import _hash, _check_hash, current_user
from app.models import ChangePasswordReq
from app.state import live_buses, geofence_states
from app.config import STOP_COORDS
from app.utils import now_str
from app.predictions import predict_eta_delay
from app import database as db_module

router = APIRouter()


@router.get("/api/my/attendance")
async def my_attendance(u=Depends(current_user)):
    db = db_module.db
    cursor = db.attendance.find(
        {"user_id": u["sub"]}, {"_id": 0}
    ).sort("tap_time", -1).limit(40)
    records = await cursor.to_list(length=None)
    result = []
    for rec in records:
        bus = await db.buses.find_one({"id": rec["bus_id"]}, {"_id": 0, "number": 1, "route_name": 1})
        rec["bus_number"] = bus["number"]     if bus else None
        rec["route_name"] = bus["route_name"] if bus else None
        result.append(rec)
    return result


@router.get("/api/my/child-attendance")
async def child_attendance(u=Depends(current_user)):
    db = db_module.db
    child_cid = u.get("parent_of", "")
    if not child_cid:
        raise HTTPException(403, "Not linked to any child")
    child = await db.users.find_one({"college_id": child_cid}, {"_id": 0, "id": 1, "name": 1})
    if not child:
        raise HTTPException(404, "Child not found")
    cursor = db.attendance.find(
        {"user_id": child["id"]}, {"_id": 0}
    ).sort("tap_time", -1).limit(40)
    records = await cursor.to_list(length=None)
    result = []
    for rec in records:
        bus = await db.buses.find_one({"id": rec["bus_id"]}, {"_id": 0, "number": 1, "route_name": 1})
        rec["bus_number"] = bus["number"]     if bus else None
        rec["route_name"] = bus["route_name"] if bus else None
        rec["child_name"] = child["name"]
        result.append(rec)
    return result


@router.post("/api/my/change-password")
async def change_password(req: ChangePasswordReq, u=Depends(current_user)):
    db = db_module.db
    user = await db.users.find_one({"id": u["sub"]})
    if not user or not _check_hash(req.old_password, user["password_hash"]):
        raise HTTPException(401, "Invalid old password")

    new_password_hash = _hash(req.new_password)
    await db.users.update_one(
        {"id": u["sub"]},
        {"$set": {"password_hash": new_password_hash}}
    )
    await db.audit_log.insert_one({
        "user_id": u["sub"], "action": "change_password",
        "ip": "N/A", "ts": now_str()
    })
    return {"status": "ok", "message": "Password changed successfully"}


@router.get("/api/alerts")
async def get_alerts(u=Depends(current_user)):
    db = db_module.db
    cursor = db.alerts.find(
        {"is_resolved": 0, "$or": [{"target_role": "all"}, {"target_role": u["role"]}]},
        {"_id": 0}
    ).sort("sent_at", -1).limit(20)
    return await cursor.to_list(length=None)


@router.get("/api/my/eta")
async def get_my_eta(u=Depends(current_user)):
    db = db_module.db
    user = await db.users.find_one({"id": u["sub"]})
    if not user:
        raise HTTPException(404, "User not found")

    bus_id = user.get("bus_id", "")
    if not bus_id:
        return {"eta": "—", "next_stop": "—", "delay": "—", "distance": "—", "remaining_stops": []}

    live = live_buses.get(bus_id)
    if not live or live.get("status") == "offline":
        return {"eta": "—", "next_stop": "Bus Offline", "delay": "—", "distance": "—", "remaining_stops": []}

    last_tap = await db.attendance.find_one({"user_id": u["sub"]}, sort=[("tap_time", -1)])
    stop_name = last_tap.get("stop_name") if last_tap else None

    bus = await db.buses.find_one({"id": bus_id})
    if not bus:
        return {"eta": "—", "next_stop": "—", "delay": "—", "distance": "—", "remaining_stops": []}

    stops = bus.get("stops", [])
    if not stop_name and stops:
        stop_name = next((s for s in stops if s != "KRCE Campus"), stops[0])

    if not stop_name or stop_name not in STOP_COORDS:
        return {"eta": "—", "next_stop": "—", "delay": "—", "distance": "—", "remaining_stops": []}

    stop_coords = STOP_COORDS[stop_name]
    pred = predict_eta_delay(bus_id, stop_coords[0], stop_coords[1], live["speed"])

    last_visited = "KRCE Campus"
    if bus_id in geofence_states:
        for st, status in geofence_states[bus_id].items():
            if status == "inside":
                last_visited = st
                break

    remaining = []
    found_last = False
    for s in stops:
        if s == last_visited:
            found_last = True
            continue
        if found_last:
            remaining.append(s)
            if s == stop_name:
                break

    next_stop = remaining[0] if remaining else (stops[0] if stops else "—")

    return {
        "eta": pred["eta"],
        "next_stop": next_stop,
        "delay": pred["delay"],
        "distance": pred["distance"],
        "remaining_stops": remaining
    }
