import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String adminLogin = '/admin-login';

  static const String home = '/home';
  static const String myBookings = '/my-bookings';
  static const String bookingDetail = '/booking-detail';
  static const String wizard = '/wizard';

  static const String adminDashboard = '/admin-dashboard';
  static const String committeeDashboard = '/committee-dashboard';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Login Screen Placeholder'))),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Signup Screen Placeholder')),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminLogin,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Admin Login Screen Placeholder')),
      ),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Applicant Home Placeholder')),
      ),
    ),
    GoRoute(
      path: AppRoutes.myBookings,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('My Bookings Placeholder'))),
    ),
    GoRoute(
      path: AppRoutes.wizard,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Booking Wizard Shell Placeholder')),
      ),
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
        state.matchedLocation == AppRoutes.adminLogin;

    if (user == null && !isAuthRoute) {
      return AppRoutes.login;
    }
    return null;
  },
);
