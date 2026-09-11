import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:survey_desk/core/errors/failures.dart';
import 'package:survey_desk/core/routing/app_router.dart';
import 'package:survey_desk/core/utils/app_snackbar.dart';
import 'package:survey_desk/core/utils/sanitizing_text_input_formatter.dart';
import 'package:survey_desk/core/utils/validators.dart';
import 'package:survey_desk/core/widgets/app_button.dart';
import 'package:survey_desk/core/widgets/app_text_field.dart';
import 'package:survey_desk/features/auth/viewmodel/auth_viewmodel.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// Seconds remaining in the server-enforced login lockout.
  int _loginLockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ref
          .read(authViewModelProvider.notifier)
          .loginAdmin(_emailController.text, _passwordController.text);
    }
  }

  void _startLoginLockout(int seconds) {
    setState(() => _loginLockoutSeconds = seconds);
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _loginLockoutSeconds--;
        if (_loginLockoutSeconds <= 0) timer.cancel();
      });
    });
  }

  bool get _isLoginLocked => _loginLockoutSeconds > 0;

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes so we can navigate immediately on success
    // and show an error snackbar on failure — both without relying solely on
    // the router redirect (which has an async Firestore round-trip).
    ref.listen(authViewModelProvider, (previous, next) {
      if (next is AsyncError) {
        final error = next.error;
        if (error is AuthRateLimitFailure) {
          final secs = error.secondsRemaining;
          if (secs != null && secs > 0) _startLoginLockout(secs);
          AppSnackbar.showError(
            context,
            title: 'Account Locked',
            message: error.message,
          );
        } else {
          AppSnackbar.showError(
            context,
            title: 'Login Failed',
            message: next.error.toString(),
          );
        }
        return;
      }

      // Navigate to the correct role-based shell as soon as we have a confirmed admin user.
      if (next is AsyncData) {
        final user = next.value;
        if (user != null && user.isAdmin) {
          context.go(AppRoutes.adminDashboard);
        }
      }
    });

    final authState = ref.watch(authViewModelProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Admin Login'),
        elevation: 0,
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: Center(
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
                    Text(
                      'Admin Portal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      label: 'Email Address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        SanitizingTextInputFormatter(),
                        LengthLimitingTextInputFormatter(54),
                      ],
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      inputFormatters: [
                        SanitizingTextInputFormatter(),
                        LengthLimitingTextInputFormatter(64),
                      ],
                      validator: (val) =>
                          Validators.validateRequired(val, 'Password'),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      text: _isLoginLocked
                          ? 'Locked (${_loginLockoutSeconds}s)'
                          : 'Login',
                      isLoading: isLoading,
                      onPressed: (_isLoginLocked || isLoading) ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
