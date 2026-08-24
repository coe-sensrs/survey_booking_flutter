import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        // Example: Only weekdays (Mon-Fri)
        return date.weekday >= DateTime.monday &&
            date.weekday <= DateTime.friday;
      },
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(adminAppointmentDetailControllerProvider)
          .setConfirmedDate(widget.appointmentId, _selectedDate!);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          title: 'Success',
          message: 'Confirmed date updated successfully.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, title: 'Error', message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Set Confirmed Date',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'This date will override the applicant\'s preferred date.',
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
                      _selectedDate != null
                          ? DateFormat(
                              'EEEE, MMM dd, yyyy',
                            ).format(_selectedDate!)
                          : 'Select a date',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: _selectedDate != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedDate != null
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
                  onPressed: (_isSubmitting || _selectedDate == null)
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
    );
  }
}
