// ============================================================================
// PERIOD LOCK SERVICE
// ============================================================================
// Centralized accounting period lock enforcement.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';

import '../../models/accounting_period.dart';
import '../repository/audit_repository.dart';
import '../security/services/owner_pin_service.dart';

/// Period Lock Service - Centralized period lock enforcement.
///
/// Features:
/// - Check if date falls in locked period
/// - Lock/unlock periods with PIN verification
/// - Audit trail for all lock operations
class PeriodLockService {
  final FirebaseFirestore _firestore;
  final OwnerPinService _pinService;
  final AuditRepository _auditRepository;

  /// Cache of period locks by businessId
  final Map<String, List<AccountingPeriod>> _lockCache = {};

  PeriodLockService({
    FirebaseFirestore? firestore,
    required OwnerPinService pinService,
    required AuditRepository auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _pinService = pinService,
       _auditRepository = auditRepository;

  /// Check if a date falls within a locked period
  Future<bool> isDateLocked({
    required String businessId,
    required DateTime date,
  }) async {
    final periods = await _getPeriodsForBusiness(businessId);

    for (final period in periods) {
      if (period.isLocked && period.containsDate(date)) {
        return true;
      }
    }

    return false;
  }

  /// Get lock status with details
  Future<PeriodLockStatus> getLockStatus({
    required String businessId,
    required DateTime date,
  }) async {
    final periods = await _getPeriodsForBusiness(businessId);

    for (final period in periods) {
      if (period.containsDate(date)) {
        return PeriodLockStatus(
          isLocked: period.isLocked,
          period: period,
          reason: period.lockReason,
        );
      }
    }

    return PeriodLockStatus(isLocked: false);
  }

  /// Lock a period (requires PIN)
  Future<void> lockPeriod({
    required String businessId,
    required String periodId,
    required String lockedBy,
    required String pin,
    String? reason,
  }) async {
    // Verify PIN
    final isValid = await _pinService.verifyPin(
      businessId: businessId,
      pin: pin,
    );

    if (!isValid) {
      throw PeriodLockException('Invalid PIN');
    }

    final now = DateTime.now();

    await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('accounting_periods')
        .doc(periodId)
        .update({
          'isLocked': true,
          'lockedAt': Timestamp.fromDate(now),
          'lockedBy': lockedBy,
          'lockReason': reason ?? 'Manual lock',
        });

    // Clear cache
    _lockCache.remove(businessId);

    // Audit log
    await _auditRepository.logAction(
      userId: lockedBy,
      targetTableName: 'accounting_periods',
      recordId: periodId,
      action: 'LOCK',
      newValueJson: '{"isLocked": true, "reason": "$reason"}',
    );

    debugPrint('PeriodLockService: Locked period $periodId');
  }

  /// Unlock a period (requires PIN, owner only)
  Future<void> unlockPeriod({
    required String businessId,
    required String periodId,
    required String unlockedBy,
    required String pin,
    required String reason,
  }) async {
    // Verify PIN
    final isValid = await _pinService.verifyPin(
      businessId: businessId,
      pin: pin,
    );

    if (!isValid) {
      throw PeriodLockException('Invalid PIN');
    }

    await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('accounting_periods')
        .doc(periodId)
        .update({
          'isLocked': false,
          'unlockedAt': Timestamp.fromDate(DateTime.now()),
          'unlockedBy': unlockedBy,
          'unlockReason': reason,
        });

    // Clear cache
    _lockCache.remove(businessId);

    // Audit log
    await _auditRepository.logAction(
      userId: unlockedBy,
      targetTableName: 'accounting_periods',
      recordId: periodId,
      action: 'UNLOCK',
      newValueJson: '{"isLocked": false, "reason": "$reason"}',
    );

    debugPrint('PeriodLockService: Unlocked period $periodId');
  }

  /// Auto-lock previous month (called by scheduler)
  Future<void> autoLockPreviousMonth({
    required String businessId,
    required String systemUserId,
  }) async {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0);

    // Check if period exists
    final query = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('accounting_periods')
        .where(
          'startDate',
          isLessThanOrEqualTo: Timestamp.fromDate(previousMonth),
        )
        .where(
          'endDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(previousMonthEnd),
        )
        .where('isLocked', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      debugPrint(
        'PeriodLockService: No unlocked period found for previous month',
      );
      return;
    }

    final periodDoc = query.docs.first;

    await periodDoc.reference.update({
      'isLocked': true,
      'lockedAt': Timestamp.fromDate(now),
      'lockedBy': systemUserId,
      'lockReason': 'Auto-locked by system',
    });

    // Clear cache
    _lockCache.remove(businessId);

    // Audit log
    await _auditRepository.logAction(
      userId: systemUserId,
      targetTableName: 'accounting_periods',
      recordId: periodDoc.id,
      action: 'AUTO_LOCK',
      newValueJson: '{"isLocked": true, "reason": "Auto-locked by system"}',
    );

    debugPrint('PeriodLockService: Auto-locked period ${periodDoc.id}');
  }

  /// Get periods for a business (cached)
  Future<List<AccountingPeriod>> _getPeriodsForBusiness(
    String businessId,
  ) async {
    if (_lockCache.containsKey(businessId)) {
      return _lockCache[businessId]!;
    }

    try {
      final query = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('accounting_periods')
          .orderBy('startDate', descending: true)
          .limit(24) // Last 2 years of months
          .get();

      final periods = query.docs.map((doc) {
        final data = doc.data();
        return AccountingPeriod(
          id: doc.id,
          businessId: businessId,
          name: data['name'] ?? '',
          type: PeriodType.values.firstWhere(
            (t) => t.name == data['type'],
            orElse: () => PeriodType.monthly,
          ),
          startDate: (data['startDate'] as Timestamp).toDate(),
          endDate: (data['endDate'] as Timestamp).toDate(),
          isLocked: data['isLocked'] ?? false,
          lockedAt: data['lockedAt'] != null
              ? (data['lockedAt'] as Timestamp).toDate()
              : null,
          lockedBy: data['lockedBy'],
          lockReason: data['lockReason'],
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();

      _lockCache[businessId] = periods;
      return periods;
    } catch (e) {
      debugPrint('PeriodLockService: Error fetching periods: $e');
      return [];
    }
  }

  /// Clear cache
  void clearCache() {
    _lockCache.clear();
  }
}

/// Period lock status result
class PeriodLockStatus {
  final bool isLocked;
  final AccountingPeriod? period;
  final String? reason;

  PeriodLockStatus({required this.isLocked, this.period, this.reason});
}

/// Exception for period lock operations
class PeriodLockException implements Exception {
  final String message;
  PeriodLockException(this.message);

  @override
  String toString() => 'PeriodLockException: $message';
}
