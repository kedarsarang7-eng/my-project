import 'package:dukanx/core/compat/firestore_compat.dart';

/// Employee permissions for petrol pump operations
class EmployeePermissions {
  final bool canOpenShift;
  final bool canCloseShift;
  final bool canEditReadings;
  final bool canAddPurchase;
  final bool canViewReports;
  final bool canManageCredit;

  const EmployeePermissions({
    this.canOpenShift = true,
    this.canCloseShift = true,
    this.canEditReadings = true,
    this.canAddPurchase = false,
    this.canViewReports = false,
    this.canManageCredit = false,
  });

  /// Default permissions for new employees
  static const EmployeePermissions defaults = EmployeePermissions();

  /// Full permissions for managers
  static const EmployeePermissions manager = EmployeePermissions(
    canOpenShift: true,
    canCloseShift: true,
    canEditReadings: true,
    canAddPurchase: true,
    canViewReports: true,
    canManageCredit: true,
  );

  EmployeePermissions copyWith({
    bool? canOpenShift,
    bool? canCloseShift,
    bool? canEditReadings,
    bool? canAddPurchase,
    bool? canViewReports,
    bool? canManageCredit,
  }) {
    return EmployeePermissions(
      canOpenShift: canOpenShift ?? this.canOpenShift,
      canCloseShift: canCloseShift ?? this.canCloseShift,
      canEditReadings: canEditReadings ?? this.canEditReadings,
      canAddPurchase: canAddPurchase ?? this.canAddPurchase,
      canViewReports: canViewReports ?? this.canViewReports,
      canManageCredit: canManageCredit ?? this.canManageCredit,
    );
  }

  Map<String, dynamic> toMap() => {
    'canOpenShift': canOpenShift,
    'canCloseShift': canCloseShift,
    'canEditReadings': canEditReadings,
    'canAddPurchase': canAddPurchase,
    'canViewReports': canViewReports,
    'canManageCredit': canManageCredit,
  };

  factory EmployeePermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EmployeePermissions();
    return EmployeePermissions(
      canOpenShift: map['canOpenShift'] as bool? ?? true,
      canCloseShift: map['canCloseShift'] as bool? ?? true,
      canEditReadings: map['canEditReadings'] as bool? ?? true,
      canAddPurchase: map['canAddPurchase'] as bool? ?? false,
      canViewReports: map['canViewReports'] as bool? ?? false,
      canManageCredit: map['canManageCredit'] as bool? ?? false,
    );
  }
}

/// Employee entity for petrol pump staff management
class Employee {
  final String employeeId;
  final String name;
  final String phone;
  final String? email;
  final List<String> assignedNozzleIds;
  final List<String> assignedShiftIds;
  final EmployeePermissions permissions;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? role; // Manager, Attendant, etc.

  Employee({
    required this.employeeId,
    required this.name,
    required this.phone,
    this.email,
    this.assignedNozzleIds = const [],
    this.assignedShiftIds = const [],
    this.permissions = const EmployeePermissions(),
    required this.ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    this.role,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Check if employee is currently assigned to an open shift
  bool get isOnShift => assignedShiftIds.isNotEmpty;

  Employee copyWith({
    String? employeeId,
    String? name,
    String? phone,
    String? email,
    List<String>? assignedNozzleIds,
    List<String>? assignedShiftIds,
    EmployeePermissions? permissions,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? role,
  }) {
    return Employee(
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      assignedNozzleIds: assignedNozzleIds ?? this.assignedNozzleIds,
      assignedShiftIds: assignedShiftIds ?? this.assignedShiftIds,
      permissions: permissions ?? this.permissions,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      role: role ?? this.role,
    );
  }

  /// Assign to a shift
  Employee assignToShift(String shiftId) {
    if (assignedShiftIds.contains(shiftId)) return this;
    return copyWith(assignedShiftIds: [...assignedShiftIds, shiftId]);
  }

  /// Unassign from a shift
  Employee unassignFromShift(String shiftId) {
    return copyWith(
      assignedShiftIds: assignedShiftIds.where((id) => id != shiftId).toList(),
    );
  }

  /// Assign to a nozzle
  Employee assignToNozzle(String nozzleId) {
    if (assignedNozzleIds.contains(nozzleId)) return this;
    return copyWith(assignedNozzleIds: [...assignedNozzleIds, nozzleId]);
  }

  /// Clear all shift assignments (at shift close)
  Employee clearShiftAssignments() {
    return copyWith(assignedShiftIds: []);
  }

  Map<String, dynamic> toMap() => {
    'employeeId': employeeId,
    'name': name,
    'phone': phone,
    'email': email,
    'assignedNozzleIds': assignedNozzleIds,
    'assignedShiftIds': assignedShiftIds,
    'permissions': permissions.toMap(),
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isActive': isActive,
    'role': role,
  };

  factory Employee.fromMap(String id, Map<String, dynamic> map) {
    return Employee(
      employeeId: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String?,
      assignedNozzleIds:
          (map['assignedNozzleIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      assignedShiftIds:
          (map['assignedShiftIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      permissions: EmployeePermissions.fromMap(
        map['permissions'] as Map<String, dynamic>?,
      ),
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      isActive: map['isActive'] as bool? ?? true,
      role: map['role'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Default roles
  static const List<String> defaultRoles = [
    'Manager',
    'Attendant',
    'Cashier',
    'Supervisor',
  ];
}
