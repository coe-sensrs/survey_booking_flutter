import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:survey_desk/core/routing/app_router.dart';
import 'package:survey_desk/core/utils/app_snackbar.dart';
import 'package:survey_desk/core/widgets/app_button.dart';
import 'package:survey_desk/features/auth/viewmodel/auth_viewmodel.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isCheckingStatus = false;
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldownSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          AppSnackbar.showInfo(
            context,
            title: 'Session Expired',
            message: 'Please log in to check your verification status.',
          );
          context.go(AppRoutes.login);
        }
        return;
      }
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            title: 'Email Verified!',
            message: 'Your email is verified. Please log in.',
          );
          context.go(AppRoutes.login);
        }
      } else {
        if (mounted) {
          AppSnackbar.showWarning(
            context,
            title: 'Not Yet Verified',
            message:
                'Email not verified yet. Check your inbox and spam folder.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Error',
          message: 'Could not check status. Please try logging in directly.',
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .sendVerificationEmailToCurrentUser();
      if (mounted) {
        _startCooldown();
        AppSnackbar.showSuccess(
          context,
          title: 'Email Sent',
          message:
              'A fresh verification email was sent to ${widget.email}. Check your inbox and spam folder.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Failed to Resend',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify Your Email',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A verification link was sent to:',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your inbox and spam/junk folder, then click the link to verify your account.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    text: 'Check Verification Status',
                    isLoading: _isCheckingStatus,
                    onPressed: (_isCheckingStatus || _isResending)
                        ? null
                        : _checkVerificationStatus,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed:
                        (_isResending ||
                            _isCheckingStatus ||
                            _cooldownSeconds > 0)
                        ? null
                        : _resendVerificationEmail,
                    child: _isResending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _cooldownSeconds > 0
                                ? 'Resend in ${_cooldownSeconds}s'
                                : 'Resend Verification Email',
                          ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Already Verified? Login'),
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
