/// Adapter: StaffMember is a type alias for StaffListItemModel.
///
/// Petrol pump screens reference `StaffMember` which was the original model
/// name from staff_petrol_pump_app. DukanX renamed it to `StaffListItemModel`
/// but petrol pump screens were never updated.
library;

import 'staff_profile_model.dart';

/// Type adapter — StaffMember wraps StaffListItemModel with the properties
/// petrol pump screens expect.
class StaffMember {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String status;
  final String role;
  final double? totalRevenue;
  final int? transactionsCount;
  final String? createdAt;

  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.status,
    required this.role,
    this.totalRevenue,
    this.transactionsCount,
    this.createdAt,
  });

  /// Create from StaffListItemModel
  factory StaffMember.fromListItem(StaffListItemModel item) {
    return StaffMember(
      id: item.staffId,
      name: item.fullName,
      email: item.email ?? '',
      phone: item.phoneNumber,
      status: item.isActive ? 'active' : 'inactive',
      role: item.role.displayName,
      totalRevenue: item.totalRevenue,
      transactionsCount: item.transactionsCount,
      createdAt: item.joiningDate.isEmpty ? null : item.joiningDate,
    );
  }
}
