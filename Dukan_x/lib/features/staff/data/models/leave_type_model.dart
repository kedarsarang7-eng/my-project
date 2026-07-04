/// LeaveType model for Universal Staff Management module.
///
/// Maps to the backend LeaveType entity (SK: LVTYPE#{id}).
class LeaveTypeModel {
  final String id;
  final String businessId;
  final String name;
  final Map<String, dynamic> accrualRule;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LeaveTypeModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.accrualRule = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveTypeModel.fromJson(Map<String, dynamic> json) {
    return LeaveTypeModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      accrualRule: json['accrualRule'] as Map<String, dynamic>? ?? {},
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
    'accrualRule': accrualRule,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
