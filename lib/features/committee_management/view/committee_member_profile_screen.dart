import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_user.dart';
import '../../../core/widgets/safe_profile_avatar.dart';
import '../viewmodel/committee_member_profile_viewmodel.dart';
import 'manage_committee_member_sheet.dart';

/// Admin-facing read-only profile view for a specific committee member.
/// Matches Stitch Design #9 (Committee Member Profile).
/// The AppBar "Manage" button opens [ManageCommitteeMemberSheet].
class CommitteeMemberProfileScreen extends ConsumerWidget {
  final String memberId;

  const CommitteeMemberProfileScreen({super.key, required this.memberId});

  void _openManageSheet(BuildContext context, AppUser member) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManageCommitteeMemberSheet(member: member),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(committeeMemberProfileProvider(memberId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Member Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        actions: [
          profileAsync.maybeWhen(
            data: (member) => member != null
                ? TextButton.icon(
                    onPressed: () => _openManageSheet(context, member),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Manage'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48.r, color: colorScheme.error),
              SizedBox(height: 12.h),
              Text(
                'Could not load member profile.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () =>
                    ref.invalidate(committeeMemberProfileProvider(memberId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (member) {
          if (member == null) {
            return Center(
              child: Text(
                'Member not found.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14.sp,
                ),
              ),
            );
          }
          return _ProfileBody(member: member);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile body
// ---------------------------------------------------------------------------
class _ProfileBody extends StatelessWidget {
  final AppUser member;

  const _ProfileBody({required this.member});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = member.active ?? true;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card ──────────────────────────────────────────────────
          _SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SafeProfileAvatar(
                  imageUrl: member.photoUrl,
                  radius: 36.r,
                  fallbackIcon: Icons.person,
                  backgroundColor:
                      colorScheme.primary.withValues(alpha: 0.12),
                  iconColor: colorScheme.primary,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (member.expertiseTag != null &&
                          member.expertiseTag!.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        _ExpertiseChip(tag: member.expertiseTag!),
                      ],
                      SizedBox(height: 6.h),
                      _StatusChip(isActive: isActive),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // ── Personal Information ─────────────────────────────────────────
          _SectionTitle('Personal Information'),
          SizedBox(height: 8.h),
          _SectionCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: member.email,
                ),
                _Divider(),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone Number',
                  value: member.phone.isEmpty ? '—' : member.phone,
                ),
                _Divider(),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member Since',
                  value: DateFormat('d MMM yyyy').format(member.createdAt),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // ── Expertise & Roles ────────────────────────────────────────────
          _SectionTitle('Expertise & Roles'),
          SizedBox(height: 8.h),
          _SectionCard(
            child: _InfoRow(
              icon: Icons.verified_outlined,
              label: 'Primary Expertise',
              value: (member.expertiseTag?.isNotEmpty ?? false)
                  ? member.expertiseTag!
                  : '—',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable sub-widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.r, color: colorScheme.primary),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _ExpertiseChip extends StatelessWidget {
  final String tag;
  const _ExpertiseChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        tag.toUpperCase(),
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          color: colorScheme.tertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive ? colorScheme.primary : colorScheme.error;
    final bg = isActive
        ? colorScheme.primary.withValues(alpha: 0.1)
        : colorScheme.error.withValues(alpha: 0.1);
    final label = isActive ? 'Active' : 'Inactive';
    final icon = isActive ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.r, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
