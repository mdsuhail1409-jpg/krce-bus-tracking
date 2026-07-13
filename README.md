# KRCE Bus Tracking System — Unified Backend & Android App

> **Complete, production-ready bus tracking solution for KRCE (K. Ramakrishnan College of Engineering)**
> Combines FastAPI backend with Kotlin/Compose Android app for real-time GPS tracking, attendance management, and live bus monitoring.

---

## 📋 Project Overview

The KRCE Bus Tracking System is a comprehensive transportation management platform designed for college bus operations. It provides real-time GPS tracking, automated attendance via RFID, live bus status monitoring, and role-based dashboards for admins, drivers, students, and parents.

### Key Features

- **Real-time GPS Tracking**: Drivers broadcast live location via WebSocket; students and admins see live bus positions on interactive maps.
- **Automated Attendance**: RFID card taps automatically record boarding/exit events with timestamp and location.
- **Role-Based Access**: Separate dashboards for Admin, Committee, Driver, Student, and Parent roles.
- **Live Bus Monitoring**: Interactive OpenStreetMap display with bus markers, speed, passenger count, and status.
- **Persistent Data**: All attendance, GPS logs, and bus data stored in MongoDB Atlas.
- **Secure Authentication**: JWT-based token auth with bcrypt password hashing.
- **Parent Portal**: Dedicated dashboard for parents to track their child's bus and view attendance.

---

## 🏗️ Architecture

### Backend (FastAPI)
- **Framework**: FastAPI with async/await support.
- **Database**: MongoDB Atlas for persistent storage.
- **Real-time Communication**: WebSocket for live GPS updates and alert broadcasting.
- **Deployment**: Optimized for Railway (direct WebSocket support).

### Android App (Kotlin/Compose)
- **UI Framework**: Jetpack Compose with Material Design 3.
- **Architecture**: MVVM with ViewModel and SavedStateHandle for state persistence.
- **Navigation**: Compose Navigation with role-based routing.
- **Location Services**: Foreground service for continuous GPS tracking.
- **Maps**: OpenStreetMap (OSMDroid) for live bus visualization.

---

## 🔧 Setup & Installation

### Backend Setup

1. **Clone and Navigate**
   ```bash
   cd backend
   ```

2. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure Environment**
   Create a `.env` file (see [Environment Variables](#-environment-variables) below) inside the `backend` directory.

4. **Run the Server**
   ```bash
   python server.py
   # Server starts at http://localhost:8000
   ```

### Android App Setup

1. **Configure API Base URL**
   Edit `android/gradle.properties` and set your production URLs:
   ```properties
   API_BASE_URL=https://your-railway-app.up.railway.app/
   WS_BASE_URL=wss://your-railway-app.up.railway.app/
   ```

2. **Build and Run**
   ```bash
   cd android
   ./gradlew assembleRelease
   ```

---

## 📚 API Documentation

All endpoints are documented in the FastAPI Swagger UI at `/api/docs` when the server is running.

### Key Endpoints

#### Authentication
- `POST /api/auth/login` — Login with email and password
- `POST /api/my/change-password` — Change password (authenticated)

#### Buses & GPS
- `GET /api/buses` — List all buses (with live data)
- `GET /api/buses/{bus_id}/live` — Get live GPS data for a bus
- `GET /api/my/eta` — Get ETA and next stop for the user's assigned bus
- `WS /ws?token={jwt}` — WebSocket connection for real-time GPS updates

#### Attendance
- `GET /api/my/attendance` — Get current user's attendance history
- `GET /api/my/child-attendance` — Get child's attendance history (for parents)
- `POST /api/rfid/tap` — Record RFID tap event

---

## 🚀 Deployment

### Backend (Railway)
1. Push code to GitHub.
2. Connect GitHub repo to Railway.
3. Set environment variables: `MONGO_URI`, `JWT_SECRET`, `ALLOWED_ORIGINS`.
4. Railway will automatically deploy via the provided `requirements.txt`.

### Android (Release)
1. Build the release APK: `./gradlew assembleRelease`.
2. The APK will be generated at `app/build/outputs/apk/release/app-release.apk`.
3. Ensure `isMinifyEnabled = true` in `build.gradle.kts` for production.

---

## 📝 Environment Variables

Create a `.env` file in the backend directory:

```env
MONGO_URI=mongodb+srv://user:password@cluster.mongodb.net/krce_bus
MONGO_DB_NAME=krce_bus
JWT_SECRET=your-very-secure-secret-key-min-32-chars
ALLOWED_ORIGINS=https://yourdomain.com,http://localhost:3000
PORT=8000
```

---

## ✅ Verification Checklist

- [x] Parent Dashboard implemented in Android app.
- [x] History and Profile screens built.
- [x] WebSocketManager refactored for stability.
- [x] Parent HTML page added to backend.
- [x] Vercel WebSocket issue resolved (direct Railway connection).
- [x] Java 17 and Minification enabled for Android release.

---

**Version**: 3.2.0  
**Last Updated**: July 9, 2026  
**Status**: Production Ready ✅
