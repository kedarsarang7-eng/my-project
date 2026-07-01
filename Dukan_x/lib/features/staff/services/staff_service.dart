import 'package:drift/drift.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/repository/audit_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../data/models/staff_model.dart';
import '../data/models/attendance_model.dart';
import '../data/models/salary_model.dart';
// actually let's just use List<StaffModel> directly as Service usually returns data,
// OR RepositoryResult if we want to follow pattern. Repository used Result. Service can return data or throw.
// Let's stick to returning data directly for Service, UI handles try-catch or Service handles it.
// Existing StaffListScreen handles RepositoryResult.
// I will return List<StaffModel> and update UI to handle exception.

class StaffService {
  late final AppDatabase _db;
  late final AuditRepository _auditRepo;
  late final SessionManager _sessionManager;

  StaffService({
    AppDatabase? db,
    AuditRepository? auditRepo,
    SessionManager? sessionManager,
  }) {
    _db = db ?? sl<AppDatabase>();
    _auditRepo = auditRepo ?? sl<AuditRepository>();
    _sessionManager = sessionManager ?? sl<SessionManager>();
  }

  String get _ownerId => _sessionManager.ownerId ?? '';

  // ===========================================================================
  // STAFF MANAGEMENT (CRUD)
  // ===========================================================================

  Future<String> createStaff(StaffMembersCompanion staff) async {
    final id = _generateId();
    final now = DateTime.now();

    final companion = staff.copyWith(
      id: Value(id),
      userId: Value(_ownerId),
      createdAt: Value(now),
      updatedAt: Value(now),
      isActive: const Value(true),
      isSynced: const Value(false),
    );

    await _db.into(_db.staffMembers).insert(companion);

    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'staff_members',
      recordId: id,
      action: 'CREATE_STAFF',
      newValueJson: staff.name.value,
    );

