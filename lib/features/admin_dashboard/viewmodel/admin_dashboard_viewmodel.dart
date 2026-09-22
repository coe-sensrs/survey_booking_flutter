import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as auth;
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
  bool _isDisposed = false;
  int _retryCount = 0;

  @override
  AdminDashboardState build() {
    _isDisposed = false;
    _retryCount = 0;

    ref.onDispose(() {
      _isDisposed = true;
      _subscription?.cancel();
    });

    Future.microtask(() => _initStream());
    return const AdminDashboardState(appointments: AsyncLoading());
  }

  Future<void> _initStream() async {
    _subscription?.cancel();

    final repo = ref.read(appointmentRepositoryProvider);
    state = state.copyWith(appointments: const AsyncLoading());

    // Ensure custom claims are active on the Firebase Auth token
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final idTokenResult = await currentUser.getIdTokenResult();
        if (idTokenResult.claims?['role'] != 'admin') {
          await currentUser.getIdToken(true);
        }
      } catch (_) {
        // Offline or token refresh failed, continue to query
      }
    }

    if (_isDisposed) return;

    _subscription = repo
        .watchAdminDashboardAppointments(
          statusFilter: state.statusFilter,
          surveyTypeFilter: state.surveyTypeFilter,
        )
        .listen(
          (data) {
            _retryCount = 0;
            if (!_isDisposed) {
              state = state.copyWith(appointments: AsyncData(data));
            }
          },
          onError: (error, stackTrace) async {
            if (_isDisposed) return;

            final errorMsg = error.toString().toLowerCase();
            // Automatically retry if Firestore reports permission-denied
            // due to auth custom claims race condition immediately after login
            if (_retryCount < 2 &&
                (errorMsg.contains('permission-denied') ||
                    errorMsg.contains('permission_denied'))) {
              _retryCount++;
              await Future.delayed(const Duration(milliseconds: 700));
              if (_isDisposed) return;
              try {
                await auth.FirebaseAuth.instance.currentUser?.getIdToken(true);
              } catch (_) {}
              if (!_isDisposed) {
                _initStream();
              }
              return;
            }

            state = state.copyWith(appointments: AsyncError(error, stackTrace));
          },
        );
  }

  Future<void> refresh() async {
    _retryCount = 0;
    await _initStream();
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
}
