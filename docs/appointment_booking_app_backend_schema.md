# Appointment Booking App — Backend Schema

**Companion to:** appointment_booking_app_prd.md (v2.0), appointment_booking_app_trd.md, appointment_booking_app_flow.md
**Database:** Cloud Firestore (NoSQL, document/collection model)
**Status:** v2.0 — supersedes the earlier schema following the App Flow review

---

## Overview

Reflects the 9-step booking wizard's structured data (state/district, XEN contact, survey area, logistics, permissions) in place of the earlier flat `location`/`description`/`documentUrls[]` fields. Also adds `photoUrl` to `users` (Admin profile photos) and `applicantId` to `auditLog` entries (needed for the Home screen's cross-appointment Recent Activity feed). The `auditLog` subcollection itself — added last revision to satisfy the PRD's stated audit-trail vision — is unchanged in structure, just gets one new field.

**Firestore type reference:** `string`, `number`, `boolean`, `timestamp`, `array`, `map`, `null`.

---

## Collection: `users/{uid}`

Document ID = Firebase Auth UID.

| Field | Type | Notes |
|---|---|---|
| `role` | `string` | Enum: `"applicant"` \| `"admin"` \| `"committee"`. Mirrored from a custom claim — never trust this field alone for security decisions. |
| `fullName` | `string` | |
| `orgName` | `string \| null` | Applicant-only, optional |
| `email` | `string` | Mirrored from Auth |
| `phone` | `string` | 10 digits, validated |
| `expertiseTag` | `string \| null` | Committee-only |
| `active` | `boolean` | Committee-only deactivation flag |
| `photoUrl` | `string \| null` | **New.** Storage path (not a download URL, same reasoning as document files below), populated via `updateProfilePhoto`. Built for Admin per the current flow, but the field works identically for any role if Applicant/Committee profile photos get added later. |
| `createdAt` | `timestamp` | |
| `updatedAt` | `timestamp` | |

`emailVerified` still deliberately not stored here — check `request.auth.token.email_verified` directly in rules.

---

## Collection: `appointments/{appointmentId}`

Document ID = Firestore auto-generated ID.

| Field | Type | Notes |
|---|---|---|
| `applicantId` | `string` | |
| `applicantName` | `string` | Denormalized |
| `applicantOrgName` | `string \| null` | Denormalized |
| `applicantEmail` | `string` | Denormalized |
| `surveyType` | `string` | Enum: `"socio_economic_survey"`, `"benchmarking_dgps_survey"`, `"dgps_survey"`, `"bathymetry_survey_red_line"`, `"other"` |
| `customSurveyName` | `string \| null` | Only when `surveyType == "other"`, max 60 chars |
| `state` | `string` | **New — replaces the old flat `location`.** From the bundled India states reference list. |
| `district` | `string` | **New.** Filtered by `state` in the UI, but stored as a plain string, not a foreign key — this is fixed reference data, not a normalized relation. |
| `xenDetails` | `map` | **New.** `{ name: string, mobile: string, email: string }` — Executive Engineer contact for the district |
| `areaName` | `string` | **New.** Max 150 chars — replaces part of what the old flat `location` covered |
| `kmlFile` | `map` | Unchanged structure: `{ storagePath, originalFileName, fileType: "kml"\|"kmz", sizeBytes, uploadedAt }` — single file, not an array |
| `preferredDate` | `timestamp` | Applicant's requested survey start date |
| `confirmedDate` | `timestamp \| null` | Admin-set, via `setConfirmedDate`. Restored in this revision — dropped from the app entirely between the original requirements-gathering and the v1.0 PRD, now has a field, a function, and a screen affordance. |
| `logistics` | `map` | **New.** See **Logistics map** below |
| `permissionDocuments` | `array<map>` | **Renamed from `documentFiles`** to match the wizard's "Permissions" step naming — same underlying constraint (min 1, max 5, PDF/JPG/PNG, 5MB max each), not a new or duplicate requirement |
| `status` | `string` | Enum unchanged: `"pending_assignment"` \| `"under_review"` \| `"clarification_requested"` \| `"approved"` \| `"rejected"` \| `"task_assigned"` |
| `assignedReviewerId` | `string \| null` | |
| `assignedReviewerName` | `string \| null` | Denormalized |
| `assignedTaskMemberId` | `string \| null` | |
| `assignedTaskMemberName` | `string \| null` | Denormalized |
| `rejectionReason` | `string \| null` | Max 500 chars, latest value only |
| `clarificationNote` | `string \| null` | Max 500 chars, latest value only |
| `clarificationReply` | `string \| null` | Max 500 chars, latest value only |
| `createdAt` | `timestamp` | |
| `updatedAt` | `timestamp` | |

