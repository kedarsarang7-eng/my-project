import 'package:equatable/equatable.dart';

/// Staff Role Enum
enum StaffRole {
  pumpOperator,
  cashier,
  supervisor,
  manager,
  admin;

  String get displayName {
    switch (this) {
      case StaffRole.pumpOperator:
        return 'Pump Attendant';
      case StaffRole.cashier:
        return 'Cashier';
      case StaffRole.supervisor:
        return 'Supervisor';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.admin:
        return 'Admin';
    }
  }

  String get jsonValue {
    switch (this) {
      case StaffRole.pumpOperator:
        return 'pump_operator';
      case StaffRole.cashier:
        return 'cashier';
      case StaffRole.supervisor:
        return 'supervisor';
      case StaffRole.manager:
        return 'manager';
      case StaffRole.admin:
        return 'admin';
    }
  }

  static StaffRole fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'pump_operator':
      case 'pumpoperator':
      case 'attendant':
        return StaffRole.pumpOperator;
      case 'cashier':
        return StaffRole.cashier;
      case 'supervisor':
        return StaffRole.supervisor;
      case 'manager':
        return StaffRole.manager;
      case 'admin':
      case 'owner':
        return StaffRole.admin;
      default:
        return StaffRole.pumpOperator;
    }
  }
}

/// Staff Status Enum
enum StaffStatus {
  active,
  inactive,
  deactivated;

  String get displayName {
    switch (this) {
      case StaffStatus.active:
        return 'Active';
      case StaffStatus.inactive:
        return 'Inactive';
      case StaffStatus.deactivated:
        return 'Deactivated';
    }
  }

  String get jsonValue {
    switch (this) {
      case StaffStatus.active:
        return 'active';
      case StaffStatus.inactive:
        return 'inactive';
      case StaffStatus.deactivated:
        return 'deactivated';
    }
  }

  static StaffStatus fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return StaffStatus.active;
      case 'inactive':
        return StaffStatus.inactive;
      case 'deactivated':
        return StaffStatus.deactivated;
      default:
        return StaffStatus.active;
    }
  }
}

/// Shift Timing Model
class ShiftTiming extends Equatable {
  final String start; // "06:00"
  final String end; // "14:00"
  final List<String> days; // ["MON", "TUE", ...]

  const ShiftTiming({
    required this.start,
    required this.end,
    required this.days,
  });

  factory ShiftTiming.fromJson(Map<String, dynamic> json) {
    return ShiftTiming(
      start: json['start'] ?? '09:00',
      end: json['end'] ?? '17:00',
      days: List<String>.from(json['days'] ?? ['MON', 'TUE', 'WED', 'THU', 'FRI']),
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'days': days,
  };

  ShiftTiming copyWith({
    String? start,
    String? end,
    List<String>? days,
  }) {
    return ShiftTiming(
      start: start ?? this.start,
      end: end ?? this.end,
      days: days ?? this.days,
    );
  }

  @override
  List<Object?> get props => [start, end, days];
}

/// Emergency Contact Model
class EmergencyContact extends Equatable {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relation: json['relation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'relation': relation,
  };

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relation,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
    );
  }

  @override
  List<Object?> get props => [name, phone, relation];
}

/// Staff Permissions Model
class StaffPermissions extends Equatable {
  final bool canDispenseFuel;
  final bool canEditFuelLogs;
  final bool canViewSalesReport;
  final bool canProcessPayments;
  final bool canApplyDiscounts;
  final bool canViewCashDrawer;
  final bool canCloseDayShift;
  final bool canViewInventory;
  final bool canUpdateInventory;
  final bool canOrderStock;
  final bool canViewOtherStaff;
  final bool canManageAttendance;
  final bool canExportReports;
  final bool canViewAllShiftReports;
  final bool canViewOwnShiftReport;

  const StaffPermissions({
    this.canDispenseFuel = false,
    this.canEditFuelLogs = false,
    this.canViewSalesReport = false,
    this.canProcessPayments = false,
    this.canApplyDiscounts = false,
    this.canViewCashDrawer = false,
    this.canCloseDayShift = false,
    this.canViewInventory = false,
    this.canUpdateInventory = false,
    this.canOrderStock = false,
    this.canViewOtherStaff = false,
    this.canManageAttendance = false,
    this.canExportReports = false,
    this.canViewAllShiftReports = false,
    this.canViewOwnShiftReport = false,
  });

