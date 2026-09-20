import {NotificationTypeValue} from "./notification_types";

export interface NotificationPayload {
    notification: {
        title: string;
        body: string;
    };
    data: {
        type: string;
        appointmentId: string;
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Title / body strings for each notification type.
// IMPORTANT: Do NOT include sensitive PII (email, phone, reasons, etc.).
// ─────────────────────────────────────────────────────────────────────────────
const PAYLOAD_MAP: Record<NotificationTypeValue, {title: string; body: string}> = {
    booking_created: {
        title: "New Survey Booking",
        body: "A new survey booking request has been submitted and requires assignment.",
    },
    reviewer_assigned: {
        title: "Review Assignment",
        body: "An appointment has been assigned to you for review.",
    },
    rejected: {
        title: "Appointment Update",
        body: "Your appointment has been reviewed. Please check the details.",
    },
    clarification_requested: {
        title: "Clarification Requested",
        body: "The reviewer has requested clarification on your appointment.",
    },
    clarification_reply: {
        title: "Clarification Reply Received",
        body: "The applicant has replied to your clarification request.",
    },
    approved: {
        title: "Appointment Approved",
        body: "Your survey appointment has been approved.",
    },
    task_assigned: {
        title: "Survey Task Assigned",
        body: "A fieldwork task has been assigned. Please check the details.",
    },
};

/**
 * Builds a complete FCM notification payload.
 * The data payload carries ONLY the notification type and appointmentId —
 * no PII, no free text from user inputs.
 */
export function buildNotificationPayload(
    type: NotificationTypeValue,
    appointmentId: string,
): NotificationPayload {
    const {title, body} = PAYLOAD_MAP[type];
    return {
        notification: {title, body},
        data: {type, appointmentId},
    };
}
