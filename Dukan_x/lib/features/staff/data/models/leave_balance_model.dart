/// LeaveBalance model for Universal Staff Management module.
///
/// Maps to the backend LeaveBalance entity (SK: LVBAL#{id}).
class LeaveBalanceModel {
  final String id;
  final String businessId;
  final String employeeId;
  final String leaveTypeId;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LeaveBalanceModel({
    required this.id,
    required this.businessId,
    required this.employeeId,
    required this.leaveTypeId,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      leaveTypeId: json['leaveTypeId'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
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
    'leaveTypeId': leaveTypeId,
    'balance': balance,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
