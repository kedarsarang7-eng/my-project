import 'dart:convert';

class PrescriptionItemModel {
  String id;
  String prescriptionId;
  String medicineName;
  String? productId; // Link to inventory
  String? dosage;
  String? frequency;
  String? duration;
  String? instructions;

  PrescriptionItemModel({
    required this.id,
    required this.prescriptionId,
    required this.medicineName,
    this.productId,
    this.dosage,
    this.frequency,
    this.duration,
    this.instructions,
  });

  factory PrescriptionItemModel.fromMap(Map<String, dynamic> map) {
    return PrescriptionItemModel(
      id: map['id'] ?? '',
      prescriptionId: map['prescriptionId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      productId: map['productId'],
      dosage: map['dosage'],
      frequency: map['frequency'],
      duration: map['duration'],
      instructions: map['instructions'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'prescriptionId': prescriptionId,
    'medicineName': medicineName,
    'productId': productId,
    'dosage': dosage,
    'frequency': frequency,
    'duration': duration,
    'instructions': instructions,
  };
}

class PrescriptionModel {
  String id;
  String doctorId;
  String patientId;
  String visitId;
  DateTime date;
  String? advice;
  List<PrescriptionItemModel> items;
  DateTime createdAt;
  DateTime updatedAt;

  PrescriptionModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.visitId,
    required this.date,
    this.advice,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrescriptionModel.fromMap(Map<String, dynamic> map) {
    return PrescriptionModel(
      id: map['id'] ?? '',
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'] ?? '',
      visitId: map['visitId'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      advice: map['advice'],
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => PrescriptionItemModel.fromMap(e))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'doctorId': doctorId,
    'patientId': patientId,
    'visitId': visitId,
    'date': date.toIso8601String(),
    'advice': advice,
    'items': items.map((e) => e.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  // Helper for generic 'medicinesJson' column if needed
  String get medicinesJson => jsonEncode(
    items.map((e) {
      // Map to simplified structure for JSON if schema expects that, or full map
      return {
        'name': e.medicineName,
        'dosage': e.dosage,
        'frequency': e.frequency,
        'duration': e.duration,
        'instructions': e.instructions,
      };
    }).toList(),
  );
}
