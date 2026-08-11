# 🗺️ Codebase Directory Map & File Responsibilities

**Parent Index:** [brain.md](file:///d:/flutter%20projects/survey_booking_app/brain/brain.md)

---

## 1. Top-Level Workspace Map

```
d:\flutter projects\survey_booking_app\
├── .agents/                        # AI Agent system rules, skills, workflows, and catalog
├── brain/                          # AI Knowledge Base (Project Brain documentation)
├── docs/                           # Architectural, PRD, TRD, Schema, and Flow design specifications
├── assets/                         # Static reference data (e.g., assets/india_states_districts.json)
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

## 2. Detailed `lib/` Target Blueprint vs Baseline

```
lib/
├── firebase_options.dart              # Auto-generated Firebase configuration (Project ID: surveybookingapp)
├── main.dart                          # Application entry point: Firebase Init, ScreenUtilPlusInit, MaterialApp
│
├── core/                              # Shared application core (NO feature imports allowed)
│   ├── constants/
│   │   ├── app_spacing.dart           # Sage & Stone grid spacing (AppSpacing) & corner radii (AppRadii)
│   │   └── app_enums.dart             # SurveyType, AppointmentStatus, UserRole enums & limits
│   ├── theme/
│   │   └── app_theme.dart             # Sage & Stone Material 3 Light/Dark color schemes & typography
│   ├── models/                        # Plain Dart data models matching backend Firestore schema
│   │   ├── appointment.dart           # Appointment model, XenDetails, Logistics, PermissionDocument, KmlFile
│   │   ├── app_user.dart              # AppUser model (uid, role, email, phone, photoUrl)
│   │   └── audit_log.dart             # AuditLogEntry model
│   ├── repositories/                  # Abstract repository interfaces (DIP & ISP)
│   │   ├── appointment_repository.dart# AppointmentReader & AppointmentWriter interfaces
│   │   ├── user_repository.dart       # UserRepository interface
│   │   └── audit_log_repository.dart  # AuditLogRepository interface
│   ├── services/                      # Concrete Firebase SDK implementations
│   │   ├── firebase_appointment_repository.dart
│   │   ├── firebase_user_repository.dart
│   │   ├── cloud_functions_service.dart
│   │   ├── storage_upload_service.dart
│   │   ├── crash_reporting_service.dart
│   │   └── analytics_service.dart
│   ├── routing/                       # go_router configuration & route registry
│   │   └── app_router.dart
│   ├── layout/                        # AppBreakpoints (Compact, Medium, Expanded)
│   │   └── breakpoints.dart
│   ├── widgets/                       # Reusable UI widgets (buttons, text fields, cards, skeletons)
│   └── utils/                         # Validators (phone 10-digit, email format) & date formatters
│
├── responsive/                        # Baseline layout wrapper components
│   ├── dimensions.dart                # mobileWidth (600), desktopWidth (1200)
│   ├── responsive_layout.dart         # LayoutBuilder builder switching mobileBody / desktopBody
│   ├── mobile_body.dart               # Compact layout scaffold placeholder
│   └── desktop_body.dart              # Desktop layout scaffold placeholder
│
└── features/                          # Feature-first modular views and ViewModels
    ├── auth/                          # Login, Signup, Auth check, Splash
    ├── applicant_home/                # Applicant Home (Scheduled surveys, Recent requests, Activity feed)
    ├── booking_wizard/                # 9-step booking wizard shell & step views (Step 1-9)
    ├── my_bookings/                   # Applicant bookings list & detail
    ├── applicant_profile/             # Applicant profile & contact details
    ├── admin_dashboard/               # Admin dashboard, list filtering, reviewer assignment
    ├── task_assignment/               # Admin post-approval fieldwork task assignment
    ├── committee_management/          # Committee account provisioning & deactivation
    ├── admin_profile/                 # Admin profile & photo upload
    ├── committee_dashboard/           # Committee review assignment dashboard
    └── committee_review/              # Committee detail review (Approve, Reject, Clarify)
```

---

## 3. Existing Baseline Files & Status Map

| File Path | Status | Primary Purpose |
|---|---|---|
| `lib/main.dart` | Initialized | Initializes Firebase SDKs & ScreenUtilPlus; sets up MaterialApp root |
| `lib/firebase_options.dart` | Generated | Multi-platform configuration targets for project `surveybookingapp` |
| `lib/core/theme/app_theme.dart` | Complete | Designer-authored Light & Dark Material 3 theme (`AppTheme.light` / `AppTheme.dark`) |
| `lib/core/constants/app_spacing.dart` | Complete | Grid tokens (`AppSpacing`: xs..xl) & shape tokens (`AppRadii`: base..full) |
| `lib/responsive/responsive_layout.dart` | Initialized | Basic `LayoutBuilder` wrapper matching `mobileWidth` breakpoint |
| `lib/responsive/dimensions.dart` | Initialized | Target breakpoint width definitions (600 / 1200) |
| `pubspec.yaml` | Complete | Package specifications (Riverpod, Dio, Firebase, Hive, go_router, table_calendar, etc.) |
| `firebase.json` | Complete | Mappings for Android app ID `1:458361446708:android:62d6b42068c28c1e354561` |
| `docs/*.md` | Complete | Comprehensive technical specifications, schemas, PRD v2.0, and TRD |

---

## 4. Code Base Dependencies Reference (`pubspec.yaml`)

- **State Management & Routing:** `riverpod: ^3.4.2`, `go_router: ^17.5.0`
- **Firebase Suite:** `firebase_core: ^4.13.0`, `firebase_auth: ^6.5.7`, `firebase_storage: ^13.4.6`, `firebase_messaging: ^16.5.0`, `firebase_crashlytics: ^5.2.7`, `firebase_analytics: ^12.4.6`, `firebase_performance: ^0.11.4+6`
- **UI & Utilities:** `google_fonts: ^8.2.1`, `cached_network_image: ^3.4.1`, `flutter_svg: ^2.3.0`, `flutter_screenutil_plus: ^1.6.0`, `awesome_snackbar_content: ^0.1.8`, `timelines_plus: ^2.0.1`, `table_calendar: ^3.2.1`, `share_plus: ^13.3.0`, `feedback: ^3.2.0`, `flutter_local_notifications: ^22.3.0`, `hive: ^2.2.3`, `dio: ^5.11.0`
