import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/appointment_status.dart';

import '../../../core/widgets/appointment_booking_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../viewmodel/my_bookings_viewmodel.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsState = ref.watch(myBookingsViewModelProvider);
    final selectedFilter = ref.watch(myBookingsStatusFilterProvider);

    final statusOptions = [
      {'label': 'All', 'code': null},
      {'label': 'Pending', 'code': AppointmentStatus.pendingAssignment.code},
      {'label': 'Under Review', 'code': AppointmentStatus.underReview.code},
      {
        'label': 'Clarification Needed',
        'code': AppointmentStatus.clarificationRequested.code,
      },
      {'label': 'Approved', 'code': AppointmentStatus.approved.code},
      {'label': 'Rejected', 'code': AppointmentStatus.rejected.code},
      {'label': 'Task Assigned', 'code': AppointmentStatus.taskAssigned.code},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Booking',
            onPressed: () => context.push('/booking-wizard'),
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
              children: statusOptions.map((opt) {
                final isSelected = selectedFilter == opt['code'];
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilterChip(
                    label: Text(opt['label'] as String),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref
                          .read(myBookingsStatusFilterProvider.notifier)
                          .setFilter(selected ? opt['code'] : null);
                    },
                    selectedColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                    checkmarkColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: bookingsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(myBookingsViewModelProvider.notifier).refresh(),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: EmptyStateWidget(
                        title: 'Failed to load bookings',
                        message: err.toString(),
                        icon: Icons.error_outline,
                        buttonText: 'Retry',
                        onButtonPressed: () => ref
                            .read(myBookingsViewModelProvider.notifier)
                            .refresh(),
                      ),
                    ),
                  ),
                ),
              ),
              data: (appointments) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(myBookingsViewModelProvider.notifier).refresh(),
                child: appointments.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: EmptyStateWidget(
                              title: 'No bookings found',
                              message: selectedFilter == null
                                  ? 'You have not made any survey appointments yet.'
                                  : 'No appointments match the selected filter.',
                              icon: Icons.bookmark_border,
                              buttonText: 'Start New Survey',
                              onButtonPressed: () =>
                                  context.push('/booking-wizard'),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(16.w),
                        itemCount: appointments.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final item = appointments[index];
                          return AppointmentBookingCard(item: item);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
