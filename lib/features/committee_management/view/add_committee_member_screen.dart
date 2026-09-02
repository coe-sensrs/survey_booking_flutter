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

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _expertiseController.clear();
    _formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
  }

  void _onCancel() {
    _clearForm();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.adminCommitteeManagement);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final expertise = _expertiseController.text.trim();

    try {
      final credentials = await ref
          .read(committeeManagementViewModelProvider.notifier)
          .createCommitteeMember(
            name: name,
            email: email,
            phone: phone,
            expertiseTag: expertise,
          );

      if (!mounted) return;

      // Freeze loading state before showing dialog so button doesn't flash
      setState(() => _isLoading = false);

      final tempPassword =
          credentials['tempPassword'] as String? ?? '(not available)';

      await _showCredentialsDialog(
        name: name,
        email: email,
        tempPassword: tempPassword,
      );

      // After dialog is dismissed — clear form and go back
      if (!mounted) return;
      _clearForm();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.adminCommitteeManagement);
      }
    } on Failure catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, title: 'Error', message: e.message);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        title: 'Error',
        message: 'An unexpected error occurred.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCredentialsDialog({
    required String name,
    required String email,
    required String tempPassword,
  }) {
    final credentialText =
        'Name: $name\nEmail: $email\nTemporary Password: $tempPassword';

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Force admin to acknowledge before leaving
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.verified_user_outlined,
          color: Theme.of(ctx).colorScheme.primary,
          size: 40,
        ),
        title: const Text('Account Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share these one-time credentials with the new committee member. '
              'They can change their password after first login.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _CredentialRow(label: 'Name', value: name),
            const SizedBox(height: 8),
            _CredentialRow(label: 'Email', value: email),
            const SizedBox(height: 8),
            _CredentialRow(label: 'Temp Password', value: tempPassword),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: credentialText));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Credentials copied!')),
              );
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
                      onPressed: _isLoading ? null : _onCancel,
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

/// A single labeled credential row used inside the credentials dialog.
class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
