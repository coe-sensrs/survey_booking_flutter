class Logistics {
  final String coordinatorName;
  final String coordinatorDesignation;
  final String driverName;
  final String driverMobile;
  final String vehicleNumber;
  final String vehicleModel;

  const Logistics({
    required this.coordinatorName,
    required this.coordinatorDesignation,
    required this.driverName,
    required this.driverMobile,
    required this.vehicleNumber,
    required this.vehicleModel,
  });

  factory Logistics.fromMap(Map<String, dynamic> map) {
    return Logistics(
      coordinatorName: map['coordinatorName'] as String? ?? '',
      coordinatorDesignation: map['coordinatorDesignation'] as String? ?? '',
      driverName: map['driverName'] as String? ?? '',
      driverMobile: map['driverMobile'] as String? ?? '',
      vehicleNumber: map['vehicleNumber'] as String? ?? '',
      vehicleModel: map['vehicleModel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'coordinatorName': coordinatorName,
      'coordinatorDesignation': coordinatorDesignation,
      'driverName': driverName,
      'driverMobile': driverMobile,
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
    };
  }
}
