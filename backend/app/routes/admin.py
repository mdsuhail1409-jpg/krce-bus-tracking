"""
KRCE Bus Tracking System — Admin routes.
All /api/admin/* endpoints.
"""

import csv
import io
import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from app.auth import _hash, admin_only
from app.models import BusUpsert, AlertCreate, RegAction
from app.state import live_buses, last_seen
from app.utils import today, now_str
from app.predictions import predict_occupancy
from app import database as db_module
import json

router = APIRouter()


# ═══════════════════════════════════════════════════════════════════
#  STATS
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/stats")
async def admin_stats(u=Depends(admin_only)):
    db = db_module.db
    td = today()
    total_students  = await db.users.count_documents({"role": {"$in": ["student","staff"]}})
    active_buses    = await db.buses.count_documents({"is_active": 1})
    boarded_today   = len(await db.attendance.distinct("user_id", {"date": td, "tap_type": "boarded"}))
    pending_regs    = await db.registrations.count_documents({"status": "pending"})
    total_drivers   = await db.users.count_documents({"role": "driver"})
    active_alerts   = await db.alerts.count_documents({"is_resolved": 0})
    live_count      = sum(1 for b in live_buses.values() if b.get("status") != "offline")
    return {
        "total_students": total_students, "active_buses": active_buses,
        "boarded_today": boarded_today, "pending_regs": pending_regs,
        "total_drivers": total_drivers, "active_alerts": active_alerts,
        "live_buses": live_count,
    }


# ═══════════════════════════════════════════════════════════════════
#  BUSES
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/buses")
async def admin_buses(u=Depends(admin_only)):
    db = db_module.db
    td = today()
    cursor = db.buses.find({"is_active": 1}, {"_id": 0}).sort("number", 1)
    buses = await cursor.to_list(length=None)

    # Batch boarded_today counts
    pipeline = [
        {"$match": {"date": td, "tap_type": "boarded"}},
        {"$group": {"_id": "$bus_id", "cnt": {"$sum": 1}}}
    ]
    count_docs = await db.attendance.aggregate(pipeline).to_list(length=None)
    count_map = {c["_id"]: c["cnt"] for c in count_docs}

    result = []
    for bus in buses:
        driver = None
        if bus.get("driver_id"):
            driver = await db.users.find_one({"id": bus["driver_id"]}, {"_id": 0, "name": 1, "phone": 1})
        bus["driver_name"]  = driver["name"]  if driver else None
        bus["driver_phone"] = driver["phone"] if driver else None

        bus_live = live_buses.get(bus["id"])
        if bus_live:
            bus_live_clean = bus_live.copy()
            bus_live_clean.pop("route_geometry", None)
            bus["live"] = bus_live_clean
        else:
            bus["live"] = None

        bus["boarded_today"] = count_map.get(bus["id"], 0)
        result.append(bus)
    return result


@router.post("/api/admin/buses")
async def create_bus(req: BusUpsert, u=Depends(admin_only)):
    db = db_module.db
    bid = "B" + str(uuid.uuid4())[:6]
    await db.buses.insert_one({
        "id": bid, "number": req.number, "route_name": req.route_name,
        "driver_id": req.driver_id or None, "capacity": req.capacity,
        "stops": req.stops, "is_active": 1, "created_at": now_str()
    })
    return {"status": "ok", "bus_id": bid}


@router.put("/api/admin/buses/{bus_id}")
async def update_bus(bus_id: str, req: BusUpsert, u=Depends(admin_only)):
    db = db_module.db
    await db.buses.update_one({"id": bus_id}, {"$set": {
        "number": req.number, "route_name": req.route_name,
        "driver_id": req.driver_id or None, "capacity": req.capacity, "stops": req.stops
    }})
    return {"status": "ok"}


@router.delete("/api/admin/buses/{bus_id}")
async def delete_bus(bus_id: str, u=Depends(admin_only)):
    db = db_module.db
    await db.buses.update_one({"id": bus_id}, {"$set": {"is_active": 0}})
    return {"status": "ok"}


