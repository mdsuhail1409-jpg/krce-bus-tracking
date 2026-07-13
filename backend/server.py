"""
KRCE Bus Tracking System — Cloud Production Backend v4.0
K. Ramakrishnan College of Engineering, Trichy, Tamil Nadu
FastAPI + MongoDB Atlas + WebSocket real-time GPS + OSRM Routing + Geofencing + Safety SOS
"""

import sys
from pathlib import Path
# Add project root to sys.path to resolve database import
_root_dir = str(Path(__file__).parent.parent)
if _root_dir not in sys.path:
    sys.path.append(_root_dir)

import asyncio, hashlib, json, logging, os, time, uuid, csv, io, bcrypt, secrets
import urllib.request
import urllib.parse
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, date
from math import atan2, cos, radians, sin, sqrt
from typing import Dict, List, Optional

import jwt
import sentry_sdk
import uvicorn
from fastapi import (
    Depends, FastAPI, HTTPException, Query, Request,
    WebSocket, WebSocketDisconnect, status
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, StreamingResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.templating import Jinja2Templates
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, field_validator
from sentry_sdk.integrations.fastapi import FastApiIntegration
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
import database.db as db_module

# Load .env file if it exists in the backend directory
_env_path = Path(__file__).parent / ".env"
if _env_path.exists():
    with open(_env_path, "r", encoding="utf-8") as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _key, _val = _line.split("=", 1)
                _key = _key.strip()
                _val = _val.strip().strip('"').strip("'")
                os.environ[_key] = _val

# ═══════════════════════════════════════════════════════════════════
#  SENTRY — optional error monitoring
# ═══════════════════════════════════════════════════════════════════
_sentry_dsn = os.getenv("SENTRY_DSN", "")
if _sentry_dsn:
    sentry_sdk.init(
        dsn=_sentry_dsn,
        integrations=[FastApiIntegration()],
        traces_sample_rate=0.2,
    )

# ═══════════════════════════════════════════════════════════════════
#  CONFIG — all from environment variables, zero hardcoded values
# ═══════════════════════════════════════════════════════════════════
COLLEGE_NAME  = "K. Ramakrishnan College of Engineering"
COLLEGE_SHORT = "KRCE"
COLLEGE_CITY  = "Trichy, Tamil Nadu"
COLLEGE_LAT   = 10.927669
COLLEGE_LON   = 78.7410

SECRET_KEY = os.getenv("JWT_SECRET", "super-secret-key-for-local-dev-mode-32-chars-long")
ALGORITHM   = "HS256"
TOKEN_HOURS = 24
VEHICLE_TTL = 300  # seconds before driver is considered offline

# MongoDB Atlas connection string
MONGO_URI = os.getenv("MONGO_URI", "mock")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME", "krce_bus")

# CORS
_raw_origins = os.getenv("ALLOWED_ORIGINS", "*")
ALLOWED_ORIGINS = [o.strip() for o in _raw_origins.split(",") if o.strip()]

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("KRCE-BUS")

# ═══════════════════════════════════════════════════════════════════
#  APP SETUP
# ═══════════════════════════════════════════════════════════════════
limiter = Limiter(key_func=get_remote_address)

# Middleware and exception handlers configured below app initialization
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "frontend" / "templates"))

# ═══════════════════════════════════════════════════════════════════
#  LIVE STATE — in-memory, per-process
# ═══════════════════════════════════════════════════════════════════
live_buses: Dict[str, dict] = {}   # bus_id → GPS state
ws_pool:    Dict[str, WebSocket] = {}  # user_id → WebSocket
last_seen:  Dict[str, float] = {}  # user_id → unix timestamp
geofence_states: Dict[str, Dict[str, str]] = {}  # bus_id → stop_name → "inside"/"outside"

# MongoDB client — initialized at startup
mongo_client: AsyncIOMotorClient = None
db = None  # motor database handle

