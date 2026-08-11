# Appointment Booking App — Code Architecture

**Companion to:** all prior docs (PRD v2.0, TRD, Backend Schema v2.0, App Flow)
**Pattern:** MVVM + feature-first modularity + SOLID
**Status:** Draft for build

---

## Overview

MVVM mapped onto this stack: **View** = Flutter Widget (`ConsumerWidget`/`ConsumerStatefulWidget`), **ViewModel** = Riverpod `Notifier`/`AsyncNotifier` (holds state, orchestrates calls, contains zero Firebase SDK calls directly), **Model** = plain Dart data classes + a Repository layer that is the *only* place Firebase is actually touched.

This is 3-layer MVVM, not 4+ layer Clean Architecture — no separate use-case/interactor layer. That's a deliberate scope decision, not an oversight; adding it would cost real time this project doesn't have budgeted.

**On "deletable features":** achievable and enforced at the code/import level (see Feature Independence Rules below). Not achievable at the product level for Applicant/Admin/Committee specifically, since they're three views onto one shared appointment state machine by design — deleting one leaves the workflow incomplete, not just leaner. The distinction matters: don't rely on this architecture to mean "the app still makes sense with a role removed," only "the app still compiles and the other roles' code is unaffected."

---

## Folder Structure

```
lib/
├── core/                              # Shared across ALL features. Nothing in core/ ever imports from features/.
│   ├── constants/                     # SurveyType enum, AppointmentStatus enum, validation limits (max lengths, file size caps)
│   ├── theme/                         # app_theme.dart, app_spacing.dart (already built)
│   ├── models/                        # Appointment, AppUser, XenDetails, Logistics, PermissionDocument,
│   │                                  # KmlFile, AuditLogEntry — plain Dart classes matching the backend schema exactly
│   ├── repositories/                  # ABSTRACT interfaces only — see SOLID section
│   │   ├── appointment_repository.dart        # AppointmentReader + AppointmentWriter (segregated, see ISP below)
│   │   ├── user_repository.dart
│   │   └── audit_log_repository.dart
│   ├── services/                      # Concrete Firebase-backed implementations of the above interfaces
│   │   ├── firebase_appointment_repository.dart
│   │   ├── firebase_user_repository.dart
│   │   ├── firebase_audit_log_repository.dart
│   │   ├── cloud_functions_service.dart        # thin wrapper around `cloud_functions` package calls
│   │   ├── storage_upload_service.dart         # thin wrapper around Firebase Storage uploads
│   │   ├── file_open_service.dart              # ABSTRACT interface + mobile impl (`open_file`) — see Web-Readiness section
│   │   ├── crash_reporting_service.dart        # ABSTRACT interface + FirebaseCrashlyticsService impl
│   │   └── analytics_service.dart              # ABSTRACT interface + FirebaseAnalyticsService impl
│   ├── routing/                       # `go_router` config — each feature contributes its routes here;
│   │                                  # deleting a feature folder means deleting its contribution, not editing a central switch statement
│   ├── layout/                        # AppBreakpoints (Compact/Medium/Expanded per Material 3 window size classes)
│   │                                  # — see Responsive & Adaptive Design section
│   ├── widgets/                       # Shared dumb UI: buttons, form fields, empty-state widget, loading skeletons —
│   │                                  # each built against AppBreakpoints via LayoutBuilder from the start
│   └── utils/                         # Validators (phone/email format), formatters
│
├── features/
│   ├── auth/
│   │   ├── view/                      # SplashScreen, LoginScreen, SignupScreen
│   │   └── viewmodel/                 # AuthViewModel (Notifier) — depends on core UserRepository interface only
│   │
│   ├── applicant_home/
│   │   ├── view/                      # HomeScreen (3 sections)
│   │   └── viewmodel/                 # HomeViewModel — depends on core AppointmentRepository + AuditLogRepository
│   │
│   ├── booking_wizard/
│   │   ├── view/                      # 9 step screens + wizard shell
│   │   └── viewmodel/                 # ONE BookingWizardViewModel holding accumulated state across all 9 steps —
│   │                                  # intentionally not split per-step, since the review screen (step 8) and the
│   │                                  # single final submission both need the fully combined state.
│   │                                  # Also the one ViewModel in the app that calls CrashReportingService on every
│   │                                  # step transition and upload attempt — see Monitoring & Observability in the TRD
│   │
│   ├── my_bookings/
│   │   ├── view/                      # MyBookingsScreen, AppointmentDetailScreen
│   │   └── viewmodel/
│   │
│   ├── applicant_profile/
│   │   ├── view/
│   │   └── viewmodel/
│   │
│   ├── admin_dashboard/
│   │   ├── view/                      # AdminDashboardScreen, AdminAppointmentDetailScreen
│   │   └── viewmodel/                 # includes assignReviewer + setConfirmedDate actions
│   │
│   ├── task_assignment/                # Deliberately SEPARATE from admin_dashboard — genuinely independent
│   │   ├── view/                      # concern (post-approval fieldwork assignment); this is the feature that's
│   │   └── viewmodel/                 # actually safely removable/reworkable without touching the rest of Admin
│   │
│   ├── committee_management/
│   │   ├── view/
│   │   └── viewmodel/
│   │
│   ├── admin_profile/
│   │   ├── view/
│   │   └── viewmodel/
│   │
│   ├── committee_dashboard/
│   │   ├── view/
│   │   └── viewmodel/
│   │
│   └── committee_review/
│       ├── view/                      # Review Detail — approve/reject/clarify
│       └── viewmodel/
│
└── main.dart                          # ProviderScope, MaterialApp, merges route lists from core/routing
```

