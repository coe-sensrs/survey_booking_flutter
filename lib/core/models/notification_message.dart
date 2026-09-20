/// Canonical FCM notification type identifiers.
/// Values MUST match the string constants in the Cloud Functions
/// `notification_types.ts` file.
enum NotificationType {
  bookingCreated,
  reviewerAssigned,
  rejected,
  clarificationRequested,
  clarificationReply,
  approved,
  taskAssigned,
  unknown;

  static NotificationType fromString(String? value) {
    switch (value) {
      case 'booking_created':
        return NotificationType.bookingCreated;
      case 'reviewer_assigned':
        return NotificationType.reviewerAssigned;
      case 'rejected':
        return NotificationType.rejected;
      case 'clarification_requested':
        return NotificationType.clarificationRequested;
      case 'clarification_reply':
        return NotificationType.clarificationReply;
      case 'approved':
        return NotificationType.approved;
      case 'task_assigned':
        return NotificationType.taskAssigned;
      default:
        // Unknown types are silently degraded — must not crash the app.
        return NotificationType.unknown;
    }
  }
}

/// A parsed, type-safe representation of a received FCM data payload.
///
/// The raw FCM data map contains only `type` and `appointmentId` —
/// no PII is ever included. The actual appointment data must be
/// loaded from Firestore after navigation.
class NotificationMessage {
  final NotificationType type;
  final String? appointmentId;
  final String? title;
  final String? body;

  const NotificationMessage({
    required this.type,
    this.appointmentId,
    this.title,
    this.body,
  });

  /// Parses a raw FCM data map into a [NotificationMessage].
  /// Unknown types are mapped to [NotificationType.unknown] — they will not
  /// crash the application or trigger navigation.
  factory NotificationMessage.fromFcmData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    return NotificationMessage(
      type: NotificationType.fromString(data['type'] as String?),
      appointmentId: data['appointmentId'] as String?,
      title: title,
      body: body,
    );
  }
}
