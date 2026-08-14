import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';

class Step9Acknowledgement extends ConsumerWidget {
  const Step9Acknowledgement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40.r,
            backgroundColor: Colors.green.shade100,
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade800,
              size: 50.sp,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Booking Request Submitted!',
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Text(
            'Your survey appointment booking has been recorded successfully. '
            'An admin will assign a reviewer shortly.',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 36.h),
          AppButton(
            text: 'Return to Home',
            onPressed: () {
              context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}
