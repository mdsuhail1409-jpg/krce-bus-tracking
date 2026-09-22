"""
KRCE Bus Tracking System — Dedicated IoT Hardware telemetry routes.
Supports ESP32 / SIM900A GPRS POST requests for GPS, RFID tap, and SOS button alerts.
"""

import time
import uuid
import os

from pydantic import BaseModel
from fastapi import APIRouter, Header, HTTPException

from app.models import RfidTap, GpsUpdate
from app.state import live_buses, ws_pool
from app.utils import today, now_str
from app.gps import process_gps_update, trigger_system_alert
from app.config import logger
from app import database as db_module

router = APIRouter()

# ─────────────────────────────────────────────────────────────
#  OPTIONAL API KEY AUTH FOR HARDWARE DEVICES
#  Set HW_API_KEY env var in Render dashboard to enable.
#  If not set, any device can POST (backward compatible).
# ─────────────────────────────────────────────────────────────
_HW_API_KEY = os.getenv("HW_API_KEY", "")


def normalize_bus_id(bus_id_or_device_id: str) -> str:
    """Normalize hardware device identifier or bus number to database bus ID (e.g. B07)."""
    val = (bus_id_or_device_id or "").strip().upper()
    if val in ["7", "BUS_7", "BUS_07", "BUS-07", "BUS_007", "TN-07", "B07", "B7"]:
        return "B07"
    if val in ["1", "BUS_1", "BUS_01", "BUS-01", "BUS_001", "TN-01", "B01", "B1"]:
        return "B01"
    if val in ["2", "BUS_2", "BUS_02", "BUS-02", "BUS_002", "TN-02", "B02", "B2"]:
        return "B02"
    if val in ["3", "BUS_3", "BUS_03", "BUS-03", "BUS_003", "TN-03", "B03", "B3"]:
        return "B03"
    if val in ["4", "BUS_4", "BUS_04", "BUS-04", "BUS_004", "TN-04", "B04", "B4"]:
        return "B04"
    if val in ["5", "BUS_5", "BUS_05", "BUS-05", "BUS_005", "TN-05", "B05", "B5"]:
        return "B05"
    if val in ["6", "BUS_6", "BUS_06", "BUS-06", "BUS_006", "TN-06", "B06", "B6"]:
        return "B06"
    return val or "B07"


async def _verify_hw_key(x_device_key: str = "", x_api_key: str = ""):
    """Optional device key check supporting both X-Device-Key and X-API-Key headers."""
    key = x_device_key or x_api_key
    if _HW_API_KEY and key != _HW_API_KEY:
        logger.warning("[HW AUTH] Rejected request with invalid device key: '%s'", key)
        raise HTTPException(status_code=403, detail="Invalid device key")


class HardwareGpsUpdate(BaseModel):
    bus_id: str = ""
    busId: str = ""
    deviceId: str = ""
    lat: float = 0.0
    latitude: float = 0.0
    lon: float = 0.0
    longitude: float = 0.0
    speed: float = 0.0
    heading: float = 0.0
    passengers: int = 0
    satellites: int = 0
    hdop: float = 0.0
    altitude: float = 0.0
    gpsFix: bool = False
    tripActive: bool = False


class HardwareRfidTap(BaseModel):
    rfid_card: str = ""
    uid: str = ""
    bus_id: str = ""
    deviceId: str = ""
    stop_name: str = ""
    lat: float = 0.0
    lon: float = 0.0
    timestamp: str = ""


class HardwareEmergencyReport(BaseModel):
    bus_id: str = ""
    deviceId: str = ""
    lat: float = 10.9601
    latitude: float = 0.0
    lon: float = 78.8078
    longitude: float = 0.0
    type: str = ""
    emergency_type: str = "SOS Button Pressed"


class HardwarePing(BaseModel):
    deviceId: str = ""
    bus_id: str = ""
    status: str = "online"
    tripActive: bool = False


