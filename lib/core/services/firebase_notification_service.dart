import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_message.dart';
import '../repositories/notification_repository.dart';
import 'firebase_notification_repository.dart';
import 'notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level background message handler.
// MUST be a top-level function annotated with @pragma so the Flutter engine
// can register it as an isolate entry point.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure framework binding is initialized in background isolate.
  WidgetsFlutterBinding.ensureInitialized();
  // Background handler runs in a separate isolate — no Flutter UI access.
  // The OS displays notifications automatically for message payloads.
}

/// Concrete Firebase implementation of [NotificationService].
///
/// This is the ONLY class in the Flutter codebase that may call
/// [FirebaseMessaging.instance] directly. All ViewModels and Repositories
/// must use the abstract [NotificationService] interface.
class FirebaseNotificationService implements NotificationService {
  final NotificationRepository _repository;
  final _foregroundController =
      StreamController<NotificationMessage>.broadcast();
  final _openedController = StreamController<NotificationMessage>.broadcast();
  StreamSubscription<String>? _tokenRefreshSub;

  FirebaseNotificationService({NotificationRepository? repository})
    : _repository = repository ?? FirebaseNotificationRepository();

  @override
  Future<void> initialize() async {
    try {
      // Register the background/terminated handler before any other setup.
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Show notifications as banners + play sound when the app is in foreground.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Wire foreground message stream.
      FirebaseMessaging.onMessage.listen((message) {
        final notification = _parseMessage(message);
        if (notification != null) {
          _foregroundController.add(notification);
        }
      });

      // Wire background→foreground tap stream.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final notification = _parseMessage(message);
        if (notification != null) {
          _openedController.add(notification);
        }
      });
    } catch (e) {
      // FCM initialization failure must never crash startup or prevent runApp.
      debugPrint('FCM initialization non-fatal error: $e');
    }
  }

  /// Returns the [NotificationMessage] the app was launched from (terminated state),
  /// or null if the app was opened normally.
  @override
  Future<NotificationMessage?> getInitialNotification() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message == null) return null;
      return _parseMessage(message);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isPermissionGranted() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      // FCM permission failure must never crash the app.
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> registerToken(String uid) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await _repository.addToken(uid, token);
      // Cancel previous token rotation listener before attaching a new one
      // to prevent leaks and ensure the token updates the active user's UID.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        newToken,
      ) async {
        try {
          await _repository.addToken(uid, newToken);
        } catch (_) {
          // Token refresh failures are non-fatal.
        }
      });
    } catch (_) {
      // Registration failure must not throw — app works without push.
    }
  }

  @override
  Future<void> unregisterToken(String uid) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    final token = await getToken();
    if (token == null) return;
    try {
      await _repository.removeToken(uid, token);
    } catch (_) {
      // Unregister failure is non-fatal.
    }
  }

  @override
  Stream<NotificationMessage> get foregroundMessages =>
      _foregroundController.stream;

  @override
  Stream<NotificationMessage> get notificationOpened =>
      _openedController.stream;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  NotificationMessage? _parseMessage(RemoteMessage message) {
    // The notification type lives in the data payload, not the notification body,
    // to ensure consistency across foreground/background/terminated states.
    if (message.data.isEmpty) return null;
    return NotificationMessage.fromFcmData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}
