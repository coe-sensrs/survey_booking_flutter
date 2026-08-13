import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/profile_viewmodel.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (!mounted || result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.path == null) return;

      final extension = file.extension?.toLowerCase();
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

      // Check 5MB size limit
      if (file.size > 5 * 1024 * 1024) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            title: 'Image Too Large',
            message: 'Profile photo size must be under 5MB.',
          );
        }
        return;
      }

      setState(() => _isUploadingPhoto = true);

      await ref
          .read(profileViewModelProvider.notifier)
          .uploadProfilePhoto(filePath: file.path!, fileName: file.name);

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
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
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
            final isDark =
                Theme.of(bottomSheetContext).brightness == Brightness.dark;

            return Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom:
                    MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24.h,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
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
              backgroundColor: AppColors.rejected,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              Icon(Icons.error_outline, size: 48.sp, color: AppColors.rejected),
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

          final initials = user.fullName.isNotEmpty
              ? user.fullName
                    .split(' ')
                    .where((e) => e.isNotEmpty)
                    .take(2)
                    .map((e) => e[0].toUpperCase())
                    .join()
              : 'A';

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
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
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
                            CircleAvatar(
                              radius: 45.r,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage:
                                  user.photoUrl != null &&
                                      user.photoUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(user.photoUrl!)
                                  : null,
                              child:
                                  user.photoUrl == null ||
                                      user.photoUrl!.isEmpty
                                  ? Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 28.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            if (_isUploadingPhoto)
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
                                onTap: _isUploadingPhoto
                                    ? null
                                    : _pickAndUploadPhoto,
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
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
                            'Applicant',
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
                              color: AppColors.approved,
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
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: AppColors.primary,
                              size: 20.sp,
                            ),
                          ),
                          title: const Text('Appearance'),
                          subtitle: Text(
                            isDark ? 'Dark Theme' : 'Light Theme',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          trailing: Switch(
                            value: isDark,
                            onChanged: (val) {
                              ref
                                  .read(themeProvider.notifier)
                                  .setThemeMode(
                                    val ? ThemeMode.dark : ThemeMode.light,
                                  );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppColors.rejected.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              Icons.logout,
                              color: AppColors.rejected,
                              size: 20.sp,
                            ),
                          ),
                          title: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.rejected),
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
        Icon(icon, size: 18.sp, color: Colors.grey[600]),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
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
