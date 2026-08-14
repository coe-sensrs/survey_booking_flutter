import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/survey_type.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step8Review extends ConsumerStatefulWidget {
  const Step8Review({super.key});

  @override
  ConsumerState<Step8Review> createState() => _Step8ReviewState();
}

class _Step8ReviewState extends ConsumerState<Step8Review> {
  bool _isSubmitting = false;

  Future<void> _onConfirmBooking() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bookingWizardViewModelProvider.notifier).submitBooking();
      AppSnackbar.showGlobalSuccess(
        title: 'Booking Confirmed',
        message: 'Appointment submitted successfully!',
      );

      // Advance to step 9 (Acknowledgement)
      ref.read(bookingWizardViewModelProvider.notifier).setStep(9);
    } catch (e) {
      AppSnackbar.showGlobalError(
        title: 'Submission Failed',
        message: 'Booking submission failed: $e',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingWizardViewModelProvider);

    final surveyName = state.surveyType == SurveyType.other.code
        ? (state.customSurveyName ?? 'Other')
        : SurveyType.fromCode(state.surveyType ?? '').label;

    final formattedDate = state.startDate != null
        ? DateFormat('EEEE, dd MMMM yyyy').format(state.startDate!)
        : 'Not selected';

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Confirm Booking',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Please review all details carefully before submitting your booking.',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 20.h),

          // Section 1: Survey Type
          _buildSummarySection(
            title: '1. Survey Type',
            stepNum: 1,
            items: ['Type: $surveyName'],
          ),

          SizedBox(height: 12.h),

          // Section 2: State & District
          _buildSummarySection(
            title: '2. State & District',
            stepNum: 2,
            items: [
              'State: ${state.stateName}',
              'District: ${state.district ?? "Not selected"}',
            ],
          ),

          SizedBox(height: 12.h),

          // Section 3: XEN Details
          _buildSummarySection(
            title: '3. XEN Contact Details',
            stepNum: 3,
            items: [
              'Name: ${state.xenName ?? "-"}',
              'Mobile: ${state.xenMobile ?? "-"}',
              'Email: ${state.xenEmail ?? "-"}',
            ],
          ),

          SizedBox(height: 12.h),

          // Section 4: Survey Area & Map File
          _buildSummarySection(
            title: '4. Survey Area & KML File',
            stepNum: 4,
            items: [
              'Area Name: ${state.areaName ?? "-"}',
              'KML/KMZ File: ${state.kmlFileName ?? "None"}',
            ],
          ),

          SizedBox(height: 12.h),

          // Section 5: Date
          _buildSummarySection(
            title: '5. Preferred Start Date',
            stepNum: 5,
            items: ['Date: $formattedDate'],
          ),

          SizedBox(height: 12.h),

          // Section 6: Logistics
          _buildSummarySection(
            title: '6. Logistics & Personnel',
            stepNum: 6,
            items: [
              'Coordinator: ${state.coordinatorName ?? "-"} (${state.coordinatorDesignation ?? "-"})',
              'Driver: ${state.driverName ?? "-"} (${state.driverMobile ?? "-"})',
              'Vehicle: ${state.vehicleModel ?? "-"} (${state.vehicleNumber ?? "-"})',
            ],
          ),

          SizedBox(height: 12.h),

          // Section 7: Permissions
          _buildSummarySection(
            title: '7. Permission Documents',
            stepNum: 7,
            items: ['Attached Documents: ${state.permissionDocs.length} files'],
          ),

          SizedBox(height: 24.h),

          AppButton(
            text: 'Confirm & Submit Booking',
            isLoading: _isSubmitting,
            onPressed: _onConfirmBooking,
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required String title,
    required int stepNum,
    required List<String> items,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit'),
                  onPressed: () {
                    ref
                        .read(bookingWizardViewModelProvider.notifier)
                        .setStep(stepNum);
                  },
                ),
              ],
            ),
            const Divider(height: 12),
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  item,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
