import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:survey_desk/core/constants/campus_visit_status.dart';
import 'package:survey_desk/core/models/app_user.dart';
import 'package:survey_desk/core/models/appointment.dart';
import 'package:survey_desk/core/models/campus_visit.dart';
import 'package:survey_desk/core/providers/core_providers.dart';
import 'package:survey_desk/core/repositories/campus_visit_repository.dart';
import 'package:survey_desk/core/routing/app_router.dart';
import 'package:survey_desk/core/widgets/campus_visit_indicator_pill.dart';
import 'package:survey_desk/features/admin_dashboard/view/admin_dashboard_screen.dart';
import 'package:survey_desk/features/admin_dashboard/viewmodel/admin_dashboard_viewmodel.dart';
import 'package:survey_desk/features/admin_visits/view/admin_visits_screen.dart';
import 'package:survey_desk/features/admin_visits/viewmodel/admin_visits_viewmodel.dart';
import 'package:survey_desk/features/applicant_home/view/home_screen.dart';
import 'package:survey_desk/features/applicant_home/viewmodel/home_viewmodel.dart';
import 'package:survey_desk/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:survey_desk/features/booking_wizard/viewmodel/booking_wizard_viewmodel.dart';
import 'package:survey_desk/features/my_visits/view/my_visits_screen.dart';
import 'package:survey_desk/features/my_visits/viewmodel/my_visits_viewmodel.dart';

class _FakeCampusVisitRepository implements CampusVisitRepository {
  final _adminController = StreamController<List<CampusVisit>>.broadcast();
  final _applicantController = StreamController<List<CampusVisit>>.broadcast();

  List<CampusVisit> _latestAdminVisits = const [];
  List<CampusVisit> _latestApplicantVisits = const [];

  void emitAdminVisits(List<CampusVisit> visits) {
    _latestAdminVisits = visits;
    _adminController.add(visits);
  }

  void emitApplicantVisits(List<CampusVisit> visits) {
    _latestApplicantVisits = visits;
    _applicantController.add(visits);
  }

