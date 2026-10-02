import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../viewmodel/admin_appointment_detail_viewmodel.dart';

class SetConfirmedDateSheet extends ConsumerStatefulWidget {
  final String appointmentId;

  const SetConfirmedDateSheet({super.key, required this.appointmentId});

  @override
  ConsumerState<SetConfirmedDateSheet> createState() =>
      _SetConfirmedDateSheetState();
}

class _SetConfirmedDateSheetState extends ConsumerState<SetConfirmedDateSheet> {
  DateTimeRange? _selectedDateRange;
  bool _isSubmitting = false;

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: tomorrow,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedDateRange == null) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(adminAppointmentDetailControllerProvider)
          .setConfirmedDate(
            widget.appointmentId,
            _selectedDateRange!.start,
            _selectedDateRange!.end,
          );

      // Pop first so the snackbar renders on the parent Scaffold.
      if (mounted && context.canPop()) context.pop();

      AppSnackbar.showGlobalSuccess(
        title: 'Date Confirmed',
        message: 'Survey date has been confirmed successfully.',
      );
    } catch (e) {
      // Always dismiss so the error snackbar is fully visible.
      if (mounted && context.canPop()) context.pop();

      final message = e is Failure ? e.message : e.toString();
      AppSnackbar.showGlobalError(title: 'Update Failed', message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set Confirmed Survey Dates',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'These dates will override the applicant\'s preferred dates.',
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 32.h),

            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        _selectedDateRange != null
                            ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'
                            : 'Select date range',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: _selectedDateRange != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedDateRange != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 40.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: FilledButton(
                    onPressed: (_isSubmitting || _selectedDateRange == null)
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirm Date'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