---

## Feature Independence Rules

1. A feature under `features/` may import from `core/` freely. It may **never** import from another feature's `view/` or `viewmodel/` folder.
2. Cross-feature communication happens only through shared `core/` state (repository data, auth state) — never by one feature reaching into another's ViewModel directly.
3. Navigation between features goes through `core/routing`'s registry (named routes), not direct widget imports across feature boundaries.
4. **Acceptance test, not just a guideline:** physically delete a feature folder and run `flutter analyze`. Any error outside that folder means a boundary was violated somewhere and needs fixing before it counts as feature-first.

---

## SOLID Principles Applied

**Single Responsibility** — Views render and forward user actions only. ViewModels hold state and orchestrate; they never call `FirebaseFirestore.instance` or `FirebaseStorage.instance` directly, only repository interfaces. Repositories are the only layer touching Firebase.

**Open/Closed** — Wizard steps and survey types are config-driven (a `List<WizardStepConfig>` and the `SurveyType` enum in `core/constants`), not a hardcoded chain of if/else across the codebase. Adding a 6th survey type or a 10th wizard step means adding a config entry, not hunting down every place a step count or type list was hardcoded.

**Liskov Substitution** — `AppointmentRepository`'s Firebase implementation must be fully substitutable by a fake/in-memory implementation in tests without changing any ViewModel code. This is the concrete payoff of the abstraction — not hypothetical "in case we switch off Firebase," but actual unit-testability of state-machine logic (e.g., "clarification can only happen once" is a real business rule worth a real unit test, not just manual QA).

**Interface Segregation** — `AppointmentRepository` is split into `AppointmentReader` (used by dashboards, read-only) and `AppointmentWriter` (used by the wizard's submission, Admin's assignment actions). A feature that only ever reads appointments (e.g., a future reporting feature) depends only on `AppointmentReader` — it isn't forced to depend on write capability it never uses.

**Dependency Inversion** — Every feature ViewModel depends on the abstract repository interfaces defined in `core/repositories`, injected via Riverpod providers, never on the concrete `core/services` implementations directly. Concrete implementations are wired up once, in `main.dart`'s provider overrides. `CrashReportingService`, `AnalyticsService`, and `FileOpenService` follow the identical pattern — a ViewModel logging a breadcrumb or an analytics event calls the interface, never `FirebaseCrashlytics.instance` or `FirebaseAnalytics.instance` directly.

