# Appointment Booking App — Product Requirements Document

**Stack:** Flutter (mobile-first) + Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging)
**Version:** 2.0 (MVP) — supersedes v1.0 following the App Flow review
**Status:** Draft for build
**Companion:** appointment_booking_app_flow.md, appointment_booking_app_trd.md, appointment_booking_app_backend_schema.md

---

## 📊 Project Overview

Replaces manual phone/email booking of government survey appointments with a structured mobile workflow across three roles: **Applicant**, **Admin**, **Committee Member**. Applicants book one of five survey types through a 9-step wizard capturing location, XEN contact, survey area, logistics, and permissions; Admin routes the request to a committee member for review; the committee member approves, rejects, or requests clarification; on approval, Admin assigns the actual survey fieldwork to a committee member.

**v2.0 change:** the booking flow was restructured from a single form into a 9-step wizard per the App Flow review. This is not a cosmetic change — it roughly doubles total screen count (13 → 23) and pushes the realistic build timeline from 6-7 weeks to **9-10 weeks**. See Development Phases below.

**Carried from v1.0:** Applicants can be anyone — individuals or organizations. "Institute mail id" is a separate, fixed notification address belonging to the organization operating this app, not a field tied to the applicant.

---

## 🎯 Product Vision

Kill the phone-call-and-email survey booking process. One app, one source of truth for appointment status, one audit trail for who approved what and why.

---

## 👤 Target Users

| Role | Who | Created by | Pain point today |
|---|---|---|---|
| Applicant | Anyone requesting a survey (individual or organization) with valid documents | Self-signup | No visibility into request status; chases by phone |
| Admin | Internal staff managing the pipeline | Pre-provisioned (first admin seeded manually in Firebase console) | Manually tracks requests in email/spreadsheets, manually calls committee members |
| Committee Member | Reviewer who approves/rejects/clarifies | **Admin-created only** — no self-signup | No structured way to review, everything comes via email/phone |

---

## ✨ Core Features (MVP — numbered, with exact specs)

### 1. Applicant Authentication
- Firebase Auth, email + password.
- Signup requires: Full Name, Organization Name (optional), Email, Phone (10 digits, validated), Password (min 8 chars, 1 number).
- **Email verification required** before an applicant can submit a booking.
- Forgot-password via Firebase's standard reset flow.

### 2. Committee Member Authentication (Admin-provisioned)
- Admin creates the account via a Cloud Function using the Firebase Admin SDK.
- Cloud Function generates a temp password, emails it to the committee member.
- Public signup with a pre-provisioned email is blocked: **"Account already exists. Please log in."**
- Forced password change on first login.

### 3. Home Screen (Applicant)
- **Upcoming Scheduled Surveys** section: appointments with status `Approved` or `Task Assigned`, sorted by confirmed date ascending.
- **Recent Appointment Requests** section: last 5 appointments of any status, sorted by creation date descending.
- **Recent Activity** feed: the applicant's own status-change events across all their appointments (approvals, rejections, clarification requests), pulled via a cross-appointment query — not a separate manually-maintained log.
- Prominent **"Start New Survey"** button.
- Bottom navigation: Home / My Bookings / Profile.

### 4. New Survey Booking (Applicant) — 9-step wizard
Linear flow, back-navigable, each step validates before advancing. Nothing is written to the backend until the final Confirm step — steps 1-7 accumulate local state only.

1. **Survey Type** — single select, exactly 5 options:
   - Socio Economic Survey
   - Benchmarking (DGPS Survey)
   - DGPS Survey
   - Bathymetry Survey (Red Line)
   - Other — reveals a required text field, max 60 chars, for custom survey name
