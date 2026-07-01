/// Clinical Visit Entity - Represents a single doctor-patient encounter
class Visit {
  final String id;
  final String patientId;
  final String doctorId; // User ID of the doctor
  final DateTime visitDate;

  // Clinical Data
  final String chiefComplaint; // "Fever, Headache"
  final String diagnosis; // "Viral Fever"
  final String notes; // Private doctor notes
  final List<String> symptoms;

  // Vitals (Optional)
  final String? bp; // "120/80"
  final double? temperature; // 98.6
  final double? weight; // kg
  final int? pulse;
  final int? spO2; // Oxygen saturation %

  // Links
  final String? prescriptionId;
  final String? billId; // Consultation Bill ID

  // Status
  final String status; // 'queued', 'in_progress', 'completed', 'cancelled'

  final DateTime createdAt;
  final DateTime updatedAt;

  const Visit({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.visitDate,
    this.chiefComplaint = '',
    this.diagnosis = '',
    this.notes = '',
    this.symptoms = const [],
    this.bp,
    this.temperature,
    this.weight,
    this.pulse,
    this.spO2,
    this.prescriptionId,
    this.billId,
    this.status = 'queued',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'visitDate': visitDate.toIso8601String(),
      'chiefComplaint': chiefComplaint,
      'diagnosis': diagnosis,
      'notes': notes,
      'symptoms': symptoms,
      'bp': bp,
      'temperature': temperature,
      'weight': weight,
      'pulse': pulse,
      'spO2': spO2,
      'prescriptionId': prescriptionId,
      'billId': billId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Visit.fromMap(String id, Map<String, dynamic> map) {
    return Visit(
      id: id,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      visitDate: DateTime.tryParse(map['visitDate'] ?? '') ?? DateTime.now(),
      chiefComplaint: map['chiefComplaint'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      notes: map['notes'] ?? '',
      symptoms: List<String>.from(map['symptoms'] ?? []),
      bp: map['bp'],
      temperature: (map['temperature'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      pulse: map['pulse'] as int?,
      spO2: map['spO2'] as int?,
      prescriptionId: map['prescriptionId'],
      billId: map['billId'],
      status: map['status'] ?? 'queued',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Visit copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? visitDate,
    String? chiefComplaint,
    String? diagnosis,
    String? notes,
    List<String>? symptoms,
    String? bp,
    double? temperature,
    double? weight,
    int? pulse,
    int? spO2,
    String? prescriptionId,
    String? billId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Visit(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      visitDate: visitDate ?? this.visitDate,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      diagnosis: diagnosis ?? this.diagnosis,
      notes: notes ?? this.notes,
      symptoms: symptoms ?? this.symptoms,
      bp: bp ?? this.bp,
      temperature: temperature ?? this.temperature,
      weight: weight ?? this.weight,
      pulse: pulse ?? this.pulse,
      spO2: spO2 ?? this.spO2,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      billId: billId ?? this.billId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
