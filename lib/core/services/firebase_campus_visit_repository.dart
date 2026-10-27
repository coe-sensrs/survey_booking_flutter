import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/campus_visit.dart';
import '../repositories/campus_visit_repository.dart';

/// Firebase-backed implementation of [CampusVisitRepository].
///
/// All writes route through callable Cloud Functions so that security rules
/// can set `allow create/update/delete: if false` on the collection —
/// preventing status tampering from the client.
class FirebaseCampusVisitRepository implements CampusVisitRepository {
  final _collection = FirebaseFirestore.instance.collection('campus_visits');
  final _functions = FirebaseFunctions.instance;

  @override
  Stream<List<CampusVisit>> watchVisitsForApplicant(String applicantId) {
    return _collection
        .where('applicantId', isEqualTo: applicantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CampusVisit.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Stream<List<CampusVisit>> watchAllVisits({String? statusFilter}) {
    Query<Map<String, dynamic>> q = _collection.orderBy(
      'createdAt',
      descending: true,
    );
    if (statusFilter != null && statusFilter.isNotEmpty) {
      q = q.where('status', isEqualTo: statusFilter);
    }
    return q.snapshots().map(
      (snap) =>
          snap.docs.map((d) => CampusVisit.fromMap(d.id, d.data())).toList(),
    );
  }

  @override
  Future<CampusVisit?> getVisitById(String visitId) async {
    final doc = await _collection.doc(visitId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CampusVisit.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<String> submitVisit({
    required String applicantName,
    required String applicantMobile,
    required String applicantEmail,
    required DateTime visitDate,
    required String session,
    required int delegationSize,
    required String purpose,
    required String idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('submitCampusVisit');
    final result = await callable.call<Map<String, dynamic>>({
      'applicantName': applicantName,
      'applicantMobile': applicantMobile,
      'applicantEmail': applicantEmail,
      // ISO-8601 date string — CF converts to Timestamp server-side
      'visitDate': visitDate.toIso8601String(),
      'session': session,
      'delegationSize': delegationSize,
      'purpose': purpose,
      'idempotencyKey': idempotencyKey,
    });
    final data = result.data;
    return data['visitId'] as String? ?? '';
  }

  @override
  Future<void> reviewVisit({
    required String visitId,
    required String action,
    String? reviewNote,
  }) async {
    final callable = _functions.httpsCallable('reviewCampusVisit');
    await callable.call<Map<String, dynamic>>({
      'visitId': visitId,
      'action': action,
      'reviewNote': ?reviewNote,
    });
  }
}
