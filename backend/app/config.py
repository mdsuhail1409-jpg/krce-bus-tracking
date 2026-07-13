"""
KRCE Bus Tracking System — Configuration Module
All environment variables and constants centralized here.
"""

import os
import logging
from pathlib import Path
from typing import List

# Load .env file if it exists in the backend directory
_env_path = Path(__file__).parent.parent / ".env"
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
#  ENVIRONMENT DETECTION
# ═══════════════════════════════════════════════════════════════════
IS_RENDER = bool(os.getenv("RENDER"))
ENVIRONMENT = os.getenv("ENVIRONMENT", "production" if IS_RENDER else "development")

# ═══════════════════════════════════════════════════════════════════
#  COLLEGE CONSTANTS
# ═══════════════════════════════════════════════════════════════════
COLLEGE_NAME  = "K. Ramakrishnan College of Engineering"
COLLEGE_SHORT = "KRCE"
COLLEGE_CITY  = "Trichy, Tamil Nadu"
COLLEGE_LAT   = 10.927669
COLLEGE_LON   = 78.7410

# ═══════════════════════════════════════════════════════════════════
#  JWT & AUTH
# ═══════════════════════════════════════════════════════════════════
SECRET_KEY = os.getenv("JWT_SECRET", "super-secret-key-for-local-dev-mode-32-chars-long")
ALGORITHM  = "HS256"
TOKEN_HOURS = 24

if IS_RENDER and (not SECRET_KEY or len(SECRET_KEY) < 32):
    raise RuntimeError("JWT_SECRET must be set and at least 32 characters in production")

# ═══════════════════════════════════════════════════════════════════
#  MONGODB
# ═══════════════════════════════════════════════════════════════════
MONGO_URI = os.getenv("MONGO_URI", "mock")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME", "krce_bus")

# ═══════════════════════════════════════════════════════════════════
#  CORS
# ═══════════════════════════════════════════════════════════════════
_raw_origins = os.getenv("ALLOWED_ORIGINS", "*")
ALLOWED_ORIGINS: List[str] = [o.strip() for o in _raw_origins.split(",") if o.strip()]

# ═══════════════════════════════════════════════════════════════════
#  SENTRY (optional)
# ═══════════════════════════════════════════════════════════════════
SENTRY_DSN = os.getenv("SENTRY_DSN", "")

# ═══════════════════════════════════════════════════════════════════
#  TIMING
# ═══════════════════════════════════════════════════════════════════
VEHICLE_TTL = 300  # seconds before driver is considered offline

# ═══════════════════════════════════════════════════════════════════
#  LOGGING
# ═══════════════════════════════════════════════════════════════════
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("KRCE-BUS")

# ═══════════════════════════════════════════════════════════════════
#  STOP COORDINATES
# ═══════════════════════════════════════════════════════════════════
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
#  TEMPLATE DIRECTORY
# ═══════════════════════════════════════════════════════════════════
TEMPLATES_DIR = str(Path(__file__).parent.parent / "templates")
