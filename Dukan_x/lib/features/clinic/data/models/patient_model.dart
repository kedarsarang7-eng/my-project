/// Patient model for Clinic module
class Patient {
  final String id;
  final String patientId;
  final String name;
  final String? gender;
  final String? phone;
  final String? email;
  final String? bloodGroup;
  final int? dateOfBirth;
  final int? lastVisitDate;
  final DateTime? createdAt;

  Patient({
    required this.id,
    required this.patientId,
    required this.name,
    this.gender,
    this.phone,
    this.email,
    this.bloodGroup,
    this.dateOfBirth,
    this.lastVisitDate,
    this.createdAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'],
      phone: json['phone'],
      email: json['email'],
      bloodGroup: json['bloodGroup'],
      dateOfBirth: json['dateOfBirth'],
      lastVisitDate: json['lastVisitDate'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'name': name,
    'gender': gender,
    'phone': phone,
    'email': email,
    'bloodGroup': bloodGroup,
    'dateOfBirth': dateOfBirth,
    'lastVisitDate': lastVisitDate,
    'createdAt': createdAt?.toIso8601String(),
  };
}
