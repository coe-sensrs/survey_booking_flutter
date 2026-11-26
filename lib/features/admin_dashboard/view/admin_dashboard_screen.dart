import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/models/appointment.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campus_visit_indicator_pill.dart';
import '../../../core/widgets/empty_state.dart';
import '../../admin_visits/viewmodel/admin_visits_viewmodel.dart';
import '../viewmodel/admin_dashboard_viewmodel.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Queue',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.domain_outlined),
            onPressed: () => context.push(AppRoutes.adminVisits),
            tooltip: 'Campus Visits Queue',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(adminDashboardViewModelProvider.notifier).refresh(),
            tooltip: 'Refresh Queue',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(context, state),
          _buildCampusVisitsBanner(context),
          _buildFilterBar(context, ref, state),
          Expanded(child: _buildList(context, ref, state)),
        ],
      ),
    );
  }

  Widget _buildCampusVisitsBanner(BuildContext context) {
    return const _CampusVisitsBanner();
  }

  Widget _buildStatsRow(BuildContext context, AdminDashboardState state) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Total',
              count: state.totalCount.toString(),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _StatCard(
              title: 'Pending',
              count: state.pendingCount.toString(),
              color: Colors.orange.shade700,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _StatCard(
              title: 'Reviewing',
              count: state.underReviewCount.toString(),
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    AdminDashboardState state,
  ) {
    final statusOptions = [
      'All',
      'pending_assignment',
      'under_review',
      'approved',
      'rejected',
      'task_assigned',
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statusOptions.map((status) {
                final isSelected = (state.statusFilter ?? 'All') == status;
                final label = status == 'All'
                    ? 'All'
                    : AppointmentStatus.fromCode(status).label;

                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(adminDashboardViewModelProvider.notifier)
                            .setStatusFilter(status);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AdminDashboardState state,
  ) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(adminDashboardViewModelProvider.notifier).refresh(),
      child: state.appointments.when(
        data: (appointments) {
          if (appointments.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(
                      child: EmptyStateWidget(
                        title: 'No appointments found',
                        message:
                            'There are no survey requests matching the current filters.',
                        icon: Icons.search_off,
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.w),
            itemCount: appointments.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              return AdminAppointmentListItem(appointment: appointments[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _AdminErrorRetryView(
                  message:
                      error.toString().toLowerCase().contains(
                        'permission-denied',
                      )
                      ? 'Permission sync in progress. Please pull down or tap Retry to reload.'
                      : 'Unable to load appointment queue. Pull down or tap Retry.',
                  onRetry: () => ref
                      .read(adminDashboardViewModelProvider.notifier)
                      .refresh(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CampusVisitsBanner extends ConsumerWidget {
  const _CampusVisitsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final indicator = ref.watch(adminCampusVisitIndicatorProvider);

    final hasPending = indicator.hasPending;
    final hasUnseen = indicator.hasUnseen;

    final borderColor = hasPending
        ? AppStatusColors.pending.withValues(alpha: hasUnseen ? 0.85 : 0.45)
        : theme.colorScheme.primary.withValues(alpha: 0.3);

    final backgroundColor = hasUnseen
        ? AppStatusColors.pending.withValues(alpha: isDark ? 0.14 : 0.08)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.35);

    String formatCount(int count) => count > 99 ? '99+' : '$count';

    final subtitle = hasUnseen
        ? '${formatCount(indicator.unseenCount)} new ${indicator.unseenCount == 1 ? 'request' : 'requests'} awaiting review'
        : hasPending
        ? '${formatCount(indicator.pendingCount)} pending ${indicator.pendingCount == 1 ? 'request' : 'requests'} to review'
        : 'Review and approve incoming campus delegation visit requests';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: InkWell(
        onTap: () => context.push(AppRoutes.adminVisits),
        borderRadius: BorderRadius.circular(10.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: borderColor,
              width: hasUnseen ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.domain_outlined,
                    size: 20.sp,
                    color: hasPending
                        ? Color.lerp(
                            AppStatusColors.pending,
                            theme.colorScheme.onSurface,
                            isDark ? 0.1 : 0.25,
                          )
                        : theme.colorScheme.primary,
                  ),
                  if (hasUnseen)
                    Positioned(
                      top: -2.h,
                      right: -3.w,
                      child: Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Campus Visits Management',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: hasUnseen
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPending) ...[
                SizedBox(width: 8.w),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 118.w),
                  child: CampusVisitIndicatorPill(
                    label: '${formatCount(indicator.pendingCount)} Pending',
                    color: AppStatusColors.pending,
                    showDot: hasUnseen,
                  ),
                ),
              ],
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right,
                size: 20.sp,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class AdminAppointmentListItem extends StatelessWidget {
  final Appointment appointment;

  const AdminAppointmentListItem({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context, appointment.status);
    final dateStr = DateFormat('MMM dd, yyyy').format(appointment.createdAt);

    return InkWell(
      onTap: () {
        context.push('/admin-appointment/${appointment.id}');
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    appointment.status.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              appointment.applicantName,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (appointment.applicantOrgName != null) ...[
              SizedBox(height: 2.h),
              Text(
                appointment.applicantOrgName!,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    '${appointment.district}, ${appointment.state}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pendingAssignment:
        return Colors.orange.shade700;
      case AppointmentStatus.underReview:
      case AppointmentStatus.clarificationRequested:
        return Colors.blue.shade700;
      case AppointmentStatus.approved:
      case AppointmentStatus.taskAssigned:
        return Colors.green.shade700;
      case AppointmentStatus.rejected:
        return Theme.of(context).colorScheme.error;
    }
  }
}

class _AdminErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdminErrorRetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56.sp,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
            SizedBox(height: 16.h),
            Text(
              'Could not load appointments',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.colorScheme.onSurfaceVariant,
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
