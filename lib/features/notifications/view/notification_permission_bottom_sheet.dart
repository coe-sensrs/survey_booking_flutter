import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

class NotificationPermissionBottomSheet extends ConsumerWidget {
  const NotificationPermissionBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(
                  alpha: isDark ? 0.3 : 1.0,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                size: 48.r,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(height: 24.h),

            // Title
            Text(
              'Stay Updated on Your Surveys',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),

            // Subtitle
            Text(
              'Enable notifications to get real-time updates when your survey is confirmed, scheduled, or reviewed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),

            // Benefit List
            _buildBenefitRow(
              context,
              icon: Icons.calendar_today_outlined,
              title: 'Instant Booking Status',
              subtitle: 'Know exactly when your date is confirmed',
            ),
            SizedBox(height: 16.h),
            _buildBenefitRow(
              context,
              icon: Icons.rate_review_outlined,
              title: 'Review Feedback',
              subtitle:
                  'Get notified when the committee requests clarification',
            ),
            SizedBox(height: 16.h),
            _buildBenefitRow(
              context,
              icon: Icons.assignment_outlined,
              title: 'Task Assignments',
              subtitle: 'Never miss an important task or deadline',
            ),
            SizedBox(height: 40.h),

            // Actions
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: FilledButton(
                onPressed: () async {
                  context.pop();
                  final notifService = ref.read(notificationServiceProvider);
                  final granted = await notifService.requestPermission();

                  if (granted) {
                    final appUser = ref.read(authViewModelProvider).value;
                    if (appUser != null) {
                      await notifService.registerToken(appUser.uid);
                    }
                    AppSnackbar.showGlobalSuccess(
                      title: 'Notifications Enabled',
                      message: 'You will receive updates about your surveys.',
                    );
                  }
                },
                child: const Text(
                  'Turn On Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary, size: 24.r),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
