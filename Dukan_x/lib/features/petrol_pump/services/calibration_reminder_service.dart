// ============================================================================
// CALIBRATION REMINDER SERVICE
// ============================================================================
// Tracks calibration due dates for petrol pump dispensers/nozzles
// and sends alerts when calibration is due (government compliance)
//
// Author: DukanX Engineering
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// Service to manage calibration reminders for petrol pump dispensers
class CalibrationReminderService {
  final AppDatabase _db;

  CalibrationReminderService(this._db);

  /// Get all dispensers with upcoming calibration
  /// [daysAhead] - Number of days to look ahead for due calibrations
  Future<List<DispenserEntity>> getDispensersWithUpcomingCalibration({
    required String ownerId,
    int daysAhead = 30,
  }) async {
    final cutoffDate = DateTime.now().add(Duration(days: daysAhead));

    final query = _db.select(_db.dispensers)
      ..where((d) => d.ownerId.equals(ownerId) & d.isActive.equals(true))
      ..where((d) => d.nextCalibrationDate.isSmallerOrEqualValue(cutoffDate));

    return query.get();
  }

  /// Get dispensers with overdue calibration
  Future<List<DispenserEntity>> getOverdueDispensers({
    required String ownerId,
  }) async {
    final now = DateTime.now();

    final query = _db.select(_db.dispensers)
      ..where((d) => d.ownerId.equals(ownerId) & d.isActive.equals(true))
      ..where((d) => d.nextCalibrationDate.isSmallerThanValue(now));

    return query.get();
  }

  /// Update calibration dates for a dispenser
  Future<void> updateCalibration({
    required String dispenserId,
    required DateTime calibrationDate,
    String? certificateNumber,
    int intervalDays = 180,
  }) async {
    final nextDue = calibrationDate.add(Duration(days: intervalDays));

    await (_db.update(
      _db.dispensers,
    )..where((d) => d.id.equals(dispenserId))).write(
      DispensersCompanion(
        lastCalibrationDate: Value(calibrationDate),
        nextCalibrationDate: Value(nextDue),
        calibrationIntervalDays: Value(intervalDays),
        calibrationCertificateNumber: Value(certificateNumber),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    debugPrint(
      'CalibrationReminderService: Updated calibration for dispenser $dispenserId, next due: $nextDue',
    );
  }

  /// Set initial calibration for a new dispenser
  Future<void> setInitialCalibration({
    required String dispenserId,
    required DateTime lastCalibrationDate,
    String? certificateNumber,
    int intervalDays = 180,
  }) async {
    await updateCalibration(
      dispenserId: dispenserId,
      calibrationDate: lastCalibrationDate,
      certificateNumber: certificateNumber,
      intervalDays: intervalDays,
    );
  }

  /// Get calibration status summary for dashboard
  Future<CalibrationSummary> getCalibrationSummary({
    required String ownerId,
  }) async {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    final allDispensers = await (_db.select(
      _db.dispensers,
    )..where((d) => d.ownerId.equals(ownerId) & d.isActive.equals(true))).get();

    int overdue = 0;
    int dueWithin7Days = 0;
    int dueWithin30Days = 0;
    int upToDate = 0;

    for (final dispenser in allDispensers) {
      final nextDue = dispenser.nextCalibrationDate;
      if (nextDue == null) {
        // No calibration set - treat as overdue
        overdue++;
      } else if (nextDue.isBefore(now)) {
        overdue++;
      } else if (nextDue.isBefore(sevenDaysFromNow)) {
        dueWithin7Days++;
      } else if (nextDue.isBefore(thirtyDaysFromNow)) {
        dueWithin30Days++;
      } else {
        upToDate++;
      }
    }

    return CalibrationSummary(
      totalDispensers: allDispensers.length,
      overdue: overdue,
      dueWithin7Days: dueWithin7Days,
      dueWithin30Days: dueWithin30Days,
      upToDate: upToDate,
    );
  }

  /// Watch dispensers with calibration alerts (real-time stream)
  Stream<List<DispenserEntity>> watchCalibrationAlerts({
    required String ownerId,
    int daysAhead = 30,
  }) {
    final cutoffDate = DateTime.now().add(Duration(days: daysAhead));

    return (_db.select(_db.dispensers)
          ..where((d) => d.ownerId.equals(ownerId) & d.isActive.equals(true))
          ..where(
            (d) => d.nextCalibrationDate.isSmallerOrEqualValue(cutoffDate),
          ))
        .watch();
  }
}

/// Summary of calibration status across all dispensers
class CalibrationSummary {
  final int totalDispensers;
  final int overdue;
  final int dueWithin7Days;
  final int dueWithin30Days;
  final int upToDate;

  CalibrationSummary({
    required this.totalDispensers,
    required this.overdue,
    required this.dueWithin7Days,
    required this.dueWithin30Days,
    required this.upToDate,
  });

  bool get hasAlerts => overdue > 0 || dueWithin7Days > 0;

  @override
  String toString() {
    return 'CalibrationSummary(total: $totalDispensers, overdue: $overdue, due7d: $dueWithin7Days, due30d: $dueWithin30Days, ok: $upToDate)';
  }
}
