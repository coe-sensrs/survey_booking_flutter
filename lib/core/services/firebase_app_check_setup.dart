import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const kWebRecaptchaSiteKey = 'put-default-web-sitekey';

class FirebaseAppCheckSetup {
  static Future<void> initialize() async {
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
}