# Seed Stop Coordinates Mapping
STOP_COORDS = {
    "KRCE Campus": (10.927669, 78.7410),
    "Samayapuram": (10.9310, 78.8130),
    "Woraiyur Bus Stand": (10.7905, 78.7047),
    "Woraiyur Town": (10.7920, 78.7020),
    "Gandhi Market": (10.8190, 78.6990),
    "Panjappur": (10.7516, 78.6830),
    "Srirangam": (10.8631, 78.6933),
    "Cauvery Bridge": (10.8416, 78.7010),
    "K.K. Nagar": (10.8176, 78.6960),
    "Thuvakudi": (10.8730, 78.7680),
    "Ariyamangalam": (10.8280, 78.7380),
    "Cantonment": (10.8116, 78.6860),
    "Collector Office": (10.8080, 78.6820),
    "Palakarai": (10.8120, 78.6930),
    "Chatram Bus Stand": (10.8096, 78.6964),
    "Central": (10.8050, 78.6840),
    "Junction": (10.8020, 78.6810),
    "Thillai Nagar": (10.8240, 78.6890),
    "Mannarpuram": (10.8182, 78.7030),
    "Rockfort": (10.8300, 78.6970),
    "Chinthamani": (10.8350, 78.7020),
}

# ═══════════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════════
def _hash(pw: str) -> str:
    hashed = bcrypt.hashpw(pw.encode('utf-8'), bcrypt.gensalt())
    return hashed.decode('utf-8')

def _check_hash(pw: str, hashed_pw: str) -> bool:
    return bcrypt.checkpw(pw.encode('utf-8'), hashed_pw.encode('utf-8'))

def haversine(lat1, lon1, lat2, lon2) -> float:
    R = 6_371_000
    φ1, φ2 = radians(lat1), radians(lat2)
    dφ, dλ = radians(lat2 - lat1), radians(lon2 - lon1)
    a = sin(dφ / 2) ** 2 + cos(φ1) * cos(φ2) * sin(dλ / 2) ** 2
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))

def today() -> str:
    return date.today().isoformat()

def now_str() -> str:
    return datetime.utcnow().isoformat()

def _fetch_osrm_sync(url: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "KRCE-BusTrack/4.0"}
    )
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.loads(response.read().decode('utf-8'))

async def fetch_osrm_route(lat1, lon1, lat2, lon2) -> Optional[dict]:
    url = f"http://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson"
    try:
        loop = asyncio.get_event_loop()
        res = await loop.run_in_executor(None, _fetch_osrm_sync, url)
        return res
    except Exception as e:
        logger.error(f"OSRM error: {e}")
        return None

# Database init and mock db classes have been moved to database/db.py

# ═══════════════════════════════════════════════════════════════════
#  AUTH
# ═══════════════════════════════════════════════════════════════════
security = HTTPBearer(auto_error=False)

def make_token(uid: str, name: str, role: str, bus_id: str = "", extra: dict = None, expires_hours: float = TOKEN_HOURS) -> str:
    payload = {
        "sub": uid, "name": name, "role": role, "bus_id": bus_id,
        "exp": datetime.utcnow() + timedelta(hours=expires_hours),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired — please log in again")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")

async def current_user(creds: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> dict:
    if not creds:
        raise HTTPException(401, "Authentication required")
    return verify_token(creds.credentials)

async def admin_only(u=Depends(current_user)):
    if u["role"] not in ("admin", "committee"):
        raise HTTPException(403, "Admin / Committee access only")
    return u

# ═══════════════════════════════════════════════════════════════════
#  PYDANTIC MODELS
# ═══════════════════════════════════════════════════════════════════
class LoginReq(BaseModel):
    email: str
    password: str

class RegisterReq(BaseModel):
    name: str; email: str; password: str; phone: str = ""; role: str
    college_id: str = ""; rfid_card: str = ""; requested_bus: str = ""; parent_child_id: str = ""
    @field_validator("role")
    @classmethod
    def vr(cls, v):
        if v not in {"student","staff","parent"}:
            raise ValueError(f"Role must be student, staff, or parent")
        return v

class BusUpsert(BaseModel):
    number: str; route_name: str; driver_id: str = ""; capacity: int = 50; stops: List[str] = []

class AlertCreate(BaseModel):
    title: str; message: str; alert_type: str = "info"; target_role: str = "all"; target_bus: str = ""

class RegAction(BaseModel):
    reg_id: str; action: str; bus_id: str = ""; rfid_card: str = ""; notes: str = ""

class RfidTap(BaseModel):
    rfid_card: str; bus_id: str; stop_name: str = ""; lat: float = 0.0; lon: float = 0.0

class GpsUpdate(BaseModel):
    lat: float; lon: float; speed: float = 0.0; heading: float = 0.0; passengers: int = 0

class ChangePasswordReq(BaseModel):
    old_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v):
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters long")
        return v

