# Appointment Booking App — Technical Requirements Document

**Companion to:** appointment_booking_app_prd.md (v2.0), appointment_booking_app_flow.md, appointment_booking_app_backend_schema.md
**Stack:** Flutter (client) + Firebase Blaze (backend) — already provisioned
**Status:** Draft for build — supersedes the earlier TRD following the App Flow review

---

## 📊 Document Overview

This TRD reflects the v2.0 PRD's 9-step booking wizard and 23-screen inventory (up from 13), plus Crashlytics, Analytics, Performance Monitoring, and web/desktop-ready (not web-built) responsive architecture. Constraints shaping every decision below:
- **No Apple Developer account** → Android-first build and launch.
- **4-5 hrs/day** → realistic timeline is now **~11-12 weeks**, up from the earlier 9-10 week estimate. Added: monitoring setup (+2-3 days), a per-screen breakpoint-aware layout tax across all UI work (+3-4 days), `go_router` adoption (+1 day).
- **$0/month target at low volume**, honest scaling costs beyond that. Crashlytics, Analytics, and Performance Monitoring are all free at any realistic scale for this app — no cost tier impact.
- State/district reference data is bundled static JSON in the client, not Firestore-backed.
- **Web/desktop-ready, not web-built:** the client is architected so a future web build doesn't require a rewrite (breakpoint-aware layouts, `go_router`, web-compatible package choices where the cost is equal today). Actually shipping web remains out of scope for v1 — this is groundwork, not a scope change.

---

## 🏗️ System Architecture

```
┌─────────────────────────┐
│   Flutter Client App    │
│ (Applicant wizard+home, │
│  Admin, Committee)      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│    Firebase Auth         │  ← identity, custom claims for role
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐      ┌──────────────────────────────┐
│   Cloud Firestore        │◄────►│  Firebase Storage             │
│ (appointments, users,    │      │ (permission docs, KML/KMZ,    │
│  auditLog, rateLimits)   │      │  admin profile photos)        │
└───────────┬─────────────┘      └──────────────────────────────┘
            │ triggers
            ▼
┌─────────────────────────┐
│   Cloud Functions        │  ← business logic, Admin SDK account creation,
│   (Node.js 20, 2nd Gen)  │     assignment, review actions, rate-limit txn
└───────────┬─────────────┘
            │
      ┌─────┴─────┐
      ▼           ▼
┌───────────┐ ┌─────────────────┐
│ SendGrid  │ │ Firebase Cloud   │
│ (SMTP,    │ │ Messaging (FCM)  │
│ email)    │ │ (push, Admin/    │
│           │ │  Committee only) │
└───────────┘ └─────────────────┘
```

No dedicated AI/LLM component.

---

## 🛠️ Technology Stack

