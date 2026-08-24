import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';

class AdminDashboardState {
  final AsyncValue<List<Appointment>> appointments;
  final String? statusFilter;
  final String? surveyTypeFilter;

  const AdminDashboardState({
    required this.appointments,
    this.statusFilter,
    this.surveyTypeFilter,
  });

  AdminDashboardState copyWith({
    AsyncValue<List<Appointment>>? appointments,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? surveyTypeFilter,
    bool clearSurveyTypeFilter = false,
  }) {
    return AdminDashboardState(
      appointments: appointments ?? this.appointments,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      surveyTypeFilter: clearSurveyTypeFilter
          ? null
          : (surveyTypeFilter ?? this.surveyTypeFilter),
    );
  }

  // Helper getters for stats
  int get totalCount => appointments.value?.length ?? 0;

  int get pendingCount =>
      appointments.value
          ?.where((a) => a.status.code == 'pending_assignment')
          .length ??
      0;

  int get underReviewCount =>
      appointments.value
          ?.where((a) => a.status.code == 'under_review')
          .length ??
      0;
}

final adminDashboardViewModelProvider =
    NotifierProvider<AdminDashboardViewModel, AdminDashboardState>(() {
      return AdminDashboardViewModel();
    });

class AdminDashboardViewModel extends Notifier<AdminDashboardState> {
  StreamSubscription<List<Appointment>>? _subscription;

  @override
  AdminDashboardState build() {
    Future.microtask(() => _initStream());
    return const AdminDashboardState(appointments: AsyncLoading());
  }

  void _initStream() {
    _subscription?.cancel();

    final repo = ref.read(appointmentRepositoryProvider);
    state = state.copyWith(appointments: const AsyncLoading());

    _subscription = repo
        .watchAdminDashboardAppointments(
          statusFilter: state.statusFilter,
          surveyTypeFilter: state.surveyTypeFilter,
        )
        .listen(
          (data) {
            state = state.copyWith(appointments: AsyncData(data));
          },
          onError: (error, stackTrace) {
            state = state.copyWith(appointments: AsyncError(error, stackTrace));
          },
        );
  }

  void setStatusFilter(String? filter) {
    if (filter == 'All' || filter == null || filter.isEmpty) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: filter);
    }
    _initStream();
  }

  void setSurveyTypeFilter(String? filter) {
    if (filter == 'All' || filter == null || filter.isEmpty) {
      state = state.copyWith(clearSurveyTypeFilter: true);
    } else {
      state = state.copyWith(surveyTypeFilter: filter);
    }
    _initStream();
  }

  // Dispose logic should be handled using ref.onDispose in build()
}
