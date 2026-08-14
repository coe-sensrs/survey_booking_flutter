import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step7Permissions extends ConsumerWidget {
  const Step7Permissions({super.key});

  Future<void> _pickDocument(BuildContext context, WidgetRef ref) async {
    final wizardState = ref.read(bookingWizardViewModelProvider);

    if (wizardState.permissionDocs.length >= 5) {
      AppSnackbar.showGlobalError(
        title: 'Limit Exceeded',
        message: 'Maximum 5 permission documents allowed.',
      );
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final extension = file.extension?.toLowerCase() ?? 'pdf';

        if (file.size > 5 * 1024 * 1024) {
          AppSnackbar.showGlobalError(
            title: 'File Too Large',
            message: 'File size must not exceed 5MB.',
          );
          return;
        }

        final docMap = {
          'path': file.path,
          'fileName': file.name,
          'fileType': extension,
          'sizeBytes': file.size,
        };

        final updatedList = List<Map<String, dynamic>>.from(
          wizardState.permissionDocs,
        )..add(docMap);

        ref
            .read(bookingWizardViewModelProvider.notifier)
            .updateState(wizardState.copyWith(permissionDocs: updatedList));
      }
    } catch (e) {
      AppSnackbar.showGlobalError(
        title: 'File Pick Error',
        message: 'Failed to pick document: $e',
      );
    }
  }

  void _removeDocument(int index, WidgetRef ref) {
    final wizardState = ref.read(bookingWizardViewModelProvider);
    final updatedList = List<Map<String, dynamic>>.from(
      wizardState.permissionDocs,
    )..removeAt(index);

    ref
        .read(bookingWizardViewModelProvider.notifier)
        .updateState(wizardState.copyWith(permissionDocs: updatedList));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(bookingWizardViewModelProvider);
    final docs = wizardState.permissionDocs;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permission Documents Upload',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Text(
            'Upload 1 to 5 permission or consent documents (PDF, JPG, PNG under 5MB).',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 20.h),

          ElevatedButton.icon(
            onPressed: () => _pickDocument(context, ref),
            icon: const Icon(Icons.upload_file),
            label: const Text('Add Permission Document'),
          ),

          SizedBox(height: 16.h),

          if (docs.isEmpty)
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade800),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'At least 1 permission document is required to proceed.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.description,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      doc['fileName'] as String? ?? 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${(doc['fileType'] as String).toUpperCase()} • ${((doc['sizeBytes'] as int) / 1024).toStringAsFixed(1)} KB',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeDocument(index, ref),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
