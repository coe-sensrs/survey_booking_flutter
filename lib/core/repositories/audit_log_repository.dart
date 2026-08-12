import '../models/audit_log_entry.dart';

abstract class AuditLogRepository {
  Future<List<AuditLogEntry>> getRecentActivityForApplicant(
    String applicantId, {
    int limit = 10,
  });
  Stream<List<AuditLogEntry>> watchRecentActivityForApplicant(
    String applicantId, {
    int limit = 10,
  });
}
