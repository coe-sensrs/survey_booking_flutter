import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step5StartDate extends ConsumerStatefulWidget {
  const Step5StartDate({super.key});

  @override
  ConsumerState<Step5StartDate> createState() => _Step5StartDateState();
}

class _Step5StartDateState extends ConsumerState<Step5StartDate> {
  DateTime _getNextWorkingDay() {
    DateTime date = DateTime.now().add(const Duration(days: 1));
    while (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wizardState = ref.read(bookingWizardViewModelProvider);
      if (wizardState.startDate == null) {
        ref
            .read(bookingWizardViewModelProvider.notifier)
            .updateState(wizardState.copyWith(startDate: _getNextWorkingDay()));
      }
    });
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final wizardState = ref.read(bookingWizardViewModelProvider);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final maxDate = DateTime(now.year, now.month, now.day + 90);

    DateTime initial = wizardState.startDate ?? _getNextWorkingDay();
    if (initial.isBefore(tomorrow)) {
      initial = tomorrow;
    } else if (initial.isAfter(maxDate)) {
      initial = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: tomorrow,
      lastDate: maxDate,
    );

    if (picked != null) {
      final shouldClearEndDate =
          wizardState.endDate != null && wizardState.endDate!.isBefore(picked);

      ref
          .read(bookingWizardViewModelProvider.notifier)
          .updateState(
            wizardState.copyWith(
              startDate: picked,
              clearEndDate: shouldClearEndDate,
            ),
          );
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final wizardState = ref.read(bookingWizardViewModelProvider);
    if (wizardState.startDate == null) {
      AppSnackbar.showGlobalWarning(
        title: 'Start Date Required',
        message: 'Please select a survey start date first.',
      );
      return;
    }

    final start = wizardState.startDate!;
    final firstDate = DateTime(start.year, start.month, start.day);
    final maxDate = DateTime(start.year, start.month, start.day + 90);

    DateTime initial = wizardState.endDate ?? start;
    if (initial.isBefore(firstDate)) {
      initial = firstDate;
    } else if (initial.isAfter(maxDate)) {
      initial = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: maxDate,
    );

    if (picked != null) {
      ref
          .read(bookingWizardViewModelProvider.notifier)
          .updateState(wizardState.copyWith(endDate: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final startDate = wizardState.startDate;
    final endDate = wizardState.endDate;

    int? duration;
    if (startDate != null && endDate != null) {
      duration = endDate.difference(startDate).inDays + 1;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Survey Dates',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Select the dates for your survey work. Weekends are allowed.',
            style: TextStyle(
              fontSize: 13.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          // Start Date
          Text(
            'Start Date',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          InkWell(
            onTap: () => _pickStartDate(context),
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    startDate != null
                        ? DateFormat('dd MMM yyyy').format(startDate)
                        : 'Select Start Date',
                    style: TextStyle(fontSize: 15.sp),
                  ),
                  Icon(Icons.calendar_month, color: colorScheme.primary),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // End Date
          Text(
            'End Date',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          InkWell(
            onTap: () => _pickEndDate(context),
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    endDate != null
                        ? DateFormat('dd MMM yyyy').format(endDate)
                        : 'Select End Date',
                    style: TextStyle(fontSize: 15.sp),
                  ),
                  Icon(Icons.calendar_month, color: colorScheme.primary),
                ],
              ),
            ),
          ),

          SizedBox(height: 24.h),

          // Duration
          if (duration != null)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Survey duration',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    duration == 1
                        ? '1 calendar day'
                        : '$duration calendar days',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