class HardwareTripEvent(BaseModel):
    deviceId: str = ""
    bus_id: str = ""
    event: str = ""
    lat: float = 0.0
    latitude: float = 0.0
    lon: float = 0.0
    longitude: float = 0.0


# ─────────────────────────────────────────────────────────────
#  KEEP-ALIVE PING & HARDWARE STATUS
#  ESP32 calls this every 5-30s to warm Render and check buzzer state.
# ─────────────────────────────────────────────────────────────
@router.get("/api/hardware/ping")
@router.post("/api/hardware/ping")
async def hardware_ping(bus_id: str = "B07", ping_data: HardwarePing = None, x_device_key: str = Header(default=""), x_api_key: str = Header(default="")):
    """Lightweight keep-alive for ESP32. Warms Render and returns buzzer status."""
    await _verify_hw_key(x_device_key, x_api_key)
    target_bus = normalize_bus_id(ping_data.bus_id or ping_data.deviceId if ping_data else bus_id)
    db = db_module.db
    emerg = None
    if db is not None:
        emerg = await db.emergencies.find_one({
            "bus_id": target_bus,
            "status": {"$ne": "resolved"},
            "buzzer_active": 1
        })
    buzzer_active = True if emerg else False
    live_count = sum(1 for b in live_buses.values() if b.get("status") != "offline")
    return {"ok": True, "ts": int(time.time()), "bus_id": target_bus, "buzzer_active": buzzer_active, "live_buses": live_count}


@router.get("/api/hardware/status")
async def hardware_status(bus_id: str = "B07"):
    """Check hardware status including active buzzer state until admin acknowledgement."""
    target_bus = normalize_bus_id(bus_id)
    db = db_module.db
    emerg = None
    if db is not None:
        emerg = await db.emergencies.find_one({
            "bus_id": target_bus,
            "status": {"$ne": "resolved"},
            "buzzer_active": 1
        })
    buzzer_active = True if emerg else False
    return {"ok": True, "bus_id": target_bus, "buzzer_active": buzzer_active, "emergency_id": emerg["id"] if emerg else None}


# ─────────────────────────────────────────────────────────────
#  GPS LOCATION — via bus_id path param
# ─────────────────────────────────────────────────────────────
@router.post("/api/buses/{bus_id}/live")
async def hardware_bus_live_post(bus_id: str, req: GpsUpdate):
    """Handle hardware GPS location broadcast from ESP32 / SIM900A."""
    db = db_module.db
    bus = await db.buses.find_one({"id": bus_id})
    driver_name = "Hardware ESP32"
    driver_id = "hw_node"
    if bus and bus.get("driver_id"):
        drv = await db.users.find_one({"id": bus["driver_id"]})
        if drv:
            driver_name = drv.get("name", driver_name)
            driver_id = drv.get("id", driver_id)

    logger.info("[HW GPS] bus=%s lat=%.4f lon=%.4f spd=%.1f km/h", bus_id, req.lat, req.lon, req.speed)

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


