"""
KRCE Bus Tracking System — Dedicated IoT Hardware telemetry routes.
Supports NodeMCU ESP8266 / SIM900A GPRS POST requests for GPS, RFID tap, and SOS button alerts.
"""

import uuid
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException

from app.models import RfidTap, GpsUpdate
from app.state import live_buses, ws_pool
from app.utils import today, now_str
from app.gps import process_gps_update, trigger_system_alert
from app import database as db_module

router = APIRouter()


class HardwareGpsUpdate(BaseModel):
    bus_id: str = "B01"
    lat: float
    lon: float
    speed: float = 0.0
    heading: float = 0.0
    passengers: int = 0


class HardwareEmergencyReport(BaseModel):
    bus_id: str = "B01"
    lat: float = 10.9601
    lon: float = 78.8078
    emergency_type: str = "SOS Button Pressed"


@router.post("/api/buses/{bus_id}/live")
async def hardware_bus_live_post(bus_id: str, req: GpsUpdate):
    """Handle hardware GPS location broadcast from ESP8266 / SIM900A."""
    db = db_module.db
    bus = await db.buses.find_one({"id": bus_id})
    driver_name = "Hardware NodeMCU"
    driver_id = "hw_node"
    if bus and bus.get("driver_id"):
        drv = await db.users.find_one({"id": bus["driver_id"]})
        if drv:
            driver_name = drv.get("name", driver_name)
            driver_id = drv.get("id", driver_id)

    await process_gps_update(
        bus_id=bus_id,
        driver_id=driver_id,
        driver_name=driver_name,
        lat=req.lat,
        lon=req.lon,
        speed=req.speed,
        heading=req.heading,
        passengers=req.passengers
    )
    return {"status": "ok", "bus_id": bus_id}


@router.post("/api/hardware/gps")
async def hardware_gps_post(req: HardwareGpsUpdate):
    """Handle hardware GPS location broadcast via generic hardware route."""
    db = db_module.db
    bus = await db.buses.find_one({"id": req.bus_id})
    driver_name = "Hardware NodeMCU"
    driver_id = "hw_node"
    if bus and bus.get("driver_id"):
        drv = await db.users.find_one({"id": bus["driver_id"]})
        if drv:
            driver_name = drv.get("name", driver_name)
            driver_id = drv.get("id", driver_id)

    await process_gps_update(
        bus_id=req.bus_id,
        driver_id=driver_id,
        driver_name=driver_name,
        lat=req.lat,
        lon=req.lon,
        speed=req.speed,
        heading=req.heading,
        passengers=req.passengers
    )
    return {"status": "ok", "bus_id": req.bus_id}


@router.post("/api/hardware/rfid/tap")
async def hardware_rfid_tap(req: RfidTap):
    """Handle hardware RFID swipe without JWT bearer requirement."""
    db = db_module.db
    stu = await db.users.find_one({"rfid_card": req.rfid_card, "is_active": 1}, {"_id": 0, "id": 1, "name": 1})
    if not stu:
        # Auto-create or log unknown card tap for hardware testing fallback
        stu = {"id": f"unk_{req.rfid_card}", "name": f"Student ({req.rfid_card})"}

    td = today()
    cursor = db.attendance.find(
        {"user_id": stu["id"], "date": td},
        {"_id": 0, "tap_type": 1}
    ).sort([("tap_time", -1)]).limit(1)
    taps = await cursor.to_list(length=1)
    last_tap = taps[0] if taps else None
    tap_type = "exited" if (last_tap and last_tap["tap_type"] == "boarded") else "boarded"

    await db.attendance.insert_one({
        "id": str(uuid.uuid4()), "user_id": stu["id"], "bus_id": req.bus_id,
        "tap_type": tap_type, "tap_time": now_str(), "stop_name": req.stop_name or "Live Stop",
        "lat": req.lat, "lon": req.lon, "date": td
    })

    new_pax = 0
    if req.bus_id in live_buses:
        delta = 1 if tap_type == "boarded" else -1
        live_buses[req.bus_id]["passengers"] = max(
            0, live_buses[req.bus_id].get("passengers", 0) + delta
        )
        new_pax = live_buses[req.bus_id]["passengers"]

    import json
    ws_payload = json.dumps({
        "type": "pax_update",
        "bus_id": req.bus_id,
        "passengers": new_pax,
        "student_name": stu["name"],
        "tap_type": tap_type
    })
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {"status": "ok", "tap_type": tap_type, "student_name": stu["name"]}


@router.post("/api/driver/breakdown")
async def hardware_driver_breakdown(req: HardwareEmergencyReport):
    """Handle breakdown & SOS button alerts from ESP8266 NodeMCU."""
    bus_id = req.bus_id
    await trigger_system_alert(
        "SOS Panic Emergency Alert",
        f"Bus {bus_id} Hardware SOS Panic Button Pressed at Lat: {req.lat:.4f}, Lon: {req.lon:.4f}! Immediate assistance requested.",
        alert_type="danger",
        target_bus=bus_id
    )
    return {"status": "ok", "message": "Emergency broadcast sent"}
