# KRCE Bus Tracking System — Production Deployment Guide

This guide covers deploying the unified KRCE Bus Tracking System (FastAPI backend + Android app) to production.

---

## 🎯 Pre-Deployment Checklist

### Backend Requirements
- [ ] MongoDB Atlas account (Free tier is sufficient)
- [ ] Python 3.9+
- [ ] JWT_SECRET (min 32 characters)
- [ ] ALLOWED_ORIGINS (comma-separated list of domains)

### Android Requirements
- [ ] Android Studio 2024+
- [ ] API_BASE_URL and WS_BASE_URL set in `gradle.properties`

---

## 🚀 Backend Deployment (Railway)

Railway is the recommended platform because it supports native WebSockets and provides a persistent MongoDB-friendly environment.

1. **Create Railway Project**
   - Connect your GitHub repository.
   - Select the `backend` folder.

2. **Configure Variables**
   Set the following in the Railway "Variables" tab:
   - `MONGO_URI`: Your MongoDB Atlas connection string.
   - `JWT_SECRET`: A long random string for security.
   - `ALLOWED_ORIGINS`: `*` or your specific web domain.
   - `PORT`: `8000`

3. **Deploy**
   - Railway will detect the `requirements.txt` and `server.py` inside `backend`.
   - Once deployed, you will get a URL like `https://krce-bus-production.up.railway.app`.

---

## 📱 Android App Deployment

1. **Set Production URLs**
   In `android/gradle.properties`, update:
   ```properties
   API_BASE_URL=https://your-railway-app.up.railway.app/
   WS_BASE_URL=wss://your-railway-app.up.railway.app/
   ```

2. **Build Release APK**
   ```bash
   ./gradlew assembleRelease
   ```
   The APK is located at: `app/build/outputs/apk/release/app-release.apk`.

3. **Security Note**
   - Minification (ProGuard) is enabled in `build.gradle.kts`.
   - Java 17 is required for the build.

---

## 🌐 Website Access

The backend serves three primary web interfaces:
- **Passenger Interface**: `/`
- **Admin Dashboard**: `/admin`
- **Parent Portal**: `/parent`

These are embedded in `server.py` for zero-configuration deployment.

---

## ⚠️ WebSocket & Proxying (I-42 Fix)

**Important**: Do NOT use Vercel to proxy the backend if you need WebSocket support. Vercel's serverless functions do not support persistent WebSocket connections. 

**Connect the Android app directly to the Railway URL.**

---

**Status**: Verified Production Ready
**Version**: 3.2.0
