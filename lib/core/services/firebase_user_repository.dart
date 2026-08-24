import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirebaseUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  @override
  Future<AppUser?> getUserById(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  @override
  Stream<AppUser?> watchUserById(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }

  @override
  Future<void> createUser(AppUser user) async {
    await _usersRef.doc(user.uid).set(user.toMap());
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    String? fullName,
    String? orgName,
    String? phone,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fullName != null) updates['fullName'] = fullName;
    if (orgName != null) updates['orgName'] = orgName;
    if (phone != null) updates['phone'] = phone;

    await _usersRef.doc(uid).update(updates);
  }

  @override
  Future<void> updateProfilePhoto({
    required String uid,
    required String photoStoragePath,
  }) async {
    await _usersRef.doc(uid).update({
      'photoUrl': photoStoragePath,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteProfilePhoto(String uid) async {
    await _usersRef.doc(uid).update({
      'photoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<AppUser>> getActiveCommitteeMembers() async {
    final snap = await _usersRef
        .where('role', isEqualTo: 'committee')
        .where('active', isEqualTo: true)
        .get();

    return snap.docs.map((doc) => AppUser.fromMap(doc.id, doc.data())).toList();
  }

  @override
  Stream<List<AppUser>> watchCommitteeMembers() {
    return _usersRef.where('role', isEqualTo: 'committee').snapshots().map((
      snap,
    ) {
      return snap.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}
