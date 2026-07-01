import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class DataIntegrityService {
  final AppDatabase database;

  DataIntegrityService({required this.database});

  /// Verify Stock Integrity
  /// Compares Product.stockQuantity (Snapshot) with Sum of StockMovements (History)
  /// Returns a report of discrepancies.
  Future<Map<String, dynamic>> verifyStockIntegrity(String userId) async {
    final discrepancies = <Map<String, dynamic>>[];
    int checkedCount = 0;

    // 1. Get all active products
    final products = await (database.select(
      database.products,
    )..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())).get();

    for (final product in products) {
      checkedCount++;

      // 2. Sum movements (IN - OUT)
      final movements = await (database.select(
        database.stockMovements,
      )..where((t) => t.productId.equals(product.id))).get();

      double calculatedStock = 0.0;
      for (final m in movements) {
        if (m.type == 'IN') {
          calculatedStock += m.quantity;
        } else if (m.type == 'OUT') {
          calculatedStock -= m.quantity;
        }
      }

      // 3. Compare with tolerance for floating point
      if ((product.stockQuantity - calculatedStock).abs() > 0.001) {
        discrepancies.add({
          'productId': product.id,
          'productName': product.name,
          'currentStock': product.stockQuantity,
          'calculatedStock': calculatedStock,
          'difference': product.stockQuantity - calculatedStock,
          'movementsCount': movements.length,
        });
      }
    }

    return {
      'status': discrepancies.isEmpty ? 'HEALTHY' : 'CORRUPTED',
      'checkedCount': checkedCount,
      'discrepancies': discrepancies,
    };
  }

  /// Verify Customer Ledger Integrity
  /// Compares Customer.totalDues with Sum of Unpaid/Partial Bills
  Future<Map<String, dynamic>> verifyCustomerLedgerIntegrity(
    String userId,
  ) async {
    final discrepancies = <Map<String, dynamic>>[];
    int checkedCount = 0;

    // 1. Get all customers
    final customers = await (database.select(
      database.customers,
    )..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())).get();

    for (final customer in customers) {
      checkedCount++;

      // 2. Sum pending bills
      final bills =
          await (database.select(database.bills)..where(
                (t) =>
                    t.customerId.equals(customer.id) &
                    t.userId.equals(userId) &
                    t.deletedAt.isNull(),
              ))
              .get();

      double calculatedDues = 0.0;

      for (final bill in bills) {
        // Bill Dues = GrandTotal - PaidAmount
        double due = bill.grandTotal - bill.paidAmount;
        if (due < 0) due = 0; // Should not happen but safety
        calculatedDues += due;
      }

      // 3. Compare
      if ((customer.totalDues - calculatedDues).abs() > 0.1) {
        // 10 paisa tolerance
        discrepancies.add({
          'customerId': customer.id,
          'customerName': customer.name,
          'ledgerDues': customer.totalDues,
          'calculatedDues': calculatedDues,
          'difference': customer.totalDues - calculatedDues,
        });
      }
    }

    return {
      'status': discrepancies.isEmpty ? 'HEALTHY' : 'CORRUPTED',
      'checkedCount': checkedCount,
      'discrepancies': discrepancies,
    };
  }

  /// Auto-Fix Stock Integrity
  /// Creates 'AUDIT_CORRECTION' stock movements to bridge the gap between History and Snapshot
  /// This assumes the Snapshot (what user sees) is "Correct" and History is missing data.
  Future<int> fixStockIntegrity(String userId) async {
    final report = await verifyStockIntegrity(userId);
    if (report['status'] == 'HEALTHY') return 0;

    int fixedCount = 0;
    final discrepancies = report['discrepancies'] as List;

    await database.transaction(() async {
      final now = DateTime.now();

      for (final item in discrepancies) {
        final productId = item['productId'] as String;
        final currentStock = item['currentStock'] as double;
        final calculatedStock = item['calculatedStock'] as double;
        final diff = currentStock - calculatedStock;

        // If diff > 0, Snapshot is higher. Need to Add Stock (IN)
        // If diff < 0, Snapshot is lower. Need to Remove Stock (OUT)

        final type = diff > 0 ? 'IN' : 'OUT';
        final quantity = diff.abs();

        final movementId = const Uuid().v4();

        // Create Correction Movement
        await database
            .into(database.stockMovements)
            .insert(
              StockMovementEntity(
                id: movementId,
                userId: userId,
                productId: productId,
                type: type,
                reason: 'AUDIT_CORRECTION',
                quantity: quantity,
                stockBefore: calculatedStock,
                stockAfter: currentStock, // Matches snapshot
                referenceId: 'AUDIT_${now.millisecondsSinceEpoch}',
                description: 'System Auto-Correction for Missing History',
                date: now,
                createdAt: now,
                createdBy: 'SYSTEM_AUDIT',
                isSynced: false,
              ),
            );

        fixedCount++;
      }
    });

    return fixedCount;
  }

  // ============================================================
  // SAFETY PATCH: Enhanced Customer Ledger Reconciliation
  // ============================================================
  // Compares cached totalDues with actual calculated value from bills
  // Auto-recalculates and logs before/after snapshot
  // ============================================================

  /// Reconcile customer balance by comparing cached totalDues with calculated
  /// Returns reconciliation report with any corrections made
  Future<IntegrityReconciliationResult> reconcileCustomerBalance(
    String userId,
  ) async {
    final corrections = <CustomerCorrectionSnapshot>[];
    int checkedCount = 0;

    // 1. Get all customers
    final customers = await (database.select(
      database.customers,
    )..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())).get();

    await database.transaction(() async {
      for (final customer in customers) {
        checkedCount++;

        // 2. Calculate actual dues from bills
        final bills =
            await (database.select(database.bills)..where(
                  (t) =>
                      t.customerId.equals(customer.id) &
                      t.userId.equals(userId) &
                      t.deletedAt.isNull(),
                ))
                .get();

        double calculatedDues = 0.0;
        double calculatedBilled = 0.0;

        for (final bill in bills) {
          calculatedBilled += bill.grandTotal;
          double due = bill.grandTotal - bill.paidAmount;
          if (due < 0) due = 0;
          calculatedDues += due;
        }

        // 3. Check for mismatch (10 paisa tolerance)
        final duesMismatch = (customer.totalDues - calculatedDues).abs() > 0.1;
        final billedMismatch =
            (customer.totalBilled - calculatedBilled).abs() > 0.1;

        if (duesMismatch || billedMismatch) {
          // 4. Log snapshot before correction
          corrections.add(
            CustomerCorrectionSnapshot(
              customerId: customer.id,
              customerName: customer.name,
              beforeTotalDues: customer.totalDues,
              afterTotalDues: calculatedDues,
              beforeTotalBilled: customer.totalBilled,
              afterTotalBilled: calculatedBilled,
              correctedAt: DateTime.now(),
            ),
          );

          // 5. Apply correction
          await (database.update(
            database.customers,
          )..where((t) => t.id.equals(customer.id))).write(
            CustomersCompanion(
              totalDues: Value(calculatedDues),
              totalBilled: Value(calculatedBilled),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    });

    return IntegrityReconciliationResult(
      status: corrections.isEmpty ? 'HEALTHY' : 'CORRECTED',
      checkedCount: checkedCount,
      correctionCount: corrections.length,
      corrections: corrections,
      timestamp: DateTime.now(),
    );
  }

  // ============================================================
  // SAFETY PATCH: Enhanced Stock Integrity with Alerting
  // ============================================================
  // - Silent auto-fix for minor mismatches (< 1 unit)
  // - Alert logging for large mismatches (> 5 units)
  // - Structured result with severity levels
  // ============================================================

  /// Verify and auto-fix stock integrity with smart thresholds
  /// Minor mismatches (<1 unit): Silent auto-fix
  /// Large mismatches (>5 units): Alert + log
  Future<StockIntegrityResult> verifyAndAutoFixStockIntegrity(
    String userId, {
    double minorThreshold = 1.0,
    double alertThreshold = 5.0,
  }) async {
    final report = await verifyStockIntegrity(userId);
    if (report['status'] == 'HEALTHY') {
      return StockIntegrityResult(
        status: 'HEALTHY',
        checkedCount: report['checkedCount'] as int,
        minorFixCount: 0,
        majorAlertCount: 0,
        fixes: [],
        alerts: [],
        timestamp: DateTime.now(),
      );
    }

    final discrepancies = report['discrepancies'] as List;
    final fixes = <StockCorrectionRecord>[];
    final alerts = <StockAlertRecord>[];

    await database.transaction(() async {
      final now = DateTime.now();

      for (final item in discrepancies) {
        final productId = item['productId'] as String;
        final productName = item['productName'] as String;
        final currentStock = item['currentStock'] as double;
        final calculatedStock = item['calculatedStock'] as double;
        final diff = (currentStock - calculatedStock).abs();

        final type = currentStock > calculatedStock ? 'IN' : 'OUT';
        final quantity = diff;

        // Determine severity
        final severity = diff <= minorThreshold
            ? StockMismatchSeverity.minor
            : (diff > alertThreshold
                  ? StockMismatchSeverity.major
                  : StockMismatchSeverity.moderate);

        // Create correction record
        final correctionRecord = StockCorrectionRecord(
          productId: productId,
          productName: productName,
          snapshotStock: currentStock,
          calculatedStock: calculatedStock,
          difference: currentStock - calculatedStock,
          severity: severity,
          correctedAt: now,
        );

        if (severity == StockMismatchSeverity.major) {
          // Log alert for large mismatches (do NOT auto-fix)
          alerts.add(
            StockAlertRecord(
              productId: productId,
              productName: productName,
              snapshotStock: currentStock,
              calculatedStock: calculatedStock,
              difference: currentStock - calculatedStock,
              alertedAt: now,
              message:
                  'LARGE STOCK DISCREPANCY: $productName has ${diff.toStringAsFixed(2)} unit mismatch. Manual review required.',
            ),
          );
        } else {
          // Auto-fix minor/moderate mismatches
          final movementId = const Uuid().v4();

          await database
              .into(database.stockMovements)
              .insert(
                StockMovementEntity(
                  id: movementId,
                  userId: userId,
                  productId: productId,
                  type: type,
                  reason: severity == StockMismatchSeverity.minor
                      ? 'AUTO_CORRECTION_MINOR'
                      : 'AUTO_CORRECTION_MODERATE',
                  quantity: quantity,
                  stockBefore: calculatedStock,
                  stockAfter: currentStock,
                  referenceId: 'INTEGRITY_${now.millisecondsSinceEpoch}',
                  description:
                      'Auto-correction for ${severity.name} stock discrepancy',
                  date: now,
                  createdAt: now,
                  createdBy: 'SYSTEM_INTEGRITY',
                  isSynced: false,
                ),
              );

          fixes.add(correctionRecord);
        }
      }
    });

    return StockIntegrityResult(
      status: alerts.isNotEmpty ? 'ALERTS_PENDING' : 'CORRECTED',
      checkedCount: report['checkedCount'] as int,
      minorFixCount: fixes
          .where((f) => f.severity == StockMismatchSeverity.minor)
          .length,
      majorAlertCount: alerts.length,
      fixes: fixes,
      alerts: alerts,
      timestamp: DateTime.now(),
    );
  }
}

// ============================================================
// RESULT CLASSES FOR STRUCTURED REPORTING
// ============================================================

/// Result of customer ledger reconciliation
class IntegrityReconciliationResult {
  final String status; // HEALTHY, CORRECTED
  final int checkedCount;
  final int correctionCount;
  final List<CustomerCorrectionSnapshot> corrections;
  final DateTime timestamp;

  IntegrityReconciliationResult({
    required this.status,
    required this.checkedCount,
    required this.correctionCount,
    required this.corrections,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'status': status,
    'checkedCount': checkedCount,
    'correctionCount': correctionCount,
    'corrections': corrections.map((c) => c.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Snapshot of customer correction for audit
class CustomerCorrectionSnapshot {
  final String customerId;
  final String customerName;
  final double beforeTotalDues;
  final double afterTotalDues;
  final double beforeTotalBilled;
  final double afterTotalBilled;
  final DateTime correctedAt;

  CustomerCorrectionSnapshot({
    required this.customerId,
    required this.customerName,
    required this.beforeTotalDues,
    required this.afterTotalDues,
    required this.beforeTotalBilled,
    required this.afterTotalBilled,
    required this.correctedAt,
  });

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'customerName': customerName,
    'beforeTotalDues': beforeTotalDues,
    'afterTotalDues': afterTotalDues,
    'beforeTotalBilled': beforeTotalBilled,
    'afterTotalBilled': afterTotalBilled,
    'correctedAt': correctedAt.toIso8601String(),
  };
}

/// Result of enhanced stock integrity check
class StockIntegrityResult {
  final String status; // HEALTHY, CORRECTED, ALERTS_PENDING
  final int checkedCount;
  final int minorFixCount;
  final int majorAlertCount;
  final List<StockCorrectionRecord> fixes;
  final List<StockAlertRecord> alerts;
  final DateTime timestamp;

  StockIntegrityResult({
    required this.status,
    required this.checkedCount,
    required this.minorFixCount,
    required this.majorAlertCount,
    required this.fixes,
    required this.alerts,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'status': status,
    'checkedCount': checkedCount,
    'minorFixCount': minorFixCount,
    'majorAlertCount': majorAlertCount,
    'fixes': fixes.map((f) => f.toJson()).toList(),
    'alerts': alerts.map((a) => a.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Stock correction record for audit
class StockCorrectionRecord {
  final String productId;
  final String productName;
  final double snapshotStock;
  final double calculatedStock;
  final double difference;
  final StockMismatchSeverity severity;
  final DateTime correctedAt;

  StockCorrectionRecord({
    required this.productId,
    required this.productName,
    required this.snapshotStock,
    required this.calculatedStock,
    required this.difference,
    required this.severity,
    required this.correctedAt,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'snapshotStock': snapshotStock,
    'calculatedStock': calculatedStock,
    'difference': difference,
    'severity': severity.name,
    'correctedAt': correctedAt.toIso8601String(),
  };
}

/// Stock alert record for large mismatches
class StockAlertRecord {
  final String productId;
  final String productName;
  final double snapshotStock;
  final double calculatedStock;
  final double difference;
  final DateTime alertedAt;
  final String message;

  StockAlertRecord({
    required this.productId,
    required this.productName,
    required this.snapshotStock,
    required this.calculatedStock,
    required this.difference,
    required this.alertedAt,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'snapshotStock': snapshotStock,
    'calculatedStock': calculatedStock,
    'difference': difference,
    'alertedAt': alertedAt.toIso8601String(),
    'message': message,
  };
}

/// Severity levels for stock mismatches
enum StockMismatchSeverity {
  minor, // < 1 unit - silent auto-fix
  moderate, // 1-5 units - auto-fix with log
  major, // > 5 units - alert only, no auto-fix
}
