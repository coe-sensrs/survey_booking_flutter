import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step6Logistics extends ConsumerStatefulWidget {
  const Step6Logistics({super.key});

  @override
  ConsumerState<Step6Logistics> createState() => _Step6LogisticsState();
}

class _Step6LogisticsState extends ConsumerState<Step6Logistics> {
  final _coordNameController = TextEditingController();
  final _coordDesigController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverMobileController = TextEditingController();
  final _vehicleNoController = TextEditingController();
  final _vehicleModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wizardState = ref.read(bookingWizardViewModelProvider);
    _coordNameController.text = wizardState.coordinatorName ?? '';
    _coordDesigController.text = wizardState.coordinatorDesignation ?? '';
    _driverNameController.text = wizardState.driverName ?? '';
    _driverMobileController.text = wizardState.driverMobile ?? '';
    _vehicleNoController.text = wizardState.vehicleNumber ?? '';
    _vehicleModelController.text = wizardState.vehicleModel ?? '';
  }

  @override
  void dispose() {
    _coordNameController.dispose();
    _coordDesigController.dispose();
    _driverNameController.dispose();
    _driverMobileController.dispose();
    _vehicleNoController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final wizardState = ref.read(bookingWizardViewModelProvider);
    ref
        .read(bookingWizardViewModelProvider.notifier)
        .updateState(
          wizardState.copyWith(
            coordinatorName: _coordNameController.text.trim(),
            coordinatorDesignation: _coordDesigController.text.trim(),
            driverName: _driverNameController.text.trim(),
            driverMobile: _driverMobileController.text.trim(),
            vehicleNumber: _vehicleNoController.text.trim(),
            vehicleModel: _vehicleModelController.text.trim(),
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
            'Logistics & Personnel Details',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Provide coordinator, driver, and vehicle details for the survey team.',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 20.h),

          Text(
            'Local Coordinator',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),

          AppTextField(
            label: 'Coordinator Name *',
            controller: _coordNameController,
            onChanged: (_) => _onChanged(),
          ),

          SizedBox(height: 12.h),

          AppTextField(
            label: 'Coordinator Designation *',
            controller: _coordDesigController,
            onChanged: (_) => _onChanged(),
          ),

          SizedBox(height: 20.h),

          Text(
            'Driver Details',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),

          AppTextField(
            label: 'Driver Name *',
            controller: _driverNameController,
            onChanged: (_) => _onChanged(),
          ),

          SizedBox(height: 12.h),

          AppTextField(
            label: 'Driver Mobile Number *',
            hint: '10 digit mobile number',
            controller: _driverMobileController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => _onChanged(),
          ),

          SizedBox(height: 20.h),

          Text(
            'Vehicle Details',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),

          AppTextField(
            label: 'Vehicle Model *',
            controller: _vehicleModelController,
            onChanged: (_) => _onChanged(),
          ),

          SizedBox(height: 12.h),

          AppTextField(
            label: 'Vehicle Number *',
            controller: _vehicleNoController,
            onChanged: (_) => _onChanged(),
          ),
        ],
      ),
    );
  }
}
