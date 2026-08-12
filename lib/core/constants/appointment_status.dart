enum AppointmentStatus {
  pendingAssignment('pending_assignment', 'Pending Assignment'),
  underReview('under_review', 'Under Review'),
  clarificationRequested('clarification_requested', 'Clarification Requested'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  taskAssigned('task_assigned', 'Task Assigned');

  final String code;
  final String label;

  const AppointmentStatus(this.code, this.label);

  static AppointmentStatus fromCode(String code) {
    return AppointmentStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AppointmentStatus.pendingAssignment,
    );
  }
}
