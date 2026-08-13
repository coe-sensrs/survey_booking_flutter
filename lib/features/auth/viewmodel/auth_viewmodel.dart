import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:survey_desk/core/errors/failures.dart';
import 'package:survey_desk/core/models/app_user.dart';
import 'package:survey_desk/core/repositories/user_repository.dart';
import 'package:survey_desk/core/providers/core_providers.dart';

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

  @override
  FutureOr<AppUser?> build() async {
    _firebaseAuth = auth.FirebaseAuth.instance;
    _userRepository = ref.watch(userRepositoryProvider);

    // Listen to auth state changes
    final completer = Completer<AppUser?>();
    _firebaseAuth.authStateChanges().listen((user) async {
      if (user == null) {
        state = const AsyncData(null);
        if (!completer.isCompleted) completer.complete(null);
      } else {
        try {
          final appUser = await _userRepository.getUserById(user.uid);
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
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null && !user.emailVerified) {
        // Keep session alive so verification screen can call user.reload() / resend.
        // Signal the UI to navigate to the email verification screen.
        state = const AsyncData(null);
        throw EmailNotVerifiedException(email);
      }

      if (user != null) {
        final appUser = await _userRepository.getUserById(user.uid);
        if (appUser == null || !appUser.isApplicant) {
          await _firebaseAuth.signOut();
          state = const AsyncError(
            AuthFailure('Invalid role for applicant login.'),
            StackTrace.empty,
          );
          return;
        }
      }
    } on EmailNotVerifiedException {
      rethrow;
    } on auth.FirebaseAuthException catch (e) {
      state = AsyncError(_handleAuthException(e), StackTrace.current);
    } catch (e) {
      state = AsyncError(const ServerFailure(), StackTrace.current);
    }
  }

  Future<void> loginAdmin(String email, String password) async {
    state = const AsyncLoading();
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        final appUser = await _userRepository.getUserById(user.uid);
        if (appUser == null || (!appUser.isAdmin && !appUser.isCommittee)) {
          await _firebaseAuth.signOut();
          state = const AsyncError(
            AuthFailure('Unauthorized access.'),
            StackTrace.empty,
          );
          return;
        }
      }
    } on auth.FirebaseAuthException catch (e) {
      state = AsyncError(_handleAuthException(e), StackTrace.current);
    } catch (e) {
      state = AsyncError(const ServerFailure(), StackTrace.current);
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
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.sendEmailVerification();

        final newAppUser = AppUser(
          uid: user.uid,
          role: 'applicant',
          fullName: fullName.trim(),
          email: email.trim(),
          phone: phone.trim(),
          orgName: orgName?.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        try {
          await _userRepository.createUser(newAppUser);
        } catch (_) {
          // Firestore write failed — delete the Auth user to prevent an orphaned account
          // that would otherwise block re-registration with the same email.
          await user.delete();
          state = AsyncError(
            const ServerFailure('Account creation failed. Please try again.'),
            StackTrace.current,
          );
          return;
        }

        // Keep session alive so the verification screen can call user.reload().
        state = const AsyncData(null);
        throw EmailNotVerifiedException(email.trim());
      }
    } on EmailNotVerifiedException {
      rethrow;
    } on auth.FirebaseAuthException catch (e) {
      state = AsyncError(_handleAuthException(e), StackTrace.current);
    } catch (e) {
      state = AsyncError(const ServerFailure(), StackTrace.current);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sends a verification email using the currently signed-in Firebase session.
  /// Called from [EmailVerificationScreen] after signup or a failed login.
  Future<void> sendVerificationEmailToCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null)
      throw const AuthFailure('No active session. Please log in again.');
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

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    state = const AsyncData(null);
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
