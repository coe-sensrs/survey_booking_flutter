/**
 * Canonical FCM notification type identifiers.
 * Values must match the strings used in Flutter's NotificationType enum.
 */
export const NotificationType = Object.freeze({
    BOOKING_CREATED: "booking_created",
    REVIEWER_ASSIGNED: "reviewer_assigned",
    REJECTED: "rejected",
    CLARIFICATION_REQUESTED: "clarification_requested",
    CLARIFICATION_REPLY: "clarification_reply",
    APPROVED: "approved",
    TASK_ASSIGNED: "task_assigned",
    // Campus visit lifecycle
    VISIT_SUBMITTED: "visit_submitted",
    VISIT_APPROVED: "visit_approved",
    VISIT_REJECTED: "visit_rejected",
} as const);

export type NotificationTypeValue = typeof NotificationType[keyof typeof NotificationType];
