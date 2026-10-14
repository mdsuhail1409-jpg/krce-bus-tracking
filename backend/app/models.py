import re
from typing import List
from pydantic import BaseModel, field_validator


def _sanitize_text(v: str, max_len: int = 128) -> str:
    """Strip, truncate, and sanitize input string against XSS script tags."""
    if not isinstance(v, str):
        return v
    cleaned = v.strip()
    if len(cleaned) > max_len:
        cleaned = cleaned[:max_len]
    # Check for direct script injection patterns
    if re.search(r"<\s*script", cleaned, re.IGNORECASE):
        raise ValueError("Potential script injection detected")
    return cleaned


class LoginReq(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v):
        cleaned = _sanitize_text(v, 128).lower()
        if not cleaned:
            raise ValueError("Email or identifier is required")
        return cleaned

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        if len(v) > 128:
            raise ValueError("Password exceeds maximum allowed length")
        return v


class RegisterReq(BaseModel):
    name: str
    email: str
    password: str
    phone: str = ""
    role: str
    college_id: str = ""
    rfid_card: str = ""
    requested_bus: str = ""
    parent_child_id: str = ""

    @field_validator("name")
    @classmethod
    def validate_name(cls, v):
        cleaned = _sanitize_text(v, 64)
        if len(cleaned) < 2:
            raise ValueError("Name must be at least 2 characters long")
        return cleaned

    @field_validator("email")
    @classmethod
    def validate_email(cls, v):
        cleaned = _sanitize_text(v, 128).lower()
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", cleaned):
            raise ValueError("Invalid email format")
        return cleaned

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if len(v) > 128:
            raise ValueError("Password exceeds maximum allowed length")
        return v

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v):
        cleaned = _sanitize_text(v, 20)
        if cleaned and not re.match(r"^[0-9+\- ]{7,15}$", cleaned):
            raise ValueError("Invalid phone number format")
        return cleaned

    @field_validator("role")
    @classmethod
    def vr(cls, v):
        if v not in {"student", "staff", "parent"}:
            raise ValueError("Role must be student, staff, or parent")
        return v

    @field_validator("college_id", "rfid_card", "requested_bus", "parent_child_id")
    @classmethod
    def validate_extras(cls, v):
        return _sanitize_text(v, 32) if v else ""


class BusUpsert(BaseModel):
    number: str
    route_name: str
    driver_id: str = ""
    capacity: int = 50
    stops: List[str] = []

    @field_validator("number", "route_name", "driver_id")
    @classmethod
    def sanitize_fields(cls, v):
        return _sanitize_text(v, 64) if v else ""

    @field_validator("capacity")
    @classmethod
    def validate_capacity(cls, v):
        if v < 1 or v > 150:
            raise ValueError("Capacity must be between 1 and 150")
        return v


class AlertCreate(BaseModel):
    title: str
    message: str
    alert_type: str = "info"
    target_role: str = "all"
    target_bus: str = ""

    @field_validator("title")
    @classmethod
    def validate_title(cls, v):
        return _sanitize_text(v, 100)

    @field_validator("message")
    @classmethod
    def validate_message(cls, v):
        return _sanitize_text(v, 500)


class RegAction(BaseModel):
    reg_id: str
    action: str
    bus_id: str = ""
    rfid_card: str = ""
    notes: str = ""
    parent_child_id: str = ""

    @field_validator("reg_id", "action", "bus_id", "rfid_card", "notes", "parent_child_id")
    @classmethod
    def sanitize_reg(cls, v):
        return _sanitize_text(v, 256) if v else ""


class AssignWardReq(BaseModel):
    student_id: str

    @field_validator("student_id")
    @classmethod
    def sanitize_ward(cls, v):
        return _sanitize_text(v, 32)


class RfidTap(BaseModel):
    rfid_card: str
    bus_id: str
    stop_name: str = ""
    lat: float = 0.0
    lon: float = 0.0

    @field_validator("rfid_card")
    @classmethod
    def validate_card(cls, v):
        return _sanitize_text(v, 32)

    @field_validator("bus_id")
    @classmethod
    def validate_bus(cls, v):
        return _sanitize_text(v, 16)

    @field_validator("lat")
    @classmethod
    def validate_lat(cls, v):
        if not (-90.0 <= v <= 90.0):
            raise ValueError("Latitude must be between -90 and 90")
        return v

    @field_validator("lon")
    @classmethod
    def validate_lon(cls, v):
        if not (-180.0 <= v <= 180.0):
            raise ValueError("Longitude must be between -180 and 180")
        return v


class GpsUpdate(BaseModel):
    lat: float
    lon: float
    speed: float = 0.0
    heading: float = 0.0
    passengers: int = 0

    @field_validator("lat")
    @classmethod
    def validate_lat(cls, v):
        if not (-90.0 <= v <= 90.0):
            raise ValueError("Latitude must be between -90 and 90")
        return v

    @field_validator("lon")
    @classmethod
    def validate_lon(cls, v):
        if not (-180.0 <= v <= 180.0):
            raise ValueError("Longitude must be between -180 and 180")
        return v

    @field_validator("speed")
    @classmethod
    def validate_speed(cls, v):
        if not (0.0 <= v <= 160.0):
            raise ValueError("Speed must be between 0 and 160 km/h")
        return v

    @field_validator("heading")
    @classmethod
    def validate_heading(cls, v):
        if not (0.0 <= v <= 360.0):
            raise ValueError("Heading must be between 0 and 360 degrees")
        return v

    @field_validator("passengers")
    @classmethod
    def validate_passengers(cls, v):
        if not (0 <= v <= 120):
            raise ValueError("Passengers must be between 0 and 120")
        return v


class ChangePasswordReq(BaseModel):
    old_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v):
        if len(v) < 8:
            raise ValueError("New password must be at least 8 characters long")
        if len(v) > 128:
            raise ValueError("New password exceeds maximum allowed length")
        return v


class RefreshReq(BaseModel):
    refresh_token: str


class TempBusAssignment(BaseModel):
    temp_bus_id: str
    expiry_hours: int = 12


class BusReassignment(BaseModel):
    bus_id: str
    reason: str = ""


class ForgotPasswordReq(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v):
        cleaned = _sanitize_text(v, 128)
        if not cleaned:
            raise ValueError("Email, phone, or ID is required")
        return cleaned


class ResetPasswordReq(BaseModel):
    email: str
    new_password: str
    otp: str = ""
    phone: str = ""
    college_id: str = ""

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v):
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters long")
        if len(v) > 128:
            raise ValueError("Password exceeds maximum allowed length")
        return v


class PasswordResetRequestCreate(BaseModel):
    name: str
    email: str
    roll_no: str = ""

    @field_validator("name")
    @classmethod
    def validate_name(cls, v):
        cleaned = _sanitize_text(v, 64)
        if len(cleaned) < 2:
            raise ValueError("Name must be at least 2 characters long")
        return cleaned

    @field_validator("email")
    @classmethod
    def validate_email(cls, v):
        cleaned = _sanitize_text(v, 128)
        if not cleaned:
            raise ValueError("Email is required")
        return cleaned


class PasswordResetAdminAction(BaseModel):
    action: str = "approved"  # approved | rejected
    temp_password: str = ""


