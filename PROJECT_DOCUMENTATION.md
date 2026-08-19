# KRCE Bus Tracking System — Comprehensive Master Technical Documentation

> **Project Name**: KRCE Bus Tracking System  
> **Target Institution**: K. Ramakrishnan College of Engineering (KRCE), Samayapuram, Tiruchirappalli, Tamil Nadu, India  
> **System Version**: 3.2.0 (Production Ready)  
> **Document Purpose**: Exhaustive technical documentation covering system architecture, technology stack, directory structure, database schema, operational workflows, API reference, IoT hardware integration, security standards, and deployment procedures.

---

## 📑 Table of Contents

1. [Executive Summary & System Purpose](#1-executive-summary--system-purpose)
2. [Complete Technology Stack](#2-complete-technology-stack)
3. [System Architecture & Data Flow](#3-system-architecture--data-flow)
4. [Repository Directory & File Breakdown](#4-repository-directory--file-breakdown)
5. [Database Schema & Data Models](#5-database-schema--data-models)
6. [Core Algorithms & Logical Workflows](#6-core-algorithms--logical-workflows)
   - 6.1 Authentication & Security Infrastructure
   - 6.2 Real-Time GPS Processing & Broadcast Workflow
   - 6.3 Automatic Route Direction Detection Algorithm
   - 6.4 Geofencing Engine (Arrival & Departure Detection)
   - 6.5 Vehicle Safety & Anomaly Detection Systems
   - 6.6 AI & Heuristic Prediction Engine (ETA, Delay, Demand, Occupancy)
   - 6.7 RFID Attendance & Automated Boarding/Alighting Workflow
   - 6.8 Emergency & Panic Alert (SOS) System
7. [API Endpoint Reference Matrix](#7-api-endpoint-reference-matrix)
8. [WebSocket Communication Protocol](#8-websocket-communication-protocol)
9. [IoT Hardware Subsystem (ESP32 / SIM900A GPRS)](#9-iot-hardware-subsystem-esp32--sim900a-gprs)
10. [User Role Dashboards & Feature Matrix](#10-user-role-dashboards--feature-matrix)
11. [Deployment, DevOps & Environment Setup](#11-deployment-devops--environment-setup)
12. [Troubleshooting & Known Solutions](#12-troubleshooting--known-solutions)

---

## 1. Executive Summary & System Purpose

The **KRCE Bus Tracking System** is an enterprise-grade, end-to-end transportation management and real-time fleet monitoring ecosystem built specifically for K. Ramakrishnan College of Engineering (KRCE).

### Core Problem Solved
Traditional institutional bus management relies on manual attendance, static phone calls to drivers, and uncertain waiting times for students and staff. This platform addresses:
- **Unpredictable Bus Arrival Times**: Provides sub-second live GPS tracking with AI-assisted ETA and traffic delay predictions.
- **Student Safety & Attendance Transparency**: Automates attendance via RFID card taps, notifying parents instantly when their child boards or alights from a specific stop.
- **Emergency Preparedness**: Offers instant SOS driver triggers and physical hardware panic buttons that sound alerts on admin dashboards and trigger hardware buzzers.
- **Fleet Safety Monitoring**: Automatically flags overspeeding (>60 km/h), vehicle idling (>5 min stationary), route deviation (>500m off route), and loss of GPS telemetry.

### Key Capabilities
- **Multi-Platform Access**: Web Application (HTML5/JS/Leaflet), Flutter Cross-Platform Mobile App (Android/iOS), and Native Android App (Kotlin Jetpack Compose).
- **IoT Hardware Integration**: Direct compatibility with standalone ESP32 hardware kits equipped with NEO-6M GPS modules, SIM900A GPRS GSM modems, and RC522 RFID scanners.
- **6 Tier Role-Based Access Control (RBAC)**: Admin, Transportation Committee, Driver, Student, Staff, and Parent.

---

## 2. Complete Technology Stack

### Backend Infrastructure
* **Language & Runtime**: Python 3.10+
* **Web Framework**: FastAPI (Async ASGI framework)
* **ASGI Server**: Uvicorn (High-performance web server)
* **Database Driver**: Motor (`AsyncIOMotorClient` for asynchronous MongoDB Atlas operations)
* **Security & Auth**: PyJWT (JSON Web Tokens), `passlib` with `bcrypt` password hashing, `secrets` library for secure credential generation.
* **Routing & GIS Engine**: Open Source Routing Machine (OSRM) REST API & Haversine Spherical Trigonometry formula.

### Database Layer
* **Primary Storage**: MongoDB Atlas (Cloud NoSQL database)
* **Fallback Storage**: Custom In-Memory Async Mock Database Engine (used for offline zero-config local development).

### Frontends

#### 1. Web Dashboard (Built-in)
* **Templates**: Jinja2 HTML5 pages (`templates/index.html`).
* **Styling**: Modern Vanilla CSS with dark mode aesthetics, glassmorphism, dynamic animations, and responsive flexbox/grid layouts.
* **Mapping Engine**: Leaflet.js open-source map library paired with OpenStreetMap tiles.

#### 2. Cross-Platform Mobile App (Flutter)
* **Framework**: Flutter 3.x / Dart SDK
* **State Management**: Provider / Riverpod architecture
* **HTTP Client**: `http` / `dio` package
* **Map Renderer**: `flutter_map` (Leaflet wrapper for Flutter) with `latlong2`
* **Real-time Engine**: `web_socket_channel`
* **Local Storage**: `shared_preferences`

#### 3. Native Android Mobile App (Kotlin / Compose)
* **Language**: Kotlin 1.9+
* **UI Toolkit**: Jetpack Compose with Material Design 3 (MD3) components.
* **Architecture**: Model-View-ViewModel (MVVM) with `StateFlow` and `SharedFlow`.
* **Network & REST**: Retrofit 2 + OkHttp 4
* **Map Rendering**: OSMDroid (OpenStreetMap for Android)
* **Background Tracking Service**: Android Foreground Service (`GpsForegroundService`) with persistent notifications (`NotificationCompat.Builder`).

### IoT Hardware Subsystem
* **Microcontroller**: ESP32 / Arduino framework (C++)
* **Cellular Modem**: SIM900A / SIM800L GPRS GSM Module (HTTP POST telemetry)
* **GPS Module**: NEO-6M GPS Receiver (NMEA sentence parser)
* **RFID Scanner**: RC522 13.56 MHz RFID Reader
* **Panic Button & Buzzer**: Physical GPIO interrupt switch & active piezoelectric buzzer.

---

## 3. System Architecture & Data Flow

```
                     +----------------------------------+
                     |   IoT Hardware Kit (ESP32/SIM900) |
                     |   [GPS + RFID + SOS Button]       |
                     +-----------------+----------------+
                                       | HTTP POST
                                       v
+-----------------------+     +------------------+     +------------------------+
|  Driver Mobile App    |---->|  FastAPI Backend |<--->|  MongoDB Atlas Database|
|  (Location Broadcast) | HTTP|  (server.py)     |     |  (Persistent Storage)  |
+-----------------------+ WS  +--------+---------+     +------------------------+
                                       |
                   +-------------------+-------------------+
                   | WebSocket Broadcast Channel (/ws)    |
                   +-------------------+-------------------+
                                       |
    +----------------------------------+----------------------------------+
    |                                  |                                  |
    v                                  v                                  v
+-----------------------+    +-----------------------+    +-----------------------+
| Student/Staff App     |    | Parent Dashboard      |    | Admin Control Center  |
| Live ETA & Bus Map    |    | Child Attendance/Track|    | Real-Time Fleet State |
+-----------------------+    +-----------------------+    +-----------------------+
```

---

## 4. Repository Directory & File Breakdown

Below is the directory structure of the repository and the exact purpose of every file:

```
krce-bus-tracking-main/
│
├── README.md                   # Primary project overview & installation guide
├── DEPLOYMENT_GUIDE.md         # Railway & Render production deployment walkthrough
├── FIXES_SUMMARY.md            # Detailed record of security & bug fixes applied
├── PROJECT_DOCUMENTATION.md    # Master documentation (this file)
├── check_backend.ps1           # PowerShell health check diagnostic script
├── test_api.py                 # Automated REST API test suite
├── test_urls.py                # Endpoint URL verification utility
│
├── database/                   # Standalone Database Utilities
│   ├── __init__.py
│   └── db.py                   # Legacy database initialization & seed generator
│
├── backend/                    # FastAPI Backend Application
│   ├── Procfile                # Gunicorn/Uvicorn command for Railway deployment
│   ├── render.yaml             # Render cloud platform deployment specification
│   ├── requirements.txt        # Python package dependencies
│   ├── server.py               # Application entry point, lifespan, & app instantiation
│   ├── .env.example            # Template for environment configuration variables
│   │
│   ├── app/                    # Core Python Application Modules
│   │   ├── __init__.py         # Package initialization & logger setup
│   │   ├── config.py           # Environment variables, constants, & stop coordinates
│   │   ├── database.py         # MongoDB connection, motor client, & mock DB engine
│   │   ├── auth.py             # JWT token encoding, decoding, & password hashing
│   │   ├── gps.py              # Geofence checks, safety algorithms, stale cleaner
│   │   ├── models.py           # Pydantic data schemas & request validators
│   │   ├── predictions.py      # ETA, delay, student demand, & occupancy ML heuristics
│   │   ├── state.py            # Shared runtime state (live_buses, ws_pool, last_seen)
│   │   ├── utils.py            # Haversine distance, OSRM router, timestamp helpers
│   │   │
│   │   └── routes/             # Modular Endpoint Route Controllers
│   │       ├── __init__.py     # Router inclusion & aggregation
│   │       ├── admin.py        # Fleet stats, user management, registration approvals
│   │       ├── auth.py         # Login, token refresh, password changes
│   │       ├── buses.py        # Bus listing, live positions, route stops, ETA
│   │       ├── driver.py       # Driver location broadcast & status toggles
│   │       ├── emergencies.py  # Emergency creation, acknowledgement, & resolution
│   │       ├── hardware.py     # Dedicated IoT ESP32 GPS/RFID/SOS HTTP endpoints
│   │       ├── pages.py        # Web dashboard template rendering (Jinja2)
│   │       ├── rfid.py         # RFID card swipe logging & attendance recording
│   │       ├── user.py         # User profile views & child attendance endpoints
│   │       └── websocket.py    # Live WebSocket connection handler (`/ws`)
│   │
│   └── templates/              # HTML Web Dashboards
│       └── index.html          # Unified multi-role web interface (Leaflet Map & Control)
│
├── frontend/                   # Cross-Platform Flutter Application
│   └── krce_bus_flutter/
│       ├── pubspec.yaml        # Flutter project dependencies & asset definitions
│       └── lib/
│           ├── main.dart       # Flutter app entry point & root widget setup
│           ├── core/
│           │   ├── config/     # App colors, constants, & API base URLs
│           │   ├── models/     # Dart data models (User, Bus, Attendance, Emergency)
│           │   ├── services/   # ApiService, WebSocketService, GpsService, NotificationService
│           │   ├── theme/      # Dark/Light Material 3 themes
│           │   └── utils/      # Formatting & date utilities
│           │
│           ├── features/       # Role-Based Feature Modules
│           │   ├── admin/      # Admin dashboard, user manager, registration screen
│           │   ├── auth/       # Login screen & password reset dialog
│           │   ├── driver/     # Driver dashboard with broadcast button & trip status
│           │   ├── history/    # Attendance history & system audit logs
│           │   ├── map/        # Interactive Leaflet map with live bus markers
│           │   ├── parent/     # Parent dashboard with child location & attendance
│           │   ├── profile/    # User profile & credentials management
│           │   └── student/    # Student/Staff dashboards with bus ETA card
│           │
│           ├── routes/         # App navigation routing table
│           └── widgets/        # Shared reusable UI widgets (Cards, Buttons, Dialogs)
│
└── android/                    # Native Android App (Kotlin & Jetpack Compose)
    ├── build.gradle.kts        # Root Gradle build script
    ├── gradle.properties       # Target API base URLs & Kotlin parameters
    └── app/
        ├── build.gradle.kts    # Android app module configuration & dependencies
        └── src/main/
            ├── AndroidManifest.xml # Android permissions & service declarations
            └── java/com/krce/bus/
                ├── MainActivity.kt # Main Jetpack Compose host activity & screens
                ├── AuthViewModel.kt# Compose StateFlow authentication state manager
                ├── api/        # Retrofit API interface definitions
                ├── models/     # Kotlin data classes
                ├── service/    # GpsForegroundService for background location posting
                └── ui/         # Jetpack Compose UI themes & components
```

---

## 5. Database Schema & Data Models

The system uses MongoDB as its primary persistence storage. Below is the complete collection schema:

### 1. `users` Collection
Stores credential accounts, contact information, and role assignments.
```json
{
  "_id": "ObjectId",
  "id": "stu01",
  "name": "Aravind Kumar",
  "email": "aravind@krce.ac.in",
  "phone": "9841100001",
  "role": "student", // Allowed: "admin", "committee", "driver", "student", "staff", "parent"
  "college_id": "21CS001",
  "rfid_card": "RF001",
  "bus_id": "B01",
  "parent_of": null, // Student college_id if role is "parent"
  "licence_no": null, // Driver license number if role is "driver"
  "password_hash": "$2b$12$e... (bcrypt hashed)",
  "is_active": 1,
  "created_at": "2026-07-09T10:00:00.000Z",
  "last_login": "2026-08-04T08:30:00.000Z"
}
```

### 2. `buses` Collection
Defines fleet vehicles, assigned routes, and drivers.
```json
{
  "_id": "ObjectId",
  "id": "B01",
  "number": "TN-45-AH-1234",
  "route_name": "Route A — Woraiyur",
  "driver_id": "drv01",
  "capacity": 50,
  "stops": [
    "KRCE Campus",
    "Samayapuram",
    "Woraiyur Bus Stand",
    "Woraiyur Town",
    "Gandhi Market"
  ],
  "is_active": 1,
  "created_at": "2026-07-09T10:00:00.000Z"
}
```

### 3. `live_bus_positions` Collection
Stores the current real-time state of each bus (updated every 1-5 seconds).
```json
{
  "_id": "ObjectId",
  "bus_id": "B01",
  "driver_id": "drv01",
  "driver_name": "Rajan S.",
  "lat": 10.8905,
  "lon": 78.7847,
  "speed": 34.5,
  "heading": 182.0,
  "passengers": 28,
  "status": "moving", // Allowed: "moving", "idle", "signal_loss", "offline"
  "direction": "forward", // "forward" (To College) or "reverse" (From College)
  "confirmed_stop_idx": 1,
  "destination_stop": "Gandhi Market",
  "destination_lat": 10.7905,
  "destination_lon": 78.7047,
  "remaining_stops": ["Samayapuram", "Woraiyur Bus Stand", "Woraiyur Town", "Gandhi Market"],
  "updated_at": 1785834000.5,
  "last_active": 1785834000.5
}
```

### 4. `live_bus_positions_history` Collection
Historical GPS points for playback and route analytics.
```json
{
  "_id": "ObjectId",
  "bus_id": "B01",
  "lat": 10.8905,
  "lon": 78.7847,
  "speed": 34.5,
  "heading": 182.0,
  "passengers": 28,
  "ts": 1785834000.5,
  "date": "2026-08-04"
}
```

### 5. `attendance` Collection
Records RFID card swipes on buses.
```json
{
  "_id": "ObjectId",
  "id": "att_9a8b7c",
  "user_id": "stu01",
  "bus_id": "B01",
  "tap_type": "boarded", // "boarded" or "exited"
  "tap_time": "2026-08-04T08:15:30.000Z",
  "stop_name": "Woraiyur Bus Stand",
  "lat": 10.7905,
  "lon": 78.7047,
  "date": "2026-08-04"
}
```

### 6. `emergencies` Collection
Stores active and historical emergency triggers.
```json
{
  "_id": "ObjectId",
  "id": "emg_123456",
  "bus_id": "B01",
  "driver_id": "drv01",
  "driver_name": "Rajan S.",
  "emergency_type": "SOS Button Pressed",
  "message": "Emergency SOS triggered from bus TN-45-AH-1234",
  "lat": 10.8905,
  "lon": 78.7847,
  "status": "active", // "active", "acknowledged", or "resolved"
  "buzzer_active": 1, // Controls ESP32 hardware buzzer
  "created_at": "2026-08-04T08:45:00.000Z",
  "resolved_at": null
}
```

### 7. `alerts` Collection
System notices broadcast to connected users.
```json
{
  "_id": "ObjectId",
  "id": "alt_abcdef",
  "title": "Overspeed Alert",
  "message": "Bus B01 is traveling at an unsafe speed of 68.5 km/h!",
  "alert_type": "warning", // "info", "warning", "danger", "delay"
  "target_role": "all",
  "target_bus": "B01",
  "sent_by": "system",
  "sent_at": "2026-08-04T08:50:00.000Z",
  "is_resolved": 0
}
```

### 8. `registrations` Collection
Pending user signup requests awaiting admin approval.
```json
{
  "_id": "ObjectId",
  "id": "reg_789012",
  "name": "New Student",
  "email": "newstudent@krce.ac.in",
  "phone": "9841199999",
  "role": "student",
  "college_id": "24CS099",
  "bus_id": "B01",
  "status": "pending", // "pending", "approved", "rejected"
  "created_at": "2026-08-04T09:00:00.000Z"
}
```

---

## 6. Core Algorithms & Logical Workflows

### 6.1 Authentication & Security Infrastructure
1. **Password Encryption**: All user passwords are encrypted using `bcrypt` salted password hashing (`gensalt(12)`). SHA-256 fallback hashing has been purged for high security.
2. **JWT Tokens**: On successful login (`POST /api/auth/login`), the server issues an HTTP Bearer JWT signed with `JWT_SECRET` (enforced at startup to be $\ge 32$ characters). Tokens contain payload: `sub` (user_id), `role`, `email`, and `exp` (24-hour expiration).
3. **Role Validation Middleware**: Protected routes check the user's role against required roles (e.g. `admin`, `committee`, `driver`, `parent`).

### 6.2 Real-Time GPS Processing & Broadcast Workflow
When a driver mobile app or ESP32 hardware posts GPS coordinates:
1. `process_gps_update()` in `app/gps.py` receives `bus_id`, `lat`, `lon`, `speed`, `heading`, and `passengers`.
2. Telemetry state is saved in memory (`live_buses[bus_id]`) and asynchronously persisted to MongoDB collection `live_bus_positions`.
3. Coordinates are logged to `live_bus_positions_history` for route playback.
4. **WebSocket Broadcast**: The updated payload is serialized to JSON and broadcast immediately to all clients connected on `/ws`.
5. **Offline Vehicle Sweeper (`stale_cleaner`)**: An asynchronous background loop runs every 10 seconds. If a bus emits no GPS pings for $>60$ seconds (`VEHICLE_TTL`), its status transitions to `"offline"`, and an offline alert is generated. If inactive between 30–60s, its status transitions to `"signal_loss"`.

### 6.3 Automatic Route Direction Detection Algorithm
To eliminate manual driver toggling of route directions (To College vs. From College):
1. On each GPS ping, the backend calculates the nearest stop index along the bus's predefined route list using the **Haversine formula**.
2. To prevent GPS jitter noise, nearest stop indices are buffered into a rolling window array of size 3 (`recent_stop_indices`).
3. When all 3 elements in the window match, the `confirmed_stop_idx` updates:
   - If `confirmed_stop_idx > previous_confirmed_idx` $\rightarrow$ Direction is marked as `"forward"` (Heading towards Campus/End Stop).
   - If `confirmed_stop_idx < previous_confirmed_idx` $\rightarrow$ Direction is marked as `"reverse"` (Heading back from Campus).
4. `remaining_stops` and target `destination_stop` are automatically recalculated dynamically based on the detected direction.

### 6.4 Geofencing Engine (Arrival & Departure Detection)
The system continuously calculates spherical distance $d$ from the bus position $(lat_1, lon_1)$ to every stop coordinate $(lat_2, lon_2)$ using Haversine calculation:

$$d = 2r \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)} \right)$$

where $r = 6371000$ meters.

* **Arrival Threshold ($d \le 150\text{ meters}$)**: If the bus was previously `"outside"`, state shifts to `"inside"`, and an automated alert `"Bus Reached [Stop Name]"` is created and broadcast via WebSocket.
* **Departure Threshold ($d > 250\text{ meters}$)**: If the bus was previously `"inside"`, state shifts to `"outside"`, and a departure alert `"Bus Departed [Stop Name]"` is triggered.

### 6.5 Vehicle Safety & Anomaly Detection Systems
Every incoming GPS point triggers three automated safety checks:
1. **Overspeed Detection**: If `speed > 60.0 km/h`, a warning alert is immediately broadcast to admins. Rate-limited to once every 3 minutes per bus to prevent notification spam.
2. **Idle Detection**: If `speed <= 1.0 km/h` continuously for $> 5\text{ minutes}$, an Idle Alert is dispatched.
3. **Route Deviation Alert**: Checks the shortest distance between current location and the bus's OSRM polyline geometry. If distance $> 500\text{ meters}$, a high-severity Danger alert `"Route Deviation Alert"` is fired.

### 6.6 AI & Heuristic Prediction Engine (ETA, Delay, Demand, Occupancy)
In `app/predictions.py`:
* **ETA & Delay Calculation**:
  - Distance $d$ to target stop calculated via Haversine.
  - Baseline speed established at $8.3\text{ m/s}$ ($30\text{ km/h}$).
  - **Rush Hour Multipliers**: If local time is between 08:00–09:00 AM or 04:00–06:00 PM, a traffic delay factor of $1.4\times$ is applied to predicted duration.
  - Baseline comparison at $40\text{ km/h}$ determines predicted delay in minutes.
* **Student Demand Heuristics**: Predicts student volume at upcoming stops based on historical stop weights and day-of-week peak factors (Mondays & Fridays scaled $1.3\times$).
* **Occupancy Status Classification**:
  - $\text{Fill Ratio} = \frac{\text{Passengers}}{\text{Capacity}}$
  - Fill Ratio $> 0.9 \rightarrow$ **Critical (Near Capacity)**
  - Fill Ratio $> 0.7 \rightarrow$ **High (Few Seats Available)**
  - Fill Ratio $> 0.3 \rightarrow$ **Moderate**
  - Fill Ratio $\le 0.3 \rightarrow$ **Low (Many Seats Available)**

### 6.7 RFID Attendance & Automated Boarding/Alighting Workflow
1. When a student taps their RFID card (`RFxxx`) on the RC522 reader:
2. The card code is sent to `POST /api/hardware/rfid/tap` or `POST /api/rfid/tap`.
3. The server looks up previous taps for that user for the current date.
4. **State Toggle**:
   - If the last tap was `"boarded"`, the current tap is automatically marked `"exited"`, and live passenger count decrements by 1.
   - If no prior tap or last tap was `"exited"`, current tap is marked `"boarded"`, and passenger count increments by 1.
5. An attendance document is inserted into MongoDB.
6. A WebSocket notification `type: "rfid_tap"` is pushed live to parents and admins.

### 6.8 Emergency & Panic Alert (SOS) System
1. **Trigger**: Pressed by driver via mobile UI or ESP32 hardware SOS button.
2. **Backend Action**: Creates an emergency record with status `"active"` and `buzzer_active: 1`.
3. **Buzzer Feedback**: ESP32 regularly polls `/api/hardware/ping`. If `buzzer_active == true`, the hardware sounds its physical alarm buzzer continuously until acknowledged.
4. **Admin Acknowledgement**: Admins click "Acknowledge" on dashboard (`POST /api/emergencies/{id}/acknowledge`), which sets `buzzer_active: 0` to silence the physical buzzer while keeping the incident active for audit.
5. **Resolution**: Marked resolved via `POST /api/emergencies/{id}/resolve`.

---

## 7. API Endpoint Reference Matrix

| Category | Endpoint | Method | Role Required | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auth** | `/api/auth/login` | `POST` | Public | Authenticates user; returns JWT token & user info. |
| **Auth** | `/api/my/change-password` | `POST` | Authenticated | Updates current user password. |
| **Buses** | `/api/buses` | `GET` | Public / Auth | Lists all buses with live position, driver name, & occupancy. |
| **Buses** | `/api/buses/{bus_id}` | `GET` | Public / Auth | Fetches detailed metadata & stop list for a bus. |
| **Buses** | `/api/buses/{bus_id}/live` | `GET` | Public / Auth | Returns instant live GPS coordinates for a specific bus. |
| **Buses** | `/api/buses/{bus_id}/stops` | `GET` | Public / Auth | Returns stop names with lat/lon coordinates & predicted ETA. |
| **Buses** | `/api/my/eta` | `GET` | Student/Staff | Calculates ETA & next stop for student's assigned bus. |
| **Driver** | `/api/driver/location` | `POST` | Driver | Receives continuous GPS broadcast from driver app. |
| **Driver** | `/api/driver/status` | `GET` | Driver | Gets driver's active trip state & assigned bus details. |
| **RFID** | `/api/rfid/tap` | `POST` | Authenticated | Logs RFID card swipe (boarding/alighting). |
| **Hardware** | `/api/hardware/gps` | `POST` | Device / Key | Hardware route for ESP32 GPS data telemetry. |
| **Hardware** | `/api/hardware/rfid/tap` | `POST` | Device / Key | Hardware route for ESP32 RFID card swipes. |
| **Hardware** | `/api/hardware/ping` | `GET` | Device / Key | ESP32 keep-alive ping; returns active buzzer state. |
| **Hardware** | `/api/hardware/emergency` | `POST` | Device / Key | Hardware SOS panic button POST endpoint. |
| **Emergencies**| `/api/emergencies` | `GET` | Authenticated | Lists all emergency incidents. |
| **Emergencies**| `/api/emergencies` | `POST` | Driver / Admin | Triggers a new emergency incident. |
| **Emergencies**| `/api/emergencies/{id}/acknowledge`| `POST` | Admin | Acknowledges emergency & silences hardware buzzer. |
| **Emergencies**| `/api/emergencies/{id}/resolve`| `POST` | Admin | Marks emergency incident as resolved. |
| **Admin** | `/api/admin/stats` | `GET` | Admin / Comm | Returns total buses, active buses, drivers, & passenger counts. |
| **Admin** | `/api/admin/users` | `GET` | Admin / Comm | Lists all system users with filtering options. |
| **Admin** | `/api/admin/registrations` | `GET` | Admin | Fetches pending signup registration requests. |
| **Admin** | `/api/admin/registrations/{id}/approve` | `POST` | Admin | Approves pending user & generates random password. |
| **Admin** | `/api/admin/alerts` | `POST` | Admin | Broadcasts custom notification to all users. |
| **User** | `/api/my/profile` | `GET` | Authenticated | Returns current user profile details. |
| **User** | `/api/my/attendance` | `GET` | Authenticated | Returns personal RFID attendance log history. |
| **User** | `/api/my/child-attendance` | `GET` | Parent | Returns child's live bus position & RFID attendance. |

---

## 8. WebSocket Communication Protocol

* **Endpoint URL**: `ws://<host>/ws?token=<JWT_TOKEN>` or `wss://<host>/ws?token=<JWT_TOKEN>`
* **Connection Lifecycle**:
  1. Client connects with valid JWT token query param.
  2. Server verifies token and registers client socket in `ws_pool`.
  3. Server sends initial snapshot of all `live_buses` immediately.
  4. Every 10 seconds, server sends a `{"type": "ping"}` frame; client responds with `{"type": "pong"}`.

### Message Payloads

#### 1. GPS Position Update Broadcast (`type: "gps_update"`)
```json
{
  "type": "gps_update",
  "bus_id": "B01",
  "lat": 10.8905,
  "lon": 78.7847,
  "speed": 34.5,
  "heading": 182.0,
  "passengers": 28,
  "status": "moving",
  "direction": "forward",
  "destination_stop": "Gandhi Market",
  "updated_at": 1785834000.5
}
```

#### 2. System Alert Broadcast (`type: "alert"`)
```json
{
  "type": "alert",
  "id": "alt_123456",
  "title": "Overspeed Alert",
  "message": "Bus TN-45-AH-1234 traveling at 65 km/h",
  "alert_type": "warning",
  "target_bus": "B01"
}
```

#### 3. Emergency SOS Broadcast (`type: "emergency"`)
```json
{
  "type": "emergency",
  "id": "emg_789012",
  "bus_id": "B01",
  "driver_name": "Rajan S.",
  "emergency_type": "SOS Button Pressed",
  "lat": 10.8905,
  "lon": 78.7847,
  "status": "active"
}
```

---

## 9. IoT Hardware Subsystem (ESP32 / SIM900A GPRS)

For standalone tracking without relying on a driver's smartphone, an ESP32 micro-controller kit can be installed directly inside the bus dashboard.

### Hardware Wiring & Interface Schematic
* **NEO-6M GPS Module**: Connected to ESP32 Serial2 (`RX=16`, `TX=17`). Reads NMEA `$GPRMC` sentences for latitude, longitude, speed, and satellites.
* **SIM900A GPRS Modem**: Connected to ESP32 Serial1 (`RX=26`, `TX=27`). Performs HTTP POST requests over cellular data.
* **RC522 RFID Reader**: Connected via SPI interface (`SS=5`, `SCK=18`, `MOSI=23`, `MISO=19`).
* **Panic SOS Button**: GPIO pin 34 with pull-down resistor. Triggers instant HTTP POST to `/api/hardware/emergency`.
* **Piezoelectric Buzzer**: GPIO pin 25. Driven HIGH when backend returns `"buzzer_active": true`.

### Hardware Authentication
ESP32 requests can include an optional custom header `X-Device-Key: <HW_API_KEY>` matching the backend environment variable `HW_API_KEY` for device validation.

---

## 10. User Role Dashboards & Feature Matrix

| Feature | Admin | Committee | Driver | Student / Staff | Parent |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Live Fleet OpenStreetMap View** | ✅ All | ✅ All | ✅ Own Bus | ✅ Assigned Bus | ✅ Child's Bus |
| **Real-time Bus Speed & Passengers** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Broadcast Live GPS Telemetry** | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Manual / Hardware SOS Trigger** | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Acknowledge/Resolve Emergency** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Approve Signup Registrations** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **View Attendance Logs & History** | ✅ All | ✅ All | ❌ | ✅ Self | ✅ Child |
| **System Alert Creation** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **ETA & Route Stop Predictions** | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 11. Deployment, DevOps & Environment Setup

### Environment Variables Matrix (`backend/.env`)

```env
# Database Settings
MONGO_URI=mongodb+srv://<user>:<password>@cluster0.mongodb.net/krce_bus?retryWrites=true&w=majority
MONGO_DB_NAME=krce_bus

# Authentication & Security
JWT_SECRET=your_super_secret_jwt_key_at_least_32_characters_long_krce
HW_API_KEY=krce_esp32_hardware_secret_key_2026

# Server & Network Configuration
PORT=8000
ALLOWED_ORIGINS=https://your-app.vercel.app,http://localhost:3000,http://localhost:8000
```

### Deploying FastAPI Backend (Railway / Render)
1. Push repository code to GitHub.
2. Link repository to Railway or Render platform.
3. Configure Environment Variables (`MONGO_URI`, `JWT_SECRET`, `ALLOWED_ORIGINS`).
4. Set Build & Start Commands:
   - **Start Command**: `gunicorn -k uvicorn.workers.UvicornWorker server:app --bind 0.0.0.0:$PORT`
5. Verify health check at `https://<your-railway-url>/api/buses`.

### Building Flutter Android Release APK
1. Open terminal in `frontend/krce_bus_flutter`.
2. Run clean & get dependencies:
   ```bash
   flutter clean
   flutter pub get
   ```
3. Build standalone release APK:
   ```bash
   flutter build apk --release
   ```
4. Output path: `frontend/krce_bus_flutter/build/app/outputs/flutter-apk/app-release.apk`.

### Building Native Android Compose App
1. Open `android/` directory in Android Studio.
2. Verify `android/gradle.properties` contains valid server production endpoints:
   ```properties
   API_BASE_URL=https://your-production-backend.up.railway.app/
   WS_BASE_URL=wss://your-production-backend.up.railway.app/
   ```
3. Execute Gradle release task:
   ```bash
   ./gradlew assembleRelease
   ```
4. Output path: `android/app/build/outputs/apk/release/app-release.apk`.

---

## 12. Troubleshooting & Known Solutions

1. **WebSocket Handshake Failure on Cloud Proxies (Vercel/Cloudflare)**:
   - *Symptom*: WebSocket fails to connect or closes with code 1006.
   - *Cause*: Serverless proxies time out long-lived WebSocket connections.
   - *Solution*: Clients should bypass proxy domains and establish WebSocket connections directly to Railway/Render origin (`wss://backend.up.railway.app/ws?token=...`).

2. **Android Foreground Location Service Killed**:
   - *Symptom*: Driver location tracking stops when screen turns off.
   - *Solution*: Ensure `GpsForegroundService` has `FOREGROUND_SERVICE_LOCATION` permission declared in `AndroidManifest.xml` and Android battery optimization is disabled for the app.

3. **In-Memory Fallback DB in Production Warning**:
   - *Symptom*: Log displays `[DB] Using In-Memory Mock Database`.
   - *Solution*: Ensure `MONGO_URI` in `.env` is a valid connection string starting with `mongodb+srv://` or `mongodb://`.

---

> **Document Maintained By**: KRCE Technical Development Team  
> **Last Verification Date**: August 4, 2026  
> **Status**: Verified & Operational ✅
