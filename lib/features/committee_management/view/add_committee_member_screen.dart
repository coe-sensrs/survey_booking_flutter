import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:survey_desk/core/routing/app_router.dart';
import 'package:survey_desk/core/utils/app_snackbar.dart';
import 'package:survey_desk/core/utils/sanitizing_text_input_formatter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/validators.dart';
import '../viewmodel/committee_management_viewmodel.dart';

class AddCommitteeMemberScreen extends ConsumerStatefulWidget {
  const AddCommitteeMemberScreen({super.key});

  @override
  ConsumerState<AddCommitteeMemberScreen> createState() =>
      _AddCommitteeMemberScreenState();
}

class _AddCommitteeMemberScreenState
    extends ConsumerState<AddCommitteeMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _expertiseController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _expertiseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(committeeManagementViewModelProvider.notifier)
          .createCommitteeMember(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            expertiseTag: _expertiseController.text.trim(),
          );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          title: 'Success',
          message: 'Committee member added successfully.',
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.adminCommitteeManagement);
        }
      }
    } on Failure catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, title: 'Error', message: e.message);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Error',
          message: 'An unexpected error occurred.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Member')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Your Name',
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  SanitizingTextInputFormatter(),
                  LengthLimitingTextInputFormatter(54),
                ],
                validator: (value) =>
                    Validators.validateRequired(value, 'Full name'),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Your Email',
                ),
                inputFormatters: [
                  SanitizingTextInputFormatter(),
                  LengthLimitingTextInputFormatter(54),
                ],
                keyboardType: TextInputType.emailAddress,
                validator: Validators.validateEmail,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Your Phone Number',
                ),
                inputFormatters: [
                  SanitizingTextInputFormatter(),
                  LengthLimitingTextInputFormatter(10),
                ],
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhone,
              ),
              SizedBox(height: 32.h),
              Text(
                'Committee Allocation',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _expertiseController,
                decoration: const InputDecoration(
                  labelText: 'Role / Expertise Description',
                  hintText: 'Briefly describe specific expertise...',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  SanitizingTextInputFormatter(),
                  LengthLimitingTextInputFormatter(150),
                ],
                validator: (value) =>
                    Validators.validateRequired(value, 'Expertise description'),
              ),
              SizedBox(height: 40.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isLoading ? 'Adding...' : 'Add Member'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