# ─────────────────────────────────────────────────────────────
#  GPS LOCATION — via JSON body (primary ESP32 endpoint)
# ─────────────────────────────────────────────────────────────
@router.post("/api/hardware/gps")
async def hardware_gps_post(req: HardwareGpsUpdate, x_device_key: str = Header(default=""), x_api_key: str = Header(default="")):
    """Handle hardware GPS location broadcast via generic hardware route."""
    await _verify_hw_key(x_device_key, x_api_key)

    target_bus = normalize_bus_id(req.bus_id or req.busId or req.deviceId or "B07")
    actual_lat = req.lat if req.lat != 0.0 else req.latitude
    actual_lon = req.lon if req.lon != 0.0 else req.longitude

    db = db_module.db
    driver_name = "Hardware ESP32"
    driver_id = "hw_node"
    if db is not None:
        bus = await db.buses.find_one({"id": target_bus})
        if bus and bus.get("driver_id"):
            drv = await db.users.find_one({"id": bus["driver_id"]})
            if drv:
                driver_name = drv.get("name", driver_name)
                driver_id = drv.get("id", driver_id)

    logger.info(
        "[HW GPS] bus=%s lat=%.4f lon=%.4f spd=%.1f km/h sats=%d hdop=%.1f",
        target_bus, actual_lat, actual_lon, req.speed, req.satellites, req.hdop
    )

    await process_gps_update(
        bus_id=target_bus,
        driver_id=driver_id,
        driver_name=driver_name,
        lat=actual_lat,
        lon=actual_lon,
        speed=req.speed,
        heading=req.heading,
        passengers=req.passengers
    )

    # Persist extra telemetry fields not in process_gps_update
    if target_bus in live_buses:
        live_buses[target_bus]["satellites"] = req.satellites
        live_buses[target_bus]["hdop"] = req.hdop
        live_buses[target_bus]["hw_source"] = "ESP32"

    return {"status": "ok", "bus_id": target_bus}


