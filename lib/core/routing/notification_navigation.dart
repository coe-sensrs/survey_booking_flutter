import 'package:go_router/go_router.dart';
import '../models/notification_message.dart';
import 'app_router.dart';

/// Centralized notification-to-route mapper.
///
/// Given a [NotificationMessage] and the current user's [role], resolves
/// the correct [go_router] path for the notification tap.
///
/// Navigation never happens inside the notification service itself — this
/// mapper is called from the ViewModel/init layer which has a BuildContext
/// or access to the GoRouter instance.
class NotificationNavigation {
  NotificationNavigation._();

  /// Returns the deep-link path to navigate to for the given notification,
  /// or null if navigation is not applicable (unknown type, missing data).
  static String? resolveRoute(NotificationMessage message, String role) {
    final appointmentId = message.appointmentId;

    switch (message.type) {
      // ── Admin receives booking_created notification ──────────────────────
      case NotificationType.bookingCreated:
        if (appointmentId == null) return null;
        if (role == 'admin') {
          return '/admin-appointment/$appointmentId';
        }
        return null;

      // ── Committee member receives reviewer_assigned notification ─────────
      case NotificationType.reviewerAssigned:
        if (appointmentId == null) return null;
        if (role == 'committee') {
          return '/committee-review/$appointmentId';
        }
        return null;

      // ── Applicant receives rejected / clarification_requested / approved ─
      case NotificationType.rejected:
      case NotificationType.clarificationRequested:
      case NotificationType.approved:
        if (appointmentId == null) return null;
        if (role == 'applicant') {
          return '/appointment-detail/$appointmentId';
        }
        return null;

      // ── Committee member receives clarification_reply ────────────────────
      case NotificationType.clarificationReply:
        if (appointmentId == null) return null;
        if (role == 'committee') {
          return '/committee-review/$appointmentId';
        }
        return null;

      // ── task_assigned: applicant goes to appointment detail, committee
      //    member goes to their task detail ──────────────────────────────
      case NotificationType.taskAssigned:
        if (appointmentId == null) return null;
        if (role == 'applicant') {
          return '/appointment-detail/$appointmentId';
        }
        if (role == 'committee') {
          return '/committee-task/$appointmentId';
        }
        return null;

      // ── Unknown types: no navigation, no crash ───────────────────────────
      case NotificationType.unknown:
        return null;
    }
  }

  /// Navigates to the notification target using [GoRouter].
  ///
  /// Null routes (unknown types or missing data) are silently ignored.
  /// The target screen performs its own Firestore authorization check —
  /// the appointmentId in the payload is only a navigation hint.
  static void navigate(GoRouter router, NotificationMessage message, String role) {
    final route = resolveRoute(message, role);
    if (route == null) return;
    router.push(route);
  }

  /// Returns the fallback home route for a given role, used when an
  /// in-progress notification cannot be processed (e.g. missing appointmentId).
  static String homeRouteFor(String role) {
    switch (role) {
      case 'admin':
        return AppRoutes.adminDashboard;
      case 'committee':
        return AppRoutes.committeeDashboard;
      default:
        return AppRoutes.home;
    }
  }
}
