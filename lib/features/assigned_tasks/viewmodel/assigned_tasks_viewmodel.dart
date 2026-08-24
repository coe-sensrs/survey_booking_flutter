import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Streams appointments where the committee member is the assigned fieldwork executor.
/// autoDispose ensures the stream is cancelled when the widget is disposed.
final assignedTasksStreamProvider =
    StreamProvider.autoDispose<List<Appointment>>((ref) {
      final authState = ref.watch(authViewModelProvider);
      final uid = authState.value?.uid;

      if (uid == null) return const Stream.empty();

      return ref
          .watch(appointmentRepositoryProvider)
          .watchCommitteeAssignedTasks(uid);
    });
