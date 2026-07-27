"""
KRCE Bus Tracking System — RFID routes.
POST /api/rfid/tap
"""

import uuid
from fastapi import APIRouter, Depends, HTTPException

from app.auth import current_user
from app.models import RfidTap
from app.state import live_buses
from app.utils import today, now_str
from app import database as db_module

router = APIRouter()


@router.post("/api/rfid/tap")
async def rfid_tap(req: RfidTap):
    db = db_module.db
    stu = await db.users.find_one({"rfid_card": req.rfid_card, "is_active": 1}, {"_id": 0, "id": 1, "name": 1})
    if not stu:
        stu = {"id": f"card_{req.rfid_card}", "name": f"Card #{req.rfid_card}"}

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
        "tap_type": tap_type, "tap_time": now_str(), "stop_name": req.stop_name,
        "lat": req.lat, "lon": req.lon, "date": td
    })

    new_pax = 0
    if req.bus_id in live_buses:
        delta = 1 if tap_type == "boarded" else -1
        live_buses[req.bus_id]["passengers"] = max(
            0, live_buses[req.bus_id].get("passengers", 0) + delta
        )
        new_pax = live_buses[req.bus_id]["passengers"]

    from app.state import ws_pool
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
