import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/selected_appointment_provider.dart';
import '../viewmodel/my_bookings_viewmodel.dart';
import 'appointment_detail_screen.dart';

/// Top-level tab destination for the 'Appointment Details' tab.
/// If an appointment is currently selected (or a recent one exists), displays its details.
/// Otherwise, provides an intuitive empty state directing the user to their bookings list.
class AppointmentDetailTabScreen extends ConsumerWidget {
  const AppointmentDetailTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedAppointmentIdProvider);
    final bookingsState = ref.watch(myBookingsViewModelProvider);

    // If an appointment ID was explicitly selected, show it
    if (selectedId != null && selectedId.isNotEmpty) {
      return AppointmentDetailScreen(
        appointmentId: selectedId,
        showBackButton: false,
      );
    }

    // Fallback: check if bookings are loaded and have at least one item
    return bookingsState.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(
            'Appointment Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            'Appointment Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
          ),
        ),
        body: EmptyStateWidget(
          title: 'Unable to load details',
          message: err.toString(),
          icon: Icons.error_outline,
          buttonText: 'View My Bookings',
          onButtonPressed: () => context.go(AppRoutes.myBookings),
        ),
      ),
      data: (bookings) {
        if (bookings.isNotEmpty) {
          // Default to displaying the most recent appointment
          final latestId = bookings.first.id;
          return AppointmentDetailScreen(
            appointmentId: latestId,
            showBackButton: false,
          );
        }

        // No bookings created yet
        return Scaffold(
          appBar: AppBar(title: const Text('Appointment Details')),
          body: Padding(
            padding: EdgeInsets.all(24.w),
            child: EmptyStateWidget(
              title: 'No Appointment Selected',
              message:
                  'You don\'t have any active survey bookings yet. Start a new survey or select a request from My Bookings.',
              icon: Icons.assignment_outlined,
              buttonText: 'Go to My Bookings',
              onButtonPressed: () => context.go(AppRoutes.myBookings),
            ),
          ),
        );
      },
    );
  }
}
