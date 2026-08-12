import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_log_entry.dart';
import '../repositories/audit_log_repository.dart';

class FirebaseAuditLogRepository implements AuditLogRepository {
  final FirebaseFirestore _firestore;

  FirebaseAuditLogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<AuditLogEntry>> getRecentActivityForApplicant(
    String applicantId, {
    int limit = 10,
  }) async {
    final snap = await _firestore
        .collectionGroup('auditLog')
        .where('applicantId', isEqualTo: applicantId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((doc) => AuditLogEntry.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Stream<List<AuditLogEntry>> watchRecentActivityForApplicant(
    String applicantId, {
    int limit = 10,
  }) {
    return _firestore
        .collectionGroup('auditLog')
        .where('applicantId', isEqualTo: applicantId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => AuditLogEntry.fromMap(doc.id, doc.data()))
              .toList();
        });
  }
}