class RefreshReq(BaseModel):
    refresh_token: str

# ═══════════════════════════════════════════════════════════════════
#  STARTUP / SHUTDOWN
# ═══════════════════════════════════════════════════════════════════
@asynccontextmanager
async def lifespan(app: FastAPI):
    global db, mongo_client
    await db_module.init_db()
    db = db_module.db
    mongo_client = db_module.mongo_client
    asyncio.create_task(_stale_cleaner())
    logger.info("KRCE Bus System started")
    yield
    if db_module.mongo_client:
        db_module.mongo_client.close()
    for bus_id, data in live_buses.items():
        save_data = data.copy()
        save_data.pop("route_geometry", None)
        await db.live_bus_positions.update_one(
            {"bus_id": bus_id},
            {"$set": save_data},
            upsert=True
        )
    logger.info("MongoDB connection closed")

app = FastAPI(title="KRCE Bus System", version="4.0.0", docs_url="/api/docs", lifespan=lifespan)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(GZipMiddleware, minimum_size=500)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    allow_credentials=True,
)

async def _stale_cleaner():
    while True:
        await asyncio.sleep(60)
        now = time.time()
        stale = [k for k, v in last_seen.items() if now - v > VEHICLE_TTL]
        for uid in stale:
            last_seen.pop(uid, None)
        for bid, info in live_buses.items():
            drv = info.get("driver_id", "")
            if drv and drv not in last_seen and info.get("status") != "offline":
                info["status"] = "offline"
                await trigger_system_alert(
                    "Driver Offline",
                    f"Driver {info.get('driver_name', 'Unknown')} of Bus {bid} is offline.",
                    alert_type="warning",
                    target_bus=bid
                )

# ═══════════════════════════════════════════════════════════════════
#  GEOFENCING & NOTIFICATION UTILITIES
# ═══════════════════════════════════════════════════════════════════
async def trigger_system_alert(title: str, message: str, alert_type: str = "info", target_bus: str = None):
    aid = str(uuid.uuid4())[:8]
    alert_doc = {
        "id": aid,
        "title": title,
        "message": message,
        "alert_type": alert_type,
        "target_role": "all",
        "target_bus": target_bus,
        "sent_by": "system",
        "sent_at": now_str(),
        "is_resolved": 0
    }
    await db.alerts.insert_one(alert_doc)
    
    payload = json.dumps({
        "type": "alert",
        "id": aid,
        "title": title,
        "message": message,
        "alert_type": alert_type,
        "target_bus": target_bus
    })
    for cid, cws in list(ws_pool.items()):
        try:
            await cws.send_text(payload)
        except Exception:
            pass

async def initialize_route_geometry(bus_id: str, start_lat: float, start_lon: float):
    route_data = await fetch_osrm_route(start_lat, start_lon, COLLEGE_LAT, COLLEGE_LON)
    if route_data and "routes" in route_data:
        routes = route_data["routes"]
        if routes:
            geometry = routes[0].get("geometry", {})
            coordinates = geometry.get("coordinates", []) # list of [lon, lat]
            geom_points = [(c[1], c[0]) for c in coordinates]
            if bus_id in live_buses:
                live_buses[bus_id]["route_geometry"] = geom_points

