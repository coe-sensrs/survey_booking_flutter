import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

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

    // Clarification guard: committee cannot request clarification twice.
    // The PRD states: "cannot request clarification a second time."
    // A clarificationReply already present means the applicant has replied,
    // so clarification is allowed (reviewer must Approve or Reject now).
    // If clarificationNote is set but no reply yet → block re-clarify.
    // UI should hide the Clarify button in this case — this is a server-side guard.
  }

  Future<void> approve(Appointment appointment) async {
    _checkReviewerRights(appointment);
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .reviewAppointment(appointmentId: appointment.id, action: 'approve');
    } on AuthFailure {
      rethrow;
    } catch (e) {
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
    } on AuthFailure {
      rethrow;
    } on ValidationFailure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Failed to reject appointment: $e');
    }
  }

  Future<void> requestClarification(
    Appointment appointment,
    String note,
  ) async {
    _checkReviewerRights(appointment);

    // PRD: cannot request clarification a second time.
    // If clarificationNote is set AND clarificationReply is null → second attempt, block.
    if (appointment.clarificationNote != null &&
        appointment.clarificationNote!.isNotEmpty &&
        (appointment.clarificationReply == null ||
            appointment.clarificationReply!.isEmpty)) {
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
    } on AuthFailure {
      rethrow;
    } on ValidationFailure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Failed to request clarification: $e');
    }
  }

  /// Whether clarification can still be requested on this appointment.
  /// Returns false if a clarification is pending (no applicant reply yet).
  bool canRequestClarification(Appointment appointment) {
    // No previous clarification → allowed
    if (appointment.clarificationNote == null ||
        appointment.clarificationNote!.isEmpty) {
      return true;
    }
    // Clarification was sent and applicant replied → allowed (reviewer must decide)
    if (appointment.clarificationReply != null &&
        appointment.clarificationReply!.isNotEmpty) {
      return false; // At this point they should Approve or Reject
    }
    // Clarification sent, awaiting reply → block re-request
    return false;
  }
}
