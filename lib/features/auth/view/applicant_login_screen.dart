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

class ApplicantLoginScreen extends ConsumerStatefulWidget {
  const ApplicantLoginScreen({super.key});

  @override
  ConsumerState<ApplicantLoginScreen> createState() =>
      _ApplicantLoginScreenState();
}

class _ApplicantLoginScreenState extends ConsumerState<ApplicantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await ref
            .read(authViewModelProvider.notifier)
            .loginApplicant(_emailController.text, _passwordController.text);
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
          title: 'Login Failed',
          message: next.error.toString(),
        );
      }
    });

    final authState = ref.watch(authViewModelProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Applicant Login',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AppTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [SanitizingTextInputFormatter()],
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    inputFormatters: [SanitizingTextInputFormatter()],
                    validator: (val) =>
                        Validators.validateRequired(val, 'Password'),
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        if (_emailController.text.isNotEmpty) {
                          ref
                              .read(authViewModelProvider.notifier)
                              .resetPassword(_emailController.text);
                          AppSnackbar.showSuccess(
                            context,
                            title: 'Password Reset',
                            message:
                                'Password reset email sent (if account exists).',
                          );
                        } else {
                          AppSnackbar.showWarning(
                            context,
                            title: 'Email Required',
                            message: 'Please enter your email address first.',
                          );
                        }
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Login',
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.signup),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.adminLogin),
                    child: const Text('Admin / Committee Login'),
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
