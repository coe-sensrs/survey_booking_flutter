import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageUploadService {
  final FirebaseStorage _storage;

  StorageUploadService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  String _getContentType(String fileNameOrExt) {
    final ext = fileNameOrExt.contains('.')
        ? fileNameOrExt.split('.').last.toLowerCase()
        : fileNameOrExt.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'kml':
        return 'application/vnd.google-earth.kml+xml';
      case 'kmz':
        return 'application/vnd.google-earth.kmz';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String> uploadPermissionDocument({
    required String appointmentId,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final destination =
        'appointments/$appointmentId/permissionDocuments/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(destination);
    final metadata = SettableMetadata(
      contentType: _getContentType(fileName),
      customMetadata: {'originalFileName': fileName},
    );
    final uploadTask = ref.putFile(File(filePath), metadata);
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }
    await uploadTask;
    return destination;
  }

  Future<String> uploadKmlFile({
    required String appointmentId,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final destination =
        'appointments/$appointmentId/kml/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(destination);
    final metadata = SettableMetadata(
      contentType: _getContentType(fileName),
      customMetadata: {'originalFileName': fileName},
    );
    final uploadTask = ref.putFile(File(filePath), metadata);
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }
    await uploadTask;
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

    // Compress the image before uploading
    final compressedFile = await _compressImage(File(filePath));
    await ref.putFile(compressedFile);

    // Clean up temporary compressed file
    try {
      if (await compressedFile.exists()) {
        await compressedFile.delete();
      }
    } catch (_) {}

    return destination;
  }

  Future<String> getDownloadUrl(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    return await ref.getDownloadURL();
  }

  Future<void> deleteFileByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      // Ignore deletion errors (e.g., if file doesn't exist)
    }
  }

  /// Compress image to reduce file size
  Future<File> _compressImage(File imageFile) async {
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if too large
      img.Image resized = image;
      if (image.width > 1024 || image.height > 1024) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 1024 : null,
          height: image.height > image.width ? 1024 : null,
        );
      }

      // Compress with quality 70
      final compressed = img.encodeJpg(resized, quality: 70);

      // Save compressed image
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('${tempDir.path}/compressed_$timestamp.jpg');
      await compressedFile.writeAsBytes(compressed);

      return compressedFile;
    } catch (e) {
      throw Exception('Failed to compress image: ${e.toString()}');
    }
  }
}
