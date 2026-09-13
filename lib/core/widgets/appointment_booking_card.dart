import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants/survey_type.dart';
import '../models/appointment.dart';
import '../routing/app_router.dart';
import '../../features/my_bookings/providers/selected_appointment_provider.dart';
import 'appointment_status_badge.dart';

class AppointmentBookingCard extends ConsumerWidget {
  final Appointment item;

  /// If true, uses [context.go] (shell navigation); if false, uses [context.push].
  final bool useGoNavigation;

  const AppointmentBookingCard({
    super.key,
    required this.item,
    this.useGoNavigation = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        contentPadding: EdgeInsets.all(14.w),
        onTap: () {
          ref.read(selectedAppointmentIdProvider.notifier).select(item.id);
          if (useGoNavigation) {
            context.go(AppRoutes.appointmentDetailTab);
          } else {
            context.push(AppRoutes.appointmentDetailTab);
          }
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
            AppointmentStatusBadge(status: item.status),
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
}
