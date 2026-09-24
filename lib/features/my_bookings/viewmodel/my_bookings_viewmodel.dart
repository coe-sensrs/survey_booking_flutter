import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
import '../../applicant_home/viewmodel/home_viewmodel.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

class MyBookingsStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? filter) {
    state = filter;
  }
}

final myBookingsStatusFilterProvider =
    NotifierProvider<MyBookingsStatusFilterNotifier, String?>(
      MyBookingsStatusFilterNotifier.new,
    );

final myBookingsViewModelProvider =
    AsyncNotifierProvider<MyBookingsViewModel, List<Appointment>>(() {
      return MyBookingsViewModel();
    });

final applicantAppointmentDetailStreamProvider = StreamProvider.autoDispose
    .family<Appointment?, String>((ref, id) {
      if (id.isEmpty) return Stream.value(null);
      final repo = ref.watch(appointmentRepositoryProvider);
      return repo.watchAppointmentById(id);
    });

class MyBookingsViewModel extends AsyncNotifier<List<Appointment>> {
  Future<List<Appointment>> _fetchBookings(
    String uid,
    String? statusFilter,
  ) async {
    final repo = ref.read(appointmentRepositoryProvider);
    return repo.getBookingsForApplicant(uid, statusFilter: statusFilter);
  }

  @override
  Future<List<Appointment>> build() async {
    final user = await ref.watch(authViewModelProvider.future);
    if (user == null) return [];

    final statusFilter = ref.watch(myBookingsStatusFilterProvider);
    return _fetchBookings(user.uid, statusFilter);
  }

  Future<void> refresh() async {
    final user = ref.read(authViewModelProvider).value;
    if (user == null) return;

    final statusFilter = ref.read(myBookingsStatusFilterProvider);
    state = await AsyncValue.guard(() => _fetchBookings(user.uid, statusFilter));
  }

  Future<void> submitClarificationReply(
    String appointmentId,
    String replyText,
  ) async {
    final repo = ref.read(appointmentRepositoryProvider);
    await repo.submitClarificationReply(appointmentId, replyText);
    // Invalidate home dashboard so badges refresh immediately
    ref.invalidate(homeViewModelProvider);
    await refresh();
  }
}
