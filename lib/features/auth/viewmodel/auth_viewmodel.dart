import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:survey_desk/core/errors/failures.dart';
import 'package:survey_desk/core/models/app_user.dart';
import 'package:survey_desk/core/repositories/user_repository.dart';
import 'package:survey_desk/core/providers/core_providers.dart';
import 'package:survey_desk/core/services/auth_functions_service.dart';
import 'package:survey_desk/core/services/hive_storage_service.dart';
import 'package:survey_desk/core/utils/app_snackbar.dart';

/// Thrown when a user attempts to log in before verifying their email.
/// Contains the [email] so the UI can pass it to the verification screen.
class EmailNotVerifiedException implements Exception {
  final String email;
  const EmailNotVerifiedException(this.email);
}

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, AppUser?>(
  () {
    return AuthViewModel();
  },
);

class AuthViewModel extends AsyncNotifier<AppUser?> {
  late auth.FirebaseAuth _firebaseAuth;
  late UserRepository _userRepository;
  String? _previousUid; // tracks previous user for FCM token migration

  @override
  FutureOr<AppUser?> build() async {
    _firebaseAuth = auth.FirebaseAuth.instance;
    _userRepository = ref.watch(userRepositoryProvider);

    // Listen to user changes (fires on token refresh, profile updates, sign-out).
    final completer = Completer<AppUser?>();
    _firebaseAuth.userChanges().listen((user) async {
      if (user == null) {
        // On sign-out, unregister the FCM token from the previous user.
        if (_previousUid != null) {
          final notifService = ref.read(notificationServiceProvider);
          await notifService.unregisterToken(_previousUid!);
          _previousUid = null;
        }
        ref.read(crashReportingServiceProvider).setCustomKey('role', 'none');
        ref.read(crashReportingServiceProvider).setCustomKey('user_id', 'none');
        ref.read(crashReportingServiceProvider).setUserIdentifier('');
        ref.read(analyticsServiceProvider).setUserId(null);
        ref
            .read(analyticsServiceProvider)
            .setUserProperty(name: 'role', value: 'none');
        state = const AsyncData(null);
        if (!completer.isCompleted) completer.complete(null);
      } else {
        try {
          final appUser = await _userRepository.getUserById(user.uid);

          if (appUser != null && appUser.active == false) {
            await _forceSignOut(
              'Your account has been deactivated. Please contact your administrator.',
            );
            return;
          }

          // FCM token lifecycle: migrate token from previous user if account switched.
          final notifService = ref.read(notificationServiceProvider);
          if (_previousUid != null && _previousUid != user.uid) {
            await notifService.unregisterToken(_previousUid!);
          }
          await notifService.registerToken(user.uid);
          _previousUid = user.uid;

          if (appUser != null) {
            ref
                .read(crashReportingServiceProvider)
                .setCustomKey('role', appUser.role);
            ref
                .read(crashReportingServiceProvider)
                .setCustomKey('user_id', appUser.uid);
            ref
                .read(crashReportingServiceProvider)
                .setUserIdentifier(appUser.uid);
            ref.read(analyticsServiceProvider).setUserId(appUser.uid);
            ref
                .read(analyticsServiceProvider)
                .setUserProperty(name: 'role', value: appUser.role);
          }

          state = AsyncData(appUser);
          if (!completer.isCompleted) completer.complete(appUser);
        } catch (e) {
          state = AsyncError(_handleAuthException(e), StackTrace.current);
          if (!completer.isCompleted) completer.completeError(e);
        }
      }
    });
    return completer.future;
  }

