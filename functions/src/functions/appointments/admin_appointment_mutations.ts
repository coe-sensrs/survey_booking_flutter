import {onCall, HttpsError} from "firebase-functions/v2/https";
import {auth, db, FieldValue, Timestamp} from "../../lib/admin";
import {sendAppointmentNotification} from "../notifications/send_push_notification";
import {NotificationType} from "../notifications/notification_types";

// ─────────────────────────────────────────────────────────────────────────────
// Shared admin guard — mirrors createCommitteeAccount's fault-tolerant approach.
// 1. Rejects unauthenticated callers immediately.
// 2. Checks for account deactivation in Firestore.
// 3. Accepts token role == "admin". Falls back to Firestore document role check
//    when the custom claim hasn't propagated yet, then backfills the claim.
// ─────────────────────────────────────────────────────────────────────────────
async function requireAdmin(
    request: {auth?: {uid: string; token: Record<string, unknown>} | null},
): Promise<void> {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be signed in to perform this action.");
    }

    const callerUid = request.auth.uid;

    // Deactivation check via Firestore
    const callerDoc = await db.collection("users").doc(callerUid).get();
    if (callerDoc.exists && (callerDoc.data()?.active === false || callerDoc.data()?.isActive === false)) {
        throw new HttpsError("permission-denied", "Your account has been deactivated. Contact your administrator.");
    }

    // Primary: check token custom claim
    const tokenRole = request.auth.token.role as string | undefined;
    if (tokenRole === "admin") return;

    // Fallback: check Firestore document role (handles stale/missing custom claims)
    if (callerDoc.exists) {
        const docRole = callerDoc.data()?.role as string | undefined;
        if (docRole === "admin") {
            // Backfill the custom claim so the next request won't need this fallback
            await auth.setCustomUserClaims(callerUid, {role: "admin"});
            return;
        }
    }

    throw new HttpsError("permission-denied", "Only administrators can perform this action.");
}

// ─────────────────────────────────────────────────────────────────────────────
// assignReviewer — routes an appointment to a committee member for review
// ─────────────────────────────────────────────────────────────────────────────

export const assignReviewer = onCall(
    {region: "us-central1", cors: true, invoker: "public", enforceAppCheck: false},
    async (request) => {
        await requireAdmin(request);

        const {appointmentId, reviewerId, reviewerName} = request.data as {
            appointmentId: string;
            reviewerId: string;
            reviewerName: string;
        };

        if (!appointmentId || !reviewerId || !reviewerName) {
            throw new HttpsError("invalid-argument", "appointmentId, reviewerId, and reviewerName are required.");
        }

        const appointmentRef = db.collection("appointments").doc(appointmentId);
        const uid = request.auth!.uid;
        const now = FieldValue.serverTimestamp();

        await db.runTransaction(async (txn) => {
            const snap = await txn.get(appointmentRef);
            if (!snap.exists) {
                throw new HttpsError("not-found", "Appointment not found.");
            }
            const appt = snap.data()!;
            if (appt.status !== "pending_assignment") {
                throw new HttpsError(
                    "failed-precondition",
                    `Cannot assign reviewer: appointment is not pending assignment (status: ${appt.status}).`,
                );
            }

            txn.update(appointmentRef, {
                assignedReviewerId: reviewerId,
                assignedReviewerName: reviewerName,
                status: "under_review",
                updatedAt: now,
            });

            const auditRef = appointmentRef.collection("auditLog").doc();
            txn.set(auditRef, {
                action: "assigned_reviewer",
                performedBy: uid,
                performedByRole: "admin",
                applicantId: appt.applicantId,
                timestamp: now,
                note: `Assigned reviewer: ${reviewerName}`,
            });
        });

        // ── Notify the assigned reviewer (fire-and-forget) ──────────────────────
        await sendAppointmentNotification(
            NotificationType.REVIEWER_ASSIGNED,
            {assignedReviewerId: reviewerId},
            appointmentId,
        );

        return {success: true};
    },
);

