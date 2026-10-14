"""
KRCE Bus Tracking System — FastAPI Application Factory.
Creates and configures the FastAPI app with all middleware, routes, and lifecycle events.
"""

import asyncio
from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from sentry_sdk.integrations.fastapi import FastApiIntegration
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import ALLOWED_ORIGINS, SENTRY_DSN, logger
from app.state import live_buses
from app import database as db_module
from app.gps import stale_cleaner
from app.routes import all_routers
from app.routes.websocket import websocket_ep


# ═══════════════════════════════════════════════════════════════════
#  SENTRY (optional error monitoring)
# ═══════════════════════════════════════════════════════════════════
if SENTRY_DSN:
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[FastApiIntegration()],
        traces_sample_rate=0.2,
    )


# ═══════════════════════════════════════════════════════════════════
#  LIFESPAN — startup and shutdown logic
# ═══════════════════════════════════════════════════════════════════
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await db_module.init_db()
    asyncio.create_task(stale_cleaner())
    logger.info("KRCE Bus System started")
    yield
    # Shutdown
    if db_module.mongo_client:
        db_module.mongo_client.close()
    db = db_module.db
    for bus_id, data in live_buses.items():
        save_data = data.copy()
        save_data.pop("route_geometry", None)
        await db.live_bus_positions.update_one(
            {"bus_id": bus_id},
            {"$set": save_data},
            upsert=True
        )
    logger.info("MongoDB connection closed")


# ═══════════════════════════════════════════════════════════════════
#  APP CREATION
# ═══════════════════════════════════════════════════════════════════
def create_app() -> FastAPI:
    app = FastAPI(
        title="KRCE Bus System",
        version="4.0.0",
        docs_url="/api/docs",
        lifespan=lifespan
    )

    # Rate limiter
    limiter = Limiter(key_func=get_remote_address)
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # Middleware
    app.add_middleware(GZipMiddleware, minimum_size=500)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Device-Key", "X-API-Key"],
        allow_credentials=True,
    )

    # Security Headers Middleware
    @app.middleware("http")
    async def security_headers_middleware(request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://maps.googleapis.com; "
            "style-src 'self' 'unsafe-inline' https://unpkg.com https://fonts.googleapis.com https://cdnjs.cloudflare.com; "
            "font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com; "
            "img-src 'self' data: blob: https://*.tile.openstreetmap.org https://unpkg.com https://*.googleapis.com https://*.gstatic.com; "
            "connect-src 'self' ws: wss: https:; "
            "frame-ancestors 'self';"
        )
        response.headers["Permissions-Policy"] = "geolocation=(self), camera=(), microphone=()"
        if "server" in response.headers:
            del response.headers["server"]
        return response

    # Health check (registered before routers)
    @app.get("/healthz")
    async def health():
        from app.state import ws_pool
        return {"ok": True, "live_buses": len(live_buses), "ws": len(ws_pool)}

    # Register all REST API routers
    for r in all_routers:
        app.include_router(r)

    # Register WebSocket endpoint (must be on app directly, not via APIRouter)
    app.websocket("/ws")(websocket_ep)

    return app
