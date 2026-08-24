import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appointment_status.dart';
import '../../../core/models/appointment.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
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
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authViewModelProvider.notifier).logout();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(context, state),
          _buildFilterBar(context, ref, state),
          Expanded(child: _buildList(context, state)),
        ],
      ),
    );
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

  Widget _buildList(BuildContext context, AdminDashboardState state) {
    return state.appointments.when(
      data: (appointments) {
        if (appointments.isEmpty) {
          return const EmptyStateWidget(
            title: 'No appointments found',
            message:
                'There are no survey requests matching the current filters.',
            icon: Icons.search_off,
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: appointments.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            return AdminAppointmentListItem(appointment: appointments[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error loading appointments',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
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
