import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/constants/survey_type.dart';
import '../../../core/models/appointment.dart';
import '../../../core/models/audit_log_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../my_bookings/providers/selected_appointment_provider.dart';
import '../viewmodel/home_viewmodel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).value;
    final homeState = ref.watch(homeViewModelProvider);

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
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
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
                    AppButton(
                      text: 'Start New Survey',
                      icon: Icons.add_circle_outline,
                      onPressed: () {
                        context.push('/booking-wizard');
                      },
                    ),
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
                              color: AppColors.primary,
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
                                color: Colors.grey[600],
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
                        onAction: () => context.push('/my-bookings'),
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
                              return _buildActivityTile(activity);
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
        Icon(icon, size: 20.sp, color: AppColors.primary),
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
          context.push('/appointment-detail/${item.id}');
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
            _buildStatusBadge(item.status),
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
                  color: Colors.grey,
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
                  color: Colors.grey,
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

  Widget _buildStatusBadge(AppointmentStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case AppointmentStatus.approved:
      case AppointmentStatus.taskAssigned:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case AppointmentStatus.rejected:
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      case AppointmentStatus.clarificationRequested:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        break;
      case AppointmentStatus.underReview:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        break;
      case AppointmentStatus.pendingAssignment:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
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

  Widget _buildActivityTile(AuditLogEntry activity) {
    final formattedTime = DateFormat(
      'dd MMM, hh:mm a',
    ).format(activity.timestamp);
    final actionText = activity.action.replaceAll('_', ' ').toUpperCase();

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16.r,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Icon(Icons.history, size: 16.sp, color: AppColors.primary),
      ),
      title: Text(
        actionText,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'By ${activity.performedByName} • $formattedTime',
        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
      ),
    );
  }
}