async def run_geofencing_check(bus_id: str, lat: float, lon: float):
    bus = await db.buses.find_one({"id": bus_id})
    if not bus:
        return
    stops = bus.get("stops", [])
    
    if bus_id not in geofence_states:
        geofence_states[bus_id] = {}
        
    bus_state = geofence_states[bus_id]
    bus_number = bus.get("number", bus_id)
    
    for stop_name in stops:
        coords = STOP_COORDS.get(stop_name)
        if not coords:
            continue
        stop_lat, stop_lon = coords
        d = haversine(lat, lon, stop_lat, stop_lon)
        
        prev_status = bus_state.get(stop_name, "outside")
        
        # Enters geofence (within 150m)
        if d <= 150 and prev_status == "outside":
            bus_state[stop_name] = "inside"
            title = f"Bus Reached {stop_name}" if stop_name != "KRCE Campus" else "Bus Reached College"
            msg = f"Bus {bus_number} has arrived at {stop_name}."
            await trigger_system_alert(title, msg, alert_type="info", target_bus=bus_id)
            
        # Leaves geofence (exceeds 250m)
        elif d > 250 and prev_status == "inside":
            bus_state[stop_name] = "outside"
            title = f"Bus Departed {stop_name}" if stop_name != "KRCE Campus" else "Bus Left College"
            msg = f"Bus {bus_number} has departed from {stop_name}."
            await trigger_system_alert(title, msg, alert_type="info", target_bus=bus_id)

async def run_safety_checks(bus_id: str, lat: float, lon: float, speed: float, now_ts: float):
    bus = await db.buses.find_one({"id": bus_id})
    if not bus:
        return
    bus_number = bus.get("number", bus_id)
    
    # 1. Overspeed Alert (> 60 km/h)
    if speed > 60:
        last_overspeed = live_buses[bus_id].get("last_overspeed_alert", 0)
        if now_ts - last_overspeed > 180:
            live_buses[bus_id]["last_overspeed_alert"] = now_ts
            await trigger_system_alert(
                "Overspeed Alert",
                f"Bus {bus_number} is traveling at an unsafe speed of {speed:.1f} km/h!",
                alert_type="warning",
                target_bus=bus_id
            )
            
    # 2. Idle Detection (> 5 mins)
    if speed <= 1:
        idle_start = live_buses[bus_id].get("idle_start_time")
        if not idle_start:
            live_buses[bus_id]["idle_start_time"] = now_ts
        else:
            if now_ts - idle_start > 300:
                last_idle_alert = live_buses[bus_id].get("last_idle_alert", 0)
                if now_ts - last_idle_alert > 300:
                    live_buses[bus_id]["last_idle_alert"] = now_ts
                    await trigger_system_alert(
                        "Idle Alert",
                        f"Bus {bus_number} has been stationary for more than 5 minutes.",
                        alert_type="warning",
                        target_bus=bus_id
                    )
    else:
        live_buses[bus_id]["idle_start_time"] = None

    # 3. Route Deviation Alert (> 500m away from route coordinates)
    geom_points = live_buses[bus_id].get("route_geometry", [])
    if geom_points:
        min_dist = min(haversine(lat, lon, gp[0], gp[1]) for gp in geom_points)
        if min_dist > 500:
            last_deviation = live_buses[bus_id].get("last_deviation_alert", 0)
            if now_ts - last_deviation > 300:
                live_buses[bus_id]["last_deviation_alert"] = now_ts
                await trigger_system_alert(
                    "Route Deviation Alert",
                    f"Bus {bus_number} has deviated from its scheduled route path!",
                    alert_type="danger",
                    target_bus=bus_id
                )

# Consolidated GPS processing helper
async def process_gps_update(bus_id: str, driver_id: str, driver_name: str, lat: float, lon: float, speed: float, heading: float, passengers: int):
    now_ts = time.time()
    is_first_ping = bus_id not in live_buses
    
    if is_first_ping:
        live_buses[bus_id] = {
            "bus_id": bus_id, "driver_id": driver_id, "driver_name": driver_name,
            "lat": lat, "lon": lon, "speed": speed, "heading": heading,
            "passengers": passengers, "updated_at": now_ts,
            "status": "moving" if speed > 2 else "idle",
            "route_geometry": [],
            "last_active": now_ts
        }
        asyncio.create_task(initialize_route_geometry(bus_id, lat, lon))
    else:
        live_buses[bus_id].update({
            "lat": lat, "lon": lon, "speed": round(speed, 1),
            "heading": round(heading, 1), "passengers": passengers,
            "updated_at": now_ts,
            "status": "moving" if speed > 2 else "idle",
            "last_active": now_ts
        })

    # Log to history collection for playback
    await db.live_bus_positions_history.insert_one({
        "bus_id": bus_id, "lat": lat, "lon": lon, "speed": speed,
        "heading": heading, "passengers": passengers, "ts": now_ts,
        "date": today()
    })

    # Persist live state to DB
    save_data = live_buses[bus_id].copy()
    save_data.pop("route_geometry", None)
    await db.live_bus_positions.update_one(
        {"bus_id": bus_id},
        {"$set": save_data},
        upsert=True
    )
    last_seen[driver_id] = now_ts

    # Perform geofencing and safety checks
    await run_geofencing_check(bus_id, lat, lon)
    await run_safety_checks(bus_id, lat, lon, speed, now_ts)

