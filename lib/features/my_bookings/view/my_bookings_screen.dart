import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/constants/survey_type.dart';
import '../../../core/models/appointment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/selected_appointment_provider.dart';
import '../viewmodel/my_bookings_viewmodel.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsState = ref.watch(myBookingsViewModelProvider);
    final selectedFilter = ref.watch(myBookingsStatusFilterProvider);

    final statusOptions = [
      {'label': 'All', 'code': null},
      {'label': 'Pending', 'code': AppointmentStatus.pendingAssignment.code},
      {'label': 'Under Review', 'code': AppointmentStatus.underReview.code},
      {
        'label': 'Clarification Needed',
        'code': AppointmentStatus.clarificationRequested.code,
      },
      {'label': 'Approved', 'code': AppointmentStatus.approved.code},
      {'label': 'Rejected', 'code': AppointmentStatus.rejected.code},
      {'label': 'Task Assigned', 'code': AppointmentStatus.taskAssigned.code},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Booking',
            onPressed: () => context.push('/booking-wizard'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: statusOptions.map((opt) {
                final isSelected = selectedFilter == opt['code'];
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilterChip(
                    label: Text(opt['label'] as String),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref
                          .read(myBookingsStatusFilterProvider.notifier)
                          .setFilter(selected ? opt['code'] : null);
                    },
                    selectedColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? AppColors.primaryDarkAccent.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textInverse
                        : AppColors.primary,
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(myBookingsViewModelProvider.notifier).refresh(),
              child: bookingsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => EmptyStateWidget(
                  title: 'Failed to load bookings',
                  message: err.toString(),
                  icon: Icons.error_outline,
                  buttonText: 'Retry',
                  onButtonPressed: () =>
                      ref.refresh(myBookingsViewModelProvider),
                ),
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return EmptyStateWidget(
                      title: 'No bookings found',
                      message: selectedFilter == null
                          ? 'You have not made any survey appointments yet.'
                          : 'No appointments match the selected filter.',
                      icon: Icons.bookmark_border,
                      buttonText: 'Start New Survey',
                      onButtonPressed: () => context.push('/booking-wizard'),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: appointments.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final item = appointments[index];
                      return _buildBookingCard(context, ref, item);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
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
        contentPadding: EdgeInsets.all(16.w),
        onTap: () {
          ref.read(selectedAppointmentIdProvider.notifier).select(item.id);
          context.push('/appointment-detail/${item.id}');
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ),
            _buildStatusBadge(context, item.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),
            Text(
              'Area: ${item.areaName}',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              'Location: ${item.district}, ${item.state}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Date: $formattedDate',
              style: TextStyle(
                fontSize: 12.sp,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
}
