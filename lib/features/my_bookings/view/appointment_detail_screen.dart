import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/constants/survey_type.dart';
import '../../../core/models/appointment.dart';
import '../../../core/providers/core_providers.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../viewmodel/my_bookings_viewmodel.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  final bool showBackButton;

  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    this.showBackButton = true,
  });

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  final _replyController = TextEditingController();
  bool _isSubmittingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      AppSnackbar.showError(
        context,
        title: 'Validation Error',
        message: 'Please enter a reply message.',
      );
      return;
    }

    setState(() => _isSubmittingReply = true);
    try {
      await ref
          .read(myBookingsViewModelProvider.notifier)
          .submitClarificationReply(widget.appointmentId, text);
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          title: 'Reply Sent',
          message: 'Clarification reply submitted successfully!',
        );
      }
      _replyController.clear();
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Submission Failed',
          message: 'Failed to submit reply: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(appointmentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Appointment Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        automaticallyImplyLeading: widget.showBackButton,
      ),
      body: FutureBuilder<Appointment?>(
        future: repo.getAppointmentById(widget.appointmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const EmptyStateWidget(
              title: 'Appointment Not Found',
              message: 'Could not load details for this appointment.',
              icon: Icons.search_off,
            );
          }

          final appointment = snapshot.data!;
          final surveyTitle = appointment.surveyType == SurveyType.other
              ? (appointment.customSurveyName ?? 'Other Survey')
              : appointment.surveyType.label;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Status Card
                Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.15)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                surveyTitle,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildStatusBadge(context, appointment.status),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'ID: ${appointment.id}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Rejection or Clarification Note Box
                if (appointment.status == AppointmentStatus.rejected &&
                    appointment.rejectionReason != null)
                  _buildAlertCard(
                    title: 'Rejection Reason',
                    message: appointment.rejectionReason!,
                    color: Colors.red,
                    icon: Icons.cancel,
                  ),

                if (appointment.status ==
                        AppointmentStatus.clarificationRequested &&
                    appointment.clarificationNote != null) ...[
                  _buildAlertCard(
                    title: 'Clarification Requested by Reviewer',
                    message: appointment.clarificationNote!,
                    color: Colors.orange,
                    icon: Icons.help_outline,
                  ),
                  SizedBox(height: 12.h),

                  if (appointment.clarificationReply != null)
                    _buildAlertCard(
                      title: 'Your Reply',
                      message: appointment.clarificationReply!,
                      color: Colors.blue,
                      icon: Icons.reply,
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit Clarification Reply',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            AppTextField(
                              label: 'Your Response (max 500 chars)',
                              controller: _replyController,
                              maxLines: 3,
                            ),
                            SizedBox(height: 12.h),
                            AppButton(
                              text: 'Submit Reply',
                              isLoading: _isSubmittingReply,
                              onPressed: _submitReply,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                SizedBox(height: 16.h),

                // Survey Location & XEN Details
                _buildDetailSection(
                  title: 'Survey Area & Contact',
                  icon: Icons.location_on,
                  items: [
                    'State: ${appointment.state}',
                    'District: ${appointment.district}',
                    'Area Name: ${appointment.areaName}',
                    'XEN Name: ${appointment.xenDetails.name}',
                    'XEN Mobile: ${appointment.xenDetails.mobile}',
                    'XEN Email: ${appointment.xenDetails.email}',
                  ],
                ),

                SizedBox(height: 16.h),

                // KML File Section
                _buildDetailSection(
                  title: 'Survey Area Map File (KML/KMZ)',
                  icon: Icons.map,
                  items: [
                    'File Name: ${appointment.kmlFile.originalFileName}',
                    'File Type: ${appointment.kmlFile.fileType.toUpperCase()}',
                    'File Size: ${(appointment.kmlFile.sizeBytes / 1024).toStringAsFixed(1)} KB',
                  ],
                ),

                SizedBox(height: 16.h),

                // Dates Section
                _buildDetailSection(
                  title: 'Dates',
                  icon: Icons.calendar_month,
                  items: [
                    'Requested Start Date: ${DateFormat('dd MMM yyyy').format(appointment.preferredDate)}',
                    if (appointment.confirmedDate != null)
                      'Confirmed Date: ${DateFormat('dd MMM yyyy').format(appointment.confirmedDate!)}',
                  ],
                ),

                SizedBox(height: 16.h),

                // Logistics Section
                _buildDetailSection(
                  title: 'Logistics & Personnel',
                  icon: Icons.directions_car,
                  items: [
                    'Coordinator: ${appointment.logistics.coordinatorName} (${appointment.logistics.coordinatorDesignation})',
                    'Driver: ${appointment.logistics.driverName} (${appointment.logistics.driverMobile})',
                    'Vehicle: ${appointment.logistics.vehicleModel} (${appointment.logistics.vehicleNumber})',
                  ],
                ),

                SizedBox(height: 16.h),

                // Permission Documents
                _buildDetailSection(
                  title:
                      'Permission Documents (${appointment.permissionDocuments.length})',
                  icon: Icons.folder,
                  items: appointment.permissionDocuments
                      .map(
                        (doc) =>
                            '• ${doc.originalFileName} (${doc.fileType.toUpperCase()})',
                      )
                      .toList(),
                ),

                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
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
                Icon(
                  icon,
                  size: 18.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, AppointmentStatus status) {
    Color bg;
    Color fg;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case AppointmentStatus.approved:
      case AppointmentStatus.taskAssigned:
        bg = isDark
            ? Colors.green.withValues(alpha: 0.25)
            : Colors.green.shade100;
        fg = isDark ? const Color(0xFF81C784) : Colors.green.shade800;
        break;
      case AppointmentStatus.rejected:
        bg = isDark ? Colors.red.withValues(alpha: 0.25) : Colors.red.shade100;
        fg = isDark ? const Color(0xFFE57373) : Colors.red.shade800;
        break;
      case AppointmentStatus.clarificationRequested:
        bg = isDark
            ? Colors.orange.withValues(alpha: 0.25)
            : Colors.orange.shade100;
        fg = isDark ? const Color(0xFFFFB74D) : Colors.orange.shade800;
        break;
      case AppointmentStatus.underReview:
        bg = isDark
            ? Colors.blue.withValues(alpha: 0.25)
            : Colors.blue.shade100;
        fg = isDark ? const Color(0xFF64B5F6) : Colors.blue.shade800;
        break;
      case AppointmentStatus.pendingAssignment:
        bg = isDark
            ? Colors.grey.withValues(alpha: 0.25)
            : Colors.grey.shade200;
        fg = isDark ? const Color(0xFFBDBDBD) : Colors.grey.shade800;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: fg,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
