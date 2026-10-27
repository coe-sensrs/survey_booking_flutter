import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/campus_visit_status.dart';
import '../../../core/models/campus_visit.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/campus_visit_status_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/my_visits_viewmodel.dart';

/// Notifier for filtering applicant visits by status in the UI.
class _ApplicantVisitFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? filter) {
    state = filter;
  }
}

final _applicantVisitFilterProvider =
    NotifierProvider.autoDispose<_ApplicantVisitFilterNotifier, String?>(
      _ApplicantVisitFilterNotifier.new,
    );

/// Screen for applicants to track and manage their booked campus visits.
class MyVisitsScreen extends ConsumerWidget {
  const MyVisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).value;
    final selectedFilter = ref.watch(_applicantVisitFilterProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final visitsAsync = ref.watch(myVisitsProvider(user.uid));

    final filterOptions = [
      {'label': 'All', 'code': null},
      {'label': 'Pending', 'code': CampusVisitStatus.pending.code},
      {'label': 'Approved', 'code': CampusVisitStatus.approved.code},
      {'label': 'Rejected', 'code': CampusVisitStatus.rejected.code},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Campus Visits',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Book Campus Visit',
            onPressed: () => context.push(AppRoutes.campusVisitForm),
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
                          .read(_applicantVisitFilterProvider.notifier)
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
                  ref.invalidate(myVisitsProvider(user.uid));
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
                            ref.invalidate(myVisitsProvider(user.uid)),
                      ),
                    ),
                  ),
                ),
              ),
              data: (visits) {
                final filtered = selectedFilter == null
                    ? visits
                    : visits
                          .where((v) => v.status.code == selectedFilter)
                          .toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(myVisitsProvider(user.uid));
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
                                ? 'No Campus Visits Booked'
                                : 'No ${selectedFilter.toUpperCase()} Visits',
                            message: selectedFilter == null
                                ? 'You have not submitted any campus visit requests yet. Schedule a guided tour or academic meeting at IIT Ropar.'
                                : 'No visits found matching this status filter.',
                            icon: Icons.domain_outlined,
                            buttonText: 'Book Campus Visit',
                            onButtonPressed: () =>
                                context.push(AppRoutes.campusVisitForm),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myVisitsProvider(user.uid));
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final visit = filtered[index];
                      return _VisitCard(
                        visit: visit,
                        onTap: () => _showVisitDetailSheet(context, visit),
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

  void _showVisitDetailSheet(BuildContext context, CampusVisit visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => _VisitDetailSheet(visit: visit),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final CampusVisit visit;
  final VoidCallback onTap;

  const _VisitCard({required this.visit, required this.onTap});

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
              // Header: Session & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      visit.session == 'morning'
                          ? Icons.wb_sunny_outlined
                          : Icons.wb_twilight_outlined,
                      color: theme.colorScheme.primary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${visit.sessionDisplayName} (${visit.sessionLabel})',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CampusVisitStatusBadge(status: visit.status),
                ],
              ),

              SizedBox(height: 12.h),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              SizedBox(height: 12.h),

              // Delegation & Purpose snippet
              Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 16.sp,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Delegation: ${visit.delegationSize} ${visit.delegationSize == 1 ? 'person' : 'people'}',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
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

              // Rejection alert snippet if rejected
              if (visit.status == CampusVisitStatus.rejected &&
                  visit.reviewNote != null &&
                  visit.reviewNote!.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16.sp,
                        color: Colors.red.shade700,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Reason: ${visit.reviewNote}',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitDetailSheet extends StatelessWidget {
  final CampusVisit visit;

  const _VisitDetailSheet({required this.visit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(visit.visitDate);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Campus Visit Details',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              CampusVisitStatusBadge(status: visit.status),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'IIT Ropar Main Campus',
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          const Divider(),
          SizedBox(height: 12.h),

          // Details List
          _DetailRow(
            icon: Icons.calendar_today,
            label: 'Visit Date',
            value: dateStr,
          ),
          SizedBox(height: 12.h),
          _DetailRow(
            icon: Icons.access_time,
            label: 'Session',
            value: '${visit.sessionDisplayName}\n${visit.sessionLabel}',
          ),
          SizedBox(height: 12.h),
          _DetailRow(
            icon: Icons.groups_outlined,
            label: 'Delegation Size',
            value:
                '${visit.delegationSize} ${visit.delegationSize == 1 ? 'member' : 'members'}',
          ),
          SizedBox(height: 12.h),
          _DetailRow(
            icon: Icons.person_outline,
            label: 'Applicant Name',
            value: visit.applicantName,
          ),
          SizedBox(height: 12.h),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'Mobile Number',
            value: visit.applicantMobile,
          ),
          SizedBox(height: 12.h),
          _DetailRow(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: visit.applicantEmail,
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
              visit.purpose,
              style: TextStyle(fontSize: 13.sp, height: 1.4),
            ),
          ),

          // Review Note if applicable
          if (visit.reviewNote != null && visit.reviewNote!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Text(
              visit.status == CampusVisitStatus.rejected
                  ? 'Rejection Reason'
                  : 'Reviewer Note',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: visit.status == CampusVisitStatus.rejected
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: 6.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color:
                    (visit.status == CampusVisitStatus.rejected
                            ? theme.colorScheme.errorContainer
                            : theme.colorScheme.primaryContainer)
                        .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                visit.reviewNote!,
                style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
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
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
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
          width: 110.w,
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
