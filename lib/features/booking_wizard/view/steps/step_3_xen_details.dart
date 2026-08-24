import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step3XenDetails extends ConsumerStatefulWidget {
  const Step3XenDetails({super.key});

  @override
  ConsumerState<Step3XenDetails> createState() => _Step3XenDetailsState();
}

class _Step3XenDetailsState extends ConsumerState<Step3XenDetails> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wizardState = ref.read(bookingWizardViewModelProvider);
    _nameController.text = wizardState.xenName ?? '';
    _mobileController.text = wizardState.xenMobile ?? '';
    _emailController.text = wizardState.xenEmail ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final wizardState = ref.read(bookingWizardViewModelProvider);
    ref
        .read(bookingWizardViewModelProvider.notifier)
        .updateState(
          wizardState.copyWith(
            xenName: _nameController.text.trim(),
            xenMobile: _mobileController.text.trim(),
            xenEmail: _emailController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Executive Engineer (XEN) Details',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Provide contact details of the Executive Engineer responsible for the district.',
            style: TextStyle(
              fontSize: 13.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          AppTextField(
            label: 'XEN Name *',
            hint: 'Enter full name of XEN',
            controller: _nameController,
            keyboardType: TextInputType.name,
            onChanged: (_) => _onChanged(),
          ),

          SizedBox(height: 16.h),

          AppTextField(
            label: 'XEN Mobile Number *',
            hint: '10 digit mobile number',
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => _onChanged(),
          ),

          SizedBox(height: 16.h),

          AppTextField(
            label: 'XEN Email Address *',
            hint: 'e.g. xen.district@gov.in',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => _onChanged(),
          ),
        ],
      ),
    );
  }
}