# ═══════════════════════════════════════════════════════════════════
#  AI STATISTICS PREDICTORS
# ═══════════════════════════════════════════════════════════════════
def predict_eta_delay(bus_id: str, stop_lat: float, stop_lon: float, speed: float) -> dict:
    live = live_buses.get(bus_id)
    if not live:
        return {"eta": "—", "delay": "—", "duration": 0}
    
    d = haversine(live["lat"], live["lon"], stop_lat, stop_lon)
    
    # Speed baseline heuristics (approx 30km/h average in case of stationary state)
    est_speed = max(speed, 8.3)
    if est_speed < 5: 
        est_speed = 8.3
        
    duration_secs = d / est_speed
    
    # Rush Hour Multipliers
    hour = datetime.now().hour
    multiplier = 1.0
    if 8 <= hour <= 9 or 16 <= hour <= 18:
        multiplier = 1.4
    
    predicted_duration = duration_secs * multiplier
    baseline_duration = d / 11.1 # 40 km/h baseline
    
    delay_secs = max(0.0, predicted_duration - baseline_duration)
    delay_mins = int(delay_secs / 60)
    delay_text = f"{delay_mins} mins" if delay_mins > 2 else "No Delay"
    
    eta_mins = max(1, int(predicted_duration / 60))
    return {
        "eta": f"{eta_mins} mins",
        "delay": delay_text,
        "duration": eta_mins,
        "distance": f"{(d / 1000.0):.1f} km"
    }

def predict_student_demand(bus_id: str, stop_name: str) -> int:
    import random
    random.seed(len(stop_name))
    base_demand = random.randint(3, 12)
    day_of_week = datetime.now().weekday()
    if day_of_week in (0, 4): # Mon/Fri peak
        return int(base_demand * 1.3)
    return base_demand

def predict_occupancy(bus_id: str, capacity: int, current_pax: int) -> str:
    fill_ratio = current_pax / max(capacity, 1)
    if fill_ratio > 0.9:
        return "Critical (Near Capacity)"
    elif fill_ratio > 0.7:
        return "High (Few Seats Available)"
    elif fill_ratio > 0.3:
        return "Moderate"
    else:
        return "Low (Many Seats Available)"

# ═══════════════════════════════════════════════════════════════════
#  AUTH ENDPOINTS
# ═══════════════════════════════════════════════════════════════════
@app.get("/healthz")
async def health():
    return {"ok": True, "live_buses": len(live_buses), "ws": len(ws_pool)}

@app.post("/api/auth/login")
@limiter.limit("15/minute")
async def login(req: LoginReq, request: Request):
    u = await db.users.find_one({"email": req.email, "is_active": 1})
    if not u or not _check_hash(req.password, u["password_hash"]):
        raise HTTPException(401, "Invalid email or password")
    
    extra = {
        "college_id": u.get("college_id") or "",
        "rfid_card":  u.get("rfid_card") or "",
        "parent_of":  u.get("parent_of") or "",
        "phone":      u.get("phone") or "",
    }
    
    # Access and Refresh tokens
    token = make_token(u["id"], u["name"], u["role"], u.get("bus_id") or "", extra, expires_hours=1)
    refresh_token = make_token(u["id"], u["name"], u["role"], u.get("bus_id") or "", {"is_refresh": True}, expires_hours=168)
    
    # Audit log
    await db.audit_log.insert_one({
        "user_id": u["id"], "action": "login",
        "ip": request.client.host if request.client else "", "ts": now_str()
    })
    
    # Create session record (Session management & Device verification)
    session_id = str(uuid.uuid4())
    device_info = request.headers.get("User-Agent", "Unknown Device")
    await db.sessions.insert_one({
        "session_id": session_id,
        "user_id": u["id"],
        "device_info": device_info,
        "ip": request.client.host if request.client else "",
        "created_at": now_str(),
        "last_active": now_str(),
        "is_active": 1
    })

    await db.users.update_one({"id": u["id"]}, {"$set": {"last_login": now_str()}})
    
    return {
        "token": token,
        "refresh_token": refresh_token,
        "user_id": u["id"], "name": u["name"], "role": u["role"],
        "bus_id": u.get("bus_id") or "", "college_id": u.get("college_id") or "",
        "rfid_card": u.get("rfid_card") or "", "parent_of": u.get("parent_of") or "",
        "phone": u.get("phone") or "",
    }

