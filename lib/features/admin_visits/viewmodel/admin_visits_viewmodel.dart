import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/campus_visit_status.dart';
import '../../../core/errors/failures.dart';
import '../../../core/models/campus_visit.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/hive_storage_service.dart';
import '../../my_visits/viewmodel/my_visits_viewmodel.dart';

/// State for the Admin Visit Review mutation.
class AdminVisitMutationState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const AdminVisitMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AdminVisitMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AdminVisitMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Controller managing Admin review actions (Approve / Reject) for campus visits.
class AdminVisitsController extends Notifier<AdminVisitMutationState> {
  @override
  AdminVisitMutationState build() {
    return const AdminVisitMutationState();
  }

  /// Approves a pending campus visit.
  Future<bool> approveVisit({required String visitId, String? note}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final repo = ref.read(campusVisitRepositoryProvider);
      await repo.reviewVisit(
        visitId: visitId,
        action: 'approve',
        reviewNote: note,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  /// Rejects a pending campus visit with an explanatory note.
  Future<bool> rejectVisit({
    required String visitId,
    required String note,
  }) async {
    if (note.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'A reason is required when rejecting a visit.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final repo = ref.read(campusVisitRepositoryProvider);
      await repo.reviewVisit(
        visitId: visitId,
        action: 'reject',
        reviewNote: note.trim(),
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }
}

final adminVisitsControllerProvider =
    NotifierProvider<AdminVisitsController, AdminVisitMutationState>(
      AdminVisitsController.new,
    );

/// Notifier for filtering admin campus visits by status in the UI.
class AdminVisitsFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? filter) {
    state = filter;
  }
}

final adminVisitsFilterProvider =
    NotifierProvider<AdminVisitsFilterNotifier, String?>(
  AdminVisitsFilterNotifier.new,
);

/// Tracks pending campus visit IDs already seen by the admin.
class AdminSeenVisitIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => HiveStorageService.getAdminSeenVisitIds();

  /// Marks all pending visits in [visits] as seen and prunes non-pending IDs.
  void markPendingVisitsSeen(List<CampusVisit> visits) {
    final pendingIds = visits
        .where((v) => v.status == CampusVisitStatus.pending)
        .map((v) => v.id)
        .toSet();
    if (setEquals(state, pendingIds)) return;
    state = pendingIds;
    HiveStorageService.saveAdminSeenVisitIds(pendingIds);
  }
}

final adminSeenVisitIdsProvider =
    NotifierProvider<AdminSeenVisitIdsNotifier, Set<String>>(
      AdminSeenVisitIdsNotifier.new,
    );

/// Summary counts driving the admin dashboard campus visits indicator.
class AdminCampusVisitIndicatorState {
  final int pendingCount;
  final int unseenCount;

  const AdminCampusVisitIndicatorState({
    required this.pendingCount,
    required this.unseenCount,
  });

  const AdminCampusVisitIndicatorState.empty()
    : pendingCount = 0,
      unseenCount = 0;

  bool get hasPending => pendingCount > 0;
  bool get hasUnseen => unseenCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminCampusVisitIndicatorState &&
          runtimeType == other.runtimeType &&
          pendingCount == other.pendingCount &&
          unseenCount == other.unseenCount;

  @override
  int get hashCode => Object.hash(pendingCount, unseenCount);
}

/// Derives live pending and unseen campus visit counts for the admin banner.
final adminCampusVisitIndicatorProvider =
    Provider<AdminCampusVisitIndicatorState>((ref) {
      final pendingVisits =
          ref
              .watch(adminVisitsProvider(CampusVisitStatus.pending.code))
              .value ??
          const <CampusVisit>[];
      if (pendingVisits.isEmpty) {
        return const AdminCampusVisitIndicatorState.empty();
      }
      final seenIds = ref.watch(adminSeenVisitIdsProvider);
      final unseenCount = pendingVisits
          .where((v) => !seenIds.contains(v.id))
          .length;
      return AdminCampusVisitIndicatorState(
        pendingCount: pendingVisits.length,
        unseenCount: unseenCount,
      );
    });
