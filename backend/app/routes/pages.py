"""
KRCE Bus Tracking System — HTML page routes.
GET / and /admin serve the web frontend templates.
"""

from pathlib import Path
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from app.config import TEMPLATES_DIR

router = APIRouter()

_templates_path = Path(TEMPLATES_DIR)


@router.get("/", response_class=HTMLResponse)
async def root():
    html_file = _templates_path / "index.html"
    return HTMLResponse(content=html_file.read_text(encoding="utf-8"))


@router.get("/admin", response_class=HTMLResponse)
async def admin_page():
    html_file = _templates_path / "admin.html"
    return HTMLResponse(content=html_file.read_text(encoding="utf-8"))
