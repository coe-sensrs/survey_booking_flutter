# 🗺️ Codebase Directory Map & File Responsibilities

**Parent Index:** [brain.md](file:///d:/flutter%20projects/survey_booking_app/brain/brain.md)

---

## 1. Top-Level Workspace Map

```
d:\flutter projects\survey_booking_app\
├── .agents/                        # AI Agent system rules, skills, workflows, and catalog
├── brain/                          # AI Knowledge Base (Project Brain documentation)
├── docs/                           # Architectural, PRD, TRD, Schema, Flow, and Stitch Design Catalog
│   └── stitch_assets/              # Downloaded 28 Stitch screen images, HTML files, and STITCH_DESIGN_CATALOG.md
├── assets/                         # Static reference data (assets/india_states_districts.json)
├── lib/                            # Main Application Dart source code
├── test/                           # Widget and Unit test specifications
├── web/                            # Web platform scaffolding & PWA manifests
├── android/                        # Android native platform project & Gradle builds
├── ios/                            # iOS native platform project & Runner configuration
├── analysis_options.yaml           # Static analysis and lint rules configuration
├── firebase.json                   # Firebase CLI project and platform target mappings
├── pubspec.yaml                    # Package dependencies, SDK constraints, and asset manifests
└── README.md                       # Project quickstart guide
```

---

## 2. Detailed `lib/` Architecture Map

```
lib/
├── firebase_options.dart              # Auto-generated Firebase configuration (Project ID: surveybookingapp)
├── main.dart                          # App Entry: ProviderScope, Hive.initFlutter(), ScreenUtilPlusInit, MaterialApp.router
│
├── core/                              # Shared application core (NO feature imports allowed)
│   ├── constants/
│   │   ├── survey_type.dart           # SurveyType enum
│   │   ├── appointment_status.dart    # AppointmentStatus enum
│   │   └── validation_constants.dart  # Form limits, string lengths, doc count (1-5) and 5MB size limits
│   ├── errors/
│   │   └── failures.dart              # Domain Failure classes (NetworkFailure, AuthFailure, RateLimitFailure, etc.)
│   ├── providers/
│   │   └── core_providers.dart        # Riverpod DI providers for repositories and services
│   ├── theme/
│   │   ├── app_colors.dart            # Sage & Stone Light & Dark color palettes & aliases
│   │   ├── app_theme.dart             # AppTheme.lightTheme & AppTheme.darkTheme (ResponsiveTheme.fromTheme)
│   │   └── theme_provider.dart        # themeProvider (ThemeNotifier with Riverpod + Hive persistence)
│   ├── models/                        # Plain Dart data models matching backend Firestore schema
│   │   ├── app_user.dart              # AppUser model (uid, role, email, phone, photoUrl)
│   │   ├── appointment.dart           # Appointment model
│   │   ├── xen_details.dart           # XenDetails map model
│   │   ├── logistics.dart             # Logistics map model
│   │   ├── kml_file.dart              # KmlFile map model
│   │   ├── permission_document.dart   # PermissionDocument map model
│   │   └── audit_log_entry.dart       # AuditLogEntry model
│   ├── repositories/                  # Abstract repository interfaces (DIP & ISP)
│   │   ├── appointment_repository.dart# AppointmentReader & AppointmentWriter segregated interfaces
│   │   ├── user_repository.dart       # UserRepository interface
│   │   └── audit_log_repository.dart  # AuditLogRepository interface
│   ├── services/                      # Concrete Firebase SDK implementations
│   │   ├── firebase_appointment_repository.dart
│   │   ├── firebase_user_repository.dart
│   │   ├── firebase_audit_log_repository.dart
│   │   ├── storage_upload_service.dart
│   │   ├── file_open_service.dart
│   │   ├── crash_reporting_service.dart
│   │   └── analytics_service.dart
│   ├── routing/                       # go_router configuration & route registry
│   │   └── app_router.dart
│   ├── layout/                        # AppBreakpoints (Compact <600dp, Medium 600-840dp, Expanded >840dp)
│   │   └── app_breakpoints.dart
│   └── widgets/                       # Reusable UI widgets
│       ├── app_button.dart
│       ├── app_text_field.dart
│       ├── empty_state.dart
│       └── theme_toggle_button.dart
│
└── features/                          # Feature-first modular views and ViewModels
    ├── auth/                          # Authentication module
    │   └── view/
    │       └── splash_screen.dart     # Animated Sage & Stone Splash screen & Auth session checker
    ├── applicant_home/                # Applicant Home (Scheduled surveys, Recent requests, Activity feed)
    ├── booking_wizard/                # 9-step booking wizard shell & step views (Step 1-9)
    ├── my_bookings/                   # Applicant bookings list & detail
    ├── applicant_profile/             # Applicant profile & contact details
    ├── admin_dashboard/               # Admin dashboard, list filtering, reviewer assignment
    ├── task_assignment/               # Admin post-approval fieldwork task assignment
    ├── committee_management/          # Committee account provisioning & deactivation
    ├── admin_profile/                 # Admin profile & photo upload
    ├── committee_dashboard/           # Committee review assignment dashboard
    ├── committee_review/              # Committee detail review (Approve, Reject, Clarify)
    └── assigned_tasks/                # Committee Fieldwork Tasks Queue
```

---

## 3. Implemented Files & Status Map

| File Path | Status | Primary Purpose |
|---|---|---|
| `lib/features/auth/view/splash_screen.dart` | Complete | Animated Sage & Stone Splash Screen with logo scale/fade and session check |
| `lib/core/routing/app_router.dart` | Complete | `GoRouter` setup routing `AppRoutes.splash` to `SplashScreen` |
| `lib/core/providers/core_providers.dart` | Complete | Riverpod DI providers for repositories and services |
| `lib/core/errors/failures.dart` | Complete | Domain Failure hierarchy (`NetworkFailure`, `AuthFailure`, etc.) |
| `lib/main.dart` | Complete | ProviderScope, Hive init, ScreenUtilPlusInit, MaterialApp.router |
| `lib/core/theme/app_colors.dart` | Complete | Light & Dark Sage & Stone color tokens & backward-compatible aliases |
| `lib/core/theme/app_theme.dart` | Complete | Light & Dark Material 3 theme (`AppTheme.lightTheme` & `AppTheme.darkTheme`) |
| `lib/core/theme/theme_provider.dart` | Complete | `themeProvider` (`ThemeNotifier`) with Hive persistence |
| `lib/core/widgets/theme_toggle_button.dart` | Complete | Reusable Light/Dark theme toggle IconButton |
