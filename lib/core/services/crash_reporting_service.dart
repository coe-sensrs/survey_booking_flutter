import 'package:firebase_crashlytics/firebase_crashlytics.dart';

abstract class CrashReportingService {
  Future<void> log(String message);
  Future<void> setCustomKey(String key, Object value);
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    bool fatal = false,
  });
}

class FirebaseCrashReportingService implements CrashReportingService {
  final FirebaseCrashlytics _crashlytics;

  FirebaseCrashReportingService({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  @override
  Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }
}
