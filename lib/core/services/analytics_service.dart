import 'package:firebase_analytics/firebase_analytics.dart';

abstract class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object>? parameters});
  Future<void> logLogin({String? loginMethod});
  Future<void> logSignUp({required String signUpMethod});
  Future<void> setCurrentScreen(String screenName);
}

class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logLogin({String? loginMethod}) async {
    await _analytics.logLogin(loginMethod: loginMethod ?? 'email');
  }

  @override
  Future<void> logSignUp({required String signUpMethod}) async {
    await _analytics.logSignUp(signUpMethod: signUpMethod);
  }

  @override
  Future<void> setCurrentScreen(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
}
