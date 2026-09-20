import {onCall, HttpsError} from "firebase-functions/v2/https";
import {db, FieldValue} from "../../lib/admin";
import {sendAppointmentNotification} from "../notifications/send_push_notification";
import {NotificationType, NotificationTypeValue} from "../notifications/notification_types";

interface ReviewAppointmentData {
    appointmentId: string;
    action: "approve" | "reject" | "clarify";
    reasonOrNote?: string;
}

/**
 * Server-mediated committee review action.
 *
 * Security guarantees vs. direct client Firestore writes:
 *  1. Role enforced: only committee (or admin) callers pass the gate.
 *  2. Assigned-reviewer guard: rejects calls from committee members who
 *     are not the designated reviewer for this appointment.
 *  3. Status pre-condition: the appointment must currently be `under_review`.
 *  4. Single-clarification PRD rule: a second clarification is rejected
 *     server-side when clarificationNote is already present without a reply.
 *  5. Quota restoration: approvals and rejections atomically decrement
 *     rateLimits/{applicantId}.pendingCount (clamped ≥ 0).
 *  6. Audit trail: every action appends an immutable auditLog entry
 *     inside the same Firestore transaction.
 */
export const reviewAppointment = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
    },
    async (request) => {
        // ── 1. Auth guard ─────────────────────────────────────────────────────
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "You must be signed in to review appointments.");
        }

        const uid = request.auth.uid;
        const role = request.auth.token.role as string | undefined;

        if (role !== "committee" && role !== "admin") {
            throw new HttpsError(
                "permission-denied",
                "Only committee members can review appointments.",
            );
        }

        // ── 2. Payload validation ─────────────────────────────────────────────
        const data = request.data as ReviewAppointmentData;

        if (!data?.appointmentId || typeof data.appointmentId !== "string") {
            throw new HttpsError("invalid-argument", "appointmentId is required.");
        }
        if (!["approve", "reject", "clarify"].includes(data.action)) {
            throw new HttpsError(
                "invalid-argument",
                "action must be one of: approve, reject, clarify.",
            );
        }
        if ((data.action === "reject" || data.action === "clarify")) {
            if (!data.reasonOrNote || data.reasonOrNote.trim().length === 0) {
                throw new HttpsError(
                    "invalid-argument",
                    data.action === "reject" ?
                        "Rejection reason is required." :
                        "Clarification note is required.",
                );
            }
            if (data.reasonOrNote.trim().length > 500) {
                throw new HttpsError(
                    "invalid-argument",
                    data.action === "reject" ?
                        "Rejection reason must be under 500 characters." :
                        "Clarification note must be under 500 characters.",
                );
            }
        }

        // Snapshot of fields needed for post-transaction notification.
        let applicantId: string | undefined;
        let notificationType: NotificationTypeValue;

        // ── 3. Run inside a Firestore transaction ────────────────────────────
        const appointmentRef = db.collection("appointments").doc(data.appointmentId);

        await db.runTransaction(async (txn) => {
            const appointmentSnap = await txn.get(appointmentRef);

            // ── 3a. Document existence check ─────────────────────────────────
            if (!appointmentSnap.exists) {
                throw new HttpsError(
                    "not-found",
                    "Appointment not found.",
                );
            }

            const appt = appointmentSnap.data()!;
            applicantId = appt.applicantId as string | undefined;

            // ── 3b. Status pre-condition: must be under_review ───────────────
            if (appt.status !== "under_review") {
                throw new HttpsError(
                    "failed-precondition",
                    `This appointment is not awaiting review (current status: ${appt.status}).`,
                );
            }

            // ── 3c. Assigned-reviewer guard ──────────────────────────────────
            if (role === "committee" && appt.assignedReviewerId !== uid) {
                throw new HttpsError(
                    "permission-denied",
                    "You are not the assigned reviewer for this appointment.",
                );
            }

            // ── 3d. Single-clarification PRD rule ────────────────────────────
            if (data.action === "clarify") {
                const hasPendingClarification =
                    appt.clarificationNote &&
                    appt.clarificationNote.length > 0 &&
                    (!appt.clarificationReply || appt.clarificationReply.length === 0);
                if (hasPendingClarification) {
                    throw new HttpsError(
                        "failed-precondition",
                        "Clarification has already been requested. " +
                        "Waiting for the applicant's reply before you can act again.",
                    );
                }
            }

            // ── 3e. Read quota doc (MUST occur before ANY writes) ───────────
            let rateLimitRef: FirebaseFirestore.DocumentReference | null = null;
            let currentCount = 0;
            if (data.action === "approve" || data.action === "reject") {
                const applicantId = appt.applicantId as string;
                if (applicantId) {
                    rateLimitRef = db.collection("rateLimits").doc(applicantId);
                    const rateLimitSnap = await txn.get(rateLimitRef);
                    currentCount = rateLimitSnap.exists ?
                        ((rateLimitSnap.data()?.pendingCount as number) ?? 0) : 0;
                }
            }

            // ── 3f. Build the status update ──────────────────────────────────
            const now = FieldValue.serverTimestamp();
            const updates: Record<string, unknown> = {
                updatedAt: now,
            };
            let newStatus: string;
            let auditAction: string;

            if (data.action === "approve") {
                newStatus = "approved";
                auditAction = "approved";
            } else if (data.action === "reject") {
                newStatus = "rejected";
                auditAction = "rejected";
                updates["rejectionReason"] = data.reasonOrNote!.trim();
            } else {
                // clarify
                newStatus = "clarification_requested";
                auditAction = "clarification_requested";
                updates["clarificationNote"] = data.reasonOrNote!.trim();
                // Clear any stale reply when a fresh clarification is sent
                updates["clarificationReply"] = null;
            }
            updates["status"] = newStatus;

            // ── 3g. Execute all writes ───────────────────────────────────────
            txn.update(appointmentRef, updates);

            if (rateLimitRef) {
                const newCount = Math.max(0, currentCount - 1);
                txn.set(rateLimitRef, {pendingCount: newCount}, {merge: true});
            }

            // Immutable audit log entry
            const auditRef = appointmentRef.collection("auditLog").doc();
            txn.set(auditRef, {
                action: auditAction,
                performedBy: uid,
                performedByRole: role,
                applicantId: appt.applicantId,
                timestamp: now,
                note: data.reasonOrNote?.trim() ? data.reasonOrNote.trim() : null,
            });
        });

        // ── 4. Determine notification type from the action ───────────────────────
        if (data.action === "approve") {
            notificationType = NotificationType.APPROVED;
        } else if (data.action === "reject") {
            notificationType = NotificationType.REJECTED;
        } else {
            notificationType = NotificationType.CLARIFICATION_REQUESTED;
        }

        // Notify applicant (fire-and-forget — must not throw or roll back).
        await sendAppointmentNotification(
            notificationType!,
            {applicantId},
            data.appointmentId,
        );

        return {success: true};
    },
);