  Future<void> loginApplicant(String email, String password) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authFunctionsServiceProvider);
      final result = await authService.authenticateUser(
        email: email,
        password: password,
        requiredRole: 'applicant',
      );

      // Sign in with the server-issued custom token to establish a Firebase session.
      await _firebaseAuth.signInWithCustomToken(result.customToken);
      await ref.read(analyticsServiceProvider).logLogin(loginMethod: 'email');

      if (!result.emailVerified) {
        // Override stream state — keep null so the auth guard does not redirect to home.
        // The verification screen will call user.reload() to poll for confirmation.
        state = const AsyncData(null);
        throw EmailNotVerifiedException(email.trim());
      }
      // userChanges() stream will fire and update state to AsyncData(appUser).
    } on EmailNotVerifiedException {
      rethrow;
    } catch (e) {
      if (e is Failure) {
        state = AsyncError(e, StackTrace.current);
      } else {
        ref
            .read(crashReportingServiceProvider)
            .recordError(
              e,
              StackTrace.current,
              reason: 'loginApplicant failed',
              fatal: false,
            );
        state = AsyncError(const ServerFailure(), StackTrace.current);
      }
    }
  }

  Future<void> loginAdmin(String email, String password) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authFunctionsServiceProvider);
      final result = await authService.authenticateUser(
        email: email,
        password: password,
        requiredRole: 'admin',
      );

      // Sign in with the server-issued custom token to establish a Firebase session.
      await _firebaseAuth.signInWithCustomToken(result.customToken);
      await ref.read(analyticsServiceProvider).logLogin(loginMethod: 'email');
      // userChanges() stream will fire and update state to AsyncData(appUser).
    } catch (e) {
      if (e is Failure) {
        state = AsyncError(e, StackTrace.current);
      } else {
        ref
            .read(crashReportingServiceProvider)
            .recordError(
              e,
              StackTrace.current,
              reason: 'loginAdmin failed',
              fatal: false,
            );
        state = AsyncError(const ServerFailure(), StackTrace.current);
      }
    }
  }

  Future<void> signupApplicant({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? orgName,
  }) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authFunctionsServiceProvider);
      final result = await authService.registerApplicant(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        orgName: orgName,
      );

      // Sign in with the server-issued custom token to establish a Firebase session.
      await _firebaseAuth.signInWithCustomToken(result.customToken);
      await ref.read(analyticsServiceProvider).logSignUp(signUpMethod: 'email');

      // Trigger Firebase-branded verification email via the client SDK
      // (requires an active session, which we just established above).
      await _firebaseAuth.currentUser?.sendEmailVerification();

      // Override stream state — keep null so auth guard does not redirect to home.
      state = const AsyncData(null);
      throw EmailNotVerifiedException(result.email);
    } on EmailNotVerifiedException {
      rethrow;
    } catch (e) {
      if (e is Failure) {
        state = AsyncError(e, StackTrace.current);
      } else {
        ref
            .read(crashReportingServiceProvider)
            .recordError(
              e,
              StackTrace.current,
              reason: 'signupApplicant failed',
              fatal: false,
            );
        state = AsyncError(const ServerFailure(), StackTrace.current);
      }
    }
  }

  Future<void> resetPassword(String email) async {
    final authService = ref.read(authFunctionsServiceProvider);
    // Throws [AuthRateLimitFailure] if rate limit is exceeded;
    // throws [AuthFailure] / [ServerFailure] on other errors.
    await authService.requestPasswordReset(email.trim());
  }

  /// Sends a verification email using the currently signed-in Firebase session.
  /// Called from [EmailVerificationScreen] after signup or a failed login.
  Future<void> sendVerificationEmailToCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please log in again.');
    }
    try {
      await user.sendEmailVerification();
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw const AuthFailure(
          'Please wait a moment before requesting another verification email.',
        );
      }
      throw _handleAuthException(e);
    }
  }

  /// Validates the current Firebase session is still active.
  ///
  /// Call on app resume (`AppLifecycleState.resumed`) to detect externally
  /// revoked sessions (e.g. password reset on another device, admin suspension).
  /// If the session is invalid, signs out locally and shows a global alert.
  Future<void> validateCurrentSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      // After reload, if Firebase SDK cleared the user the stream handles it.

      // Proactively check if the user was deactivated in Firestore by an admin
      final appUser = await _userRepository.getUserById(user.uid);
      if (appUser != null && appUser.active == false) {
        await _forceSignOut(
          'Your account has been deactivated. Please contact your administrator.',
        );
        return;
      }
    } on auth.FirebaseAuthException catch (e) {
      // user-disabled, user-token-expired, user-not-found
      await _forceSignOut(
        e.code == 'user-disabled'
            ? 'Your account has been disabled. Contact support.'
            : 'Your session has expired. Please sign in again.',
      );
    } catch (_) {
      // Network errors are silently ignored — we'll retry on next resume.
    }
  }

  Future<void> logout() async {
    final currentUid = _firebaseAuth.currentUser?.uid;
    if (currentUid != null) {
      try {
        await ref.read(notificationServiceProvider).unregisterToken(currentUid);
      } catch (_) {}
      _previousUid = null;
    }
    await _firebaseAuth.signOut();
    await HiveStorageService.clearUserData();
    state = const AsyncData(null);
  }

  /// Signs out, clears local data, and shows a global warning snackbar.
  Future<void> _forceSignOut(String message) async {
    final currentUid = _firebaseAuth.currentUser?.uid;
    if (currentUid != null) {
      try {
        await ref.read(notificationServiceProvider).unregisterToken(currentUid);
      } catch (_) {}
      _previousUid = null;
    }
    await _firebaseAuth.signOut();
    await HiveStorageService.clearUserData();
    state = const AsyncData(null);
    AppSnackbar.showGlobalWarning(title: 'Session Ended', message: message);
  }

  Failure _handleAuthException(dynamic e) {
    if (e is auth.FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return const AuthFailure('Invalid email or password.');
        case 'email-already-in-use':
          return const AuthFailure(
            'An account with this email already exists. '
            'If you haven\'t verified your email yet, log in to resend the verification link.',
          );
        case 'weak-password':
          return const AuthFailure('The password provided is too weak.');
        case 'too-many-requests':
          return const AuthFailure(
            'Too many attempts. Please try again later.',
          );
        case 'network-request-failed':
          return const NetworkFailure();
        default:
          return AuthFailure(e.message ?? 'Authentication failed.');
      }
    }
    return const ServerFailure('An unknown error occurred.');
  }
}
