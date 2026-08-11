# Appointment Booking App — App Flow (Navigation & User Journey Map)

**Companion to:** appointment_booking_app_prd.md, appointment_booking_app_trd.md, appointment_booking_app_backend_schema.md
**Status:** Draft for build

---

## Overview

23 screens total across 3 roles — up from the original 13. The jump is almost entirely the booking flow, which went from a single form to a 9-step wizard. This doc maps every screen, its navigation targets, and its empty/error/loading states. See the six flagged issues in the chat response this accompanies before treating any of this as final — several are open decisions, not settled ones.

---

## Navigation Structure

**Applicant:** Bottom tab bar — Home / My Bookings / Profile. The booking wizard is a full-screen modal flow launched from Home, not a tab — it shouldn't be reachable by switching tabs mid-wizard (prevents silently abandoning wizard state via nav bar taps).
**Admin:** Drawer or tab bar — Dashboard / Committee Management / Profile. Task Assignment and Appointment Detail are pushed screens reached from the Dashboard, not top-level tabs.
**Committee Member:** Single-purpose — Dashboard / Profile (no bottom nav needed for just two destinations; a simple app bar profile icon suffices).

---

## Screen-by-Screen Flow

### Shared (3)

**1. Splash / Auth Check**
Checks Firebase Auth session on launch. Routes to Login if unauthenticated, or directly to the role-appropriate Home/Dashboard if a valid session exists.
- *Loading:* brief spinner while the auth state resolves (should be near-instant; flag it if it isn't).
- *Error:* if Firestore role lookup fails after Auth succeeds, show a retry screen rather than silently stranding the user on a blank page.

**2. Login**
Email + password. "Forgot password" link triggers Firebase's reset flow.
- *Error:* wrong credentials, unverified email (applicant-specific — block login-to-booking, not login itself), network failure — each needs a distinct, specific message, not one generic "login failed."

**3. Signup (Applicant only)**
Full Name, Organization (optional), Email, Phone, Password. Blocks pre-provisioned committee emails with "Account already exists. Please log in."
- *Error:* duplicate email, weak password, invalid phone format — inline field-level errors, not a single toast.

---

### Applicant — Core (4)

**4. Home**
Three sections:
- **Upcoming Scheduled Surveys** — appointments with status `approved` or `task_assigned`, sorted by `confirmedDate` (fallback `preferredDate`) ascending. This is what "any survey scheduled" refers to — distinct from the pending-request list below.
- **Recent Appointment Requests** — last 5 appointments regardless of status, sorted by `createdAt` descending, tap-through to Appointment Detail.
- **Recent Activity** — a flat feed of the applicant's own status-change events (approvals, rejections, clarification requests) pulled from the `auditLog` subcollections via a `collectionGroup` query — see schema update below.
- Prominent **"Start New Survey"** button launches the booking wizard.
- *Empty:* first-time applicant with zero appointments — show the Start New Survey CTA large and centered, no empty list placeholders competing for attention.
- *Loading:* skeleton cards for each of the 3 sections while the 3 queries resolve independently — don't block the whole screen on the slowest one.
- *Error:* if the Recent Activity collectionGroup query fails (e.g., missing index before first deploy), fail that section silently with a retry icon — don't block the other two sections or the CTA.

**5. My Bookings**
Full paginated list of all the applicant's appointments (20 per page), filterable by status. Tap-through to Appointment Detail.
- *Empty:* "No bookings yet" + Start New Survey button.
- *Loading:* skeleton list rows.

**6. Appointment Detail**
Full read view of everything captured in the wizard (survey type, state/district, XEN contact, area name + KML download, dates, logistics, permission documents), current status, rejection reason or clarification note where applicable, and the clarification-reply field when status is `clarification_requested`.
- *Empty:* n/a (always has data once reached)
- *Error:* KML/document download failure — show retry, don't fail the whole screen.

**7. Profile**
Name, organization, email, phone — edit contact info only. No photo upload here per the flow as given (see flag #6 in chat — confirm if this should change).

---

### Applicant — New Survey Booking Wizard (9)

Launched from Home's "Start New Survey" button. Linear, back-navigable, each step validates before "Next" is enabled. Final submission happens once, at step 8 — steps 1-7 only accumulate local (Riverpod) state, no partial Firestore writes.

**8. Step 1 — Choose Survey Type**
Single-select: Socio Economic Survey / Benchmarking (DGPS Survey) / DGPS Survey / Bathymetry Survey (Red Line) / Other (reveals required text field, max 60 chars).

**9. Step 2 — State & District**
Cascading dropdowns. District options filter based on selected State. Backed by a static bundled JSON asset (India states/districts — see flag above), not a Firestore query — this reference data changes rarely enough that shipping it in the app is simpler and free.

**10. Step 3 — XEN Details**
Name (max 100 chars), Mobile (10 digits, validated), Email (valid format) — of the Executive Engineer responsible for the district's survey.

**11. Step 4 — Survey Area & KML/KMZ**
Area Name (text, max 150 chars) + KML/KMZ file upload (single file, per the schema's `kmlFile` map — not an array).
- *Error:* wrong file extension, file too large — inline validation before upload starts, not after a failed network call.
- *Loading:* upload progress indicator — KML files can be large enough that silent waiting reads as a frozen screen.

**12. Step 5 — Survey Start Date**
Date picker, Saturdays/Sundays disabled, min date = tomorrow, max date = +90 days.

**13. Step 6 — Logistics & Personnel**
Local Coordinator: **Name (added — see flag #3 in chat) + Designation** (max 100 chars each). Driver Name (max 100) + Mobile (10 digits, validated). Vehicle Number (max 20 chars) + Vehicle Model (max 60 chars).

**14. Step 7 — Permissions**
Document upload: permission-to-survey document + consent document. Same constraint as the original spec — min 1, max 5 files, PDF/JPG/PNG only, 5MB max per file (this step is where the PRD's original "Document Upload" requirement now lives, renamed for clarity — not a duplicate requirement).

**15. Step 8 — Review & Confirm**
Read-only summary of all 7 prior steps, grouped by section, each with an "Edit" link that jumps back to that step without losing progress on the others. "Confirm Booking" button triggers the single `submitAppointment` call with the full accumulated payload.
- *Loading:* explicit "Submitting..." state — this call uploads multiple files plus writes the appointment document plus runs the rate-limit transaction; it will not be instant.
- *Error:* rate limit exceeded (3+ unresolved appointments already open) — specific message, not a generic failure. Network failure mid-submit — must not leave a half-created appointment; the rate-limit transaction (see schema) already guards against partial writes here.

**16. Step 9 — Booking Acknowledgement**
Confirmation screen with appointment reference. "Done" returns to Home.

---

### Admin (5)

**17. Admin Dashboard**
All appointments, filterable by status and survey type, paginated. Shows applicant name per row (denormalized, no extra read).
- *Empty:* "No appointments yet" (unlikely to matter post-launch, but matters on day one).
- *Loading:* skeleton rows.

**18. Appointment Detail — Admin view**
Full detail (same rich data as the applicant's own Appointment Detail) plus the assignment action (dropdown of active committee members → `assignReviewer`) and, once approved, the `confirmedDate` field if the date needs changing from the applicant's original request.

**19. Committee Management**
Create/deactivate committee accounts (name, email, expertise tag).
- *Error:* duplicate email on creation — specific message pointing at the exact conflict.

**20. Task Assignment**
Post-approval fieldwork assignment — dropdown of committee members, can repeat the original reviewer.

**21. Admin Profile**
Name, details, **photo upload** — new per this flow. Uses the `photoUrl` field now added to `users/{uid}` (see schema update). Scoped to Admin only for now per the flow as described — flag if Applicant/Committee should get this too, since the field is schema-ready for either.

---

### Committee Member (2)

**22. Committee Dashboard**
Appointments assigned to this member for review, paginated.
- *Empty:* "No appointments assigned to you yet."
- **Still missing, third time flagged:** no screen here surfaces appointments this member has been assigned as *fieldwork task* executor (distinct from review assignments). The schema field (`assignedTaskMemberId`) and its composite index are ready; the screen isn't in this flow either. Needs an explicit decision, not another silent pass-through.

**23. Review Detail**
Same full rich data view as Admin's Appointment Detail (XEN, area + KML, logistics, permission docs) plus Approve / Reject (reason, mandatory) / Request Clarification (note, mandatory) actions.

---

## Global Edge-Case Patterns

- **Session expiry mid-wizard:** if the Firebase Auth token expires while the applicant is on step 4-7 of the booking wizard, don't silently kick to Login and lose everything — attempt a silent token refresh first; only force re-login if that fails, and warn before discarding wizard state.
- **Network loss during file upload** (KML in step 4, permission docs in step 7): pause and offer retry rather than failing the entire step silently.
- **Concurrent Admin actions:** two Admins viewing the same Dashboard could both attempt to assign the same appointment — the `assignReviewer` function should check current status server-side before acting, not just trust the client's last-known state, so a double-assignment can't silently overwrite an already-assigned appointment.
- **Stale list data:** Admin/Committee dashboards showing a cached list where an appointment's status changed elsewhere (e.g., Admin dashboard shows `pending_assignment` after another admin already assigned it) — use Firestore's real-time listeners (`snapshots()`) for these dashboards rather than one-time `get()` calls, so status changes reflect without a manual pull-to-refresh.
