import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';
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

class MyBookingsViewModel extends AsyncNotifier<List<Appointment>> {
  @override
  Future<List<Appointment>> build() async {
    final user = ref.watch(authViewModelProvider).value;
    if (user == null) return [];

    final statusFilter = ref.watch(myBookingsStatusFilterProvider);
    final repo = ref.watch(appointmentRepositoryProvider);

    return repo.getBookingsForApplicant(user.uid, statusFilter: statusFilter);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> submitClarificationReply(
    String appointmentId,
    String replyText,
  ) async {
    final repo = ref.watch(appointmentRepositoryProvider);
    await repo.submitClarificationReply(appointmentId, replyText);
    await refresh();
  }
}
