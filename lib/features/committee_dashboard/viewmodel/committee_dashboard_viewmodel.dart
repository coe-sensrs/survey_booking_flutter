import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Streams appointments assigned to the current committee member for review.
/// The [StreamProvider] automatically cancels when the widget is disposed,
/// preventing memory leaks on logout.
final committeeDashboardStreamProvider =
    StreamProvider.autoDispose<List<Appointment>>((ref) {
      final authState = ref.watch(authViewModelProvider);
      final uid = authState.value?.uid;

      // Guard: if not authenticated, return empty stream
      if (uid == null) return const Stream.empty();

      return ref
          .watch(appointmentRepositoryProvider)
          .watchCommitteeReviewAppointments(uid);
    });
