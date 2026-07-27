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


async def check_parent_bus_access(db, u, bus_id: str):
    if u.get("role") == "parent":
        parent_of = u.get("parent_of")
        if not parent_of:
            raise HTTPException(403, "Access Denied: No child associated with your parent account.")
        child = await db.users.find_one({"college_id": parent_of}, {"_id": 0, "bus_id": 1})
        if not child or child.get("bus_id") != bus_id:
            raise HTTPException(403, "Access Denied: You are not authorized to track this bus.")


@router.get("/api/buses")
async def get_buses(u=Depends(current_user)):
    db = db_module.db
    td = today()

    # If parent, only fetch their child's assigned bus
    if u.get("role") == "parent":
        parent_of = u.get("parent_of")
        if not parent_of:
            return []
        child = await db.users.find_one({"college_id": parent_of}, {"_id": 0, "bus_id": 1})
        if not child or not child.get("bus_id"):
            return []
        cursor = db.buses.find({"id": child["bus_id"], "is_active": 1}, {"_id": 0})
    else:
        cursor = db.buses.find({"is_active": 1}, {"_id": 0})

    buses = await cursor.to_list(length=None)

    # Calculate currently boarded count for each bus (last tap today is "boarded")
    cursor = db.attendance.find({"date": td})
    records = await cursor.to_list(length=None)
    records = sorted(records, key=lambda x: x.get("tap_time", ""))
    last_taps = {}
    for rec in records:
        last_taps[rec["user_id"]] = rec
    
    count_map = {}
    for rec in last_taps.values():
        if rec["tap_type"] == "boarded":
            bid = rec["bus_id"]
            count_map[bid] = count_map.get(bid, 0) + 1

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
    return buses


@router.get("/api/buses/{bus_id}/live")
async def bus_live(bus_id: str, u=Depends(current_user)):
    db = db_module.db
    await check_parent_bus_access(db, u, bus_id)
    
    bus_live_data = live_buses.get(bus_id)
    if bus_live_data:
        bus_live_clean = bus_live_data.copy()
        bus_live_clean.pop("route_geometry", None)
        return bus_live_clean
    return {"status": "offline"}


@router.get("/api/buses/{bus_id}/passengers")
async def bus_passengers(bus_id: str, u=Depends(current_user)):
    db = db_module.db
    await check_parent_bus_access(db, u, bus_id)

    td = today()
    cursor = db.attendance.find({"bus_id": bus_id, "date": td})
    records = await cursor.to_list(length=None)
    records = sorted(records, key=lambda x: x.get("tap_time", ""))
    
    last_taps = {}
    for rec in records:
        last_taps[rec["user_id"]] = rec
        
    onboard_records = [rec for rec in last_taps.values() if rec["tap_type"] == "boarded"]
    onboard_records = sorted(onboard_records, key=lambda x: x.get("tap_time", ""))
    
    result = []
    for rec in onboard_records:
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
    await check_parent_bus_access(db, u, bus_id)

    bus = await db.buses.find_one({"id": bus_id}, {"_id": 0})
    if not bus:
        raise HTTPException(404, "Bus not found")
    
    driver = None
    if bus.get("driver_id"):
        driver = await db.users.find_one({"id": bus["driver_id"]}, {"_id": 0, "name": 1, "phone": 1})
    bus["driver_name"]  = driver["name"]  if driver else None
    bus["driver_phone"] = driver["phone"] if driver else None

    td = today()
    cursor = db.attendance.find({"bus_id": bus_id, "date": td})
    records = await cursor.to_list(length=None)
    records = sorted(records, key=lambda x: x.get("tap_time", ""))
    
    last_taps = {}
    for rec in records:
        last_taps[rec["user_id"]] = rec
        
    boarded_count = sum(1 for rec in last_taps.values() if rec["tap_type"] == "boarded")
    bus["boarded_today"] = boarded_count

    bus_live_data = live_buses.get(bus_id)
    if bus_live_data:
        bus_live_clean = bus_live_data.copy()
        bus_live_clean.pop("route_geometry", None)
        bus["live"] = bus_live_clean
    else:
        bus["live"] = None
    return bus
