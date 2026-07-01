import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Aggregated settlement data for a farmer over a period.
///
/// All monetary values are in integer paise.
/// Requirement 11.3: total sales, itemized deductions, lot identifiers, payment status.
class SettlementData {
  /// Total sales amount in paise across all ledger entries in the period.
  final int totalSalesPaise;

  /// Total commission deducted in paise.
  final int totalCommissionPaise;

  /// Total labor charges in paise.
  final int totalLaborPaise;

  /// Total hamali charges in paise.
  final int totalHamaliPaise;

  /// Total weighing charges in paise.
  final int totalWeighingPaise;

  /// Total market fee in paise.
  final int totalMarketFeePaise;

  /// Net payable to farmer in paise (sales - all deductions).
  final int netPayablePaise;

  /// List of lot/bill identifiers included in this settlement.
  final List<String> includedLotIds;

  /// Payment status derived from MandiSettlements or computed.
  /// One of: PENDING, PARTIAL, PAID.
  final String paymentStatus;

  /// The farmer name for display.
  final String farmerName;

  /// Period start date (inclusive).
  final DateTime periodStart;

  /// Period end date (inclusive).
  final DateTime periodEnd;

  const SettlementData({
    required this.totalSalesPaise,
    required this.totalCommissionPaise,
    required this.totalLaborPaise,
    required this.totalHamaliPaise,
    required this.totalWeighingPaise,
    required this.totalMarketFeePaise,
    required this.netPayablePaise,
    required this.includedLotIds,
    required this.paymentStatus,
    required this.farmerName,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Sum of all deduction charges (commission + labor + hamali + weighing + market fee).
  int get totalDeductionsPaise =>
      totalCommissionPaise +
      totalLaborPaise +
      totalHamaliPaise +
      totalWeighingPaise +
      totalMarketFeePaise;
}

/// Service responsible for generating settlement (Patti) data for a farmer
/// over an inclusive date period.
///
/// This is the testable aggregation logic separated from the UI.
/// Requirement 11.3.
class SettlementService {
  final AppDatabase _db;

  SettlementService(this._db);

  /// Generates a [SettlementData] for the given [farmerId] within the
  /// inclusive date range [startDate] to [endDate].
  ///
  /// Queries `CommissionLedger` entries for the farmer within the period,
  /// aggregates totals, collects lot/bill identifiers, and derives payment
  /// status from the `MandiSettlements` table (if a matching settlement exists)
  /// or defaults to PENDING.
  ///
  /// Returns `null` if the farmer is not found.
  Future<SettlementData?> generateSettlement({
    required String farmerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Look up the farmer for name display.
    final farmer = await (_db.select(
      _db.farmers,
    )..where((t) => t.id.equals(farmerId))).getSingleOrNull();

    if (farmer == null) return null;

    // Query CommissionLedger entries for this farmer within the inclusive date range.
    // The `date` column stores DateTime; we compare using start-of-day and end-of-day.
    final startMillis = _startOfDay(startDate).millisecondsSinceEpoch;
    final endMillis = _endOfDay(endDate).millisecondsSinceEpoch;

    final entries = await _db
        .customSelect(
          '''SELECT id, bill_id, sale_amount, commission_amount,
                labor_charges, hamali_charges, weighing_charges, market_fee,
                net_payable_to_farmer
         FROM commission_ledger
         WHERE farmer_id = ? AND date >= ? AND date <= ?
         ORDER BY date DESC''',
          variables: [
            Variable.withString(farmerId),
            Variable.withInt(startMillis),
            Variable.withInt(endMillis),
          ],
        )
        .get();

    // Aggregate values.
    final aggregation = aggregateEntries(entries);

    // Derive payment status from MandiSettlements if a matching record exists.
    final paymentStatus = await _derivePaymentStatus(
      farmerId: farmerId,
      startDate: startDate,
      endDate: endDate,
    );

    return SettlementData(
      totalSalesPaise: aggregation.totalSalesPaise,
      totalCommissionPaise: aggregation.totalCommissionPaise,
      totalLaborPaise: aggregation.totalLaborPaise,
      totalHamaliPaise: aggregation.totalHamaliPaise,
      totalWeighingPaise: aggregation.totalWeighingPaise,
      totalMarketFeePaise: aggregation.totalMarketFeePaise,
      netPayablePaise: aggregation.netPayablePaise,
      includedLotIds: aggregation.includedLotIds,
      paymentStatus: paymentStatus,
      farmerName: farmer.name,
      periodStart: startDate,
      periodEnd: endDate,
    );
  }

  /// Pure aggregation logic — testable without DB.
  ///
  /// Takes a list of raw query result rows and produces totals.
  static SettlementAggregation aggregateEntries(List<QueryRow> entries) {
    int totalSales = 0;
    int totalCommission = 0;
    int totalLabor = 0;
    int totalHamali = 0;
    int totalWeighing = 0;
    int totalMarketFee = 0;
    int netPayable = 0;
    final lotIds = <String>[];

    for (final row in entries) {
      totalSales += row.read<int>('sale_amount');
      totalCommission += row.read<int>('commission_amount');
      totalLabor += row.read<int>('labor_charges');
      totalHamali += row.read<int>('hamali_charges');
      totalWeighing += row.read<int>('weighing_charges');
      totalMarketFee += row.read<int>('market_fee');
      netPayable += row.read<int>('net_payable_to_farmer');

      // Collect bill IDs as lot identifiers.
      final billId = row.read<String>('bill_id');
      if (!lotIds.contains(billId)) {
        lotIds.add(billId);
      }
    }

    return SettlementAggregation(
      totalSalesPaise: totalSales,
      totalCommissionPaise: totalCommission,
      totalLaborPaise: totalLabor,
      totalHamaliPaise: totalHamali,
      totalWeighingPaise: totalWeighing,
      totalMarketFeePaise: totalMarketFee,
      netPayablePaise: netPayable,
      includedLotIds: lotIds,
    );
  }

  /// Derives the payment status for a settlement period.
  ///
  /// Checks the `MandiSettlements` table for a matching record (same farmer,
  /// overlapping period). If found, uses its payment status. Otherwise, PENDING.
  Future<String> _derivePaymentStatus({
    required String farmerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startMillis = _startOfDay(startDate).millisecondsSinceEpoch;
    final endMillis = _endOfDay(endDate).millisecondsSinceEpoch;

    final results = await _db
        .customSelect(
          '''SELECT payment_status FROM mandi_settlements
         WHERE farmer_id = ?
           AND period_start_date >= ? AND period_end_date <= ?
         ORDER BY period_end_date DESC
         LIMIT 1''',
          variables: [
            Variable.withString(farmerId),
            Variable.withInt(startMillis),
            Variable.withInt(endMillis),
          ],
        )
        .get();

    if (results.isNotEmpty) {
      return results.first.read<String>('payment_status');
    }
    return 'PENDING';
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}

/// Intermediate aggregation result — pure data, no DB dependency.
class SettlementAggregation {
  final int totalSalesPaise;
  final int totalCommissionPaise;
  final int totalLaborPaise;
  final int totalHamaliPaise;
  final int totalWeighingPaise;
  final int totalMarketFeePaise;
  final int netPayablePaise;
  final List<String> includedLotIds;

  const SettlementAggregation({
    required this.totalSalesPaise,
    required this.totalCommissionPaise,
    required this.totalLaborPaise,
    required this.totalHamaliPaise,
    required this.totalWeighingPaise,
    required this.totalMarketFeePaise,
    required this.netPayablePaise,
    required this.includedLotIds,
  });
}
