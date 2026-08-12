class XenDetails {
  final String name;
  final String mobile;
  final String email;

  const XenDetails({
    required this.name,
    required this.mobile,
    required this.email,
  });

  factory XenDetails.fromMap(Map<String, dynamic> map) {
    return XenDetails(
      name: map['name'] as String? ?? '',
      mobile: map['mobile'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'mobile': mobile, 'email': email};
  }
}
