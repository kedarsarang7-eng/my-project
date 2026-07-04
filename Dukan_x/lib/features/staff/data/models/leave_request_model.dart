/// LeaveRequest model for Universal Staff Management module.
///
/// Maps to the backend LeaveRequest entity (SK: LVREQ#{id}).
class LeaveRequestModel {
  final String id;
  final String businessId;
  final String employeeId;
  final String leaveTypeId;
  final String from;
  final String to;
  final String status;
  final int version;
  final String? reason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LeaveRequestModel({
    required this.id,
    required this.businessId,
    required this.employeeId,
    required this.leaveTypeId,
    required this.from,
    required this.to,
    this.status = 'pending',
    this.version = 1,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      leaveTypeId: json['leaveTypeId'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      version: (json['version'] as num?)?.toInt() ?? 1,
      reason: json['reason'] as String?,
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
    'from': from,
    'to': to,
    'status': status,
    'version': version,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
