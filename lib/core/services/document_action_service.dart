import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Centralized service for document actions across all detail screens:
/// - Fetch a Firebase Storage download URL from a [storagePath].
/// - Download a KML/KMZ file to a temp dir and share it.
/// - Download a PDF to a temp/cache dir and return the local file path.
class DocumentActionService {
  final FirebaseStorage _storage;
  final Dio _dio;

  DocumentActionService({FirebaseStorage? storage, Dio? dio})
    : _storage = storage ?? FirebaseStorage.instance,
      _dio = dio ?? Dio();

  /// Returns a short-lived download URL for the given storage path.
  /// Throws a [DocumentActionException] on failure.
  Future<String> getDownloadUrl(String storagePath) async {
    if (storagePath.isEmpty) {
      throw DocumentActionException('Storage path is empty.');
    }
    try {
      return await _storage.ref().child(storagePath).getDownloadURL();
    } on FirebaseException catch (e) {
      throw DocumentActionException(_mapFirebaseError(e), cause: e);
    } catch (e) {
      throw DocumentActionException(
        'Failed to get download URL. Please try again.',
        cause: e,
      );
    }
  }

  /// Downloads [storagePath] to a temp file and triggers the native OS share
  /// sheet, so the user can save or open it in Google Earth / a KML app.
  ///
  /// [fileName] is used as the on-disk name (e.g. "boundary.kmz").
  Future<void> shareKmlFile({
    required String storagePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    if (storagePath.isEmpty) {
      throw DocumentActionException('Storage path is empty.');
    }
    final url = await getDownloadUrl(storagePath);
    final localFile = await _downloadToTemp(
      url: url,
      fileName: fileName,
      onProgress: onProgress,
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(localFile.path)], subject: fileName),
    );
  }

  /// Downloads [storagePath] to the application's cache dir and returns the
  /// local file path, ready to be passed to PDFView.
  ///
  /// Caches the file by [storagePath] key so repeat opens skip the download.
  Future<String> downloadPdfForViewing({
    required String storagePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    if (storagePath.isEmpty) {
      throw DocumentActionException('Storage path is empty.');
    }

    // Use a sanitized, stable filename so we can cache by storage path.
    final safeKey = storagePath.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final cacheDir = await getTemporaryDirectory();
    final cachedFile = File('${cacheDir.path}/$safeKey.pdf');

    if (!await cachedFile.exists()) {
      final url = await getDownloadUrl(storagePath);
      await _downloadToFile(
        url: url,
        destination: cachedFile,
        onProgress: onProgress,
      );
    }

    return cachedFile.path;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<File> _downloadToTemp({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final destination = File('${tempDir.path}/$fileName');
    await _downloadToFile(
      url: url,
      destination: destination,
      onProgress: onProgress,
    );
    return destination;
  }

  Future<void> _downloadToFile({
    required String url,
    required File destination,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _dio.download(
        url,
        destination.path,
        onReceiveProgress: onProgress != null
            ? (received, total) {
                if (total > 0) onProgress(received / total);
              }
            : null,
      );
    } on DioException catch (e) {
      throw DocumentActionException(_mapDioError(e), cause: e);
    } catch (e) {
      throw DocumentActionException(
        'Download failed. Please check your connection.',
        cause: e,
      );
    }
  }

  String _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'object-not-found':
        return 'The document no longer exists on the server.';
      case 'unauthorized':
      case 'unauthenticated':
        return 'You do not have permission to access this document.';
      case 'storage/quota-exceeded':
        return 'Storage quota exceeded. Please contact support.';
      default:
        return 'Could not retrieve the document. (${e.code})';
    }
  }

  String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      default:
        return 'Download failed. Please try again.';
    }
  }
}

/// Typed error for document action failures.
class DocumentActionException implements Exception {
  final String message;
  final Object? cause;

  const DocumentActionException(this.message, {this.cause});

  @override
  String toString() => 'DocumentActionException: $message';
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final documentActionServiceProvider = Provider<DocumentActionService>((ref) {
  return DocumentActionService();
});
