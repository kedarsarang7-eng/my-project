/// Job Card model for Auto Parts module
class JobCard {
  final String id;
  final String jobCardNumber;
  final Vehicle vehicle;
  final String customerName;
  final String? customerPhone;
  final String reportedIssue;
  final String status;
  final double estimatedCostPaisa;
  final DateTime createdAt;
  final DateTime? updatedAt;

  JobCard({
    required this.id,
    required this.jobCardNumber,
    required this.vehicle,
    required this.customerName,
    this.customerPhone,
    required this.reportedIssue,
    required this.status,
    this.estimatedCostPaisa = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory JobCard.fromJson(Map<String, dynamic> json) {
    return JobCard(
      id: json['id'] ?? '',
      jobCardNumber: json['jobCardNumber'] ?? '',
      vehicle: Vehicle.fromJson(json['vehicle'] ?? {}),
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'],
      reportedIssue: json['reportedIssue'] ?? '',
      status: json['status'] ?? 'INTAKE',
      estimatedCostPaisa: (json['estimatedCostPaisa'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'jobCardNumber': jobCardNumber,
    'vehicle': vehicle.toJson(),
    'customerName': customerName,
    'customerPhone': customerPhone,
    'reportedIssue': reportedIssue,
    'status': status,
    'estimatedCostPaisa': estimatedCostPaisa,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

class Vehicle {
  final String make;
  final String model;
  final String registrationNumber;
  final int? year;

  Vehicle({
    required this.make,
    required this.model,
    required this.registrationNumber,
    this.year,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      registrationNumber: json['registrationNumber'] ?? '',
      year: json['year'],
    );
  }

  Map<String, dynamic> toJson() => {
    'make': make,
    'model': model,
    'registrationNumber': registrationNumber,
    'year': year,
  };
}
