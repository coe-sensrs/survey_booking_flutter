# 🧠 Project Knowledge Base (Brain Master Index)

**Project:** Survey Desk (`survey_booking_app` / `survey_desk`)  
**Stack:** Flutter 3.x (Dart) + Firebase (Auth, Firestore, Storage, Cloud Functions Node.js 20 2nd Gen, Cloud Messaging) + Riverpod 2.x + GoRouter 17 + Flutter ScreenUtil Plus 1.6 + Hive + Flutter Native Splash  
**Architecture:** 3-Layer MVVM + Feature-First Modularity + SOLID Principles  
**Theme Engine:** Sage & Stone Light & Dark Themes + Persisted Theme Switcher (`themeProvider` + Hive)  
**Target Roles:** Applicant, Admin, Committee Member  

---

## 📌 Master Knowledge Index

| Module / Topic | Description | File Link |
|---|---|---|
| **Architecture & Data Flow** | 3-layer MVVM, feature-first boundary rules, data flow, DIP/ISP, and request lifecycle | [architecture.md](file:///d:/flutter%20projects/survey_booking_app/brain/architecture.md) |
| **Directory & Codebase Map** | Complete workspace directory structure, file responsibilities, and target blueprint | [directory_map.md](file:///d:/flutter%20projects/survey_booking_app/brain/directory_map.md) |
| **Frontend & UI System** | Native splash, animated SplashScreen, 28 Stitch screens, Light/Dark Sage & Stone themes, `flutter_screenutil_plus`, `go_router` | [modules_frontend.md](file:///d:/flutter%20projects/survey_booking_app/brain/modules_frontend.md) |
| **Backend Schema & APIs** | Firestore schema, composite indexes, Storage paths, and 9 Callable Cloud Functions | [backend_api.md](file:///d:/flutter%20projects/survey_booking_app/brain/backend_api.md) |
| **Auth & Security** | Email/pass Auth, custom claims RBAC, Firestore/Storage security rules, rate-limiting transaction | [auth_security.md](file:///d:/flutter%20projects/survey_booking_app/brain/auth_security.md) |
| **Business Logic & Workflows** | 6-state appointment lifecycle, committee review loop, clarification roundtrip, audit log feed | [workflows_business_logic.md](file:///d:/flutter%20projects/survey_booking_app/brain/workflows_business_logic.md) |
| **Integrations & Deployment** | SendGrid email, FCM push, Firebase App Check, Android release & Play Console pipeline | [integrations_deployment.md](file:///d:/flutter%20projects/survey_booking_app/brain/integrations_deployment.md) |
| **Testing, Quality & Monitoring** | Crashlytics breadcrumbs (PII-safe), Performance traces, Analytics, graceful error handling | [testing_quality_monitoring.md](file:///d:/flutter%20projects/survey_booking_app/brain/testing_quality_monitoring.md) |

---

## 📐 System Topology & Core Flow

```mermaid
graph TD
    subgraph Startup ["App Startup Sequence"]
        NS["Native Splash (flutter_native_splash) — Sage #1B3B2B / Dark #0D1611"]
        NS -->|FlutterNativeSplash.preserve()| Main["main.dart (WidgetsBinding → Hive.initFlutter → Firebase.initializeApp → ProviderScope → MaterialApp.router)"]
        Main -->|FlutterNativeSplash.remove()| Nav["GoRouter → /home (redirects to /login if unauthenticated)"]
    end

    subgraph Client ["Flutter Mobile Client (MVVM + Riverpod)"]
        UI["View Layer (ConsumerWidget / ScreenUtilPlusInit)"]
        Theme["Theme Engine (AppTheme Light & Dark + themeProvider + Hive)"]
        VM["ViewModel Layer (Riverpod Notifiers)"]
        Repo["Repository Interfaces (core/repositories)"]
    end

    subgraph Firebase ["Firebase Backend Infrastructure"]
        Auth["Firebase Auth (Custom Claims RBAC)"]
        FS["Cloud Firestore (appointments, users, auditLog, rateLimits)"]
        Storage["Firebase Storage (KML/KMZ, Docs, Admin Photos)"]
        CF["Cloud Functions Node.js 20 2nd Gen"]
    end

    subgraph External ["External Integrations"]
        SG["SendGrid API (Email Notifications)"]
        FCM["Firebase Cloud Messaging (Push)"]
    end

    Nav --> UI
    UI -->|User Actions / Theme Toggle| VM
    VM -->|Theme Persistence| Theme
    VM -->|Abstract Calls| Repo
    Repo -->|Direct SDK| Auth
    Repo -->|Direct SDK| FS
    Repo -->|Direct SDK| Storage
    VM -->|Callable Trigger| CF
    FS -->|Firestore Triggers| CF
    CF -->|SMTP/HTTP| SG
    CF -->|Push Payload| FCM
```

---

## ⚡ Quick Project Context Summary

- **Core Function:** Replaces manual survey appointment bookings with a digital 9-step wizard workflow spanning Applicants, Admins, and Review Committee Members.
- **Current Status:** 
  - **Phase 1 Infrastructure Complete & Verified**: Data models, Abstract Repositories & Concrete Services, `GoRouter` config, shared widgets, static reference asset.
  - **Single-Stage Native Splash**: `flutter_native_splash` generates platform-native Sage & Stone colored splash (Android, iOS, Web). No manual Flutter splash screen.
  - **Light & Dark Theme System**: `AppColors` & `AppTheme`, Riverpod `themeProvider` with Hive persistence, `ThemeToggleButton`.
  - **Screen Scaling**: `flutter_screenutil_plus` (`designSize: Size(375, 812)`, `minTextAdapt: true`, `splitScreenMode: true`, `autoRebuild: false`).
  - **Riverpod DI**: Core providers in `lib/core/providers/core_providers.dart`.
  - **Graceful Error Handling**: Domain Failure hierarchy in `lib/core/errors/failures.dart`.
  - **Verification**: `flutter analyze` passing with 0 errors/warnings.
- **Startup Sequence:** `main()` → `FlutterNativeSplash.preserve()` → `Hive.initFlutter()` → `Firebase.initializeApp()` → `runApp()` → `FlutterNativeSplash.remove()` → `GoRouter` (navigates).
