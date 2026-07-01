// ============================================================================
// CLINIC DASHBOARD DATA MODELS
// ============================================================================
// Maps 1:1 to clinic dashboard API responses
// All amounts are in cents (paise) — divided by 100 for display
// Business Type: clinic (enforced via license validation)
// ============================================================================

import 'package:equatable/equatable.dart';

// ============================================================================
// ENUMS
// ============================================================================

enum ClinicRole {
  admin,
  doctor,
  nurse,
  receptionist,
  labTech,
  pharmacist;

  String get displayName {
    switch (this) {
      case ClinicRole.admin:
        return 'Administrator';
      case ClinicRole.doctor:
        return 'Doctor';
      case ClinicRole.nurse:
        return 'Nurse';
      case ClinicRole.receptionist:
        return 'Receptionist';
      case ClinicRole.labTech:
        return 'Lab Technician';
      case ClinicRole.pharmacist:
        return 'Pharmacist';
    }
  }

  String get apiValue {
    return name.toLowerCase();
  }

  static ClinicRole fromString(String value) {
    return ClinicRole.values.firstWhere(
      (r) => r.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ClinicRole.receptionist,
    );
  }
}

enum AppointmentStatus {
  scheduled,
  completed,
  cancelled,
  noShow,
  inProgress;

  String get displayName {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'Scheduled';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.noShow:
        return 'No Show';
      case AppointmentStatus.inProgress:
        return 'In Progress';
    }
  }

  String get apiValue {
    switch (this) {
      case AppointmentStatus.inProgress:
        return 'in-progress';
      case AppointmentStatus.noShow:
        return 'no-show';
      default:
        return name.toLowerCase();
    }
  }
}

enum StaffStatus {
  onDuty,
  offDuty,
  onLeave,
  busy;

  String get displayName {
    switch (this) {
      case StaffStatus.onDuty:
        return 'On Duty';
      case StaffStatus.offDuty:
        return 'Off Duty';
      case StaffStatus.onLeave:
        return 'On Leave';
      case StaffStatus.busy:
        return 'Busy';
    }
  }

  String get apiValue {
    switch (this) {
      case StaffStatus.onDuty:
        return 'on-duty';
      case StaffStatus.offDuty:
        return 'off-duty';
      case StaffStatus.onLeave:
        return 'on-leave';
      default:
        return name.toLowerCase();
    }
  }
}

enum RoomStatus {
  available,
  occupied,
  cleaning,
  maintenance;

  String get displayName {
    switch (this) {
      case RoomStatus.available:
        return 'Available';
      case RoomStatus.occupied:
        return 'Occupied';
      case RoomStatus.cleaning:
        return 'Cleaning';
      case RoomStatus.maintenance:
        return 'Maintenance';
    }
  }
}

enum InventoryStatus {
  inStock,
  lowStock,
  outOfStock,
  expired;

  String get displayName {
    switch (this) {
      case InventoryStatus.inStock:
        return 'In Stock';
      case InventoryStatus.lowStock:
        return 'Low Stock';
      case InventoryStatus.outOfStock:
        return 'Out of Stock';
      case InventoryStatus.expired:
        return 'Expired';
    }
  }
}

enum WaitTimeZone {
  green,
  yellow,
  red;

  String get displayName {
    switch (this) {
      case WaitTimeZone.green:
        return 'Green Zone';
      case WaitTimeZone.yellow:
        return 'Yellow Zone';
      case WaitTimeZone.red:
        return 'Red Zone';
    }
  }

  String get description {
    switch (this) {
      case WaitTimeZone.green:
        return '< 20 min';
      case WaitTimeZone.yellow:
        return '20-40 min';
      case WaitTimeZone.red:
        return '> 40 min';
    }
  }
}

// ============================================================================
// LICENSE MODEL
// ============================================================================

class ClinicLicense extends Equatable {
  final bool valid;
  final String status;
  final String? clinicId;
  final String? tenantId;
  final String? businessType;
  final String? expiresAt;
  final String? error;

  const ClinicLicense({
    required this.valid,
    required this.status,
    this.clinicId,
    this.tenantId,
    this.businessType,
    this.expiresAt,
    this.error,
  });

