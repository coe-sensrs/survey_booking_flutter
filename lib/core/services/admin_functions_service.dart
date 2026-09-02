import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/viewmodel/auth_viewmodel.dart';
import '../errors/failures.dart';

final adminFunctionsServiceProvider = Provider<AdminFunctionsService>((ref) {
  return AdminFunctionsService(ref);
});

/// A dedicated service wrapper for calling Admin Cloud Functions.
/// Handles pre-flight claim checks, forces token refreshes to avoid stale
/// unauthenticated errors, and translates Cloud Function exceptions cleanly.
class AdminFunctionsService {
  final Ref _ref;

  AdminFunctionsService(this._ref);

  Future<T> callAdminFunction<T>({
    required String functionName,
    required Map<String, dynamic> data,
  }) async {
    // 1. Verify local auth state claims (pre-flight check)
    final authState = _ref.read(authViewModelProvider);
    if (authState.value?.isAdmin != true) {
      throw const AuthFailure('Only administrators can perform this action.');
    }

    // 2. Force token refresh to ensure a valid session token is sent.
    // This prevents edge cases where the token is stale and the backend throws 'unauthenticated'.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const AuthFailure(
          'Local session is missing. Please log in again.',
        );
      }
      await user.getIdToken(true);
    } catch (e) {
      throw const AuthFailure(
        'Session expired or missing. Please log in again.',
      );
    }

    // 3. Execute function
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(functionName);
      final result = await callable.call<T>(data);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // 4. Graceful error translation
      switch (e.code) {
        case 'already-exists':
          throw ValidationFailure(e.message ?? 'Record already exists.');
        case 'not-found':
          throw const ServerFailure(
            'Service not found. Please ensure the Cloud Function is deployed.',
          );
        case 'permission-denied':
          throw const AuthFailure(
            'You do not have permission to perform this action.',
          );
        case 'unauthenticated':
          throw const AuthFailure(
            'You must be logged in to perform this action.',
          );
        case 'invalid-argument':
          throw ValidationFailure(
            e.message ?? 'Invalid data provided to the server.',
          );
        case 'unavailable':
        case 'deadline-exceeded':
        case 'internal':
          throw const NetworkFailure();
        default:
          throw ServerFailure(
            e.message ?? 'An unexpected error occurred.',
            e.code,
          );
      }
    } catch (e) {
      throw ServerFailure('An unexpected error occurred: $e');
    }
  }
}
