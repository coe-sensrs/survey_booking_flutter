enum CampusVisitStatus {
  pending('pending', 'Pending Review'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  final String code;
  final String label;

  const CampusVisitStatus(this.code, this.label);

  static CampusVisitStatus fromCode(String code) {
    return CampusVisitStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => CampusVisitStatus.pending,
    );
  }
}
