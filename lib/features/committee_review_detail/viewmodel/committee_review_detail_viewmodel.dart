import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../committee_dashboard/viewmodel/committee_dashboard_viewmodel.dart';

// ---------------------------------------------------------------------------
// Live stream of a single appointment (autoDispose = cancels on screen close)
// ---------------------------------------------------------------------------
final committeeReviewDetailStreamProvider = StreamProvider.autoDispose
    .family<Appointment?, String>((ref, id) {
      return ref.watch(appointmentRepositoryProvider).watchAppointmentById(id);
    });

// ---------------------------------------------------------------------------
// Controller — enforces committee-only access before any mutation
// ---------------------------------------------------------------------------
final committeeReviewDetailControllerProvider = Provider.autoDispose(
  (ref) => CommitteeReviewDetailController(ref),
);

class CommitteeReviewDetailController {
  final Ref ref;
  CommitteeReviewDetailController(this.ref);

  // --------------------------------------------------------------------------
  // Security guard: only the assigned reviewer may act.
  // --------------------------------------------------------------------------
  void _checkReviewerRights(Appointment appointment) {
    final authState = ref.read(authViewModelProvider);
    final uid = authState.value?.uid;
    final role = authState.value?.role;

    if (uid == null || role != 'committee') {
      throw const AuthFailure('Committee access required.');
    }

    // Verify this member is the assigned reviewer for this specific appointment.
    if (appointment.assignedReviewerId != uid) {
      throw const AuthFailure(
        'You are not the assigned reviewer for this appointment.',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Translate FirebaseFunctionsException → domain Failure for clean UI errors.
  // --------------------------------------------------------------------------
  Never _translateFunctionError(FirebaseFunctionsException e, String context) {
    switch (e.code) {
      case 'permission-denied':
        throw AuthFailure(e.message ?? 'Permission denied.');
      case 'unauthenticated':
        throw const AuthFailure(
          'Your session has expired. Please log in again.',
        );
      case 'failed-precondition':
        throw ValidationFailure(
          e.message ?? 'Action not allowed in current state.',
        );
      case 'invalid-argument':
        throw ValidationFailure(e.message ?? 'Invalid data provided.');
      case 'not-found':
        throw ServerFailure(e.message ?? 'Appointment not found.');
      default:
        throw ServerFailure('$context: ${e.message ?? e.code}');
    }
  }

  Future<void> approve(Appointment appointment) async {
    _checkReviewerRights(appointment);
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .reviewAppointment(appointmentId: appointment.id, action: 'approve');
      // Invalidate dashboard so the resolved appointment moves to "Resolved" immediately
      ref.invalidate(committeeDashboardStreamProvider);
      await ref
          .read(analyticsServiceProvider)
          .logReviewActionTaken(action: 'approve');
    } on AuthFailure {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      _translateFunctionError(e, 'Approve failed');
    } catch (e, st) {
      ref
          .read(crashReportingServiceProvider)
          .recordError(e, st, reason: 'approve failed', fatal: false);
      throw ServerFailure('Failed to approve appointment: $e');
    }
  }

  Future<void> reject(Appointment appointment, String reason) async {
    _checkReviewerRights(appointment);
    if (reason.trim().isEmpty) {
      throw const ValidationFailure('Rejection reason is required.');
    }
    if (reason.trim().length > 500) {
      throw const ValidationFailure(
        'Rejection reason must be under 500 characters.',
      );
    }
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .reviewAppointment(
            appointmentId: appointment.id,
            action: 'reject',
            reasonOrNote: reason.trim(),
          );
      // Invalidate dashboard so the resolved appointment moves to "Resolved" immediately
      ref.invalidate(committeeDashboardStreamProvider);
      await ref
          .read(analyticsServiceProvider)
          .logReviewActionTaken(action: 'reject');
    } on AuthFailure {
      rethrow;
    } on ValidationFailure {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      _translateFunctionError(e, 'Reject failed');
    } catch (e, st) {
      ref
          .read(crashReportingServiceProvider)
          .recordError(e, st, reason: 'reject failed', fatal: false);
      throw ServerFailure('Failed to reject appointment: $e');
    }
  }

  Future<void> requestClarification(
    Appointment appointment,
    String note,
  ) async {
    _checkReviewerRights(appointment);

    // PRD: block only when a clarification is *pending* (no reply yet).
    // Once the applicant has replied, the reviewer may clarify again.
    final isPendingClarification =
        appointment.clarificationNote != null &&
        appointment.clarificationNote!.isNotEmpty &&
        (appointment.clarificationReply == null ||
            appointment.clarificationReply!.isEmpty);
    if (isPendingClarification) {
      throw const ValidationFailure(
        'Clarification has already been requested. '
        'Waiting for the applicant\'s reply before you can act again.',
      );
    }

    if (note.trim().isEmpty) {
      throw const ValidationFailure('Clarification note is required.');
    }
    if (note.trim().length > 500) {
      throw const ValidationFailure(
        'Clarification note must be under 500 characters.',
      );
    }
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .reviewAppointment(
            appointmentId: appointment.id,
            action: 'clarify',
            reasonOrNote: note.trim(),
          );
      await ref
          .read(analyticsServiceProvider)
          .logReviewActionTaken(action: 'clarify');
    } on AuthFailure {
      rethrow;
    } on ValidationFailure {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      _translateFunctionError(e, 'Request clarification failed');
    } catch (e, st) {
      ref
          .read(crashReportingServiceProvider)
          .recordError(
            e,
            st,
            reason: 'requestClarification failed',
            fatal: false,
          );
      throw ServerFailure('Failed to request clarification: $e');
    }
  }

  /// Whether clarification can still be requested on this appointment.
  /// Returns false only when a clarification is *pending* (no applicant reply yet).
  /// Once the applicant replies, the reviewer may clarify again — matching CF logic.
  bool canRequestClarification(Appointment appointment) {
    // No prior clarification → always allowed.
    if (appointment.clarificationNote == null ||
        appointment.clarificationNote!.isEmpty) {
      return true;
    }
    // A clarification was sent. Block only while waiting for the applicant's reply.
    final hasReply =
        appointment.clarificationReply != null &&
        appointment.clarificationReply!.isNotEmpty;
    return hasReply;
  }
}
