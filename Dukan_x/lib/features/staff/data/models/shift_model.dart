/// Shift model for Universal Staff Management module.
///
/// Maps to the backend Shift entity (SK: SHIFT#{id}).
class ShiftModel {
  final String id;
  final String businessId;
  final String name;
  final String start;
  final String end;
  final Map<String, dynamic>? breakRules;
  final int? lateThresholdMin;
  final Map<String, dynamic>? overtimeRule;
  final Map<String, dynamic>? geoFence;
  final Map<String, dynamic>? approvalRule;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShiftModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.start,
    required this.end,
    this.breakRules,
    this.lateThresholdMin,
    this.overtimeRule,
    this.geoFence,
    this.approvalRule,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
      breakRules: json['breakRules'] as Map<String, dynamic>?,
      lateThresholdMin: (json['lateThresholdMin'] as num?)?.toInt(),
      overtimeRule: json['overtimeRule'] as Map<String, dynamic>?,
      geoFence: json['geoFence'] as Map<String, dynamic>?,
      approvalRule: json['approvalRule'] as Map<String, dynamic>?,
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
    'start': start,
    'end': end,
    'breakRules': breakRules,
    'lateThresholdMin': lateThresholdMin,
    'overtimeRule': overtimeRule,
    'geoFence': geoFence,
    'approvalRule': approvalRule,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
