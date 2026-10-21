# Supabase Email OTP Authenticator Integration Guide
**KRCE Smart Bus Tracking System**

This guide provides the complete architecture, setup instructions, backend endpoints, and Flutter client integration details for using **Supabase Authenticator (Email OTP)** with verified college email addresses.

---

## 1. Architecture Overview

Identity verification and role-based permissions are separated into a hybrid security model:
1. **Supabase Auth (GoTrue)** handles identity verification: email input, 6-digit OTP generation, delivery via secure SMTP, and OTP validation.
2. **KRCE FastAPI + MongoDB Backend** handles college authorization: user role (`student`, `parent`, `driver`, `staff`, `admin`), bus assignment, routes, and live GPS access.

```
                      ┌──────────────────────────────────────┐
                      │    User (Student / Parent / Staff)   │
                      └──────────────────┬───────────────────┘
                                         │ Enters verified college email
                                         ▼
                     ┌───────────────────────────────────────┐
                     │   Flutter Mobile App / Admin Portal   │
                     └───────┬───────────────────────▲───────┘
          1. signInWithOtp() │                       │ 6. Exchange for
                             ▼                       │    KRCE Session JWT
                  ┌────────────────────┐             │
                  │   Supabase Auth    │             │
                  │   (GoTrue API)     │             │
                  └─────────┬──────────┘             │
           2. Sends │       │ 4. verifyOTP()         │
           6-digit  ▼       ▼                        ▼
         ┌────────────┐   ┌──────────────────────────────┐
         │ User Email │   │     KRCE FastAPI Backend     │
         │  (Gmail)   │   │  POST /api/auth/supabase-verify
         └────────────┘   └──────────────┬───────────────┘
                                         │ 5. Validate Supabase JWT
                                         │    & query role from MongoDB
                                         ▼
                               ┌───────────────────┐
                               │  MongoDB Cluster  │
                               │  (users collection│
                               └───────────────────┘
```

---

## 2. Supabase Dashboard Setup

### Step 1: Create Project
1. Log in to [Supabase](https://supabase.com) and create a project named `krce-bus-tracking`.
2. Select your closest region (e.g. `ap-south-1` for Mumbai/India).

### Step 2: Configure Email Authentication
1. Go to **Authentication** $\rightarrow$ **Providers** $\rightarrow$ **Email**.
2. Turn **ON** `Enable Email provider`.
3. Turn **ON** `Confirm email`.
4. Turn **ON** `Enable Email OTP`.
5. Set **OTP expiry** to `300` seconds (5 minutes).

### Step 3: Customize Email Template
Navigate to **Authentication** $\rightarrow$ **Email Templates** $\rightarrow$ **Magic Link / OTP**.
* **Subject**: `KRCE Bus Transit - Your Login Code`
* **Message Body**:
```html
<div style="font-family: Arial, sans-serif; background-color: #0f172a; color: #f8fafc; padding: 24px; border-radius: 12px; max-width: 480px;">
  <h2 style="color: #6366f1; margin-bottom: 8px;">K. Ramakrishnan College of Engineering</h2>
  <p style="color: #94a3b8; font-size: 14px;">Smart Bus Transit Verification</p>
  <p style="font-size: 15px; margin-top: 16px;">Use the following 6-digit one-time password (OTP) to log into your account:</p>
  <div style="background-color: #1e293b; padding: 16px; text-align: center; border-radius: 8px; margin: 20px 0; border: 1px solid #334155;">
    <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #38bdf8;">{{ .Token }}</span>
  </div>
  <p style="color: #94a3b8; font-size: 12px;">This code will expire in 5 minutes. Do not share this code with anyone.</p>
</div>
```

### Step 4: Retrieve API Keys
Go to **Project Settings** $\rightarrow$ **API** and copy:
* **Project URL**: `https://<your-project-ref>.supabase.co`
* **Anon Key**: `eyJh...` (Public API Key)
* **JWT Secret**: `your-supabase-jwt-secret`

---

## 3. Backend Integration (FastAPI)

### 1. Update Environment Variables (`backend/.env`)
```ini
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_JWT_SECRET=your-supabase-jwt-secret
```

### 2. Add Exchange Endpoint (`backend/app/routes/auth.py`)
Add `POST /api/auth/supabase-verify` to validate the Supabase-authenticated session and issue a KRCE token:

```python
from pydantic import BaseModel, EmailStr
from fastapi import APIRouter, Request, HTTPException

class SupabaseAuthReq(BaseModel):
    email: EmailStr
    supabase_token: str

@router.post("/api/auth/supabase-verify")
@limiter.limit("10/minute")
async def verify_supabase_session(req: SupabaseAuthReq, request: Request):
    """
    Validates Supabase-verified email and issues active KRCE access token with MongoDB role & bus details.
    """
    db = db_module.db
    email_clean = req.email.strip().lower()

    # Query verified user from MongoDB
    user = await db.users.find_one({"email": email_clean, "is_active": 1})
    if not user:
        raise HTTPException(
            status_code=403,
            detail="Your email was verified by Supabase, but is not registered in the KRCE directory. Please contact the administrator."
        )

    # Extract user metadata
    bus_id = user.get("bus_id", "")
    role = user.get("role", "student")
    parent_of = user.get("parent_of", "")

    # Generate KRCE JWT Access & Refresh Tokens
    token = make_token(
        uid=user["id"],
        name=user["name"],
        role=role,
        bus_id=bus_id,
        extra={
            "college_id": user.get("college_id", ""),
            "parent_of": parent_of,
            "rfid_card": user.get("rfid_card", ""),
            "phone": user.get("phone", "")
        }
    )
    refresh_token = make_refresh_token(user["id"], user["name"], role)

    return {
        "status": "ok",
        "token": token,
        "refresh_token": refresh_token,
        "user_id": user["id"],
        "name": user["name"],
        "role": role,
        "bus_id": bus_id,
        "college_id": user.get("college_id", "")
    }
```

---

## 4. Mobile App Integration (Flutter)

### 1. Add Supabase Flutter Dependency
In `frontend/krce_bus_flutter/pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.8.0
```

### 2. Configure Credentials (`lib/core/config/app_config.dart`)
```dart
class AppConfig {
  static const String supabaseUrl = 'https://<your-project-ref>.supabase.co';
  static const String supabaseAnonKey = '<your-anon-public-key>';
}
```

### 3. Initialize in Entry Point (`lib/main.dart`)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: KrceBusApp()));
}
```

### 4. Authentication Logic (`lib/core/services/api_service.dart`)
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

// Send OTP to registered email
Future<void> sendSupabaseOtp(String email) async {
  await Supabase.instance.client.auth.signInWithOtp(
    email: email.trim(),
    shouldCreateUser: false, // Prevents non-college user creation
  );
}

// Verify OTP & exchange for KRCE session
Future<Map<String, dynamic>> verifySupabaseOtpAndLogin({
  required String email,
  required String otp,
}) async {
  final res = await Supabase.instance.client.auth.verifyOTP(
    email: email.trim(),
    token: otp.trim(),
    type: OtpType.email,
  );

  if (res.session == null) {
    throw Exception('Verification failed. Invalid or expired OTP.');
  }

  // Exchange with KRCE backend
  final response = await _dio.post(
    '/api/auth/supabase-verify',
    data: {
      'email': email.trim(),
      'supabase_token': res.session!.accessToken,
    },
  );

  return Map<String, dynamic>.from(response.data);
}
```

