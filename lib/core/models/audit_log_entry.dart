import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String action;
  final String applicantId;
  final String performedByUid;
  final String performedByRole;
  final String performedByName;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.applicantId,
    required this.performedByUid,
    required this.performedByRole,
    required this.performedByName,
    required this.timestamp,
    this.details,
  });

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> map) {
    return AuditLogEntry(
      id: id,
      action: map['action'] as String? ?? '',
      applicantId: map['applicantId'] as String? ?? '',
      performedByUid: map['performedByUid'] as String? ?? '',
      performedByRole: map['performedByRole'] as String? ?? '',
      performedByName: map['performedByName'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details: map['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'applicantId': applicantId,
      'performedByUid': performedByUid,
      'performedByRole': performedByRole,
      'performedByName': performedByName,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
    };
  }
}
