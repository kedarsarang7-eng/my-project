// ============================================================================
// CASH CLOSING VALIDATION SERVICE
// ============================================================================
// Validates daily cash closing before allowing next-day billing.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';

import '../database/app_database.dart';

/// Cash Closing Validation Result
class CashClosingValidation {
  final bool isValid;
  final bool closingRequired;
  final DateTime? lastClosingDate;
  final String? message;

  const CashClosingValidation._({
    required this.isValid,
    this.closingRequired = false,
    this.lastClosingDate,
    this.message,
  });

  factory CashClosingValidation.valid() {
    return const CashClosingValidation._(isValid: true);
  }

  factory CashClosingValidation.closingRequired(DateTime lastDate) {
    return CashClosingValidation._(
      isValid: false,
      closingRequired: true,
      lastClosingDate: lastDate,
      message:
          'Please complete cash closing for ${lastDate.day}/${lastDate.month}/${lastDate.year} before creating bills.',
    );
  }

  factory CashClosingValidation.error(String message) {
    return CashClosingValidation._(isValid: false, message: message);
  }
}

/// Cash Closing Validation Service - Enforces cash closing before billing.
///
/// Business logic:
/// - Bills can only be created if previous day(s) have cash closing
/// - Configurable grace period (default: 0 days)
/// - Owner can override with PIN
class CashClosingValidationService {
  final AppDatabase _database;
  final FirebaseFirestore _firestore;

  /// Days of grace before requiring cash closing (0 = same day required)
  final int graceDays;

  CashClosingValidationService({
    required AppDatabase database,
    FirebaseFirestore? firestore,
    this.graceDays = 1,
  }) : _database = database,
       _firestore = firestore ?? FirebaseFirestore.instance;

  /// Validate if billing is allowed based on cash closing status
  Future<CashClosingValidation> validateForBilling({
    required String businessId,
    required DateTime billDate,
  }) async {
    try {
      // Get the cutoff date that needs to be closed
      final today = DateTime.now();
      final cutoffDate = today.subtract(Duration(days: graceDays));

      // If bill date is before cutoff, always allow (historical bill)
      if (billDate.isBefore(cutoffDate)) {
        return CashClosingValidation.valid();
      }

      // Check if previous day's closing is done
      final previousDay = DateTime(today.year, today.month, today.day - 1);

      // Query local database for closing
      final localClosing =
          await (_database.select(_database.cashClosings)
                ..where((t) => t.businessId.equals(businessId))
                ..where((t) => t.closingDate.isBiggerOrEqualValue(previousDay))
                ..where((t) => t.closingDate.isSmallerThanValue(today))
                ..limit(1))
              .getSingleOrNull();

      if (localClosing != null &&
          (localClosing.status == 'MATCHED' ||
              localClosing.status == 'MISMATCH_APPROVED')) {
        return CashClosingValidation.valid();
      }

      // Check Firestore as backup
      try {
        final firestoreClosing = await _firestore
            .collection('cash_closings')
            .where('businessId', isEqualTo: businessId)
            .where(
              'closingDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(previousDay),
            )
            .where('closingDate', isLessThan: Timestamp.fromDate(today))
            .limit(1)
            .get();

        if (firestoreClosing.docs.isNotEmpty) {
          final data = firestoreClosing.docs.first.data();
          if (data['status'] == 'MATCHED' ||
              data['status'] == 'MISMATCH_APPROVED') {
            return CashClosingValidation.valid();
          }
        }
      } catch (e) {
        debugPrint('CashClosingValidationService: Firestore check failed: $e');
        // Continue with validation - network failures shouldn't block billing
      }

      // No valid closing found
      return CashClosingValidation.closingRequired(previousDay);
    } catch (e) {
      debugPrint('CashClosingValidationService: Validation failed: $e');
      // On error, allow billing to not block business operations
      return CashClosingValidation.valid();
    }
  }

  /// Get pending closing dates that need attention
  Future<List<DateTime>> getPendingClosingDates({
    required String businessId,
    int lookbackDays = 7,
  }) async {
    final pendingDates = <DateTime>[];
    final today = DateTime.now();

    for (int i = 1; i <= lookbackDays; i++) {
      final checkDate = DateTime(today.year, today.month, today.day - i);
      final nextDay = checkDate.add(const Duration(days: 1));

      final closing =
          await (_database.select(_database.cashClosings)
                ..where((t) => t.businessId.equals(businessId))
                ..where((t) => t.closingDate.isBiggerOrEqualValue(checkDate))
                ..where((t) => t.closingDate.isSmallerThanValue(nextDay))
                ..limit(1))
              .getSingleOrNull();

      if (closing == null ||
          (closing.status != 'MATCHED' &&
              closing.status != 'MISMATCH_APPROVED')) {
        pendingDates.add(checkDate);
      }
    }

    return pendingDates;
  }
}
