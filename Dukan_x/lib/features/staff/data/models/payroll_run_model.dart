/// PayrollRun model for Universal Staff Management module.
///
/// Maps to the backend PayrollRun entity (SK: PAYRUN#{period}).
/// One run per (tenant, business, period). Online-only, single-writer lock.
class PayrollRunModel {
  final String id;
  final String businessId;
  final String period;
  final String status;
  final String? lockOwner;
  final DateTime? lockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayrollRunModel({
    required this.id,
    required this.businessId,
    required this.period,
    this.status = 'draft',
    this.lockOwner,
    this.lockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PayrollRunModel.fromJson(Map<String, dynamic> json) {
    return PayrollRunModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      period: json['period'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      lockOwner: json['lockOwner'] as String?,
      lockedAt: json['lockedAt'] != null
          ? DateTime.tryParse(json['lockedAt'].toString())
          : null,
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
    'period': period,
    'status': status,
    'lockOwner': lockOwner,
    'lockedAt': lockedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