# ═══════════════════════════════════════════════════════════════════
#  USERS
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/users")
async def admin_users(role: str = "", u=Depends(admin_only)):
    db = db_module.db
    query = {"role": role} if role else {}
    fields = {"_id": 0, "password_hash": 0}
    cursor = db.users.find(query, fields).sort([("role", 1), ("name", 1)])
    return await cursor.to_list(length=None)


@router.post("/api/admin/users/{uid}/toggle")
async def toggle_user(uid: str, u=Depends(admin_only)):
    db = db_module.db
    user = await db.users.find_one({"id": uid}, {"_id": 0, "is_active": 1})
    if not user:
        raise HTTPException(404, "User not found")
    new_val = 0 if user["is_active"] else 1
    await db.users.update_one({"id": uid}, {"$set": {"is_active": new_val}})
    return {"status": "ok", "is_active": new_val}


# ═══════════════════════════════════════════════════════════════════
#  DRIVERS
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/drivers")
async def admin_drivers(u=Depends(admin_only)):
    db = db_module.db
    cursor = db.users.find({"role": "driver"}, {"_id": 0, "password_hash": 0}).sort("name", 1)
    drivers = await cursor.to_list(length=None)
    result = []
    for drv in drivers:
        bus = None
        if drv.get("bus_id"):
            bus = await db.buses.find_one({"id": drv["bus_id"]}, {"_id": 0, "number": 1, "route_name": 1})
        drv["bus_number"] = bus["number"]     if bus else None
        drv["route_name"] = bus["route_name"] if bus else None
        drv["is_online"]  = drv["id"] in last_seen
        result.append(drv)
    return result


# ═══════════════════════════════════════════════════════════════════
#  ATTENDANCE & PLAYBACK
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/attendance")
async def admin_attendance(date_filter: str = "", bus_id: str = "", u=Depends(admin_only)):
    db = db_module.db
    query = {}
    if date_filter:
        query["date"] = date_filter
    if bus_id:
        query["bus_id"] = bus_id

    pipeline = [
        {"$match": query},
        {"$sort": {"tap_time": -1}},
        {"$limit": 300},
        {"$lookup": {
            "from": "users",
            "localField": "user_id",
            "foreignField": "id",
            "as": "user_info"
        }},
        {"$unwind": {"path": "$user_info", "preserveNullAndEmptyArrays": True}},
        {"$lookup": {
            "from": "buses",
            "localField": "bus_id",
            "foreignField": "id",
            "as": "bus_info"
        }},
        {"$unwind": {"path": "$bus_info", "preserveNullAndEmptyArrays": True}},
        {"$project": {
            "_id": 0,
            "id": "$id",
            "user_id": "$user_id",
            "bus_id": "$bus_id",
            "tap_type": "$tap_type",
            "tap_time": "$tap_time",
            "stop_name": "$stop_name",
            "lat": "$lat",
            "lon": "$lon",
            "date": "$date",
            "student_name": {"$ifNull": ["$user_info.name", "Unknown"]},
            "college_id": "$user_info.college_id",
            "bus_number": "$bus_info.number",
            "route_name": "$bus_info.route_name"
        }}
    ]
    cursor = db.attendance.aggregate(pipeline)
    return await cursor.to_list(length=None)


@router.get("/api/admin/attendance/export")
async def export_attendance(date_filter: str = "", bus_id: str = "", u=Depends(admin_only)):
    rows = await admin_attendance(date_filter=date_filter, bus_id=bus_id, u=u)
    output = io.StringIO()
    w = csv.writer(output)
    w.writerow(["Student Name","College ID","Bus","Route","Tap Type","Stop","Time","Date"])
    for r in rows:
        w.writerow([r.get("student_name"), r.get("college_id"), r.get("bus_number"),
                    r.get("route_name"), r.get("tap_type"), r.get("stop_name"),
                    r.get("tap_time"), r.get("date")])
    output.seek(0)
    filename = f"attendance_{date_filter or today()}.csv"
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode()), media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@router.get("/api/admin/playback/{bus_id}")
async def get_trip_playback(bus_id: str, date_filter: str = "", u=Depends(admin_only)):
    db = db_module.db
    td = date_filter or today()
    cursor = db.live_bus_positions_history.find(
        {"bus_id": bus_id, "date": td},
        {"_id": 0, "lat": 1, "lon": 1, "speed": 1, "heading": 1, "ts": 1}
    ).sort("ts", 1)
    history = await cursor.to_list(length=None)
    return history


