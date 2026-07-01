import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../repositories/staff_repository.dart';
import '../models/staff_model.dart';
import '../models/attendance_model.dart';
import '../models/salary_model.dart';
import '../../../../core/accounting/money_math.dart';

/// Payroll Service
///
/// Handles salary calculations based on attendance and staff configuration.
class PayrollService {
  final StaffRepository _repository;

  PayrollService(this._repository);

  /// Calculate payable salary for a staff member for a month
  ///
  /// Takes into account:
  /// - Base salary (monthly/daily/hourly)
  /// - Attendance (present days, half days, absents)
  /// - Overtime (if any)
  /// - Deductions (advances, loans, penalties)
  Future<SalaryCalculation> calculateSalary({
    required String staffId,
    required int month,
    required int year,
    double bonuses = 0,
    double advances = 0,
    double loans = 0,
    double otherDeductions = 0,
  }) async {
    // 1. Get staff details
    final staffResult = await _repository.getStaffById(staffId);
    if (!staffResult.isSuccess || staffResult.data == null) {
      return SalaryCalculation.empty();
    }
    final staff = staffResult.data!;

    // 2. Get attendance summary
    final attendance = await _repository.getAttendanceSummary(
      staffId: staffId,
      month: month,
      year: year,
    );

    // 3. Calculate based on salary type
    double baseSalary = 0;
    double overtimePay = 0;

    switch (staff.salaryType) {
      case SalaryType.monthly:
        baseSalary = _calculateMonthlySalary(staff, attendance);
        break;
      case SalaryType.daily:
        baseSalary = _calculateDailySalary(staff, attendance);
        break;
      case SalaryType.hourly:
        baseSalary = _calculateHourlySalary(staff, attendance);
        overtimePay = _calculateOvertimePay(staff, attendance);
        break;
    }

    // 4. Calculate totals
    final grossSalary = baseSalary + overtimePay + bonuses;
    final totalDeductions = advances + loans + otherDeductions;
    final netSalary = grossSalary - totalDeductions;

    return SalaryCalculation(
      staffId: staffId,
      staffName: staff.name,
      month: month,
      year: year,
      attendance: attendance,
      baseSalary: baseSalary,
      overtimePay: overtimePay,
      bonuses: bonuses,
      grossSalary: grossSalary,
      advances: advances,
      loans: loans,
      otherDeductions: otherDeductions,
      totalDeductions: totalDeductions,
      netSalary: netSalary,
    );
  }

  /// Calculate monthly salary based on attendance
  double _calculateMonthlySalary(
    StaffModel staff,
    AttendanceSummary attendance,
  ) {
    final totalWorkingDays =
        attendance.totalDays - _getWeekOffs(attendance.totalDays);
    if (totalWorkingDays == 0) return 0;

    // Per day rate for monthly employees
    final perDayRate = staff.baseSalary / totalWorkingDays;

    // Full pay for present days, half for half days, nothing for absents
    final effectiveDays = attendance.presentDays + (attendance.halfDays * 0.5);

    return perDayRate * effectiveDays;
  }

  /// Calculate daily salary
  double _calculateDailySalary(StaffModel staff, AttendanceSummary attendance) {
    final effectiveDays = attendance.presentDays + (attendance.halfDays * 0.5);
    return staff.dailyRate * effectiveDays;
  }

  /// Calculate hourly salary
  double _calculateHourlySalary(
    StaffModel staff,
    AttendanceSummary attendance,
  ) {
    return staff.hourlyRate * attendance.totalHoursWorked;
  }

  /// Calculate overtime pay (for hourly employees)
  double _calculateOvertimePay(StaffModel staff, AttendanceSummary attendance) {
    // Overtime rate is typically 1.5x or 2x hourly rate
    const overtimeMultiplier = 1.5;
    return staff.hourlyRate * overtimeMultiplier * attendance.overtimeHours;
  }

  /// Estimate weekly offs in a month (typically 4 Sundays)
  int _getWeekOffs(int totalDays) {
    return (totalDays / 7).floor(); // Approximate Sundays
  }

  /// Generate salary for a staff member
  Future<SalaryModel?> generateSalary({
    required String staffId,
    required int month,
    required int year,
    double bonuses = 0,
    double advances = 0,
  }) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return null;

    // Calculate first
    final calculation = await calculateSalary(
      staffId: staffId,
      month: month,
      year: year,
      bonuses: bonuses,
      advances: advances,
    );

    // Create record
    final result = await _repository.createSalaryRecord(
      staffId: staffId,
      userId: userId,
      month: month,
      year: year,
      attendance: calculation.attendance,
      baseSalary: calculation.baseSalary,
      overtimePay: calculation.overtimePay,
      bonuses: calculation.bonuses,
      advances: calculation.advances,
      otherDeductions: calculation.otherDeductions,
    );

    return result.data;
  }

  /// Generate salaries for all staff for a month
  Future<List<SalaryModel>> generateAllSalaries({
    required int month,
    required int year,
  }) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return [];

    final staffResult = await _repository.getAllStaff(userId: userId);
    if (!staffResult.isSuccess) return [];

    final salaries = <SalaryModel>[];

    for (final staff in staffResult.data!) {
      final salary = await generateSalary(
        staffId: staff.id,
        month: month,
        year: year,
      );
      if (salary != null) {
        salaries.add(salary);
      }
    }

    return salaries;
  }

  /// Get total pending salaries amount
  Future<double> getTotalPendingSalaries() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return 0;

    final result = await _repository.getPendingSalaries(userId);
    if (!result.isSuccess || result.data == null) return 0;

    return MoneyMath.sum(result.data!.map((salary) => salary.remainingBalance));
  }
}

/// Salary Calculation Result
class SalaryCalculation {
  final String staffId;
  final String staffName;
  final int month;
  final int year;
  final AttendanceSummary attendance;
  final double baseSalary;
  final double overtimePay;
  final double bonuses;
  final double grossSalary;
  final double advances;
  final double loans;
  final double otherDeductions;
  final double totalDeductions;
  final double netSalary;

  SalaryCalculation({
    required this.staffId,
    required this.staffName,
    required this.month,
    required this.year,
    required this.attendance,
    required this.baseSalary,
    required this.overtimePay,
    required this.bonuses,
    required this.grossSalary,
    required this.advances,
    required this.loans,
    required this.otherDeductions,
    required this.totalDeductions,
    required this.netSalary,
  });

  factory SalaryCalculation.empty() {
    return SalaryCalculation(
      staffId: '',
      staffName: '',
      month: 0,
      year: 0,
      attendance: AttendanceSummary(
        totalDays: 0,
        presentDays: 0,
        absentDays: 0,
        halfDays: 0,
        leaveDays: 0,
        totalHoursWorked: 0,
        overtimeHours: 0,
      ),
      baseSalary: 0,
      overtimePay: 0,
      bonuses: 0,
      grossSalary: 0,
      advances: 0,
      loans: 0,
      otherDeductions: 0,
      totalDeductions: 0,
      netSalary: 0,
    );
  }
}
