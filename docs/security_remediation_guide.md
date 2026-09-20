# 🛠️ Security Remediation Guide: Survey Desk

This guide provides immediate, copy-paste ready patches for all vulnerabilities discovered during the security audit.

---

## 1. Patch 1 (P0): Disable Direct Client Creation on `/appointments`

- **File:** [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules#L104-L126)
- **Vulnerability:** [`SEC-02 (Quota Bypass)`](file:///d:/flutter%20projects/survey_booking_app/docs/security_audit_findings.md#sec-02-server-mediated-appointment-quota-bypass-via-direct-firestore-write)
- **Objective:** Force all survey booking creations through the server-mediated [`submitAppointment`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/submit_appointment.ts) Cloud Function.

### Changes in `firestore.rules`:
Replace lines 103–126:
```javascript
      // Applicants can create appointments (self-owned, verified email, correct initial status)
      allow create: if isApplicant() &&
                    isEmailVerified() &&
                    request.resource.data.applicantId == request.auth.uid &&
                    request.resource.data.keys().hasAll([
                      'applicantId', 'applicantName', 'applicantEmail',
                      'surveyType', 'state', 'district', 'areaName',
                      'preferredDate', 'status', 'createdAt', 'updatedAt'
                    ]) &&
                    isValidString(request.resource.data.surveyType, 1, 50) &&
                    isValidString(request.resource.data.state, 1, 100) &&
                    isValidString(request.resource.data.district, 1, 100) &&
                    isValidString(request.resource.data.areaName, 1, 150) &&
                    (!('customSurveyName' in request.resource.data) || isValidString(request.resource.data.customSurveyName, 1, 60)) &&
                    request.resource.data.status == 'pending_assignment' &&
                    request.resource.data.createdAt is timestamp &&
                    request.resource.data.preferredDate is timestamp;

      // All state transitions (assignment, review decisions, task assignment, clarification)
      // are handled by backend Cloud Functions using the Admin SDK — never by the client directly.
      // This eliminates a class of IDOR and privilege-escalation attacks.
      allow update: if false;
      allow delete: if false;
```

**With:**
```javascript
      // All appointment creations and lifecycle mutations MUST route through Cloud Functions
      // using the Admin SDK. This enforces atomic quota limits and audit logging.
      allow create: if false;
      allow update: if false;
      allow delete: if false;
```

---

## 2. Patch 2 (P0): Enforce Appointment Ownership on Storage Uploads

- **File:** [`storage.rules`](file:///d:/flutter%20projects/survey_booking_app/storage.rules#L84-L129)
- **Vulnerability:** [`SEC-01 (Cross-User Storage Upload)`](file:///d:/flutter%20projects/survey_booking_app/docs/security_audit_findings.md#sec-01-unrestricted-cross-user-storage-upload-on-appointment-files)
- **Objective:** Prevent arbitrary verified users from uploading documents into other users' appointment directories.

### Changes in `storage.rules`:
Replace lines 96–105:
```javascript
      // Create: authenticated + email-verified applicant or admin
      // File type and size validated server-side
      allow create: if isEmailVerified() && isPdfOrImage() && isUnder5MB();
```

**With:**
```javascript
      // Create: authenticated + email-verified applicant or admin
      // Enforces that the appointment belongs to the caller, or uses a caller-scoped appointment prefix
      allow create: if isEmailVerified() &&
                    (isAdmin() || appointmentId.matches('^' + request.auth.uid + '_.*') || isOwningApplicant(appointmentId)) &&
                    isPdfOrImage() &&
                    isUnder5MB();
```

And replace lines 120–122:
```javascript
      // Create: authenticated + email-verified applicant or admin
      allow create: if isEmailVerified() && isUnder15MB();
```

**With:**
```javascript
      // Create: authenticated + email-verified applicant or admin
      allow create: if isEmailVerified() &&
                    (isAdmin() || appointmentId.matches('^' + request.auth.uid + '_.*') || isOwningApplicant(appointmentId)) &&
                    request.resource.contentType.matches('application/vnd\\.google-earth\\.(kml\\+xml|kmz)') &&
                    isUnder15MB();
```

---

## 3. Patch 3 (P1): Restrict User Directory PII Read Access

- **File:** [`firestore.rules`](file:///d:/flutter%20projects/survey_booking_app/firestore.rules#L55-L59)
- **Vulnerability:** [`SEC-03 (PII Scraping)`](file:///d:/flutter%20projects/survey_booking_app/docs/security_audit_findings.md#sec-03-global-unrestricted-read-access-to-user-directory-exposes-pii)
- **Objective:** Restrict full profile reads to the account owner or administrators.

### Changes in `firestore.rules`:
Replace lines 55–59:
```javascript
    match /users/{uid} {
      // Any authenticated user can read profile data
      // (needed for display names, reviewer assignments, avatars across roles)
      allow read: if isAuthenticated();
```

**With:**
```javascript
    match /users/{uid} {
      // Only the account owner or an administrator can read full profile PII (phone, email)
      allow read: if isOwner(uid) || isAdmin();
```

---

## 4. Patch 4 (P1): Enforce Account Deactivation Checks in Mutation Functions

- **File:** [`functions/src/functions/appointments/admin_appointment_mutations.ts`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/appointments/admin_appointment_mutations.ts#L7-L16)
- **Vulnerability:** [`SEC-05 (Deactivated Account Execution)`](file:///d:/flutter%20projects/survey_booking_app/docs/security_audit_findings.md#sec-05-deactivated-staff-account-operations-permitted-in-appointment-mutations)
- **Objective:** Immediately reject mutations from revoked staff before their 1-hour JWT token expires.

### Changes in `admin_appointment_mutations.ts`:
Update `requireAdmin`:
```typescript
async function requireAdmin(request: {auth?: {uid: string; token: Record<string, unknown>} | null}) {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be signed in to perform this action.");
    }
    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data()?.active === false || callerDoc.data()?.isActive === false) {
        throw new HttpsError("permission-denied", "This account has been deactivated.");
    }
    const role = request.auth.token.role as string | undefined;
    if (role !== "admin") {
        throw new HttpsError("permission-denied", "Only administrators can perform this action.");
    }
}
```

---

## 5. Patch 5 (P2): Use CSPRNG for Committee Temporary Passwords

- **File:** [`functions/src/functions/auth/create_committee_account.ts`](file:///d:/flutter%20projects/survey_booking_app/functions/src/functions/auth/create_committee_account.ts#L93-L96)
- **Vulnerability:** [`SEC-04 (Predictable Randomness)`](file:///d:/flutter%20projects/survey_booking_app/docs/security_audit_findings.md#sec-04-predictable-temporary-password-generation-using-mathrandom)
- **Objective:** Eliminate pseudo-random password generation using Node.js `crypto.randomBytes()`.

### Changes in `create_committee_account.ts`:
Add `import * as crypto from "crypto";` at the top of the file, then replace line 94:
```typescript
        // 4. Generate Temporary Password
        const tempPassword = `Temp@${Math.random().toString(36).slice(-8)}!1`;
```

**With:**
```typescript
        // 4. Generate Temporary Password using cryptographically secure random bytes
        const randSlice = crypto.randomBytes(9).toString("base64").replace(/[^a-zA-Z0-9]/g, "").slice(0, 8);
        const tempPassword = `Temp@${randSlice}!1`;
```

---

## 6. Patch 6 (P2): Disable Android Application Backups

- **File:** [`android/app/src/main/AndroidManifest.xml`](file:///d:/flutter%20projects/survey_booking_app/android/app/src/main/AndroidManifest.xml#L2-L6)
- **Vulnerability:** [`SEC-06 (ADB Backup Extraction)`](file:///d:/flutter%20projects/survey_booking_app/docs/security_audit_findings.md#sec-06-missing-android-application-backup-restriction-exposes-local-hive-cache)
- **Objective:** Prevent unauthorized extraction of private Hive boxes and offline drafts via ADB.

### Changes in `AndroidManifest.xml`:
Update `<application>` tag:
```xml
    <application
        android:label="Survey Desk"
        android:name="${applicationName}"
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher">
```
