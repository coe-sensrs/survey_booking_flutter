import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageUploadService {
  final FirebaseStorage _storage;

  StorageUploadService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadPermissionDocument({
    required String appointmentId,
    required String filePath,
    required String fileName,
  }) async {
    final destination =
        'appointments/$appointmentId/permissionDocuments/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(destination);
    await ref.putFile(File(filePath));
    return destination;
  }

  Future<String> uploadKmlFile({
    required String appointmentId,
    required String filePath,
    required String fileName,
  }) async {
    final destination =
        'appointments/$appointmentId/kml/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(destination);
    await ref.putFile(File(filePath));
    return destination;
  }

  Future<String> uploadProfilePhoto({
    required String uid,
    required String filePath,
    required String fileName,
  }) async {
    final destination =
        'users/$uid/profile/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(destination);
    await ref.putFile(File(filePath));
    return destination;
  }

  Future<String> getDownloadUrl(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    return await ref.getDownloadURL();
  }
}
