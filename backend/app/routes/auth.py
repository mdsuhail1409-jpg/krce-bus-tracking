"""
KRCE Bus Tracking System — Auth routes.
POST /api/auth/login, /api/auth/register, /api/auth/refresh
GET  /api/my/sessions
"""

import uuid
import random
from fastapi import APIRouter, HTTPException, Request, Depends

from app.auth import _hash, _check_hash, make_token, verify_token, current_user
from app.models import LoginReq, RegisterReq, RefreshReq, ForgotPasswordReq, ResetPasswordReq, PasswordResetRequestCreate
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
    clean_email = req.email.strip().lower()
    queries = [
        {"email": clean_email},
        {"email": req.email.strip()},
        {"phone": req.email.strip()},
        {"id": req.email.strip()}
    ]
    if clean_email in ["driver7@krce.ac.in", "driver07@krce.ac.in", "bus7@krce.ac.in", "bus07@krce.ac.in", "driver7"]:
        queries.extend([{"id": "drv07"}, {"email": "ganesh@krce.ac.in"}])

    u = await db.users.find_one({"$or": queries, "is_active": 1})
    if not u or not _check_hash(req.password, u["password_hash"]):
        raise HTTPException(401, "Invalid email or password")

    bus_id = u.get("bus_id") or ""
    parent_of = u.get("parent_of") or ""
    if u.get("role") == "parent" and parent_of and not bus_id:
        child = await db.users.find_one(
            {"role": "student", "$or": [{"college_id": parent_of}, {"id": parent_of}]},
            {"_id": 0, "bus_id": 1}
        )
        if child and child.get("bus_id"):
            bus_id = child["bus_id"]
            u["bus_id"] = bus_id
            await db.users.update_one({"id": u["id"]}, {"$set": {"bus_id": bus_id}})

    extra = {
        "college_id": u.get("college_id") or "",
        "rfid_card":  u.get("rfid_card") or "",
        "parent_of":  parent_of,
        "phone":      u.get("phone") or "",
    }

    # Access and Refresh tokens
    token = make_token(u["id"], u["name"], u["role"], bus_id, extra, expires_hours=1)
    refresh_token = make_token(u["id"], u["name"], u["role"], bus_id, {"is_refresh": True}, expires_hours=168)

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


@router.post("/api/auth/forgot-password")
@limiter.limit("10/minute")
async def forgot_password(req: ForgotPasswordReq, request: Request):
    db = db_module.db
    ident = req.email.strip()
    clean_ident = ident.lower()
    queries = [
        {"email": clean_ident},
        {"email": ident},
        {"phone": ident},
        {"college_id": ident},
        {"college_id": clean_ident},
        {"id": ident}
    ]
    u = await db.users.find_one({"$or": queries, "is_active": 1})
    if not u:
        reg = await db.registrations.find_one({"$or": queries, "status": "approved"})
        if reg:
            u = await db.users.find_one({"email": reg.get("email"), "is_active": 1})

    if not u:
        raise HTTPException(404, "No active account found for that email, phone, or ID")

    otp = f"{random.randint(100000, 999999)}"

    # Save to password_resets collection
    await db.password_resets.delete_many({"user_id": u["id"]})
    await db.password_resets.insert_one({
        "user_id": u["id"],
        "email": u.get("email", ""),
        "phone": u.get("phone", ""),
        "otp": otp,
        "created_at": now_str(),
    })

    email_str = u.get("email") or ""
    masked_email = ""
    if "@" in email_str:
        parts = email_str.split("@", 1)
        user_p = parts[0]
        masked_email = f"{user_p[0]}***{user_p[-1] if len(user_p) > 1 else ''}@{parts[1]}"

    phone_str = u.get("phone") or ""
    masked_phone = f"******{phone_str[-4:]}" if len(phone_str) >= 4 else phone_str

    return {
        "status": "ok",
        "message": f"Verification code generated for {u.get('name')}",
        "otp": otp,
        "user_id": u["id"],
        "name": u.get("name"),
        "role": u.get("role"),
        "email": u.get("email"),
        "masked_email": masked_email,
        "masked_phone": masked_phone,
    }


