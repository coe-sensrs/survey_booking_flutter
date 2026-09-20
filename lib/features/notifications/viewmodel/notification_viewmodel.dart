import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/notification_message.dart';
import '../../../core/providers/core_providers.dart';

/// Exposes the latest foreground [NotificationMessage] to the UI overlay.
///
/// Set to null after the user acknowledges or dismisses the in-app banner.
final notificationViewModelProvider =
    NotifierProvider<NotificationViewModel, NotificationMessage?>(
  NotificationViewModel.new,
);

class NotificationViewModel extends Notifier<NotificationMessage?> {
  StreamSubscription<NotificationMessage>? _foregroundSub;

  @override
  NotificationMessage? build() {
    final service = ref.read(notificationServiceProvider);

    _foregroundSub = service.foregroundMessages.listen((message) {
      if (message.type != NotificationType.unknown) {
        state = message;
      }
    });

    ref.onDispose(() => _foregroundSub?.cancel());

    return null;
  }

  /// Called when the user dismisses the in-app notification banner.
  void dismiss() => state = null;
}