  factory ClinicLicense.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return ClinicLicense(
      valid: data['valid'] as bool? ?? false,
      status: data['status'] as String? ?? 'unknown',
      clinicId: data['clinicId'] as String?,
      tenantId: data['tenantId'] as String?,
      businessType: data['businessType'] as String?,
      expiresAt: data['expiresAt'] as String?,
      error: data['error'] as String?,
    );
  }

  bool get isValidClinic => valid && businessType == 'clinic';
  bool get isExpired => status == 'expired';
  bool get isInactive => status == 'inactive';

  @override
  List<Object?> get props => [valid, status, clinicId, tenantId, businessType, expiresAt, error];
}

// ============================================================================
// DASHBOARD OVERVIEW (4 KPI Cards)
// ============================================================================

class DashboardOverview extends Equatable {
  final PatientKpi totalPatients;
  final AppointmentsKpi appointmentsToday;
  final StaffKpi staffOnDuty;
  final RevenueKpi revenueToday;
  final bool isEmpty;
  final String? message;

  const DashboardOverview({
    required this.totalPatients,
    required this.appointmentsToday,
    required this.staffOnDuty,
    required this.revenueToday,
    required this.isEmpty,
    this.message,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return DashboardOverview(
      totalPatients: PatientKpi.fromJson(data['totalPatients'] ?? {}),
      appointmentsToday: AppointmentsKpi.fromJson(data['appointmentsToday'] ?? {}),
      staffOnDuty: StaffKpi.fromJson(data['staffOnDuty'] ?? {}),
      revenueToday: RevenueKpi.fromJson(data['revenueToday'] ?? {}),
      isEmpty: data['isEmpty'] as bool? ?? true,
      message: data['message'] as String?,
    );
  }

  static const empty = DashboardOverview(
    totalPatients: PatientKpi.empty,
    appointmentsToday: AppointmentsKpi.empty,
    staffOnDuty: StaffKpi.empty,
    revenueToday: RevenueKpi.empty,
    isEmpty: true,
  );

  @override
  List<Object?> get props => [totalPatients, appointmentsToday, staffOnDuty, revenueToday, isEmpty, message];
}

class PatientKpi extends Equatable {
  final int count;
  final double changePercent;
  final bool isPositive;

  const PatientKpi({
    required this.count,
    required this.changePercent,
    required this.isPositive,
  });

  factory PatientKpi.fromJson(Map<String, dynamic> json) {
    final change = (json['changePercent'] as num?)?.toDouble() ?? 0;
    return PatientKpi(
      count: (json['count'] as num?)?.toInt() ?? 0,
      changePercent: change.abs(),
      isPositive: change >= 0,
    );
  }

  static const empty = PatientKpi(count: 0, changePercent: 0, isPositive: true);

  @override
  List<Object?> get props => [count, changePercent, isPositive];
}

class AppointmentsKpi extends Equatable {
  final int total;
  final int completed;
  final int pending;
  final int cancelled;

  const AppointmentsKpi({
    required this.total,
    required this.completed,
    required this.pending,
    required this.cancelled,
  });

