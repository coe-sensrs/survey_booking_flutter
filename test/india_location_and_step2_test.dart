import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_desk/core/providers/core_providers.dart';
import 'package:survey_desk/core/services/india_location_service.dart';
import 'package:survey_desk/core/models/app_user.dart';
import 'package:survey_desk/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:survey_desk/features/booking_wizard/view/steps/step_2_state_district.dart';
import 'package:survey_desk/features/booking_wizard/viewmodel/booking_wizard_viewmodel.dart';

class _FakeAuthViewModel extends AuthViewModel {
  @override
  Future<AppUser?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testJson = '''
{
  "states": [
    {
      "state": "Punjab",
      "districts": ["Amritsar", "Jalandhar", "Ludhiana", "Patiala"]
    },
    {
      "state": "Haryana",
      "districts": ["Ambala", "Gurugram", "Karnal", "Panipat"]
    },
    {
      "state": "Goa",
      "districts": ["North Goa", "South Goa"]
    }
  ]
}
''';

  group('IndiaLocationService Unit Tests', () {
    test('StateLocation correctly parses from JSON map', () {
      final loc = StateLocation.fromJson({
        'state': 'Punjab',
        'districts': ['Amritsar', 'Bathinda', ''],
      });

      expect(loc.state, 'Punjab');
      expect(loc.districts, ['Amritsar', 'Bathinda']);
    });

    test('Loads and sorts states from AssetBundle', () async {
      final bundle = _MockAssetBundle({
        'assets/india_states_districts.json': testJson,
      });
      final service = IndiaLocationService(bundle: bundle);

      final states = await service.getStates();
      expect(states, ['Goa', 'Haryana', 'Punjab']);
    });

    test('Loads and sorts districts for a specific state', () async {
      final bundle = _MockAssetBundle({
        'assets/india_states_districts.json': testJson,
      });
      final service = IndiaLocationService(bundle: bundle);

      final punjabDistricts = await service.getDistrictsForState('Punjab');
      expect(punjabDistricts, ['Amritsar', 'Jalandhar', 'Ludhiana', 'Patiala']);

      final haryanaDistricts = await service.getDistrictsForState('Haryana');
      expect(haryanaDistricts, ['Ambala', 'Gurugram', 'Karnal', 'Panipat']);
    });

    test('Case-insensitive district lookup with whitespace trimming', () async {
      final bundle = _MockAssetBundle({
        'assets/india_states_districts.json': testJson,
      });
      final service = IndiaLocationService(bundle: bundle);

      final districts = await service.getDistrictsForState('  punjab  ');
      expect(districts, contains('Amritsar'));
    });

    test('Returns empty list for non-existent or empty state', () async {
      final bundle = _MockAssetBundle({
        'assets/india_states_districts.json': testJson,
      });
      final service = IndiaLocationService(bundle: bundle);

      expect(await service.getDistrictsForState('NonExistent'), isEmpty);
      expect(await service.getDistrictsForState(''), isEmpty);
      expect(await service.getDistrictsForState('   '), isEmpty);
    });

    test('Handles malformed JSON bundle gracefully without throwing', () async {
      final bundle = _MockAssetBundle({
        'assets/india_states_districts.json': 'invalid json',
      });
      final service = IndiaLocationService(bundle: bundle);

      expect(await service.getStates(), isEmpty);
      expect(await service.getDistrictsForState('Punjab'), isEmpty);
    });
  });

  group('Bundled assets/india_states_districts.json Integrity Tests', () {
    test(
      'Loads live asset file and validates all 36 Indian states & UTs',
      () async {
        final service = IndiaLocationService();
        final states = await service.getStates();

        expect(
          states.length,
          36,
          reason: 'Must contain all 28 states and 8 union territories',
        );
        expect(states, contains('Punjab'));
        expect(states, contains('Maharashtra'));
        expect(states, contains('Delhi'));
        expect(states, contains('Tamil Nadu'));
        expect(states, contains('Chandigarh'));
        expect(states, contains('Ladakh'));

        // Check districts for a few key states
        final punjabDistricts = await service.getDistrictsForState('Punjab');
        expect(punjabDistricts, contains('Amritsar'));
        expect(punjabDistricts, contains('Ludhiana'));
        expect(punjabDistricts.length, greaterThanOrEqualTo(20));

        final maharashtraDistricts = await service.getDistrictsForState(
          'Maharashtra',
        );
        expect(maharashtraDistricts, contains('Pune'));
        expect(maharashtraDistricts, contains('Mumbai City'));
      },
    );
  });