# ═══════════════════════════════════════════════════════════════════
#  ANALYTICS & REPORTS
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/reports")
async def get_admin_reports(report_type: str, date_filter: str = "", u=Depends(admin_only)):
    db = db_module.db
    td = date_filter or today()
    if report_type == "trip":
        history_cursor = db.live_bus_positions_history.find({"date": td})
        history_logs = await history_cursor.to_list(length=None)

        bus_metrics = {}
        for log in history_logs:
            bid = log["bus_id"]
            if bid not in bus_metrics:
                bus_metrics[bid] = {"distance": 0, "speeds": [], "max_speed": 0}
            bus_metrics[bid]["speeds"].append(log["speed"])
            if log["speed"] > bus_metrics[bid]["max_speed"]:
                bus_metrics[bid]["max_speed"] = log["speed"]

        trips = []
        for bid, metrics in bus_metrics.items():
            bus = await db.buses.find_one({"id": bid})
            avg_speed = sum(metrics["speeds"]) / len(metrics["speeds"]) if metrics["speeds"] else 0
            distance_km = (avg_speed * (5 * len(metrics["speeds"]))) / 1000.0
            fuel_liters = distance_km / 4.0  # 4km/L
            trips.append({
                "bus_id": bid,
                "bus_number": bus.get("number", bid) if bus else bid,
                "route_name": bus.get("route_name", "Woraiyur") if bus else "Woraiyur",
                "distance_covered": f"{distance_km:.2f} km",
                "avg_speed": f"{(avg_speed * 3.6):.1f} km/h",
                "max_speed": f"{(metrics['max_speed'] * 3.6):.1f} km/h",
                "fuel_estimate": f"{fuel_liters:.1f} L"
            })
        return trips

    elif report_type == "driver":
        cursor = db.users.find({"role": "driver"}, {"_id": 0, "name": 1, "id": 1})
        drivers = await cursor.to_list(length=None)
        driver_reports = []
        for drv in drivers:
            alerts_count = await db.alerts.count_documents({
                "sent_by": drv["id"],
                "sent_at": {"$regex": "^" + td}
            })
            overspeed_alerts = await db.alerts.count_documents({
                "title": "Overspeed Alert",
                "target_bus": {"$ne": None},
                "sent_at": {"$regex": "^" + td}
            })
            driver_reports.append({
                "driver_id": drv["id"],
                "driver_name": drv["name"],
                "alerts_broadcasted": alerts_count,
                "overspeeding_violations": overspeed_alerts,
                "safety_score": max(50, 100 - (overspeed_alerts * 10))
            })
        return driver_reports

    elif report_type == "attendance":
        pipeline = [
            {"$match": {"date": td}},
            {"$lookup": {
                "from": "users",
                "localField": "user_id",
                "foreignField": "id",
                "as": "user"
            }},
            {"$unwind": "$user"},
            {"$project": {
                "_id": 0,
                "student_name": "$user.name",
                "college_id": "$user.college_id",
                "bus_id": "$bus_id",
                "tap_type": "$tap_type",
                "tap_time": "$tap_time",
                "stop_name": "$stop_name"
            }}
        ]
        cursor = db.attendance.aggregate(pipeline)
        return await cursor.to_list(length=None)

    elif report_type == "delay":
        alerts_cursor = db.alerts.find({
            "title": {"$regex": "Delay|deviation", "$options": "i"},
            "sent_at": {"$regex": "^" + td}
        }, {"_id": 0})
        return await alerts_cursor.to_list(length=None)

    elif report_type == "utilization":
        cursor = db.buses.find({"is_active": 1})
        buses = await cursor.to_list(length=None)
        utilizations = []
        for bus in buses:
            boarded = await db.attendance.count_documents({
                "bus_id": bus["id"], "date": td, "tap_type": "boarded"
            })
            cap = bus.get("capacity", 50)
            utilizations.append({
                "bus_id": bus["id"],
                "bus_number": bus["number"],
                "capacity": cap,
                "max_occupancy": boarded,
                "utilization_rate": f"{(boarded / max(cap, 1) * 100):.1f}%",
                "status": predict_occupancy(bus["id"], cap, boarded)
            })
        return utilizations
    else:
        raise HTTPException(400, "Invalid report type")