2. **State & District** — cascading dropdowns (India states/districts, bundled static reference data — flagged assumption, confirm if incorrect).
3. **XEN Details** — Executive Engineer responsible for the district's survey: Name (max 100 chars), Mobile (10 digits, validated), Email (valid format).
4. **Survey Area & KML/KMZ** — Area Name (text, max 150 chars) + KML/KMZ file (exactly one file, not multiple). Required for all 5 survey types — confirmed, not just the spatial ones.
5. **Survey Start Date** — date picker, Saturdays/Sundays disabled, min date = tomorrow, max date = +90 days.
6. **Logistics & Personnel** — Local Coordinator Name (max 100 chars — **added**; the original spec only asked for a designation/title, which alone isn't enough to reach anyone) + Designation (max 100 chars). Driver Name (max 100) + Mobile (10 digits, validated). Vehicle Number (max 20 chars) + Vehicle Model (max 60 chars).
7. **Permissions** — document upload: permission-to-survey + consent documents. Min 1, max 5 files, PDF/JPG/PNG only, 5MB max per file. (This is where the v1.0 PRD's original "Document Upload" requirement now lives — not a duplicate of it.)
8. **Review & Confirm** — read-only summary of steps 1-7, grouped by section, each with an inline "Edit" link back to that step. "Confirm Booking" triggers the single backend submission.
9. **Booking Acknowledgement** — confirmation screen with appointment reference, "Done" returns to Home.

**Dropped from v1.0, flagged not silently removed:** the free-text "Purpose/Description" field (max 1000 chars) is not present anywhere in the 9-step wizard. Treated as superseded by the new structured fields — confirm if a free-text description is still wanted somewhere.

**Open decision, not yet resolved:** what happens if an applicant closes the app mid-wizard. Defaulting to in-memory state only (survives backgrounding, not an app kill) as the cheaper MVP option — a persisted Firestore draft is the more robust but more expensive alternative if abandonment turns out to matter in practice.

### 5. Admin — Appointment Assignment
- Admin dashboard lists all appointments, filterable by status and survey type, shows applicant name per row.
- Admin assigns **one** committee member per appointment for review.
- Status → `Under Review`. Notification to the assigned committee member only.
- Admin can also set/change the **confirmed date** on an appointment (separate from the applicant's originally requested date) — **restored** in this version; this capability was requested early in scoping but had dropped out of v1.0 entirely with no field or screen supporting it.

### 6. Committee Review (single assignee)
- Committee dashboard shows only appointments assigned to that member.
- Full detail view: survey type, state/district, XEN contact, survey area + KML download, dates, logistics, permission documents.
- Three actions: **Approve**, **Reject** (reason, mandatory, max 500 chars), **Request Clarification** (note, mandatory, max 500 chars).
- Reject → applicant must submit a brand-new appointment, no edit/resubmit path.
- Clarification → applicant gets one reply (max 500 chars, no re-upload), then status returns to `Under Review` for the same reviewer to make a final Approve/Reject call — cannot request clarification a second time.

### 7. Admin — Survey Task Assignment (post-approval)
- Once `Approved`, Admin assigns the fieldwork task to a committee member (same or different from the reviewer).
- Status → `Task Assigned`. Applicant receives approval email with the assigned surveyor's name and contact.
- **Unresolved, flagged three times now across this review:** no screen exists anywhere in the app for a committee member to see appointments they've been assigned as fieldwork executor. The Committee Dashboard only shows review assignments. This needs an explicit decision before build, not another pass-through.

### 8. Notifications
- Email for: booking confirmation (applicant + fixed institute BCC address), new appointment (Admin), assignment (committee member), rejection (applicant), clarification request (applicant), clarification reply (committee member), approval + task assignment (applicant).
- In-app push mirrors every trigger above for Admin and Committee. Applicant relies on email + in-app status.

### 9. Admin Profile — **new in v2.0**
- Name, details, and **photo upload**.
- Scoped to Admin only per the App Flow as described — flag if Applicant/Committee should get profile photos too, since the backend field supports either without extra schema work.

### 10. Applicant Profile
- Name, organization (optional), email, phone — edit contact info only. No photo per the flow as given.

---

## 📱 Screen Inventory (23 screens total — up from 13 in v1.0)

**Shared (3):** Splash/Auth check, Login, Signup

**Applicant Core (4):** Home, My Bookings, Appointment Detail, Profile

**Applicant Booking Wizard (9):** Survey Type, State & District, XEN Details, Survey Area & KML, Start Date, Logistics & Personnel, Permissions, Review & Confirm, Acknowledgement

**Admin (5):** Admin Dashboard, Appointment Detail (Admin view), Committee Management, Task Assignment, Admin Profile

**Committee Member (2):** Committee Dashboard, Review Detail

See appointment_booking_app_flow.md for the full screen-by-screen navigation map, including empty/error/loading states per screen.

---

## 🔄 Key User Flows

See appointment_booking_app_flow.md for the complete flow, including edge cases. Summary:

**Flow A — Booking to Approval:** Applicant completes the 9-step wizard → single submission → Admin assigns reviewer → Committee approves → Admin assigns fieldwork task → applicant notified.

**Flow B — Rejection:** Committee rejects with mandatory reason → applicant must start an entirely new booking, no resubmit.

**Flow C — Clarification:** Committee requests clarification → applicant gets one reply → reviewer must then Approve or Reject, cannot request clarification again.

**Flow D — Committee provisioning:** Admin creates account → Cloud Function issues temp credentials → forced reset on first login.

---

## 📊 Success Metrics

- **Primary:** Appointments booked per week.
- **Workflow health:** median time to assignment, median time to decision, re-application rate after rejection, clarification round-trip completion rate.
- **New given the wizard's length:** wizard **abandonment rate** — % of applicants who start the booking wizard but don't reach step 9 within the session. A 9-step flow has real drop-off risk that a single-page form didn't; this needs tracking from day one, not after users start complaining.
  **Not yet implemented:** per the TRD's Analytics scope decision, this metric isn't currently computable — general event tracking (sign-up, login, booking submitted) doesn't include per-step wizard funnel events. Closing this requires adding step-level start/complete events as an explicit follow-up, not something already covered because Analytics is installed.

---

## 🚫 Out of Scope (v1)

- Payments, SMS notifications, multi-member majority voting, web app, analytics/reporting exports, in-app real-time chat beyond the single clarification round-trip, editing/resubmitting a rejected appointment, slot capacity limits, document OCR, multi-language support, offline mode.
- Persisted wizard drafts (in-memory only for MVP — see Feature 4's open decision above).

---

## 🎯 Development Phases

**Revised realistic estimate: ~9-10 weeks at 4-5 hrs/day** (up from the earlier 6-7 week estimate — the 9-step wizard, cascading state/district data, and richer review-detail rendering are real added scope, not a relabeling of the same work). See appointment_booking_app_trd.md for the full week-by-week checklist.

---

## 🔐 Privacy & Safety

- Firestore security rules enforce role checks server-side via custom claims, never client-reported role fields.
- Document/KML access restricted to the uploading applicant, Admins, and the specifically assigned committee member.
- Rejection reasons and clarification notes visible only to the applicant and assigned reviewer.
- Committee accounts cannot be created via public signup under any circumstance.
- Email verification required before booking submission.

---

## ✅ Definition of Done (MVP)

- [ ] Applicant can complete all 9 wizard steps and submit a booking in one final action
- [ ] Home screen correctly separates Upcoming Scheduled Surveys, Recent Requests, and Recent Activity
- [ ] Admin can assign a reviewer, and separately set/change a confirmed date
- [ ] Committee member sees full structured detail (XEN, area+KML, logistics, permissions) and can Approve/Reject/Clarify
- [ ] Clarification round-trip works exactly once per appointment
- [ ] Rejected appointments require a brand-new booking, no edit path
- [ ] Admin can assign a fieldwork task post-approval — **and** the still-unresolved committee "my assigned tasks" visibility gap has been explicitly decided one way or the other before this is marked done
- [ ] All notification triggers fire and land in the correct inbox
- [ ] Committee accounts can only be created by Admin
- [ ] Firestore/Storage rules tested to block cross-role access
- [ ] Admin can upload and see their own profile photo
