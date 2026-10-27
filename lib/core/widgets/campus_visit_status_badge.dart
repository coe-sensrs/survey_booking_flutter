import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import '../constants/campus_visit_status.dart';

/// Reusable status chip badge for Campus Visits.
/// Supports seamless dark mode switching without hardcoded opaque colors.
class CampusVisitStatusBadge extends StatelessWidget {
  final CampusVisitStatus status;

  const CampusVisitStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg;
    final Color fg;

    switch (status) {
      case CampusVisitStatus.approved:
        bg = isDark
            ? Colors.green.withValues(alpha: 0.25)
            : Colors.green.shade100;
        fg = isDark ? const Color(0xFF81C784) : Colors.green.shade800;
        break;
      case CampusVisitStatus.rejected:
        bg = isDark ? Colors.red.withValues(alpha: 0.25) : Colors.red.shade100;
        fg = isDark ? const Color(0xFFE57373) : Colors.red.shade800;
        break;
      case CampusVisitStatus.pending:
        bg = isDark
            ? Colors.orange.withValues(alpha: 0.25)
            : Colors.orange.shade100;
        fg = isDark ? const Color(0xFFFFB74D) : Colors.orange.shade800;
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
