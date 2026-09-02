import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart' show AppStatusColors;

import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/profile_viewmodel.dart';
import '../../../core/widgets/safe_profile_avatar.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _pickAndUploadPhoto() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (!mounted || file == null || file.path == null) return;

      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      if (extension != 'jpg' &&
          extension != 'jpeg' &&
          extension != 'png' &&
          extension != 'webp') {
        if (mounted) {
          AppSnackbar.showError(
            context,
            title: 'Invalid Image',
            message: 'Please select a JPG or PNG image.',
          );
        }
        return;
      }

      final fileSize = await file.length();
      // Check 5MB size limit
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            title: 'Image Too Large',
            message: 'Profile photo size must be under 5MB.',
          );
        }
        return;
      }

      // 3. Crop image to 1:1 ratio and resize to fixed dimension
      if (!mounted) return;
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path!,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512, // Fixed dimension for consistency and saving storage
        maxHeight: 512,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: const Color(0xFF2E5C45),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 512, height: 512),
          ),
        ],
      );

      if (croppedFile == null) return;

      await ref
          .read(profileViewModelProvider.notifier)
          .uploadProfilePhoto(filePath: croppedFile.path, fileName: file.name);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          title: 'Photo Updated',
          message: 'Your profile photo has been updated successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Upload Failed',
          message: 'Failed to upload profile photo: $e',
        );
      }
    }
  }

  void _showPhotoOptionsSheet(AppUser user) {
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;

    if (!hasPhoto) {
      _pickAndUploadPhoto();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Profile Photo',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    leading: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: Theme.of(ctx).colorScheme.primary,
                        size: 20.sp,
                      ),
                    ),
                    title: const Text('Upload New Photo'),
                    subtitle: const Text('JPG, PNG or WebP up to 5MB'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndUploadPhoto();
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    leading: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(ctx).colorScheme.error,
                        size: 20.sp,
                      ),
                    ),
                    title: Text(
                      'Remove Photo',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                    subtitle: const Text('Restore default avatar'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeletePhoto();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeletePhoto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Profile Photo'),
        content: const Text(
          'Are you sure you want to remove your profile photo? This will restore the default avatar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(profileViewModelProvider.notifier)
                    .deleteProfilePhoto();
                if (mounted) {
                  AppSnackbar.showSuccess(
                    context,
                    title: 'Photo Removed',
                    message: 'Your profile photo has been removed.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppSnackbar.showError(
                    context,
                    title: 'Error',
                    message: 'Failed to remove profile photo: $e',
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(AppUser user) {
    final nameController = TextEditingController(text: user.fullName);
    final orgController = TextEditingController(text: user.orgName ?? '');
    final phoneController = TextEditingController(text: user.phone);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom:
                    MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24.h,
              ),
              decoration: BoxDecoration(
                color: Theme.of(bottomSheetContext).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Edit Profile Details',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'Full Name',
                        controller: nameController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 12.h),
                      AppTextField(
                        label: 'Organization (Optional)',
                        controller: orgController,
                        hint: 'Company or Agency name',
                      ),
                      SizedBox(height: 12.h),
                      AppTextField(
                        label: 'Phone Number (10 Digits)',
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().length != 10) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20.h),
                      AppButton(
                        text: 'Save Changes',
                        isLoading: isSaving,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSaving = true);
                          try {
                            await ref
                                .read(profileViewModelProvider.notifier)
                                .updateProfile(
                                  fullName: nameController.text.trim(),
                                  orgName: orgController.text.trim(),
                                  phone: phoneController.text.trim(),
                                );
                            if (bottomSheetContext.mounted) {
                              Navigator.pop(bottomSheetContext);
                            }
                            if (mounted) {
                              AppSnackbar.showSuccess(
                                context,
                                title: 'Profile Updated',
                                message:
                                    'Your profile information has been saved.',
                              );
                            }
                          } catch (e) {
                            if (bottomSheetContext.mounted) {
                              setModalState(() => isSaving = false);
                              AppSnackbar.showError(
                                bottomSheetContext,
                                title: 'Update Error',
                                message: e.toString(),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authViewModelProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUploading = profileState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
      ),
      body: userState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48.sp,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: 12.h),
              Text('Failed to load profile: $err'),
              SizedBox(height: 12.h),
              AppButton(
                text: 'Retry',
                onPressed: () => ref.refresh(authViewModelProvider),
              ),
            ],
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No active user profile.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(authViewModelProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  // Profile Photo & Name Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            GestureDetector(
                              onTap: isUploading
                                  ? null
                                  : () => _showPhotoOptionsSheet(user),
                              child: SafeProfileAvatar(
                                imageUrl: user.photoUrl,
                                radius: 45.r,
                                fallbackIcon: Icons.person,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                iconColor: Colors.white,
                              ),
                            ),
                            if (isUploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: isUploading
                                    ? null
                                    : () => _showPhotoOptionsSheet(user),
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    user.photoUrl != null &&
                                            user.photoUrl!.isNotEmpty
                                        ? Icons.edit
                                        : Icons.camera_alt,
                                    size: 16.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          user.fullName.isNotEmpty
                              ? user.fullName
                              : 'Applicant User',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            user.role.isNotEmpty
                                ? '${user.role[0].toUpperCase()}${user.role.substring(1)}'
                                : 'User',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Information Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                                onPressed: () => _showEditProfileDialog(user),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            label: 'Full Name',
                            value: user.fullName.isNotEmpty
                                ? user.fullName
                                : '—',
                          ),
                          SizedBox(height: 12.h),
                          _buildInfoRow(
                            icon: Icons.business_outlined,
                            label: 'Organization',
                            value: user.orgName?.isNotEmpty == true
                                ? user.orgName!
                                : 'Not Specified',
                          ),
                          SizedBox(height: 12.h),
                          _buildInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            value: user.phone.isNotEmpty ? user.phone : '—',
                          ),
                          SizedBox(height: 12.h),
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email Address',
                            value: user.email,
                            trailing: const Icon(
                              Icons.verified,
                              size: 16,
                              color: AppStatusColors.approved,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Member Since',
                            value: DateFormat(
                              'dd MMM yyyy',
                            ).format(user.createdAt),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Settings & Actions
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20.sp,
                            ),
                          ),
                          title: const Text('Appearance'),
                          subtitle: Text(
                            isDark ? 'Dark Theme' : 'Light Theme',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          trailing: const ThemeToggleButton(),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              Icons.logout,
                              color: Theme.of(context).colorScheme.error,
                              size: 20.sp,
                            ),
                          ),
                          title: Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: _confirmLogout,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18.sp,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
