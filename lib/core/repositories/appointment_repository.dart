import '../models/appointment.dart';

abstract class AppointmentReader {
  Future<Appointment?> getAppointmentById(String id);
  Stream<Appointment?> watchAppointmentById(String id);

  Future<List<Appointment>> getUpcomingSurveysForApplicant(String applicantId);
  Future<List<Appointment>> getRecentRequestsForApplicant(
    String applicantId, {
    int limit = 5,
  });
  Future<List<Appointment>> getBookingsForApplicant(
    String applicantId, {
    String? statusFilter,
  });

  Stream<List<Appointment>> watchAdminDashboardAppointments({
    String? statusFilter,
    String? surveyTypeFilter,
  });
  Stream<List<Appointment>> watchCommitteeReviewAppointments(String reviewerId);
  Stream<List<Appointment>> watchCommitteeAssignedTasks(String taskMemberId);
}

abstract class AppointmentWriter {
  Future<String> submitAppointment(Appointment appointment);
  Future<void> assignReviewer(
    String appointmentId,
    String reviewerId,
    String reviewerName,
  );
  Future<void> setConfirmedDate(String appointmentId, DateTime confirmedDate);
  Future<void> reviewAppointment({
    required String appointmentId,
    required String action, // 'approve' | 'reject' | 'clarify'
    String? reasonOrNote,
  });
  Future<void> submitClarificationReply(String appointmentId, String replyText);
  Future<void> assignFieldworkTask(
    String appointmentId,
    String memberId,
    String memberName,
  );
}

abstract class AppointmentRepository
    implements AppointmentReader, AppointmentWriter {}
