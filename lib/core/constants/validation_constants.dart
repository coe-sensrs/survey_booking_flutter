class ValidationConstants {
  ValidationConstants._();

  static const int minPasswordLength = 8;
  static const int maxCustomSurveyNameLength = 60;
  static const int maxAreaNameLength = 150;
  static const int maxXenNameLength = 100;
  static const int maxCoordinatorNameLength = 100;
  static const int maxCoordinatorDesignationLength = 100;
  static const int maxDriverNameLength = 100;
  static const int maxVehicleNumberLength = 20;
  static const int maxVehicleModelLength = 60;
  static const int maxRejectionReasonLength = 500;
  static const int maxClarificationNoteLength = 500;
  static const int maxClarificationReplyLength = 500;

  static const int maxPermissionDocsCount = 5;
  static const int minPermissionDocsCount = 1;
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  static const int maxUnresolvedBookingsPerApplicant = 3;
}
