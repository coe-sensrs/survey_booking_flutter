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
} as const);

export type NotificationTypeValue = typeof NotificationType[keyof typeof NotificationType];
