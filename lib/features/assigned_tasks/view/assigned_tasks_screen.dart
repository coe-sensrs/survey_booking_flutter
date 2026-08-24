import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/models/appointment.dart';
import '../../../core/routing/app_router.dart';
import '../viewmodel/assigned_tasks_viewmodel.dart';

class AssignedTasksScreen extends ConsumerWidget {
  const AssignedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(assignedTasksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Assigned Tasks',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        centerTitle: false,
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorRetryView(
          onRetry: () => ref.invalidate(assignedTasksStreamProvider),
        ),
        data: (tasks) {
          if (tasks.isEmpty) return _EmptyTasksView();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(assignedTasksStreamProvider),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => SizedBox(height: 10.h),
              itemBuilder: (_, index) => _TaskCard(
                appointment: tasks[index],
                onTap: () => context.push(
                  AppRoutes.committeeTaskDetail.replaceAll(
                    ':id',
                    tasks[index].id,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task card — read-only, shows survey info + confirmed date if available
// ---------------------------------------------------------------------------
class _TaskCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const _TaskCard({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTaskAssigned = appointment.status == AppointmentStatus.taskAssigned;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SRV-${appointment.id.substring(0, 6).toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      isTaskAssigned
                          ? 'Task Assigned'
                          : appointment.status.label,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                appointment.surveyType.label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${appointment.district}, ${appointment.state}',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 10.h),
              // Survey date row
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 14.sp,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    appointment.confirmedDate != null
                        ? 'Survey on ${DateFormat('dd MMM yyyy').format(appointment.confirmedDate!)}'
                        : 'Preferred: ${DateFormat('dd MMM yyyy').format(appointment.preferredDate)}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: appointment.confirmedDate != null
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      appointment.applicantName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyTasksView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Fieldwork Tasks',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Fieldwork tasks assigned to you by Admin will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error + retry
// ---------------------------------------------------------------------------
class _ErrorRetryView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetryView({required this.onRetry});

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
              'Could not load tasks',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              'Check your internet connection and try again.',
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
