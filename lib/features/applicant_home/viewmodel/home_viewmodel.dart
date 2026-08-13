import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/appointment.dart';
import '../../../core/models/audit_log_entry.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

class HomeDashboardData {
  final List<Appointment> upcomingSurveys;
  final List<Appointment> recentRequests;
  final List<AuditLogEntry> recentActivity;

  const HomeDashboardData({
    required this.upcomingSurveys,
    required this.recentRequests,
    required this.recentActivity,
  });
}

final homeViewModelProvider =
    AsyncNotifierProvider<HomeViewModel, HomeDashboardData>(() {
  return HomeViewModel();
});

class HomeViewModel extends AsyncNotifier<HomeDashboardData> {
  @override
  Future<HomeDashboardData> build() async {
    final user = ref.watch(authViewModelProvider).value;
    if (user == null) {
      return const HomeDashboardData(
        upcomingSurveys: [],
        recentRequests: [],
        recentActivity: [],
      );
    }

    final appointmentRepo = ref.watch(appointmentRepositoryProvider);
    final auditLogRepo = ref.watch(auditLogRepositoryProvider);

    final upcomingFuture = appointmentRepo.getUpcomingSurveysForApplicant(user.uid);
    final recentFuture = appointmentRepo.getRecentRequestsForApplicant(user.uid, limit: 5);
    final activityFuture = auditLogRepo.getRecentActivityForApplicant(user.uid, limit: 10);

    final upcoming = await upcomingFuture.catchError((_) => <Appointment>[]);
    final recent = await recentFuture.catchError((_) => <Appointment>[]);
    final activity = await activityFuture.catchError((_) => <AuditLogEntry>[]);

    return HomeDashboardData(
      upcomingSurveys: upcoming,
      recentRequests: recent,
      recentActivity: activity,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}
