import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionDocument {
  final String storagePath;
  final String originalFileName;
  final String fileType; // 'pdf' | 'jpg' | 'png'
  final int sizeBytes;
  final DateTime uploadedAt;

  const PermissionDocument({
    required this.storagePath,
    required this.originalFileName,
    required this.fileType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory PermissionDocument.fromMap(Map<String, dynamic> map) {
    return PermissionDocument(
      storagePath: map['storagePath'] as String? ?? '',
      originalFileName: map['originalFileName'] as String? ?? '',
      fileType: map['fileType'] as String? ?? 'pdf',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storagePath': storagePath,
      'originalFileName': originalFileName,
      'fileType': fileType,
      'sizeBytes': sizeBytes,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }
}
