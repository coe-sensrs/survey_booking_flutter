import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/audit_log_repository.dart';
import '../models/app_user.dart';
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