  group('BookingWizardViewModel State & Cascading Tests', () {
    test('Initial WizardStateData has empty stateName and null district', () {
      const state = WizardStateData();
      expect(state.stateName, '');
      expect(state.district, isNull);
    });

    test('selectState updates stateName and clears district', () {
      final container = ProviderContainer();
      final notifier = container.read(bookingWizardViewModelProvider.notifier);

      notifier.selectState('Punjab');
      expect(
        container.read(bookingWizardViewModelProvider).stateName,
        'Punjab',
      );
      expect(container.read(bookingWizardViewModelProvider).district, isNull);

      notifier.selectDistrict('Amritsar');
      expect(
        container.read(bookingWizardViewModelProvider).district,
        'Amritsar',
      );

      // Change state to Haryana -> district must be cleared!
      notifier.selectState('Haryana');
      expect(
        container.read(bookingWizardViewModelProvider).stateName,
        'Haryana',
      );
      expect(container.read(bookingWizardViewModelProvider).district, isNull);
    });

    test(
      'copyWith preserves or clears district based on clearDistrict flag',
      () {
        const state = WizardStateData(
          stateName: 'Punjab',
          district: 'Amritsar',
        );
        expect(state.district, 'Amritsar');

        final updatedWithState = state.copyWith(
          stateName: 'Haryana',
          clearDistrict: true,
        );
        expect(updatedWithState.stateName, 'Haryana');
        expect(updatedWithState.district, isNull);

        final updatedWithDistrict = updatedWithState.copyWith(
          district: 'Gurugram',
        );
        expect(updatedWithDistrict.district, 'Gurugram');
      },
    );

    test(
      'Serialization and deserialization roundtrip preserves state and district',
      () {
        const original = WizardStateData(
          currentStep: 2,
          stateName: 'Karnataka',
          district: 'Bengaluru Urban',
        );

        final map = original.toMap();
        expect(map['stateName'], 'Karnataka');
        expect(map['district'], 'Bengaluru Urban');

        final restored = WizardStateData.fromMap(map);
        expect(restored.stateName, 'Karnataka');
        expect(restored.district, 'Bengaluru Urban');
      },
    );
  });

  group('Step 2 Validation Logic Tests', () {
    bool validateStep2(WizardStateData state) {
      if (state.stateName.trim().isEmpty) return false;
      if (state.district == null || state.district!.trim().isEmpty) {
        return false;
      }
      return true;
    }

    test('Step 2 validation fails when stateName is empty', () {
      const state = WizardStateData(stateName: '', district: null);
      expect(validateStep2(state), isFalse);
    });

    test('Step 2 validation fails when district is not selected', () {
      const state = WizardStateData(stateName: 'Punjab', district: null);
      expect(validateStep2(state), isFalse);
    });

    test(
      'Step 2 validation succeeds when both state and district are selected',
      () {
        const state = WizardStateData(
          stateName: 'Punjab',
          district: 'Amritsar',
        );
        expect(validateStep2(state), isTrue);
      },
    );
  });

  group('Step2StateDistrict Widget Tests', () {
    testWidgets('District dropdown is disabled when state is not selected', (
      tester,
    ) async {
      final bundle = _MockAssetBundle({
        'assets/india_states_districts.json': testJson,
      });
      final mockService = IndiaLocationService(bundle: bundle);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            indiaLocationServiceProvider.overrideWithValue(mockService),
            authViewModelProvider.overrideWith(_FakeAuthViewModel.new),
          ],
          child: ScreenUtilPlusInit(
            designSize: const Size(375, 812),
            builder: (context, child) =>
                const MaterialApp(home: Scaffold(body: Step2StateDistrict())),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // State dropdown should be present
      expect(find.byKey(const ValueKey('state_dropdown')), findsOneWidget);

      // District dropdown disabled placeholder should be present
      expect(
        find.byKey(const ValueKey('district_dropdown_disabled')),
        findsOneWidget,
      );
      expect(find.text('Select a state first'), findsOneWidget);
    });

    testWidgets(
      'Selecting a state enables district dropdown with that state districts',
      (tester) async {
        final bundle = _MockAssetBundle({
          'assets/india_states_districts.json': testJson,
        });
        final mockService = IndiaLocationService(bundle: bundle);

        final container = ProviderContainer(
          overrides: [
            indiaLocationServiceProvider.overrideWithValue(mockService),
            authViewModelProvider.overrideWith(_FakeAuthViewModel.new),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ScreenUtilPlusInit(
              designSize: const Size(375, 812),
              builder: (context, child) =>
                  const MaterialApp(home: Scaffold(body: Step2StateDistrict())),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially disabled
        expect(
          find.byKey(const ValueKey('district_dropdown_disabled')),
          findsOneWidget,
        );

        // Select 'Punjab' via viewmodel
        container
            .read(bookingWizardViewModelProvider.notifier)
            .selectState('Punjab');
        await tester.pumpAndSettle();

        // Now active district dropdown for Punjab should be present
        expect(
          find.byKey(const ValueKey('district_dropdown_Punjab_null')),
          findsOneWidget,
        );
        container
            .read(bookingWizardViewModelProvider.notifier)
            .selectDistrict('Amritsar');
        await tester.pumpAndSettle();

        expect(container.read(bookingWizardViewModelProvider).district, 'Amritsar');
        expect(find.text('Amritsar'), findsOneWidget);

        // Changing state to 'Goa' clears old district
        container
            .read(bookingWizardViewModelProvider.notifier)
            .selectState('Goa');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('district_dropdown_Goa_null')),
          findsOneWidget,
        );
        expect(container.read(bookingWizardViewModelProvider).district, isNull);
      },
    );
  });
}

class _MockAssetBundle extends CachingAssetBundle {
  final Map<String, String> _data;
  _MockAssetBundle(this._data);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (_data.containsKey(key)) {
      return _data[key]!;
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    if (_data.containsKey(key)) {
      final bytes = utf8.encode(_data[key]!);
      return ByteData.sublistView(Uint8List.fromList(bytes));
    }
    throw FlutterError('Asset not found: $key');
  }
}