// ─────────────────────────────────────────────────────────────────────────────
// setConfirmedDate — admin sets / updates the confirmed survey date
// ─────────────────────────────────────────────────────────────────────────────

export const setConfirmedDate = onCall(
    {region: "us-central1", cors: true, invoker: "public", enforceAppCheck: false},
    async (request) => {
        await requireAdmin(request);

        const {appointmentId, confirmedDate} = request.data as {
            appointmentId: string;
            confirmedDate: string; // ISO-8601 string from client
        };

        if (!appointmentId || !confirmedDate) {
            throw new HttpsError("invalid-argument", "appointmentId and confirmedDate are required.");
        }

        const parsedDate = new Date(confirmedDate);
        if (isNaN(parsedDate.getTime())) {
            throw new HttpsError("invalid-argument", "confirmedDate must be a valid ISO-8601 date string.");
        }

        const appointmentRef = db.collection("appointments").doc(appointmentId);
        const uid = request.auth!.uid;
        const now = FieldValue.serverTimestamp();

        await db.runTransaction(async (txn) => {
            const snap = await txn.get(appointmentRef);
            if (!snap.exists) {
                throw new HttpsError("not-found", "Appointment not found.");
            }

            txn.update(appointmentRef, {
                confirmedDate: Timestamp.fromDate(parsedDate),
                updatedAt: now,
            });

            const auditRef = appointmentRef.collection("auditLog").doc();
            txn.set(auditRef, {
                action: "date_confirmed",
                performedBy: uid,
                performedByRole: "admin",
                applicantId: snap.data()!.applicantId,
                timestamp: now,
                note: `Confirmed date set to: ${parsedDate.toISOString()}`,
            });
        });

        return {success: true};
    },
);

// ─────────────────────────────────────────────────────────────────────────────
// assignFieldworkTask — admin assigns the post-approval fieldwork task
// ─────────────────────────────────────────────────────────────────────────────

export const assignFieldworkTask = onCall(
    {region: "us-central1", cors: true, invoker: "public", enforceAppCheck: false},
    async (request) => {
        await requireAdmin(request);

        const {appointmentId, memberId, memberName} = request.data as {
            appointmentId: string;
            memberId: string;
            memberName: string;
        };

        if (!appointmentId || !memberId || !memberName) {
            throw new HttpsError("invalid-argument", "appointmentId, memberId, and memberName are required.");
        }

        const appointmentRef = db.collection("appointments").doc(appointmentId);
        const uid = request.auth!.uid;
        const now = FieldValue.serverTimestamp();

        let taskApplicantId: string | undefined;

        await db.runTransaction(async (txn) => {
            const snap = await txn.get(appointmentRef);
            if (!snap.exists) {
                throw new HttpsError("not-found", "Appointment not found.");
            }
            const appt = snap.data()!;
            taskApplicantId = appt.applicantId as string | undefined;
            if (appt.status !== "approved") {
                throw new HttpsError(
                    "failed-precondition",
                    `Fieldwork task can only be assigned to approved appointments (status: ${appt.status}).`,
                );
            }

            txn.update(appointmentRef, {
                assignedTaskMemberId: memberId,
                assignedTaskMemberName: memberName,
                status: "task_assigned",
                updatedAt: now,
            });

            const auditRef = appointmentRef.collection("auditLog").doc();
            txn.set(auditRef, {
                action: "task_assigned",
                performedBy: uid,
                performedByRole: "admin",
                applicantId: appt.applicantId,
                timestamp: now,
                note: `Fieldwork task assigned to: ${memberName}`,
            });
        });

        // ── Notify applicant and the assigned task member (fire-and-forget) ──────
        await sendAppointmentNotification(
            NotificationType.TASK_ASSIGNED,
            {applicantId: taskApplicantId, assignedTaskMemberId: memberId},
            appointmentId,
        );

        return {success: true};
    },
);
