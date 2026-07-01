class DoctorProfileModel {
  String id;
  String vendorId;
  String? specialization;
  String? licenseNumber;
  String? qualification;
  String? clinicName;
  double consultationFee;
  DateTime createdAt;

  DoctorProfileModel({
    required this.id,
    required this.vendorId,
    this.specialization,
    this.licenseNumber,
    this.qualification,
    this.clinicName,
    this.consultationFee = 0.0,
    required this.createdAt,
  });

  factory DoctorProfileModel.fromMap(Map<String, dynamic> map) {
    return DoctorProfileModel(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      specialization: map['specialization'],
      licenseNumber: map['licenseNumber'],
      qualification: map['qualification'],
      clinicName: map['clinicName'],
      consultationFee: (map['consultationFee'] ?? 0.0).toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'vendorId': vendorId,
    'specialization': specialization,
    'licenseNumber': licenseNumber,
    'qualification': qualification,
    'clinicName': clinicName,
    'consultationFee': consultationFee,
    'createdAt': createdAt.toIso8601String(),
  };

  DoctorProfileModel copyWith({
    String? id,
    String? vendorId,
    String? specialization,
    String? licenseNumber,
    String? qualification,
    String? clinicName,
    double? consultationFee,
    DateTime? createdAt,
  }) {
    return DoctorProfileModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      specialization: specialization ?? this.specialization,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      qualification: qualification ?? this.qualification,
      clinicName: clinicName ?? this.clinicName,
      consultationFee: consultationFee ?? this.consultationFee,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
