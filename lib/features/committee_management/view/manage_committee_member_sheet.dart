import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_user.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../viewmodel/committee_member_profile_viewmodel.dart';

/// Modal bottom sheet for Admin to edit a committee member's profile.
/// Editable fields: fullName, phone, expertiseTag, active status.
///
/// Pattern: Pop-Before-Snackbar (dismiss sheet → showGlobalSuccess/Error).
/// PopScope disables back-swipe while mutation is in flight.
class ManageCommitteeMemberSheet extends ConsumerStatefulWidget {
  final AppUser member;

  const ManageCommitteeMemberSheet({super.key, required this.member});

  @override
  ConsumerState<ManageCommitteeMemberSheet> createState() =>
      _ManageCommitteeMemberSheetState();
}

class _ManageCommitteeMemberSheetState
    extends ConsumerState<ManageCommitteeMemberSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _tagController;
  late bool _isActive;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.fullName);
    _phoneController = TextEditingController(text: widget.member.phone);
    _tagController = TextEditingController(
      text: widget.member.expertiseTag ?? '',
    );
    _isActive = widget.member.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref
        .read(manageMemberControllerProvider.notifier)
        .updateMember(
          uid: widget.member.uid,
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          expertiseTag: _tagController.text.trim(),
          active: _isActive,
        );

    if (!mounted) return;

    // Pop-Before-Snackbar: dismiss first, then show global snackbar
    if (context.canPop()) context.pop();

    if (success) {
      AppSnackbar.showGlobalSuccess(
        title: 'Success',
        message: 'Member profile updated successfully.',
      );
    } else {
      final error = ref.read(manageMemberControllerProvider).errorMessage;
      AppSnackbar.showGlobalError(
        title: 'Error',
        message: error ?? 'Failed to update member profile.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(
      manageMemberControllerProvider.select((s) => s.isSubmitting),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !isSubmitting,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          24.w,
          16.h,
          24.w,
          MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              Text(
                'Manage Member',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                widget.member.email,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 24.h),

              // Full Name
              AppTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter full name',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required.';
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Phone
              AppTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Enter 10-digit phone number',
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Phone number is required.';
                  }
                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 10 || digits.length > 15) {
                    return 'Enter a valid 10-digit phone number.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Expertise Tag
              AppTextField(
                controller: _tagController,
                label: 'Expertise Tag',
                hint: 'e.g. Bathymetry, DGPS',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Expertise tag is required.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),

              // Active Status Toggle
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Account Active',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Member can log in and receive assignments.'
                        : 'Member cannot log in or receive new assignments.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _isActive,
                  onChanged: isSubmitting
                      ? null
                      : (val) => setState(() => _isActive = val),
                ),
              ),
              SizedBox(height: 24.h),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Save Changes',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
