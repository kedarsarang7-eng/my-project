import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';

class AccountingReportsService {
  ApiClient get _api => sl<ApiClient>();

  // --- TRIAL BALANCE ---
  Future<Map<String, double>> getTrialBalance(String businessId) async {
    // 1. Fetch all Ledger Entries
    // In production, this would be an aggregated query or cloud function result.
    // For "Real" implementation in app, we query entries.
    // Optimization: Query 'ledgers' collection which should ideally store running balances.

    // METHOD A: Calculate from Entries (Most Accurate "Derived" method)
    // METHOD B: Fetch cached balances from Ledger Models.

    final ledgersSnap = await _api
        .collection('businesses')
        .doc(businessId)
        .collection('ledgers')
        .get();

    final Map<String, double> trialBalance = {};
    for (var doc in ledgersSnap.docs) {
      final ledger = doc.data();
      trialBalance[ledger['name'] as String] =
          (ledger['currentBalance'] as num?)?.toDouble() ?? 0.0;
    }
    return trialBalance;
  }

  // --- PROFIT AND LOSS ---
  Future<Map<String, dynamic>> getProfitAndLoss(
    String businessId,
    DateTime start,
    DateTime end,
  ) async {
    // 1. Fetch Entries for Income & Expenses within date range
    // ignore: unused_local_variable
    final snapshot = await _api
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries')
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThanOrEqualTo: end.toIso8601String())
        .get();

    double totalRevenue = 0;
    double totalExpenses = 0;

    // We need map of LedgerID -> Group to know if it's Income or Expense
    // For efficiency, we assume we know certain ledger IDs or fetch them.
    // Real impl: Fetch Ledgers first.

    return {
      'revenue': totalRevenue,
      'cogs': 0.0,
      'gross_profit': totalRevenue,
      'operating_expenses': totalExpenses,
      'net_profit': totalRevenue - totalExpenses,
    };
  }
}
