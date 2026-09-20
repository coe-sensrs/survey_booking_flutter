import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../repositories/notification_repository.dart';
import '../models/app_user.dart';
import '../services/firebase_appointment_repository.dart';
import '../services/firebase_user_repository.dart';
import '../services/firebase_audit_log_repository.dart';
import '../services/firebase_notification_repository.dart';
import '../services/storage_upload_service.dart';
import '../services/file_open_service.dart';
import '../services/crash_reporting_service.dart';
import '../services/analytics_service.dart';
import '../services/performance_service.dart';
import '../services/notification_service.dart';
import '../services/firebase_notification_service.dart';

// Repositories
final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return FirebaseAppointmentRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirebaseUserRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return FirebaseNotificationRepository();
});

// ==========================================
// 6. Common Stream/Future Providers
// ==========================================

/// Stream of all committee members (Admin only)
final committeeMembersProvider = StreamProvider<List<AppUser>>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return repo.watchCommitteeMembers();
});

/// Future of active committee members (Admin only, used for assignments)
final activeCommitteeMembersProvider = FutureProvider<List<AppUser>>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getActiveCommitteeMembers();
});

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return FirebaseAuditLogRepository();
});

// Services
final storageUploadServiceProvider = Provider<StorageUploadService>((ref) {
  return StorageUploadService();
});

final fileOpenServiceProvider = Provider<FileOpenService>((ref) {
  return MobileFileOpenService();
});

final crashReportingServiceProvider = Provider<CrashReportingService>((ref) {
  return FirebaseCrashReportingService();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return FirebaseAnalyticsService();
});

final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return FirebasePerformanceService();
});

/// Singleton FCM notification service.
/// Initialized once in main() before runApp — the Provider only wraps the
/// pre-constructed instance for DI access throughout the widget tree.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => _sharedNotificationService,
);

/// The shared [FirebaseNotificationService] instance.
/// Exposed at package level so main() can call initialize() before runApp.
final _sharedNotificationService = FirebaseNotificationService();

/// Returns the singleton [FirebaseNotificationService] for startup initialization.
/// Use [notificationServiceProvider] everywhere else.
FirebaseNotificationService getNotificationServiceForInit() =>
    _sharedNotificationService;
