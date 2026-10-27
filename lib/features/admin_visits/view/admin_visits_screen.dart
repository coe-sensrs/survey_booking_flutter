import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/campus_visit_status.dart';
import '../../../core/models/campus_visit.dart';
import '../../../core/widgets/campus_visit_status_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../my_visits/viewmodel/my_visits_viewmodel.dart';
import '../viewmodel/admin_visits_viewmodel.dart';
import 'admin_visit_review_sheet.dart';

/// Screen for administrators to view, filter, and review all campus visit requests.
class AdminVisitsScreen extends ConsumerWidget {
  const AdminVisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(adminVisitsFilterProvider);
    final visitsAsync = ref.watch(adminVisitsProvider(selectedFilter));

    final filterOptions = [
      {'label': 'All', 'code': null},
      {'label': 'Pending', 'code': CampusVisitStatus.pending.code},
      {'label': 'Approved', 'code': CampusVisitStatus.approved.code},
      {'label': 'Rejected', 'code': CampusVisitStatus.rejected.code},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Campus Visit Queue',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(adminVisitsProvider(selectedFilter)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: filterOptions.map((opt) {
                final isSelected = selectedFilter == opt['code'];
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilterChip(
                    label: Text(opt['label'] as String),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref
                          .read(adminVisitsFilterProvider.notifier)
                          .setFilter(selected ? opt['code'] : null);
                    },
                    selectedColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                    checkmarkColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),

          // Visits List
          Expanded(
            child: visitsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminVisitsProvider(selectedFilter));
                },
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: EmptyStateWidget(
                        title: 'Failed to load visits',
                        message: err.toString(),
                        icon: Icons.error_outline,
                        buttonText: 'Retry',
                        onButtonPressed: () =>
                            ref.invalidate(adminVisitsProvider(selectedFilter)),
                      ),
                    ),
                  ),
                ),
              ),
              data: (visits) {
                if (visits.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(adminVisitsProvider(selectedFilter));
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: EmptyStateWidget(
                            title: selectedFilter == null
                                ? 'No Campus Visit Requests'
                                : 'No ${selectedFilter.toUpperCase()} Visits',
                            message: selectedFilter == null
                                ? 'There are currently no campus visit bookings in the system.'
                                : 'No visits match the selected status filter.',
                            icon: Icons.event_available,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminVisitsProvider(selectedFilter));
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    itemCount: visits.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final visit = visits[index];
                      return _AdminVisitCard(
                        visit: visit,
                        onTap: () => _openReviewSheet(context, visit),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openReviewSheet(BuildContext context, CampusVisit visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => AdminVisitReviewSheet(visit: visit),
    );
  }
}

class _AdminVisitCard extends StatelessWidget {
  final CampusVisit visit;
  final VoidCallback onTap;

  const _AdminVisitCard({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEE, d MMM yyyy').format(visit.visitDate);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Applicant Name & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.applicantName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${visit.applicantEmail} • ${visit.applicantMobile}',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  CampusVisitStatusBadge(status: visit.status),
                ],
              ),

              SizedBox(height: 12.h),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              SizedBox(height: 12.h),

              // Date, Session & Delegation
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 15.sp,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(
                    Icons.access_time,
                    size: 15.sp,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    visit.sessionDisplayName,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 16.sp,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Delegation size: ${visit.delegationSize} ${visit.delegationSize == 1 ? 'member' : 'members'}',
                    style: TextStyle(fontSize: 12.5.sp),
                  ),
                ],
              ),
              SizedBox(height: 6.h),

              Text(
                visit.purpose,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),

              SizedBox(height: 12.h),

              // Action button row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (visit.status == CampusVisitStatus.pending) ...[
                    OutlinedButton.icon(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 6.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                      label: const Text('Review Visit'),
                    ),
                  ] else ...[
                    TextButton.icon(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Details'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
