import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/notification_message.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/notification_navigation.dart';
import '../../../core/services/firebase_notification_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Handles background→foreground notification tap navigation and the
/// terminated-state initial notification.
///
/// Wraps the root app tree and routes through [appRouter].
/// It does NOT render any UI — all visual notification feedback is handled
/// by [NotificationOverlayWrapper].
class NotificationHandler extends ConsumerStatefulWidget {
  const NotificationHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationHandler> createState() =>
      _NotificationHandlerState();
}

class _NotificationHandlerState extends ConsumerState<NotificationHandler> {
  StreamSubscription<NotificationMessage>? _openedSub;
  ProviderSubscription<AsyncValue<dynamic>>? _authWaitSub;
  bool _initialMessageProcessed = false;

  @override
  void initState() {
    super.initState();

    // Background → foreground tap: fires via onMessageOpenedApp.
    final service = ref.read(notificationServiceProvider);
    _openedSub = service.notificationOpened.listen(_handleNavigation);

    // Terminated-state: check for the initial message after first frame
    // so GoRouter and auth are both ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialMessage();
    });
  }

  @override
  void dispose() {
    _openedSub?.cancel();
    _authWaitSub?.close();
    super.dispose();
  }

  Future<void> _checkInitialMessage() async {
    if (_initialMessageProcessed) return;
    _initialMessageProcessed = true;

    final concreteService =
        ref.read(notificationServiceProvider) as FirebaseNotificationService;
    final message = await concreteService.getInitialNotification();
    if (message == null || !mounted) return;

    // Wait for auth to resolve before navigating — never navigate before
    // auth + role resolution is complete.
    final authState = ref.read(authViewModelProvider);
    if (authState.isLoading) {
      _authWaitSub?.close();
      _authWaitSub = ref.listenManual(authViewModelProvider, (prev, next) {
        if (!next.isLoading && mounted) {
          _authWaitSub?.close();
          _authWaitSub = null;
          _handleNavigation(message);
        }
      }, fireImmediately: false);
    } else {
      _handleNavigation(message);
    }
  }

  void _handleNavigation(NotificationMessage message) {
    if (!mounted) return;
    final appUser = ref.read(authViewModelProvider).value;
    final role = appUser?.role ?? '';
    if (role.isEmpty) return;

    NotificationNavigation.navigate(appRouter, message, role);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