### 5. Mobile Login UI Flow (`lib/features/auth/screens/login_screen.dart`)
* **Step 1**: User enters their verified email (e.g. `jacob@krce.ac.in`) $\rightarrow$ Tap **Send OTP**.
* **Step 2**: 60-second cooldown timer begins $\rightarrow$ 6-digit PIN input fields appear.
* **Step 3**: On entering the 6th digit, the app auto-verifies with Supabase, exchanges the token with FastAPI, and loads the user's dashboard (`StudentDashboard`, `DriverDashboard`, etc.).

---

## 5. Web Admin Portal Integration (`backend/templates/admin.html`)

Include the Supabase client via CDN in `<head>`:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script>
  const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  async function requestAdminOtp(email) {
    const { error } = await supabase.auth.signInWithOtp({
      email: email,
      options: { shouldCreateUser: false }
    });
    if (error) throw error;
  }

  async function verifyAdminOtp(email, token) {
    const { data, error } = await supabase.auth.verifyOtp({
      email: email,
      token: token,
      type: 'email'
    });
    if (error) throw error;
    return data.session.access_token;
  }
</script>
```

---

## 6. Security & Hardening Checklist

| Security Requirement | Implementation |
| :--- | :--- |
| **No Open Registrations** | `shouldCreateUser: false` ensures only pre-registered college emails can trigger OTPs. |
| **Brute Force Protection** | Supabase locks OTP attempts after 3 incorrect guesses. |
| **Expiration Control** | Strict 5-minute TTL (`300 seconds`). |
| **Deactivated Account Safeguard** | The backend verifies `is_active: 1` in MongoDB on every token exchange. |
| **Replay Protection** | Tokens are single-use and invalidated immediately upon verification. |

---

## 7. Testing Checklist

1. **Successful Student Login**: Send OTP to `jacob@krce.ac.in` $\rightarrow$ Enter OTP $\rightarrow$ Verifies and loads Bus 07 Route G.
2. **Invalid OTP**: Enter `000000` $\rightarrow$ Confirm error snackbar shows `Invalid or expired OTP`.
3. **Expired OTP**: Wait 5 minutes before submitting $\rightarrow$ Confirm rejection.
4. **Unregistered Email**: Attempt OTP with `unknown@gmail.com` $\rightarrow$ Confirm blocked by `shouldCreateUser: false`.
