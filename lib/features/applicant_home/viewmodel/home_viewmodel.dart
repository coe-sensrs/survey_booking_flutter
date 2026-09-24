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
  Future<HomeDashboardData> _fetchDashboardData(String uid) async {
    final appointmentRepo = ref.read(appointmentRepositoryProvider);
    final auditLogRepo = ref.read(auditLogRepositoryProvider);

    final upcomingFuture = appointmentRepo.getUpcomingSurveysForApplicant(uid);
    final recentFuture = appointmentRepo.getRecentRequestsForApplicant(
      uid,
      limit: 5,
    );
    final activityFuture = auditLogRepo.getRecentActivityForApplicant(
      uid,
      limit: 5,
    );

    final upcoming = await upcomingFuture.catchError((_) => <Appointment>[]);
    final recent = await recentFuture.catchError((_) => <Appointment>[]);
    final activity = await activityFuture.catchError((_) => <AuditLogEntry>[]);

    return HomeDashboardData(
      upcomingSurveys: upcoming,
      recentRequests: recent,
      recentActivity: activity,
    );
  }

  @override
  Future<HomeDashboardData> build() async {
    final user = await ref.watch(authViewModelProvider.future);
    if (user == null) {
      return const HomeDashboardData(
        upcomingSurveys: [],
        recentRequests: [],
        recentActivity: [],
      );
    }

    return _fetchDashboardData(user.uid);
  }

  Future<void> refresh() async {
    final user = ref.read(authViewModelProvider).value;
    if (user == null) return;

    state = await AsyncValue.guard(() => _fetchDashboardData(user.uid));
  }
}
