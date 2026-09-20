import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String role; // 'applicant' | 'admin' | 'committee'
  final String fullName;
  final String? orgName;
  final String email;
  final String phone;
  final String? expertiseTag;
  final bool? active;
  final String? photoUrl;
  final List<String> fcmTokens;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.role,
    required this.fullName,
    this.orgName,
    required this.email,
    required this.phone,
    this.expertiseTag,
    this.active,
    this.photoUrl,
    this.fcmTokens = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApplicant => role == 'applicant';
  bool get isAdmin => role == 'admin';
  bool get isCommittee => role == 'committee';

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      role: map['role'] as String? ?? 'applicant',
      fullName: map['fullName'] as String? ?? '',
      orgName: map['orgName'] as String?,
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      expertiseTag: map['expertiseTag'] as String?,
      active: map['active'] as bool?,
      photoUrl: map['photoUrl'] as String?,
      fcmTokens: (map['fcmTokens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'role': role,
      'fullName': fullName,
      'orgName': orgName,
      'email': email,
      'phone': phone,
      'expertiseTag': expertiseTag,
      'active': active,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
    if (fcmTokens.isNotEmpty) {
      data['fcmTokens'] = fcmTokens;
    }
    return data;
  }
}
