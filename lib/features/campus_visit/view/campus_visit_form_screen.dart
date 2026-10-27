import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../viewmodel/campus_visit_viewmodel.dart';

/// Campus Visit booking form — three numbered sections matching the spec:
///  1. Applicant & Visit Details
///  2. Schedule & Time Window
///  3. Delegation Details
class CampusVisitFormScreen extends ConsumerStatefulWidget {
  const CampusVisitFormScreen({super.key});

  @override
  ConsumerState<CampusVisitFormScreen> createState() =>
      _CampusVisitFormScreenState();
}

class _CampusVisitFormScreenState extends ConsumerState<CampusVisitFormScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  // ── Date picker ─────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    // Minimum notice: 3 full calendar days from today
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day + 4);
    final last = DateTime(today.year + 1, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (date) => date.weekday != DateTime.sunday,
      helpText: 'Select Visit Date',
      confirmText: 'Confirm',
    );
    if (picked != null) {
      ref.read(campusVisitViewModelProvider.notifier).setVisitDate(picked);
    }
  }

  // ── Submission ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = ref.read(campusVisitViewModelProvider.notifier);
    await vm.submit();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(campusVisitViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Listen for errors and success
    ref.listen<CampusVisitFormState>(campusVisitViewModelProvider, (
      prev,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        AppSnackbar.showGlobalError(
          title: 'Submission Failed',
          message: next.errorMessage!,
        );
      }
      if (next.successVisitId != null && prev?.successVisitId == null) {
        // Show success, then navigate back
        AppSnackbar.showGlobalSuccess(
          title: 'Visit Request Submitted',
          message: 'Your campus visit request has been submitted for review.',
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      }
    });

    return PopScope(
      canPop: !formState.isSubmitting,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Book Campus Visit'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(42.h),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 16.w, bottom: 10.h),
              child: Text(
                'Indian Institute of Technology Ropar',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────
              // Section 1 — Applicant & Visit Details
              // ─────────────────────────────────────────────────────────────
              _SectionHeader(number: 1, title: 'Applicant & Visit Details'),
              SizedBox(height: 16.h),

              AppTextField(
                label: 'Full name *',
                hint: 'Your Name',
                controller: _nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
                onChanged: (v) => ref
                    .read(campusVisitViewModelProvider.notifier)
                    .setFullName(v),
              ),
              SizedBox(height: 14.h),

              AppTextField(
                label: 'Mobile number *',
                hint: '1234567890',
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                validator: (v) {
                  final digits = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (digits.length < 10) return 'Enter a valid mobile number';
                  return null;
                },
                onChanged: (v) => ref
                    .read(campusVisitViewModelProvider.notifier)
                    .setMobileNumber(v),
              ),
              SizedBox(height: 14.h),

              AppTextField(
                label: 'Email address *',
                hint: 'mail@institution.ac.in',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(125),
                ],
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
                onChanged: (v) =>
                    ref.read(campusVisitViewModelProvider.notifier).setEmail(v),
              ),
              SizedBox(height: 28.h),

              // ─────────────────────────────────────────────────────────────
              // Section 2 — Schedule & Time Window
              // ─────────────────────────────────────────────────────────────
              _SectionHeader(number: 2, title: 'Schedule & Time Window'),
              SizedBox(height: 16.h),

              // Date picker tile
              _DatePickerTile(
                selectedDate: formState.visitDate,
                onTap: _pickDate,
              ),
              SizedBox(height: 16.h),

              Text(
                'Preferred session *',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 10.h),

              // Session selector cards
              _SessionCard(
                label: 'Morning Session',
                timeRange: '09:30 AM – 12:30 PM',
                value: 'morning',
                selected: formState.session == 'morning',
                onTap: () => ref
                    .read(campusVisitViewModelProvider.notifier)
                    .setSession('morning'),
              ),
              SizedBox(height: 10.h),
              _SessionCard(
                label: 'Afternoon Session',
                timeRange: '02:00 PM – 05:00 PM',
                value: 'afternoon',
                selected: formState.session == 'afternoon',
                onTap: () => ref
                    .read(campusVisitViewModelProvider.notifier)
                    .setSession('afternoon'),
              ),
              SizedBox(height: 10.h),

              // Notice info chip
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 15.r,
                      color: colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Visits require advance notice. Minimum 3 full days notice required.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 28.h),

              // ─────────────────────────────────────────────────────────────
              // Section 3 — Delegation Details
              // ─────────────────────────────────────────────────────────────
              _SectionHeader(number: 3, title: 'Delegation Details'),
              SizedBox(height: 16.h),

              // Delegation size stepper
              _DelegationStepper(
                value: formState.delegationSize,
                onChanged: (v) => ref
                    .read(campusVisitViewModelProvider.notifier)
                    .setDelegationSize(v),
              ),
              SizedBox(height: 14.h),

              AppTextField(
                label: 'Purpose of visit *',
                hint:
                    'Describe the purpose, objectives and proposed activities of your visit…',
                controller: _purposeController,
                keyboardType: TextInputType.multiline,
                maxLines: 5,
                minLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 20) {
                    return 'Purpose must be at least 20 characters';
                  }
                  return null;
                },
                onChanged: (v) => ref
                    .read(campusVisitViewModelProvider.notifier)
                    .setPurpose(v),
              ),
              SizedBox(height: 8.h),

              // Character counter
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${formState.purpose.trim().length}/1000',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Submit button
              AppButton(
                text: 'Submit Visit Request',
                isLoading: formState.isSubmitting,
                onPressed: formState.isSubmitting ? null : _submit,
                icon: Icons.arrow_forward,
              ),

              SizedBox(height: 16.h),
              Center(
                child: Text(
                  'Illustrative layout preview; not a live booking form.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int number;
  final String title;
  const _SectionHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26.r,
          height: 26.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;
  const _DatePickerTile({required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDate = selectedDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select visit date *',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: hasDate
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.4),
                width: hasDate ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18.r,
                  color: hasDate
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(width: 10.w),
                Text(
                  hasDate ? _formatDate(selectedDate!) : 'Tap to select a date',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                    color: hasDate
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _SessionCard extends StatelessWidget {
  final String label;
  final String timeRange;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _SessionCard({
    required this.label,
    required this.timeRange,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value == 'morning' ? Icons.wb_sunny_outlined : Icons.wb_twilight,
              size: 20.r,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    timeRange,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18.r, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _DelegationStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DelegationStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total delegation size *',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              onTap: value > 1 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(width: 20.w),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(width: 20.w),
            _StepButton(
              icon: Icons.add,
              onTap: value < 50 ? () => onChanged(value + 1) : null,
            ),
            SizedBox(width: 16.w),
            Text(
              value == 1 ? 'person' : 'people',
              style: TextStyle(
                fontSize: 14.sp,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: 36.r,
        height: 36.r,
        decoration: BoxDecoration(
          color: enabled
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.outline.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: enabled
                ? colorScheme.primary.withValues(alpha: 0.4)
                : colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 18.r,
          color: enabled
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
