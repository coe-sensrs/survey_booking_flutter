import {db} from "../../lib/admin";
import {NotificationTypeValue} from "./notification_types";

interface AppointmentData {
    applicantId?: string;
    assignedReviewerId?: string;
    assignedTaskMemberId?: string;
    [key: string]: unknown;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fetches the FCM tokens for a single user from users/{uid}.fcmTokens.
// Returns an empty array when the user has no tokens or the document is missing.
// ─────────────────────────────────────────────────────────────────────────────
export async function getFcmTokensForUser(uid: string): Promise<string[]> {
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return [];
    const tokens = userDoc.data()?.fcmTokens as string[] | undefined;
    return Array.isArray(tokens) ? tokens.filter(Boolean) : [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Fetches FCM tokens for all users whose Firestore role document has role == 'admin'.
// Returns a flat list of tokens across all admin accounts.
// ─────────────────────────────────────────────────────────────────────────────
export async function getAdminFcmTokens(): Promise<string[]> {
    const snapshot = await db.collection("users")
        .where("role", "==", "admin")
        .get();

    const tokenArrays = await Promise.all(
        snapshot.docs.map((doc) => {
            const tokens = doc.data().fcmTokens as string[] | undefined;
            return Array.isArray(tokens) ? tokens.filter(Boolean) : [];
        }),
    );
    return tokenArrays.flat();
}

// ─────────────────────────────────────────────────────────────────────────────
// Resolves the recipient UIDs for a given notification type and appointment.
// Cloud Functions call this — Flutter never selects recipients.
// ─────────────────────────────────────────────────────────────────────────────
export function getRecipientUids(
    type: NotificationTypeValue,
    appointment: AppointmentData,
): string[] {
    switch (type) {
    case "booking_created":
        // Admin(s) fetched via role query — caller uses getAdminFcmTokens() directly.
        return [];

    case "reviewer_assigned":
        return appointment.assignedReviewerId ? [appointment.assignedReviewerId] : [];

    case "rejected":
    case "clarification_requested":
    case "approved":
        return appointment.applicantId ? [appointment.applicantId] : [];

    case "clarification_reply":
        return appointment.assignedReviewerId ? [appointment.assignedReviewerId] : [];

    case "task_assigned":
        return [
            ...(appointment.applicantId ? [appointment.applicantId] : []),
            ...(appointment.assignedTaskMemberId ? [appointment.assignedTaskMemberId] : []),
        ];

    default:
        return [];
    }
}
