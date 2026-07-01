// ============================================================================
// INVOICE NUMBER SERVICE
// ============================================================================
// Provides atomic, collision-free invoice number generation
//
// Design:
// - Uses database transaction for atomic increment
// - Financial year based reset (April-March for India)
// - Customizable prefix per vendor
// - Guaranteed unique within vendor + financial year
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Service for generating unique invoice numbers atomically
class InvoiceNumberService {
  final AppDatabase _db;

  InvoiceNumberService(this._db);

  /// Get the current Indian financial year (April-March)
  /// Returns format: "2025-26"
  String getCurrentFinancialYear() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Indian financial year: April to March
    if (month >= 4) {
      // We're in the financial year starting this calendar year
      return '$year-${(year + 1) % 100}';
    } else {
      // We're in the financial year that started last calendar year
      return '${year - 1}-${year % 100}';
    }
  }

  /// Generate the next invoice number atomically
  /// Returns format: "INV-2025-000001" or custom prefix like "BILL-2025-000001"
  ///
  /// This method is thread-safe and uses database transactions to ensure
  /// no two invoices get the same number even under concurrent access.
  Future<String> getNextInvoiceNumber({
    required String userId,
    String? prefix,
    String? financialYear,
  }) async {
    final fy = financialYear ?? getCurrentFinancialYear();
    final invoicePrefix = prefix ?? 'INV';

    // Use a transaction to ensure atomic read-modify-write
    final nextNumber = await _db.transaction<int>(() async {
      // Try to get existing counter
      final existingCounter =
          await (_db.select(_db.invoiceCounters)..where(
                (t) => t.userId.equals(userId) & t.financialYear.equals(fy),
              ))
              .getSingleOrNull();

      final now = DateTime.now();
      int newNumber;

      if (existingCounter != null) {
        // Increment existing counter
        newNumber = existingCounter.lastNumber + 1;

        await (_db.update(_db.invoiceCounters)..where(
              (t) => t.userId.equals(userId) & t.financialYear.equals(fy),
            ))
            .write(
              InvoiceCountersCompanion(
                lastNumber: Value(newNumber),
                prefix: Value(invoicePrefix),
                updatedAt: Value(now),
              ),
            );
      } else {
        // Create new counter starting at 1
        newNumber = 1;

        await _db
            .into(_db.invoiceCounters)
            .insert(
              InvoiceCountersCompanion.insert(
                userId: userId,
                financialYear: fy,
                prefix: Value(invoicePrefix),
                lastNumber: Value(newNumber),
                numberPadding: const Value(6),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      return newNumber;
    });

    // Format: PREFIX-FYYEAR-NNNNNN (e.g., INV-2025-000001)
    final fyYear = fy.split('-').first; // Get the starting year
    final paddedNumber = nextNumber.toString().padLeft(6, '0');

    return '$invoicePrefix-$fyYear-$paddedNumber';
  }

  /// Get the current counter value without incrementing
  /// Useful for previewing the next invoice number
  Future<int> getCurrentCounter({
    required String userId,
    String? financialYear,
  }) async {
    final fy = financialYear ?? getCurrentFinancialYear();

    final counter =
        await (_db.select(_db.invoiceCounters)..where(
              (t) => t.userId.equals(userId) & t.financialYear.equals(fy),
            ))
            .getSingleOrNull();

    return counter?.lastNumber ?? 0;
  }

  /// Peek at the next invoice number without consuming it
  /// Useful for showing preview in UI
  Future<String> peekNextInvoiceNumber({
    required String userId,
    String? prefix,
    String? financialYear,
  }) async {
    final fy = financialYear ?? getCurrentFinancialYear();
    final invoicePrefix = prefix ?? 'INV';
    final currentCounter = await getCurrentCounter(
      userId: userId,
      financialYear: fy,
    );

    final nextNumber = currentCounter + 1;
    final fyYear = fy.split('-').first;
    final paddedNumber = nextNumber.toString().padLeft(6, '0');

    return '$invoicePrefix-$fyYear-$paddedNumber';
  }

  /// Reset counter for a specific financial year (use with caution!)
  /// This should only be used for administrative purposes
  Future<void> resetCounter({
    required String userId,
    required String financialYear,
    int startFrom = 0,
  }) async {
    final now = DateTime.now();

    await (_db.update(_db.invoiceCounters)..where(
          (t) =>
              t.userId.equals(userId) & t.financialYear.equals(financialYear),
        ))
        .write(
          InvoiceCountersCompanion(
            lastNumber: Value(startFrom),
            updatedAt: Value(now),
          ),
        );
  }

  /// Get all counters for a user (for admin/settings view)
  Future<List<InvoiceCounterEntity>> getAllCounters(String userId) async {
    return (_db.select(_db.invoiceCounters)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.financialYear)]))
        .get();
  }
}
