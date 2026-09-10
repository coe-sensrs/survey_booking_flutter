/// Firebase Emulator Suite connectivity smoke test.
///
/// This test verifies that the Flutter app can connect to each emulator
/// service (Auth, Firestore, Storage, Functions) and perform basic operations.
///
/// Run with:
/// ```
/// flutter test test/integration/firebase_emulator_test.dart \
///   --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// Prerequisites:
///   - `firebase emulators:start` must be running.
///   - Use the host machine's LAN IP for physical devices,
///     or `10.0.2.2` for the Android Emulator (configured in firebase_emulator.dart).
library;

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_desk/core/firebase/firebase_emulator.dart';
import 'package:survey_desk/firebase_options.dart';

/// Initializes Firebase and connects to the emulator suite once for all tests.
Future<void> _initializeEmulator() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Force emulator connection regardless of the dart-define flag since this
  // IS an emulator test.
  await FirebaseEmulator.connect();
}

void main() {
  setUpAll(() async {
    await _initializeEmulator();
  });

  group('Auth Emulator', () {
    test('can create a test user and sign in', () async {
      const email = 'emulator-test@test.com';
      const password = 'test-password-123';

      // Create
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      expect(cred.user, isNotNull);
      expect(cred.user!.email, email);

      // Sign out and back in
      await FirebaseAuth.instance.signOut();
      final signInCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      expect(signInCred.user!.uid, cred.user!.uid);

      // Cleanup
      await signInCred.user!.delete();
    });
  });

  group('Firestore Emulator', () {
    test('can write and read a document', () async {
      final doc = FirebaseFirestore.instance.collection('_test_').doc('smoke');
      await doc.set({'value': 42, 'timestamp': FieldValue.serverTimestamp()});

      final snapshot = await doc.get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()?['value'], 42);

      // Cleanup
      await doc.delete();
    });
  });

  group('Storage Emulator', () {
    test('can upload and download a small file', () async {
      final ref = FirebaseStorage.instance.ref('_test_/smoke.txt');
      final data = [72, 101, 108, 108, 111]; // "Hello" as bytes

      await ref.putData(Uint8List.fromList(data));

      final downloaded = await ref.getData();
      expect(downloaded, isNotNull);
      expect(downloaded!.length, data.length);

      // Cleanup
      await ref.delete();
    });
  });

  group('Functions Emulator', () {
    test(
      'callable function responds (may error on missing function)',
      () async {
        // This tests connectivity — the function may not exist, but we should
        // get a Firebase error (not a network timeout) proving the emulator
        // is reachable.
        final callable = FirebaseFunctions.instance.httpsCallable('_smokePing');
        try {
          await callable.call();
          // If it actually exists and returns, that's fine too
        } on FirebaseFunctionsException catch (e) {
          // NOT_FOUND or UNIMPLEMENTED means the emulator is reachable
          // but the function doesn't exist — connectivity confirmed.
          expect(['not-found', 'unimplemented', 'internal'], contains(e.code));
        }
      },
    );
  });
}