| Component | Technology | Why This Choice |
|---|---|---|
| Client framework | Flutter 3.x (Dart) | Single codebase, Android now, iOS later |
| State management | `flutter_riverpod` (v2.x, hand-written `Notifier`/`AsyncNotifier`, no codegen) | Carried from v1.0; the 9-step wizard makes disciplined state management more important, not less — one `Notifier` should hold the full accumulated wizard payload across all 7 data-entry steps |
| Architecture pattern | MVVM (View/ViewModel/Model) + feature-first folder structure + SOLID | See appointment_booking_app_architecture.md — Riverpod `Notifier`s serve as the ViewModel layer; features never import each other directly, only `core/` |
| Wizard navigation | Flutter's built-in `PageView` + a step-index `Notifier`, not the `Stepper` widget | `Stepper` is designed for short vertical step lists rendered on one screen — a 9-step flow with per-step full-screen forms and back navigation fits `PageView` (or simple `Navigator` push/pop) far better |
| State/District reference data | Bundled static JSON asset (`assets/india_states_districts.json`) | Fixed reference data, changes rarely — no reason to query Firestore for something this static |
| Auth | Firebase Authentication | Native email/password + custom claims |
| Database | Cloud Firestore | Free tier covers MVP volume |
| File storage | Firebase Storage | Handles PDF/JPG/PNG/KML/KMZ + admin profile photos |
| Backend logic | Cloud Functions, Node.js 20, 2nd Gen | Admin-SDK account creation, Firestore-triggered emails |
| Email delivery | SendGrid (free tier, 100/day) via Firebase "Trigger Email" extension | Standard, zero custom email code |
| Push notifications | Firebase Cloud Messaging + `firebase_messaging` | Native integration |
| File picking | `file_picker` package | Supports `.kml`/`.kmz` and PDF/JPG/PNG |
| Image picking (profile photo) | `image_picker` package | Standard, camera + gallery source |
| PDF preview | `pdfx` (**swapped from `flutter_pdfview`**) | `flutter_pdfview` is Android/iOS only — verified via search, not assumed. `pdfx` supports Android/iOS/Web/Windows/macOS at equal cost today, removing a forced package migration when web ships |
| Image preview/caching | `cached_network_image` | Standard, web-compatible |
| Image compression pre-upload | `flutter_image_compress` | Applies to permission-doc images and profile photos alike |
| Date picker | Flutter's built-in `showDatePicker` with `selectableDayPredicate` | Native, no package needed, web-compatible |
| Abuse protection | Firebase App Check (Play Integrity API) | Free, blocks non-genuine app instances. **Web-readiness gap that can't be closed now:** App Check's web provider is reCAPTCHA, not Play Integrity — this genuinely can't be pre-configured without a real web app registered in Firebase console, unlike the other line items here |
| File open (KML download) | `open_file`, behind a `FileOpenService` interface (see architecture doc) | `open_file` has no web equivalent — opening a file in an external app is a mobile/desktop-only concept. The interface, not the package, is what makes this swappable later without touching calling code |
| Routing | `go_router` (**new** — replaces ad-hoc `Navigator` push/pop) | Standard, URL-based, web-compatible routing; integrates directly with the `core/routing` feature-registry pattern already established. Costs nothing extra for an Android-only build, avoids a routing rewrite if web ships |
| Crash reporting | `firebase_crashlytics` | Free at any realistic scale. Custom breadcrumbs on the booking wizard specifically — see Monitoring & Observability below |
| Analytics | `firebase_analytics` | General event tracking (screen views, sign-up, login, booking submitted, review action) — **not** wired to the PRD's specific named success metrics (wizard abandonment, time-to-assignment) per this scope decision; that wiring is deferred |
| Performance monitoring | `firebase_performance` | Automatic traces (app start, network requests) largely free out of the box; custom traces added for wizard file uploads and the step-8 submission call specifically |

---

## 🗄️ Backend Framework / Runtime

**Cloud Functions for Firebase, 2nd Gen, Node.js 20 runtime, plain JavaScript.** Unchanged reasoning from v1.0 — TypeScript's overhead isn't justified on this timeline even with the added wizard complexity, since the complexity is client-side state management, not backend logic.

---

## Database: Cloud Firestore

Full field-level schema lives in appointment_booking_app_backend_schema.md (v2.0). Summary of what changed:

| Collection | What Changed |
|---|---|
| `users/{uid}` | Added `photoUrl` (nullable) for Admin profile photos |
| `appointments/{id}` | Replaced flat `location`/`documentUrls[]` with structured `state`, `district`, `xenDetails` (map), `areaName`, `kmlFile` (map, unchanged), `logistics` (map: coordinator name+designation, driver name+mobile, vehicle number+model), `permissionDocuments` (array, renamed from `documentFiles`). Added `confirmedDate` (restored — see PRD). Dropped `description`. |
| `appointments/{id}/auditLog/{logId}` | Added `applicantId` (denormalized) to support the Home screen's cross-appointment "Recent Activity" `collectionGroup` query |
| `rateLimits/{applicantId}` | Unchanged |

Pagination unchanged: `.limit(20).startAfter()` cursor pattern for all list queries.

---

## 🔌 API Design (Cloud Functions — callable)

