import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

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

  Future<void> _pickDate(BuildContext context, DateTime initialDate) async {
    final tomorrow = _getNextWorkingDay();
    final maxDate = DateTime.now().add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(tomorrow) ? tomorrow : initialDate,
      firstDate: tomorrow,
      lastDate: maxDate,
      selectableDayPredicate: (day) {
        // Disable Saturday (6) and Sunday (7)
        return day.weekday != DateTime.saturday &&
            day.weekday != DateTime.sunday;
      },
    );

    if (picked != null) {
      final wizardState = ref.read(bookingWizardViewModelProvider);
      ref
          .read(bookingWizardViewModelProvider.notifier)
          .updateState(wizardState.copyWith(startDate: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final selectedDate = wizardState.startDate ?? _getNextWorkingDay();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Survey Preferred Start Date',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Select your preferred date to start the survey (Weekends are excluded).',
            style: TextStyle(
              fontSize: 13.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      size: 28.sp,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Preferred Date',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                    ),
                    onPressed: () => _pickDate(context, selectedDate),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
