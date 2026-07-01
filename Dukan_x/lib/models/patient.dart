/// Patient Entity - Extends basic Customer profile with clinical data
class Patient {
  final String id;
  final String userId; // Clinic Owner ID
  final String customerId; // Linked Customer ID
  final String name;
  final String? phone;

  // Clinical Demographics
  final int age;
  final String gender; // 'Male', 'Female', 'Other'
  final String bloodGroup;

  // Medical History
  final List<String> allergies;
  final List<String> chronicConditions;
  final String emergencyContactName;
  final String emergencyContactPhone;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastVisitId;

  const Patient({
    required this.id,
    required this.userId,
    required this.customerId,
    required this.name,
    this.phone,
    required this.age,
    required this.gender,
    this.bloodGroup = '',
    this.allergies = const [],
    this.chronicConditions = const [],
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    required this.createdAt,
    required this.updatedAt,
    this.lastVisitId,
  });

  factory Patient.empty() => Patient(
    id: '',
    userId: '',
    customerId: '',
    name: '',
    age: 0,
    gender: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'customerId': customerId,
      'name': name,
      'phone': phone,
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastVisitId': lastVisitId,
    };
  }

  factory Patient.fromMap(String id, Map<String, dynamic> map) {
    return Patient(
      id: id,
      userId: map['userId'] ?? '',
      customerId: map['customerId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      age: map['age'] is int
          ? map['age']
          : int.tryParse(map['age']?.toString() ?? '0') ?? 0,
      gender: map['gender'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      allergies: List<String>.from(map['allergies'] ?? []),
      chronicConditions: List<String>.from(map['chronicConditions'] ?? []),
      emergencyContactName: map['emergencyContactName'] ?? '',
      emergencyContactPhone: map['emergencyContactPhone'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      lastVisitId: map['lastVisitId'],
    );
  }

  Patient copyWith({
    String? id,
    String? userId,
    String? customerId,
    String? name,
    String? phone,
    int? age,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? chronicConditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastVisitId,
  }) {
    return Patient(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVisitId: lastVisitId ?? this.lastVisitId,
    );
  }
}
