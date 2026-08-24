import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

final adminAppointmentDetailStreamProvider =
    StreamProvider.family<Appointment?, String>((ref, id) {
      return ref.watch(appointmentRepositoryProvider).watchAppointmentById(id);
    });

final adminAppointmentDetailControllerProvider = Provider(
  (ref) => AdminAppointmentDetailController(ref),
);

class AdminAppointmentDetailController {
  final Ref ref;

  AdminAppointmentDetailController(this.ref);

  void _checkAdminRights() {
    final authState = ref.read(authViewModelProvider);
    if (authState.value?.isAdmin != true) {
      throw const AuthFailure('Admin access required.');
    }
  }

  Future<void> assignReviewer(
    String appointmentId,
    String reviewerId,
    String reviewerName,
  ) async {
    _checkAdminRights();
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.assignReviewer(appointmentId, reviewerId, reviewerName);
    } catch (e) {
      throw ServerFailure('Failed to assign reviewer: $e');
    }
  }

  Future<void> setConfirmedDate(String appointmentId, DateTime date) async {
    _checkAdminRights();
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.setConfirmedDate(appointmentId, date);
    } catch (e) {
      throw ServerFailure('Failed to set confirmed date: $e');
    }
  }

  Future<void> assignFieldworkTask(
    String appointmentId,
    String memberId,
    String memberName,
  ) async {
    _checkAdminRights();
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.assignFieldworkTask(appointmentId, memberId, memberName);
    } catch (e) {
      throw ServerFailure('Failed to assign task: $e');
    }
  }
}
