import 'package:drift/drift.dart';
import 'dart:convert';
import '../../../core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class LockingService {
  final AppDatabase _db;

  LockingService(this._db);

  /// Get the current lock date for a user
  Future<DateTime?> getLockDate(String userId) async {
    final lock =
        await (_db.select(_db.periodLocks)..where(
              (t) => t.id.equals('global_lock') & t.userId.equals(userId),
            ))
            .getSingleOrNull();
    return lock?.lockDate;
  }

  /// Set or update the lock date
  Future<void> setLockDate(String userId, DateTime date) async {
    await _db
        .into(_db.periodLocks)
        .insert(
          PeriodLockEntity(
            id: 'global_lock',
            userId: userId,
            lockDate: date,
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Check if a specific date is locked
  Future<bool> isDateLocked(String userId, DateTime date) async {
    final lockDate = await getLockDate(userId);
    if (lockDate == null) return false;

    // Normalize dates to remove time component for comparison if needed,
    // but typically lockDate implies "everything up to end of this day".
    // Let's assume strict comparison: if transaction date <= lockDate, it's locked.
    // Usually lock date is "locked UP TO this date".

    return date.isBefore(lockDate) || date.isAtSameMomentAs(lockDate);
  }

  /// Validate action and throw exception if locked, unless an override is provided.
  Future<void> validateAction(
    String userId,
    DateTime date, {
    LockOverrideContext? overrideContext,
  }) async {
    if (await isDateLocked(userId, date)) {
      if (overrideContext != null) {
        // Valid override provided, log it and proceed
        await logOverride(
          userId: userId,
          entityType: overrideContext.entityType,
          entityId: overrideContext.entityId,
          reason: overrideContext.reason,
          originalValues: overrideContext.originalValues,
          modifiedValues: overrideContext.modifiedValues,
          approvedBy: overrideContext.approvedByUserId,
        );
        return;
      }
      throw PeriodLockedException(
        "This period is locked. Cannot add/edit entries.",
      );
    }
  }

  /// Log an override action for audit trail
  Future<void> logOverride({
    required String userId,
    required String entityType,
    required String entityId,
    required String reason,
    required Map<String, dynamic> originalValues,
    required Map<String, dynamic> modifiedValues,
    required String approvedBy,
  }) async {
    await _db
        .into(_db.lockOverrideLogs)
        .insert(
          LockOverrideLogEntity(
            id: const Uuid().v4(),
            userId: userId,
            entityType: entityType,
            entityId: entityId,
            reason: reason,
            originalValuesJson: jsonEncode(originalValues),
            modifiedValuesJson: jsonEncode(modifiedValues),
            approvedByUserId: approvedBy,
            approvedAt: DateTime.now(),
            isSynced: false,
          ),
        );
  }
}

class PeriodLockedException implements Exception {
  final String message;
  PeriodLockedException(this.message);
  @override
  String toString() => message;
}

/// Context for overriding a lock
class LockOverrideContext {
  final String entityType;
  final String entityId;
  final String reason;
  final Map<String, dynamic> originalValues;
  final Map<String, dynamic> modifiedValues;
  final String approvedByUserId;

  LockOverrideContext({
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.originalValues,
    required this.modifiedValues,
    required this.approvedByUserId,
  });
}
