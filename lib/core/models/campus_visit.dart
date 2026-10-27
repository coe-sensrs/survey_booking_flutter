import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/campus_visit_status.dart';

/// Immutable domain model for a campus visit booking.
/// Mirrors the `campus_visits/{visitId}` Firestore collection.
class CampusVisit {
  final String id;
  final String applicantId;
  final String applicantName;
  final String applicantMobile;
  final String applicantEmail;

  /// Requested visit date (date-only; time is determined by [session]).
  final DateTime visitDate;

  /// Either 'morning' (09:30–12:30) or 'afternoon' (14:00–17:00).
  final String session;

  /// Number of people in the visiting delegation (1–50).
  final int delegationSize;

  /// Free-text description of the visit purpose (20–1000 chars).
  final String purpose;

  /// SHA-256 idempotency key: `SHA-256(uid + visitDate.toIso8601String() + session)`.
  /// Used server-side to prevent duplicate bookings on retry.
  final String idempotencyKey;

  final CampusVisitStatus status;
  final String? reviewedBy;
  final String? reviewerName;
  final String? reviewNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  const CampusVisit({
    required this.id,
    required this.applicantId,
    required this.applicantName,
    required this.applicantMobile,
    required this.applicantEmail,
    required this.visitDate,
    required this.session,
    required this.delegationSize,
    required this.purpose,
    required this.idempotencyKey,
    required this.status,
    this.reviewedBy,
    this.reviewerName,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CampusVisit.fromMap(String id, Map<String, dynamic> map) {
    return CampusVisit(
      id: id,
      applicantId: map['applicantId'] as String? ?? '',
      applicantName: map['applicantName'] as String? ?? '',
      applicantMobile: map['applicantMobile'] as String? ?? '',
      applicantEmail: map['applicantEmail'] as String? ?? '',
      visitDate:
          (map['visitDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      session: map['session'] as String? ?? 'morning',
      delegationSize: (map['delegationSize'] as num?)?.toInt() ?? 1,
      purpose: map['purpose'] as String? ?? '',
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      status: CampusVisitStatus.fromCode(map['status'] as String? ?? ''),
      reviewedBy: map['reviewedBy'] as String?,
      reviewerName: map['reviewerName'] as String?,
      reviewNote: map['reviewNote'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Returns the human-readable session time window.
  String get sessionLabel =>
      session == 'afternoon' ? '02:00 PM – 05:00 PM' : '09:30 AM – 12:30 PM';

  String get sessionDisplayName =>
      session == 'afternoon' ? 'Afternoon Session' : 'Morning Session';
}
