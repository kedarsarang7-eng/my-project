import '../../domain/entities/staff_user.dart';

class StaffUserModel {
  final String staffId;
  final String fullName;
  final String role;
  final String pumpStationId;
  final bool isFirstLogin;
  final bool isActive;
  final String? profileImageUrl;
  final List<String> permissions;

  StaffUserModel({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.pumpStationId,
    required this.isFirstLogin,
    required this.isActive,
    this.profileImageUrl,
    required this.permissions,
  });

  factory StaffUserModel.fromJson(Map<String, dynamic> json) {
    return StaffUserModel(
      staffId: json['staffId'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'pump_operator',
      pumpStationId: json['pumpStationId'] ?? '',
      isFirstLogin: json['isFirstLogin'] ?? false,
      isActive: json['isActive'] ?? true,
      profileImageUrl: json['profileImageUrl'],
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staffId': staffId,
      'fullName': fullName,
      'role': role,
      'pumpStationId': pumpStationId,
      'isFirstLogin': isFirstLogin,
      'isActive': isActive,
      'profileImageUrl': profileImageUrl,
      'permissions': permissions,
    };
  }

  StaffUser toEntity() {
    return StaffUser(
      staffId: staffId,
      fullName: fullName,
      role: _parseRole(role),
      pumpStationId: pumpStationId,
      isFirstLogin: isFirstLogin,
      isActive: isActive,
      profileImageUrl: profileImageUrl,
      permissions: permissions,
    );
  }

  static StaffRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'pump_operator':
        return StaffRole.pumpOperator;
      case 'cashier':
        return StaffRole.cashier;
      case 'manager':
        return StaffRole.manager;
      case 'supervisor':
        return StaffRole.supervisor;
      case 'admin':
        return StaffRole.admin;
      default:
        return StaffRole.pumpOperator;
    }
  }
}
