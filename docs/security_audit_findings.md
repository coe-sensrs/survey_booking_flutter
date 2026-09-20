# 🛡️ Security Audit Findings & Vulnerability Report

**Project:** Survey Desk (`survey_booking_app`)  
**Stack:** Flutter 3.x + Firebase (Cloud Firestore, Cloud Storage, Auth, 2nd Gen Cloud Functions on Node.js 20)  
**Reviewed Commit:** `899a30a169bb4f2e4604cb8ab0ff64207c3687c1`  
**Date of Audit:** September 15, 2026  
**Auditor:** Elite Cybersecurity Specialist (`security-auditor`)  
**Review Type:** Defensive Source-First Architecture & Implementation Audit  
**Artifact Directory:** `~/audits/my-project/` (Validated with `report-schema.json` and `coverage-ledger.json`)

---

## 1. Executive Summary

A comprehensive source-code security review was conducted across the Flutter client application, Firebase Security Rules (Firestore and Storage), 2nd Gen Cloud Functions, and Android platform configurations.

The application architecture demonstrates strong engineering discipline in several high-risk vectors:
- **Server-Mediated Auth Gateway**: Sensitive authentication vectors (login, registration, password reset) are routed through serverless Cloud Functions utilizing the Google Identity Toolkit REST API. Brute-force protections are backed by SHA-256 hashed document keys in `/auth_rate_limits/`, with direct client writes completely blocked (`allow read, write: if false;`).
- **Atomic Concurrency Transactions**: Appointment resolution logic (`reviewAppointment`) adheres to Firestore read-before-write transactional invariants, atomically updating status, decrementing rate limits, and appending immutable audit log records.
- **Committee Read Scoping**: Read permissions on `/appointments` restrict committee members strictly to appointments where they are designated as the assigned reviewer or fieldwork task member.

However, the audit identified **six confirmed vulnerabilities** (2 High, 3 Medium, 1 Low), **one deployment verification item**, and **one disproved hypothesis**:

```
  CRITICAL: 0
  HIGH:     2  ████████████████████
  MEDIUM:   3  ██████████████████████████████
  LOW:      1  ██████████
  INFO:     1  ██████████
```

---

## 2. Findings Matrix

