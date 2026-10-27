import {onCall, HttpsError} from "firebase-functions/v2/https";
import {auth, db, FieldValue} from "../../lib/admin";
import {sendAppointmentNotification} from "../notifications/send_push_notification";
import {NotificationType} from "../notifications/notification_types";

// ─────────────────────────────────────────────────────────────────────────────
// Shared admin guard — identical pattern to admin_appointment_mutations.ts
// ─────────────────────────────────────────────────────────────────────────────
async function requireAdmin(
    request: { auth?: { uid: string; token: Record<string, unknown> } | null },
): Promise<void> {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be signed in to perform this action.");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await db.collection("users").doc(callerUid).get();

    if (callerDoc.exists &&
        (callerDoc.data()?.active === false || callerDoc.data()?.isActive === false)) {
        throw new HttpsError(
            "permission-denied",
            "Your account has been deactivated. Contact your administrator.",
        );
    }

    const tokenRole = request.auth.token.role as string | undefined;
    if (tokenRole === "admin") return;

    if (callerDoc.exists) {
        const docRole = callerDoc.data()?.role as string | undefined;
        if (docRole === "admin") {
            await auth.setCustomUserClaims(callerUid, {role: "admin"});
            return;
        }
    }

    throw new HttpsError("permission-denied", "Only administrators can perform this action.");
}

interface ReviewCampusVisitData {
    visitId:    string;
    action:     "approve" | "reject";
    reviewNote?: string; // required on reject, optional on approve
}

/**
 * reviewCampusVisit — Admin-only callable Cloud Function.
 *
 * Security guarantees:
 *  1. requireAdmin guard: unauthenticated/non-admin callers are rejected.
 *  2. Visit must exist and be in "pending" status.
 *  3. Concurrent decisions are safe: uses Firestore transaction with
 *     read-before-write ordering to prevent overwrite races.
 *  4. reviewedBy and reviewerName are derived from the Admin SDK context,
 *     not the client payload.
 *  5. Only "approve" or "reject" are allowed; arbitrary status values are rejected.
 *  6. Audit log entry is written in the same transaction.
 */
export const reviewCampusVisit = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
    },
    async (request) => {
        // ── 1. Admin guard ─────────────────────────────────────────────────────
        await requireAdmin(request);

        const uid = request.auth!.uid;
        const data = request.data as ReviewCampusVisitData;

        // ── 2. Input validation ────────────────────────────────────────────────
        if (!data?.visitId || typeof data.visitId !== "string") {
            throw new HttpsError("invalid-argument", "visitId is required.");
        }

        const VALID_ACTIONS = new Set(["approve", "reject"]);
        if (!data?.action || !VALID_ACTIONS.has(data.action)) {
            throw new HttpsError("invalid-argument", "action must be 'approve' or 'reject'.");
        }

        if (data.action === "reject") {
            if (!data?.reviewNote || data.reviewNote.trim().length < 5) {
                throw new HttpsError(
                    "invalid-argument",
                    "A review note of at least 5 characters is required when rejecting a visit.",
                );
            }
        }

        // ── 3. Load admin profile for reviewer metadata ────────────────────────
        const adminDoc = await db.collection("users").doc(uid).get();
        const reviewerName = adminDoc.exists ?
            (adminDoc.data()?.fullName as string ?? "Administrator") :
            "Administrator";

        const visitRef = db.collection("campus_visits").doc(data.visitId);
        const now = FieldValue.serverTimestamp();
        const newStatus = data.action === "approve" ? "approved" : "rejected";

        // ── 4. Atomic Firestore transaction (Phase 1 reads → Phase 2 writes) ───
        await db.runTransaction(async (txn) => {
            // Phase 1: All reads
            const visitSnap = await txn.get(visitRef);

            if (!visitSnap.exists) {
                throw new HttpsError("not-found", "Campus visit request not found.");
            }

            const visitData = visitSnap.data()!;
            if (visitData.status !== "pending") {
                throw new HttpsError(
                    "failed-precondition",
                    `Cannot review visit: current status is '${visitData.status}', expected 'pending'.`,
                );
            }

            // Phase 2: All writes
            txn.update(visitRef, {
                status: newStatus,
                reviewedBy: uid,
                reviewerName,
                reviewNote: data.reviewNote?.trim() ?? null,
                updatedAt: now,
            });

            const auditRef = visitRef.collection("auditLog").doc();
            txn.set(auditRef, {
                action: data.action === "approve" ? "approved" : "rejected",
                performedByUid: uid,
                performedByRole: "admin",
                reviewerName,
                applicantId: visitData.applicantId,
                reviewNote: data.reviewNote?.trim() ?? null,
                timestamp: now,
            });
        });

        // ── 5. Notify applicant (fire-and-forget) ──────────────────────────────
        try {
            const notifType = data.action === "approve"
                ? NotificationType.VISIT_APPROVED
                : NotificationType.VISIT_REJECTED;

            const visitSnap = await visitRef.get();
            const applicantId = visitSnap.data()?.applicantId as string | undefined;

            if (applicantId) {
                await sendAppointmentNotification(notifType, {applicantId}, data.visitId);
            }
        } catch {
            // Notification failure must not propagate to caller
        }

        return {success: true, newStatus};
    },
);
