import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const kWebRecaptchaSiteKey = 'put-default-web-sitekey';

/// Inject a custom App Check debug token via --dart-define:
///   `flutter run --dart-define=APP_CHECK_DEBUG_TOKEN=your-uuid-token`
///
/// Leave unset to let the SDK generate a token automatically (debug builds only).
/// Never set a value in release builds — the const defaults to empty string.
const _debugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

class FirebaseAppCheckSetup {
  static String? _token;

  static Future<void> initialize() async {
    // Fetch immediately; catch Integrity API errors gracefully
    FirebaseAppCheck.instance
        .getToken()
        .then((token) {
          _token = token;
        })
        .catchError((error) {
          // Prevents crash on devices without official Play Store
          debugPrint('AppCheck getToken failed: $error');
        });

    // Listen for future token refreshes
    FirebaseAppCheck.instance.onTokenChange.listen(
      (token) {
        _token = token;
      },
      onError: (error) {
        debugPrint('AppCheck onTokenChange error: $error');
      },
    );

    // App Check in audit mode for now.
    // In audit mode we initialize App Check but do not enforce it in the
    // Firebase console yet. We use PlayIntegrity on Android (release).
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? (_debugToken.isNotEmpty
                  ? AndroidDebugProvider(debugToken: _debugToken)
                  : const AndroidDebugProvider())
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? (_debugToken.isNotEmpty
                  ? AppleDebugProvider(debugToken: _debugToken)
                  : const AppleDebugProvider())
            : const AppleDeviceCheckProvider(),
        // Replace with your actual reCAPTCHA site key
        providerWeb: kDebugMode
            ? (_debugToken.isNotEmpty
                  ? WebDebugProvider(debugToken: _debugToken)
                  : WebDebugProvider())
            : ReCaptchaV3Provider(kWebRecaptchaSiteKey),
      );
    } catch (e) {
      debugPrint('Failed to initialize App Check: $e');
    }
  }

  /// Use this to append the Firebase App Check token to HTTP requests
  /// made outside of official Firebase SDKs (e.g. CachedNetworkImage)
  static Map<String, String>? get httpHeaders {
    if (_token != null) {
      return {'X-Firebase-AppCheck': _token!};
    }
    return null;
  }
}