---

## Responsive & Adaptive Design

Built against Material 3's window size classes, defined once in `core/layout`:

| Class | Width | v1 status |
|---|---|---|
| Compact | <600dp | Fully designed — this is the phone layout every screen in appointment_booking_app_flow.md describes |
| Medium | 600-840dp | Breakpoint exists, `LayoutBuilder` branch present, no dedicated layout designed — falls back to a reasonably scaled Compact layout |
| Expanded | >840dp | Same as Medium — breakpoint wired, not designed |

Every View wraps its root in a `LayoutBuilder` checking against `AppBreakpoints`, even where only the Compact branch has real design work behind it. This directly reuses the Sage & Stone design system's own grid tokens (12-col desktop / 4-col mobile, 16px/32px margins) — tokens this project explicitly flagged as "not applicable yet" when web was ruled out for v1. They're relevant again now as the forward-looking breakpoint values; nothing new was invented for this.

**What this buys, concretely:** when a Medium or Expanded layout eventually gets designed, it's implemented inside the existing `LayoutBuilder` branch of each View — not a rewrite of the View, the ViewModel, or anything below it. What it does *not* buy: an actual tablet or web experience today. The Medium/Expanded branches exist so they don't crash if triggered (e.g., a user on a large Android tablet or a foldable in unfolded state), not because they've been designed.

## Web-Readiness Boundary

Three separate things get conflated under "make it responsive and adaptive" — worth keeping distinct:

1. **Layout architecture** (breakpoints, `LayoutBuilder`) — done now, per above, at near-zero extra cost since nothing was built yet.
2. **Package compatibility** — partially addressed. `pdfx` swapped in for `flutter_pdfview` (web-compatible at equal cost today — see TRD). `open_file` has no web equivalent and can't be swapped for a single cross-platform package; it's wrapped behind `FileOpenService` instead, so a web implementation can be added later without touching any calling code. This is the concrete reason that interface exists — not abstraction for its own sake.
3. **Platform infrastructure** (Firebase App Check's web provider, actual web hosting/deployment, browser-specific Auth flows) — genuinely cannot be prepared for now. These require a real web app registered in Firebase console and don't have a "just architect around it" shortcut. Flagged here so nobody assumes items 1 and 2 mean web is fully de-risked — it isn't.

## Provider (DI) Scoping Convention

- **Core providers** (repository instances, current-user/role state) are declared once in `core/repositories` or `core/services`, and are the only providers imported across feature boundaries.
- **Feature-local providers** (a specific ViewModel's state) live inside that feature's own `viewmodel/` folder and are never imported from outside that feature.

---

## Concrete Payoff: The Still-Open Committee Task-Visibility Gap

This structure makes that decision cheap to act on whenever it's made. Because `task_assignment` is already isolated as its own feature with its own ViewModel and repository calls, adding a mirrored `my_assigned_tasks` feature for Committee members (surfacing `assignedTaskMemberId` — the field and composite index already exist in the schema) is a clean new feature folder, not a refactor of `admin_dashboard` or `committee_dashboard`. Worth knowing this now specifically because it lowers the cost of finally resolving a gap that's been flagged three times.

---

## Timeline Impact

**+2-3 days added to Week 1** for the original `core/` setup (models, repository interfaces, Firebase implementations, routing registry, provider wiring). **+2-3 more days** for `go_router` and monitoring service setup, plus a **~10% distributed tax** on every screen's implementation from Week 2 onward for breakpoint-aware layouts. Combined with the wizard/monitoring instrumentation work, the TRD's checklist now runs **~11-12 weeks total**, with Week 12 reserved explicitly as unscheduled buffer rather than pretending an 11-week solo estimate has zero slack. Expected to be close to a wash or a net gain on debugging time by the end of the build if the patterns are actually followed consistently — that's a projection, not a guarantee.
