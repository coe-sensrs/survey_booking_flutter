import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

final profileViewModelProvider = AsyncNotifierProvider<ProfileViewModel, void>(
  () {
    return ProfileViewModel();
  },
);

class ProfileViewModel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> updateProfile({
    required String fullName,
    String? orgName,
    required String phone,
  }) async {
    final user = ref.read(authViewModelProvider).value;
    if (user == null) {
      throw const AuthFailure('No active user found. Please log in.');
    }

    state = const AsyncLoading();
    try {
      final userRepository = ref.read(userRepositoryProvider);
      await userRepository.updateUserProfile(
        uid: user.uid,
        fullName: fullName.trim(),
        orgName: orgName?.trim().isEmpty == true ? null : orgName?.trim(),
        phone: phone.trim(),
      );

      // Force refresh user profile across the app
      ref.invalidate(authViewModelProvider);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(
        ServerFailure('Failed to update profile: $e'),
        StackTrace.current,
      );
      rethrow;
    }
  }

  Future<void> uploadProfilePhoto({
    required String filePath,
    required String fileName,
  }) async {
    final user = ref.read(authViewModelProvider).value;
    if (user == null) {
      throw const AuthFailure('No active user found. Please log in.');
    }

    state = const AsyncLoading();
    try {
      final storageUploadService = ref.read(storageUploadServiceProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final oldPhotoUrl = user.photoUrl;

      // 1. Upload to Firebase Storage
      final storagePath = await storageUploadService.uploadProfilePhoto(
        uid: user.uid,
        filePath: filePath,
        fileName: fileName,
      );

      // 2. Obtain download URL
      final downloadUrl = await storageUploadService.getDownloadUrl(
        storagePath,
      );

      // 3. Save photo URL in user's Firestore document
      await userRepository.updateProfilePhoto(
        uid: user.uid,
        photoStoragePath: downloadUrl,
      );

      // 4. Delete old photo from Firebase Storage if it exists
      if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
        await storageUploadService.deleteFileByUrl(oldPhotoUrl);
      }

      // 5. Invalidate auth provider to refresh user data globally
      ref.invalidate(authViewModelProvider);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(
        ServerFailure('Failed to upload profile photo: $e'),
        StackTrace.current,
      );
      rethrow;
    }
  }
}