    return id;
  }

  Future<void> updateStaff(String id, StaffMembersCompanion staff) async {
    await (_db.update(_db.staffMembers)..where((t) => t.id.equals(id))).write(
      staff.copyWith(
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'staff_members',
      recordId: id,
      action: 'UPDATE_STAFF',
      newValueJson: 'Updated staff details',
    );
  }

  Future<void> deleteStaff(String id) async {
    await (_db.update(_db.staffMembers)..where((t) => t.id.equals(id))).write(
      StaffMembersCompanion(
        isActive: const Value(false),
        deletedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'staff_members',
      recordId: id,
      action: 'DELETE_STAFF',
      newValueJson: 'Soft Deleted',
    );
  }

  Stream<List<StaffMemberEntity>> watchAllStaff() {
    return (_db.select(_db.staffMembers)
          ..where((t) => t.isActive.equals(true) & t.userId.equals(_ownerId)))
        .watch();
  }

  Future<List<StaffModel>> getAllStaff({bool activeOnly = true}) async {
    var query = _db.select(_db.staffMembers)
      ..where((t) => t.userId.equals(_ownerId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    if (activeOnly) {
      query = query..where((t) => t.isActive.equals(true));
    }

    final entities = await query.get();
    return entities.map((e) => StaffModelX.fromEntity(e)).toList();
  }

  Future<StaffModel?> getStaffById(String id) async {
    final entity = await (_db.select(
      _db.staffMembers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    return entity != null ? StaffModelX.fromEntity(entity) : null;
  }

  // ===========================================================================
  // ATTENDANCE
  // ===========================================================================

  Future<void> checkIn(String staffId, {String method = 'MANUAL'}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final id = '${staffId}_${today.millisecondsSinceEpoch}';

    // Check if already checked in today
    final existing =
        await (_db.select(_db.staffAttendance)
              ..where((t) => t.staffId.equals(staffId) & t.date.equals(today)))
            .getSingleOrNull();

    if (existing != null) {
      throw Exception('Staff already marked attendance for today');
    }

    await _db
        .into(_db.staffAttendance)
        .insert(
          StaffAttendanceCompanion(
            id: Value(id),
            userId: Value(_ownerId),
            staffId: Value(staffId),
            date: Value(today),
            checkIn: Value(now),
            checkInTime: Value(now),
            status: const Value('PRESENT'),
            method: Value(method),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    // Audit
    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'staff_attendance',
      recordId: id,
      action: 'CHECK_IN',
      newValueJson: 'Method: $method',
    );
  }

  Future<void> checkOut(String staffId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existing =
        await (_db.select(_db.staffAttendance)
              ..where((t) => t.staffId.equals(staffId) & t.date.equals(today)))
            .getSingleOrNull();

    if (existing == null) {
      // Auto-create check-in if missed? Strict mode says NO.
      throw Exception('Cannot check-out without check-in.');
    }

    if (existing.checkOut != null) {
      throw Exception('Already checked out.');
    }

    // Calculate hours
    final duration = now.difference(existing.checkIn ?? now);
    final hours = duration.inMinutes / 60.0;

    await (_db.update(
      _db.staffAttendance,
    )..where((t) => t.id.equals(existing.id))).write(
      StaffAttendanceCompanion(
        checkOut: Value(now),
        checkOutTime: Value(now),
        hoursWorked: Value(hours),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );

    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'staff_attendance',
      recordId: existing.id,
      action: 'CHECK_OUT',
      newValueJson: 'Hours: ${hours.toStringAsFixed(2)}',
    );
  }

  // ===========================================================================
  // PAYROLL & PERFORMANCE
  // ===========================================================================
  // ===========================================================================
  // ATTENDANCE - ADMIN / MANUAL
  // ===========================================================================

  Future<void> markAttendance({
    required String staffId,
    required DateTime date,
    required String status,
    DateTime? checkIn,
    DateTime? checkOut,
    String method = 'MANUAL',
    String? markedBy,
  }) async {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final id = '${staffId}_${day.millisecondsSinceEpoch}';

    double hours = 0;
    if (checkIn != null && checkOut != null) {
      hours = checkOut.difference(checkIn).inMinutes / 60.0;
    }

    final companion = StaffAttendanceCompanion(
      id: Value(id),
      userId: Value(_ownerId),
      staffId: Value(staffId),
      date: Value(day),
      status: Value(status),
      checkIn: Value(checkIn),
      checkInTime: Value(checkIn),
      checkOut: Value(checkOut),
      checkOutTime: Value(checkOut),
      hoursWorked: Value(hours),
      method: Value(method),
      markedBy: Value(markedBy ?? _ownerId),
      createdAt: Value(now),
      updatedAt: Value(now),
      isSynced: const Value(false),
    );

    await _db.into(_db.staffAttendance).insertOnConflictUpdate(companion);

    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'staff_attendance',
      recordId: id,
      action: 'MARK_ATTENDANCE',
      newValueJson: '$status by ${markedBy ?? _ownerId}',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayAttendance() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // Get all active staff
    final staffList = await getAllStaff(activeOnly: false);

    // Get today's attendance
    final attendanceList =
        await (_db.select(_db.staffAttendance)..where(
              (t) => t.userId.equals(_ownerId) & t.date.equals(startOfDay),
            ))
            .get();

    final attendanceMap = {for (var a in attendanceList) a.staffId: a};

    return staffList.map((staff) {
      final attendance = attendanceMap[staff.id];
      // Convert to Entity or simple Map? UI expects Map from Repo
      // Let's stick to Map for now to minimize UI changes in AttendanceScreen
      return {
        'staff': staff,
        'status': attendance?.status ?? 'NOT_MARKED',
        'checkIn': attendance?.checkIn,
        'checkOut': attendance?.checkOut,
      };
    }).toList();
  }

  Future<AttendanceSummary> getAttendanceSummary({
    required String staffId,
    required int month,
    required int year,
  }) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0);

    final attendanceList =
        await (_db.select(_db.staffAttendance)..where(
              (t) =>
                  t.staffId.equals(staffId) &
                  t.date.isBetween(
                    Variable(startOfMonth),
                    Variable(endOfMonth),
                  ),
            ))
            .get();

    int present = 0, absent = 0, halfDay = 0, leave = 0;
    double totalHours = 0, overtime = 0;

    for (final record in attendanceList) {
      switch (record.status) {
        case 'PRESENT':
          present++;
          break;
        case 'ABSENT':
          absent++;
          break;
        case 'HALF_DAY':
          halfDay++;
          break;
        case 'LEAVE':
          leave++;
          break;
      }
      totalHours += record.hoursWorked;
    }

    // Simple Absent Calculation (Total Days in Month - Marked Days)
    // This is approximate. Ideally should check joining date and today's date.
    final totalDaysInMonth = endOfMonth.day;
    // final markedDays = present + absent + halfDay + leave; // Unused
    // For now assuming unmarked days are NOT absent unless explicitly marked

    return AttendanceSummary(
      totalDays: totalDaysInMonth,
      presentDays: present,
      absentDays: absent,
      halfDays: halfDay,
      leaveDays: leave,
      totalHoursWorked: totalHours,
      overtimeHours: overtime,
    );
  }

  // ===========================================================================
  // PAYROLL & SALARY
  // ===========================================================================

  /// Generate Monthly Salary Record (Renamed from generatePayroll)
  Future<void> generateSalaryRecord({
    required String staffId,
    required int month,
    required int year,
  }) async {
    // 1. Fetch Staff
    final staff = await getStaffById(staffId);
    if (staff == null) return;

    // 2. Fetch Attendance
    final summary = await getAttendanceSummary(
      staffId: staffId,
      month: month,
      year: year,
    );

    // 3. Calculate Pay based on Type
    double pay = 0;
    if (staff.salaryType == SalaryType.monthly) {
      // Simple pro-rata
      final workingDays =
          summary.totalDays - (summary.totalDays ~/ 7); // ~4 Sundays off
      final perDay = staff.baseSalary / (workingDays > 0 ? workingDays : 30);
      pay = (summary.presentDays * perDay) + (summary.halfDays * 0.5 * perDay);
    } else if (staff.salaryType == SalaryType.daily) {
      pay =
          (summary.presentDays * staff.dailyRate) +
          (summary.halfDays * 0.5 * staff.dailyRate);
    } else if (staff.salaryType == SalaryType.hourly) {
      pay = summary.totalHoursWorked * staff.hourlyRate;
    }

    final gross = pay;

    // Calculate deductions
    double deductions = 0;

    // PF (12% of basic if applicable - typically for salary > 15000)
    if (gross >= 15000) {
      deductions += gross * 0.12;
    }

    // ESI (0.75% if applicable - for salary < 21000)
    if (gross < 21000) {
      deductions += gross * 0.0075;
    }

    // TDS (simplified: 10% if salary > 50000/month)
    if (gross > 50000) {
      deductions += (gross - 50000) * 0.10;
    }

    // Advance recovery (if any advances were given, would query from advances table)
    // This is placeholder - in production would query staff_advances table
    final advanceRecovery = 0.0;
    deductions += advanceRecovery;

    final net = gross - deductions;

    // 4. Upsert Record
    final recordId = '${staffId}_${year}_$month';
    final now = DateTime.now();

    final existing = await (_db.select(
      _db.salaryRecords,
    )..where((t) => t.id.equals(recordId))).getSingleOrNull();

    await _db
        .into(_db.salaryRecords)
        .insertOnConflictUpdate(
          SalaryRecordsCompanion(
            id: Value(recordId),
            staffId: Value(staffId),
            userId: Value(_ownerId),
            month: Value(month),
            year: Value(year),
            baseSalary: Value(staff.baseSalary),
            grossSalary: Value(gross),
            netSalary: Value(net),
            presentDays: Value(summary.presentDays),
            halfDays: Value(summary.halfDays),
            absentDays: Value(summary.absentDays),
            totalHoursWorked: Value(summary.totalHoursWorked),
            totalDays: Value(summary.totalDays),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'salary_records',
      recordId: recordId,
      action: 'GENERATE_PAYROLL',
      newValueJson: 'Net: $net',
    );
  }

  Future<List<SalaryModel>> getPendingSalaries() async {
    final entities =
        await (_db.select(_db.salaryRecords)..where(
              (t) =>
                  t.userId.equals(_ownerId) &
                  t.status.isIn(['PENDING', 'PARTIAL']),
            ))
            .get();

    return entities.map((e) => SalaryModelX.fromEntity(e)).toList();
  }

  Future<void> markSalaryPaid({
    required String id,
    required double amount,
    required String paymentMode,
  }) async {
    final record = await (_db.select(
      _db.salaryRecords,
    )..where((t) => t.id.equals(id))).getSingle();

    final newPaid = record.paidAmount + amount;
    final status = newPaid >= record.netSalary ? 'PAID' : 'PARTIAL';

    await (_db.update(_db.salaryRecords)..where((t) => t.id.equals(id))).write(
      SalaryRecordsCompanion(
        paidAmount: Value(newPaid),
        status: Value(status),
        paymentMode: Value(paymentMode),
        paidAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'salary_records',
      recordId: id,
      action: 'PAY_SALARY',
      newValueJson: 'Paid: $amount, Mode: $paymentMode',
    );
  }

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}';
  }
} // End Class
