import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../../../core/constants/survey_type.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step1SurveyType extends ConsumerStatefulWidget {
  const Step1SurveyType({super.key});

  @override
  ConsumerState<Step1SurveyType> createState() => _Step1SurveyTypeState();
}

class _Step1SurveyTypeState extends ConsumerState<Step1SurveyType> {
  final _customNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wizardState = ref.read(bookingWizardViewModelProvider);
    _customNameController.text = wizardState.customSurveyName ?? '';
  }

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final selectedType = wizardState.surveyType;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Survey Type',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Choose the type of survey required for your booking.',
            style: TextStyle(
              fontSize: 13.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          RadioGroup<String?>(
            groupValue: selectedType,
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(bookingWizardViewModelProvider.notifier)
                    .updateState(
                      wizardState.copyWith(
                        surveyType: val,
                        customSurveyName: val == SurveyType.other.code
                            ? _customNameController.text
                            : null,
                      ),
                    );
              }
            },
            child: Column(
              children: SurveyType.values.map((st) {
                final isSelected = selectedType == st.code;
                return Card(
                  elevation: isSelected ? 3 : 1,
                  margin: EdgeInsets.only(bottom: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: RadioListTile<String?>(
                    value: st.code,
                    title: Text(
                      st.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          if (selectedType == SurveyType.other.code) ...[
            SizedBox(height: 12.h),
            AppTextField(
              label: 'Custom Survey Name *',
              hint: 'Enter custom survey title (max 60 chars)',
              controller: _customNameController,
              onChanged: (val) {
                ref
                    .read(bookingWizardViewModelProvider.notifier)
                    .updateState(
                      wizardState.copyWith(customSurveyName: val.trim()),
                    );
              },
            ),
          ],
        ],
      ),
    );
  }
}