# ═══════════════════════════════════════════════════════════════════
#  REGISTRATIONS
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/registrations")
async def admin_regs(status: str = "pending", u=Depends(admin_only)):
    db = db_module.db
    cursor = db.registrations.find({"status": status}, {"_id": 0}).sort("submitted_at", -1)
    return await cursor.to_list(length=None)


@router.post("/api/admin/registrations/action")
async def reg_action(req: RegAction, u=Depends(admin_only)):
    db = db_module.db
    from app.config import logger
    reg = await db.registrations.find_one({"id": req.reg_id}, {"_id": 0})
    if not reg:
        raise HTTPException(404, "Registration not found")

    await db.registrations.update_one({"id": req.reg_id}, {"$set": {
        "status": req.action, "reviewed_by": u["sub"],
        "reviewed_at": now_str(), "notes": req.notes
    }})

    if req.action == "approved":
        new_uid  = reg["role"][:3] + str(uuid.uuid4())[:6]
        new_password = secrets.token_urlsafe(12)
        pw_hash = _hash(new_password)
        logger.info(f"Generated password for {reg['email']}: {new_password}")
        await db.users.insert_one({
            "id": new_uid, "name": reg["name"], "email": reg["email"],
            "phone": reg.get("phone"), "role": reg["role"],
            "college_id": reg.get("college_id"), "rfid_card": req.rfid_card or None,
            "bus_id": req.bus_id or None, "parent_of": None, "licence_no": None,
            "password_hash": pw_hash, "is_active": 1, "created_at": now_str(), "last_login": None
        })

    msg = "approved" if req.action == "approved" else "rejected"
    return {"status": "ok", "message": f"Registration {msg}"}


# ═══════════════════════════════════════════════════════════════════
#  ALERTS
# ═══════════════════════════════════════════════════════════════════
@router.get("/api/admin/alerts")
async def admin_alerts(u=Depends(admin_only)):
    db = db_module.db
    cursor = db.alerts.find({}, {"_id": 0}).sort("sent_at", -1).limit(50)
    return await cursor.to_list(length=None)


@router.post("/api/admin/alerts")
async def send_alert(req: AlertCreate, u=Depends(admin_only)):
    db = db_module.db
    from app.state import ws_pool
    aid = str(uuid.uuid4())[:8]
    await db.alerts.insert_one({
        "id": aid, "title": req.title, "message": req.message,
        "alert_type": req.alert_type, "target_role": req.target_role,
        "target_bus": req.target_bus or None, "sent_by": u["sub"],
        "sent_at": now_str(), "is_resolved": 0
    })
    payload = json.dumps({
        "type": "alert", "id": aid, "title": req.title,
        "message": req.message, "alert_type": req.alert_type,
    })
    for uid, ws in list(ws_pool.items()):
        try:
            await ws.send_text(payload)
        except Exception:
            pass
    return {"status": "ok", "alert_id": aid}


@router.post("/api/admin/alerts/{aid}/resolve")
async def resolve_alert(aid: str, u=Depends(admin_only)):
    db = db_module.db
    await db.alerts.update_one({"id": aid}, {"$set": {"is_resolved": 1}})
    return {"status": "ok"}
