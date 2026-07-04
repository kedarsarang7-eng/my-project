/// Department model for Universal Staff Management module.
///
/// Maps to the backend Department entity (SK: DEPT#{id}).
class DepartmentModel {
  final String id;
  final String businessId;
  final String name;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DepartmentModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      name: json['name'] as String? ?? '',
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
    'name': name,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
