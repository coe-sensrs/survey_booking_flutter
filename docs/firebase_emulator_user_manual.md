# Firebase Local Emulator Suite — Complete User Manual

> **Project:** Survey Booking App / Survey Desk  
> **Target Audience:** Developers, QA Engineers, and DevOps  
> **Last Updated:** September 2026

---

## 📑 Table of Contents

1. [Overview & Architecture](#1-overview--architecture)
2. [Port Allocation & Architecture Matrix](#2-port-allocation--architecture-matrix)
3. [Prerequisites & System Setup](#3-prerequisites--system-setup)
4. [Project Configuration](#4-project-configuration)
5. [Starting & Managing Emulators](#5-starting--managing-emulators)
6. [Connecting the Flutter Client](#6-connecting-the-flutter-client)
7. [Running Automated Tests](#7-running-automated-tests)
8. [Manual Testing via Emulator Suite UI & REST](#8-manual-testing-via-emulator-suite-ui--rest)
9. [Data Persistence & Mock Data Seeding](#9-data-persistence--mock-data-seeding)
10. [Troubleshooting & Common Pitfalls](#10-troubleshooting--common-pitfalls)

---

## 1. Overview & Architecture

The **Firebase Local Emulator Suite** is a companion toolchain that replicates Google Cloud & Firebase production services entirely on your local machine. 

Using the emulator suite allows you to:
- **Test Security Rules locally:** Verify granular permissions for Cloud Firestore (`firestore.rules`) and Cloud Storage (`storage.rules`) without polluting production or incurring cloud costs.
- **Develop & Debug Cloud Functions:** Test 2nd-generation Cloud Functions (`onCall` HTTP triggers, rate limiting, background tasks) with hot-reloading.
- **Run Offline & Isolated:** Execute end-to-end user journeys (registration, appointment booking, file uploads, reviews) without internet access.
- **Automate CI/CD:** Run Jest unit and integration test suites in headless environments with 100% deterministic test data.

```
+-----------------------------------------------------------------------------------+
|                              LOCAL WORKSTATION                                    |
|                                                                                   |
|  +---------------------------+             +-----------------------------------+  |
|  |     Flutter Client        |             |        Jest Test Suite            |  |
|  | (Android / iOS / Desktop) |             | (Firestore, Storage, Functions)   |  |
|  +-------------+-------------+             +-----------------+-----------------+  |
|                |                                             |                    |
|                | (--dart-define=USE_FIREBASE_EMULATOR=true)  | (npm test)         |
|                v                                             v                    |
|  +-----------------------------------------------------------------------------+  |
|  |                       Firebase Emulator Suite                               |  |
|  |  +------------------+  +-------------------+  +--------------------------+  |  |
|  |  | Auth (Port 9099) |  |  Firestore (8080) |  |  Storage (Port 9199)     |  |  |
|  |  +------------------+  +-------------------+  +--------------------------+  |  |
|  |  | Functions (5001) |  |  Emulator UI (4000)                               |  |
|  |  +------------------+  +-------------------------------------------------+  |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 2. Port Allocation & Architecture Matrix

Defined in [`firebase.json`](file:///d:/flutter%20projects/survey_booking_app/firebase.json):

| Service | Port | Protocol / URL | Description |
| :--- | :--- | :--- | :--- |
| **Emulator Suite UI** | `4000` | `http://127.0.0.1:4000` | Web UI to view Auth users, Firestore documents, Storage buckets, and logs |
| **Cloud Functions** | `5001` | `http://127.0.0.1:5001` | 2nd-Gen HTTP Callable endpoints (`/survey-desk-test/us-central1/...`) |
| **Cloud Firestore** | `8080` | `http://127.0.0.1:8080` | Local NoSQL document database emulator |
| **Firebase Auth** | `9099` | `http://127.0.0.1:9099` | Local Identity Platform emulator with custom token and JWT support |
| **Cloud Storage** | `9199` | `http://127.0.0.1:9199` | Local Google Cloud Storage bucket emulator |

---

## 3. Prerequisites & System Setup

Before running the emulators, verify the following tools are installed on your machine:

### 3.1. Java Runtime Environment (JRE)
Firestore and Cloud Storage emulators run on Java.
- Requires **Java 11 or higher** (OpenJDK recommended).
- Check installation:
  ```powershell
  java -version
  ```
- *If not installed (Windows):* Install via `winget install Microsoft.OpenJDK.17` or download from [Adoptium Temurin](https://adoptium.net/).

### 3.2. Node.js & npm
- Requires **Node.js v18.x or v20.x+** (Node 22 LTS supported).
- Check installation:
  ```powershell
  node -v
  npm -v
  ```

### 3.3. Firebase CLI
- Install the CLI globally:
  ```powershell
  npm install -g firebase-tools
  ```
- Verify CLI version:
  ```powershell
  firebase --version
  ```

---

## 4. Project Configuration

### 4.1. Install Cloud Functions Dependencies
From the repository root:
```powershell
cd functions
npm install
npm run build
cd ..
```

### 4.2. Configure Local Secret Mock (`functions/.secret.local`)
Cloud Functions utilize Google Cloud Secret Manager (`defineSecret("AUTH_WEB_API_KEY")`). The emulator needs a local secret file so that secret manager calls don't attempt to connect to production cloud APIs.

Ensure [`functions/.secret.local`](file:///d:/flutter%20projects/survey_booking_app/functions/.secret.local) exists with:
```properties
AUTH_WEB_API_KEY=AIzaSyDVfBAL_-Iz_US3R7g2rzSGi4FNuj1v5sg
```
*(Note: `*.local` is already included in `.gitignore` and `firebase.json` ignore rules).*

### 4.3. Install Testing Suite Dependencies
From the repository root:
```powershell
cd firebase/tests
npm install
cd ../..
```

---

## 5. Starting & Managing Emulators

### 5.1. Start All Services (With Web UI)
Start all configured emulators using the dedicated testing project ID (`survey-desk-test`):

```powershell
firebase emulators:start --project survey-desk-test
```

Once started:
- Open your browser to **`http://127.0.0.1:4000`** to access the **Emulator Suite UI**.
- Press `Ctrl + C` in the terminal to cleanly terminate all services.

### 5.2. Start Specific Services Only
If you are only developing Cloud Functions and Firestore rules:
```powershell
firebase emulators:start --project survey-desk-test --only auth,firestore,functions
```

### 5.3. Inspecting Logs
- Emulator logs appear in real time in the terminal.
- Cloud Functions logs are also rendered in the UI at `http://127.0.0.1:4000/logs`.
- Detailed Firestore engine logs are saved to `firestore-debug.log`.

---

## 6. Connecting the Flutter Client

The Flutter app includes built-in, production-safe emulator bridging via [`lib/core/firebase/firebase_emulator.dart`](file:///d:/flutter%20projects/survey_booking_app/lib/core/firebase/firebase_emulator.dart).

### 6.1. How It Works
1. In [`lib/main.dart`](file:///d:/flutter%20projects/survey_booking_app/lib/main.dart), the app evaluates `FirebaseEmulator.kUseFirebaseEmulator`:
   ```dart
   if (FirebaseEmulator.kUseFirebaseEmulator) {
     await FirebaseEmulator.connect();
   } else {
     await FirebaseAppCheckSetup.initialize();
   }
   ```
2. In emulator mode, **Firebase App Check is automatically bypassed** so that calls to Callable Cloud Functions succeed without needing attestation tokens.
3. Auth, Firestore, Storage, and Functions SDK clients are redirected to the respective emulator ports.

### 6.2. Network Addressing (Host vs. Device)

| Platform | Host IP in `firebase_emulator.dart` | Notes |
| :--- | :--- | :--- |
| **Android Emulator** | `10.0.2.2` *(Default)* | The official Android emulator routes `10.0.2.2` to the host machine's `127.0.0.1`. |
| **iOS Simulator** | `localhost` or `127.0.0.1` | Runs directly on the host network. |
| **Physical Device (USB)** | `localhost` + `adb reverse` | Run port reversing via USB (see below). |
| **Physical Device (LAN)** | `192.168.x.x` (Your PC IP) | Ensure Windows Defender / Firewall allows inbound connections on ports 8080, 9099, 9199, 5001. |

#### For Physical Android Devices via USB (Recommended):
Run the following commands in PowerShell with your phone connected via USB debugging:
```powershell
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:9199 tcp:9199
adb reverse tcp:5001 tcp:5001
```
*(Then change `_emulatorHost` in [`firebase_emulator.dart`](file:///d:/flutter%20projects/survey_booking_app/lib/core/firebase/firebase_emulator.dart) to `'localhost'` or `'127.0.0.1'`).*

### 6.3. Running Flutter with the Emulator Flag
Launch Flutter passing `--dart-define=USE_FIREBASE_EMULATOR=true`:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

#### VS Code `launch.json` Configuration
Add the following configuration to your `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Survey Desk (Local Emulator)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=USE_FIREBASE_EMULATOR=true"
      ]
    },
    {
      "name": "Survey Desk (Production)",
      "request": "launch",
      "type": "dart"
    }
  ]
}
```

---

## 7. Running Automated Tests

The testing suite inside [`firebase/tests/`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/) contains comprehensive test coverage:
- **Firestore Security Rules:** [`appointments.rules.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/firestore/appointments.rules.test.js), [`users.rules.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/firestore/users.rules.test.js), [`rate_limits.rules.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/firestore/rate_limits.rules.test.js), [`audit_log.rules.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/firestore/audit_log.rules.test.js).
- **Storage Security Rules:** [`appointment_files.rules.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/storage/appointment_files.rules.test.js), [`profile_photo.rules.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/storage/profile_photo.rules.test.js).
- **Cloud Functions Authorization & Concurrency:** [`authz.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/functions/authz.test.js), [`race_condition.test.js`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/functions/race_condition.test.js).

### Method A: Single Command Execution (`firebase emulators:exec`)
*Ideal for CI/CD and one-shot local verification. Spawns emulators, runs tests, and shuts down automatically.*

#### 1. Run All Cloud Functions Tests (Authorization & Concurrency)
```powershell
firebase emulators:exec --project survey-desk-test --only auth,firestore,functions "npm --prefix firebase/tests run test:functions"
```

#### 2. Run Firestore Security Rules Tests
```powershell
firebase emulators:exec --project survey-desk-test --only firestore "npm --prefix firebase/tests run test:firestore"
```

#### 3. Run Storage Security Rules Tests
```powershell
firebase emulators:exec --project survey-desk-test --only firestore,storage "npm --prefix firebase/tests run test:storage"
```

#### 4. Run the Full Test Suite
```powershell
firebase emulators:exec --project survey-desk-test --only auth,firestore,storage,functions "npm --prefix firebase/tests test"
```

---

### Method B: Persistent Development Session (Interactive / Watch Mode)
*Ideal while modifying rules, functions, or writing new tests.*

1. **Terminal 1: Start Emulators**
   ```powershell
   firebase emulators:start --project survey-desk-test
   ```
2. **Terminal 2: Run Tests on Demand**
   ```powershell
   cd firebase/tests

   # Run all function tests
   npm run test:functions

   # Run tests in watch mode (re-runs on file changes)
   npm run test:watch
   ```

---

## 8. Manual Testing via Emulator Suite UI & REST

### 8.1. Inspecting Data in the UI (`http://127.0.0.1:4000`)
- **Authentication (`/auth`):**
  - Manually create test accounts with custom UIDs.
  - Set custom user claims directly in the UI (e.g., `{"role": "admin"}` or `{"role": "committee_reviewer"}`).
  - Toggle email verification state (`emailVerified: true`).
- **Firestore (`/firestore`):**
  - View documents in `users`, `appointments`, `audit_logs`, and `rate_limits`.
  - Add or delete documents manually to test reactive Flutter UI updates.
- **Storage (`/storage`):**
  - View bucket `surveybookingapp.firebasestorage.app`.
  - Inspect uploaded appointment documents, KML boundary files, and profile photos.

### 8.2. Calling Cloud Functions via cURL / PowerShell

Cloud Functions are accessible as standard HTTP POST endpoints:

```powershell
# Example: Calling requestPasswordReset
curl -X POST http://127.0.0.1:5001/survey-desk-test/us-central1/requestPasswordReset `
  -H "Content-Type: application/json" `
  -d '{"data": {"email": "applicant@test.com"}}'
```

#### Authenticated Callable Requests
To invoke functions requiring authentication (`submitAppointment`, `createCommitteeAccount`):

1. **Obtain an ID Token from the Auth Emulator:**
   ```powershell
   $response = Invoke-RestMethod -Uri "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key" `
     -Method Post `
     -ContentType "application/json" `
     -Body '{"email":"applicant@test.com","password":"Password123!","returnSecureToken":true}'
   $idToken = $response.idToken
   ```

2. **Send Callable Request with Bearer Token:**
   ```powershell
   $body = @{
     data = @{
       surveyType = "Cadastral"
       state = "Punjab"
       district = "Ludhiana"
       areaName = "Sector 32"
       preferredDate = "2026-10-15T10:00:00.000Z"
       kmlFileUrl = "https://example.com/boundary.kml"
       supportingDocUrls = @("https://example.com/doc1.pdf")
     }
   } | ConvertTo-Json

   Invoke-RestMethod -Uri "http://127.0.0.1:5001/survey-desk-test/us-central1/submitAppointment" `
     -Method Post `
     -Headers @{ "Authorization" = "Bearer $idToken"; "Content-Type" = "application/json" } `
     -Body $body
   ```

---

## 9. Data Persistence & Mock Data Seeding

By default, the emulator runs in-memory and wipes all data when stopped. You can persist and reload data across sessions.

### 9.1. Export on Exit
Save all current users, Firestore records, and uploaded files when closing the emulator:
```powershell
firebase emulators:start --project survey-desk-test --export-on-exit=./emulator-data
```

### 9.2. Import Existing Data on Start
Start with seeded data:
```powershell
firebase emulators:start --project survey-desk-test --import=./emulator-data
```

### 9.3. Continuous Development Workflow
Combine both flags to load previous state and continuously save new changes:
```powershell
firebase emulators:start --project survey-desk-test --import=./emulator-data --export-on-exit=./emulator-data
```

---

## 10. Troubleshooting & Common Pitfalls

### Issue 1: `connect ECONNREFUSED 127.0.0.1:5001`
- **Cause:** Cloud Functions tests were executed without the emulator running.
- **Fix:** Either start emulators first (`firebase emulators:start`) or wrap the command with `firebase emulators:exec`.

### Issue 2: `Port 8080 (or 9099 / 5001) is already in use`
- **Cause:** An earlier emulator process or background task did not terminate cleanly.
- **Fix (Windows):** Find and kill the process occupying the port:
  ```powershell
  # Find PID for port 8080
  Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess | Stop-Process -Force
  ```

### Issue 3: Custom Token vs. ID Token in 2nd Gen Callables
- **Cause:** Calling `admin.auth().createCustomToken()` produces a custom JWT minted by a service account. Passing it directly to Callable functions leaves `request.auth.token.role` undefined.
- **Fix:** In tests or custom scripts, exchange custom tokens for ID tokens via the Auth emulator's `accounts:signInWithCustomToken` endpoint before calling functions (implemented in [`test_helpers.js:getIdTokenForUser`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/functions/test_helpers.js)).

### Issue 4: Secret Manager `403 Forbidden`
- **Cause:** Functions calling `defineSecret("AUTH_WEB_API_KEY")` attempt to connect to Cloud Secret Manager if no local mock is provided.
- **Fix:** Ensure [`functions/.secret.local`](file:///d:/flutter%20projects/survey_booking_app/functions/.secret.local) exists with a mock key.

### Issue 5: App Check Rejections in Flutter
- **Cause:** App Check token is missing or rejected when calling Cloud Functions locally.
- **Fix:** Verify you are running Flutter with `--dart-define=USE_FIREBASE_EMULATOR=true`. [`main.dart`](file:///d:/flutter%20projects/survey_booking_app/lib/main.dart) bypasses `FirebaseAppCheckSetup.initialize()` when this flag is active.

### Issue 6: Java Not Found
- **Symptom:** `Error: An error occurred while checking for Java. Please make sure Java is installed and on your system PATH.`
- **Fix:** Install OpenJDK 17+ and verify `java -version` works in your terminal. Set `JAVA_HOME` environment variable if needed.

---

## 11. Quick Reference Commands Cheatsheet

```powershell
# 1. Compile Cloud Functions
npm --prefix functions run build

# 2. Run Functions Tests (One-liner)
firebase emulators:exec --project survey-desk-test --only auth,firestore,functions "npm --prefix firebase/tests run test:functions"

# 3. Run Firestore Tests (One-liner)
firebase emulators:exec --project survey-desk-test --only firestore "npm --prefix firebase/tests run test:firestore"

# 4. Start Emulators with UI
firebase emulators:start --project survey-desk-test

# 5. Launch Flutter App in Emulator Mode
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```
