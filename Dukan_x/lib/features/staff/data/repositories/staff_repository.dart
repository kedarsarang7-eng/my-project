import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../models/staff_model.dart';
import '../models/attendance_model.dart';
import '../models/salary_model.dart';

/// Staff Repository
///
/// Handles local database operations for staff management
/// with offline-first architecture.
class StaffRepository {
  final AppDatabase _db;

  StaffRepository(this._db);

  // ============================================================================
  // STAFF MEMBER OPERATIONS
  // ============================================================================

  /// Add a new staff member
  Future<RepositoryResult<StaffModel>> addStaffMember({
    required String userId,
    required String name,
    required String phone,
    required String role,
    String? email,
    String? address,
    double baseSalary = 0,
    String salaryType = 'MONTHLY',
    DateTime? joinedAt,
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      await _db
          .into(_db.staffMembers)
          .insert(
            StaffMembersCompanion.insert(
              id: id,
              userId: userId,
              name: name,
              phone: Value(phone), // phone is nullable now
              role: role,
              email: Value(email),
              address: Value(address),
              baseSalary: Value(baseSalary),
              salaryType: Value(salaryType),
              joinedAt: joinedAt ?? now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.staffMembers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Failed to add staff member');
      }

      return RepositoryResult.success(StaffModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error adding staff: $e');
    }
  }

  /// Get all staff members
  Future<RepositoryResult<List<StaffModel>>> getAllStaff({
    required String userId,
    bool activeOnly = true,
  }) async {
    try {
      var query = _db.select(_db.staffMembers)
        ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (activeOnly) {
        query = query..where((t) => t.isActive.equals(true));
      }

      final entities = await query.get();
      return RepositoryResult.success(
        entities.map((e) => StaffModelX.fromEntity(e)).toList(),
      );
    } catch (e) {
      return RepositoryResult.failure('Error fetching staff: $e');
    }
  }

  /// Get staff member by ID
  Future<RepositoryResult<StaffModel>> getStaffById(String id) async {
    try {
      final entity = await (_db.select(
        _db.staffMembers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Staff member not found');
      }

      return RepositoryResult.success(StaffModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error fetching staff: $e');
    }
  }

  /// Update staff member
  Future<RepositoryResult<void>> updateStaff({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? role,
    double? baseSalary,
    String? salaryType,
    bool? isActive,
  }) async {
    try {
      await (_db.update(_db.staffMembers)..where((t) => t.id.equals(id))).write(
        StaffMembersCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          phone: phone != null ? Value(phone) : const Value.absent(),
          email: email != null ? Value(email) : const Value.absent(),
          role: role != null ? Value(role) : const Value.absent(),
          baseSalary: baseSalary != null
              ? Value(baseSalary)
              : const Value.absent(),
          salaryType: salaryType != null
              ? Value(salaryType)
              : const Value.absent(),
          isActive: isActive != null ? Value(isActive) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('Error updating staff: $e');
    }
  }

  /// Soft delete staff member
  Future<RepositoryResult<void>> deleteStaff(String id) async {
    try {
      await (_db.update(_db.staffMembers)..where((t) => t.id.equals(id))).write(
        StaffMembersCompanion(
          isActive: const Value(false),
          deletedAt: Value(DateTime.now()),
          leftAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('Error deleting staff: $e');
    }
  }

  // ============================================================================
  // ATTENDANCE OPERATIONS
  // ============================================================================

  /// Mark attendance for a staff member
  Future<RepositoryResult<AttendanceModel>> markAttendance({
    required String staffId,
    required String userId,
    required DateTime date,
    required String status,
    DateTime? checkIn,
    DateTime? checkOut,
    String? leaveType,
    String? notes,
    String markedBy = 'ADMIN',
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      // Calculate hours worked if check-in and check-out provided
      double hoursWorked = 0;
      if (checkIn != null && checkOut != null) {
        hoursWorked = checkOut.difference(checkIn).inMinutes / 60;
      }

      await _db
          .into(_db.staffAttendance)
          .insert(
            StaffAttendanceCompanion.insert(
              id: id,
              staffId: staffId,
              userId: userId,
              date: DateTime(date.year, date.month, date.day),
              status: status,
              checkIn: Value(checkIn),
              checkOut: Value(checkOut),
              hoursWorked: Value(hoursWorked),
              leaveType: Value(leaveType),
              notes: Value(notes),
              markedBy: Value(markedBy),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.staffAttendance,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Failed to mark attendance');
      }

      return RepositoryResult.success(AttendanceModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error marking attendance: $e');
    }
  }

  /// Get attendance for a staff member for a date range
  Future<RepositoryResult<List<AttendanceModel>>> getAttendance({
    required String staffId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final entities =
          await (_db.select(_db.staffAttendance)
                ..where(
                  (t) =>
                      t.staffId.equals(staffId) &
                      t.date.isBiggerOrEqualValue(fromDate) &
                      t.date.isSmallerOrEqualValue(toDate),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.date)]))
              .get();

      return RepositoryResult.success(
        entities.map((e) => AttendanceModelX.fromEntity(e)).toList(),
      );
    } catch (e) {
      return RepositoryResult.failure('Error fetching attendance: $e');
    }
  }

  /// Get attendance summary for a month
  Future<AttendanceSummary> getAttendanceSummary({
    required String staffId,
    required int month,
    required int year,
  }) async {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    final result = await getAttendance(
      staffId: staffId,
      fromDate: firstDay,
      toDate: lastDay,
    );

    if (!result.isSuccess || result.data == null) {
      return AttendanceSummary(
        totalDays: 0,
        presentDays: 0,
        absentDays: 0,
        halfDays: 0,
        leaveDays: 0,
        totalHoursWorked: 0,
        overtimeHours: 0,
      );
    }

    final records = result.data!;

    int present = 0, absent = 0, halfDay = 0, leave = 0;
    double totalHours = 0, overtime = 0;

    for (final record in records) {
      switch (record.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.halfDay:
          halfDay++;
          break;
        case AttendanceStatus.leave:
          leave++;
          break;
        default:
          break;
      }
      totalHours += record.hoursWorked;
      overtime += record.overtimeHours;
    }

    return AttendanceSummary(
      totalDays: lastDay.day,
      presentDays: present,
      absentDays: absent,
      halfDays: halfDay,
      leaveDays: leave,
      totalHoursWorked: totalHours,
      overtimeHours: overtime,
    );
  }

  /// Get today's attendance for all staff
  Future<RepositoryResult<List<Map<String, dynamic>>>> getTodayAttendance(
    String userId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Get all staff
      final staffResult = await getAllStaff(userId: userId);
      if (!staffResult.isSuccess) {
        return RepositoryResult.failure('Failed to fetch staff');
      }

      // Get today's attendance records
      final attendanceRecords =
          await (_db.select(_db.staffAttendance)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.date.isBiggerOrEqualValue(startOfDay),
              ))
              .get();

      final attendanceMap = {for (var a in attendanceRecords) a.staffId: a};

      final result = staffResult.data!.map((staff) {
        final attendance = attendanceMap[staff.id];
        return {
          'staff': staff,
          'status': attendance?.status ?? 'NOT_MARKED',
          'checkIn': attendance?.checkIn,
          'checkOut': attendance?.checkOut,
        };
      }).toList();

      return RepositoryResult.success(result);
    } catch (e) {
      return RepositoryResult.failure('Error fetching attendance: $e');
    }
  }

  // ============================================================================
  // SALARY OPERATIONS
  // ============================================================================

  /// Create salary record for a staff member
  Future<RepositoryResult<SalaryModel>> createSalaryRecord({
    required String staffId,
    required String userId,
    required int month,
    required int year,
    required AttendanceSummary attendance,
    required double baseSalary,
    double overtimePay = 0,
    double bonuses = 0,
    double advances = 0,
    double otherDeductions = 0,
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      final grossSalary = baseSalary + overtimePay + bonuses;
      final totalDeductions = advances + otherDeductions;
      final netSalary = grossSalary - totalDeductions;

      await _db
          .into(_db.salaryRecords)
          .insert(
            SalaryRecordsCompanion.insert(
              id: id,
              staffId: staffId,
              userId: userId,
              month: month,
              year: year,
              totalDays: attendance.totalDays,
              presentDays: attendance.presentDays,
              absentDays: attendance.absentDays,
              halfDays: Value(attendance.halfDays),
              leaveDays: Value(attendance.leaveDays),
              totalHoursWorked: Value(attendance.totalHoursWorked),
              overtimeHours: Value(attendance.overtimeHours),
              baseSalary: baseSalary,
              overtimePay: Value(overtimePay),
              bonuses: Value(bonuses),
              grossSalary: grossSalary,
              advances: Value(advances),
              otherDeductions: Value(otherDeductions),
              totalDeductions: Value(totalDeductions),
              netSalary: netSalary,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.salaryRecords,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Failed to create salary record');
      }

      return RepositoryResult.success(SalaryModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error creating salary: $e');
    }
  }

  /// Get salary records for a staff member
  Future<RepositoryResult<List<SalaryModel>>> getSalaryRecords({
    required String staffId,
    int? year,
  }) async {
    try {
      var query = _db.select(_db.salaryRecords)
        ..where((t) => t.staffId.equals(staffId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.year),
          (t) => OrderingTerm.desc(t.month),
        ]);

      if (year != null) {
        query = query..where((t) => t.year.equals(year));
      }

      final entities = await query.get();
      return RepositoryResult.success(
        entities.map((e) => SalaryModelX.fromEntity(e)).toList(),
      );
    } catch (e) {
      return RepositoryResult.failure('Error fetching salaries: $e');
    }
  }

  /// Mark salary as paid
  Future<RepositoryResult<void>> markSalaryPaid({
    required String id,
    required double amount,
    required String paymentMode,
    String? paymentReference,
  }) async {
    try {
      // Get current salary record
      final entity = await (_db.select(
        _db.salaryRecords,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Salary record not found');
      }

      final newPaidAmount = entity.paidAmount + amount;
      final status = newPaidAmount >= entity.netSalary ? 'PAID' : 'PARTIAL';

      await (_db.update(
        _db.salaryRecords,
      )..where((t) => t.id.equals(id))).write(
        SalaryRecordsCompanion(
          paidAmount: Value(newPaidAmount),
          status: Value(status),
          paidAt: Value(DateTime.now()),
          paymentMode: Value(paymentMode),
          paymentReference: Value(paymentReference),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('Error marking salary paid: $e');
    }
  }

  /// Get pending salaries for a user
  Future<RepositoryResult<List<SalaryModel>>> getPendingSalaries(
    String userId,
  ) async {
    try {
      final entities =
          await (_db.select(_db.salaryRecords)
                ..where(
                  (t) =>
                      t.userId.equals(userId) &
                      t.status.isIn(['PENDING', 'PARTIAL']),
                )
                ..orderBy([
                  (t) => OrderingTerm.asc(t.year),
                  (t) => OrderingTerm.asc(t.month),
                ]))
              .get();

      return RepositoryResult.success(
        entities.map((e) => SalaryModelX.fromEntity(e)).toList(),
      );
    } catch (e) {
      return RepositoryResult.failure('Error fetching pending salaries: $e');
    }
  }
}
