import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/constants/survey_type.dart';
import '../../../core/models/appointment.dart';
import '../../../core/models/audit_log_entry.dart';
import '../../../core/routing/app_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../booking_wizard/viewmodel/booking_wizard_viewmodel.dart';
import '../../my_bookings/providers/selected_appointment_provider.dart';
import '../viewmodel/home_viewmodel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _confirmStartFresh(
    BuildContext context,
    WidgetRef ref,
    int currentStep,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Fresh Survey?'),
        content: Text(
          'You have saved progress at Step $currentStep of 9. '
          'Starting a new survey will discard your existing draft. Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Draft'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(bookingWizardViewModelProvider.notifier)
                  .startFreshSurvey();
              if (context.mounted) {
                context.push('/booking-wizard');
              }
            },
            child: const Text('Discard & Start Fresh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).value;
    final homeState = ref.watch(homeViewModelProvider);
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final hasDraft = ref
        .watch(bookingWizardViewModelProvider.notifier)
        .hasDraft;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Survey Desk',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeViewModelProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.fullName ?? 'Applicant'} 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Book survey appointments & track your request status seamlessly.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (hasDraft) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_document,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Draft in progress • Step ${wizardState.currentStep} of 9',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                minimumSize: Size.fromHeight(46.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                textStyle: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                context.push('/booking-wizard');
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                'Resume (Step ${wizardState.currentStep})',
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              minimumSize: Size.zero,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              textStyle: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () => _confirmStartFresh(
                              context,
                              ref,
                              wizardState.currentStep,
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New'),
                          ),
                        ],
                      ),
                    ] else ...[
                      AppButton(
                        text: 'Start New Survey',
                        icon: Icons.add_circle_outline,
                        onPressed: () {
                          context.push('/booking-wizard');
                        },
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              homeState.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => EmptyStateWidget(
                  title: 'Unable to load dashboard',
                  message: err.toString(),
                  icon: Icons.error_outline,
                  buttonText: 'Retry',
                  onButtonPressed: () => ref.refresh(homeViewModelProvider),
                ),
                data: (data) {
                  final isFirstTime =
                      data.upcomingSurveys.isEmpty &&
                      data.recentRequests.isEmpty;

                  if (isFirstTime) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.h),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_add,
                              size: 64.sp,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'No Survey Bookings Yet',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Start your first survey booking wizard using the button above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Upcoming Scheduled Surveys
                      if (data.upcomingSurveys.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          title: 'Upcoming Scheduled Surveys',
                          icon: Icons.event,
                        ),
                        SizedBox(height: 8.h),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.upcomingSurveys.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final item = data.upcomingSurveys[index];
                            return _buildAppointmentCard(context, ref, item);
                          },
                        ),
                        SizedBox(height: 24.h),
                      ],

                      // Section 2: Recent Appointment Requests
                      _buildSectionHeader(
                        context,
                        title: 'Recent Appointment Requests',
                        icon: Icons.history,
                        actionText: 'View All',
                        onAction: () => context.go(AppRoutes.myBookings),
                      ),
                      SizedBox(height: 8.h),
                      if (data.recentRequests.isEmpty)
                        const EmptyStateWidget(
                          title: 'No recent requests',
                          message:
                              'Your recent booking requests will appear here.',
                          icon: Icons.inbox,
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.recentRequests.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final item = data.recentRequests[index];
                            return _buildAppointmentCard(context, ref, item);
                          },
                        ),

                      SizedBox(height: 24.h),

                      // Section 3: Recent Activity Feed
                      _buildSectionHeader(
                        context,
                        title: 'Recent Activity',
                        icon: Icons.notifications_none,
                      ),
                      SizedBox(height: 8.h),
                      if (data.recentActivity.isEmpty)
                        const EmptyStateWidget(
                          title: 'No activity yet',
                          message: 'Status updates and logs will appear here.',
                          icon: Icons.feed_outlined,
                        )
                      else
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: data.recentActivity.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final activity = data.recentActivity[index];
                              return _buildActivityTile(context, activity);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (actionText != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionText)),
      ],
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    WidgetRef ref,
    Appointment item,
  ) {
    final title = item.surveyType == SurveyType.other
        ? (item.customSurveyName ?? 'Other Survey')
        : item.surveyType.label;

    final formattedDate = item.confirmedDate != null
        ? DateFormat('dd MMM yyyy').format(item.confirmedDate!)
        : DateFormat('dd MMM yyyy').format(item.preferredDate);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: ListTile(
        contentPadding: EdgeInsets.all(12.w),
        onTap: () {
          ref.read(selectedAppointmentIdProvider.notifier).select(item.id);
          context.go(AppRoutes.appointmentDetailTab);
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
            _buildStatusBadge(context, item.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    '${item.areaName}, ${item.district}, ${item.state}',
                    style: TextStyle(fontSize: 12.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(width: 4.w),
                Text('Date: $formattedDate', style: TextStyle(fontSize: 12.sp)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, AppointmentStatus status) {
    Color bg;
    Color fg;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case AppointmentStatus.approved:
      case AppointmentStatus.taskAssigned:
        bg = isDark
            ? Colors.green.withValues(alpha: 0.25)
            : Colors.green.shade100;
        fg = isDark ? const Color(0xFF81C784) : Colors.green.shade800;
        break;
      case AppointmentStatus.rejected:
        bg = isDark ? Colors.red.withValues(alpha: 0.25) : Colors.red.shade100;
        fg = isDark ? const Color(0xFFE57373) : Colors.red.shade800;
        break;
      case AppointmentStatus.clarificationRequested:
        bg = isDark
            ? Colors.orange.withValues(alpha: 0.25)
            : Colors.orange.shade100;
        fg = isDark ? const Color(0xFFFFB74D) : Colors.orange.shade800;
        break;
      case AppointmentStatus.underReview:
        bg = isDark
            ? Colors.blue.withValues(alpha: 0.25)
            : Colors.blue.shade100;
        fg = isDark ? const Color(0xFF64B5F6) : Colors.blue.shade800;
        break;
      case AppointmentStatus.pendingAssignment:
        bg = isDark
            ? Colors.grey.withValues(alpha: 0.25)
            : Colors.grey.shade200;
        fg = isDark ? const Color(0xFFBDBDBD) : Colors.grey.shade800;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: fg,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActivityTile(BuildContext context, AuditLogEntry activity) {
    final formattedTime = DateFormat(
      'dd MMM, hh:mm a',
    ).format(activity.timestamp);
    final actionText = activity.action.replaceAll('_', ' ').toUpperCase();

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16.r,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(
          Icons.history,
          size: 16.sp,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        actionText,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'By ${activity.performedByName} • $formattedTime',
        style: TextStyle(
          fontSize: 11.sp,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
