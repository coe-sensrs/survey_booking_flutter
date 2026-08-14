import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedAppointmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? appointmentId) {
    state = appointmentId;
  }
}

/// Holds the ID of the appointment currently selected to view in the Appointment Detail tab.
final selectedAppointmentIdProvider =
    NotifierProvider<SelectedAppointmentNotifier, String?>(
      SelectedAppointmentNotifier.new,
    );
