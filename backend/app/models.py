"""
KRCE Bus Tracking System — Pydantic request/response models.
"""

from typing import List
from pydantic import BaseModel, field_validator


class LoginReq(BaseModel):
    email: str
    password: str


class RegisterReq(BaseModel):
    name: str; email: str; password: str; phone: str = ""; role: str
    college_id: str = ""; rfid_card: str = ""; requested_bus: str = ""; parent_child_id: str = ""

    @field_validator("role")
    @classmethod
    def vr(cls, v):
        if v not in {"student", "staff", "parent"}:
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
