import 'package:flutter_test/flutter_test.dart';
import 'package:survey_desk/core/constants/validation_constants.dart';
import 'package:survey_desk/core/models/app_user.dart';
import 'package:survey_desk/features/booking_wizard/viewmodel/booking_wizard_viewmodel.dart';

void main() {
  group('AppUser Model Tests', () {
    test('AppUser handles photoUrl serialization and deserialization', () {
      final now = DateTime.now();
      final user = AppUser(
        uid: 'test_uid',
        role: 'applicant',
        fullName: 'Test User',
        email: 'test@example.com',
        phone: '1234567890',
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toMap();
      expect(map['photoUrl'], 'https://example.com/photo.jpg');

      final deserialized = AppUser.fromMap('test_uid', {
        'role': 'applicant',
        'fullName': 'Test User',
        'email': 'test@example.com',
        'phone': '1234567890',
        'photoUrl': null,
      });

      expect(deserialized.photoUrl, isNull);
    });

    test('AppUser equality and hashCode work correctly for identical values', () {
      final now = DateTime(2026, 9, 24);
      final user1 = AppUser(
        uid: 'user_1',
        role: 'applicant',
        fullName: 'Same Name',
        email: 'same@example.com',
        phone: '1234567890',
        createdAt: now,
        updatedAt: now,
      );
      final user2 = AppUser(
        uid: 'user_1',
        role: 'applicant',
        fullName: 'Same Name',
        email: 'same@example.com',
        phone: '1234567890',
        createdAt: now,
        updatedAt: now,
      );
      final user3 = user1.copyWith(fullName: 'Different Name');

      expect(user1, equals(user2));
      expect(user1.hashCode, equals(user2.hashCode));
      expect(user1, isNot(equals(user3)));
    });
  });

  group('Booking Wizard Step 7 Permission Documents Tests', () {
    test('ValidationConstants permits 0 minimum and 5 maximum documents', () {
      expect(ValidationConstants.minPermissionDocsCount, 0);
      expect(ValidationConstants.maxPermissionDocsCount, 5);
      expect(ValidationConstants.maxFileSizeBytes, 5 * 1024 * 1024);
    });

    test(
      'WizardStateData correctly handles empty permissionDocs by default',
      () {
        const state = WizardStateData();
        expect(state.permissionDocs, isEmpty);

        final map = state.toMap();
        expect(map['permissionDocs'], isEmpty);

        final fromMap = WizardStateData.fromMap(map);
        expect(fromMap.permissionDocs, isEmpty);
      },
    );

    test('WizardStateData correctly preserves multiple attached documents', () {
      final docs = [
        {
          'path': '/path/to/doc1.pdf',
          'fileName': 'doc1.pdf',
          'fileType': 'pdf',
          'sizeBytes': 1024,
        },
        {
          'path': '/path/to/doc2.png',
          'fileName': 'doc2.png',
          'fileType': 'png',
          'sizeBytes': 2048,
        },
      ];

      final state = const WizardStateData().copyWith(permissionDocs: docs);
      expect(state.permissionDocs.length, 2);

      final map = state.toMap();
      final fromMap = WizardStateData.fromMap(map);
      expect(fromMap.permissionDocs.length, 2);
      expect(fromMap.permissionDocs.first['fileName'], 'doc1.pdf');
      expect(fromMap.permissionDocs.last['fileName'], 'doc2.png');
    });
  });
}