@router.post("/api/auth/reset-password")
@limiter.limit("10/minute")
async def reset_password(req: ResetPasswordReq, request: Request):
    db = db_module.db
    ident = req.email.strip()
    clean_ident = ident.lower()
    queries = [
        {"email": clean_ident},
        {"email": ident},
        {"phone": ident},
        {"college_id": ident},
        {"id": ident}
    ]
    u = await db.users.find_one({"$or": queries, "is_active": 1})
    if not u:
        raise HTTPException(404, "User account not found")

    is_verified = False

    # 1. Verify via OTP
    if req.otp and req.otp.strip():
        rec = await db.password_resets.find_one({
            "user_id": u["id"],
            "otp": req.otp.strip()
        })
        if rec:
            is_verified = True

    # 2. Verify via Phone match
    if not is_verified and req.phone and req.phone.strip():
        user_phone = (u.get("phone") or "").strip()
        if user_phone and user_phone == req.phone.strip():
            is_verified = True

    # 3. Verify via College ID match
    if not is_verified and req.college_id and req.college_id.strip():
        user_cid = (u.get("college_id") or "").strip()
        if user_cid and user_cid.upper() == req.college_id.strip().upper():
            is_verified = True

    if not is_verified:
        raise HTTPException(400, "Invalid verification code or security details")

    # Update password
    new_hash = _hash(req.new_password)
    await db.users.update_one({"id": u["id"]}, {"$set": {"password_hash": new_hash}})
    await db.password_resets.delete_many({"user_id": u["id"]})

    # Log action
    await db.audit_log.insert_one({
        "user_id": u["id"],
        "action": "password_reset",
        "ip": request.client.host if request.client else "",
        "ts": now_str()
    })

    return {
        "status": "ok",
        "message": f"Password reset successfully for {u.get('name')}. Please log in with your new password.",
        "email": u.get("email")
    }


@router.post("/api/auth/password-reset-request")
@limiter.limit("5/minute")
async def submit_password_reset_request(req: PasswordResetRequestCreate, request: Request):
    db = db_module.db
    email_clean = req.email.strip().lower()
    roll_clean = req.roll_no.strip()

    queries = [
        {"email": email_clean},
        {"email": req.email.strip()}
    ]
    if roll_clean:
        queries.extend([
            {"college_id": roll_clean},
            {"college_id": roll_clean.upper()}
        ])

    u = await db.users.find_one({"$or": queries, "is_active": 1})
    if not u:
        # Check approved registrations as well
        reg = await db.registrations.find_one({"$or": queries, "status": "approved"})
        if reg:
            u = await db.users.find_one({"email": reg.get("email"), "is_active": 1})

    if not u:
        raise HTTPException(404, "No matching account found with the provided details.")

    # Check if a pending request already exists
    existing = await db.password_reset_requests.find_one({
        "user_id": u["id"],
        "status": "pending"
    })
    if existing:
        return {
            "status": "ok",
            "message": "A password reset request is already pending Admin review. Please await Admin approval.",
            "request_id": existing["id"],
            "user_name": u.get("name"),
            "role": u.get("role")
        }

    rid = str(uuid.uuid4())[:8]
    await db.password_reset_requests.insert_one({
        "id": rid,
        "user_id": u["id"],
        "name": req.name.strip() or u.get("name"),
        "email": u.get("email", email_clean),
        "roll_no": roll_clean or u.get("college_id", ""),
        "role": u.get("role", "student"),
        "bus_id": u.get("bus_id", ""),
        "phone": u.get("phone", ""),
        "status": "pending",
        "temp_password": None,
        "requested_at": now_str(),
        "reviewed_by": None,
        "reviewed_at": None,
    })

    return {
        "status": "ok",
        "message": f"Password reset request submitted for {u.get('name')}. The Admin has been notified.",
        "request_id": rid,
        "user_name": u.get("name"),
        "role": u.get("role")
    }


