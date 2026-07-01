class PatientModel {
  String id;
  String name;
  String? phone;
  int? age;
  String? gender;
  String? bloodGroup;
  String? address;
  String? qrToken;
  String? chronicConditions;
  String? allergies;
  DateTime createdAt;
  DateTime updatedAt;
  bool isSynced;

  /// PHI consent flag (clinic task 5.3 — Req 2.11).
  /// null = unconsented (legacy/default), true = patient has consented,
  /// false = patient explicitly declined.
  bool? consent;

  /// Human-readable Unique Health ID / Medical Record Number (clinic task 6.4 — Req 2.19).
  /// Format: "MRN-{YYYYMMDD}-{4-char-hex}" — short, clinic-friendly, unique per tenant.
  /// Nullable for legacy rows; backfilled on migration or on-read.
  String? uhid;

  /// Date of birth (clinic task 9.1 — Req 2.30).
  /// Storing DOB allows the app to derive a current age at any point in time
  /// instead of relying on a static `age` int that goes stale.
  /// Nullable: legacy rows preserved with NULL via explicit v50 migration.
  DateTime? dateOfBirth;

  /// Computed current age derived from [dateOfBirth]. Returns null when DOB is
  /// not set. Falls back to the static [age] field for legacy patients.
  int? get currentAge {
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int years = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        years--;
      }
      return years;
    }
    return age;
  }

  PatientModel({
    required this.id,
    required this.name,
    this.phone,
    this.age,
    this.gender,
    this.bloodGroup,
    this.address,
    this.qrToken,
    this.chronicConditions,
    this.allergies,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.consent,
    this.uhid,
    this.dateOfBirth,
  });

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    return PatientModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      age: map['age'],
      gender: map['gender'],
      bloodGroup: map['bloodGroup'],
      address: map['address'],
      qrToken: map['qrToken'],
      chronicConditions: map['chronicConditions'],
      allergies: map['allergies'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      isSynced: map['isSynced'] ?? false,
      consent: map['consent'],
      uhid: map['uhid'],
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.tryParse(map['dateOfBirth'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'age': age,
    'gender': gender,
    'bloodGroup': bloodGroup,
    'address': address,
    'qrToken': qrToken,
    'chronicConditions': chronicConditions,
    'allergies': allergies,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isSynced': isSynced,
    'consent': consent,
    'uhid': uhid,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
  };

  PatientModel copyWith({
    String? id,
    String? name,
    String? phone,
    int? age,
    String? gender,
    String? bloodGroup,
    String? address,
    String? qrToken,
    String? chronicConditions,
    String? allergies,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? consent,
    String? uhid,
    DateTime? dateOfBirth,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      qrToken: qrToken ?? this.qrToken,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      allergies: allergies ?? this.allergies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      consent: consent ?? this.consent,
      uhid: uhid ?? this.uhid,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}