@app.post("/api/auth/refresh")
async def refresh_token_ep(req: RefreshReq):
    try:
        payload = verify_token(req.refresh_token)
        if not payload.get("is_refresh"):
            raise HTTPException(401, "Invalid token type")
        uid = payload["sub"]
        u = await db.users.find_one({"id": uid, "is_active": 1})
        if not u:
            raise HTTPException(401, "User not found or inactive")
        extra = {
            "college_id": u.get("college_id") or "",
            "rfid_card":  u.get("rfid_card") or "",
            "parent_of":  u.get("parent_of") or "",
            "phone":      u.get("phone") or "",
        }
        new_token = make_token(u["id"], u["name"], u["role"], u.get("bus_id") or "", extra, expires_hours=1)
        new_refresh = make_token(u["id"], u["name"], u["role"], u.get("bus_id") or "", {"is_refresh": True}, expires_hours=168)
        return {
            "token": new_token,
            "refresh_token": new_refresh
        }
    except Exception as e:
        raise HTTPException(401, f"Failed to refresh token: {str(e)}")

@app.get("/api/my/sessions")
async def get_my_sessions(u=Depends(current_user)):
    cursor = db.sessions.find({"user_id": u["sub"], "is_active": 1}, {"_id": 0})
    return await cursor.to_list(length=None)

@app.post("/api/auth/register")
@limiter.limit("5/minute")
async def register(req: RegisterReq, request: Request):
    if await db.users.find_one({"email": req.email}):
        raise HTTPException(400, "Email already registered")
    rid = str(uuid.uuid4())[:8]
    await db.registrations.insert_one({
        "id": rid, "user_id": "pending_" + rid, "name": req.name,
        "email": req.email, "college_id": req.college_id, "role": req.role,
        "requested_bus": req.requested_bus, "rfid_card": req.rfid_card,
        "phone": req.phone, "status": "pending", "submitted_at": now_str(),
        "reviewed_by": None, "reviewed_at": None, "notes": None
    })
    return {"status": "ok", "message": "Registration submitted. Await admin approval.", "reg_id": rid}

# ═══════════════════════════════════════════════════════════════════
#  ADMIN — STATS
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/stats")
async def admin_stats(u=Depends(admin_only)):
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
#  ADMIN — BUSES
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/buses")
async def admin_buses(u=Depends(admin_only)):
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
        
        # Clean route geometry array from doc before returning
        bus_live = live_buses.get(bus["id"])
        if bus_live:
            bus_live_clean = bus_live.copy()
            bus_live_clean.pop("route_geometry", None)
            bus["live"] = bus_live_clean
        else:
            bus["live"] = None
            
        bus["boarded_today"]= count_map.get(bus["id"], 0)
        result.append(bus)
    return result

@app.post("/api/admin/buses")
async def create_bus(req: BusUpsert, u=Depends(admin_only)):
    bid = "B" + str(uuid.uuid4())[:6]
    await db.buses.insert_one({
        "id": bid, "number": req.number, "route_name": req.route_name,
        "driver_id": req.driver_id or None, "capacity": req.capacity,
        "stops": req.stops, "is_active": 1, "created_at": now_str()
    })
    return {"status": "ok", "bus_id": bid}

@app.put("/api/admin/buses/{bus_id}")
async def update_bus(bus_id: str, req: BusUpsert, u=Depends(admin_only)):
    await db.buses.update_one({"id": bus_id}, {"$set": {
        "number": req.number, "route_name": req.route_name,
        "driver_id": req.driver_id or None, "capacity": req.capacity, "stops": req.stops
    }})
    return {"status": "ok"}

