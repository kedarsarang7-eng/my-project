/// Staff Role
enum StaffRole {
  admin,
  manager,
  cashier,
  salesperson,
  stockKeeper,
  accountant,
  delivery,
  caterer,
}

/// Employment Type
enum EmploymentType { fullTime, partTime, contract }

/// Salary Type
enum SalaryType { monthly, daily, hourly }

/// Staff Member Model
class StaffModel {
  final String id;
  final String userId; // Owner's ID
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? emergencyContact;
  final StaffRole role;
  final String? department;
  final double baseSalary;
  final SalaryType salaryType;
  final double hourlyRate;
  final double dailyRate;
  final int weeklyHours;
  final List<int> workingDays;
  final String? shiftTiming;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final EmploymentType employmentType;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? upiId;
  final String? aadharNumber;
  final String? panNumber;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isSynced;
  final String? syncOperationId;
  final int version;

  const StaffModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.emergencyContact,
    required this.role,
    this.department,
    this.baseSalary = 0.0,
    this.salaryType = SalaryType.monthly,
    this.hourlyRate = 0.0,
    this.dailyRate = 0.0,
    this.weeklyHours = 48,
    this.workingDays = const [1, 2, 3, 4, 5, 6],
    this.shiftTiming,
    required this.joinedAt,
    this.leftAt,
    this.employmentType = EmploymentType.fullTime,
    this.bankAccountNumber,
    this.bankIfsc,
    this.upiId,
    this.aadharNumber,
    this.panNumber,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = false,
    this.syncOperationId,
    this.version = 1,
  });

  StaffModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? email,
    String? address,
    StaffRole? role,
    double? baseSalary,
    SalaryType? salaryType,
    bool? isActive,
  }) {
    return StaffModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      role: role ?? this.role,
      department: department,
      baseSalary: baseSalary ?? this.baseSalary,
      salaryType: salaryType ?? this.salaryType,
      hourlyRate: hourlyRate,
      dailyRate: dailyRate,
      weeklyHours: weeklyHours,
      workingDays: workingDays,
      shiftTiming: shiftTiming,
      joinedAt: joinedAt,
      leftAt: leftAt,
      employmentType: employmentType,
      bankAccountNumber: bankAccountNumber,
      bankIfsc: bankIfsc,
      upiId: upiId,
      aadharNumber: aadharNumber,
      panNumber: panNumber,
      photoUrl: photoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deletedAt: deletedAt,
      isSynced: false,
      syncOperationId: syncOperationId,
      version: version + 1,
    );
  }
}

/// Extension for entity mapping
extension StaffModelX on StaffModel {
  /// Create from database entity
  static StaffModel fromEntity(dynamic entity) {
    return StaffModel(
      id: entity.id as String,
      userId: entity.userId as String,
      name: entity.name as String,
      phone: entity.phone as String,
      email: entity.email as String?,
      address: entity.address as String?,
      emergencyContact: entity.emergencyContact as String?,
      role: _parseRole(entity.role as String),
      department: entity.department as String?,
      baseSalary: entity.baseSalary as double,
      salaryType: _parseSalaryType(entity.salaryType as String),
      hourlyRate: entity.hourlyRate as double,
      dailyRate: entity.dailyRate as double,
      weeklyHours: entity.weeklyHours as int,
      workingDays: _parseWorkingDays(entity.workingDaysJson as String),
      shiftTiming: entity.shiftTiming as String?,
      joinedAt: entity.joinedAt as DateTime,
      leftAt: entity.leftAt as DateTime?,
      employmentType: _parseEmploymentType(entity.employmentType as String),
      bankAccountNumber: entity.bankAccountNumber as String?,
      bankIfsc: entity.bankIfsc as String?,
      upiId: entity.upiId as String?,
      aadharNumber: entity.aadharNumber as String?,
      panNumber: entity.panNumber as String?,
      photoUrl: entity.photoUrl as String?,
      isActive: entity.isActive as bool,
      createdAt: entity.createdAt as DateTime,
      updatedAt: entity.updatedAt as DateTime,
      deletedAt: entity.deletedAt as DateTime?,
      isSynced: entity.isSynced as bool,
      syncOperationId: entity.syncOperationId as String?,
      version: entity.version as int,
    );
  }

  static StaffRole _parseRole(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return StaffRole.admin;
      case 'MANAGER':
        return StaffRole.manager;
      case 'CASHIER':
        return StaffRole.cashier;
      case 'STOCK_KEEPER':
        return StaffRole.stockKeeper;
      case 'ACCOUNTANT':
        return StaffRole.accountant;
      case 'DELIVERY':
        return StaffRole.delivery;
      default:
        return StaffRole.salesperson;
    }
  }

  static SalaryType _parseSalaryType(String type) {
    switch (type.toUpperCase()) {
      case 'DAILY':
        return SalaryType.daily;
      case 'HOURLY':
        return SalaryType.hourly;
      default:
        return SalaryType.monthly;
    }
  }

  static EmploymentType _parseEmploymentType(String type) {
    switch (type.toUpperCase()) {
      case 'PART_TIME':
        return EmploymentType.partTime;
      case 'CONTRACT':
        return EmploymentType.contract;
      default:
        return EmploymentType.fullTime;
    }
  }

  static List<int> _parseWorkingDays(String json) {
    try {
      final list = json.replaceAll('[', '').replaceAll(']', '').split(',');
      return list.map((s) => int.parse(s.trim())).toList();
    } catch (e) {
      return [1, 2, 3, 4, 5, 6]; // Mon-Sat default
    }
  }
}