  factory StaffPermissions.fromJson(Map<String, dynamic> json) {
    return StaffPermissions(
      canDispenseFuel: json['canDispenseFuel'] ?? false,
      canEditFuelLogs: json['canEditFuelLogs'] ?? false,
      canViewSalesReport: json['canViewSalesReport'] ?? false,
      canProcessPayments: json['canProcessPayments'] ?? false,
      canApplyDiscounts: json['canApplyDiscounts'] ?? false,
      canViewCashDrawer: json['canViewCashDrawer'] ?? false,
      canCloseDayShift: json['canCloseDayShift'] ?? false,
      canViewInventory: json['canViewInventory'] ?? false,
      canUpdateInventory: json['canUpdateInventory'] ?? false,
      canOrderStock: json['canOrderStock'] ?? false,
      canViewOtherStaff: json['canViewOtherStaff'] ?? false,
      canManageAttendance: json['canManageAttendance'] ?? false,
      canExportReports: json['canExportReports'] ?? false,
      canViewAllShiftReports: json['canViewAllShiftReports'] ?? false,
      canViewOwnShiftReport: json['canViewOwnShiftReport'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'canDispenseFuel': canDispenseFuel,
    'canEditFuelLogs': canEditFuelLogs,
    'canViewSalesReport': canViewSalesReport,
    'canProcessPayments': canProcessPayments,
    'canApplyDiscounts': canApplyDiscounts,
    'canViewCashDrawer': canViewCashDrawer,
    'canCloseDayShift': canCloseDayShift,
    'canViewInventory': canViewInventory,
    'canUpdateInventory': canUpdateInventory,
    'canOrderStock': canOrderStock,
    'canViewOtherStaff': canViewOtherStaff,
    'canManageAttendance': canManageAttendance,
    'canExportReports': canExportReports,
    'canViewAllShiftReports': canViewAllShiftReports,
    'canViewOwnShiftReport': canViewOwnShiftReport,
  };

  StaffPermissions copyWith({
    bool? canDispenseFuel,
    bool? canEditFuelLogs,
    bool? canViewSalesReport,
    bool? canProcessPayments,
    bool? canApplyDiscounts,
    bool? canViewCashDrawer,
    bool? canCloseDayShift,
    bool? canViewInventory,
    bool? canUpdateInventory,
    bool? canOrderStock,
    bool? canViewOtherStaff,
    bool? canManageAttendance,
    bool? canExportReports,
    bool? canViewAllShiftReports,
    bool? canViewOwnShiftReport,
  }) {
    return StaffPermissions(
      canDispenseFuel: canDispenseFuel ?? this.canDispenseFuel,
      canEditFuelLogs: canEditFuelLogs ?? this.canEditFuelLogs,
      canViewSalesReport: canViewSalesReport ?? this.canViewSalesReport,
      canProcessPayments: canProcessPayments ?? this.canProcessPayments,
      canApplyDiscounts: canApplyDiscounts ?? this.canApplyDiscounts,
      canViewCashDrawer: canViewCashDrawer ?? this.canViewCashDrawer,
      canCloseDayShift: canCloseDayShift ?? this.canCloseDayShift,
      canViewInventory: canViewInventory ?? this.canViewInventory,
      canUpdateInventory: canUpdateInventory ?? this.canUpdateInventory,
      canOrderStock: canOrderStock ?? this.canOrderStock,
      canViewOtherStaff: canViewOtherStaff ?? this.canViewOtherStaff,
      canManageAttendance: canManageAttendance ?? this.canManageAttendance,
      canExportReports: canExportReports ?? this.canExportReports,
      canViewAllShiftReports: canViewAllShiftReports ?? this.canViewAllShiftReports,
      canViewOwnShiftReport: canViewOwnShiftReport ?? this.canViewOwnShiftReport,
    );
  }

  @override
  List<Object?> get props => [
    canDispenseFuel,
    canEditFuelLogs,
    canViewSalesReport,
    canProcessPayments,
    canApplyDiscounts,
    canViewCashDrawer,
    canCloseDayShift,
    canViewInventory,
    canUpdateInventory,
    canOrderStock,
    canViewOtherStaff,
    canManageAttendance,
    canExportReports,
    canViewAllShiftReports,
    canViewOwnShiftReport,
  ];
}

/// Staff Profile Model - Main model for staff data
class StaffProfileModel extends Equatable {
  final String staffId; // Format: "PP-2024-0042"
  final String cognitoUserId;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String? profilePhotoUrl;
  final StaffRole role;
  final StaffPermissions permissions;
  final ShiftTiming shiftTiming;
  final String joiningDate; // ISO 8601
  final bool isActive;
  final String petrolPumpId;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? lastLoginAt;
  final EmergencyContact? emergencyContact;

  const StaffProfileModel({
    required this.staffId,
    required this.cognitoUserId,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.profilePhotoUrl,
    required this.role,
    required this.permissions,
    required this.shiftTiming,
    required this.joiningDate,
    required this.isActive,
    required this.petrolPumpId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.emergencyContact,
  });

  factory StaffProfileModel.fromJson(Map<String, dynamic> json) {
    return StaffProfileModel(
      staffId: json['staffId'] ?? json['staff_id'] ?? '',
      cognitoUserId: json['cognitoUserId'] ?? json['cognito_user_id'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      email: json['email'],
      profilePhotoUrl: json['profilePhotoUrl'] ?? json['profile_image_url'],
      role: StaffRole.fromJson(json['role'] ?? 'pump_operator'),
      permissions: json['permissions'] != null 
        ? StaffPermissions.fromJson(json['permissions'])
        : const StaffPermissions(),
      shiftTiming: json['shiftTiming'] != null
        ? ShiftTiming.fromJson(json['shiftTiming'])
        : const ShiftTiming(start: '09:00', end: '17:00', days: ['MON', 'TUE', 'WED', 'THU', 'FRI']),
      joiningDate: json['joiningDate'] ?? json['joining_date'] ?? json['createdAt'] ?? '',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      petrolPumpId: json['petrolPumpId'] ?? json['petrol_pump_id'] ?? json['pump_station_id'] ?? '',
      createdBy: json['createdBy'] ?? json['created_by'] ?? '',
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      updatedAt: json['updatedAt'] ?? json['updated_at'] ?? '',
      lastLoginAt: json['lastLoginAt'] ?? json['last_login'],
      emergencyContact: json['emergencyContact'] != null
        ? EmergencyContact.fromJson(json['emergencyContact'])
        : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'staffId': staffId,
    'cognitoUserId': cognitoUserId,
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'email': email,
    'profilePhotoUrl': profilePhotoUrl,
    'role': role.jsonValue,
    'permissions': permissions.toJson(),
    'shiftTiming': shiftTiming.toJson(),
    'joiningDate': joiningDate,
    'isActive': isActive,
    'petrolPumpId': petrolPumpId,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'lastLoginAt': lastLoginAt,
    'emergencyContact': emergencyContact?.toJson(),
  };

  StaffProfileModel copyWith({
    String? staffId,
    String? cognitoUserId,
    String? fullName,
    String? phoneNumber,
    String? email,
    String? profilePhotoUrl,
    StaffRole? role,
    StaffPermissions? permissions,
    ShiftTiming? shiftTiming,
    String? joiningDate,
    bool? isActive,
    String? petrolPumpId,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
    String? lastLoginAt,
    EmergencyContact? emergencyContact,
  }) {
    return StaffProfileModel(
      staffId: staffId ?? this.staffId,
      cognitoUserId: cognitoUserId ?? this.cognitoUserId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      shiftTiming: shiftTiming ?? this.shiftTiming,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      petrolPumpId: petrolPumpId ?? this.petrolPumpId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

  StaffStatus get status => isActive ? StaffStatus.active : StaffStatus.inactive;

  @override
  List<Object?> get props => [
    staffId,
    cognitoUserId,
    fullName,
    phoneNumber,
    email,
    profilePhotoUrl,
    role,
    permissions,
    shiftTiming,
    joiningDate,
    isActive,
    petrolPumpId,
    createdBy,
    createdAt,
    updatedAt,
    lastLoginAt,
    emergencyContact,
  ];
}

/// Staff List Item - Simplified model for list views
class StaffListItemModel extends Equatable {
  final String staffId;
  final String fullName;
  final StaffRole role;
  final String phoneNumber;
  final String? email;
  final bool isActive;
  final String? profilePhotoUrl;
  final String joiningDate;
  final String? lastLoginAt;
  final int? transactionsCount;
  final double? totalRevenue;

  const StaffListItemModel({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.phoneNumber,
    this.email,
    required this.isActive,
    this.profilePhotoUrl,
    required this.joiningDate,
    this.lastLoginAt,
    this.transactionsCount,
    this.totalRevenue,
  });

  factory StaffListItemModel.fromJson(Map<String, dynamic> json) {
    return StaffListItemModel(
      staffId: json['staffId'] ?? json['staff_id'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      role: StaffRole.fromJson(json['role'] ?? 'pump_operator'),
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      email: json['email'],
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      profilePhotoUrl: json['profilePhotoUrl'] ?? json['profile_image_url'],
      joiningDate: json['joiningDate'] ?? json['joining_date'] ?? json['createdAt'] ?? '',
      lastLoginAt: json['lastLoginAt'] ?? json['last_login'] ?? json['lastLogin'],
      transactionsCount: json['transactionsCount'] ?? json['transactionCount'],
      totalRevenue: json['totalRevenue'] != null 
        ? (json['totalRevenue'] as num).toDouble()
        : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'staffId': staffId,
    'fullName': fullName,
    'role': role.jsonValue,
    'phoneNumber': phoneNumber,
    'email': email,
    'isActive': isActive,
    'profilePhotoUrl': profilePhotoUrl,
    'joiningDate': joiningDate,
    'lastLoginAt': lastLoginAt,
    'transactionsCount': transactionsCount,
    'totalRevenue': totalRevenue,
  };

  StaffListItemModel copyWith({
    String? staffId,
    String? fullName,
    StaffRole? role,
    String? phoneNumber,
    String? email,
    bool? isActive,
    String? profilePhotoUrl,
    String? joiningDate,
    String? lastLoginAt,
    int? transactionsCount,
    double? totalRevenue,
  }) {
    return StaffListItemModel(
      staffId: staffId ?? this.staffId,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      joiningDate: joiningDate ?? this.joiningDate,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      transactionsCount: transactionsCount ?? this.transactionsCount,
      totalRevenue: totalRevenue ?? this.totalRevenue,
    );
  }

  StaffStatus get status => isActive ? StaffStatus.active : StaffStatus.inactive;

  String get initials {
    if (fullName.isEmpty) return '?';
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  List<Object?> get props => [
    staffId,
    fullName,
    role,
    phoneNumber,
    email,
    isActive,
    profilePhotoUrl,
    joiningDate,
    lastLoginAt,
    transactionsCount,
    totalRevenue,
  ];
}

/// Create Staff Request Model
class CreateStaffRequest extends Equatable {
  final String fullName;
  final String phoneNumber;
  final String? email;
  final StaffRole role;
  final ShiftTiming shiftTiming;
  final StaffPermissions? permissions;
  final EmergencyContact? emergencyContact;

  const CreateStaffRequest({
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.role,
    required this.shiftTiming,
    this.permissions,
    this.emergencyContact,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'email': email,
    'role': role.jsonValue,
    'shiftTiming': shiftTiming.toJson(),
    'permissions': permissions?.toJson(),
    'emergencyContact': emergencyContact?.toJson(),
  };

  @override
  List<Object?> get props => [
    fullName,
    phoneNumber,
    email,
    role,
    shiftTiming,
    permissions,
    emergencyContact,
  ];
}

/// Update Staff Request Model
class UpdateStaffRequest extends Equatable {
  final String? fullName;
  final String? phoneNumber;
  final String? email;
  final StaffRole? role;
  final ShiftTiming? shiftTiming;
  final StaffPermissions? permissions;
  final bool? isActive;
  final EmergencyContact? emergencyContact;

  const UpdateStaffRequest({
    this.fullName,
    this.phoneNumber,
    this.email,
    this.role,
    this.shiftTiming,
    this.permissions,
    this.isActive,
    this.emergencyContact,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (fullName != null) data['fullName'] = fullName;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (email != null) data['email'] = email;
    if (role != null) data['role'] = role!.jsonValue;
    if (shiftTiming != null) data['shiftTiming'] = shiftTiming!.toJson();
    if (permissions != null) data['permissions'] = permissions!.toJson();
    if (isActive != null) data['isActive'] = isActive;
    if (emergencyContact != null) data['emergencyContact'] = emergencyContact!.toJson();
    return data;
  }

  @override
  List<Object?> get props => [
    fullName,
    phoneNumber,
    email,
    role,
    shiftTiming,
    permissions,
    isActive,
    emergencyContact,
  ];
}

/// Create Staff Response Model
class CreateStaffResponse extends Equatable {
  final String staffId;
  final String temporaryPassword;
  final String cognitoUserId;

  const CreateStaffResponse({
    required this.staffId,
    required this.temporaryPassword,
    required this.cognitoUserId,
  });

  factory CreateStaffResponse.fromJson(Map<String, dynamic> json) {
    return CreateStaffResponse(
      staffId: json['staffId'] ?? '',
      temporaryPassword: json['temporaryPassword'] ?? json['tempPassword'] ?? '',
      cognitoUserId: json['cognitoUserId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'staffId': staffId,
    'temporaryPassword': temporaryPassword,
    'cognitoUserId': cognitoUserId,
  };

  @override
  List<Object?> get props => [staffId, temporaryPassword, cognitoUserId];
}

/// Reset Password Response Model
class ResetPasswordResponse extends Equatable {
  final String staffId;
  final String temporaryPassword;
  final String message;

  const ResetPasswordResponse({
    required this.staffId,
    required this.temporaryPassword,
    required this.message,
  });

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      staffId: json['staffId'] ?? '',
      temporaryPassword: json['temporaryPassword'] ?? json['tempPassword'] ?? '',
      message: json['message'] ?? '',
    );
  }

  @override
  List<Object?> get props => [staffId, temporaryPassword, message];
}

/// Staff Stats Model
class StaffStatsModel extends Equatable {
  final int totalStaff;
  final int activeStaff;
  final int inactiveStaff;
  final Map<String, int> staffByRole;
  final int recentJoins;

  const StaffStatsModel({
    required this.totalStaff,
    required this.activeStaff,
    required this.inactiveStaff,
    required this.staffByRole,
    required this.recentJoins,
  });

  factory StaffStatsModel.fromJson(Map<String, dynamic> json) {
    return StaffStatsModel(
      totalStaff: json['totalStaff'] ?? json['total'] ?? 0,
      activeStaff: json['activeStaff'] ?? json['active'] ?? 0,
      inactiveStaff: json['inactiveStaff'] ?? json['inactive'] ?? 0,
      staffByRole: Map<String, int>.from(json['staffByRole'] ?? {}),
      recentJoins: json['recentJoins'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    totalStaff,
    activeStaff,
    inactiveStaff,
    staffByRole,
    recentJoins,
  ];
}

/// Staff Filters Model
class StaffFilters extends Equatable {
  final StaffRole? role;
  final StaffStatus? status;
  final String? searchQuery;

  const StaffFilters({
    this.role,
    this.status,
    this.searchQuery,
  });

  StaffFilters copyWith({
    StaffRole? role,
    StaffStatus? status,
    String? searchQuery,
  }) {
    return StaffFilters(
      role: role ?? this.role,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  Map<String, String?> toQueryParams() {
    return {
      if (role != null) 'role': role!.jsonValue,
      if (status != null) 'isActive': (status == StaffStatus.active).toString(),
    };
  }

  @override
  List<Object?> get props => [role, status, searchQuery];
}
