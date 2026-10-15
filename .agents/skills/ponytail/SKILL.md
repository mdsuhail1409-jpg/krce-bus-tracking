---
name: ponytail
description: >-
  Background watchdog, daemon process supervisor, and continuous health monitor.
  Maintains live dev servers, monitors file changes, and alerts on regression or service failure.
---

# Ponytail — Daemon & Watchdog Supervisor Protocol

Ponytail provides continuous supervision over background dev tasks (FastAPI backend, Flutter ADB stream, and WebSocket listeners) so developers and agents don't have to constantly babysit running processes.

---

## Capabilities & Responsibilities

1. **Daemon Management**:
   - Spawns and supervises background support servers without blocking the main workflow:
     - Local Backend: `uvicorn server:app --reload --port 8000`
     - Mobile Device Stream: ADB connection to attached device (`cmijhmzt6pkvws7p`)
2. **Watchdog Health Pings**:
   - Validates that background daemons haven't crashed:
     - Check: `http://localhost:8000/healthz`
     - Cloud Check: `https://krce-bus-tracking.onrender.com/healthz`
3. **Auto-Recovery**:
   - If a daemon fails or exits prematurely:
     - Inspect the last 20 lines of the task log.
     - Automatically revive the daemon with appropriate fallback flags.
