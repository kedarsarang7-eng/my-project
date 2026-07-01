/// Prescription Entity
class Prescription {
  final String id;
  final String visitId;
  final String patientId;
  final String doctorId;
  final DateTime date;

  final List<MedicineItem> medicines;
  final String advice; // General advice/instructions
  final String? nextVisitDate; // "After 5 days" or specific date string

  final DateTime createdAt;
  final DateTime updatedAt;

  const Prescription({
    required this.id,
    required this.visitId,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.medicines,
    this.advice = '',
    this.nextVisitDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visitId': visitId,
      'patientId': patientId,
      'doctorId': doctorId,
      'date': date.toIso8601String(),
      'medicines': medicines.map((e) => e.toMap()).toList(),
      'advice': advice,
      'nextVisitDate': nextVisitDate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Prescription.fromMap(String id, Map<String, dynamic> map) {
    return Prescription(
      id: id,
      visitId: map['visitId'] ?? '',
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      medicines:
          (map['medicines'] as List<dynamic>?)
              ?.map((e) => MedicineItem.fromMap(e))
              .toList() ??
          [],
      advice: map['advice'] ?? '',
      nextVisitDate: map['nextVisitDate'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Prescription copyWith({
    String? id,
    String? visitId,
    String? patientId,
    String? doctorId,
    DateTime? date,
    List<MedicineItem>? medicines,
    String? advice,
    String? nextVisitDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Prescription(
      id: id ?? this.id,
      visitId: visitId ?? this.visitId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      medicines: medicines ?? this.medicines,
      advice: advice ?? this.advice,
      nextVisitDate: nextVisitDate ?? this.nextVisitDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Helper class for individual medicine lines in a prescription
class MedicineItem {
  final String name; // "Paracetamol 500mg"
  final String dosage; // "1-0-1"
  final String timing; // "After Food"
  final String duration; // "3 Days"
  final String type; // "Tablet", "Syrup", "Injection" (Optional)
  final String instructions; // Additional notes

  MedicineItem({
    required this.name,
    this.dosage = '',
    this.timing = '',
    this.duration = '',
    this.type = 'Tablet',
    this.instructions = '',
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'dosage': dosage,
    'timing': timing,
    'duration': duration,
    'type': type,
    'instructions': instructions,
  };

  factory MedicineItem.fromMap(Map<String, dynamic> map) => MedicineItem(
    name: map['name'] ?? '',
    dosage: map['dosage'] ?? '',
    timing: map['timing'] ?? '',
    duration: map['duration'] ?? '',
    type: map['type'] ?? 'Tablet',
    instructions: map['instructions'] ?? '',
  );
}
