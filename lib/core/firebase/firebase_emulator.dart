import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Connects the Flutter app to the Firebase Emulator Suite for local
/// development. Production-safe: [kUseFirebaseEmulator] defaults to `false`
/// and must be explicitly enabled via `--dart-define=USE_FIREBASE_EMULATOR=true`.
///
/// Call [connect] once after `Firebase.initializeApp()` and before any
/// Firebase SDK usage (auth, Firestore reads, etc.).
class FirebaseEmulator {
  /// Production-safe toggle. `false` by default — never ships enabled unless
  /// the developer explicitly passes the dart-define flag at the CLI.
  static const kUseFirebaseEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  /// The host address the Android Emulator uses to reach the development
  /// machine's localhost. For physical devices, replace with your machine's
  /// LAN IP address.
  static const _emulatorHost = '10.0.2.2';

  /// Connects all four Firebase services to their respective local emulators.
  /// Ports match the `emulators` block in `firebase.json`.
  static Future<void> connect() async {
    debugPrint('🔥 Connecting to Firebase Emulator Suite...');

    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);

    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);

    await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);

    FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, 5001);

    debugPrint(
      '🔥 Firebase Emulator Suite connected '
      '(Auth:9099, Firestore:8080, Storage:9199, Functions:5001)',
    );
  }
}
