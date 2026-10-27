import {onCall, HttpsError} from "firebase-functions/v2/https";
import {db, FieldValue, Timestamp} from "../../lib/admin";
import {sendAppointmentNotification} from "../notifications/send_push_notification";
import {NotificationType} from "../notifications/notification_types";

interface SubmitCampusVisitData {
    applicantName:   string;   // 2–100 chars
    applicantMobile: string;   // E.164, e.g. +91XXXXXXXXXX
    applicantEmail:  string;   // valid email
    visitDate:       string;   // ISO-8601 date string, future + 3 full days
    session:         "morning" | "afternoon";
    delegationSize:  number;   // integer 1–50
    purpose:         string;   // 20–1000 chars
    idempotencyKey:  string;   // SHA-256(uid+visitDate+session) from client
}

const VALID_SESSIONS = new Set(["morning", "afternoon"]);
const MIN_NOTICE_DAYS = 3;
const MAX_DELEGATION = 50;

/**
 * submitCampusVisit — Applicant-callable Cloud Function.
 *
 * Security guarantees:
 *  1. Requires authenticated caller — applicantId is never trusted from client.
 *  2. All fields validated server-side independently of Flutter validation.
 *  3. Minimum notice (3 full calendar days) enforced using the server clock.
 *  4. Session must be exactly "morning" or "afternoon".
 *  5. Delegation size bounded to [1, MAX_DELEGATION].
 *  6. Idempotency: if a document with the same idempotencyKey already exists
 *     for this applicant, it returns the existing visitId without creating a
 *     duplicate — safe to retry on network failure.
 *  7. status = "pending" and timestamps are set server-side only.
 */
export const submitCampusVisit = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
    },
    async (request) => {
        // ── 1. Auth guard ─────────────────────────────────────────────────────
        if (!request.auth) {
            throw new HttpsError(
                "unauthenticated",
                "You must be signed in to submit a campus visit request.",
            );
        }

        const uid = request.auth.uid;

        // ── 2. Field validation ───────────────────────────────────────────────
        const data = request.data as SubmitCampusVisitData;

        if (!data?.applicantName || typeof data.applicantName !== "string" ||
            data.applicantName.trim().length < 2 ||
            data.applicantName.trim().length > 100) {
            throw new HttpsError("invalid-argument", "Full name must be 2–100 characters.");
        }

        const mobileRe = /^\+\d{7,15}$/;
        if (!data?.applicantMobile || !mobileRe.test(data.applicantMobile.trim())) {
            throw new HttpsError("invalid-argument", "A valid international mobile number is required.");
        }

        const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!data?.applicantEmail || !emailRe.test(data.applicantEmail.trim())) {
            throw new HttpsError("invalid-argument", "A valid email address is required.");
        }

        if (!data?.visitDate || typeof data.visitDate !== "string") {
            throw new HttpsError("invalid-argument", "visitDate is required as an ISO-8601 string.");
        }

        const visitDateObj = new Date(data.visitDate);
        if (isNaN(visitDateObj.getTime())) {
            throw new HttpsError("invalid-argument", "visitDate is not a valid date.");
        }

        // Minimum notice: visitDate must be at least MIN_NOTICE_DAYS full calendar
        // days in the future. Compares date-only (ignores time of day).
        const serverToday = new Date();
        serverToday.setHours(0, 0, 0, 0);
        const minAllowedDate = new Date(serverToday);
        minAllowedDate.setDate(minAllowedDate.getDate() + MIN_NOTICE_DAYS + 1);
        const visitMidnight = new Date(visitDateObj);
        visitMidnight.setHours(0, 0, 0, 0);

        if (visitMidnight < minAllowedDate) {
            throw new HttpsError(
                "invalid-argument",
                `Visit must be scheduled at least ${MIN_NOTICE_DAYS} full days in advance.`,
            );
        }

        // Weekday check (Mon–Sat; 0=Sun, 6=Sat allowed, adjust if campus is Mon–Fri only)
        const dayOfWeek = visitMidnight.getDay();
        if (dayOfWeek === 0) {
            throw new HttpsError("invalid-argument", "Campus visits are not available on Sundays.");
        }

        if (!data?.session || !VALID_SESSIONS.has(data.session)) {
            throw new HttpsError("invalid-argument", "session must be 'morning' or 'afternoon'.");
        }

        const delegationSize = Number(data?.delegationSize);
        if (!Number.isInteger(delegationSize) || delegationSize < 1 || delegationSize > MAX_DELEGATION) {
            throw new HttpsError(
                "invalid-argument",
                `delegationSize must be an integer between 1 and ${MAX_DELEGATION}.`,
            );
        }

        if (!data?.purpose || typeof data.purpose !== "string" ||
            data.purpose.trim().length < 20 ||
            data.purpose.trim().length > 1000) {
            throw new HttpsError(
                "invalid-argument",
                "Purpose must be 20–1000 characters.",
            );
        }

        if (!data?.idempotencyKey || typeof data.idempotencyKey !== "string" ||
            data.idempotencyKey.trim().length < 10) {
            throw new HttpsError("invalid-argument", "idempotencyKey is required.");
        }

        // ── 3. Idempotency check ──────────────────────────────────────────────
        // If a prior request with the same key already succeeded, return the
        // existing visitId without creating a duplicate booking.
        const existingSnap = await db
            .collection("campus_visits")
            .where("idempotencyKey", "==", data.idempotencyKey.trim())
            .where("applicantId", "==", uid)
            .limit(1)
            .get();

        if (!existingSnap.empty) {
            const existingDoc = existingSnap.docs[0];
            return {visitId: existingDoc.id, status: existingDoc.data().status};
        }

        // ── 4. Write new visit document ───────────────────────────────────────
        const now = FieldValue.serverTimestamp();
        const visitRef = db.collection("campus_visits").doc();

        await visitRef.set({
            applicantId: uid,
            applicantName: data.applicantName.trim(),
            applicantMobile: data.applicantMobile.trim(),
            applicantEmail: data.applicantEmail.trim().toLowerCase(),
            visitDate: Timestamp.fromDate(visitMidnight),
            session: data.session,
            delegationSize,
            purpose: data.purpose.trim(),
            idempotencyKey: data.idempotencyKey.trim(),
            // Server-enforced; clients cannot set these on creation
            status: "pending",
            reviewedBy: null,
            reviewerName: null,
            reviewNote: null,
            createdAt: now,
            updatedAt: now,
        });

        // Initial audit log entry
        await visitRef.collection("auditLog").add({
            action: "submitted",
            performedByUid: uid,
            performedByRole: "applicant",
            applicantId: uid,
            timestamp: now,
            note: "Campus visit request submitted by applicant.",
        });

        // ── 5. Notify admins (fire-and-forget) ────────────────────────────────
        try {
            await sendAppointmentNotification(
                NotificationType.VISIT_SUBMITTED,
                {applicantName: data.applicantName.trim()},
                visitRef.id,
            );
        } catch {
            // Notification failure must not abort a successful booking
        }

        return {visitId: visitRef.id, status: "pending"};
    },
);
