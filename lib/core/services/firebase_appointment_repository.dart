import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import '../repositories/appointment_repository.dart';
import '../constants/appointment_status.dart';

class FirebaseAppointmentRepository implements AppointmentRepository {
  final FirebaseFirestore _firestore;

  FirebaseAppointmentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _firestore.collection('appointments');

  @override
  Future<Appointment?> getAppointmentById(String id) async {
    final doc = await _appointmentsRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Appointment.fromMap(doc.id, doc.data()!);
  }

  @override
  Stream<Appointment?> watchAppointmentById(String id) {
    return _appointmentsRef.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Appointment.fromMap(doc.id, doc.data()!);
    });
  }

  @override
  Future<List<Appointment>> getUpcomingSurveysForApplicant(
    String applicantId,
  ) async {
    final snap = await _appointmentsRef
        .where('applicantId', isEqualTo: applicantId)
        .where(
          'status',
          whereIn: [
            AppointmentStatus.approved.code,
            AppointmentStatus.taskAssigned.code,
          ],
        )
        .orderBy('confirmedDate', descending: false)
        .get();

    return snap.docs
        .map((doc) => Appointment.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<Appointment>> getRecentRequestsForApplicant(
    String applicantId, {
    int limit = 5,
  }) async {
    final snap = await _appointmentsRef
        .where('applicantId', isEqualTo: applicantId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((doc) => Appointment.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<Appointment>> getBookingsForApplicant(
    String applicantId, {
    String? statusFilter,
  }) async {
    Query<Map<String, dynamic>> query = _appointmentsRef.where(
      'applicantId',
      isEqualTo: applicantId,
    );

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snap = await query.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((doc) => Appointment.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Stream<List<Appointment>> watchAdminDashboardAppointments({
    String? statusFilter,
    String? surveyTypeFilter,
  }) {
    Query<Map<String, dynamic>> query = _appointmentsRef;

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (surveyTypeFilter != null && surveyTypeFilter.isNotEmpty) {
      query = query.where('surveyType', isEqualTo: surveyTypeFilter);
    }

    return query.orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs
          .map((doc) => Appointment.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Stream<List<Appointment>> watchCommitteeReviewAppointments(
    String reviewerId,
  ) {
    return _appointmentsRef
        .where('assignedReviewerId', isEqualTo: reviewerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => Appointment.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  @override
  Stream<List<Appointment>> watchCommitteeAssignedTasks(String taskMemberId) {
    return _appointmentsRef
        .where('assignedTaskMemberId', isEqualTo: taskMemberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => Appointment.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  @override
  Future<String> submitAppointment(Appointment appointment) async {
    final docRef = await _appointmentsRef.add(appointment.toMap());
    return docRef.id;
  }

  @override
  Future<void> assignReviewer(
    String appointmentId,
    String reviewerId,
    String reviewerName,
  ) async {
    await _appointmentsRef.doc(appointmentId).update({
      'assignedReviewerId': reviewerId,
      'assignedReviewerName': reviewerName,
      'status': AppointmentStatus.underReview.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setConfirmedDate(
    String appointmentId,
    DateTime confirmedDate,
  ) async {
    await _appointmentsRef.doc(appointmentId).update({
      'confirmedDate': Timestamp.fromDate(confirmedDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reviewAppointment({
    required String appointmentId,
    required String action,
    String? reasonOrNote,
  }) async {
    String newStatus = AppointmentStatus.underReview.code;
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (action == 'approve') {
      newStatus = AppointmentStatus.approved.code;
    } else if (action == 'reject') {
      newStatus = AppointmentStatus.rejected.code;
      updates['rejectionReason'] = reasonOrNote;
    } else if (action == 'clarify') {
      newStatus = AppointmentStatus.clarificationRequested.code;
      updates['clarificationNote'] = reasonOrNote;
    }

    updates['status'] = newStatus;
    await _appointmentsRef.doc(appointmentId).update(updates);
  }

  @override
  Future<void> submitClarificationReply(
    String appointmentId,
    String replyText,
  ) async {
    await _appointmentsRef.doc(appointmentId).update({
      'clarificationReply': replyText,
      'status': AppointmentStatus.underReview.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> assignFieldworkTask(
    String appointmentId,
    String memberId,
    String memberName,
  ) async {
    await _appointmentsRef.doc(appointmentId).update({
      'assignedTaskMemberId': memberId,
      'assignedTaskMemberName': memberName,
      'status': AppointmentStatus.taskAssigned.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
