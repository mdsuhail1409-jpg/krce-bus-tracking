"""
KRCE Bus Tracking System — Bus routes (public).
GET /api/buses, /api/buses/{bus_id}, /api/buses/{bus_id}/live, /api/buses/{bus_id}/passengers
"""

from fastapi import APIRouter, Depends, HTTPException

from app.auth import current_user
from app.state import live_buses
from app.utils import today
from app import database as db_module

router = APIRouter()


@router.get("/api/buses")
async def get_buses(u=Depends(current_user)):
    db = db_module.db
    td = today()
    cursor = db.buses.find({"is_active": 1}, {"_id": 0})
    buses = await cursor.to_list(length=None)

    # Batch boarded_today counts
    pipeline = [
        {"$match": {"date": td, "tap_type": "boarded"}},
        {"$group": {"_id": "$bus_id", "cnt": {"$sum": 1}}}
    ]
    count_docs = await db.attendance.aggregate(pipeline).to_list(length=None)
    count_map = {c["_id"]: c["cnt"] for c in count_docs}

    for bus in buses:
        bus_live = live_buses.get(bus["id"])
        if bus_live:
            bus_live_clean = bus_live.copy()
            bus_live_clean.pop("route_geometry", None)
            bus["live"] = bus_live_clean
        else:
            bus["live"] = None
        bus["boarded_today"] = count_map.get(bus["id"], 0)
    return buses


@router.get("/api/buses/{bus_id}/live")
async def bus_live(bus_id: str, u=Depends(current_user)):
    bus_live_data = live_buses.get(bus_id)
    if bus_live_data:
        bus_live_clean = bus_live_data.copy()
        bus_live_clean.pop("route_geometry", None)
        return bus_live_clean
    return {"status": "offline"}


@router.get("/api/buses/{bus_id}/passengers")
async def bus_passengers(bus_id: str, u=Depends(current_user)):
    db = db_module.db
    td = today()
    cursor = db.attendance.find(
        {"bus_id": bus_id, "date": td, "tap_type": "boarded"}, {"_id": 0}
    ).sort("tap_time", 1)
    records = await cursor.to_list(length=None)
    result = []
    for rec in records:
        user = await db.users.find_one({"id": rec["user_id"]}, {"_id": 0, "name": 1, "college_id": 1, "rfid_card": 1})
        result.append({
            "name":       user["name"]        if user else "Unknown",
            "college_id": user.get("college_id") if user else None,
            "rfid_card":  user.get("rfid_card")  if user else None,
            "tap_type":   rec["tap_type"],
            "tap_time":   rec["tap_time"],
            "stop_name":  rec.get("stop_name"),
        })
    return result


@router.get("/api/buses/{bus_id}")
async def get_bus_details(bus_id: str, u=Depends(current_user)):
    db = db_module.db
    bus = await db.buses.find_one({"id": bus_id}, {"_id": 0})
    if not bus:
        raise HTTPException(404, "Bus not found")
    
    td = today()
    boarded_count = await db.attendance.count_documents({"bus_id": bus_id, "date": td, "tap_type": "boarded"})
    bus["boarded_today"] = boarded_count

    bus_live_data = live_buses.get(bus_id)
    if bus_live_data:
        bus_live_clean = bus_live_data.copy()
        bus_live_clean.pop("route_geometry", None)
        bus["live"] = bus_live_clean
    else:
        bus["live"] = None
    return bus
