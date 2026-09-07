import 'package:firebase_analytics/firebase_analytics.dart';

abstract class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object>? parameters});
  Future<void> logLogin({String? loginMethod});
  Future<void> logSignUp({required String signUpMethod});
  Future<void> setCurrentScreen(String screenName);

  Future<void> setUserId(String? userId);
  Future<void> setUserProperty({required String name, required String? value});

  // Domain specific events
  Future<void> logBookingWizardStarted();
  Future<void> logBookingSubmitted({
    required String surveyType,
    required bool hasDocs,
  });
  Future<void> logReviewActionTaken({required String action});

  FirebaseAnalyticsObserver get navigationObserver;
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

  @override
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> logBookingWizardStarted() async {
    await _analytics.logEvent(name: 'booking_wizard_started');
  }

  @override
  Future<void> logBookingSubmitted({
    required String surveyType,
    required bool hasDocs,
  }) async {
    await _analytics.logEvent(
      name: 'booking_submitted',
      parameters: {'survey_type': surveyType, 'has_docs': hasDocs.toString()},
    );
  }

  @override
  Future<void> logReviewActionTaken({required String action}) async {
    await _analytics.logEvent(
      name: 'review_action_taken',
      parameters: {'action': action},
    );
  }

  @override
  FirebaseAnalyticsObserver get navigationObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);
}
