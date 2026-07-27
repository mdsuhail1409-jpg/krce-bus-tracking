"""
KRCE Bus Tracking System — WebSocket route.
WS /ws?token={jwt}
"""

import asyncio
import json
import time

from fastapi import WebSocket, WebSocketDisconnect, Query, HTTPException

from app.auth import verify_token
from app.config import COLLEGE_LAT, COLLEGE_LON, logger
from app.state import live_buses, ws_pool, last_seen
from app.gps import process_gps_update, initialize_route_geometry
from app import database as db_module


async def websocket_ep(ws: WebSocket, token: str = Query(...)):
    """WebSocket endpoint for real-time GPS push + alert broadcast."""
    try:
        payload = verify_token(token)
    except HTTPException:
        await ws.close(code=1008)
        return

    uid    = payload["sub"]
    role   = payload["role"]
    name   = payload["name"]
    bus_id = payload.get("bus_id", "")

    await ws.accept()
    ws_pool[uid] = ws
    last_seen[uid] = time.time()

    db = db_module.db

    if role == "driver" and bus_id:
        last_pos = await db.live_bus_positions.find_one({"bus_id": bus_id})
        if last_pos:
            live_buses[bus_id] = {
                "bus_id": bus_id, "driver_id": uid, "driver_name": name,
                "lat": last_pos["lat"], "lon": last_pos["lon"],
                "speed": last_pos["speed"], "heading": last_pos["heading"], "passengers": last_pos["passengers"],
                "updated_at": last_pos["updated_at"], "status": last_pos["status"],
                "route_geometry": [],
                "last_active": time.time()
            }
            asyncio.create_task(initialize_route_geometry(bus_id, last_pos["lat"], last_pos["lon"]))
        else:
            live_buses[bus_id] = {
                "bus_id": bus_id, "driver_id": uid, "driver_name": name,
                "lat": COLLEGE_LAT, "lon": COLLEGE_LON,
                "speed": 0, "heading": 0, "passengers": 0,
                "updated_at": time.time(), "status": "idle",
                "route_geometry": [],
                "last_active": time.time()
            }
            asyncio.create_task(initialize_route_geometry(bus_id, COLLEGE_LAT, COLLEGE_LON))

    logger.info("WS+ %s (%s)", uid, role)

    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            mtype = msg.get("type")

            # Driver pushes GPS
            if mtype == "gps" and role == "driver" and bus_id:
                lat = float(msg.get("lat", 0))
                lon = float(msg.get("lon", 0))
                if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                    continue
                spd  = float(msg.get("speed", 0))
                head = float(msg.get("heading", 0))
                pax  = int(msg.get("passengers", live_buses.get(bus_id, {}).get("passengers", 0)))

                await process_gps_update(
                    bus_id=bus_id,
                    driver_id=uid,
                    driver_name=name,
                    lat=lat,
                    lon=lon,
                    speed=spd,
                    heading=head,
                    passengers=pax
                )

                # Fan-out updates to connected clients in real time
                gps_payload = json.dumps({
                    "type": "gps_update", "bus_id": bus_id,
                    "lat": lat, "lon": lon,
                    "speed": round(spd, 1), "heading": round(head, 1),
                    "passengers": pax,
                    "status": "moving" if spd > 2 else "idle",
                })
                for cid, cws in list(ws_pool.items()):
                    if cid != uid:
                        try:
                            await cws.send_text(gps_payload)
                        except Exception:
                            pass

            elif mtype == "ping":
                await ws.send_text(json.dumps({"type": "pong", "ts": time.time()}))
                last_seen[uid] = time.time()

    except WebSocketDisconnect:
        logger.info("WS- %s (%s)", uid, role)
    except Exception as e:
        logger.warning("WS err %s: %s", uid, e)
    finally:
        ws_pool.pop(uid, None)
        last_seen.pop(uid, None)
        if role == "driver" and bus_id and bus_id in live_buses:
            live_buses[bus_id]["status"] = "offline"
            await db.live_bus_positions.update_one(
                {"bus_id": bus_id},
                {"$set": {"status": "offline", "updated_at": time.time()}}
            )
