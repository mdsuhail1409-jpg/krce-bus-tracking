"""
KRCE Bus Tracking System — Route module aggregation.
"""

from fastapi import APIRouter
from app.routes.auth import router as auth_router
from app.routes.admin import router as admin_router
from app.routes.buses import router as buses_router
from app.routes.user import router as user_router
from app.routes.driver import router as driver_router
from app.routes.rfid import router as rfid_router
from app.routes.pages import router as pages_router
from app.routes.emergencies import router as emergencies_router

# WebSocket is registered directly on the app (not via APIRouter)
# See app/__init__.py for websocket registration

all_routers = [
    auth_router,
    admin_router,
    buses_router,
    user_router,
    driver_router,
    rfid_router,
    pages_router,
    emergencies_router,
]
