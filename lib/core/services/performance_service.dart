import 'package:firebase_performance/firebase_performance.dart';

abstract class PerformanceService {
  Future<Trace> newTrace(String traceName);

  Future<T> traceAction<T>(
    String traceName,
    Future<T> Function() action, {
    Map<String, String>? attributes,
    Map<String, int>? metrics,
  });
}

class FirebasePerformanceService implements PerformanceService {
  final FirebasePerformance _performance;

  FirebasePerformanceService({FirebasePerformance? performance})
    : _performance = performance ?? FirebasePerformance.instance;

  @override
  Future<Trace> newTrace(String traceName) async {
    return _performance.newTrace(traceName);
  }

  @override
  Future<T> traceAction<T>(
    String traceName,
    Future<T> Function() action, {
    Map<String, String>? attributes,
    Map<String, int>? metrics,
  }) async {
    final trace = await newTrace(traceName);
    await trace.start();

    if (attributes != null) {
      for (final entry in attributes.entries) {
        trace.putAttribute(entry.key, entry.value);
      }
    }
    if (metrics != null) {
      for (final entry in metrics.entries) {
        trace.setMetric(entry.key, entry.value);
      }
    }

    try {
      return await action();
    } finally {
      await trace.stop();
    }
  }
}
