import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/hive_storage_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import 'notification_permission_bottom_sheet.dart';

/// Wraps the shell navigation to conditionally display the notification permission
/// bottom sheet primer on first mount for authenticated users.
class NotificationPermissionCoordinator extends ConsumerStatefulWidget {
  const NotificationPermissionCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationPermissionCoordinator> createState() =>
      _NotificationPermissionCoordinatorState();
}

class _NotificationPermissionCoordinatorState
    extends ConsumerState<NotificationPermissionCoordinator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPrompt();
    });
  }

  Future<void> _checkAndShowPrompt() async {
    // 1. Only prompt if a user is authenticated
    final user = ref.read(authViewModelProvider).value;
    if (user == null || !mounted) return;

    // 2. Only prompt once per device/session clear
    if (HiveStorageService.hasSeenNotificationPrompt()) {
      return;
    }

    // 3. Skip if permission is already granted via OS
    final notifService = ref.read(notificationServiceProvider);
    final isGranted = await notifService.isPermissionGranted();
    if (isGranted) {
      // Mark as seen so we don't query OS needlessly next time
      await HiveStorageService.setNotificationPromptSeen(true);
      return;
    }

    if (!mounted) return;
    
    // Mark as seen *before* showing to prevent loops if app minimizes/crashes
    await HiveStorageService.setNotificationPromptSeen(true);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => const NotificationPermissionBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
