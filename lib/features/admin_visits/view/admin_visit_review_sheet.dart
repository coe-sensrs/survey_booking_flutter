import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/campus_visit_status.dart';
import '../../../core/models/campus_visit.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/campus_visit_status_badge.dart';
import '../viewmodel/admin_visits_viewmodel.dart';

class AdminVisitReviewSheet extends ConsumerStatefulWidget {
  final CampusVisit visit;

  const AdminVisitReviewSheet({super.key, required this.visit});

  @override
  ConsumerState<AdminVisitReviewSheet> createState() =>
      _AdminVisitReviewSheetState();
}

class _AdminVisitReviewSheetState extends ConsumerState<AdminVisitReviewSheet> {
  final _noteController = TextEditingController();
  bool _isRejectingMode = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    final nav = Navigator.of(context);
    final success = await ref
        .read(adminVisitsControllerProvider.notifier)
        .approveVisit(
          visitId: widget.visit.id,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );

    if (mounted) {
      if (success) {
        nav.pop();
        AppSnackbar.showGlobalSuccess(
          title: 'Visit Approved',
          message:
              'Campus visit on ${DateFormat('d MMM yyyy').format(widget.visit.visitDate)} has been approved.',
        );
      } else {
        final err =
            ref.read(adminVisitsControllerProvider).errorMessage ??
            'Failed to approve visit';
        AppSnackbar.showGlobalError(title: 'Approval Failed', message: err);
      }
    }
  }

  Future<void> _handleReject() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      AppSnackbar.showError(
        context,
        title: 'Rejection Reason Required',
        message:
            'Please provide a clear reason for rejecting this campus visit.',
      );
      return;
    }

    final nav = Navigator.of(context);
    final success = await ref
        .read(adminVisitsControllerProvider.notifier)
        .rejectVisit(visitId: widget.visit.id, note: note);

    if (mounted) {
      if (success) {
        nav.pop();
        AppSnackbar.showGlobalSuccess(
          title: 'Visit Rejected',
          message: 'Campus visit request has been marked as rejected.',
        );
      } else {
        final err =
            ref.read(adminVisitsControllerProvider).errorMessage ??
            'Failed to reject visit';
        AppSnackbar.showGlobalError(title: 'Rejection Failed', message: err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(adminVisitsControllerProvider);
    final isLoading = mutationState.isLoading;
    final theme = Theme.of(context);
    final dateStr = DateFormat(
      'EEEE, d MMMM yyyy',
    ).format(widget.visit.visitDate);

    return PopScope(
      canPop: !isLoading,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Title & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Review Campus Visit',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  CampusVisitStatusBadge(status: widget.visit.status),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'Delegation: ${widget.visit.delegationSize} ${widget.visit.delegationSize == 1 ? 'person' : 'people'}',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 16.h),
              const Divider(),
              SizedBox(height: 12.h),

              // Details
              _DetailItem(
                icon: Icons.person_outline,
                label: 'Applicant',
                value: widget.visit.applicantName,
              ),
              SizedBox(height: 10.h),
              _DetailItem(
                icon: Icons.phone_outlined,
                label: 'Mobile',
                value: widget.visit.applicantMobile,
              ),
              SizedBox(height: 10.h),
              _DetailItem(
                icon: Icons.email_outlined,
                label: 'Email',
                value: widget.visit.applicantEmail,
              ),
              SizedBox(height: 10.h),
              _DetailItem(
                icon: Icons.calendar_today,
                label: 'Visit Date',
                value: dateStr,
              ),
              SizedBox(height: 10.h),
              _DetailItem(
                icon: Icons.access_time,
                label: 'Session',
                value:
                    '${widget.visit.sessionDisplayName}\n(${widget.visit.sessionLabel})',
              ),

              SizedBox(height: 16.h),
              Text(
                'Purpose of Visit',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  widget.visit.purpose,
                  style: TextStyle(fontSize: 13.sp, height: 1.4),
                ),
              ),

              // If already reviewed, display reviewer note
              if (widget.visit.status != CampusVisitStatus.pending) ...[
                if (widget.visit.reviewNote != null &&
                    widget.visit.reviewNote!.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Text(
                    widget.visit.status == CampusVisitStatus.approved
                        ? 'Approval Note'
                        : 'Rejection Reason',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: widget.visit.status == CampusVisitStatus.approved
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color:
                          (widget.visit.status == CampusVisitStatus.approved
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.errorContainer)
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      widget.visit.reviewNote!,
                      style: TextStyle(fontSize: 13.sp, height: 1.4),
                    ),
                  ),
                ],
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(46.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Pending visit review workflow
                SizedBox(height: 16.h),
                Text(
                  _isRejectingMode
                      ? 'Rejection Reason (Required) *'
                      : 'Review Note (Optional)',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: _isRejectingMode ? theme.colorScheme.error : null,
                  ),
                ),
                SizedBox(height: 6.h),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    hintText: _isRejectingMode
                        ? 'Specify why this visit cannot be accommodated (e.g. scheduling conflict, holiday)...'
                        : 'Any special instructions or confirmation notes...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color: _isRejectingMode
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                if (_isRejectingMode) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isRejectingMode = false;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.fromHeight(46.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: const Text('Back to Review'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleReject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            minimumSize: Size.fromHeight(46.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onError,
                                  ),
                                )
                              : const Text('Confirm Reject'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isRejectingMode = true;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                            minimumSize: Size.fromHeight(46.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _handleApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            minimumSize: Size.fromHeight(46.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          icon: isLoading
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.sp, color: theme.colorScheme.primary),
        SizedBox(width: 12.w),
        SizedBox(
          width: 90.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
