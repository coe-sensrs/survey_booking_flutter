import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/view/applicant_login_screen.dart';
import '../../features/auth/view/applicant_signup_screen.dart';
import '../../features/auth/view/admin_login_screen.dart';
import '../../features/auth/view/email_verification_screen.dart';

import '../../features/applicant_home/view/applicant_shell_screen.dart';
import '../../features/admin_dashboard/view/admin_shell_screen.dart';
import '../../features/admin_dashboard/view/admin_dashboard_screen.dart';
import '../../features/committee_management/view/committee_management_screen.dart';
import '../../features/committee_management/view/add_committee_member_screen.dart';
import '../../features/admin_appointment_detail/view/admin_appointment_detail_screen.dart';
import '../../features/applicant_home/view/home_screen.dart';
import '../../features/my_bookings/view/my_bookings_screen.dart';
import '../../features/my_bookings/view/appointment_detail_tab_screen.dart';
import '../../features/my_bookings/view/appointment_detail_screen.dart';
import '../../features/booking_wizard/view/booking_wizard_screen.dart';
import '../../features/profile/view/profile_screen.dart';

import '../../features/committee_dashboard/view/committee_shell_screen.dart';
import '../../features/committee_dashboard/view/committee_dashboard_screen.dart';
import '../../features/assigned_tasks/view/assigned_tasks_screen.dart';
import '../../features/committee_review_detail/view/committee_review_detail_screen.dart';

// ---------------------------------------------------------------------------
// Minimal role-only data holder — avoids a full AppUser parse in the router.
// ---------------------------------------------------------------------------
class _AppUserRole {
  final String role;
  const _AppUserRole(this.role);

  factory _AppUserRole.fromMap(Map<String, dynamic> map) =>
      _AppUserRole(map['role'] as String? ?? '');
}

/// A [ChangeNotifier] that subscribes to [FirebaseAuth.userChanges] and
/// resolves the Firestore role after each auth state emission.
///
/// Two-step resolution:
///   1. Wait for the first [userChanges] emission (fixes stale-session race).
///   2. Fetch the Firestore `/users/{uid}` document to read `role`.
///
/// GoRouter's `redirect` blocks on [isLoading] until both steps complete.
class AsyncAuthNotifier extends ChangeNotifier {
  AsyncAuthNotifier() {
    _subscription = FirebaseAuth.instance.userChanges().listen((user) async {
      _user = user;
      _appUserRole = null;

      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (doc.exists && doc.data() != null) {
            _appUserRole = _AppUserRole.fromMap(doc.data()!);
          }
        } catch (_) {
          // Firestore unavailable — treat as unknown role; will re-evaluate
          // on next stream emission or app resume.
          _appUserRole = null;
        }
      }

      // First resolution — let GoRouter redirect to the correct screen,
      // THEN strip the native splash so users never see a flash of /login.
      final wasLoading = _isLoading;
      _isLoading = false;
      notifyListeners();
      if (wasLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FlutterNativeSplash.remove();
        });
      }
    });
  }

  late final StreamSubscription<User?> _subscription;

  bool _isLoading = true;
  User? _user;
  _AppUserRole? _appUserRole;

  /// `true` until the first [userChanges] emission AND Firestore role fetch
  /// have both completed.
  bool get isLoading => _isLoading;

  /// The currently authenticated Firebase [User], or `null` if signed out.
  User? get user => _user;

  /// The Firestore role string (`'applicant'`, `'admin'`, `'committee'`),
  /// or `null` if signed out or fetch failed.
  String? get role => _appUserRole?.role;

  bool get isAdmin => role == 'admin';
  bool get isCommittee => role == 'committee';
  bool get isApplicant => role == 'applicant';
  bool get isStaff => isAdmin || isCommittee;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String adminLogin = '/admin-login';
  static const String verifyEmail = '/verify-email';

  // Applicant Bottom Navigation Destinations
  static const String home = '/home';
  static const String myBookings = '/my-bookings';
  static const String appointmentDetailTab = '/appointment-detail';
  static const String profile = '/profile';

  // Pushed Full-Screen Routes
  static const String appointmentDetail = '/appointment-detail/:id';
  static const String wizard = '/booking-wizard';

  // Admin Bottom Navigation Destinations
  static const String adminDashboard = '/admin-dashboard';
  static const String adminCommitteeManagement = '/admin-committees';
  static const String adminAddMember = '/admin-add-member';
  static const String adminSettings = '/admin-settings';

  static const String adminAppointmentDetail = '/admin-appointment/:id';

  // Committee Bottom Navigation Destinations
  static const String committeeDashboard = '/committee-dashboard';
  static const String committeeTaskQueue = '/committee-tasks';

  // Committee profile tab
  static const String committeeProfile = '/committee-profile';

  // Committee pushed full-screen routes
  static const String committeeReviewDetail = '/committee-review/:id';
  static const String committeeTaskDetail = '/committee-task/:id';
}

