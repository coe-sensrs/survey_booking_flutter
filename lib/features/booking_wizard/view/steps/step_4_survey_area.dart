import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step4SurveyArea extends ConsumerStatefulWidget {
  const Step4SurveyArea({super.key});

  @override
  ConsumerState<Step4SurveyArea> createState() => _Step4SurveyAreaState();
}

class _Step4SurveyAreaState extends ConsumerState<Step4SurveyArea> {
  final _areaNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wizardState = ref.read(bookingWizardViewModelProvider);
    _areaNameController.text = wizardState.areaName ?? '';
  }

  @override
  void dispose() {
    _areaNameController.dispose();
    super.dispose();
  }

  Future<void> _pickKmlFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml', 'kmz'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final extension = file.extension?.toLowerCase() ?? 'kml';

        if (extension != 'kml' && extension != 'kmz') {
          AppSnackbar.showGlobalError(
            title: 'Invalid File',
            message: 'Please select a valid .kml or .kmz file.',
          );
          return;
        }

        final wizardState = ref.read(bookingWizardViewModelProvider);
        ref
            .read(bookingWizardViewModelProvider.notifier)
            .updateState(
              wizardState.copyWith(
                kmlFilePath: file.path,
                kmlFileName: file.name,
                kmlFileType: extension,
                kmlFileSize: file.size,
              ),
            );
      }
    } catch (e) {
      AppSnackbar.showGlobalError(
        title: 'File Pick Error',
        message: 'Failed to pick file: $e',
      );
    }
  }

  Future<void> _openKmlFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      AppSnackbar.showGlobalError(
        title: 'File Not Found',
        message:
            'The selected file is no longer available on device. Please select it again.',
      );
      return;
    }

    final fileOpenService = ref.read(fileOpenServiceProvider);
    final success = await fileOpenService.openFile(filePath);
    if (!success) {
      AppSnackbar.showGlobalError(
        title: 'File Open Error',
        message: 'Could not open or share the selected file.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Survey Area & Map File',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Provide the area name and upload the KML or KMZ spatial file.',
            style: TextStyle(
              fontSize: 13.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          AppTextField(
            label: 'Survey Area Name *',
            hint: 'Enter area / site name (max 150 chars)',
            controller: _areaNameController,
            onChanged: (val) {
              ref
                  .read(bookingWizardViewModelProvider.notifier)
                  .updateState(wizardState.copyWith(areaName: val.trim()));
            },
          ),

          SizedBox(height: 20.h),

          Text(
            'Upload KML/KMZ File *',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),

          InkWell(
            onTap: _pickKmlFile,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: wizardState.kmlFileName != null
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    wizardState.kmlFileName != null
                        ? Icons.insert_drive_file
                        : Icons.cloud_upload_outlined,
                    size: 40.sp,
                    color: colorScheme.primary,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    wizardState.kmlFileName ??
                        'Tap to select .kml or .kmz file',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: wizardState.kmlFileName != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: wizardState.kmlFileName != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (wizardState.kmlFileSize != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      '${(wizardState.kmlFileSize! / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (wizardState.kmlFilePath != null) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: () => _openKmlFile(wizardState.kmlFilePath!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open / Preview File'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _pickKmlFile,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Change'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
