import '../core/di/service_locator.dart';
import '../features/accounting/repositories/accounting_repository.dart';
import '../features/accounting/models/ledger_account_model.dart';

/// LedgerService - Offline-First Ledger Management
///
/// Replaces the old Firestore-based service.
/// Uses [AccountingRepository] to access the local Drift database.
///
/// Core Principles:
/// 1. SPEED: Use cached [currentBalance] for real-time UI.
/// 2. ACCURACY: Support [asOfDate] calculation by summing Journals.
/// 3. OFFLINE: All reads happen locally.
class LedgerService {
  final AccountingRepository _repo;

  LedgerService({AccountingRepository? repo})
    : _repo = repo ?? sl<AccountingRepository>();

  /// Get the current balance of a ledger.
  ///
  /// If [asOfDate] is null, returns the pre-calculated [currentBalance] (Instant).
  /// If [asOfDate] is provided, calculates balance by summing journal entries (Slower, Audit-grade).
  Future<double> calculateBalance(
    String userId, // Changed from businessId to match new repo pattern
    String ledgerId, {
    DateTime? asOfDate,
  }) async {
    // 1. Get Ledger
    final ledger = await _repo.getLedgerById(ledgerId);
    if (ledger == null) {
      throw Exception(
        'Ledger not found: $ledgerId',
      ); // Should we return 0? Safe fail?
    }

    // 2. Fast Path: Current Balance
    if (asOfDate == null) {
      return ledger.currentBalance;
    }

    // 3. Slow Path: Historical Calculation
    // We need to fetch all journals up to date.
    // Optimization: If asOfDate is recent, maybe work backwards?
    // For now, simpler to sum from Opening.

    // Fetch entries
    // Note: getJournalEntriesByLedger isn't in Interface yet, we might need to rely on getAllJournalEntries filtered.
    // Or we implement a specific query in Repo.
    // For now, let's grab all entries for the user and filter (safe for < 10k entries, simpler).
    // Ideally we add `getEntriesForLedger(ledgerId)` to Repo.

    // Let's rely on Repo's getAllJournalEntries with date filter
    final entries = await _repo.getAllJournalEntries(userId, endDate: asOfDate);

    double balance = ledger.openingBalance;

    for (var entry in entries) {
      // Find lines affecting this ledger
      for (var line in entry.entries) {
        if (line.ledgerId == ledgerId) {
          if (ledger.group.isDebitNormal) {
            balance += line.debit - line.credit;
          } else {
            balance += line.credit - line.debit;
          }
        }
      }
    }

    return balance;
  }

  /// Batch calculate balances (Optimized)
  Future<Map<String, double>> calculateBalances(
    String userId,
    List<String> ledgerIds, {
    DateTime? asOfDate,
  }) async {
    final results = <String, double>{};

    for (var id in ledgerIds) {
      // Serial for now, parallelizable
      results[id] = await calculateBalance(userId, id, asOfDate: asOfDate);
    }

    return results;
  }

  /// Get Customer/Vendor Balance
  Future<double> getPartyBalance(String userId, String partyId) async {
    // 1. Find Ledger for Party
    // The previous implementation inferred "businessId" was passed.
    // Here we need userId.

    // We check via Repo helper
    // Note: We need to know if it's CUSTOMER or VENDOR to use specific repo method?
    // Repo has `getLedgerByLinkedEntity`.

    var ledger = await _repo.getLedgerByLinkedEntity(
      userId,
      'CUSTOMER',
      partyId,
    );
    ledger ??= await _repo.getLedgerByLinkedEntity(userId, 'VENDOR', partyId);

    if (ledger == null) return 0.0;

    return ledger.currentBalance;
  }

  /// Verify Trial Balance (Audit Tool)
  Future<TrialBalanceResult> verifyTrialBalance(
    String userId, {
    DateTime? asOfDate,
  }) async {
    final ledgers = await _repo.getAllLedgerAccounts(userId);

    double totalDebit = 0;
    double totalCredit = 0;

    // Use current balances if no date
    if (asOfDate == null) {
      for (var l in ledgers) {
        if (l.currentBalance > 0) {
          // We need to know if it's Dr or Cr balance based on Type + Sign
          // Actually, currentBalance usually implies "Normal" balance.
          // Asset (Dr Normal): Positive means Debit Balance.
          // Liability (Cr Normal): Positive means Credit Balance.

          if (l.group.isDebitNormal) {
            totalDebit += l.currentBalance;
          } else {
            totalCredit += l.currentBalance;
          }
        } else {
          // Negative balance means contra?
          // e.g. Overdraft (Bank is Asset, but negative -> Credit Balance)
          if (l.group.isDebitNormal) {
            totalCredit += l.currentBalance.abs();
          } else {
            totalDebit += l.currentBalance.abs();
          }
        }
      }
    } else {
      // Historical - heavy calc
      for (var l in ledgers) {
        final bal = await calculateBalance(userId, l.id, asOfDate: asOfDate);
        if (bal >= 0) {
          if (l.group.isDebitNormal) {
            totalDebit += bal;
          } else {
            totalCredit += bal;
          }
        } else {
          if (l.group.isDebitNormal) {
            totalCredit += bal.abs();
          } else {
            totalDebit += bal.abs();
          }
        }
      }
    }

    return TrialBalanceResult(
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      difference: totalDebit - totalCredit,
      isBalanced:
          (totalDebit - totalCredit).abs() < 0.1, // Floating point tolerance
      asOfDate: asOfDate ?? DateTime.now(),
    );
  }
}

class TrialBalanceResult {
  final double totalDebit;
  final double totalCredit;
  final double difference;
  final bool isBalanced;
  final DateTime asOfDate;

  const TrialBalanceResult({
    required this.totalDebit,
    required this.totalCredit,
    required this.difference,
    required this.isBalanced,
    required this.asOfDate,
  });

  @override
  String toString() =>
      'TrialBalance(Dr: $totalDebit, Cr: $totalCredit, Diff: $difference)';
}
