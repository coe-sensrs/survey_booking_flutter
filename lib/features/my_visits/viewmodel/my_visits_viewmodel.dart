import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/campus_visit_status.dart';
import '../../../core/models/campus_visit.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/hive_storage_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Streams all campus visits for the currently authenticated applicant.
final myVisitsProvider = StreamProvider.family<List<CampusVisit>, String>((
  ref,
  applicantId,
) {
  final repo = ref.watch(campusVisitRepositoryProvider);
  return repo.watchVisitsForApplicant(applicantId);
});

/// Admin: streams all campus visits, optionally filtered by status.
final adminVisitsProvider = StreamProvider.family<List<CampusVisit>, String?>((
  ref,
  statusFilter,
) {
  final repo = ref.watch(campusVisitRepositoryProvider);
  return repo.watchAllVisits(statusFilter: statusFilter);
});

/// Returns a stable token representing a reviewed campus visit's status & revision.
String applicantVisitSeenToken(CampusVisit visit) =>
    '${visit.status.code}:${visit.updatedAt.millisecondsSinceEpoch}';

/// Tracks reviewed (approved/rejected) campus visit states already seen by the applicant.
class ApplicantSeenVisitsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final uid = ref.watch(authViewModelProvider.select((a) => a.value?.uid));
    if (uid == null || uid.isEmpty) return const {};
    return HiveStorageService.getApplicantSeenVisitStates(uid);
  }

  /// Marks all approved/rejected visits in [visits] as seen for [uid].
  void markReviewedVisitsSeen(String uid, List<CampusVisit> visits) {
    if (uid.isEmpty) return;
    final next = <String, String>{};
    for (final visit in visits) {
      if (visit.status == CampusVisitStatus.approved ||
          visit.status == CampusVisitStatus.rejected) {
        next[visit.id] = applicantVisitSeenToken(visit);
      }
    }
    if (mapEquals(state, next)) return;
    state = next;
    HiveStorageService.saveApplicantSeenVisitStates(uid, next);
  }
}

final applicantSeenVisitsProvider =
    NotifierProvider<ApplicantSeenVisitsNotifier, Map<String, String>>(
      ApplicantSeenVisitsNotifier.new,
    );

/// Summary counts of unseen approved/rejected visits for the applicant home card.
class ApplicantCampusVisitIndicatorState {
  final int unseenApprovedCount;
  final int unseenRejectedCount;

  const ApplicantCampusVisitIndicatorState({
    required this.unseenApprovedCount,
    required this.unseenRejectedCount,
  });

  const ApplicantCampusVisitIndicatorState.empty()
    : unseenApprovedCount = 0,
      unseenRejectedCount = 0;

  int get totalUnread => unseenApprovedCount + unseenRejectedCount;
  bool get hasUnread => totalUnread > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicantCampusVisitIndicatorState &&
          runtimeType == other.runtimeType &&
          unseenApprovedCount == other.unseenApprovedCount &&
          unseenRejectedCount == other.unseenRejectedCount;

  @override
  int get hashCode => Object.hash(unseenApprovedCount, unseenRejectedCount);
}

/// Derives unread approved/rejected counts for the current applicant's home card.
final applicantCampusVisitIndicatorProvider =
    Provider<ApplicantCampusVisitIndicatorState>((ref) {
      final uid = ref.watch(authViewModelProvider.select((a) => a.value?.uid));
      if (uid == null || uid.isEmpty) {
        return const ApplicantCampusVisitIndicatorState.empty();
      }
      final visits =
          ref.watch(myVisitsProvider(uid)).value ?? const <CampusVisit>[];
      if (visits.isEmpty) {
        return const ApplicantCampusVisitIndicatorState.empty();
      }
      final seenStates = ref.watch(applicantSeenVisitsProvider);
      var unseenApproved = 0;
      var unseenRejected = 0;
      for (final visit in visits) {
        if (visit.status == CampusVisitStatus.approved &&
            seenStates[visit.id] != applicantVisitSeenToken(visit)) {
          unseenApproved++;
        } else if (visit.status == CampusVisitStatus.rejected &&
            seenStates[visit.id] != applicantVisitSeenToken(visit)) {
          unseenRejected++;
        }
      }
      return ApplicantCampusVisitIndicatorState(
        unseenApprovedCount: unseenApproved,
        unseenRejectedCount: unseenRejected,
      );
    });
