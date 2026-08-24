import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/survey_type.dart';

import '../../../core/utils/app_snackbar.dart';
import '../viewmodel/booking_wizard_viewmodel.dart';
import 'steps/step_1_survey_type.dart';
import 'steps/step_2_state_district.dart';
import 'steps/step_3_xen_details.dart';
import 'steps/step_4_survey_area.dart';
import 'steps/step_5_start_date.dart';
import 'steps/step_6_logistics.dart';
import 'steps/step_7_permissions.dart';
import 'steps/step_8_review.dart';
import 'steps/step_9_acknowledgement.dart';

class BookingWizardScreen extends ConsumerWidget {
  const BookingWizardScreen({super.key});

  bool _validateCurrentStep(int step, WizardStateData state) {
    switch (step) {
      case 1:
        if (state.surveyType == null) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please select a survey type.',
          );
          return false;
        }
        if (state.surveyType == SurveyType.other.code &&
            (state.customSurveyName == null ||
                state.customSurveyName!.trim().isEmpty)) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter a custom survey name.',
          );
          return false;
        }
        return true;
      case 2:
        if (state.district == null || state.district!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please select a district.',
          );
          return false;
        }
        return true;
      case 3:
        if (state.xenName == null || state.xenName!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter XEN Name.',
          );
          return false;
        }
        if (state.xenMobile == null || state.xenMobile!.length != 10) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter a valid 10-digit XEN Mobile Number.',
          );
          return false;
        }
        if (state.xenEmail == null || !state.xenEmail!.contains('@')) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter a valid XEN Email.',
          );
          return false;
        }
        return true;
      case 4:
        if (state.areaName == null || state.areaName!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter Survey Area Name.',
          );
          return false;
        }
        if (state.kmlFilePath == null || state.kmlFileName == null) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please upload a KML/KMZ file.',
          );
          return false;
        }
        return true;
      case 5:
        if (state.startDate == null) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please select a preferred start date.',
          );
          return false;
        }
        return true;
      case 6:
        if (state.coordinatorName == null ||
            state.coordinatorName!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter Coordinator Name.',
          );
          return false;
        }
        if (state.coordinatorDesignation == null ||
            state.coordinatorDesignation!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter Coordinator Designation.',
          );
          return false;
        }
        if (state.driverName == null || state.driverName!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter Driver Name.',
          );
          return false;
        }
        if (state.driverMobile == null || state.driverMobile!.length != 10) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter a valid 10-digit Driver Mobile.',
          );
          return false;
        }
        if (state.vehicleModel == null || state.vehicleModel!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter Vehicle Model.',
          );
          return false;
        }
        if (state.vehicleNumber == null ||
            state.vehicleNumber!.trim().isEmpty) {
          AppSnackbar.showGlobalError(
            title: 'Validation Error',
            message: 'Please enter Vehicle Number.',
          );
          return false;
        }
        return true;
      case 7:
        // Permission documents are optional; applicant can proceed with 0 or more files
        return true;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final currentStep = wizardState.currentStep;

    Widget currentStepWidget;
    switch (currentStep) {
      case 1:
        currentStepWidget = const Step1SurveyType();
        break;
      case 2:
        currentStepWidget = const Step2StateDistrict();
        break;
      case 3:
        currentStepWidget = const Step3XenDetails();
        break;
      case 4:
        currentStepWidget = const Step4SurveyArea();
        break;
      case 5:
        currentStepWidget = const Step5StartDate();
        break;
      case 6:
        currentStepWidget = const Step6Logistics();
        break;
      case 7:
        currentStepWidget = const Step7Permissions();
        break;
      case 8:
        currentStepWidget = const Step8Review();
        break;
      case 9:
        currentStepWidget = const Step9Acknowledgement();
        break;
      default:
        currentStepWidget = const Step1SurveyType();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentStep > 1 && currentStep < 9) {
          ref.read(bookingWizardViewModelProvider.notifier).previousStep();
        } else {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Survey Booking (Step $currentStep of 9)'),
          leading: currentStep > 1 && currentStep < 9
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    ref
                        .read(bookingWizardViewModelProvider.notifier)
                        .previousStep();
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
        ),
        body: Column(
          children: [
            // Linear Progress Bar
            LinearProgressIndicator(
              value: currentStep / 9.0,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),

            Expanded(child: currentStepWidget),

            // Navigation bar at bottom (for steps 1-7)
            if (currentStep < 8)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (currentStep > 1)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref
                                .read(bookingWizardViewModelProvider.notifier)
                                .previousStep();
                          },
                          child: const Text('Back'),
                        ),
                      ),
                    if (currentStep > 1) SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_validateCurrentStep(currentStep, wizardState)) {
                            ref
                                .read(bookingWizardViewModelProvider.notifier)
                                .nextStep();
                          }
                        },
                        child: Text(
                          currentStep == 7 ? 'Proceed to Review' : 'Next',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