| Finding ID | Title | Component | Severity | OWASP 2025 | Status |
|---|---|---|---|---|---|
| [`SEC-01`](#sec-01-unrestricted-cross-user-storage-upload-on-appointment-files) | Unrestricted Cross-User Storage Upload on Appointment Files | [`storage.rules`](file:///d:/flutter%20projects/survey_booking_app/storage.rules) | **HIGH** | A01: Broken Access Control | **Confirmed** |
| [`SEC-02`](#sec-02-server-mediated-appointment-quota-bypass-via-direct-firestore-write) | Server-Mediated Appointment Quota Bypass via Direct Firestore Write | [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules) | **HIGH** | A01: Broken Access Control | **Confirmed** |
| [`SEC-03`](#sec-03-global-unrestricted-read-access-to-user-directory-exposes-pii) | Global Unrestricted Read Access to User Directory Exposes PII | [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules) | **MEDIUM** | A01: Broken Access Control | **Confirmed** |
| [`SEC-04`](#sec-04-predictable-temporary-password-generation-using-mathrandom) | Predictable Temporary Password Generation Using `Math.random()` | [`create_committee_account.ts`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/auth/create_committee_account.ts) | **MEDIUM** | A04: Cryptographic Failures | **Confirmed** |
| [`SEC-05`](#sec-05-deactivated-staff-account-operations-permitted-in-appointment-mutations) | Deactivated Staff Account Operations Permitted in Mutations | [`admin_appointment_mutations.ts`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/admin_appointment_mutations.ts) | **MEDIUM** | A07: Identification & Auth | **Confirmed** |
| [`SEC-06`](#sec-06-missing-android-application-backup-restriction-exposes-local-hive-cache) | Missing Android Application Backup Restriction Exposes Hive Cache | [`AndroidManifest.xml`](file:///d:/flutter%20projects/survey_booking_app/android/app/src/main/AndroidManifest.xml) | **LOW** | A02: Security Misconfiguration | **Confirmed** |
| [`SEC-07`](#sec-07-firebase-app-check-enforcement-mode-verification) | Firebase App Check Enforcement Mode Verification | Cloud Functions / Client | **INFO** | A02: Security Misconfiguration | **Needs Validation** |
| [`SEC-08`](#sec-08-hypothetical-direct-client-tampering-of-rate-limits-collection) | Direct Client Tampering of Rate Limits Collection | [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules) | **N/A** | A01: Broken Access Control | **Rejected** |

---

## 3. Deep-Dive Findings Analysis

---

### SEC-01: Unrestricted Cross-User Storage Upload on Appointment Files

- **Fingerprint:** `storage:appointment-files:cross-user-upload-bypass`
- **Severity:** **HIGH** (Likelihood: High, Impact: High, Confidence: High)
- **Affected File:** [`storage.rules:98`](file:///d:/flutter%20projects/survey_booking_app/storage.rules#L98), [`storage.rules:121`](file:///d:/flutter%20projects/survey_booking_app/storage.rules#L121)
- **CWE:** CWE-284 (Improper Access Control), CWE-434 (Unrestricted Upload of File)

#### Technical Analysis
In [`storage.rules`](file:///d:/flutter%20projects/survey_booking_app/storage.rules), the `create` rules for `/appointments/{appointmentId}/permissionDocuments/{fileName}` (line 98) and `/appointments/{appointmentId}/kml/{fileName}` (line 121) are defined as:
```javascript
// storage.rules:98
allow create: if isEmailVerified() && isPdfOrImage() && isUnder5MB();

// storage.rules:121
allow create: if isEmailVerified() && isUnder15MB();
```
Neither rule checks whether the uploading user owns the appointment (`isOwningApplicant(appointmentId)`), nor do they verify that the `appointmentId` belongs to the caller. Consequently, **any authenticated user who has verified their email address can upload arbitrary files directly into another user's appointment storage directory**.

Furthermore, line 121 lacks any MIME content-type validation (`request.resource.contentType.matches(...)`), allowing verified callers to upload arbitrary binary payloads under 15MB into the `kml/` folder.

#### Evidence in Test Suite
The security test suite ([`appointment_files.rules.test.js:134-145`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/storage/appointment_files.rules.test.js#L134-L145)) explicitly documents this defect:
```javascript
test('applicant B cannot upload to applicant A appointment path', async () => {
  await seedAppointment(testEnv);
  const ref = testEnv.authenticatedContext(APPLICANT_B.uid, APPLICANT_B.token).storage().ref(kmlPath);
  // Note: The current create rule only checks isEmailVerified + size, not ownership.
  // This is safe because reads are restricted, but document it here.
  await assertSucceeds(ref.put(new Uint8Array(1024), { contentType: 'application/vnd.google-earth.kml+xml' }));
});
```
The test comment claims this is "safe because reads are restricted," but an attacker can inject fraudulent land permits or corrupt spatial boundary files into a victim's pending appointment, directly misleading review committee members during official evaluations.

#### Remediation Diff
Enforce ownership checking on creation. For pre-creation uploads (before the Firestore appointment document exists), prefix the appointment ID with the applicant's UID (e.g. `appointments/{uid}_{appointmentId}/...`) or verify existing document ownership:
```diff
--- a/storage.rules
+++ b/storage.rules
@@ -95,7 +95,7 @@ service firebase.storage {
                   isOwningApplicant(appointmentId);
 
       // Create: authenticated + email-verified applicant or admin
-      allow create: if isEmailVerified() && isPdfOrImage() && isUnder5MB();
+      allow create: if isEmailVerified() && (isAdmin() || appointmentId.matches('^' + request.auth.uid + '_.*') || isOwningApplicant(appointmentId)) && isPdfOrImage() && isUnder5MB();
 
       // Delete: admin or owning applicant (applicant may revise before submission)
       allow delete: if isAdmin() || isOwningApplicant(appointmentId);
@@ -118,7 +118,7 @@ service firebase.storage {
                   isOwningApplicant(appointmentId);
 
       // Create: authenticated + email-verified applicant or admin
-      allow create: if isEmailVerified() && isUnder15MB();
+      allow create: if isEmailVerified() && (isAdmin() || appointmentId.matches('^' + request.auth.uid + '_.*') || isOwningApplicant(appointmentId)) && request.resource.contentType.matches('application/vnd.google-earth.*') && isUnder15MB();
```

---

### SEC-02: Server-Mediated Appointment Quota Bypass via Direct Firestore Write

- **Fingerprint:** `firestore:appointments:direct-create-quota-bypass`
- **Severity:** **HIGH** (Likelihood: High, Impact: High, Confidence: High)
- **Affected File:** [`firestore.rules:104-120`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules#L104-L120)
- **CWE:** CWE-799 (Improper Control of Generation of Multiple Requests), CWE-284 (Improper Access Control)

#### Technical Analysis
The core security and concurrency architecture documented in `brain/auth_security.md` requires that all appointment submissions be mediated by the 2nd Gen Cloud Function [`submitAppointment`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/submit_appointment.ts#L139-L200) to atomically check and enforce the 3-pending-appointment quota:
```typescript
// submit_appointment.ts:145
if (pendingCount >= 3) {
    throw new HttpsError(
        "resource-exhausted",
        "You have reached the maximum of 3 unresolved survey requests..."
    );
}
```
However, in [`firestore.rules:104-120`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules#L104-L120), direct client creation was left active:
```javascript
match /appointments/{appointmentId} {
  allow create: if isApplicant() &&
                isEmailVerified() &&
                request.resource.data.applicantId == request.auth.uid &&
                request.resource.data.keys().hasAll([...]) &&
                request.resource.data.status == 'pending_assignment' && ...
```

#### Exploitation
An applicant can bypass the Flutter repository wrapper ([`FirebaseAppointmentRepository.submitAppointment`](file:///d:/flutter%20projects/survey_booking_app/lib/core/services/firebase_appointment_repository.dart#L160)) and write directly to Firestore using standard SDK commands (`FirebaseFirestore.instance.collection('appointments').add(...)`). Direct writes:
1. Do not query or evaluate `/rateLimits/{applicantId}.pendingCount`.
2. Do not increment the user's pending appointment counter.
3. Do not create an entry in `/appointments/{appointmentId}/auditLog/`.

An attacker can flood the administrative queue with thousands of pending bookings, completely circumventing rate-limiting protections.

#### Remediation Diff
Change `allow create:` to `allow create: if false;`, mirroring `allow update: if false;` and forcing all creations through `submitAppointment`:
```diff
--- a/firestore.rules
+++ b/firestore.rules
@@ -101,23 +101,8 @@ service cloud.firestore {
                     resource.data.assignedTaskMemberId == request.auth.uid
                   ));
 
-      // Applicants can create appointments (self-owned, verified email, correct initial status)
-      allow create: if isApplicant() &&
-                    isEmailVerified() &&
-                    request.resource.data.applicantId == request.auth.uid &&
-                    request.resource.data.keys().hasAll([
-                      'applicantId', 'applicantName', 'applicantEmail',
-                      'surveyType', 'state', 'district', 'areaName',
-                      'preferredDate', 'status', 'createdAt', 'updatedAt'
-                    ]) &&
-                    isValidString(request.resource.data.surveyType, 1, 50) &&
-                    isValidString(request.resource.data.state, 1, 100) &&
-                    isValidString(request.resource.data.district, 1, 100) &&
-                    isValidString(request.resource.data.areaName, 1, 150) &&
-                    (!('customSurveyName' in request.resource.data) || isValidString(request.resource.data.customSurveyName, 1, 60)) &&
-                    request.resource.data.status == 'pending_assignment' &&
-                    request.resource.data.createdAt is timestamp &&
-                    request.resource.data.preferredDate is timestamp;
+      // All appointment creations must route through submitAppointment Cloud Function
+      allow create: if false;
 
       // All state transitions are handled by backend Cloud Functions
       allow update: if false;
```

---

### SEC-03: Global Unrestricted Read Access to User Directory Exposes PII

- **Fingerprint:** `firestore:users:global-pii-exposure`
- **Severity:** **MEDIUM** (Likelihood: High, Impact: Medium, Confidence: High)
- **Affected File:** [`firestore.rules:58`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules#L58)
- **CWE:** CWE-200 (Exposure of Sensitive Information), CWE-359 (Exposure of Private Personal Information)

#### Technical Analysis
In [`firestore.rules:58`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules#L58):
```javascript
match /users/{uid} {
  // Any authenticated user can read profile data
  // (needed for display names, reviewer assignments, avatars across roles)
  allow read: if isAuthenticated();
```
In Cloud Firestore, `allow read` applies to both single-document reads (`get`) and collection queries (`list`). Each document in `/users/{uid}` contains:
- Legal full name
- Primary mobile telephone number
- Personal/official email address
- Organization name / contractor firm
- Internal system role (`applicant`, `committee`, `admin`) and expertise tag

Any attacker who self-registers an applicant account can execute `db.collection('users').get()` and scrape the entire contact database of citizens, government survey officers, and administrators.

#### Evidence in Test Suite
The unit test suite ([`users.rules.test.js:65-75`](file:///d:/flutter%20projects/survey_booking_app/firebase/tests/firestore/users.rules.test.js#L65-L75)) validates that Applicant A can read Applicant B's full document:
```javascript
test('authenticated user can read another user document', async () => {
  // Per rules: any authenticated user can read profile data
  const db = testEnv.authenticatedContext(APPLICANT_A.uid, authToken(APPLICANT_A).token).firestore();
  await assertSucceeds(db.collection('users').doc(APPLICANT_B.uid).get());
});
```

#### Remediation Diff
Restrict user document reads to the account owner or administrators:
```diff
--- a/firestore.rules
+++ b/firestore.rules
@@ -55,8 +55,8 @@ service cloud.firestore {
     match /users/{uid} {
       // Any authenticated user can read profile data
       // (needed for display names, reviewer assignments, avatars across roles)
-      allow read: if isAuthenticated();
+      allow read: if isOwner(uid) || isAdmin();
```
*Note*: If applicant views need to display committee reviewer names, either store public staff directory cards in a separate `/staffDirectory` collection (containing only `displayName`, `photoUrl`, and `expertiseTag`), or denormalize the reviewer name onto the appointment document during the `assignReviewer` mutation.

---

### SEC-04: Predictable Temporary Password Generation Using `Math.random()`

- **Fingerprint:** `functions:admin:insecure-temp-password-randomness`
- **Severity:** **MEDIUM** (Likelihood: Low, Impact: Medium, Confidence: High)
- **Affected File:** [`functions/src/functions/auth/create_committee_account.ts:94`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/auth/create_committee_account.ts#L94)
- **CWE:** CWE-330 (Use of Insufficiently Random Values), CWE-338 (Use of Cryptographically Weak PRNG)

#### Technical Analysis
When an administrator provisions a new committee member account via `createCommitteeAccount`, the temporary password is generated using:
```typescript
// create_committee_account.ts:94
const tempPassword = `Temp@${Math.random().toString(36).slice(-8)}!1`;
```
V8's `Math.random()` algorithm (xoroshiro128+) is not a cryptographically secure pseudo-random number generator (CSPRNG). Its internal 128-bit state can be reconstructed by observing consecutive outputs. An attacker who can sample random values generated by the Node.js process can predict passwords generated for subsequent accounts.

#### Remediation Diff
Use the native Node.js `crypto` module to generate high-entropy random bytes:
```diff
--- a/functions/src/functions/auth/create_committee_account.ts
+++ b/functions/src/functions/auth/create_committee_account.ts
@@ -1,4 +1,5 @@
 import {onCall, HttpsError} from "firebase-functions/v2/https";
+import * as crypto from "crypto";
 import {db, auth, FieldValue} from "../../lib/admin";
 
@@ -93,2 +94,3 @@ export const createCommitteeAccount = onCall(
         // 4. Generate Temporary Password
-        const tempPassword = `Temp@${Math.random().toString(36).slice(-8)}!1`;
+        const randomChars = crypto.randomBytes(9).toString("base64").replace(/[^a-zA-Z0-9]/g, "").slice(0, 8);
+        const tempPassword = `Temp@${randomChars}!1`;
```

---

### SEC-05: Deactivated Staff Account Operations Permitted in Appointment Mutations

- **Fingerprint:** `functions:appointments:deactivated-user-mutation-execution`
- **Severity:** **MEDIUM** (Likelihood: Medium, Impact: Medium, Confidence: High)
- **Affected File:** [`admin_appointment_mutations.ts:7-15`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/admin_appointment_mutations.ts#L7-L15), [`review_appointment.ts:33-47`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/review_appointment.ts#L33-L47)
- **CWE:** CWE-613 (Insufficient Session Expiration), CWE-284 (Improper Access Control)

#### Technical Analysis
In `create_committee_account.ts` and `authenticate_user.ts`, caller account activation is strictly validated:
```typescript
if (callerDoc.exists && (callerDoc.data()?.active === false || callerDoc.data()?.isActive === false)) {
    throw new HttpsError("permission-denied", "This account has been deactivated.");
}
```
However, the administrative mutation functions ([`assignReviewer`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/admin_appointment_mutations.ts#L20), [`setConfirmedDate`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/admin_appointment_mutations.ts#L77), [`assignFieldworkTask`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/admin_appointment_mutations.ts#L129)) and the committee review function ([`reviewAppointment`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/review_appointment.ts#L25)) only inspect custom claims on the JWT:
```typescript
function requireAdmin(request: ...) {
    if (role !== "admin") {
        throw new HttpsError("permission-denied", "Only administrators can perform this action.");
    }
}
```
If an administrator or committee member is deactivated in Firestore (`users/{uid}.active = false`), their issued Firebase ID token remains valid for up to 1 hour. During this window, the deactivated staff member can continue to assign, review, approve, or reject appointments.

#### Remediation Diff
Verify the caller's Firestore profile status within `requireAdmin` and `reviewAppointment`:
```diff
--- a/functions/src/functions/appointments/admin_appointment_mutations.ts
+++ b/functions/src/functions/appointments/admin_appointment_mutations.ts
@@ -8,4 +8,8 @@ function requireAdmin(request: {auth?: {uid: string; token: Record<string, unkn
     if (!request.auth) {
         throw new HttpsError("unauthenticated", "You must be signed in to perform this action.");
     }
+    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
+    if (!callerDoc.exists || callerDoc.data()?.active === false) {
+        throw new HttpsError("permission-denied", "This account has been deactivated.");
+    }
     const role = request.auth.token.role as string | undefined;
```

---

### SEC-06: Missing Android Application Backup Restriction Exposes Local Hive Cache

- **Fingerprint:** `mobile:android:allow-backup-unrestricted`
- **Severity:** **LOW** (Likelihood: Low, Impact: Low, Confidence: High)
- **Affected File:** [`android/app/src/main/AndroidManifest.xml:2`](file:///d:/flutter%20projects/survey_booking_app/android/app/src/main/AndroidManifest.xml#L2)
- **CWE:** CWE-200 (Exposure of Sensitive Information), CWE-922 (Insecure Storage of Sensitive Information)

#### Technical Analysis
In [`AndroidManifest.xml`](file:///d:/flutter%20projects/survey_booking_app/android/app/src/main/AndroidManifest.xml), the `<application>` tag omits the `android:allowBackup` attribute. On Android, `android:allowBackup` defaults to `true`.

Furthermore, [`HiveStorageService`](file:///d:/flutter%20projects/survey_booking_app/lib/core/services/hive_storage_service.dart#L30) opens `wizard_draft_box` without encryption. Anyone with physical access to an unlocked handset or an active ADB debugging session can execute:
```bash
adb backup -f survey_desk_backup.ab -noapk com.example.survey_booking_app
```
and extract unencrypted draft documents containing coordinator contact information, driver mobile numbers, and parcel location coordinates.

#### Remediation Diff
Explicitly disable ADB application backup in `AndroidManifest.xml`:
```diff
--- a/android/app/src/main/AndroidManifest.xml
+++ b/android/app/src/main/AndroidManifest.xml
@@ -3,4 +3,5 @@
     <application
         android:label="Survey Desk"
         android:name="${applicationName}"
+        android:allowBackup="false"
         android:icon="@mipmap/ic_launcher">
```

---

### SEC-07: Firebase App Check Enforcement Mode Verification

- **Fingerprint:** `cloud:app-check:enforcement-mode-verification`
- **Status:** **NEEDS VALIDATION**
- **Affected Components:** Cloud Functions 2nd Gen & Cloud Firestore

#### Description
All 2nd Gen callable Cloud Functions explicitly declare `enforceAppCheck: false` in their option blocks:
```typescript
export const authenticateUser = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false, // <-- Explicitly disabled
        secrets: [webApiKey],
    }, ...
);
```
In [`lib/core/services/firebase_app_check_setup.dart`](file:///d:/flutter%20projects/survey_booking_app/lib/core/services/firebase_app_check_setup.dart), App Check is initialized in "audit mode" with a dummy reCAPTCHA key (`kWebRecaptchaSiteKey = 'put-default-web-sitekey'`).

Whether App Check is actively enforced at the Firebase project level cannot be determined from Git source code alone.

#### Verification Plan for Project Owner
1. Navigate to the **Firebase Console** -> **App Check**.
2. Check the **Apps** tab: Confirm that Android (`com.sensrs.survey_booking_app`) is bound to the Play Integrity provider.
3. Check the **APIs** tab: Verify whether **Cloud Functions** and **Cloud Firestore** are set to "Enforced" or "Monitoring". If monitoring, review metric charts for non-attested requests before flipping to "Enforce".

---

### SEC-08: Hypothetical Direct Client Tampering of Rate Limits Collection

- **Fingerprint:** `firestore:rate-limits:client-tampering-claim`
- **Status:** **REJECTED (DISPROVED)**

#### Description & Refutation
The audit evaluated whether client SDK callers could tamper with rate limit records to reset lockout timers or clear submission quotas.

Inspection of [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules) conclusively disproves this vulnerability:
- `/rateLimits/{applicantId}` (line 169): `allow write: if false;`
- `/auth_rate_limits/{docId}` (line 179): `allow read, write: if false;`

Both collections are locked to the Firebase Admin SDK inside trusted Cloud Functions. No client SDK caller can read or alter rate limit documents directly.

---

## 4. Remediation Checklist & Roadmap

| Priority | Action Item | Affected File | Estimated Effort |
|:---:|---|---|:---:|
| **P0** | Change `allow create:` to `allow create: if false;` on `/appointments` | [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules) | 5 mins |
| **P0** | Add appointment ownership / UID prefix check on Storage file creation | [`storage.rules`](file:///d:/flutter%20projects/survey_booking_app/storage.rules) | 15 mins |
| **P1** | Restrict `/users/{uid}` read access to `isOwner(uid) || isAdmin()` | [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules) | 10 mins |
| **P1** | Add `active !== false` verification inside mutation functions | [`admin_appointment_mutations.ts`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/admin_appointment_mutations.ts), [`review_appointment.ts`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/review_appointment.ts) | 20 mins |
| **P2** | Replace `Math.random()` with `crypto.randomBytes()` in committee provisioning | [`create_committee_account.ts`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/auth/create_committee_account.ts) | 10 mins |
| **P2** | Add `android:allowBackup="false"` to application manifest | [`AndroidManifest.xml`](file:///d:/flutter%20projects/survey_booking_app/android/app/src/main/AndroidManifest.xml) | 5 mins |
| **P3** | Verify and enforce App Check in the Firebase Console | Firebase Console (Cloud) | 30 mins |
