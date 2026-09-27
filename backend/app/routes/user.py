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
        parent_usr = await db.users.find_one({"id": u["sub"]}, {"_id": 0, "parent_of": 1})
        if parent_usr:
            child_cid = parent_usr.get("parent_of", "")

    if not child_cid:
        return []

    child = await db.users.find_one(
        {"$or": [{"college_id": child_cid}, {"id": child_cid}]},
        {"_id": 0, "id": 1, "name": 1, "college_id": 1, "bus_id": 1}
    )
    if not child:
        return []

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


@router.get("/api/my/ward")
async def get_my_ward(u=Depends(current_user)):
    """
    Get detailed profile of the assigned student ward and their live bus tracking details.
    Accessible by parent accounts.
    """
    db = db_module.db
    usr = await db.users.find_one({"id": u["sub"]})
    if not usr or usr.get("role") != "parent":
        raise HTTPException(400, "Only parent accounts can access student ward information")

    parent_of = usr.get("parent_of")
    if not parent_of:
        return {
            "has_ward": False,
            "message": "No student linked to this parent account yet."
        }

    child = await db.users.find_one(
        {"role": "student", "$or": [{"college_id": parent_of}, {"id": parent_of}]},
        {"_id": 0, "id": 1, "name": 1, "college_id": 1, "bus_id": 1, "rfid_card": 1, "phone": 1, "email": 1}
    )
    if not child:
        return {
            "has_ward": False,
            "message": f"Student profile for ID '{parent_of}' was not found in the directory."
        }

    bus_id = child.get("bus_id") or usr.get("bus_id")
    # Synchronize parent bus_id if missing
    if bus_id and not usr.get("bus_id"):
        await db.users.update_one({"id": usr["id"]}, {"$set": {"bus_id": bus_id}})

    bus_info = None
    if bus_id:
        bus = await db.buses.find_one({"id": bus_id, "is_active": 1}, {"_id": 0})
        if bus:
            driver = None
            if bus.get("driver_id"):
                driver = await db.users.find_one({"id": bus["driver_id"]}, {"_id": 0, "name": 1, "phone": 1})

            live = live_buses.get(bus_id)
            live_clean = None
            if live:
                live_clean = {
                    "lat": live.get("lat"),
                    "lon": live.get("lon"),
                    "speed": live.get("speed", 0.0),
                    "status": live.get("status", "in_transit"),
                    "last_updated": live.get("last_updated"),
                    "passengers": live.get("passengers", 0)
                }

            bus_info = {
                "id": bus["id"],
                "number": bus["number"],
                "route_name": bus.get("route_name"),
                "driver_name": driver["name"] if driver else None,
                "driver_phone": driver["phone"] if driver else None,
                "stops": bus.get("stops", []),
                "live": live_clean
            }

    # Fetch child's most recent attendance tap today
    last_attendance = await db.attendance.find_one(
        {"user_id": child["id"]},
        {"_id": 0},
        sort=[("tap_time", -1)]
    )

    return {
        "has_ward": True,
        "ward": {
            "id": child["id"],
            "name": child["name"],
            "college_id": child.get("college_id"),
            "rfid_card": child.get("rfid_card"),
            "email": child.get("email"),
            "phone": child.get("phone")
        },
        "bus": bus_info,
        "last_attendance": last_attendance
    }


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
    user_role = u.get("role", "student")

    if user_role in ("admin", "committee"):
        cursor = db.alerts.find(
            {"is_resolved": 0},
            {"_id": 0}
        ).sort("sent_at", -1).limit(30)
        return await cursor.to_list(length=None)

    # For passengers (student, parent, staff):
    user_doc = await db.users.find_one({"id": u["sub"]})
    user_bus = user_doc.get("bus_id") if user_doc else None

    # Role matching: 'all', specific role, or 'passenger'
    role_filter = {
        "$or": [
            {"target_role": "all"},
            {"target_role": user_role},
            {"target_role": "passenger"} if user_role in ("student", "parent", "staff") else {"target_role": user_role}
        ]
    }

    # Bus matching:
    # 1. Universal announcements from admin (target_bus is None, empty, or 'all')
    # 2. Alerts specifically targeting the user's assigned bus
    allowed_bus_targets = [None, "", "all"]
    if user_bus:
        allowed_bus_targets.append(user_bus)

    bus_filter = {"target_bus": {"$in": allowed_bus_targets}}

    query = {"is_resolved": 0, "$and": [role_filter, bus_filter]}
    cursor = db.alerts.find(query, {"_id": 0}).sort("sent_at", -1).limit(20)
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


@router.get("/api/my/bus-students")
async def get_my_bus_students(u=Depends(current_user)):
    """
    Roster of students assigned to the logged-in user's bus.
    Used by staff coordinators and drivers to see all students on their bus and real-time boarding status.
    """
    from datetime import date
    db = db_module.db
    usr = await db.users.find_one({"id": u["sub"]})
    if not usr:
        raise HTTPException(404, "User not found")

    bus_id = usr.get("bus_id") or u.get("bus_id")
    if not bus_id:
        return {
            "has_bus": False,
            "bus_id": None,
            "bus_number": None,
            "route_name": None,
            "total_students": 0,
            "boarded_count": 0,
            "students": [],
            "message": "No bus assigned to your account yet. Contact administrator to assign your bus route."
        }

    bus = await db.buses.find_one({"id": bus_id}, {"_id": 0})
    if not bus:
        return {
            "has_bus": False,
            "bus_id": bus_id,
            "bus_number": "Unknown",
            "route_name": "Unknown",
            "total_students": 0,
            "boarded_count": 0,
            "students": [],
            "message": f"Assigned bus '{bus_id}' not found in active bus fleet."
        }

    driver = None
    if bus.get("driver_id"):
        driver = await db.users.find_one({"id": bus["driver_id"]}, {"_id": 0, "name": 1, "phone": 1})

    today_str = date.today().isoformat()
    cursor = db.users.find(
        {"role": "student", "bus_id": bus_id, "is_active": 1},
        {"_id": 0, "id": 1, "name": 1, "college_id": 1, "phone": 1, "email": 1, "rfid_card": 1, "bus_stop": 1}
    ).sort("name", 1)
    students = await cursor.to_list(length=None)

    boarded_count = 0
    students_list = []
    for s in students:
        att = await db.attendance.find_one(
            {"user_id": s["id"], "bus_id": bus_id, "tap_time": {"$regex": f"^{today_str}"}},
            {"_id": 0, "tap_time": 1, "status": 1, "stop_name": 1}
        )
        is_boarded = att is not None
        if is_boarded:
            boarded_count += 1

        students_list.append({
            "id": s["id"],
            "name": s["name"],
            "college_id": s.get("college_id") or "—",
            "phone": s.get("phone") or "",
            "email": s.get("email") or "",
            "rfid_card": s.get("rfid_card") or "—",
            "bus_stop": s.get("bus_stop") or "General Route",
            "is_boarded": is_boarded,
            "boarded_at": att.get("tap_time") if att else None,
            "boarded_stop": att.get("stop_name") if att else None,
        })

    return {
        "has_bus": True,
        "bus_id": bus_id,
        "bus_number": bus.get("number"),
        "route_name": bus.get("route_name"),
        "capacity": bus.get("capacity", 0),
        "driver_name": driver.get("name") if driver else None,
        "driver_phone": driver.get("phone") if driver else None,
        "total_students": len(students_list),
        "boarded_count": boarded_count,
        "students": students_list,
    }

