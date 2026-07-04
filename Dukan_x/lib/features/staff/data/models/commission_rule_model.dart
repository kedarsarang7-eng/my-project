/// CommissionRule model for Universal Staff Management module.
///
/// Maps to the backend CommissionRule entity (SK: COMMRULE#{id}).
class CommissionRuleModel {
  final String id;
  final String businessId;
  final String kind;
  final Map<String, dynamic>? params;
  final String? formula;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommissionRuleModel({
    required this.id,
    required this.businessId,
    required this.kind,
    this.params,
    this.formula,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommissionRuleModel.fromJson(Map<String, dynamic> json) {
    return CommissionRuleModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      kind: json['kind'] as String? ?? 'category',
      params: json['params'] as Map<String, dynamic>?,
      formula: json['formula'] as String?,
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
    'kind': kind,
    'params': params,
    'formula': formula,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
