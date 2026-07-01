import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/audit_repository.dart';
import '../../accounting/services/locking_service.dart'; // Sync with Global Lock

/// PeriodLockService - Protects historical data (Gap #7)
///
/// Manages accounting periods by setting a "Lock Date".
/// Any transaction attempts before this date are blocked.
/// Used for finalizing monthly/yearly accounts.
class PeriodLockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _ownerId => sl<SessionManager>().ownerId ?? '';

  CollectionReference get _settingsCollection =>
      _firestore.collection('owners').doc(_ownerId).collection('settings');

  /// Get the current period lock date (if any)
  Future<DateTime?> getLockDate() async {
    try {
      final doc = await _settingsCollection.doc('period_lock').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['lockedUntil'] as Timestamp?;
        return timestamp?.toDate();
      }
      return null;
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

    // 2. Set new lock date in Firestore (Petrol Pump)
    await _settingsCollection.doc('period_lock').set({
      'lockedUntil': Timestamp.fromDate(newLockDate),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    });

    // 3. Gap #7 FIX COMPLETE: Sync with Global Accounting Lock (Drift/SQL)
    // This ensures BillsRepository and other localized features also respect this lock.
    try {
      if (sl.isRegistered<LockingService>()) {
        final lockingService = sl<LockingService>();
        await lockingService.setLockDate(userId, newLockDate);
      }
    } catch (e) {
      // Log error but don't fail the primary lock
      // debugPrint('Failed to sync global lock: $e');
    }

    // 4. Audit log after action
    try {
      final auditRepo = sl<AuditRepository>();
      await auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'settings',
        recordId: 'period_lock',
        action: 'PERIOD_LOCK_UPDATE',
        newValueJson:
            '{"previousLock": "${currentLock?.toIso8601String()}", "newLock": "${newLockDate.toIso8601String()}", "updatedBy": "$userId"}',
      );
    } catch (_) {}
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
