import 'package:equatable/equatable.dart';

enum StaffRole {
  pumpOperator,
  cashier,
  manager,
  supervisor,
  admin,
}

class StaffUser extends Equatable {
  final String staffId;
  final String fullName;
  final StaffRole role;
  final String pumpStationId;
  final bool isFirstLogin;
  final bool isActive;
  final String? profileImageUrl;
  final List<String> permissions;

  const StaffUser({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.pumpStationId,
    required this.isFirstLogin,
    required this.isActive,
    this.profileImageUrl,
    required this.permissions,
  });

  @override
  List<Object?> get props => [staffId, fullName, role, pumpStationId, isActive];
}
