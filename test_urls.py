import urllib.request
import urllib.error

urls = [
    "https://krce-bus-production.onrender.com",
    "https://krce-bus-tracking.onrender.com",
    "https://krce-bus.onrender.com",
    "https://krce-bus-system.onrender.com",
    "https://krce-bus-api.onrender.com",
    "https://krce-bus-backend.onrender.com",
    "https://srv-d9ab7l58nd3s73ap4rl0.onrender.com",
]

for url in urls:
    try:
        req = urllib.request.Request(f"{url}/healthz")
        with urllib.request.urlopen(req, timeout=10) as r:
            body = r.read().decode()
            print(f"ALIVE: {url} -> {r.status} | {body}")
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {url}")
    except urllib.error.URLError as e:
        print(f"UNREACHABLE: {url} -> {e.reason}")
    except Exception as e:
        print(f"ERROR: {url} -> {e}")
