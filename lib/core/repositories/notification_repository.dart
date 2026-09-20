/// Abstract interface for persisting FCM tokens to Firestore.
///
/// ViewModels call this via the concrete [FirebaseNotificationService],
/// which already embeds the token registration logic. This interface exists
/// as a seam for testing and to make the boundary explicit.
abstract interface class NotificationRepository {
  /// Registers [token] for [uid] using arrayUnion (idempotent).
  Future<void> addToken(String uid, String token);

  /// Removes [token] from [uid]'s token list.
  Future<void> removeToken(String uid, String token);
}
