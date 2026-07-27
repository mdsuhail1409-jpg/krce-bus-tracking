import urllib.request
import urllib.error
import json

BASE = "https://krce-bus-tracking.onrender.com"

# Test all key endpoints
tests = [
    ("GET", "/healthz", None),
    ("GET", "/api/buses", None),           # expects 401 (no token) = endpoint exists
    ("GET", "/api/my/attendance", None),   # expects 401 = endpoint exists
    ("GET", "/api/alerts", None),          # expects 401 = endpoint exists
    ("POST", "/api/auth/login", json.dumps({"email":"x","password":"x"}).encode()),
]

for method, path, data in tests:
    try:
        req = urllib.request.Request(f"{BASE}{path}", data=data, method=method)
        req.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read().decode()[:120]
            print(f"OK  {method} {path} -> {r.status} | {body}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:80]
        print(f"{e.code} {method} {path} -> {body}")
    except Exception as e:
        print(f"ERR {method} {path} -> {e}")
