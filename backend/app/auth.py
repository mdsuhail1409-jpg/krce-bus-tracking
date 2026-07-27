"""
KRCE Bus Tracking System — Authentication & JWT utilities.
"""

from datetime import datetime, timedelta
from typing import Optional

import bcrypt
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.config import SECRET_KEY, ALGORITHM, TOKEN_HOURS

security = HTTPBearer(auto_error=False)


def _hash(pw: str) -> str:
    """Hash a password with bcrypt."""
    hashed = bcrypt.hashpw(pw.encode('utf-8'), bcrypt.gensalt())
    return hashed.decode('utf-8')


def _check_hash(pw: str, hashed_pw: str) -> bool:
    """Verify a password against its bcrypt hash."""
    return bcrypt.checkpw(pw.encode('utf-8'), hashed_pw.encode('utf-8'))


def make_token(uid: str, name: str, role: str, bus_id: str = "", extra: dict = None, expires_hours: float = TOKEN_HOURS) -> str:
    """Create a JWT access or refresh token."""
    payload = {
        "sub": uid, "name": name, "role": role, "bus_id": bus_id,
        "exp": datetime.utcnow() + timedelta(hours=expires_hours),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_token(token: str) -> dict:
    """Decode and verify a JWT token."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired — please log in again")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")


async def current_user(creds: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> dict:
    """FastAPI dependency — extract and verify current user from Bearer token."""
    if not creds:
        raise HTTPException(401, "Authentication required")
    return verify_token(creds.credentials)


async def admin_only(u=Depends(current_user)):
    """FastAPI dependency — restrict to admin/committee roles."""
    if u["role"] not in ("admin", "committee"):
        raise HTTPException(403, "Admin / Committee access only")
    return u
