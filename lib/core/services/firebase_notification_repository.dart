import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/notification_repository.dart';

/// Concrete Firestore implementation of [NotificationRepository].
///
/// Handles persisting and removing FCM device registration tokens
/// in `/users/{uid}`. Updates `updatedAt` on every mutation to comply
/// with Firestore security rules.
class FirebaseNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _firestore;

  FirebaseNotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> addToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
