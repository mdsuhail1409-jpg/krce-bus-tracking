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
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
        allow_credentials=True,
    )

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