# ─────────────────────────────────────────────────────────────
#  RFID TAP — boarding / alighting
# ─────────────────────────────────────────────────────────────
@router.post("/api/hardware/rfid/tap")
async def hardware_rfid_tap(req: HardwareRfidTap, x_device_key: str = Header(default=""), x_api_key: str = Header(default="")):
    """Handle hardware RFID swipe without JWT bearer requirement."""
    await _verify_hw_key(x_device_key, x_api_key)

    target_bus = normalize_bus_id(req.bus_id or req.deviceId or "B07")
    card_id = req.rfid_card or req.uid or ""
    raw_card = card_id.replace(":", "").replace(" ", "").upper() if card_id else ""
    formatted_card = f"{raw_card[0:2]}:{raw_card[2:4]}:{raw_card[4:6]}:{raw_card[6:8]}" if len(raw_card) == 8 else raw_card

    db = db_module.db
    stu = await db.users.find_one({
        "$or": [
            {"rfid_card": card_id},
            {"rfid_card": formatted_card},
            {"rfid_card": raw_card}
        ],
        "is_active": 1
    }, {"_id": 0, "id": 1, "name": 1})
    if not stu:
        logger.warning("[HW RFID] Unknown card tapped: %s on bus %s", card_id, target_bus)
        stu = {"id": f"unk_{card_id}", "name": f"Student ({card_id})"}

    td = today()
    cursor = db.attendance.find(
        {"user_id": stu["id"], "date": td},
        {"_id": 0, "tap_type": 1}
    ).sort([("tap_time", -1)]).limit(1)
    taps = await cursor.to_list(length=1)
    last_tap = taps[0] if taps else None
    tap_type = "exited" if (last_tap and last_tap["tap_type"] == "boarded") else "boarded"

    bus_live = live_buses.get(target_bus)
    is_offline = not bus_live or bus_live.get("status") == "offline"
    if is_offline and tap_type == "boarded":
        raise HTTPException(status_code=400, detail="Bus is offline. Passengers cannot board an offline bus.")

    await db.attendance.insert_one({
        "id": str(uuid.uuid4()), "user_id": stu["id"], "bus_id": target_bus,
        "tap_type": tap_type, "tap_time": now_str(), "stop_name": req.stop_name or "Live Stop",
        "lat": req.lat, "lon": req.lon, "date": td
    })

    logger.info("[HW RFID] %s → %s (%s) on bus %s", card_id, stu["name"], tap_type, target_bus)

    new_pax = 0
    if target_bus in live_buses:
        delta = 1 if tap_type == "boarded" else -1
        live_buses[target_bus]["passengers"] = max(
            0, live_buses[target_bus].get("passengers", 0) + delta
        )
        new_pax = live_buses[target_bus]["passengers"]

    import json
    ws_payload = json.dumps({
        "type": "pax_update",
        "bus_id": target_bus,
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


# ─────────────────────────────────────────────────────────────
#  SOS / BREAKDOWN EMERGENCY (HARDWARE BUTTON)
# ─────────────────────────────────────────────────────────────
@router.post("/api/hardware/sos")
@router.post("/api/hardware/emergency")
@router.post("/api/driver/breakdown")
async def hardware_driver_breakdown(req: HardwareEmergencyReport, x_device_key: str = Header(default=""), x_api_key: str = Header(default="")):
    """Handle breakdown & SOS hardware button alerts from ESP32."""
    await _verify_hw_key(x_device_key, x_api_key)

    target_bus = normalize_bus_id(req.bus_id or req.deviceId or "B07")
    actual_lat = req.lat if req.lat != 0.0 else req.latitude
    actual_lon = req.lon if req.lon != 0.0 else req.longitude
    etype = req.type or req.emergency_type or "SOS Button Pressed"

    logger.warning(
        "[HW SOS] EMERGENCY from bus=%s at lat=%.4f lon=%.4f type='%s'",
        target_bus, actual_lat, actual_lon, etype
    )

    db = db_module.db
    bus = await db.buses.find_one({"id": target_bus})
    bus_number = bus.get("number", target_bus) if bus else target_bus

    eid = "E" + str(uuid.uuid4())[:6]
    emerg_doc = {
        "id": eid,
        "bus_id": target_bus,
        "bus_number": bus_number,
        "driver_name": "Hardware ESP32 Node",
        "driver_phone": "N/A",
        "status": "recommended",
        "buzzer_active": 1,
        "emergency_type": etype,
        "emergency_time": now_str(),
        "date": today(),
        "gps": {"lat": actual_lat, "lon": actual_lon},
        "backup_bus_id": None,
        "timeline": [
            {
                "status": "SOS Button Pressed",
                "ts": now_str(),
                "msg": f"Hardware SOS Panic Button pressed on Bus {bus_number}. Buzzer activated on kit."
            }
        ]
    }

    await db.emergencies.update_one({"id": eid}, {"$set": emerg_doc}, upsert=True)

    await trigger_system_alert(
        "SOS Panic Emergency Alert",
        f"Bus {bus_number} Hardware SOS Panic Button Pressed at Lat: {actual_lat:.4f}, Lon: {actual_lon:.4f}! Immediate assistance requested.",
        alert_type="danger",
        target_bus=target_bus
    )

    import json
    ws_payload = json.dumps({
        "type": "emergency",
        "id": eid,
        "bus_id": target_bus,
        "bus_number": bus_number,
        "emergency_type": etype,
        "buzzer_active": 1
    })
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {
        "status": "ok",
        "message": "Emergency broadcast sent",
        "emergency_id": eid,
        "buzzer_active": True
    }


# ─────────────────────────────────────────────────────────────
#  TRIP BUTTON (START / END)
# ─────────────────────────────────────────────────────────────
@router.post("/api/hardware/trip")
async def hardware_trip_event(req: HardwareTripEvent, x_device_key: str = Header(default=""), x_api_key: str = Header(default="")):
    """Handle hardware trip start / end button events from ESP32."""
    await _verify_hw_key(x_device_key, x_api_key)

    target_bus = normalize_bus_id(req.bus_id or req.deviceId or "B07")
    actual_lat = req.lat if req.lat != 0.0 else req.latitude
    actual_lon = req.lon if req.lon != 0.0 else req.longitude
    event = (req.event or "UPDATE").upper()

    logger.info("[HW TRIP] bus=%s event=%s lat=%.4f lon=%.4f", target_bus, event, actual_lat, actual_lon)

    import json
    ws_payload = json.dumps({
        "type": "trip_event",
        "bus_id": target_bus,
        "event": event,
        "timestamp": now_str()
    })
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(ws_payload)
        except Exception:
            pass

    return {"status": "ok", "bus_id": target_bus, "event": event}

