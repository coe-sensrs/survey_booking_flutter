import '../models/campus_visit.dart';

abstract class CampusVisitRepository {
  /// Watch all visits submitted by [applicantId], newest first.
  Stream<List<CampusVisit>> watchVisitsForApplicant(String applicantId);

  /// Watch all campus visits (admin view), ordered by createdAt descending.
  Stream<List<CampusVisit>> watchAllVisits({String? statusFilter});

  /// Fetch a single visit by [visitId].
  Future<CampusVisit?> getVisitById(String visitId);

  /// Submit a new campus visit via the [submitCampusVisit] callable Cloud Function.
  /// Returns the server-assigned [visitId].
  Future<String> submitVisit({
    required String applicantName,
    required String applicantMobile,
    required String applicantEmail,
    required DateTime visitDate,
    required String session,
    required int delegationSize,
    required String purpose,
    required String idempotencyKey,
  });

  /// Admin: approve or reject a visit via the [reviewCampusVisit] CF.
  Future<void> reviewVisit({
    required String visitId,
    required String action, // 'approve' | 'reject'
    String? reviewNote,
  });
}
