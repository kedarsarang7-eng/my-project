/// Lab Report Status
enum LabReportStatus {
  pending, // Test ordered but not yet collected
  collected, // Sample collected
  processing, // Lab processing
  ready, // Results ready
  uploaded, // Report uploaded
}

/// Lab Report Model
class LabReportModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String? visitId;
  final String testName;
  final String? testCode;
  final String? reportUrl;
  final String? notes;
  final LabReportStatus status;
  final DateTime orderedAt;
  final DateTime? uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  LabReportModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.visitId,
    required this.testName,
    this.testCode,
    this.reportUrl,
    this.notes,
    this.status = LabReportStatus.pending,
    required this.orderedAt,
    this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'patientId': patientId,
    'doctorId': doctorId,
    'visitId': visitId,
    'testName': testName,
    'testCode': testCode,
    'reportUrl': reportUrl,
    'notes': notes,
    'status': status.name.toUpperCase(),
    'orderedAt': orderedAt.toIso8601String(),
    'uploadedAt': uploadedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LabReportModel.fromMap(Map<String, dynamic> map) {
    return LabReportModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      visitId: map['visitId'],
      testName: map['testName'] ?? '',
      testCode: map['testCode'],
      reportUrl: map['reportUrl'],
      notes: map['notes'],
      status: parseStatus(map['status']),
      orderedAt: DateTime.tryParse(map['orderedAt'] ?? '') ?? DateTime.now(),
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.tryParse(map['uploadedAt'])
          : null,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  static LabReportStatus parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'COLLECTED':
        return LabReportStatus.collected;
      case 'PROCESSING':
        return LabReportStatus.processing;
      case 'READY':
        return LabReportStatus.ready;
      case 'UPLOADED':
        return LabReportStatus.uploaded;
      default:
        return LabReportStatus.pending;
    }
  }

  LabReportModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? visitId,
    String? testName,
    String? testCode,
    String? reportUrl,
    String? notes,
    LabReportStatus? status,
    DateTime? orderedAt,
    DateTime? uploadedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LabReportModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      visitId: visitId ?? this.visitId,
      testName: testName ?? this.testName,
      testCode: testCode ?? this.testCode,
      reportUrl: reportUrl ?? this.reportUrl,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      orderedAt: orderedAt ?? this.orderedAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