  factory AppointmentsKpi.fromJson(Map<String, dynamic> json) {
    return AppointmentsKpi(
      total: (json['total'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = AppointmentsKpi(total: 0, completed: 0, pending: 0, cancelled: 0);

  double get completionRate => total > 0 ? (completed / total) * 100 : 0;

  @override
  List<Object?> get props => [total, completed, pending, cancelled];
}

class StaffKpi extends Equatable {
  final int total;
  final int onDuty;

  const StaffKpi({
    required this.total,
    required this.onDuty,
  });

  factory StaffKpi.fromJson(Map<String, dynamic> json) {
    return StaffKpi(
      total: (json['total'] as num?)?.toInt() ?? 0,
      onDuty: (json['onDuty'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = StaffKpi(total: 0, onDuty: 0);

  double get onDutyPercent => total > 0 ? (onDuty / total) * 100 : 0;

  @override
  List<Object?> get props => [total, onDuty];
}

class RevenueKpi extends Equatable {
  final int amountCents;
  final double changePercent;
  final bool isPositive;

  const RevenueKpi({
    required this.amountCents,
    required this.changePercent,
    required this.isPositive,
  });

  factory RevenueKpi.fromJson(Map<String, dynamic> json) {
    final change = (json['changePercent'] as num?)?.toDouble() ?? 0;
    return RevenueKpi(
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      changePercent: change.abs(),
      isPositive: change >= 0,
    );
  }

  static const empty = RevenueKpi(amountCents: 0, changePercent: 0, isPositive: true);

  String get formattedAmount {
    final rupees = amountCents / 100;
    return '₹${rupees.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    )}';
  }

  @override
  List<Object?> get props => [amountCents, changePercent, isPositive];
}

// ============================================================================
// APPOINTMENTS
// ============================================================================

class AppointmentList extends Equatable {
  final List<Appointment> appointments;
  final bool isEmpty;
  final String? message;

  const AppointmentList({
    required this.appointments,
    required this.isEmpty,
    this.message,
  });

  factory AppointmentList.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final items = (data['appointments'] as List<dynamic>? ?? [])
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
    return AppointmentList(
      appointments: items,
      isEmpty: data['isEmpty'] as bool? ?? items.isEmpty,
      message: data['message'] as String?,
    );
  }

  static const empty = AppointmentList(appointments: [], isEmpty: true);

  @override
  List<Object?> get props => [appointments, isEmpty, message];
}

class Appointment extends Equatable {
  final String id;
  final String patientName;
  final String patientId;
  final String doctorName;
  final String doctorId;
  final String type;
  final String startTime;
  final String endTime;
  final String status;
  final String reason;
  final String? roomNumber;

  const Appointment({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.doctorName,
    required this.doctorId,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.reason,
    this.roomNumber,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String? ?? '',
      patientName: json['patientName'] as String? ?? 'Unknown',
      patientId: json['patientId'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? 'Unknown',
      doctorId: json['doctorId'] as String? ?? '',
      type: json['type'] as String? ?? 'consultation',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      status: json['status'] as String? ?? 'scheduled',
      reason: json['reason'] as String? ?? '',
      roomNumber: json['roomNumber'] as String?,
    );
  }

  AppointmentStatus get statusEnum => AppointmentStatus.values.firstWhere(
    (s) => s.apiValue == status,
    orElse: () => AppointmentStatus.scheduled,
  );

  String get formattedTime {
    if (startTime.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(startTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return startTime.substring(11, 16);
    }
  }

  @override
  List<Object?> get props => [id, patientName, patientId, doctorName, doctorId, type, startTime, status];
}

// ============================================================================
// PATIENT INSIGHTS
// ============================================================================

class PatientInsights extends Equatable {
  final List<DepartmentStat> newPatientsByDepartment;
  final List<RecentPatient> recentPatients;
  final bool isEmpty;
  final String? message;

  const PatientInsights({
    required this.newPatientsByDepartment,
    required this.recentPatients,
    required this.isEmpty,
    this.message,
  });

  factory PatientInsights.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final depts = (data['newPatientsByDepartment'] as List<dynamic>? ?? [])
        .map((e) => DepartmentStat.fromJson(e as Map<String, dynamic>))
        .toList();
    final recent = (data['recentPatients'] as List<dynamic>? ?? [])
        .map((e) => RecentPatient.fromJson(e as Map<String, dynamic>))
        .toList();
    return PatientInsights(
      newPatientsByDepartment: depts,
      recentPatients: recent,
      isEmpty: data['isEmpty'] as bool? ?? (depts.isEmpty && recent.isEmpty),
      message: data['message'] as String?,
    );
  }

  static const empty = PatientInsights(
    newPatientsByDepartment: [],
    recentPatients: [],
    isEmpty: true,
  );

  @override
  List<Object?> get props => [newPatientsByDepartment, recentPatients, isEmpty, message];
}

class DepartmentStat extends Equatable {
  final String department;
  final int count;
  final int percentage;

  const DepartmentStat({
    required this.department,
    required this.count,
    required this.percentage,
  });

  factory DepartmentStat.fromJson(Map<String, dynamic> json) {
    return DepartmentStat(
      department: json['department'] as String? ?? 'General',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [department, count, percentage];
}

class RecentPatient extends Equatable {
  final String name;
  final String id;
  final String lastVisit;
  final String reason;
  final String status;

  const RecentPatient({
    required this.name,
    required this.id,
    required this.lastVisit,
    required this.reason,
    required this.status,
  });

  factory RecentPatient.fromJson(Map<String, dynamic> json) {
    return RecentPatient(
      name: json['name'] as String? ?? 'Unknown',
      id: json['id'] as String? ?? '',
      lastVisit: json['lastVisit'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'returning',
    );
  }

  String get formattedLastVisit {
    if (lastVisit.isEmpty) return '';
    try {
      final dt = DateTime.parse(lastVisit);
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return lastVisit.substring(5, 10).replaceAll('-', '/');
    }
  }

  @override
  List<Object?> get props => [name, id, lastVisit, reason, status];
}

// ============================================================================
// STAFF AVAILABILITY
// ============================================================================

class StaffAvailability extends Equatable {
  final List<StaffMember> staff;
  final bool isEmpty;
  final String? message;

  const StaffAvailability({
    required this.staff,
    required this.isEmpty,
    this.message,
  });

  factory StaffAvailability.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final items = (data['staff'] as List<dynamic>? ?? [])
        .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
        .toList();
    return StaffAvailability(
      staff: items,
      isEmpty: data['isEmpty'] as bool? ?? items.isEmpty,
      message: data['message'] as String?,
    );
  }

  static const empty = StaffAvailability(staff: [], isEmpty: true);

  int get doctorsOnDuty => staff.where((s) => s.role == 'doctor' && s.isOnDuty).length;
  int get nursesOnDuty => staff.where((s) => s.role == 'nurse' && s.isOnDuty).length;

  @override
  List<Object?> get props => [staff, isEmpty, message];
}

class StaffMember extends Equatable {
  final String userId;
  final String name;
  final String role;
  final String status;
  final String? department;
  final String? roomAssigned;
  final bool isOnDuty;
  final String? shiftStart;
  final String? shiftEnd;

  const StaffMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    this.department,
    this.roomAssigned,
    required this.isOnDuty,
    this.shiftStart,
    this.shiftEnd,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      role: json['role'] as String? ?? 'staff',
      status: json['status'] as String? ?? 'off-duty',
      department: json['department'] as String?,
      roomAssigned: json['roomAssigned'] as String?,
      isOnDuty: json['isOnDuty'] as bool? ?? false,
      shiftStart: json['shiftStart'] as String?,
      shiftEnd: json['shiftEnd'] as String?,
    );
  }

  String get roleDisplay {
    switch (role.toLowerCase()) {
      case 'doctor':
        return 'Dr. $name';
      case 'nurse':
        return 'Nurse $name';
      default:
        return name;
    }
  }

  @override
  List<Object?> get props => [userId, name, role, status, isOnDuty];
}

// ============================================================================
// ROOMS STATUS
// ============================================================================

class RoomsStatus extends Equatable {
  final List<Room> rooms;
  final int available;
  final int occupied;
  final int cleaning;
  final bool isEmpty;
  final String? message;

  const RoomsStatus({
    required this.rooms,
    required this.available,
    required this.occupied,
    required this.cleaning,
    required this.isEmpty,
    this.message,
  });

  factory RoomsStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final items = (data['rooms'] as List<dynamic>? ?? [])
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
    return RoomsStatus(
      rooms: items,
      available: data['available'] as int? ?? 0,
      occupied: data['occupied'] as int? ?? 0,
      cleaning: data['cleaning'] as int? ?? 0,
      isEmpty: data['isEmpty'] as bool? ?? items.isEmpty,
      message: data['message'] as String?,
    );
  }

  static const empty = RoomsStatus(
    rooms: [],
    available: 0,
    occupied: 0,
    cleaning: 0,
    isEmpty: true,
  );

  int get total => available + occupied + cleaning;
  double get occupancyRate => total > 0 ? (occupied / total) * 100 : 0;

  @override
  List<Object?> get props => [rooms, available, occupied, cleaning, isEmpty];
}

class Room extends Equatable {
  final String roomId;
  final String roomNumber;
  final String type;
  final String status;
  final String? currentPatientName;
  final String? assignedDoctorName;
  final String? nextAvailableAt;

  const Room({
    required this.roomId,
    required this.roomNumber,
    required this.type,
    required this.status,
    this.currentPatientName,
    this.assignedDoctorName,
    this.nextAvailableAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['roomId'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      type: json['type'] as String? ?? 'consultation',
      status: json['status'] as String? ?? 'available',
      currentPatientName: json['currentPatientName'] as String?,
      assignedDoctorName: json['assignedDoctorName'] as String?,
      nextAvailableAt: json['nextAvailableAt'] as String?,
    );
  }

  RoomStatus get statusEnum => RoomStatus.values.firstWhere(
    (s) => s.name == status,
    orElse: () => RoomStatus.available,
  );

  @override
  List<Object?> get props => [roomId, roomNumber, type, status, currentPatientName];
}

// ============================================================================
// BILLING SUMMARY
// ============================================================================

class BillingSummary extends Equatable {
  final List<MonthlyRevenue> monthlyRevenue;
  final int pendingInvoices;
  final int pendingAmountCents;
  final int completedPayments;
  final bool isEmpty;
  final String? message;

  const BillingSummary({
    required this.monthlyRevenue,
    required this.pendingInvoices,
    required this.pendingAmountCents,
    required this.completedPayments,
    required this.isEmpty,
    this.message,
  });

  factory BillingSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final revenue = (data['monthlyRevenue'] as List<dynamic>? ?? [])
        .map((e) => MonthlyRevenue.fromJson(e as Map<String, dynamic>))
        .toList();
    return BillingSummary(
      monthlyRevenue: revenue,
      pendingInvoices: (data['pendingInvoices'] as num?)?.toInt() ?? 0,
      pendingAmountCents: (data['pendingAmountCents'] as num?)?.toInt() ?? 0,
      completedPayments: (data['completedPayments'] as num?)?.toInt() ?? 0,
      isEmpty: data['isEmpty'] as bool? ?? revenue.isEmpty,
      message: data['message'] as String?,
    );
  }

  static const empty = BillingSummary(
    monthlyRevenue: [],
    pendingInvoices: 0,
    pendingAmountCents: 0,
    completedPayments: 0,
    isEmpty: true,
  );

  String get formattedPendingAmount {
    final rupees = pendingAmountCents / 100;
    return '₹${rupees.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    )}';
  }

  @override
  List<Object?> get props => [
    monthlyRevenue,
    pendingInvoices,
    pendingAmountCents,
    completedPayments,
    isEmpty,
    message,
  ];
}

class MonthlyRevenue extends Equatable {
  final String month;
  final int amountCents;
  final String formatted;

  const MonthlyRevenue({
    required this.month,
    required this.amountCents,
    required this.formatted,
  });

  factory MonthlyRevenue.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenue(
      month: json['month'] as String? ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      formatted: json['formatted'] as String? ?? '₹0',
    );
  }

  @override
  List<Object?> get props => [month, amountCents, formatted];
}

// ============================================================================
// INVENTORY ALERTS
// ============================================================================

class InventoryAlerts extends Equatable {
  final List<InventoryItem> items;
  final int lowStockCount;
  final int expiredCount;
  final bool isEmpty;
  final String? message;

  const InventoryAlerts({
    required this.items,
    required this.lowStockCount,
    required this.expiredCount,
    required this.isEmpty,
    this.message,
  });

  factory InventoryAlerts.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return InventoryAlerts(
      items: items,
      lowStockCount: (data['lowStockCount'] as num?)?.toInt() ?? 0,
      expiredCount: (data['expiredCount'] as num?)?.toInt() ?? 0,
      isEmpty: data['isEmpty'] as bool? ?? items.isEmpty,
      message: data['message'] as String?,
    );
  }

  static const empty = InventoryAlerts(
    items: [],
    lowStockCount: 0,
    expiredCount: 0,
    isEmpty: true,
  );

  @override
  List<Object?> get props => [items, lowStockCount, expiredCount, isEmpty, message];
}

class InventoryItem extends Equatable {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final int minThreshold;
  final String status;
  final int? daysUntilExpiry;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minThreshold,
    required this.status,
    this.daysUntilExpiry,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      category: json['category'] as String? ?? 'other',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      minThreshold: (json['minThreshold'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'in-stock',
      daysUntilExpiry: (json['daysUntilExpiry'] as num?)?.toInt(),
    );
  }

  bool get isExpired => daysUntilExpiry != null && daysUntilExpiry! < 0;
  bool get isExpiringSoon => daysUntilExpiry != null && daysUntilExpiry! >= 0 && daysUntilExpiry! <= 7;
  bool get isLowStock => quantity <= minThreshold;
  double get stockLevelPercent => minThreshold > 0 ? (quantity / minThreshold) * 100 : 0;

  @override
  List<Object?> get props => [id, name, quantity, status, daysUntilExpiry];
}

// ============================================================================
// WEEKLY APPOINTMENT TRENDS
// ============================================================================

class WeeklyAppointmentTrends extends Equatable {
  final List<DailyTrend> data;
  final bool isEmpty;
  final String? message;

  const WeeklyAppointmentTrends({
    required this.data,
    required this.isEmpty,
    this.message,
  });

  factory WeeklyAppointmentTrends.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final items = (data['data'] as List<dynamic>? ?? [])
        .map((e) => DailyTrend.fromJson(e as Map<String, dynamic>))
        .toList();
    return WeeklyAppointmentTrends(
      data: items,
      isEmpty: data['isEmpty'] as bool? ?? items.isEmpty,
      message: data['message'] as String?,
    );
  }

  static const empty = WeeklyAppointmentTrends(data: [], isEmpty: true);

  int get maxThisWeek => data.isEmpty ? 0 : data.map((d) => d.thisWeek).reduce((a, b) => a > b ? a : b);
  int get maxLastWeek => data.isEmpty ? 0 : data.map((d) => d.lastWeek).reduce((a, b) => a > b ? a : b);
  int get maxValue => maxThisWeek > maxLastWeek ? maxThisWeek : maxLastWeek;

  @override
  List<Object?> get props => [data, isEmpty, message];
}

class DailyTrend extends Equatable {
  final String day;
  final int thisWeek;
  final int lastWeek;

  const DailyTrend({
    required this.day,
    required this.thisWeek,
    required this.lastWeek,
  });

  factory DailyTrend.fromJson(Map<String, dynamic> json) {
    return DailyTrend(
      day: json['day'] as String? ?? '',
      thisWeek: (json['thisWeek'] as num?)?.toInt() ?? 0,
      lastWeek: (json['lastWeek'] as num?)?.toInt() ?? 0,
    );
  }

  double get changePercent => lastWeek > 0 ? ((thisWeek - lastWeek) / lastWeek) * 100 : 0;

  @override
  List<Object?> get props => [day, thisWeek, lastWeek];
}

// ============================================================================
// WAIT TIME
// ============================================================================

class WaitTimeInfo extends Equatable {
  final int avgWaitMinutes;
  final WaitTimeZone zone;
  final int totalCheckedIn;
  final bool isEmpty;
  final String? message;

  const WaitTimeInfo({
    required this.avgWaitMinutes,
    required this.zone,
    required this.totalCheckedIn,
    required this.isEmpty,
    this.message,
  });

  factory WaitTimeInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final zoneStr = data['zone'] as String? ?? 'green';
    return WaitTimeInfo(
      avgWaitMinutes: (data['avgWaitMinutes'] as num?)?.toInt() ?? 0,
      zone: WaitTimeZone.values.firstWhere(
        (z) => z.name == zoneStr,
        orElse: () => WaitTimeZone.green,
      ),
      totalCheckedIn: (data['totalCheckedIn'] as num?)?.toInt() ?? 0,
      isEmpty: data['isEmpty'] as bool? ?? false,
      message: data['message'] as String?,
    );
  }

  static const empty = WaitTimeInfo(
    avgWaitMinutes: 0,
    zone: WaitTimeZone.green,
    totalCheckedIn: 0,
    isEmpty: true,
  );

  String get formattedTime => '$avgWaitMinutes min';

  @override
  List<Object?> get props => [avgWaitMinutes, zone, totalCheckedIn, isEmpty, message];
}
