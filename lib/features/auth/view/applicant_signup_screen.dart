import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:survey_desk/core/routing/app_router.dart';
import 'package:survey_desk/core/utils/app_snackbar.dart';
import 'package:survey_desk/core/widgets/app_button.dart';
import 'package:survey_desk/core/widgets/app_text_field.dart';
import 'package:survey_desk/core/utils/validators.dart';
import 'package:survey_desk/core/utils/sanitizing_text_input_formatter.dart';
import 'package:survey_desk/features/auth/viewmodel/auth_viewmodel.dart';

class ApplicantSignupScreen extends ConsumerStatefulWidget {
  const ApplicantSignupScreen({super.key});

  @override
  ConsumerState<ApplicantSignupScreen> createState() =>
      _ApplicantSignupScreenState();
}

class _ApplicantSignupScreenState extends ConsumerState<ApplicantSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _orgController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await ref
            .read(authViewModelProvider.notifier)
            .signupApplicant(
              fullName: _nameController.text,
              email: _emailController.text,
              phone: _phoneController.text,
              password: _passwordController.text,
              orgName: _orgController.text.isNotEmpty
                  ? _orgController.text
                  : null,
            );
      } on EmailNotVerifiedException catch (e) {
        if (mounted) {
          context.go(
            '${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(e.email)}',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authViewModelProvider, (previous, next) {
      if (next is AsyncError) {
        AppSnackbar.showError(
          context,
          title: 'Signup Failed',
          message: next.error.toString(),
        );
      }
    });

    final authState = ref.watch(authViewModelProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    inputFormatters: [SanitizingTextInputFormatter()],
                    validator: (val) => Validators.validateRequired(
                      val,
                      'Full Name',
                      maxLength: 100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Organization Name (Optional)',
                    controller: _orgController,
                    inputFormatters: [SanitizingTextInputFormatter()],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [SanitizingTextInputFormatter()],
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [SanitizingTextInputFormatter()],
                    validator: Validators.validatePhone,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    inputFormatters: [SanitizingTextInputFormatter()],
                    validator: Validators.validatePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    text: 'Sign Up',
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
