import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../constants/appointment_status.dart';

class AppointmentStatusBadge extends StatelessWidget {
  final AppointmentStatus status;

  const AppointmentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg;
    final Color fg;

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
