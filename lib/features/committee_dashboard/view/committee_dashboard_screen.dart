import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/models/appointment.dart';
import '../../../core/routing/app_router.dart';
import '../viewmodel/committee_dashboard_viewmodel.dart';

class CommitteeDashboardScreen extends ConsumerWidget {
  const CommitteeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(committeeDashboardStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Reviews',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        centerTitle: false,
      ),
      body: appointmentsAsync.when(
        // --- Loading state: only shown on first load ---
        loading: () => const Center(child: CircularProgressIndicator()),

        // --- Error state: retry without crashing the whole portal ---
        error: (error, _) => _ErrorRetryView(
          message: error.toString(),
          onRetry: () => ref.invalidate(committeeDashboardStreamProvider),
        ),

        // --- Data state ---
        data: (appointments) {
          if (appointments.isEmpty) {
            return _EmptyReviewsView();
          }

          // Segment appointments: active (pending action) vs. resolved
          final active = appointments
              .where(
                (a) =>
                    a.status == AppointmentStatus.underReview ||
                    a.status == AppointmentStatus.clarificationRequested,
              )
              .toList();
          final resolved = appointments
              .where(
                (a) =>
                    a.status == AppointmentStatus.approved ||
                    a.status == AppointmentStatus.rejected,
              )
              .toList();

          return RefreshIndicator(
            // Pull-to-refresh invalidates the stream provider
            onRefresh: () async =>
                ref.invalidate(committeeDashboardStreamProvider),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Awaiting Your Action (${active.length})',
                  ),
                  SizedBox(height: 8.h),
                  ...active.map(
                    (a) => _AppointmentCard(
                      appointment: a,
                      onTap: () => context.push(
                        AppRoutes.committeeReviewDetail.replaceAll(':id', a.id),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
                if (resolved.isNotEmpty) ...[
                  _SectionHeader(title: 'Resolved (${resolved.length})'),
                  SizedBox(height: 8.h),
                  ...resolved.map(
                    (a) => _AppointmentCard(
                      appointment: a,
                      onTap: () => context.push(
                        AppRoutes.committeeReviewDetail.replaceAll(':id', a.id),
                      ),
                      muted: true,
                    ),
                  ),
                ],
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header — avoids inline Text styling duplication
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appointment list card — only rebuilds when its [appointment] value changes
// ---------------------------------------------------------------------------
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;
  final bool muted;

  const _AppointmentCard({
    required this.appointment,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(appointment.status, colorScheme);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Card(
        elevation: muted ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(
            color: muted
                ? colorScheme.outlineVariant.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SRV-${appointment.id.substring(0, 6).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary.withValues(
                            alpha: muted ? 0.6 : 1.0,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        appointment.status.label,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  appointment.surveyType.label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(
                      alpha: muted ? 0.6 : 1.0,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${appointment.district}, ${appointment.state}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        appointment.applicantName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      DateFormat('dd MMM yyyy').format(appointment.createdAt),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(AppointmentStatus status, ColorScheme colorScheme) {
    return switch (status) {
      AppointmentStatus.underReview => Colors.blue,
      AppointmentStatus.clarificationRequested => Colors.orange,
      AppointmentStatus.approved => Colors.green,
      AppointmentStatus.rejected => colorScheme.error,
      _ => colorScheme.onSurfaceVariant,
    };
  }
}

// ---------------------------------------------------------------------------
// Empty state — shown when no reviews are assigned
// ---------------------------------------------------------------------------
class _EmptyReviewsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Review Assignments',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Appointments assigned to you for review will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error + retry — isolated to this section, not full-screen fatal
// ---------------------------------------------------------------------------
class _ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56.sp,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
            ),
            SizedBox(height: 16.h),
            Text(
              'Could not load reviews',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 20.h),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