@app.delete("/api/admin/buses/{bus_id}")
async def delete_bus(bus_id: str, u=Depends(admin_only)):
    await db.buses.update_one({"id": bus_id}, {"$set": {"is_active": 0}})
    return {"status": "ok"}

# ═══════════════════════════════════════════════════════════════════
#  ADMIN — USERS
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/users")
async def admin_users(role: str = "", u=Depends(admin_only)):
    query = {"role": role} if role else {}
    fields = {"_id": 0, "password_hash": 0}
    cursor = db.users.find(query, fields).sort([("role", 1), ("name", 1)])
    return await cursor.to_list(length=None)

@app.post("/api/admin/users/{uid}/toggle")
async def toggle_user(uid: str, u=Depends(admin_only)):
    user = await db.users.find_one({"id": uid}, {"_id": 0, "is_active": 1})
    if not user:
        raise HTTPException(404, "User not found")
    new_val = 0 if user["is_active"] else 1
    await db.users.update_one({"id": uid}, {"$set": {"is_active": new_val}})
    return {"status": "ok", "is_active": new_val}

# ═══════════════════════════════════════════════════════════════════
#  ADMIN — DRIVERS
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/drivers")
async def admin_drivers(u=Depends(admin_only)):
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
#  ADMIN — ATTENDANCE & HISTORICAL PLAYBACK
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/attendance")
async def admin_attendance(date_filter: str = "", bus_id: str = "", u=Depends(admin_only)):
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

@app.get("/api/admin/attendance/export")
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

@app.get("/api/admin/playback/{bus_id}")
async def get_trip_playback(bus_id: str, date_filter: str = "", u=Depends(admin_only)):
    td = date_filter or today()
    cursor = db.live_bus_positions_history.find(
        {"bus_id": bus_id, "date": td},
        {"_id": 0, "lat": 1, "lon": 1, "speed": 1, "heading": 1, "ts": 1}
    ).sort("ts", 1)
    history = await cursor.to_list(length=None)
    return history

# ═══════════════════════════════════════════════════════════════════
#  ADMIN — ANALYTICS & REPORTS
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/reports")
async def get_admin_reports(report_type: str, date_filter: str = "", u=Depends(admin_only)):
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
            fuel_liters = distance_km / 4.0 # 4km/L
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
#  ADMIN — REGISTRATIONS
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/registrations")
async def admin_regs(status: str = "pending", u=Depends(admin_only)):
    cursor = db.registrations.find({"status": status}, {"_id": 0}).sort("submitted_at", -1)
    return await cursor.to_list(length=None)

@app.post("/api/admin/registrations/action")
async def reg_action(req: RegAction, u=Depends(admin_only)):
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
#  ADMIN — ALERTS
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/admin/alerts")
async def admin_alerts(u=Depends(admin_only)):
    cursor = db.alerts.find({}, {"_id": 0}).sort("sent_at", -1).limit(50)
    return await cursor.to_list(length=None)

@app.post("/api/admin/alerts")
async def send_alert(req: AlertCreate, u=Depends(admin_only)):
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

@app.post("/api/admin/alerts/{aid}/resolve")
async def resolve_alert(aid: str, u=Depends(admin_only)):
    await db.alerts.update_one({"id": aid}, {"$set": {"is_resolved": 1}})
    return {"status": "ok"}

# ═══════════════════════════════════════════════════════════════════
#  PASSENGER — PUBLIC BUS DATA
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/buses")
async def get_buses(u=Depends(current_user)):
    cursor = db.buses.find({"is_active": 1}, {"_id": 0})
    buses = await cursor.to_list(length=None)
    for bus in buses:
        bus_live = live_buses.get(bus["id"])
        if bus_live:
            bus_live_clean = bus_live.copy()
            bus_live_clean.pop("route_geometry", None)
            bus["live"] = bus_live_clean
        else:
            bus["live"] = None
    return buses

@app.get("/api/buses/{bus_id}/live")
async def bus_live(bus_id: str, u=Depends(current_user)):
    bus_live = live_buses.get(bus_id)
    if bus_live:
        bus_live_clean = bus_live.copy()
        bus_live_clean.pop("route_geometry", None)
        return bus_live_clean
    return {"status": "offline"}

