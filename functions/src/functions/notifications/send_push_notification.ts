import * as admin from "firebase-admin";
import {db} from "../../lib/admin";
import {NotificationTypeValue} from "./notification_types";
import {buildNotificationPayload} from "./notification_payload";
import {
    getFcmTokensForUser,
    getAdminFcmTokens,
    getRecipientUids,
} from "./notification_recipients";

const INVALID_TOKEN_ERRORS = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
]);

// ─────────────────────────────────────────────────────────────────────────────
// Removes a single stale FCM token from a user's fcmTokens array.
// Called after FCM reports a token is invalid.
// ─────────────────────────────────────────────────────────────────────────────
async function pruneInvalidToken(uid: string, token: string): Promise<void> {
    try {
        await db.collection("users").doc(uid).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
        });
    } catch (err) {
        // Non-fatal: log and continue. A missing user doc is safe to ignore.
        console.error(`[FCM] Failed to prune token for uid=${uid}:`, err);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sends FCM notifications to a single user.
// Returns silently on errors — notification failure must not break workflows.
// ─────────────────────────────────────────────────────────────────────────────
async function sendToUser(
    uid: string,
    type: NotificationTypeValue,
    appointmentId: string,
): Promise<void> {
    const tokens = await getFcmTokensForUser(uid);
    if (tokens.length === 0) return;

    const {notification, data} = buildNotificationPayload(type, appointmentId);

    const message: admin.messaging.MulticastMessage = {
        tokens,
        notification,
        data,
        android: {
            priority: "high",
            notification: {channelId: "survey_desk_notifications"},
        },
    };

    let response: admin.messaging.BatchResponse;
    try {
        response = await admin.messaging().sendEachForMulticast(message);
    } catch (err) {
        // Network/FCM service error — log without PII and return.
        console.error(
            `[FCM] sendEachForMulticast failed. type=${type} uid=${uid} appointmentId=${appointmentId}`,
            err,
        );
        return;
    }

    // Prune invalid tokens reported by FCM.
    const prunePromises: Promise<void>[] = [];
    response.responses.forEach((res, idx) => {
        if (!res.success && res.error &&
            INVALID_TOKEN_ERRORS.has(res.error.code)) {
            console.warn(
                `[FCM] Invalid token detected, pruning. uid=${uid} errorCode=${res.error.code}`,
            );
            prunePromises.push(pruneInvalidToken(uid, tokens[idx]));
        }
    });
    await Promise.all(prunePromises);
}

// ─────────────────────────────────────────────────────────────────────────────
// Sends FCM notifications to all admin users (role-query based).
// ─────────────────────────────────────────────────────────────────────────────
async function sendToAdmins(
    type: NotificationTypeValue,
    appointmentId: string,
): Promise<void> {
    const tokens = await getAdminFcmTokens();
    if (tokens.length === 0) return;

    const {notification, data} = buildNotificationPayload(type, appointmentId);

    const message: admin.messaging.MulticastMessage = {
        tokens,
        notification,
        data,
        android: {
            priority: "high",
            notification: {channelId: "survey_desk_notifications"},
        },
    };

    try {
        await admin.messaging().sendEachForMulticast(message);
    } catch (err) {
        console.error(
            `[FCM] Admin multicast failed. type=${type} appointmentId=${appointmentId}`,
            err,
        );
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API used by all appointment Cloud Functions.
//
// Resolves recipients from the appointment document server-side, then
// dispatches FCM messages. Errors are caught and logged — notification
// failure MUST NOT throw or roll back any workflow state.
//
// type         — one of the NotificationType constants
// appointment  — the appointment data snapshot (already read in the function)
// appointmentId — the Firestore document ID
// ─────────────────────────────────────────────────────────────────────────────
export async function sendAppointmentNotification(
    type: NotificationTypeValue,
    appointment: Record<string, unknown>,
    appointmentId: string,
): Promise<void> {
    try {
        if (type === "booking_created") {
            await sendToAdmins(type, appointmentId);
            return;
        }

        const recipientUids = getRecipientUids(type, appointment);
        await Promise.all(
            recipientUids.map((uid) => sendToUser(uid, type, appointmentId)),
        );
    } catch (err) {
        // Top-level safety net: notification errors must never propagate to callers.
        console.error(
            `[FCM] sendAppointmentNotification error. type=${type} appointmentId=${appointmentId}`,
            err,
        );
    }
}
