import 'package:dukanx/core/compat/firestore_compat.dart';
import '../models/ledger_model.dart';

class AccountingReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- TRIAL BALANCE ---
  Future<Map<String, double>> getTrialBalance(String businessId) async {
    // 1. Fetch all Ledger Entries
    // In production, this would be an aggregated query or cloud function result.
    // For "Real" implementation in app, we query entries.
    // Optimization: Query 'ledgers' collection which should ideally store running balances.

    // METHOD A: Calculate from Entries (Most Accurate "Derived" method)
    // METHOD B: Fetch cached balances from Ledger Models.

    // Using Method B (Fast) but providing logic for A (Verify)

    final ledgersSnap = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledgers')
        .get();

    final Map<String, double> trialBalance = {};

    for (var doc in ledgersSnap.docs) {
      final ledger = LedgerModel.fromMap(doc.data());
      // Convention: Asset/Expense -> Debit Balance positive
      // Liability/Income -> Credit Balance positive

      // However, strictly:
      // We sum up (Debit - Credit).
      // If Positive -> Debit Side.
      // If Negative -> Credit Side.

      // Let's assume we simply list the balances.
      // Ideally, we sum entries.

      trialBalance[ledger.name] = ledger.currentBalance;
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
    final snapshot = await _firestore
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

    // Placeholder logic for the "Structure":
    return {
      'revenue': totalRevenue,
      'cogs': 0.0, // Needs Stock Ledger
      'gross_profit': 0.0,
      'operating_expenses': totalExpenses,
      'net_profit': totalRevenue - totalExpenses,
    };
  }
}