  @override
  Stream<List<CampusVisit>> watchAllVisits({String? statusFilter}) {
    List<CampusVisit> filterList(List<CampusVisit> items) {
      if (statusFilter == null || statusFilter.isEmpty) return items;
      return items.where((v) => v.status.code == statusFilter).toList();
    }

    return Stream.multi((controller) {
      controller.add(filterList(_latestAdminVisits));
      final sub = _adminController.stream.listen(
        (items) => controller.add(filterList(items)),
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<CampusVisit>> watchVisitsForApplicant(String applicantId) {
    List<CampusVisit> filterList(List<CampusVisit> items) =>
        items.where((v) => v.applicantId == applicantId).toList();

    return Stream.multi((controller) {
      controller.add(filterList(_latestApplicantVisits));
      final sub = _applicantController.stream.listen(
        (items) => controller.add(filterList(items)),
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<CampusVisit?> getVisitById(String visitId) async => null;

  @override
  Future<void> reviewVisit({
    required String visitId,
    required String action,
    String? reviewNote,
  }) async {}

  @override
  Future<String> submitVisit({
    required String applicantName,
    required String applicantMobile,
    required String applicantEmail,
    required DateTime visitDate,
    required String session,
    required int delegationSize,
    required String purpose,
    required String idempotencyKey,
  }) async => 'visit_1';

  void dispose() {
    _adminController.close();
    _applicantController.close();
  }
}

class _FakeAuthViewModel extends AuthViewModel {
  final AppUser? _user;
  _FakeAuthViewModel(this._user);

  @override
  FutureOr<AppUser?> build() => _user;
}

class _FakeAdminDashboardViewModel extends AdminDashboardViewModel {
  @override
  AdminDashboardState build() =>
      const AdminDashboardState(appointments: AsyncData(<Appointment>[]));

  @override
  Future<void> refresh() async {}
}

class _FakeHomeViewModel extends HomeViewModel {
  @override
  Future<HomeDashboardData> build() async =>
      const HomeDashboardData(recentRequests: [], recentActivity: []);

  @override
  Future<void> refresh() async {}
}

class _FakeBookingWizardViewModel extends BookingWizardViewModel {
  @override
  WizardStateData build() => const WizardStateData();

  @override
  bool get hasDraft => false;
}

CampusVisit _makeVisit({
  required String id,
  String applicantId = 'user_1',
  CampusVisitStatus status = CampusVisitStatus.pending,
  DateTime? updatedAt,
}) {
  final ts = updatedAt ?? DateTime(2026, 11, 20, 10);
  return CampusVisit(
    id: id,
    applicantId: applicantId,
    applicantName: 'Test Applicant',
    applicantMobile: '9876543210',
    applicantEmail: 'applicant@example.com',
    visitDate: DateTime(2026, 12, 5),
    session: 'morning',
    delegationSize: 4,
    purpose: 'Campus robotics laboratory tour and academic collaboration',
    idempotencyKey: 'key_$id',
    status: status,
    reviewNote: status == CampusVisitStatus.rejected ? 'Holiday on campus' : null,
    createdAt: DateTime(2026, 11, 18, 9),
    updatedAt: ts,
  );
}

AppUser _makeUser({required String uid, required String role}) {
  final now = DateTime(2026, 11, 1);
  return AppUser(
    uid: uid,
    role: role,
    fullName: role == 'admin' ? 'Admin User' : 'Applicant User',
    email: '$role@example.com',
    phone: '9876543210',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Campus Visit Indicator Providers', () {
    test(
      'Admin indicator tracks pending count and clears unseen dot after markPendingVisitsSeen',
      () async {
        final fakeRepo = _FakeCampusVisitRepository();
        addTearDown(fakeRepo.dispose);

        final container = ProviderContainer(
          overrides: [
            campusVisitRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        // Keep provider alive
        final sub = container.listen(
          adminCampusVisitIndicatorProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await Future<void>.delayed(Duration.zero);
        await container.pump();
        expect(
          container.read(adminCampusVisitIndicatorProvider),
          const AdminCampusVisitIndicatorState.empty(),
        );

        // 1. Applicant books a visit
        final visit1 = _makeVisit(id: 'v1', status: CampusVisitStatus.pending);
        fakeRepo.emitAdminVisits([visit1]);
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        var state = container.read(adminCampusVisitIndicatorProvider);
        expect(state.pendingCount, 1);
        expect(state.unseenCount, 1);
        expect(state.hasPending, isTrue);
        expect(state.hasUnseen, isTrue);

        // 2. Admin opens AdminVisitsScreen -> marks pending visits seen
        container
            .read(adminSeenVisitIdsProvider.notifier)
            .markPendingVisitsSeen([visit1]);
        await container.pump();

        state = container.read(adminCampusVisitIndicatorProvider);
        expect(state.pendingCount, 1); // stays visible until reviewed
        expect(state.unseenCount, 0); // new dot cleared
        expect(state.hasPending, isTrue);
        expect(state.hasUnseen, isFalse);

        // 3. Another visit is requested
        final visit2 = _makeVisit(id: 'v2', status: CampusVisitStatus.pending);
        fakeRepo.emitAdminVisits([visit2, visit1]);
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        state = container.read(adminCampusVisitIndicatorProvider);
        expect(state.pendingCount, 2);
        expect(state.unseenCount, 1);
        expect(state.hasUnseen, isTrue);

        // 4. All visits reviewed -> pending disappears
        fakeRepo.emitAdminVisits([
          _makeVisit(id: 'v1', status: CampusVisitStatus.approved),
          _makeVisit(id: 'v2', status: CampusVisitStatus.rejected),
        ]);
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        state = container.read(adminCampusVisitIndicatorProvider);
        expect(state.pendingCount, 0);
        expect(state.unseenCount, 0);
        expect(state.hasPending, isFalse);
      },
    );

    test(
      'Applicant indicator shows unread approved/rejected updates and clears when marked seen',
      () async {
        final fakeRepo = _FakeCampusVisitRepository();
        addTearDown(fakeRepo.dispose);

        final applicant = _makeUser(uid: 'user_1', role: 'applicant');
        final container = ProviderContainer(
          overrides: [
            campusVisitRepositoryProvider.overrideWithValue(fakeRepo),
            authViewModelProvider.overrideWith(
              () => _FakeAuthViewModel(applicant),
            ),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          applicantCampusVisitIndicatorProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await container.read(authViewModelProvider.future);
        await container.pump();

        // Pending visit should not trigger unread badge
        final pendingVisit = _makeVisit(
          id: 'v1',
          status: CampusVisitStatus.pending,
        );
        fakeRepo.emitApplicantVisits([pendingVisit]);
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        var state = container.read(applicantCampusVisitIndicatorProvider);
        expect(state.hasUnread, isFalse);

        // Admin approves visit
        final approvedVisit = _makeVisit(
          id: 'v1',
          status: CampusVisitStatus.approved,
          updatedAt: DateTime(2026, 11, 21, 11),
        );
        fakeRepo.emitApplicantVisits([approvedVisit]);
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        state = container.read(applicantCampusVisitIndicatorProvider);
        expect(state.unseenApprovedCount, 1);
        expect(state.unseenRejectedCount, 0);
        expect(state.hasUnread, isTrue);

        // Applicant opens MyVisitsScreen -> marks seen
        container
            .read(applicantSeenVisitsProvider.notifier)
            .markReviewedVisitsSeen('user_1', [approvedVisit]);
        await container.pump();

        state = container.read(applicantCampusVisitIndicatorProvider);
        expect(state.hasUnread, isFalse);

        // Second visit gets rejected -> rejected indicator appears
        final rejectedVisit = _makeVisit(
          id: 'v2',
          status: CampusVisitStatus.rejected,
          updatedAt: DateTime(2026, 11, 22, 12),
        );
        fakeRepo.emitApplicantVisits([rejectedVisit, approvedVisit]);
        await Future<void>.delayed(Duration.zero);
        await container.pump();

        state = container.read(applicantCampusVisitIndicatorProvider);
        expect(state.unseenApprovedCount, 0);
        expect(state.unseenRejectedCount, 1);
        expect(state.hasUnread, isTrue);
      },
    );
  });

  group('Campus Visit Indicator Widgets', () {
    testWidgets(
      'Admin dashboard banner shows pending + new indicator and clears new dot after opening AdminVisitsScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1125, 2436);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeCampusVisitRepository();
        addTearDown(fakeRepo.dispose);

        final visit1 = _makeVisit(id: 'v1', status: CampusVisitStatus.pending);
        fakeRepo.emitAdminVisits([visit1]);

        final router = GoRouter(
          initialLocation: AppRoutes.adminDashboard,
          routes: [
            GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (_, _) => const AdminDashboardScreen(),
            ),
            GoRoute(
              path: AppRoutes.adminVisits,
              builder: (_, _) => const AdminVisitsScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              campusVisitRepositoryProvider.overrideWithValue(fakeRepo),
              adminDashboardViewModelProvider.overrideWith(
                () => _FakeAdminDashboardViewModel(),
              ),
            ],
            child: ScreenUtilPlusInit(
              designSize: const Size(375, 812),
              builder: (context, child) => MaterialApp.router(
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Campus Visits Management'), findsOneWidget);
        expect(find.text('1 Pending'), findsOneWidget);
        expect(find.text('1 new request awaiting review'), findsOneWidget);

        // Tap banner to open AdminVisitsScreen
        await tester.tap(find.text('Campus Visits Management'));
        await tester.pumpAndSettle();
        expect(find.text('Campus Visit Queue'), findsOneWidget);

        // Navigate back to dashboard -> unseen text cleared, pending count remains
        router.pop();
        await tester.pumpAndSettle();

        expect(find.text('1 Pending'), findsOneWidget);
        expect(find.text('1 pending request to review'), findsOneWidget);
        expect(find.text('1 new request awaiting review'), findsNothing);

        // Approve the visit -> pending pill disappears
        fakeRepo.emitAdminVisits([
          _makeVisit(id: 'v1', status: CampusVisitStatus.approved),
        ]);
        await tester.pumpAndSettle();

        expect(find.text('1 Pending'), findsNothing);
        expect(
          find.text('Review and approve incoming campus delegation visit requests'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Applicant home card shows Approved/Rejected indicator and clears after opening MyVisitsScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1125, 2436);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeCampusVisitRepository();
        addTearDown(fakeRepo.dispose);

        final applicant = _makeUser(uid: 'user_1', role: 'applicant');
        final approvedVisit = _makeVisit(
          id: 'v1',
          status: CampusVisitStatus.approved,
          updatedAt: DateTime(2026, 11, 21, 10),
        );
        fakeRepo.emitApplicantVisits([approvedVisit]);

        final router = GoRouter(
          initialLocation: AppRoutes.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const HomeScreen(),
            ),
            GoRoute(
              path: AppRoutes.myVisits,
              builder: (_, _) => const MyVisitsScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              campusVisitRepositoryProvider.overrideWithValue(fakeRepo),
              authViewModelProvider.overrideWith(
                () => _FakeAuthViewModel(applicant),
              ),
              homeViewModelProvider.overrideWith(() => _FakeHomeViewModel()),
              bookingWizardViewModelProvider.overrideWith(
                () => _FakeBookingWizardViewModel(),
              ),
            ],
            child: ScreenUtilPlusInit(
              designSize: const Size(375, 812),
              builder: (context, child) => MaterialApp.router(
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Campus Visits'), findsOneWidget);
        expect(find.text('Approved'), findsOneWidget);
        expect(find.text('Tap to view decision'), findsOneWidget);

        // Tap card to open MyVisitsScreen
        await tester.tap(find.text('My Campus Visits'));
        await tester.pumpAndSettle();
        expect(find.text('Campus Visits'), findsOneWidget);

        // Return to HomeScreen -> indicator is cleared
        router.pop();
        await tester.pumpAndSettle();

        expect(find.text('Approved'), findsNothing);
        expect(find.text('Track review status'), findsOneWidget);

        // Admin rejects another visit -> Rejected indicator appears
        fakeRepo.emitApplicantVisits([
          _makeVisit(
            id: 'v2',
            status: CampusVisitStatus.rejected,
            updatedAt: DateTime(2026, 11, 22, 14),
          ),
          approvedVisit,
        ]);
        await tester.pumpAndSettle();

        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('Tap to view decision'), findsOneWidget);
      },
    );

    testWidgets(
      'Responsive stress: AdminDashboardScreen and AdminVisitsScreen at 320dp with 99+ counts',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2.0; // 320x568 logical
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeCampusVisitRepository();
        addTearDown(fakeRepo.dispose);

        final manyPending = List.generate(
          105,
          (i) => _makeVisit(id: 'p_$i', status: CampusVisitStatus.pending),
        );
        fakeRepo.emitAdminVisits(manyPending);

        final router = GoRouter(
          initialLocation: AppRoutes.adminDashboard,
          routes: [
            GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (_, _) => const AdminDashboardScreen(),
            ),
            GoRoute(
              path: AppRoutes.adminVisits,
              builder: (_, _) => const AdminVisitsScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              campusVisitRepositoryProvider.overrideWithValue(fakeRepo),
              adminDashboardViewModelProvider.overrideWith(
                () => _FakeAdminDashboardViewModel(),
              ),
            ],
            child: ScreenUtilPlusInit(
              designSize: const Size(375, 812),
              builder: (context, child) => MaterialApp.router(
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('99+ Pending'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Campus Visits Management'));
        await tester.pumpAndSettle();
        expect(find.text('Campus Visit Queue'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Responsive stress: HomeScreen and MyVisitsScreen at 320dp with mixed updates',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2.0; // 320x568 logical
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeCampusVisitRepository();
        addTearDown(fakeRepo.dispose);

        final applicant = _makeUser(uid: 'user_1', role: 'applicant');
        fakeRepo.emitApplicantVisits([
          _makeVisit(
            id: 'a1',
            status: CampusVisitStatus.approved,
            updatedAt: DateTime(2026, 11, 21),
          ),
          _makeVisit(
            id: 'r1',
            status: CampusVisitStatus.rejected,
            updatedAt: DateTime(2026, 11, 22),
          ),
        ]);

        final router = GoRouter(
          initialLocation: AppRoutes.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const HomeScreen(),
            ),
            GoRoute(
              path: AppRoutes.myVisits,
              builder: (_, _) => const MyVisitsScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              campusVisitRepositoryProvider.overrideWithValue(fakeRepo),
              authViewModelProvider.overrideWith(
                () => _FakeAuthViewModel(applicant),
              ),
              homeViewModelProvider.overrideWith(() => _FakeHomeViewModel()),
              bookingWizardViewModelProvider.overrideWith(
                () => _FakeBookingWizardViewModel(),
              ),
            ],
            child: ScreenUtilPlusInit(
              designSize: const Size(375, 812),
              builder: (context, child) => MaterialApp.router(
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 Updates'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('My Campus Visits'));
        await tester.pumpAndSettle();
        expect(find.text('Campus Visits'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CampusVisitIndicatorPill scales cleanly under tight constraints and 2.0x text scaling',
      (tester) async {
        await tester.pumpWidget(
          ScreenUtilPlusInit(
            designSize: const Size(375, 812),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: const MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 68,
                      child: CampusVisitIndicatorPill(
                        label: '99+ Pending',
                        color: Colors.orange,
                        showDot: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('99+ Pending'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
