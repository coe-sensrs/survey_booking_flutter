import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failures.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/admin_functions_service.dart';
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

  /// Routes through [AdminFunctionsService] which force-refreshes the ID token
  /// before every call, translates [FirebaseFunctionsException] error codes into
  /// clean [Failure] objects, and preserves [Failure] subclasses on rethrow.
  Future<void> assignReviewer(
    String appointmentId,
    String reviewerId,
    String reviewerName,
  ) async {
    _checkAdminRights();
    try {
      await ref
          .read(adminFunctionsServiceProvider)
          .callAdminFunction<void>(
            functionName: 'assignReviewer',
            data: {
              'appointmentId': appointmentId,
              'reviewerId': reviewerId,
              'reviewerName': reviewerName,
            },
          );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Failed to assign reviewer: $e');
    }
  }

  Future<void> setConfirmedDate(String appointmentId, DateTime date) async {
    _checkAdminRights();
    try {
      await ref
          .read(adminFunctionsServiceProvider)
          .callAdminFunction<void>(
            functionName: 'setConfirmedDate',
            data: {
              'appointmentId': appointmentId,
              'confirmedDate': date.toIso8601String(),
            },
          );
    } on Failure {
      rethrow;
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
      await ref
          .read(adminFunctionsServiceProvider)
          .callAdminFunction<void>(
            functionName: 'assignFieldworkTask',
            data: {
              'appointmentId': appointmentId,
              'memberId': memberId,
              'memberName': memberName,
            },
          );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Failed to assign fieldwork task: $e');
    }
  }
}
