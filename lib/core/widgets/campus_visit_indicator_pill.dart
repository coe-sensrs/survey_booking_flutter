import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

/// Compact status/count pill with an optional unread indicator dot.
/// Uses theme-aware color blending for light and dark mode contrast and scales
/// down cleanly when constrained on small screens or large accessibility fonts.
class CampusVisitIndicatorPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;
  final Color? dotColor;

  const CampusVisitIndicatorPill({
    super.key,
    required this.label,
    required this.color,
    this.showDot = false,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = Color.lerp(
      color,
      theme.colorScheme.onSurface,
      isDark ? 0.15 : 0.35,
    )!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.5 : 0.35),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 7.w,
                height: 7.w,
                decoration: BoxDecoration(
                  color: dotColor ?? theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 5.w),
            ],
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
