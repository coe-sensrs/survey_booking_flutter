import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import '../../../../core/constants/validation_constants.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../viewmodel/booking_wizard_viewmodel.dart';

class Step7Permissions extends ConsumerWidget {
  const Step7Permissions({super.key});

  static const Set<String> _allowedExtensions = {'pdf', 'jpg', 'jpeg', 'png'};

  Future<void> _pickDocuments(BuildContext context, WidgetRef ref) async {
    final wizardState = ref.read(bookingWizardViewModelProvider);
    final currentDocs = wizardState.permissionDocs;

    if (currentDocs.length >= ValidationConstants.maxPermissionDocsCount) {
      AppSnackbar.showGlobalError(
        title: 'Limit Reached',
        message:
            'Maximum ${ValidationConstants.maxPermissionDocsCount} permission documents allowed.',
      );
      return;
    }

    try {
      final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions.toList(),
      );

      if (pickedFiles.isEmpty) return;

      final remainingSlots =
          ValidationConstants.maxPermissionDocsCount - currentDocs.length;
      final List<Map<String, dynamic>> validNewDocs = [];
      final List<String> oversizedFiles = [];
      final List<String> invalidTypeFiles = [];
      final List<String> duplicateFiles = [];

      for (final file in pickedFiles) {
        if (file.path == null) continue;

        final fileName = file.name;
        final extension = fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : '';

        // 1. Security & File Type Validation
        if (!_allowedExtensions.contains(extension)) {
          invalidTypeFiles.add(fileName);
          continue;
        }

        // 2. Individual File Size Validation (5MB max)
        final fileSize = await file.length();
        if (fileSize <= 0 || fileSize > ValidationConstants.maxFileSizeBytes) {
          oversizedFiles.add(fileName);
          continue;
        }

        // 3. Duplicate check against existing and currently queued docs
        final isDuplicate =
            currentDocs.any(
              (d) => d['fileName'] == fileName && d['sizeBytes'] == fileSize,
            ) ||
            validNewDocs.any(
              (d) => d['fileName'] == fileName && d['sizeBytes'] == fileSize,
            );

        if (isDuplicate) {
          duplicateFiles.add(fileName);
          continue;
        }

        validNewDocs.add({
          'path': file.path,
          'fileName': fileName,
          'fileType': extension,
          'sizeBytes': fileSize,
        });
      }

      // 4. Handle edge cases & feedback
      if (invalidTypeFiles.isNotEmpty) {
        AppSnackbar.showGlobalError(
          title: 'Invalid File Format',
          message:
              'Skipped unsupported files: ${invalidTypeFiles.join(", ")}. Allowed: PDF, JPG, PNG.',
        );
      }

      if (oversizedFiles.isNotEmpty) {
        AppSnackbar.showGlobalError(
          title: 'File Too Large',
          message: 'Skipped files exceeding 5MB: ${oversizedFiles.join(", ")}.',
        );
      }

      if (duplicateFiles.isNotEmpty && validNewDocs.isEmpty) {
        AppSnackbar.showGlobalWarning(
          title: 'Duplicate Files',
          message: 'Selected document(s) are already attached.',
        );
        return;
      }

      if (validNewDocs.isEmpty) {
        return;
      }

      // 5. Apply capacity clamp
      final docsToAdd = validNewDocs.take(remainingSlots).toList();
      final droppedCount = validNewDocs.length - docsToAdd.length;

      if (droppedCount > 0) {
        AppSnackbar.showGlobalWarning(
          title: 'Slot Limit Reached',
          message:
              'Added ${docsToAdd.length} document(s). $droppedCount file(s) omitted (max 5 allowed).',
        );
      } else if (invalidTypeFiles.isEmpty && oversizedFiles.isEmpty) {
        AppSnackbar.showGlobalSuccess(
          title: 'Documents Added',
          message: 'Successfully attached ${docsToAdd.length} document(s).',
        );
      }

      final updatedList = List<Map<String, dynamic>>.from(currentDocs)
        ..addAll(docsToAdd);

      ref
          .read(bookingWizardViewModelProvider.notifier)
          .updateState(wizardState.copyWith(permissionDocs: updatedList));
    } catch (e) {
      AppSnackbar.showGlobalError(
        title: 'File Pick Error',
        message: 'Failed to pick documents: $e',
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
    final maxDocs = ValidationConstants.maxPermissionDocsCount;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Permission Documents (Optional)',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${docs.length} / $maxDocs',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Upload up to $maxDocs consent/permission documents (PDF, JPG, PNG under 5MB each). You may select multiple files at once, or proceed without uploading.',
            style: TextStyle(
              fontSize: 13.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 20.h),

          if (docs.length < maxDocs)
            ElevatedButton.icon(
              onPressed: () => _pickDocuments(context, ref),
              icon: const Icon(Icons.upload_file),
              label: Text(
                docs.isEmpty
                    ? 'Add Permission Documents'
                    : 'Add More Documents',
              ),
            ),

          SizedBox(height: 16.h),

          if (docs.isEmpty)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'No documents attached. You can attach documents here or proceed directly to Review & Confirm.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Theme.of(context).colorScheme.onSurface,
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
                final sizeInKb = (doc['sizeBytes'] as int) / 1024;
                final sizeDisplay = sizeInKb > 1024
                    ? '${(sizeInKb / 1024).toStringAsFixed(1)} MB'
                    : '${sizeInKb.toStringAsFixed(1)} KB';

                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        (doc['fileType'] as String).toLowerCase() == 'pdf'
                            ? Icons.picture_as_pdf
                            : Icons.image,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22.sp,
                      ),
                    ),
                    title: Text(
                      doc['fileName'] as String? ?? 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${(doc['fileType'] as String).toUpperCase()} • $sizeDisplay',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: 'Remove Document',
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
