/// Designation model for Universal Staff Management module.
///
/// Maps to the backend Designation entity (SK: DESIG#{id}).
class DesignationModel {
  final String id;
  final String businessId;
  final String title;
  final String? departmentId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DesignationModel({
    required this.id,
    required this.businessId,
    required this.title,
    this.departmentId,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory DesignationModel.fromJson(Map<String, dynamic> json) {
    return DesignationModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      departmentId: json['departmentId'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'title': title,
    'departmentId': departmentId,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
