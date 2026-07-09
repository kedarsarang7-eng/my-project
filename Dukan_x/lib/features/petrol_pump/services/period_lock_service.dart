import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/audit_repository.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../accounting/services/locking_service.dart'; // Sync with Global Lock

/// PeriodLockService - Protects historical data (Gap #7)
///
/// Manages accounting periods by setting a "Lock Date".
/// Any transaction attempts before this date are blocked.
/// Used for finalizing monthly/yearly accounts.
///
/// Refactored for Offline-First using Drift (SQLite).
/// Reuses the existing LockingService / PeriodLocks Drift table pattern.
class PeriodLockService {
  late final AppDatabase _db;
  late final AuditRepository _auditRepo;
  late final SessionManager _sessionManager;

  PeriodLockService({
    AppDatabase? db,
    AuditRepository? auditRepo,
    SessionManager? sessionManager,
  }) {
    _db = db ?? sl<AppDatabase>();
    _auditRepo = auditRepo ?? sl<AuditRepository>();
    _sessionManager = sessionManager ?? sl<SessionManager>();
  }

  String get _ownerId => _sessionManager.ownerId ?? '';

  /// Get the current period lock date (if any)
  Future<DateTime?> getLockDate() async {
    try {
      final lock =
          await (_db.select(_db.periodLocks)..where(
                (t) =>
                    t.id.equals('petrol_pump_lock') & t.userId.equals(_ownerId),
              ))
              .getSingleOrNull();
      return lock?.lockDate;
    } catch (e) {
      return null;
    }
  }

  /// Check if a specific date is in a locked period
  /// Returns TRUE if operation should be BLOCKED
  Future<bool> isDateLocked(DateTime date) async {
    final lockDate = await getLockDate();
    if (lockDate == null) return false;

    // Check if date is strictly before the lock date (ignoring time for safety)
    final checkDate = DateTime(date.year, date.month, date.day);
    final periodLimit = DateTime(lockDate.year, lockDate.month, lockDate.day);

    return checkDate.isBefore(periodLimit) ||
        checkDate.isAtSameMomentAs(periodLimit);
  }

  /// Close accounting period (Lock all data up to newDate)
  /// Only Owner can perform this action.
  Future<void> closePeriod(DateTime newLockDate, String userId) async {
    // 1. Audit log before action
    final currentLock = await getLockDate();

    // 2. Set new lock date in Drift PeriodLocks table
    await _db
        .into(_db.periodLocks)
        .insert(
          PeriodLockEntity(
            id: 'petrol_pump_lock',
            userId: _ownerId,
            lockDate: newLockDate,
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );

    // Sync Queue: Period lock update
    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'settings',
      documentId: 'period_lock',
      payload: {
        'lockedUntil': newLockDate.toIso8601String(),
        'updatedBy': userId,
      },
    );

    // 3. Gap #7 FIX COMPLETE: Sync with Global Accounting Lock (Drift/SQL)
    // This ensures BillsRepository and other localized features also respect this lock.
    try {
      if (sl.isRegistered<LockingService>()) {
        final lockingService = sl<LockingService>();
        await lockingService.setLockDate(userId, newLockDate);
      }
    } catch (e) {
      // Log error but don't fail the primary lock
    }

    // 4. Audit log after action
    try {
      await _auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'settings',
        recordId: 'period_lock',
        action: 'PERIOD_LOCK_UPDATE',
        newValueJson:
            '{"previousLock": "${currentLock?.toIso8601String()}", "newLock": "${newLockDate.toIso8601String()}", "updatedBy": "$userId"}',
      );
    } catch (_) {}
  }

  // --- Helpers ---

  /// Enqueue a sync operation for offline-first sync
  Future<void> _enqueueSync({
    required SyncOperationType operationType,
    required String targetCollection,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final safeDocId = documentId.length >= 4
        ? documentId.substring(0, 4)
        : documentId;
    final opId = '${DateTime.now().microsecondsSinceEpoch}_$safeDocId';

    final syncItem = SyncQueueCompanion(
      operationId: Value(opId),
      operationType: Value(operationType.name),
      targetCollection: Value(targetCollection),
      documentId: Value(documentId),
      payload: Value(jsonEncode(payload)),
      status: const Value('PENDING'),
      createdAt: Value(DateTime.now()),
      retryCount: const Value(0),
      ownerId: Value(_ownerId),
      userId: Value(_ownerId),
      priority: const Value(1),
    );

    await _db.into(_db.syncQueue).insert(syncItem);
  }
}

/// Exception thrown when attempting to modify data in a locked period
class PeriodLockedException implements Exception {
  final DateTime lockedUntil;
  final DateTime attemptedDate;

  PeriodLockedException({
    required this.lockedUntil,
    required this.attemptedDate,
  });

  @override
  String toString() =>
      'PeriodLockedException: Accounting period is closed up to ${lockedUntil.toString().split(' ')[0]}. Cannot modify data for ${attemptedDate.toString().split(' ')[0]}.';
}
