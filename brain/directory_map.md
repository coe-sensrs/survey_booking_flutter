# 🗺️ Codebase Directory Map & File Responsibilities

**Parent Index:** [brain.md](file:///d:/flutter%20projects/survey_booking_app/brain/brain.md)

---

## 1. Top-Level Workspace Map

```
d:\flutter projects\survey_booking_app\
├── .agents/                        # AI Agent system rules, skills, workflows, and catalog
├── brain/                          # AI Knowledge Base (Project Brain documentation)
├── docs/                           # Architectural, PRD, TRD, Schema, Flow, and Emulator Manual
│   ├── firebase_emulator_user_manual.md # Complete Firebase Emulator Suite operations & testing user manual
│   └── stitch_assets/              # Downloaded 28 Stitch screen images, HTML files, and STITCH_DESIGN_CATALOG.md
├── assets/                         # Static reference data (assets/india_states_districts.json)
├── lib/                            # Main Application Dart source code
├── test/                           # Widget, Unit, and Integration test specifications
│   └── integration/                # Emulator integration tests (firebase_emulator_test.dart)
├── firebase/                       # Firebase configuration and test specifications
│   └── tests/                      # Automated Rules & Functions Test Suite (108 assertions across 8 suites)
│       ├── firestore/              # Firestore rules test suites (users, appointments, audit_log, rate_limits)
│       ├── storage/                # Storage rules test suites (appointment_files, profile_photo)
│       └── functions/              # Cloud Functions auth & concurrency tests (authz, race_condition, test_helpers)
├── functions/                      # Firebase Cloud Functions (TypeScript Node.js 22 2nd Gen)
│   └── .secret.local               # Local Secret Manager mock key for emulator (AUTH_WEB_API_KEY)
├── web/                            # Web platform scaffolding & PWA manifests
├── android/                        # Android native platform project & Gradle builds
├── ios/                            # iOS native platform project & Runner configuration
├── analysis_options.yaml           # Static analysis and lint rules configuration
├── firebase.json                   # Firebase CLI project and platform target mappings
├── firestore.rules                 # Cloud Firestore security rules
├── storage.rules                   # Firebase Cloud Storage security rules
├── pubspec.yaml                    # Package dependencies, SDK constraints, and asset manifests
└── README.md                       # Project quickstart guide
```

---

## 2. Detailed `lib/` Architecture Map

```
lib/
├── firebase_options.dart              # Auto-generated Firebase configuration (Project ID: surveybookingapp)
├── main.dart                          # App Entry: ProviderScope, HiveStorageService.init(), ScreenUtilPlusInit, MaterialApp.router
│
├── core/                              # Shared application core (NO feature imports allowed)
│   ├── firebase/
│   │   └── firebase_emulator.dart     # FirebaseEmulator connection helper (ports 9099, 8080, 9199, 5001)
│   ├── constants/
│   │   ├── survey_type.dart           # SurveyType enum
│   │   ├── appointment_status.dart    # AppointmentStatus enum
│   │   └── validation_constants.dart  # Form limits, string lengths, doc count (0-5 optional) and 5MB size limits
│   ├── errors/
│   │   └── failures.dart              # Domain Failure classes (NetworkFailure, AuthFailure, RateLimitFailure, etc.)
│   ├── providers/
│   │   └── core_providers.dart        # Riverpod DI providers for repositories and services
│   ├── theme/
│   │   ├── app_colors.dart            # Sage & Stone Light & Dark color palettes & aliases
│   │   ├── app_theme.dart             # AppTheme.lightTheme & AppTheme.darkTheme (ResponsiveTheme.fromTheme)
│   │   └── theme_provider.dart        # themeProvider (ThemeNotifier with Riverpod + Hive persistence)
│   ├── models/                        # Plain Dart data models matching backend Firestore schema
│   │   ├── app_user.dart              # AppUser model (uid, role, email, phone, photoUrl, expertiseTag, active)
│   │   ├── appointment.dart           # Appointment model
│   │   ├── xen_details.dart           # XenDetails map model
│   │   ├── logistics.dart             # Logistics map model
│   │   ├── kml_file.dart              # KmlFile map model
│   │   ├── permission_document.dart   # PermissionDocument map model
│   │   ├── notification_message.dart  # NotificationMessage model & NotificationType enum
│   │   └── audit_log_entry.dart       # AuditLogEntry model
│   ├── repositories/                  # Abstract repository interfaces (DIP & ISP)
│   │   ├── appointment_repository.dart# AppointmentReader & AppointmentWriter segregated interfaces
│   │   ├── user_repository.dart       # UserRepository interface
│   │   ├── notification_repository.dart # NotificationRepository token registration interface
│   │   └── audit_log_repository.dart  # AuditLogRepository interface
│   ├── services/                      # Concrete Firebase SDK & local storage implementations
│   │   ├── notification_service.dart  # Abstract push notification service interface
│   │   ├── firebase_notification_service.dart # Concrete FirebaseMessaging implementation & token lifecycle
│   │   ├── hive_storage_service.dart  # Centralized Hive storage service (settingsBox, wizard_draft_box, cacheBox)
│   │   ├── admin_functions_service.dart # Admin Cloud Functions execution wrapper (claim check, token refresh, Failure mapping)
│   │   ├── auth_functions_service.dart  # Unauthenticated Auth Cloud Functions wrapper (authenticateUser, registerApplicant, requestPasswordReset)
│   │   ├── firebase_appointment_repository.dart
│   │   ├── firebase_user_repository.dart
│   │   ├── firebase_audit_log_repository.dart
│   │   ├── storage_upload_service.dart
│   │   ├── document_action_service.dart # Centralized service for secure download URL fetching, Dio file caching, sharing & open
│   │   ├── file_open_service.dart
│   │   ├── crash_reporting_service.dart
│   │   └── analytics_service.dart
│   ├── routing/                       # go_router configuration & role-based routing registry
│   │   ├── app_router.dart
│   │   └── notification_navigation.dart # Auth-aware deep linking router mapping notification types to routes
│   ├── utils/                         # Helper utilities
│   │   ├── app_snackbar.dart          # AppSnackbar helper (awesome_snackbar_content + scaffoldMessengerKey)
│   │   ├── sanitizing_text_input_formatter.dart
│   │   └── validators.dart
│   └── widgets/                       # Reusable UI widgets
│       ├── app_button.dart
│       ├── app_text_field.dart
│       ├── empty_state.dart
│       ├── safe_profile_avatar.dart   # App Check & error-resilient profile avatar
│       ├── theme_toggle_button.dart
│       ├── appointment_status_badge.dart # Centralized status badge widget
│       ├── appointment_booking_card.dart # Shared appointment booking card widget
│       ├── survey_document_tiles.dart    # Shared SurveyDocumentTile & KmlFileTile components
│       └── pdf_viewer_screen.dart        # Centralized PDF Viewer screen (flutter_pdfview + download/share)
│
└── features/                          # Feature-first modular views and ViewModels
    ├── auth/                          # Authentication module
    │   ├── view/
    │   │   ├── splash_screen.dart
    │   │   ├── applicant_login_screen.dart
    │   │   ├── applicant_signup_screen.dart
    │   │   ├── admin_login_screen.dart
    │   │   └── email_verification_screen.dart
    │   └── viewmodel/auth_viewmodel.dart
    ├── applicant_home/                # Applicant Home (Scheduled surveys, Recent requests, Activity feed)
    │   ├── view/
    │   │   ├── applicant_shell_screen.dart # Persistent 4-tab bottom navigation shell
    │   │   └── home_screen.dart
    │   └── viewmodel/home_viewmodel.dart
    ├── booking_wizard/                # 9-step booking wizard shell & step views (Step 1-9)
    │   ├── view/
    │   │   ├── booking_wizard_screen.dart
    │   │   └── steps/step_*.dart
    │   └── viewmodel/booking_wizard_viewmodel.dart
    ├── my_bookings/                   # Applicant bookings list, tab detail & single detail
    │   ├── view/
    │   │   ├── my_bookings_screen.dart
    │   │   ├── appointment_detail_screen.dart
    │   │   └── appointment_detail_tab_screen.dart
    │   └── viewmodel/my_bookings_viewmodel.dart
    ├── profile/                       # Profile, photo upload, theme toggle, and sign-out
    │   ├── view/profile_screen.dart
    │   └── viewmodel/profile_viewmodel.dart
    ├── admin_dashboard/               # Admin dashboard, list filtering, status counters
    │   ├── view/
    │   │   ├── admin_shell_screen.dart # Persistent 4-tab admin bottom navigation
    │   │   └── admin_dashboard_screen.dart # Stitch #17 dashboard
    │   └── viewmodel/admin_dashboard_viewmodel.dart
    ├── committee_management/          # Committee account provisioning & directory
    │   ├── view/
    │   │   ├── committee_management_screen.dart # Stitch #18
    │   │   └── add_committee_member_screen.dart # Stitch #19
    │   └── viewmodel/committee_management_viewmodel.dart
    ├── admin_appointment_detail/      # Admin appointment inspection & modal action sheets
    │   ├── view/
    │   │   ├── admin_appointment_detail_screen.dart # Stitch #20 & #21
    │   │   └── widgets/
    │   │       ├── assign_reviewer_sheet.dart # Modal sheet to assign reviewer
    │   │       ├── assign_task_sheet.dart     # Modal sheet to assign fieldwork task
    │   │       └── set_confirmed_date_sheet.dart # Modal sheet to edit confirmed date
    │   └── viewmodel/admin_appointment_detail_viewmodel.dart
    ├── committee_dashboard/           # Committee review assignment dashboard & persistent shell
    │   ├── view/
    │   │   ├── committee_shell_screen.dart # Persistent 3-tab committee shell
    │   │   └── committee_dashboard_screen.dart # Stitch #22 review assignments dashboard
    │   └── viewmodel/committee_dashboard_viewmodel.dart
    ├── committee_review_detail/       # Committee decision portal (Approve, Reject, Clarify)
    │   ├── view/committee_review_detail_screen.dart # Stitch #23, #24, #25, #26
    │   └── viewmodel/committee_review_detail_viewmodel.dart
    ├── assigned_tasks/                # Committee Fieldwork Tasks Queue
│   │   ├── view/assigned_tasks_screen.dart # Stitch #28 fieldwork queue
│   │   └── viewmodel/assigned_tasks_viewmodel.dart
│   └── notifications/                 # In-app notification overlays and launch handlers
│       ├── view/
│       │   ├── notification_handler.dart # Background tap & terminated state launch listener
│       │   └── notification_overlay.dart # Foreground top-sliding banner overlay & wrapper
│       └── viewmodel/notification_viewmodel.dart # Active foreground notification state
```

---

## 3. Implemented Files & Status Map

| File Path | Status | Primary Purpose |
|---|---|---|
| `lib/features/auth/view/splash_screen.dart` | Complete | Animated Sage & Stone Splash Screen with logo scale/fade and session check |
| `lib/core/routing/app_router.dart` | Complete | `GoRouter` setup with 3 shells (Applicant, Admin, Committee), full-screen routes, and role-based redirects |
| `lib/core/providers/core_providers.dart` | Complete | Riverpod DI providers for repositories and services |
| `lib/core/errors/failures.dart` | Complete | Domain Failure hierarchy (`NetworkFailure`, `AuthFailure`, `AuthRateLimitFailure` with lockout seconds, `ValidationFailure`, etc.) |
| `lib/main.dart` | Complete | ProviderScope, Hive init, ScreenUtilPlusInit, MaterialApp.router |
| `lib/core/theme/app_colors.dart` | Complete | Light & Dark Sage & Stone color tokens & backward-compatible aliases |
| `lib/core/theme/app_theme.dart` | Complete | Light & Dark Material 3 theme (`AppTheme.lightTheme` & `AppTheme.darkTheme`) |
| `lib/core/services/hive_storage_service.dart` | Complete | Centralized Hive local storage service (theme, wizard draft, offline cache) |
| `lib/core/services/admin_functions_service.dart` | Complete | Dedicated admin Cloud Functions gateway with pre-flight RBAC, forced token refresh, and Failure translation |
| `lib/core/services/auth_functions_service.dart` | Complete | Dedicated unauthenticated Cloud Functions gateway for `authenticateUser`, `registerApplicant`, and `requestPasswordReset` |
| `lib/core/theme/theme_provider.dart` | Complete | `themeProvider` (`ThemeNotifier`) with HiveStorageService persistence |
| `lib/core/widgets/theme_toggle_button.dart` | Complete | Reusable Light/Dark theme toggle IconButton |
| `lib/core/widgets/appointment_status_badge.dart` | Complete | Centralized semantic appointment status badge widget across all screens |
| `lib/core/widgets/appointment_booking_card.dart` | Complete | Shared appointment booking card widget for home and booking list views |
| `lib/core/utils/app_snackbar.dart` | Complete | Centralized `AppSnackbar` service powered by `awesome_snackbar_content` |
| `lib/features/applicant_home/view/applicant_shell_screen.dart` | Complete | Persistent 4-tab bottom navigation (Home, Bookings, Details, Profile) |
| `lib/features/applicant_home/viewmodel/home_viewmodel.dart` | Complete | Home dashboard viewmodel fetching upcoming surveys, recent requests, and activity feed |
| `lib/features/applicant_home/view/home_screen.dart` | Complete | Applicant home screen matching Stitch #4 & #5 |
| `lib/features/my_bookings/viewmodel/my_bookings_viewmodel.dart` | Complete | Booking list viewmodel with status filtering and clarification reply submit |
| `lib/features/my_bookings/view/my_bookings_screen.dart` | Complete | My Bookings filterable list screen matching Stitch #6 |
| `lib/features/my_bookings/view/appointment_detail_screen.dart` | Complete | Full read view for appointments with clarification reply form matching Stitch #7 |
| `lib/features/my_bookings/view/appointment_detail_tab_screen.dart` | Complete | Persistent tab detail view within `StatefulShellRoute` with fallback empty state |
| `lib/features/profile/viewmodel/profile_viewmodel.dart` | Complete | Profile management, photo upload, and photo removal viewmodel |
| `lib/features/profile/view/profile_screen.dart` | Complete | Profile editing, theme switcher, and photo upload/removal screen (shared across roles) |
| `lib/core/services/storage_upload_service.dart` | Complete | Firebase Storage upload service with MIME contentType metadata and byte progress listeners |
| `lib/features/booking_wizard/viewmodel/booking_wizard_viewmodel.dart` | Complete | 9-step wizard viewmodel with Hive draft persistence, optional docs handling, and granular upload progress |
| `lib/features/booking_wizard/view/booking_wizard_screen.dart` | Complete | 9-step booking wizard shell with progress bar and step validation |
| `lib/features/booking_wizard/view/steps/step_1_survey_type.dart` | Complete | Step 1: RadioGroup selection of survey type + custom name |
| `lib/features/booking_wizard/view/steps/step_2_state_district.dart` | Complete | Step 2: Punjab state + dynamic district dropdown |
| `lib/features/booking_wizard/view/steps/step_3_xen_details.dart` | Complete | Step 3: Executive Engineer contact form |
| `lib/features/booking_wizard/view/steps/step_4_survey_area.dart` | Complete | Step 4: Survey area name + KML/KMZ spatial file picker (file_picker v12) |
| `lib/features/booking_wizard/view/steps/step_5_start_date.dart` | Complete | Step 5: Preferred start date picker (excluding weekends) |
| `lib/features/booking_wizard/view/steps/step_6_logistics.dart` | Complete | Step 6: Coordinator, driver, and vehicle details |
| `lib/features/booking_wizard/view/steps/step_7_permissions.dart` | Complete | Step 7: Permission document multi-file uploader (0-5 optional files <= 5MB, PDF/JPG/PNG) |
| `lib/features/booking_wizard/view/steps/step_8_review.dart` | Complete | Step 8: Readonly review summary with edit links, optional docs display, and live upload progress card |
| `lib/features/booking_wizard/view/steps/step_9_acknowledgement.dart` | Complete | Step 9: Submission confirmation screen |
| `lib/features/admin_dashboard/view/admin_shell_screen.dart` | Complete | Admin persistent 4-tab bottom navigation shell |
| `lib/features/admin_dashboard/view/admin_dashboard_screen.dart` | Complete | Admin dashboard with status counters, filtering, and search matching Stitch #17 |
| `lib/features/admin_dashboard/viewmodel/admin_dashboard_viewmodel.dart` | Complete | Admin dashboard viewmodel managing stats and filter queries |
| `lib/features/committee_management/view/committee_management_screen.dart` | Complete | Committee member directory with active/inactive filtering matching Stitch #18 |
| `lib/features/committee_management/view/add_committee_member_screen.dart` | Complete | Secure committee account provisioning form matching Stitch #19 |
| `lib/features/committee_management/viewmodel/committee_management_viewmodel.dart` | Complete | Committee management viewmodel invoking Cloud Function provisioning |
| `lib/features/admin_appointment_detail/view/admin_appointment_detail_screen.dart` | Complete | Full admin request detail view matching Stitch #20 & #21 |
| `lib/features/admin_appointment_detail/viewmodel/admin_appointment_detail_viewmodel.dart` | Complete | Real-time StreamProvider + imperative Controller provider for admin mutations |
| `lib/features/admin_appointment_detail/view/widgets/assign_reviewer_sheet.dart` | Complete | Modal bottom sheet to assign committee reviewer using RadioGroup |
| `lib/features/admin_appointment_detail/view/widgets/assign_task_sheet.dart` | Complete | Modal bottom sheet to assign fieldwork task using RadioGroup |
| `lib/features/admin_appointment_detail/view/widgets/set_confirmed_date_sheet.dart` | Complete | Modal bottom sheet to set or change confirmed survey date |
| `lib/features/committee_dashboard/view/committee_shell_screen.dart` | Complete | Committee persistent 3-tab bottom navigation shell (Reviews, Tasks, Profile) |
| `lib/features/committee_dashboard/view/committee_dashboard_screen.dart` | Complete | Committee dashboard showing active/resolved review assignments matching Stitch #22 |
| `lib/features/committee_dashboard/viewmodel/committee_dashboard_viewmodel.dart` | Complete | Committee dashboard viewmodel streaming assigned reviews (`StreamProvider.autoDispose`) |
| `lib/features/committee_review_detail/view/committee_review_detail_screen.dart` | Complete | Committee decision portal (Approve, Reject, Clarify) matching Stitch #23-26 |
| `lib/features/committee_review_detail/viewmodel/committee_review_detail_viewmodel.dart` | Complete | Committee review detail viewmodel with RBAC & assignment validation controller |
| `lib/features/assigned_tasks/view/assigned_tasks_screen.dart` | Complete | Committee Fieldwork Tasks queue matching Stitch #28 |
| `lib/features/assigned_tasks/viewmodel/assigned_tasks_viewmodel.dart` | Complete | Assigned tasks viewmodel streaming fieldwork tasks (`StreamProvider.autoDispose`) |
| `firestore.rules` | Complete | Hardened Firestore rules with scoped committee access, collectionGroup protection, and `/auth_rate_limits/` lockdown |
| `storage.rules` | Complete | Hardened Storage rules with `isAssignedCommittee()` cross-reference verification |
| `lib/core/services/firebase_appointment_repository.dart` | Complete | Concrete appointment repository routing all state mutations (review, clarification, assignment, date) through Cloud Functions to comply with `allow update: if false;` |
| `functions/src/index.ts` | Complete | Clean barrel re-exporting all 10 2nd Gen HTTPS Callables (Auth, Submission, Review, Clarification, Admin mutations) |
| `functions/src/lib/admin.ts` | Complete | Firebase Admin SDK and secret (`AUTH_WEB_API_KEY`) initialization module |
| `functions/src/lib/identity_toolkit.ts` | Complete | Google Identity Toolkit REST API credential verification & password reset email helpers |
| `functions/src/lib/rate_limit.ts` | Complete | Firestore-backed rate limiting module (`/auth_rate_limits/` - failure-based for login, count-based for signup/reset, SHA-256 email hashing) |
| `functions/src/functions/auth/create_committee_account.ts` | Complete | Admin-only committee member provisioning callable with custom claim assignment and temp credentials |
| `functions/src/functions/auth/authenticate_user.ts` | Complete | Server-mediated login callable verifying credentials via Identity Toolkit, enforcing rate limits, returning custom token |
| `functions/src/functions/auth/register_applicant.ts` | Complete | Server-mediated applicant registration callable with rate limiting (3/hr) and profile creation |
| `functions/src/functions/auth/request_password_reset.ts` | Complete | Server-mediated password reset dispatch with rate limiting (3/hr) via Identity Toolkit |
| `functions/src/functions/appointments/submit_appointment.ts` | Complete | Server-mediated appointment submission callable with atomic Firestore transaction quota enforcement (pendingCount < 3) |
| `functions/src/functions/appointments/review_appointment.ts` | Complete | Server-mediated committee review callable (approve, reject, clarify) with RBAC, reviewer checks, atomic rate limit decrement, and audit log |
| `functions/src/functions/appointments/submit_clarification_reply.ts` | Complete | Server-mediated applicant clarification reply callable with ownership guard and status reset |
| `functions/src/functions/appointments/admin_appointment_mutations.ts` | Complete | Admin appointment mutation callables (`assignReviewer`, `setConfirmedDate`, `assignFieldworkTask`) with audit logging |
| `functions/.secret.local` | Complete | Local Secret Manager mock key (`AUTH_WEB_API_KEY`) for local Cloud Functions emulation |
| `docs/firebase_emulator_user_manual.md` | Complete | Comprehensive operational, setup, testing, and troubleshooting user manual for Firebase Emulator Suite |
| `lib/core/firebase/firebase_emulator.dart` | Complete | Production-safe Firebase Emulator Suite connection abstraction (`USE_FIREBASE_EMULATOR` define) |
| `test/integration/firebase_emulator_test.dart` | Complete | Dart smoke integration test verifying Auth, Firestore, Storage, and Functions emulator endpoints |
| `firebase/tests/package.json` | Complete | Node.js rules testing harness configuration (`@firebase/rules-unit-testing`, `jest`, `firebase-admin`) |
| `firebase/tests/jest.config.js` | Complete | Jest test runner config for rules assertions against isolated `survey-desk-test` project namespace |
| `firebase/tests/firestore/users.rules.test.js` | Complete | 14 test assertions for `/users/{uid}` rules, RBAC, self-signup, and custom claim mismatch defenses |
| `firebase/tests/firestore/appointments.rules.test.js` | Complete | 20 test assertions for `/appointments/{id}` rules, role read isolation, and status bypass prevention |
| `firebase/tests/firestore/audit_log.rules.test.js` | Complete | 13 test assertions for `/appointments/{id}/audit_log/{logId}` subcollection rules and zero client writes |
| `firebase/tests/firestore/rate_limits.rules.test.js` | Complete | 14 test assertions verifying complete client lockdown (`allow read, write: if false`) on rate limit collections |
| `firebase/tests/storage/appointment_files.rules.test.js` | Complete | 12 test assertions for `/appointments/{id}/kml` & `permissionDocuments` storage rules and `firestore.get()` cross-referencing |
| `firebase/tests/storage/profile_photo.rules.test.js` | Complete | 11 test assertions for `/users/{uid}/profile/` storage rules, MIME checking, and user isolation |
| `firebase/tests/functions/authz.test.js` | Complete | 13 test assertions verifying authentication, RBAC, and input parameter validation across all 5 Cloud Functions |
| `firebase/tests/functions/race_condition.test.js` | Complete | 11 test assertions verifying atomic rate limiting, concurrency race condition safety, and tenant isolation |
| `lib/core/services/firebase_notification_service.dart` | Complete | Concrete FCM service managing initialization, isolates, foreground/background streams, and Firestore token registration |
| `lib/core/routing/notification_navigation.dart` | Complete | Auth-gated deep linking dispatcher routing notification taps to target screens |
| `lib/features/notifications/view/notification_overlay.dart` | Complete | Animated in-app top banner overlay with type icons, 4s auto-dismiss, and swipe-to-dismiss |
| `lib/features/notifications/view/notification_handler.dart` | Complete | Top-level app wrapper capturing background taps and terminated-state launch intents |
| `functions/src/functions/notifications/send_push_notification.ts` | Complete | Multicast FCM dispatcher with automatic error handling, recipient batching, and stale token pruning |
| `functions/src/functions/notifications/notification_recipients.ts` | Complete | Server-side recipient resolution from appointment document and admin role queries |

