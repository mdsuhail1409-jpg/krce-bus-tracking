"""
KRCE Bus Tracking System — Driver routes.
POST /api/driver/gps, /api/driver/emergency
"""

from fastapi import APIRouter, Depends, HTTPException, Request

from app.auth import current_user
from app.models import GpsUpdate
from app.gps import process_gps_update, trigger_system_alert

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
router = APIRouter()


@router.post("/api/driver/gps")
@limiter.limit("30/minute")
async def driver_gps(req: GpsUpdate, request: Request, u=Depends(current_user)):
    if u["role"] != "driver":
        raise HTTPException(403, "Drivers only")
    bus_id = u.get("bus_id", "")
    if not bus_id:
        raise HTTPException(400, "No bus assigned to this driver")
    if not (-90 <= req.lat <= 90 and -180 <= req.lon <= 180):
        raise HTTPException(422, "Invalid coordinates")

    await process_gps_update(
        bus_id=bus_id,
        driver_id=u["sub"],
        driver_name=u["name"],
        lat=req.lat,
        lon=req.lon,
        speed=req.speed,
        heading=req.heading,
        passengers=req.passengers
    )
    return {"status": "ok"}


@router.post("/api/driver/emergency")
async def driver_emergency(u=Depends(current_user)):
    if u["role"] != "driver":
        raise HTTPException(403, "Drivers only")
    bus_id = u.get("bus_id")
    if not bus_id:
        raise HTTPException(400, "No bus assigned to this driver")

    await trigger_system_alert(
        "SOS Panic Emergency Alert",
        f"Bus {bus_id} (Driver {u['name']}) has triggered a panic emergency signal! Immediate security assistance required.",
        alert_type="danger",
        target_bus=bus_id
    )
    return {"status": "ok"}
