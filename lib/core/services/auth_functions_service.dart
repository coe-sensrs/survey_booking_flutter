import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:survey_desk/core/errors/failures.dart';

final authFunctionsServiceProvider = Provider<AuthFunctionsService>((ref) {
  return AuthFunctionsService();
});

/// Lightweight wrapper for unauthenticated Cloud Function calls used during
/// login, signup, and password reset.
///
/// Unlike [AdminFunctionsService], this service requires no pre-flight auth
/// check — the caller is unauthenticated by definition.
class AuthFunctionsService {
  final _functions = FirebaseFunctions.instance;

  // ============================================================
  // Public methods
  // ============================================================

  /// Authenticates the user via the `authenticateUser` Cloud Function.
  ///
  /// The server verifies credentials, enforces rate limits, and returns a
  /// Firebase Custom Token + the user's role. The caller must then sign in
  /// with [FirebaseAuth.signInWithCustomToken].
  Future<AuthResult> authenticateUser({
    required String email,
    required String password,
    required String requiredRole,
  }) async {
    try {
      final callable = _functions.httpsCallable('authenticateUser');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'email': email,
        'password': password,
        'requiredRole': requiredRole,
      });
      final data = result.data;
      return AuthResult(
        customToken: data['customToken'] as String,
        role: data['role'] as String,
        emailVerified: data['emailVerified'] as bool? ?? true,
      );
    } on FirebaseFunctionsException catch (e) {
      throw _translateError(e);
    } catch (e) {
      throw ServerFailure('An unexpected error occurred: $e');
    }
  }

  /// Registers a new applicant via the `registerApplicant` Cloud Function.
  ///
  /// Returns a [customToken] to establish a Firebase session so the client
  /// can call [FirebaseAuth.currentUser.sendEmailVerification()].
  Future<RegisterResult> registerApplicant({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? orgName,
  }) async {
    try {
      final callable = _functions.httpsCallable('registerApplicant');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        if (orgName != null && orgName.isNotEmpty) 'orgName': orgName,
      });
      final data = result.data;
      return RegisterResult(
        customToken: data['customToken'] as String,
        email: data['email'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      throw _translateError(e);
    } catch (e) {
      throw ServerFailure('An unexpected error occurred: $e');
    }
  }

  /// Requests a password reset email via the `requestPasswordReset` Cloud
  /// Function. The server enforces a rate limit of 3 requests per email/hour.
  Future<void> requestPasswordReset(String email) async {
    try {
      final callable = _functions.httpsCallable('requestPasswordReset');
      await callable.call<void>({'email': email});
    } on FirebaseFunctionsException catch (e) {
      throw _translateError(e);
    } catch (e) {
      throw ServerFailure('An unexpected error occurred: $e');
    }
  }

  // ============================================================
  // Error translation
  // ============================================================

  Failure _translateError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'resource-exhausted':
        final details = e.details as Map<dynamic, dynamic>?;
        final seconds = details?['secondsRemaining'] as int?;
        return AuthRateLimitFailure(
          e.message ?? 'Too many attempts. Please try again later.',
          secondsRemaining: seconds,
        );
      case 'unauthenticated':
        return AuthFailure(e.message ?? 'Invalid email or password.');
      case 'permission-denied':
        return AuthFailure(
          e.message ?? 'You are not authorized to perform this action.',
        );
      case 'already-exists':
        return AuthFailure(
          e.message ?? 'An account with this email already exists.',
        );
      case 'not-found':
        return const AuthFailure(
          'User profile not found. Please contact support.',
        );
      case 'invalid-argument':
        return ValidationFailure(e.message ?? 'Invalid data provided.');
      case 'unavailable':
      case 'deadline-exceeded':
        return const NetworkFailure();
      default:
        return ServerFailure(
          e.message ?? 'An unexpected error occurred.',
          e.code,
        );
    }
  }
}

// ============================================================
// Return types
// ============================================================

class AuthResult {
  final String customToken;
  final String role;
  final bool emailVerified;

  const AuthResult({
    required this.customToken,
    required this.role,
    required this.emailVerified,
  });
}

class RegisterResult {
  final String customToken;
  final String email;

  const RegisterResult({required this.customToken, required this.email});
}
