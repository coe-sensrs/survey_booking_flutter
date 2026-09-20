import '../models/notification_message.dart';

/// Abstract interface for Firebase Cloud Messaging operations.
///
/// ViewModels depend on this abstraction, not on FirebaseMessaging.instance
/// directly, preserving the project's Dependency Inversion architecture.
abstract interface class NotificationService {
  /// Initializes FCM, sets foreground presentation options, and wires up
  /// background/terminated message handlers.
  Future<void> initialize();

  /// Requests the Android notification permission (Android 13+).
  /// Failure is non-fatal — the app remains usable without push notifications.
  Future<void> requestPermission();

  /// Returns the current FCM registration token, or null if unavailable.
  Future<String?> getToken();

  /// Saves the current FCM token to Firestore under users/{uid}/fcmTokens.
  /// Idempotent — arrayUnion prevents duplicates.
  Future<void> registerToken(String uid);

  /// Removes the current FCM token from the previous user's Firestore document.
  /// Called during account switching to prevent cross-role notification delivery.
  Future<void> unregisterToken(String uid);

  /// Returns the [NotificationMessage] the app was launched from (terminated state),
  /// or null if the app was opened normally.
  Future<NotificationMessage?> getInitialNotification();

  /// Stream of parsed [NotificationMessage]s received while the app is
  /// in the foreground.
  Stream<NotificationMessage> get foregroundMessages;

  /// Stream of [NotificationMessage]s from notification taps while the app
  /// was backgrounded.
  Stream<NotificationMessage> get notificationOpened;
}
