import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment.dart';
import '../repositories/appointment_repository.dart';
import '../constants/appointment_status.dart';

class FirebaseAppointmentRepository implements AppointmentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirebaseAppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _appointmentsRef =>
      _firestore.collection('appointments');

  /// Force-refreshes the Firebase ID token before any Cloud Function call.
  /// Prevents stale cached tokens from triggering `unauthenticated` errors,
  /// mirroring the pattern used in [AdminFunctionsService].
  /// Failures (e.g. App Check / network issues) are logged and swallowed so
  /// the CF call still proceeds with the best available cached token.
  Future<void> _refreshToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken(true);
    } catch (e) {
      // App Check or network failure during refresh — proceed with cached token.
      debugPrint('[FirebaseAppointmentRepository] getIdToken(true) failed: $e');
    }
  }

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
  String newAppointmentId() => _firestore.collection('appointments').doc().id;

  @override
  Future<String> submitAppointment(Appointment appointment) async {
    await _refreshToken();
    final callable = _functions.httpsCallable('submitAppointment');
    final result = await callable.call<Map<String, dynamic>>({
      if (appointment.id.isNotEmpty) 'appointmentId': appointment.id,
      'applicantName': appointment.applicantName,
      'applicantOrgName': appointment.applicantOrgName,
      'applicantEmail': appointment.applicantEmail,
      'surveyType': appointment.surveyType.code,
      'customSurveyName': appointment.customSurveyName,
      'state': appointment.state,
      'district': appointment.district,
      'xenDetails': appointment.xenDetails.toJson(),
      'areaName': appointment.areaName,
      'kmlFile': appointment.kmlFile.toJson(),
      'preferredDate': appointment.preferredDate.toIso8601String(),
      'logistics': appointment.logistics.toJson(),
      'permissionDocuments': appointment.permissionDocuments
          .map((d) => d.toJson())
          .toList(),
    });
    return result.data['appointmentId'] as String;
  }

  @override
  Future<void> assignReviewer(
    String appointmentId,
    String reviewerId,
    String reviewerName,
  ) async {
    final callable = _functions.httpsCallable('assignReviewer');
    await callable.call(<String, dynamic>{
      'appointmentId': appointmentId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
    });
  }

  @override
  Future<void> setConfirmedDate(
    String appointmentId,
    DateTime confirmedDate,
  ) async {
    final callable = _functions.httpsCallable('setConfirmedDate');
    await callable.call(<String, dynamic>{
      'appointmentId': appointmentId,
      'confirmedDate': confirmedDate.toIso8601String(),
    });
  }

  @override
  Future<void> reviewAppointment({
    required String appointmentId,
    required String action,
    String? reasonOrNote,
  }) async {
    await _refreshToken();
    final callable = _functions.httpsCallable('reviewAppointment');
    await callable.call(<String, dynamic>{
      'appointmentId': appointmentId,
      'action': action,
      'reasonOrNote': reasonOrNote ?? '',
    });
  }

  @override
  Future<void> submitClarificationReply(
    String appointmentId,
    String replyText,
  ) async {
    await _refreshToken();
    final callable = _functions.httpsCallable('submitClarificationReply');
    await callable.call(<String, dynamic>{
      'appointmentId': appointmentId,
      'replyText': replyText,
    });
  }

  @override
  Future<void> assignFieldworkTask(
    String appointmentId,
    String memberId,
    String memberName,
  ) async {
    await _refreshToken();
    final callable = _functions.httpsCallable('assignFieldworkTask');
    await callable.call(<String, dynamic>{
      'appointmentId': appointmentId,
      'memberId': memberId,
      'memberName': memberName,
    });
  }
}
