import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/models/appointment.dart';
import '../../../core/utils/app_snackbar.dart';
import '../viewmodel/committee_review_detail_viewmodel.dart';

class CommitteeReviewDetailScreen extends ConsumerWidget {
  final String appointmentId;

  const CommitteeReviewDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(committeeReviewDetailStreamProvider(appointmentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Review Details')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _NetworkErrorView(
          onRetry: () => ref.invalidate(
            committeeReviewDetailStreamProvider(appointmentId),
          ),
        ),
        data: (appointment) {
          if (appointment == null) {
            return const Center(child: Text('Appointment not found.'));
          }
          return _ReviewDetailBody(appointment: appointment);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — receives the appointment directly; only rebuilds on data changes
// ---------------------------------------------------------------------------
class _ReviewDetailBody extends ConsumerWidget {
  final Appointment appointment;

  const _ReviewDetailBody({required this.appointment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(committeeReviewDetailControllerProvider);
    final isResolved =
        appointment.status == AppointmentStatus.approved ||
        appointment.status == AppointmentStatus.rejected;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(appointment: appointment),
          SizedBox(height: 20.h),

          // --- Location ---
          _SectionTitle('Location Details'),
          _InfoCard(
            rows: [
              _InfoRow('State', appointment.state),
              _InfoRow('District', appointment.district),
              _InfoRow('Area Name', appointment.areaName),
            ],
          ),
          SizedBox(height: 16.h),

          // --- XEN Contact ---
          _SectionTitle('XEN Contact'),
          _InfoCard(
            rows: [
              _InfoRow('Name', appointment.xenDetails.name),
              _InfoRow('Mobile', appointment.xenDetails.mobile),
              _InfoRow('Email', appointment.xenDetails.email),
            ],
          ),
          SizedBox(height: 16.h),

          // --- Survey Dates ---
          _SectionTitle('Schedule'),
          _InfoCard(
            rows: [
              _InfoRow(
                'Preferred Date',
                DateFormat('dd MMM yyyy').format(appointment.preferredDate),
              ),
              if (appointment.confirmedDate != null)
                _InfoRow(
                  'Confirmed Date',
                  DateFormat('dd MMM yyyy').format(appointment.confirmedDate!),
                ),
            ],
          ),
          SizedBox(height: 16.h),

          // --- Logistics ---
          _SectionTitle('Logistics & Personnel'),
          _InfoCard(
            rows: [
              _InfoRow(
                'Coordinator',
                '${appointment.logistics.coordinatorName} '
                    '(${appointment.logistics.coordinatorDesignation})',
              ),
              _InfoRow(
                'Driver',
                '${appointment.logistics.driverName} · '
                    '${appointment.logistics.driverMobile}',
              ),
              _InfoRow(
                'Vehicle',
                '${appointment.logistics.vehicleNumber} — '
                    '${appointment.logistics.vehicleModel}',
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // --- Permission Documents ---
          _SectionTitle(
            'Permission Documents (${appointment.permissionDocuments.length})',
          ),
          _DocumentList(appointment: appointment),
          SizedBox(height: 16.h),

          // --- Clarification thread (if any) ---
          if (appointment.clarificationNote != null &&
              appointment.clarificationNote!.isNotEmpty) ...[
            _SectionTitle('Clarification Thread'),
            _ClarificationCard(appointment: appointment),
            SizedBox(height: 16.h),
          ],

          // --- Rejection reason (if any) ---
          if (appointment.rejectionReason != null &&
              appointment.rejectionReason!.isNotEmpty) ...[
            _SectionTitle('Rejection Reason'),
            _ReasonCard(
              reason: appointment.rejectionReason!,
              isRejection: true,
            ),
            SizedBox(height: 16.h),
          ],

          // --- Actions (only shown when the appointment needs a decision) ---
          if (!isResolved) ...[
            SizedBox(height: 8.h),
            _ActionButtons(appointment: appointment, controller: controller),
          ],

          SizedBox(height: 40.h),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header card with status badge
// ---------------------------------------------------------------------------
class _HeaderCard extends StatelessWidget {
  final Appointment appointment;
  const _HeaderCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
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
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  appointment.status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            appointment.surveyType.label,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14.sp,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 4.w),
              Text(
                appointment.applicantName,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (appointment.applicantOrgName != null) ...[
                Text(
                  ' · ',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  appointment.applicantOrgName!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable section title
// ---------------------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, left: 2.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info rows card
// ---------------------------------------------------------------------------
class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 7.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.value.isNotEmpty ? row.value : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  height: 1,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission documents list
// ---------------------------------------------------------------------------
class _DocumentList extends StatelessWidget {
  final Appointment appointment;
  const _DocumentList({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (appointment.permissionDocuments.isEmpty) {
      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          'No permission documents uploaded.',
          style: TextStyle(
            fontSize: 13.sp,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: appointment.permissionDocuments.asMap().entries.map((entry) {
          final isLast =
              entry.key == appointment.permissionDocuments.length - 1;
          final doc = entry.value;
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  doc.fileType == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  doc.originalFileName,
                  style: TextStyle(fontSize: 13.sp),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB · ${doc.fileType.toUpperCase()}',
                  style: TextStyle(fontSize: 11.sp),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clarification thread card
// ---------------------------------------------------------------------------
class _ClarificationCard extends StatelessWidget {
  final Appointment appointment;
  const _ClarificationCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_outlined,
                size: 16.sp,
                color: Colors.orange.shade700,
              ),
              SizedBox(width: 6.w),
              Text(
                'Your Clarification Request',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            appointment.clarificationNote!,
            style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
          ),
          if (appointment.clarificationReply != null &&
              appointment.clarificationReply!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Divider(color: Colors.orange.withValues(alpha: 0.3)),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.reply, size: 16.sp, color: colorScheme.primary),
                SizedBox(width: 6.w),
                Text(
                  'Applicant\'s Reply',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              appointment.clarificationReply!,
              style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
            ),
          ] else ...[
            SizedBox(height: 10.h),
            Text(
              'Awaiting applicant reply…',
              style: TextStyle(
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rejection reason display card
// ---------------------------------------------------------------------------
class _ReasonCard extends StatelessWidget {
  final String reason;
  final bool isRejection;
  const _ReasonCard({required this.reason, this.isRejection = false});

  @override
  Widget build(BuildContext context) {
    final color = isRejection
        ? Theme.of(context).colorScheme.error
        : Colors.orange.shade700;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        reason,
        style: TextStyle(
          fontSize: 13.sp,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons — Approve / Clarify / Reject
// Only rendered when action is possible, avoiding unnecessary widget builds.
// ---------------------------------------------------------------------------
class _ActionButtons extends ConsumerStatefulWidget {
  final Appointment appointment;
  final CommitteeReviewDetailController controller;

  const _ActionButtons({required this.appointment, required this.controller});

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  bool _isLoading = false;

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Action Failed',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRejectSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TextInputSheet(
        title: 'Reject Appointment',
        hint: 'Provide a mandatory rejection reason (max 500 chars)',
        confirmLabel: 'Reject',
        confirmColor: Theme.of(context).colorScheme.error,
        maxLength: 500,
        onConfirm: (text) => _runAction(
          () => widget.controller.reject(widget.appointment, text),
        ),
      ),
    );
  }

  void _showClarifySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TextInputSheet(
        title: 'Request Clarification',
        hint:
            'What information do you need from the applicant? (max 500 chars)',
        confirmLabel: 'Send Request',
        maxLength: 500,
        onConfirm: (text) => _runAction(
          () =>
              widget.controller.requestClarification(widget.appointment, text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canClarify = widget.controller.canRequestClarification(
      widget.appointment,
    );
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Approve
        FilledButton.icon(
          onPressed: () =>
              _runAction(() => widget.controller.approve(widget.appointment)),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Approve'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
          ),
        ),
        SizedBox(height: 10.h),

        // Clarify (conditionally shown per PRD once-per-cycle rule)
        if (canClarify)
          OutlinedButton.icon(
            onPressed: _showClarifySheet,
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Request Clarification'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade400),
              padding: EdgeInsets.symmetric(vertical: 14.h),
            ),
          ),
        if (canClarify) SizedBox(height: 10.h),

        // Reject
        OutlinedButton.icon(
          onPressed: _showRejectSheet,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error),
            padding: EdgeInsets.symmetric(vertical: 14.h),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable text-input bottom sheet for Reject / Clarify
// ---------------------------------------------------------------------------
class _TextInputSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;
  final Color? confirmColor;
  final int maxLength;
  final Future<void> Function(String text) onConfirm;

  const _TextInputSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.maxLength,
    required this.onConfirm,
    this.confirmColor,
  });

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'This field is required.');
      return;
    }
    if (text.length > widget.maxLength) {
      setState(() => _error = 'Must be under ${widget.maxLength} characters.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.onConfirm(text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            widget.title,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 14.h),
          TextField(
            controller: _controller,
            maxLength: widget.maxLength,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: widget.confirmColor ?? colorScheme.primary,
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(widget.confirmLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Network / generic error view
// ---------------------------------------------------------------------------
class _NetworkErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _NetworkErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56.sp,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
            ),
            SizedBox(height: 16.h),
            Text(
              'Could not load details',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 20.h),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
