// ============================================================================
// RECONCILIATION SERVICE - DISCREPANCY DETECTION
// ============================================================================
// Detects mismatches between ledger summaries and transaction totals
// for audit verification and data integrity checks.
//
// Author: DukanX Engineering
// Created: 2026-01-23
// ============================================================================

import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Represents a detected discrepancy between expected and actual values
class Discrepancy {
  final String type; // CUSTOMER_LEDGER, STOCK, TRIAL_BALANCE
  final String entityId;
  final String entityName;
  final double expectedValue;
  final double actualValue;
  final double variance;
  final String details;

  Discrepancy({
    required this.type,
    required this.entityId,
    required this.entityName,
    required this.expectedValue,
    required this.actualValue,
    required this.details,
  }) : variance = (expectedValue - actualValue).abs();

  bool get hasDiscrepancy => variance > 0.01; // Allow 1 paisa tolerance

  Map<String, dynamic> toMap() => {
    'type': type,
    'entityId': entityId,
    'entityName': entityName,
    'expectedValue': expectedValue,
    'actualValue': actualValue,
    'variance': variance,
    'details': details,
  };
}

/// Reconciliation summary for dashboard display
class ReconciliationReport {
  final DateTime generatedAt;
  final List<Discrepancy> customerLedgerIssues;
  final List<Discrepancy> stockIssues;
  final Discrepancy? trialBalanceVariance;
  final int totalIssues;

  ReconciliationReport({
    required this.generatedAt,
    required this.customerLedgerIssues,
    required this.stockIssues,
    this.trialBalanceVariance,
  }) : totalIssues =
           customerLedgerIssues.length +
           stockIssues.length +
           (trialBalanceVariance?.hasDiscrepancy == true ? 1 : 0);

  bool get hasIssues => totalIssues > 0;
}

/// Reconciliation Service - Detects discrepancies in accounting data
///
/// Provides methods to verify:
/// 1. Customer ledger balance vs sum of unpaid bills
/// 2. Stock quantity vs sum of stock movements
/// 3. Trial balance (Total DR = Total CR)
class ReconciliationService {
  final AppDatabase db;

  ReconciliationService({required this.db});

  /// Run full reconciliation check and return report
  Future<ReconciliationReport> runFullReconciliation(String userId) async {
    final customerIssues = await checkCustomerLedgerDiscrepancies(userId);
    final stockIssues = await checkStockDiscrepancies(userId);
    final trialBalance = await checkTrialBalanceVariance(userId);

    return ReconciliationReport(
      generatedAt: DateTime.now(),
      customerLedgerIssues: customerIssues,
      stockIssues: stockIssues,
      trialBalanceVariance: trialBalance,
    );
  }

  /// Check if customer.totalDues matches sum of unpaid bill amounts
  ///
  /// Formula: totalDues should equal SUM(grandTotal - paidAmount) for all bills
  Future<List<Discrepancy>> checkCustomerLedgerDiscrepancies(
    String userId,
  ) async {
    final discrepancies = <Discrepancy>[];

    // Get all customers
    final customers = await (db.select(
      db.customers,
    )..where((c) => c.userId.equals(userId))).get();

    for (final customer in customers) {
      // Get sum of unpaid amounts from bills
      final bills =
          await (db.select(db.bills)..where(
                (b) =>
                    b.userId.equals(userId) &
                    b.customerId.equals(customer.id) &
                    b.deletedAt.isNull(),
              ))
              .get();

      double sumUnpaid = 0;
      for (final bill in bills) {
        sumUnpaid += (bill.grandTotal - bill.paidAmount);
      }

      // Compare with customer.totalDues
      final variance = (customer.totalDues - sumUnpaid).abs();
      if (variance > 0.01) {
        discrepancies.add(
          Discrepancy(
            type: 'CUSTOMER_LEDGER',
            entityId: customer.id,
            entityName: customer.name,
            expectedValue: sumUnpaid,
            actualValue: customer.totalDues,
            details:
                'Customer ledger shows ?${customer.totalDues.toStringAsFixed(2)} dues, '
                'but sum of unpaid bills is ?${sumUnpaid.toStringAsFixed(2)}',
          ),
        );
      }
    }

    return discrepancies;
  }

  /// Check if product.stockQuantity matches sum of stock movements
  ///
  /// Formula: stockQuantity should equal SUM(IN movements) - SUM(OUT movements)
  Future<List<Discrepancy>> checkStockDiscrepancies(String userId) async {
    final discrepancies = <Discrepancy>[];

    // Get all products
    final products = await (db.select(
      db.products,
    )..where((p) => p.userId.equals(userId))).get();

    for (final product in products) {
      // Get sum of stock movements
      final movements = await (db.select(
        db.stockMovements,
      )..where((m) => m.productId.equals(product.id))).get();

      double netMovement = 0;
      for (final m in movements) {
        if (m.type == 'IN') {
          netMovement += m.quantity;
        } else if (m.type == 'OUT') {
          netMovement -= m.quantity;
        }
      }

      // Compare with product.stockQuantity
      final variance = (product.stockQuantity - netMovement).abs();
      if (variance > 0.01) {
        discrepancies.add(
          Discrepancy(
            type: 'STOCK',
            entityId: product.id,
            entityName: product.name,
            expectedValue: netMovement,
            actualValue: product.stockQuantity,
            details:
                'Product stock shows ${product.stockQuantity.toStringAsFixed(2)}, '
                'but net movements total ${netMovement.toStringAsFixed(2)}',
          ),
        );
      }
    }

    return discrepancies;
  }

  /// Check if Total Debits = Total Credits in journal entries
  ///
  /// If they don't match, there's a fundamental accounting error
  Future<Discrepancy?> checkTrialBalanceVariance(String userId) async {
    // Get all journal entries
    final entries = await (db.select(
      db.journalEntries,
    )..where((j) => j.userId.equals(userId))).get();

    double totalDebits = 0;
    double totalCredits = 0;

    for (final entry in entries) {
      totalDebits += entry.totalDebit;
      totalCredits += entry.totalCredit;
    }

    final variance = (totalDebits - totalCredits).abs();
    if (variance > 0.01) {
      return Discrepancy(
        type: 'TRIAL_BALANCE',
        entityId: userId,
        entityName: 'Trial Balance',
        expectedValue: totalDebits,
        actualValue: totalCredits,
        details:
            'Total Debits (?${totalDebits.toStringAsFixed(2)}) does not equal '
            'Total Credits (?${totalCredits.toStringAsFixed(2)}). '
            'Variance: ?${variance.toStringAsFixed(2)}',
      );
    }

    return null; // No variance = healthy
  }

  /// Quick health check - returns true if all reconciliations pass
  Future<bool> isDataHealthy(String userId) async {
    final report = await runFullReconciliation(userId);
    return !report.hasIssues;
  }

  /// Get summary counts for dashboard widget
  Future<Map<String, int>> getDiscrepancySummary(String userId) async {
    final report = await runFullReconciliation(userId);
    return {
      'customerLedgerIssues': report.customerLedgerIssues.length,
      'stockIssues': report.stockIssues.length,
      'trialBalanceOk': report.trialBalanceVariance == null ? 1 : 0,
      'totalIssues': report.totalIssues,
    };
  }
}