/// Single instance, lives for the app lifetime.
final _authNotifier = AsyncAuthNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  refreshListenable: _authNotifier,
  routes: [
    // -------------------------------------------------------------------------
    // Auth Routes
    // -------------------------------------------------------------------------
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const ApplicantLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const ApplicantSignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminLogin,
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        return EmailVerificationScreen(email: email);
      },
    ),

    // -------------------------------------------------------------------------
    // Stateful Shell Route for Applicant Bottom Navigation
    // -------------------------------------------------------------------------
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ApplicantShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.myBookings,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.home);
                },
                child: const MyBookingsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.appointmentDetailTab,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.home);
                },
                child: const AppointmentDetailTabScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.home);
                },
                child: const ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // Full Screen Pushed Routes — Applicant
    // -------------------------------------------------------------------------
    GoRoute(
      path: AppRoutes.appointmentDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AppointmentDetailScreen(appointmentId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.wizard,
      builder: (context, state) => const BookingWizardScreen(),
    ),

    // -------------------------------------------------------------------------
    // Stateful Shell Route for Admin Bottom Navigation
    // -------------------------------------------------------------------------
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AdminShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (context, state) => const AdminDashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminCommitteeManagement,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.adminDashboard);
                },
                child: const CommitteeManagementScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminAddMember,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.adminDashboard);
                },
                child: const AddCommitteeMemberScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminSettings,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.adminDashboard);
                },
                child: const Scaffold(
                  body: Center(child: Text('Admin Settings Placeholder')),
                ),
              ),
            ),
          ],
        ),
      ],
    ),

    // Full Screen Pushed Routes — Admin
    GoRoute(
      path: AppRoutes.adminAppointmentDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AdminAppointmentDetailScreen(appointmentId: id);
      },
    ),

    // -------------------------------------------------------------------------
    // Stateful Shell Route for Committee Member Bottom Navigation
    // -------------------------------------------------------------------------
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return CommitteeShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0 — Reviews
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.committeeDashboard,
              builder: (context, state) => const CommitteeDashboardScreen(),
            ),
          ],
        ),
        // Tab 1 — My Assigned Tasks (resolves the PRD open item)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.committeeTaskQueue,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.committeeDashboard);
                },
                child: const AssignedTasksScreen(),
              ),
            ),
          ],
        ),
        // Tab 2 — Profile (reuses Applicant ProfileScreen — same widget, same ViewModel)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.committeeProfile,
              builder: (context, state) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.go(AppRoutes.committeeDashboard);
                },
                child: const ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // Full Screen Pushed Routes — Committee (review detail + task detail)
    GoRoute(
      path: AppRoutes.committeeReviewDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return CommitteeReviewDetailScreen(appointmentId: id);
      },
    ),
    // Task detail reuses the review detail screen (read-only, no action buttons)
    GoRoute(
      path: AppRoutes.committeeTaskDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        // CommitteeReviewDetailScreen is read-only when status is task_assigned
        // (action buttons are hidden by the isResolved guard in the view).
        return CommitteeReviewDetailScreen(appointmentId: id);
      },
    ),
  ],

  // ---------------------------------------------------------------------------
  // Global redirect — role-based routing with loading guard
  // ---------------------------------------------------------------------------
  redirect: (context, state) {
    // While auth + Firestore role are still resolving, hold the user on
    // the login screen (which acts as a lightweight splash).  Returning
    // null here would let the initialLocation render — causing a flash
    // of the home/dashboard screen before the redirect fires.
    if (_authNotifier.isLoading) {
      return state.matchedLocation == AppRoutes.login ? null : AppRoutes.login;
    }

    final user = _authNotifier.user;
    final role = _authNotifier.role;
    final loc = state.matchedLocation;

    // -------------------------------------------------------------------------
    // Route classification helpers
    // -------------------------------------------------------------------------
    final isAuthRoute =
        loc == AppRoutes.login ||
        loc == AppRoutes.signup ||
        loc == AppRoutes.adminLogin ||
        loc == AppRoutes.verifyEmail;

    // All applicant-side routes (shell + pushed)
    final isApplicantRoute =
        loc == AppRoutes.home ||
        loc == AppRoutes.myBookings ||
        loc == AppRoutes.appointmentDetailTab ||
        loc == AppRoutes.profile ||
        loc.startsWith('/appointment-detail') ||
        loc == AppRoutes.wizard;

    // All admin-only routes
    final isAdminRoute =
        loc == AppRoutes.adminDashboard ||
        loc == AppRoutes.adminCommitteeManagement ||
        loc == AppRoutes.adminAddMember ||
        loc == AppRoutes.adminSettings ||
        loc.startsWith('/admin-appointment');

    // All committee-only routes
    final isCommitteeRoute =
        loc == AppRoutes.committeeDashboard ||
        loc == AppRoutes.committeeTaskQueue ||
        loc == AppRoutes.committeeProfile ||
        loc.startsWith('/committee-review') ||
        loc.startsWith('/committee-task');

    final isStaffRoute = isAdminRoute || isCommitteeRoute;

    // -------------------------------------------------------------------------
    // 1. Unauthenticated — send to login
    // -------------------------------------------------------------------------
    if (user == null && !isAuthRoute) {
      return AppRoutes.login;
    }

    // -------------------------------------------------------------------------
    // 2. Authenticated — role-based routing
    // -------------------------------------------------------------------------
    if (user != null) {
      // --- Admin ---
      if (role == 'admin') {
        // Admin hitting auth routes or applicant routes → admin dashboard
        if (isAuthRoute || isApplicantRoute || isCommitteeRoute) {
          return AppRoutes.adminDashboard;
        }
      }

      // --- Committee Member ---
      if (role == 'committee') {
        // Committee hitting auth routes, applicant routes, or admin-only routes
        // → committee dashboard
        if (isAuthRoute || isApplicantRoute || isAdminRoute) {
          return AppRoutes.committeeDashboard;
        }
      }

      // --- Applicant ---
      if (role == 'applicant') {
        // Unverified applicant → force to verification screen
        if (!user.emailVerified) {
          if (loc != AppRoutes.verifyEmail) {
            return '${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(user.email ?? '')}';
          }
          return null;
        }
        // Verified applicant hitting auth routes → home
        if (isAuthRoute) {
          return AppRoutes.home;
        }
        // Applicant hitting any staff route → bounce to home
        if (isStaffRoute) {
          return AppRoutes.home;
        }
      }

      // Unknown/null role (Firestore fetch failed) — stay put, will retry
    }

    return null;
  },
);
