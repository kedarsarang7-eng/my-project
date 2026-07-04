/// SalaryComponent model for Universal Staff Management module.
///
/// Maps to the backend SalaryComponent entity (SK: SALCOMP#{employeeId}#{componentId}).
/// Money stored as integer paise on the wire, converted to rupees in the model.
class SalaryComponentModel {
  final String id;
  final String businessId;
  final String employeeId;
  final String type;
  final double amount;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalaryComponentModel({
    required this.id,
    required this.businessId,
    required this.employeeId,
    required this.type,
    required this.amount,
    this.meta,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalaryComponentModel.fromJson(Map<String, dynamic> json) {
    return SalaryComponentModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      type: json['type'] as String? ?? 'monthly',
      amount: ((json['amountPaise'] as num?) ?? 0) / 100.0,
      meta: json['meta'] as Map<String, dynamic>?,
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
    'employeeId': employeeId,
    'type': type,
    'amountPaise': (amount * 100).round(),
    'meta': meta,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