| Function | Purpose | Input | Output |
|---|---|---|---|
| `createCommitteeAccount` | Admin provisions a committee login | name, email, expertiseTag | uid, temp password emailed |
| `submitAppointment` | Applicant books a survey — **now called once at wizard step 8**, not per-step | surveyType, customSurveyName, state, district, xenDetails, areaName, kmlFile, preferredDate, logistics, permissionDocuments | appointmentId, status: `pending_assignment` |
| `assignReviewer` | Admin routes appointment to one committee member | appointmentId, committeeMemberId | status: `under_review` |
| `setConfirmedDate` | **New** — Admin sets/changes the confirmed survey date | appointmentId, confirmedDate | updated appointment |
| `reviewAppointment` | Committee member acts on assigned appointment | appointmentId, action, reason/note | updated status |
| `submitClarificationReply` | Applicant responds to clarification | appointmentId, replyText | status: `under_review` |
| `assignFieldworkTask` | Admin assigns post-approval fieldwork task | appointmentId, committeeMemberId | status: `task_assigned` |
| `checkRateLimit` | Pre-check before `submitAppointment` | applicantId | allow/deny — must run inside the same transaction as appointment creation, not as a separate call (see schema doc's race-condition note) |
| `updateProfilePhoto` | **New** — Admin uploads/updates profile photo | photoStoragePath | updated `users/{uid}.photoUrl` |

Firestore-triggered:
- `onAppointmentCreate` → booking confirmation email
- `onStatusChange` → notification matrix per PRD Feature 8
- `onAppointmentWrite` → appends an `auditLog` entry for every status-affecting write (backs the audit trail and the Home screen's Recent Activity feed)

---

## 🔒 Security & Rate Limiting

Unchanged from v1.0, still applies:
- Firestore Security Rules enforce role via custom claims, never client-reported fields.
- Storage rules restrict appointment file access to uploading applicant, Admins, and the specifically assigned committee member.
- Firebase App Check on all callable functions and Firestore access.
- Booking rate limit: max 3 unresolved appointments, enforced via a single atomic transaction (not a naive read-then-write — see schema doc).
- Email verification gate before booking submission.
- File type/size validated both client- and server-side.

**New:** Admin profile photo Storage path (`users/{uid}/profile/{fileName}`) — readable by anyone in the app (profile photos aren't sensitive), writable only by the account owner.

---

## Environment Variables Needed

Unchanged from v1.0: `SENDGRID_API_KEY`, `INSTITUTE_NOTIFY_EMAIL`, `FIREBASE_PROJECT_ID` (auto-populated).

---

## 🤖 AI Integration

Not applicable — unchanged from v1.0.

---

## 🚀 Deployment Strategy

Unchanged from v1.0 steps 1-8 (Firebase project already on Blaze, rules deployed before client testing, Functions via Emulator Suite first, SendGrid + Trigger Email extension, App Check, signed Android build, Google Play Internal Testing $25 one-time fee, iOS deferred pending Apple Developer account).

**Added steps:**
- Bundle the India states/districts JSON asset into the Flutter app's `assets/` folder and register it in `pubspec.yaml` before the wizard's Step 2 can be built.
- Enable Crashlytics, Analytics, and Performance Monitoring in the Firebase console (each is a separate toggle, none require Blaze specifically — all three work on Spark too, though the project is already on Blaze regardless).

---

## 📈 Monitoring & Observability

**Crashlytics:**
- Default crash and non-fatal error capture, enabled app-wide via `FlutterError.onError` and `PlatformDispatcher.instance.onError` hooks.
- **Custom breadcrumbs on the booking wizard specifically** (per scope decision) — a `setCustomKey('current_wizard_step', stepName)` call on every step transition, plus `log()` breadcrumbs on file upload attempts/failures and the final submission attempt/outcome. This gives a debug trail of exactly where in the 9-step flow a crash or error occurred without needing full session replay.
- **Hard privacy rule, not optional:** breadcrumbs and custom keys never contain PII. Log step names, survey type, file type/size — never XEN email/phone, applicant contact details, or any free-text field content. This is a government app handling personal data; crash logs are not an acceptable place for it to leak into.

**Analytics (general tracking, per scope decision — not wired to PRD success metrics yet):**
- Automatic screen-view tracking via `go_router`'s observer integration.
- Custom events: `sign_up`, `login`, `booking_wizard_started`, `booking_submitted`, `review_action_taken` (with an `action` parameter: approve/reject/clarify).
- **Explicitly not included:** per-step wizard funnel events. The PRD's "wizard abandonment rate" metric cannot be computed from this general tracking alone — that needs step-level start/complete events added later as a deliberate follow-up, not assumed to already exist because Analytics is installed.

**Performance Monitoring:**
- Automatic traces (app start time, HTTP/network request duration) ship largely for free once the SDK is added — no extra instrumentation needed for baseline visibility.
- Custom traces added for: KML/permission-document upload duration (Storage upload calls), and the step-8 `submitAppointment` call specifically — both named in the existing Performance Requirements below, so this is the concrete way to verify those stated targets are actually being met in production rather than just hoped for.

**Backend schema impact: none.** Crashlytics, Analytics, and Performance Monitoring are separate Firebase products that don't write to Firestore — appointment_booking_app_backend_schema.md needs no changes for any of this.

---

## 📊 Performance Requirements

Unchanged from v1.0, plus:
- Wizard step transitions should feel instant (no network calls between steps 1-7 — everything is local Riverpod state until the single submission at step 8).
- The Review & Confirm screen (step 8) must render a full summary of 7 prior steps without a noticeable lag — this is pure local-state rendering, not a network call, so there's no excuse for it feeling slow.
- **Responsive layout:** every screen built against Material 3's window size classes (Compact <600dp, Medium 600-840dp, Expanded >840dp) via `LayoutBuilder`, even though only the Compact (phone) variant is fully designed for v1. This directly reuses the Sage & Stone design system's own grid tokens (12-col desktop / 4-col mobile, 16px/32px margins) — tokens flagged earlier in this project as "not applicable yet" since web was out of scope. They matter again now as the forward-looking breakpoint values, not new numbers invented for this purpose.

---

## 💰 Cost Estimate

Largely unchanged from v1.0 — the wizard adds client-side complexity, not backend load. One addition: Admin profile photos add negligible Storage cost (a handful of small images, not per-transaction like appointment documents).

| Users | Firestore/Storage/Functions | SendGrid | Google Play | Total |
|---|---|---|---|---|
| 100 | $0 | $0 | $25 one-time | **~$0/month** |
| 1,000 | Likely $0 | Likely $0 under ~15-20 bookings/day | — | **$0-5/month** |
| 10,000 | **$5-20/month** (Storage egress, KML files especially) | Likely exceeds free tier — SendGrid Essentials ~$20/month | — | **~$25-40/month** |

---

## 📋 Development Checklist (4-5 hrs/day, ~11-12 weeks total — revised)

**Note on the responsive-layout tax:** it isn't one lump block of days — it's a small (~10%) overhead applied to every screen's implementation from Week 2 onward, since each View gets wrapped in `LayoutBuilder` against the Compact/Medium/Expanded breakpoints even though only Compact is fully designed. Baked into the per-week estimates below rather than called out as a separate line item every time.

**Week 1 — Foundation + architecture skeleton**
- Days 1-2: Firestore schema setup (v2.0 fields), security rules skeleton, Auth flows
- Day 3: `core/` layer setup: models matching the schema, repository interfaces, Firebase-backed implementations
- Day 4: **Added** — `go_router` setup with the `core/routing` feature-registry pattern; Crashlytics/Analytics/Performance SDK integration and Firebase console enablement
- Day 5: Role-based navigation shells wired through `go_router`, custom claims setup
- Days 6-7 (spills into Week 2): Firebase Emulator Suite setup, first feature (`auth`) built end-to-end against the new architecture as a template for the rest

**Week 2 — Home screen + wizard foundation**
- Days 6-7: Home screen (3 sections: Upcoming Scheduled, Recent Requests, Recent Activity)
- Days 8-10: Wizard navigation shell (`PageView` + step-index `Notifier`), Step 1 (Survey Type), Step 2 (State/District cascading dropdowns + bundled JSON asset)

**Week 3 — Wizard steps 3-5**
- Days 11-12: Step 3 (XEN Details form)
- Days 13-15: Step 4 (Survey Area + KML/KMZ upload, reusing file upload patterns), Step 5 (Start Date)

**Week 4 — Wizard steps 6-9**
- Days 16-18: Step 6 (Logistics & Personnel — 6 fields)
- Days 19-20: Step 7 (Permissions document upload)

**Week 5 — Wizard completion + Admin core**
- Days 21-23: Step 8 (Review & Confirm — aggregating and displaying all prior steps) and Step 9 (Acknowledgement)
- Days 24-25: Admin Dashboard (list, filter, pagination)

**Week 6 — Admin actions + rate limiting**
- Days 26-27: `assignReviewer`, `setConfirmedDate`, `checkRateLimit` as a single atomic transaction
- Days 28-30: Admin Appointment Detail (rendering the full new data model)

**Week 7 — Committee review loop**
- Days 31-33: Committee Dashboard, Review Detail (same rich rendering as Admin's detail view)
- Days 34-35: Clarification round-trip, rejection flow, status state machine testing

**Week 8 — Provisioning, notifications, admin profile**
- Days 36-37: `createCommitteeAccount`, forced password reset
- Days 38-39: SendGrid + Trigger Email extension, all notification triggers
- Day 40: Admin Profile screen + photo upload

**Week 9 — Task assignment + security hardening**
- Days 41-42: Post-approval fieldwork task assignment
- Days 43-45: App Check integration, Firestore/Storage rules penetration testing, `auditLog` write-on-every-action verification

**Week 10 — Monitoring validation + responsive QA**
- Days 46-47: Force-test Crashlytics breadcrumbs by triggering deliberate errors at each wizard step, confirm PII never appears in logged data
- Days 48-50: Test every screen's `LayoutBuilder` branches at Medium/Expanded widths (even though only Compact ships) — confirm nothing crashes or renders broken if a user is on a large-screen Android device or foldable; this is the actual payoff check for the "web/desktop-ready" architecture decision

**Week 11 — Polish and QA**
- Days 51-53: Empty/error/loading states per appointment_booking_app_flow.md, wizard mid-session interruption handling
- Days 54-55: Full end-to-end QA across all three roles, Play Console Internal Testing upload

**Week 12 — Buffer**
- Days 56-60: Reserved for whatever the QA pass above actually surfaces — not scheduled work, just honest acknowledgment that an 11-week estimate with zero slack for a solo dev is optimistic, not realistic

---

## 🎯 Technical Success Criteria

- [ ] All wizard steps 1-7 accumulate state locally with zero network calls; `submitAppointment` fires exactly once at step 8
- [ ] Rate-limit check and appointment creation happen inside one atomic transaction — verified by attempting two rapid simultaneous submissions from the same test account
- [ ] `auditLog` entries are written for every status-affecting action, each including `applicantId`, and the Home screen's Recent Activity `collectionGroup` query returns them correctly
- [ ] State/District cascading dropdown correctly filters districts when state changes, using the bundled JSON asset (no network dependency)
- [ ] All file types (PDF/JPG/PNG/KML/KMZ) upload successfully and respect size/count limits
- [ ] Every notification trigger lands in the correct inbox
- [ ] Admin can set/change a confirmed date independent of the applicant's original preferred date
- [ ] Admin can upload and see their own profile photo
- [ ] Firestore/Storage rules block cross-role access, tested by hand
- [ ] Crashlytics breadcrumbs correctly show the current wizard step on a forced test crash, with zero PII present in any logged key or breadcrumb
- [ ] Analytics events fire for sign-up, login, booking submission, and review actions — confirmed via DebugView, not just assumed from the code being present
- [ ] Performance Monitoring custom traces show real duration data for file uploads and the step-8 submission call
- [ ] Every screen's Medium/Expanded `LayoutBuilder` branch renders without crashing when manually forced (even though Compact is the only one designed) — this is the actual test of whether "web/desktop-ready" architecture holds up, not just an assumption
- [ ] App bundle signed, uploaded, and live on Google Play Internal Testing
