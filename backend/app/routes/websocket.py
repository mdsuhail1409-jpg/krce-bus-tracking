"""
KRCE Bus Tracking System — WebSocket route.
WS /ws?token={jwt}
"""

import asyncio
import json
import time

from fastapi import WebSocket, WebSocketDisconnect, Query, HTTPException

from datetime import datetime
from app.auth import verify_token
from app.config import COLLEGE_LAT, COLLEGE_LON, STOP_COORDS, logger
from app.state import live_buses, ws_pool, last_seen
from app.gps import process_gps_update, initialize_route_geometry
from app.utils import IST
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
        bus = await db.buses.find_one({"id": bus_id})
        stops = bus.get("stops", []) if bus else []
        current_hour = datetime.now(IST).hour
        default_dir = "reverse" if current_hour < 12 else "forward"
        dest_stop = stops[0] if default_dir == "reverse" else (stops[-1] if stops else "KRCE Campus")
        dest_coord = STOP_COORDS.get(dest_stop, (COLLEGE_LAT, COLLEGE_LON))

        last_pos = await db.live_bus_positions.find_one({"bus_id": bus_id})
        if last_pos:
            start_lat = last_pos["lat"]
            start_lon = last_pos["lon"]
            spd = last_pos.get("speed", 0)
            hdg = last_pos.get("heading", 0)
            pax = last_pos.get("passengers", 0)
            status = "moving" if spd > 2 else "idle"
        else:
            start_lat = COLLEGE_LAT
            start_lon = COLLEGE_LON
            spd = 0
            hdg = 0
            pax = 0
            status = "idle"

        live_buses[bus_id] = {
            "bus_id": bus_id, "driver_id": uid, "driver_name": name,
            "lat": start_lat, "lon": start_lon,
            "speed": spd, "heading": hdg, "passengers": pax,
            "updated_at": time.time(),
            "status": status,
            "route_geometry": [],
            "last_active": time.time(),
            "direction": default_dir,
            "destination_stop": dest_stop,
            "destination_lat": dest_coord[0],
            "destination_lon": dest_coord[1],
            "remaining_stops": stops if default_dir == "forward" else (stops[::-1] if stops else [])
        }
        asyncio.create_task(initialize_route_geometry(bus_id, start_lat, start_lon, dest_coord[0], dest_coord[1]))

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
