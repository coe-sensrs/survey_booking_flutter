import {onCall, HttpsError} from "firebase-functions/v2/https";
import {db, auth, FieldValue} from "../../lib/admin";

interface SubmitClarificationReplyData {
    appointmentId: string;
    replyText: string;
}

/**
 * Server-mediated applicant clarification reply.
 *
 * Security guarantees:
 *  1. Only the original applicant (by applicantId) can submit a reply.
 *  2. Reply is only accepted if status is `clarification_requested`.
 *  3. Single-reply rule: blocks a second reply if clarificationReply is already set.
 *  4. Status resets to `under_review` atomically.
 *  5. Audit log entry appended in the same transaction.
 */
export const submitClarificationReply = onCall(
    {
        region: "us-central1",
        cors: true,
        invoker: "public",
        enforceAppCheck: false,
    },
    async (request) => {
        // ── 1. Auth guard ─────────────────────────────────────────────────────
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "You must be signed in to reply.");
        }

        const uid = request.auth.uid;
        let role = request.auth.token.role as string | undefined;

        if (!role) {
            const userDoc = await db.collection("users").doc(uid).get();
            if (userDoc.exists) {
                role = userDoc.data()?.role as string | undefined;
                if (role) {
                    try {
                        await auth.setCustomUserClaims(uid, {role});
                    } catch {/* ignore claims sync errors */}
                }
            }
        }

        if (role !== "applicant") {
            throw new HttpsError(
                "permission-denied",
                "Only applicants can submit clarification replies.",
            );
        }

        // ── 2. Payload validation ─────────────────────────────────────────────
        const data = request.data as SubmitClarificationReplyData;

        if (!data?.appointmentId || typeof data.appointmentId !== "string") {
            throw new HttpsError("invalid-argument", "appointmentId is required.");
        }
        if (!data?.replyText || data.replyText.trim().length === 0) {
            throw new HttpsError("invalid-argument", "Reply text is required.");
        }
        if (data.replyText.trim().length > 500) {
            throw new HttpsError("invalid-argument", "Reply must be under 500 characters.");
        }

        // ── 3. Firestore transaction ──────────────────────────────────────────
        const appointmentRef = db.collection("appointments").doc(data.appointmentId);

        await db.runTransaction(async (txn) => {
            const snap = await txn.get(appointmentRef);

            if (!snap.exists) {
                throw new HttpsError("not-found", "Appointment not found.");
            }

            const appt = snap.data()!;

            // ── 3a. Ownership check ──────────────────────────────────────────
            if (appt.applicantId !== uid) {
                throw new HttpsError(
                    "permission-denied",
                    "You can only reply to your own appointment clarification.",
                );
            }

            // ── 3b. Status pre-condition ─────────────────────────────────────
            if (appt.status !== "clarification_requested") {
                throw new HttpsError(
                    "failed-precondition",
                    `No clarification is pending for this appointment (status: ${appt.status}).`,
                );
            }

            // ── 3c. Single-reply rule ────────────────────────────────────────
            if (appt.clarificationReply && appt.clarificationReply.length > 0) {
                throw new HttpsError(
                    "failed-precondition",
                    "You have already submitted a reply for this clarification request.",
                );
            }

            const now = FieldValue.serverTimestamp();

            txn.update(appointmentRef, {
                clarificationReply: data.replyText.trim(),
                status: "under_review",
                updatedAt: now,
            });

            // ── 3d. Audit log ─────────────────────────────────────────────────
            const auditRef = appointmentRef.collection("auditLog").doc();
            txn.set(auditRef, {
                action: "clarification_replied",
                performedBy: uid,
                performedByRole: "applicant",
                applicantId: uid,
                timestamp: now,
                note: data.replyText.trim(),
            });
        });

        return {success: true};
    },
);
