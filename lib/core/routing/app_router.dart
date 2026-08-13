import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/view/applicant_login_screen.dart';
import '../../features/auth/view/applicant_signup_screen.dart';
import '../../features/auth/view/admin_login_screen.dart';
import '../../features/auth/view/email_verification_screen.dart';

import '../../features/applicant_home/view/applicant_shell_screen.dart';
import '../../features/applicant_home/view/home_screen.dart';
import '../../features/my_bookings/view/my_bookings_screen.dart';
import '../../features/my_bookings/view/appointment_detail_tab_screen.dart';
import '../../features/my_bookings/view/appointment_detail_screen.dart';
import '../../features/booking_wizard/view/booking_wizard_screen.dart';
import '../../features/profile/view/profile_screen.dart';

/// Converts a [Stream] into a [ChangeNotifier] so GoRouter re-evaluates
/// its redirect guard whenever the stream emits (e.g. on sign-in/sign-out).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

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

  static const String adminDashboard = '/admin-dashboard';
  static const String committeeDashboard = '/committee-dashboard';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  routes: [
    // Auth Routes
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

    // Stateful Shell Route for Applicant Bottom Navigation
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
              builder: (context, state) => const MyBookingsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.appointmentDetailTab,
              builder: (context, state) => const AppointmentDetailTabScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Full Screen Pushed Routes
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
    GoRoute(
      path: AppRoutes.adminDashboard,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Admin Dashboard Placeholder')),
      ),
    ),
    GoRoute(
      path: AppRoutes.committeeDashboard,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Committee Dashboard Placeholder')),
      ),
    ),
  ],
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isAuthRoute =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.signup ||
        state.matchedLocation == AppRoutes.adminLogin ||
        state.matchedLocation == AppRoutes.verifyEmail;

    if (user == null && !isAuthRoute) {
      return AppRoutes.login;
    }

    // Redirect authenticated + verified users away from auth screens to home.
    if (user != null && user.emailVerified && isAuthRoute) {
      return AppRoutes.home;
    }

    return null;
  },
);