**Removed in this revision:** `description` (the old free-text Purpose/Description, max 1000 chars) — not present anywhere in the 9-step wizard as described. If a free-text description is still wanted, it needs to be explicitly reintroduced as a wizard step; it isn't silently preserved here.

**Logistics map** (`logistics`):
| Field | Type | Notes |
|---|---|---|
| `coordinatorName` | `string` | **Added.** The original spec only asked for a designation/title with no name — not enough to actually reach the person. Max 100 chars. |
| `coordinatorDesignation` | `string` | Max 100 chars |
| `driverName` | `string` | Max 100 chars |
| `driverMobile` | `string` | 10 digits, validated |
| `vehicleNumber` | `string` | Max 20 chars |
| `vehicleModel` | `string` | Max 60 chars |

**Permission document map** (`permissionDocuments` array entries — same structure as before, just relocated/renamed):
| Field | Type | Notes |
|---|---|---|
| `storagePath` | `string` | Not a download URL — same reasoning as before |
| `originalFileName` | `string` | |
| `fileType` | `string` | `"pdf"` \| `"jpg"` \| `"png"` |
| `sizeBytes` | `number` | |
| `uploadedAt` | `timestamp` | |

---

## Subcollection: `appointments/{appointmentId}/auditLog/{logId}`

Unchanged from the previous revision except one addition:

| Field | Type | Notes |
|---|---|---|
| `action` | `string` | Enum: `"created"` \| `"assigned_reviewer"` \| `"approved"` \| `"rejected"` \| `"clarification_requested"` \| `"clarification_replied"` \| `"task_assigned"` \| `"date_confirmed"` |
| `applicantId` | `string` | **New.** Denormalized onto every entry (not just derivable from the parent appointment) specifically so a `collectionGroup('auditLog').where('applicantId', '==', uid)` query can power the Home screen's Recent Activity feed without needing a separate top-level activity collection. |
| `performedByUid` | `string` | |
| `performedByRole` | `string` | `"applicant"` \| `"admin"` \| `"committee"` |
| `performedByName` | `string` | Denormalized |
| `timestamp` | `timestamp` | |
| `details` | `map \| null` | |

Still a subcollection, not a growing array — same reasoning as before (1MB document ceiling, unnecessary full-history reads).

---

## Collection: `rateLimits/{applicantId}`

Unchanged from the previous revision.

| Field | Type | Notes |
|---|---|---|
| `pendingCount` | `number` | |
| `lastBookingAt` | `timestamp` | |

**Still critical:** `checkRateLimit` and the appointment-creation write must happen inside a single Firestore transaction — a naive read-then-write is a race condition, as noted previously. This has not changed with the wizard restructuring and is easy to forget given how much else moved.

---

## Firebase Storage Path Convention

```
appointments/{appointmentId}/permissionDocuments/{uuid}_{originalFileName}
appointments/{appointmentId}/kml/{uuid}_{originalFileName}
users/{uid}/profile/{uuid}_{originalFileName}
```

Third path is **new** — Admin profile photos. Readable broadly within the app (not sensitive), writable only by the owning account. `storagePath` fields still store the path, never a `getDownloadURL()` result — same reasoning as before (embedded access tokens, staleness risk).

---

## Required Composite Indexes

Four carried over, two new:

| Query (used by) | Fields |
|---|---|
| Admin Dashboard, filter by status | `status` (==), `createdAt` (desc) |
| Admin Dashboard, filter by status + survey type | `surveyType` (==), `status` (==), `createdAt` (desc) |
| Committee Dashboard (review assignments) | `assignedReviewerId` (==), `status` (==), `createdAt` (desc) |
| Applicant "My Bookings" list | `applicantId` (==), `createdAt` (desc) |
| **New** — Home screen "Upcoming Scheduled Surveys" | `applicantId` (==), `status` (`in` [`approved`, `task_assigned`]), `confirmedDate` (asc) |
| **New** — Home screen "Recent Activity" (`collectionGroup` on `auditLog`) | `applicantId` (==), `timestamp` (desc) |

**Still missing, third time flagged across this whole review:** if a "My Assigned Tasks" screen for committee members ever gets built, it needs `assignedTaskMemberId` (==), `status` (==), `createdAt` (desc) as a seventh index. The field has existed in the schema since the previous revision; the screen still doesn't exist anywhere in the App Flow. This needs an explicit yes/no decision, not another silent carry-forward.

Deploy via `firestore.indexes.json` and `firebase deploy --only firestore:indexes` — Firestore's own error messages will suggest the exact definition the first time an un-indexed query runs during Emulator Suite testing.
