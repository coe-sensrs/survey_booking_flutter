import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../services/firebase_appointment_repository.dart';
import '../services/firebase_user_repository.dart';
import '../services/firebase_audit_log_repository.dart';
import '../services/storage_upload_service.dart';
import '../services/file_open_service.dart';
import '../services/crash_reporting_service.dart';
import '../services/analytics_service.dart';

// Repositories
final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return FirebaseAppointmentRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirebaseUserRepository();
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
