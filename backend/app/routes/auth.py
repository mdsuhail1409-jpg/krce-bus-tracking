"""
KRCE Bus Tracking System — Auth routes.
POST /api/auth/login, /api/auth/register, /api/auth/refresh
GET  /api/my/sessions
"""

import uuid
from fastapi import APIRouter, HTTPException, Request, Depends

from app.auth import _hash, _check_hash, make_token, verify_token, current_user
from app.models import LoginReq, RegisterReq, RefreshReq
from app.utils import now_str
from app import database as db_module

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
router = APIRouter()


@router.post("/api/auth/login")
@limiter.limit("15/minute")
async def login(req: LoginReq, request: Request):
    db = db_module.db
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

    # Create session record
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


@router.post("/api/auth/refresh")
async def refresh_token_ep(req: RefreshReq):
    db = db_module.db
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


@router.post("/api/auth/register")
@limiter.limit("5/minute")
async def register(req: RegisterReq, request: Request):
    db = db_module.db
    if await db.users.find_one({"email": req.email}):
        raise HTTPException(400, "Email already registered")
    rid = str(uuid.uuid4())[:8]
    pw_hash = _hash(req.password)
    await db.registrations.insert_one({
        "id": rid, "user_id": "pending_" + rid, "name": req.name,
        "email": req.email, "college_id": req.college_id, "role": req.role,
        "requested_bus": req.requested_bus, "rfid_card": req.rfid_card,
        "parent_child_id": req.parent_child_id, "password_hash": pw_hash,
        "phone": req.phone, "status": "pending", "submitted_at": now_str(),
        "reviewed_by": None, "reviewed_at": None, "notes": None
    })
    return {"status": "ok", "message": "Registration submitted. Await admin approval.", "reg_id": rid}


@router.get("/api/my/sessions")
async def get_my_sessions(u=Depends(current_user)):
    db = db_module.db
    cursor = db.sessions.find({"user_id": u["sub"], "is_active": 1}, {"_id": 0})
    return await cursor.to_list(length=None)
