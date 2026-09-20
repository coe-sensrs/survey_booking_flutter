import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import '../../../core/models/notification_message.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/notification_navigation.dart';
import '../viewmodel/notification_viewmodel.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Wraps a [child] widget with an animated in-app notification banner that
/// slides in from the top when a foreground FCM message is received.
///
/// Place this widget high in the tree (e.g. wrapping the shell screen) so
/// that banners appear regardless of which tab is active.
class NotificationOverlayWrapper extends ConsumerWidget {
  const NotificationOverlayWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(notificationViewModelProvider);
    return Stack(
      children: [
        child,
        if (message != null)
          _NotificationBanner(
            key: ValueKey(message),
            message: message,
            onDismiss: () =>
                ref.read(notificationViewModelProvider.notifier).dismiss(),
            onView: () {
              ref.read(notificationViewModelProvider.notifier).dismiss();
              final appUser = ref.read(authViewModelProvider).value;
              final role = appUser?.role ?? '';
              NotificationNavigation.navigate(appRouter, message, role);
            },
          ),
      ],
    );
  }
}

class _NotificationBanner extends StatefulWidget {
  const _NotificationBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    required this.onView,
  });

  final NotificationMessage message;
  final VoidCallback onDismiss;
  final VoidCallback onView;

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    // Auto-dismiss banner after 4 seconds
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      _dismissWithAnimation();
    });
  }

  void _dismissWithAnimation() {
    _autoDismissTimer?.cancel();
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  void _handleTap() {
    _autoDismissTimer?.cancel();
    widget.onView();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Dismissible(
              key: ValueKey(widget.message),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12.r),
                color: colorScheme.surfaceContainerHighest,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.message.appointmentId != null
                      ? _handleTap
                      : null,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_rounded,
                          color: colorScheme.primary,
                          size: 22.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.message.title != null)
                                Text(
                                  widget.message.title!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (widget.message.body != null)
                                Text(
                                  widget.message.body!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        if (widget.message.appointmentId != null)
                          TextButton(
                            onPressed: _handleTap,
                            child: Text(
                              'VIEW',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: _dismissWithAnimation,
                          icon: Icon(
                            Icons.close,
                            size: 18.sp,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
