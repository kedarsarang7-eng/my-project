/// Salary Status
enum SalaryStatus { pending, paid, partial }

/// Salary Record Model
class SalaryModel {
  final String id;
  final String staffId;
  final String userId;
  final int month; // 1-12
  final int year;
  // Attendance summary
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int leaveDays;
  final double totalHoursWorked;
  final double overtimeHours;
  // Earnings
  final double baseSalary;
  final double overtimePay;
  final double bonuses;
  final double incentives;
  final double allowances;
  final double grossSalary;
  // Deductions
  final double advances;
  final double loans;
  final double latePenalty;
  final double otherDeductions;
  final double totalDeductions;
  // Final amount
  final double netSalary;
  // Payment details
  final SalaryStatus status;
  final double paidAmount;
  final DateTime? paidAt;
  final String? paymentMode;
  final String? paymentReference;
  final String? notes;
  final String? calculationDetailsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String? syncOperationId;

  const SalaryModel({
    required this.id,
    required this.staffId,
    required this.userId,
    required this.month,
    required this.year,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    this.halfDays = 0,
    this.leaveDays = 0,
    this.totalHoursWorked = 0.0,
    this.overtimeHours = 0.0,
    required this.baseSalary,
    this.overtimePay = 0.0,
    this.bonuses = 0.0,
    this.incentives = 0.0,
    this.allowances = 0.0,
    required this.grossSalary,
    this.advances = 0.0,
    this.loans = 0.0,
    this.latePenalty = 0.0,
    this.otherDeductions = 0.0,
    this.totalDeductions = 0.0,
    required this.netSalary,
    this.status = SalaryStatus.pending,
    this.paidAmount = 0.0,
    this.paidAt,
    this.paymentMode,
    this.paymentReference,
    this.notes,
    this.calculationDetailsJson,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.syncOperationId,
  });
}

/// Extension for entity mapping
extension SalaryModelX on SalaryModel {
  /// Create from database entity
  static SalaryModel fromEntity(dynamic entity) {
    return SalaryModel(
      id: entity.id as String,
      staffId: entity.staffId as String,
      userId: entity.userId as String,
      month: entity.month as int,
      year: entity.year as int,
      totalDays: entity.totalDays as int,
      presentDays: entity.presentDays as int,
      absentDays: entity.absentDays as int,
      halfDays: entity.halfDays as int,
      leaveDays: entity.leaveDays as int,
      totalHoursWorked: entity.totalHoursWorked as double,
      overtimeHours: entity.overtimeHours as double,
      baseSalary: entity.baseSalary as double,
      overtimePay: entity.overtimePay as double,
      bonuses: entity.bonuses as double,
      incentives: entity.incentives as double,
      allowances: entity.allowances as double,
      grossSalary: entity.grossSalary as double,
      advances: entity.advances as double,
      loans: entity.loans as double,
      latePenalty: entity.latePenalty as double,
      otherDeductions: entity.otherDeductions as double,
      totalDeductions: entity.totalDeductions as double,
      netSalary: entity.netSalary as double,
      status: _parseStatus(entity.status as String),
      paidAmount: entity.paidAmount as double,
      paidAt: entity.paidAt as DateTime?,
      paymentMode: entity.paymentMode as String?,
      paymentReference: entity.paymentReference as String?,
      notes: entity.notes as String?,
      calculationDetailsJson: entity.calculationDetailsJson as String?,
      createdAt: entity.createdAt as DateTime,
      updatedAt: entity.updatedAt as DateTime,
      isSynced: entity.isSynced as bool,
      syncOperationId: entity.syncOperationId as String?,
    );
  }

  static SalaryStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return SalaryStatus.paid;
      case 'PARTIAL':
        return SalaryStatus.partial;
      default:
        return SalaryStatus.pending;
    }
  }
}

/// Extension for salary calculations
extension SalaryCalculations on SalaryModel {
  /// Get remaining balance
  double get remainingBalance => netSalary - paidAmount;

  /// Check if fully paid
  bool get isFullyPaid => paidAmount >= netSalary;

  /// Get period string
  String get periodString {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month]} $year';
  }
}