@app.get("/api/buses/{bus_id}/passengers")
async def bus_passengers(bus_id: str, u=Depends(current_user)):
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

@app.get("/api/buses/{bus_id}")
async def get_bus_details(bus_id: str, u=Depends(current_user)):
    bus = await db.buses.find_one({"id": bus_id}, {"_id": 0})
    if not bus:
        raise HTTPException(404, "Bus not found")
    bus_live = live_buses.get(bus_id)
    if bus_live:
        bus_live_clean = bus_live.copy()
        bus_live_clean.pop("route_geometry", None)
        bus["live"] = bus_live_clean
    else:
        bus["live"] = None
    return bus

# ═══════════════════════════════════════════════════════════════════
#  PASSENGER — MY DATA & CONTINUOUS ETA
# ═══════════════════════════════════════════════════════════════════
@app.get("/api/my/attendance")
async def my_attendance(u=Depends(current_user)):
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

@app.get("/api/my/child-attendance")
async def child_attendance(u=Depends(current_user)):
    child_cid = u.get("parent_of", "")
    if not child_cid:
        raise HTTPException(403, "Not linked to any child")
    child = await db.users.find_one({"college_id": child_cid}, {"_id": 0, "id": 1, "name": 1})
    if not child:
        raise HTTPException(404, "Child not found")
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

@app.post("/api/my/change-password")
async def change_password(req: ChangePasswordReq, u=Depends(current_user)):
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

@app.get("/api/alerts")
async def get_alerts(u=Depends(current_user)):
    cursor = db.alerts.find(
        {"is_resolved": 0, "$or": [{"target_role": "all"}, {"target_role": u["role"]}]},
        {"_id": 0}
    ).sort("sent_at", -1).limit(20)
    return await cursor.to_list(length=None)

@app.get("/api/my/eta")
async def get_my_eta(u=Depends(current_user)):
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

# ═══════════════════════════════════════════════════════════════════
#  RFID TAP — called by hardware or mobile driver app
# ═══════════════════════════════════════════════════════════════════
@app.post("/api/rfid/tap")
async def rfid_tap(req: RfidTap, u=Depends(current_user)):
    stu = await db.users.find_one({"rfid_card": req.rfid_card, "is_active": 1}, {"_id": 0, "id": 1, "name": 1})
    if not stu:
        raise HTTPException(404, "RFID card not registered")

    td = today()
    last_tap = await db.attendance.find_one(
        {"user_id": stu["id"], "date": td},
        {"_id": 0, "tap_type": 1},
        sort=[("tap_time", -1)]
    )
    tap_type = "exited" if (last_tap and last_tap["tap_type"] == "boarded") else "boarded"

    await db.attendance.insert_one({
        "id": str(uuid.uuid4()), "user_id": stu["id"], "bus_id": req.bus_id,
        "tap_type": tap_type, "tap_time": now_str(), "stop_name": req.stop_name,
        "lat": req.lat, "lon": req.lon, "date": td
    })

    if req.bus_id in live_buses:
        delta = 1 if tap_type == "boarded" else -1
        live_buses[req.bus_id]["passengers"] = max(
            0, live_buses[req.bus_id].get("passengers", 0) + delta
        )
    return {"status": "ok", "tap_type": tap_type, "student_name": stu["name"]}

# ═══════════════════════════════════════════════════════════════════
#  DRIVER ENDPOINTS
# ═══════════════════════════════════════════════════════════════════
@app.post("/api/driver/gps")
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

@app.post("/api/driver/emergency")
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

# ═══════════════════════════════════════════════════════════════════
#  WEBSOCKET — real-time GPS push + alert broadcast
# ═══════════════════════════════════════════════════════════════════
@app.websocket("/ws")
async def websocket_ep(ws: WebSocket, token: str = Query(...)):
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

# ═══════════════════════════════════════════════════════════════════
#  HTML ROUTES
# ═══════════════════════════════════════════════════════════════════
@app.get("/", response_class=HTMLResponse)
async def root(req: Request):
    return templates.TemplateResponse("index.html", {"request": req})

@app.get("/admin", response_class=HTMLResponse)
async def admin_page(req: Request):
    return templates.TemplateResponse("admin.html", {"request": req})

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("server:app", host="0.0.0.0", port=port, log_level="info")
