import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_desk/features/campus_visit/view/campus_visit_form_screen.dart';
import 'package:survey_desk/features/campus_visit/viewmodel/campus_visit_viewmodel.dart';

void main() {
  group('CampusVisitViewModel AutoDispose and Reset Tests', () {
    test('Initial state is completely empty and clean', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(campusVisitViewModelProvider);
      expect(state.fullName, isEmpty);
      expect(state.mobileNumber, isEmpty);
      expect(state.email, isEmpty);
      expect(state.visitDate, isNull);
      expect(state.session, isNull);
      expect(state.delegationSize, equals(1));
      expect(state.purpose, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.successVisitId, isNull);
    });

    test('Calling reset() clears all modified fields back to fresh state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(campusVisitViewModelProvider.notifier);
      notifier.setFullName('Test Applicant');
      notifier.setMobileNumber('9876543210');
      notifier.setEmail('test@iitrpr.ac.in');
      notifier.setSession('morning');
      notifier.setDelegationSize(5);
      notifier.setVisitDate(DateTime(2026, 11, 15));
      notifier.setPurpose(
        'Educational exploration and robotics laboratory tour',
      );

      var state = container.read(campusVisitViewModelProvider);
      expect(state.fullName, equals('Test Applicant'));
      expect(state.session, equals('morning'));
      expect(state.delegationSize, equals(5));
      expect(state.visitDate, isNotNull);

      // Now reset
      notifier.reset();

      state = container.read(campusVisitViewModelProvider);
      expect(state.fullName, isEmpty);
      expect(state.mobileNumber, isEmpty);
      expect(state.email, isEmpty);
      expect(state.visitDate, isNull);
      expect(state.session, isNull);
      expect(state.delegationSize, equals(1));
      expect(state.purpose, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.successVisitId, isNull);
    });

    test(
      'autoDispose cleans up state when screen exits (listener disposed)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Screen opens: listens to provider
        var subscription = container.listen(
          campusVisitViewModelProvider,
          (_, _) {},
          fireImmediately: true,
        );

        // User enters details
        container
            .read(campusVisitViewModelProvider.notifier)
            .setFullName('Dr. Sharma');
        container
            .read(campusVisitViewModelProvider.notifier)
            .setSession('afternoon');
        container
            .read(campusVisitViewModelProvider.notifier)
            .setDelegationSize(8);
        container
            .read(campusVisitViewModelProvider.notifier)
            .setVisitDate(DateTime(2026, 12, 1));
        container
            .read(campusVisitViewModelProvider.notifier)
            .setPurpose('Academic visit regarding drone survey methodology');

        expect(
          container.read(campusVisitViewModelProvider).fullName,
          equals('Dr. Sharma'),
        );
        expect(
          container.read(campusVisitViewModelProvider).session,
          equals('afternoon'),
        );
        expect(
          container.read(campusVisitViewModelProvider).delegationSize,
          equals(8),
        );

        // Screen exits: subscription is closed
        subscription.close();
        await container.pump();

        // Screen reopened: user taps 'Book Campus Visit' again
        subscription = container.listen(
          campusVisitViewModelProvider,
          (_, _) {},
          fireImmediately: true,
        );

        // Fresh state must be returned
        final freshState = container.read(campusVisitViewModelProvider);
        expect(freshState.fullName, isEmpty);
        expect(freshState.mobileNumber, isEmpty);
        expect(freshState.email, isEmpty);
        expect(freshState.visitDate, isNull);
        expect(freshState.session, isNull);
        expect(freshState.delegationSize, equals(1));
        expect(freshState.purpose, isEmpty);
        expect(freshState.errorMessage, isNull);
        expect(freshState.successVisitId, isNull);

        subscription.close();
      },
    );

    testWidgets('Screen resets all details when popped and reopened', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilPlusInit(
            designSize: const Size(375, 812),
            builder: (context, child) => MaterialApp(
              navigatorKey: navKey,
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => const CampusVisitFormScreen(),
                        ),
                      );
                    },
                    child: const Text('Open Form'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the form
      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      // Verify form is open
      expect(find.text('Book Campus Visit'), findsOneWidget);
      expect(find.text('Tap to select a date'), findsOneWidget);
      expect(find.text('person'), findsOneWidget);

      // Enter details
      await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
      await tester.pumpAndSettle();

      // Tap Afternoon Session
      await tester.tap(find.text('Afternoon Session'));
      await tester.pumpAndSettle();

      // Scroll down and increment delegation size
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('people'), findsOneWidget);

      // Pop the screen (simulate user exiting the screen)
      navKey.currentState!.pop();
      await tester.pumpAndSettle();

      // Verify back on home
      expect(find.text('Open Form'), findsOneWidget);
      expect(find.text('Book Campus Visit'), findsNothing);

      // User clicks 'Open Form' (Book Campus Visit) again
      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      // Verify FRESH screen!
      expect(find.text('Book Campus Visit'), findsOneWidget);
      expect(find.text('Tap to select a date'), findsOneWidget);
      expect(find.text('person'), findsOneWidget);
      // Name field should be empty, not 'John Doe'
      expect(find.text('John Doe'), findsNothing);
      // Delegation size should be 'person', not 'people'
      expect(find.text('people'), findsNothing);
      // Afternoon session checkmark should be gone
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
