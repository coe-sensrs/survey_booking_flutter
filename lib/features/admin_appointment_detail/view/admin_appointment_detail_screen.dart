import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';
import 'package:survey_desk/features/admin_appointment_detail/viewmodel/admin_appointment_detail_viewmodel.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/models/appointment.dart';
import 'widgets/assign_reviewer_sheet.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/set_confirmed_date_sheet.dart';

class AdminAppointmentDetailScreen extends ConsumerWidget {
  final String appointmentId;

  const AdminAppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      adminAppointmentDetailStreamProvider(appointmentId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: state.when(
        data: (appointment) {
          if (appointment == null) {
            return const Center(child: Text('Appointment not found.'));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(context, appointment),
                SizedBox(height: 24.h),
                _buildSectionTitle(context, 'Location Details'),
                _buildInfoCard(context, [
                  _InfoRow(label: 'State', value: appointment.state),
                  _InfoRow(label: 'District', value: appointment.district),
                  _InfoRow(
                    label: 'Landmark / Area Name',
                    value: appointment.areaName,
                  ),
                  if (appointment.xenDetails.name.isNotEmpty)
                    _InfoRow(
                      label: 'XEN Name',
                      value: appointment.xenDetails.name,
                    ),
                ]),
                SizedBox(height: 24.h),
                _buildSectionTitle(context, 'Schedule'),
                _buildInfoCard(context, [
                  _InfoRow(
                    label: 'Preferred Date',
                    value: DateFormat(
                      'MMM dd, yyyy',
                    ).format(appointment.preferredDate),
                  ),
                  _InfoRow(
                    label: 'Confirmed Date',
                    value: appointment.confirmedDate != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(appointment.confirmedDate!)
                        : 'Not yet confirmed',
                    actionIcon: Icons.edit_calendar,
                    onAction: () => _showSetDateSheet(context, appointmentId),
                  ),
                ]),
                if (appointment.assignedReviewerId != null ||
                    appointment.assignedTaskMemberId != null) ...[
                  SizedBox(height: 24.h),
                  _buildSectionTitle(context, 'Assignments'),
                  _buildInfoCard(context, [
                    if (appointment.assignedReviewerId != null)
                      _InfoRow(
                        label: 'Assigned Reviewer',
                        value: appointment.assignedReviewerName ?? 'Unknown',
                      ),
                    if (appointment.assignedTaskMemberId != null)
                      _InfoRow(
                        label: 'Assigned Field Task',
                        value: appointment.assignedTaskMemberName ?? 'Unknown',
                      ),
                  ]),
                ],
                SizedBox(height: 32.h),
                _buildAdminActions(context, appointment),
                SizedBox(height: 40.h),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Appointment appointment) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SRV-${appointment.id.substring(0, 6).toUpperCase()}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  appointment.status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            appointment.surveyType.label,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                child: Icon(
                  Icons.person,
                  size: 18.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.applicantName,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Applicant',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<_InfoRow> rows) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.value.label,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.value.value,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (entry.value.actionIcon != null) ...[
                            SizedBox(width: 8.w),
                            InkWell(
                              onTap: entry.value.onAction,
                              child: Icon(
                                entry.value.actionIcon,
                                size: 18.sp,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context, Appointment appointment) {
    if (appointment.status == AppointmentStatus.pendingAssignment) {
      return FilledButton.icon(
        onPressed: () => _showAssignReviewerSheet(context, appointmentId),
        icon: const Icon(Icons.person_search),
        label: const Text('Assign Reviewer'),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16.h),
        ),
      );
    }

    if (appointment.status == AppointmentStatus.approved) {
      return FilledButton.icon(
        onPressed: () => _showAssignTaskSheet(context, appointmentId),
        icon: const Icon(Icons.assignment_ind),
        label: const Text('Assign Fieldwork Task'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          padding: EdgeInsets.symmetric(vertical: 16.h),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showSetDateSheet(BuildContext context, String appointmentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SetConfirmedDateSheet(appointmentId: appointmentId),
    );
  }

  void _showAssignReviewerSheet(BuildContext context, String appointmentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AssignReviewerSheet(appointmentId: appointmentId),
    );
  }

  void _showAssignTaskSheet(BuildContext context, String appointmentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AssignTaskSheet(appointmentId: appointmentId),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  _InfoRow({
    required this.label,
    required this.value,
    this.actionIcon,
    this.onAction,
  });
}
