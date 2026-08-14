import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const kWebRecaptchaSiteKey = 'put-default-web-sitekey';

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
    // App Check in audit mode for now, as requested.
    // In audit mode, we initialize App Check but we don't enforce it in the Firebase console yet.
    // We use PlayIntegrity on Android.
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
        // Replace with your actual reCAPTCHA site key
        providerWeb: kDebugMode
            ? WebDebugProvider()
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
