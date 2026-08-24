import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../viewmodel/admin_appointment_detail_viewmodel.dart';

class AssignTaskSheet extends ConsumerStatefulWidget {
  final String appointmentId;

  const AssignTaskSheet({super.key, required this.appointmentId});

  @override
  ConsumerState<AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends ConsumerState<AssignTaskSheet> {
  AppUser? _selectedMember;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_selectedMember == null) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(adminAppointmentDetailControllerProvider)
          .assignFieldworkTask(
            widget.appointmentId,
            _selectedMember!.uid,
            _selectedMember!.fullName,
          );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          title: 'Success',
          message: 'Fieldwork task assigned successfully.',
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
    final activeMembersAsync = ref.watch(activeCommitteeMembersProvider);

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
            'Assign Fieldwork Task',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Select a committee member to conduct the fieldwork survey.',
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 24.h),

          Expanded(
            child: activeMembersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return const Center(
                    child: Text('No active committee members found.'),
                  );
                }

                return RadioGroup<AppUser>(
                  groupValue: _selectedMember,
                  onChanged: (value) {
                    setState(() {
                      _selectedMember = value;
                    });
                  },
                  child: ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return RadioListTile<AppUser>(
                        title: Text(member.fullName),
                        subtitle: Text(member.expertiseTag ?? member.email),
                        value: member,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.green.shade700,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),

          SizedBox(height: 24.h),
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
                  onPressed: (_isSubmitting || _selectedMember == null)
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
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
                      : const Text('Confirm Task'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
