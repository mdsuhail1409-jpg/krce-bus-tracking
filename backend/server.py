"""
KRCE Bus Tracking System — Entry Point
Thin server module that creates the FastAPI app and runs uvicorn.
All logic lives in the app/ package.
"""

import os
import uvicorn
from app import create_app

app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("server:app", host="0.0.0.0", port=port, log_level="info")
