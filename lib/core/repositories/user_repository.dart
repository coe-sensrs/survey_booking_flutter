import '../models/app_user.dart';

abstract class UserRepository {
  Future<AppUser?> getUserById(String uid);
  Stream<AppUser?> watchUserById(String uid);
  Future<void> createUser(AppUser user);
  Future<void> updateUserProfile({
    required String uid,
    String? fullName,
    String? orgName,
    String? phone,
  });
  Future<void> updateProfilePhoto({
    required String uid,
    required String photoStoragePath,
  });

  Future<List<AppUser>> getActiveCommitteeMembers();
  Stream<List<AppUser>> watchCommitteeMembers();
}
