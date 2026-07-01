import '../models/party_ledger_model.dart';
import '../../accounting/accounting.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import 'package:drift/drift.dart';

import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/sync_queue_state_machine.dart';

/// Party Ledger Service - Manages customer/vendor ledgers
///
/// Bridges the gap between traditional "Party" concept and
/// double-entry "Ledger" concept.
class PartyLedgerService {
  final AccountingRepository _accountingRepo;
  final FinancialReportsService _reportsService;
  final AppDatabase _db;
  final SyncManager _syncManager;

  PartyLedgerService({
    AccountingRepository? accountingRepo,
    FinancialReportsService? reportsService,
    AppDatabase? db,
    SyncManager? syncManager,
  }) : _accountingRepo = accountingRepo ?? AccountingRepository(),
       _reportsService = reportsService ?? FinancialReportsService(),
       _db = db ?? sl<AppDatabase>(),
       _syncManager = syncManager ?? SyncManager.instance;

  /// Get party balance summary
  Future<PartyBalanceSummary> getPartyBalance({
    required String userId,
    required String partyId,
    required String partyType, // 'CUSTOMER' or 'VENDOR'
  }) async {
    // Get linked ledger account
    final ledger = await _accountingRepo.getLedgerByLinkedEntity(
      userId,
      partyType,
      partyId,
    );

    if (ledger == null) {
      return PartyBalanceSummary(
        currentBalance: 0,
        balanceType: 'Dr',
        lastTransactionDate: null,
      );
    }

    // Get last transaction date
    // Better: get last journal entry involving this ledger
    final statement = await _reportsService.getLedgerStatement(
      userId: userId,
      ledgerId: ledger.id,
      startDate: DateTime.now().subtract(const Duration(days: 365)),
      endDate: DateTime.now(),
    );

    final lastTxnDate = statement.transactions.isNotEmpty
        ? statement.transactions.last.date
        : null;

    return PartyBalanceSummary(
      currentBalance: ledger.currentBalance.abs(),
      balanceType: ledger.currentBalance >= 0 ? 'Dr' : 'Cr',
      lastTransactionDate: lastTxnDate,
    );
  }

  /// Get detailed statement of account for a party
  Future<LedgerStatement> getPartyStatement({
    required String userId,
    required String partyId,
    required String partyType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ledger = await _accountingRepo.getLedgerByLinkedEntity(
      userId,
      partyType,
      partyId,
    );

    if (ledger == null) {
      throw Exception('Ledger not found for party');
    }

    return await _reportsService.getLedgerStatement(
      userId: userId,
      ledgerId: ledger.id,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Sync legacy CustomerModel balance with double-entry ledger
  ///
  /// This ensures backward compatibility by updating the `totalDues`
  /// field in Customers table to match the calculated ledger balance.
  Future<void> syncCustomerBalance(String userId, String customerId) async {
    final ledger = await _accountingRepo.getLedgerByLinkedEntity(
      userId,
      'CUSTOMER',
      customerId,
    );

    if (ledger == null) return;

    final now = DateTime.now();

    // Update customer table with new balance
    await (_db.update(
      _db.customers,
    )..where((t) => t.id.equals(customerId))).write(
      CustomersCompanion(
        totalDues: Value(ledger.currentBalance),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );

    // CRITICAL: Queue for Sync
    await _syncManager.enqueue(
      SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.update,
        targetCollection: 'customers',
        documentId: customerId,
        payload: {
          'totalDues': ledger.currentBalance,
          'updatedAt': now.toIso8601String(),
        },
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// NEW: Aging Analysis & Interest Calculation (Phase 3 Enhancements)
  /// --------------------------------------------------------------------------

  /// Calculate Aging Analysis for a Customer (FIFO Basis)
  ///
  /// buckets: 0-30, 31-60, 61-90, 91+ days
  Future<AgingReport> getAgingAnalysis({
    required String userId,
    required String partyId,
    required String partyType,
  }) async {
    // Fetch party name based on type
    String partyName = 'Unknown';
    if (partyType == 'CUSTOMER') {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(partyId))).getSingleOrNull();
      partyName = customer?.name ?? 'Unknown Customer';
    } else if (partyType == 'VENDOR') {
      final vendor = await (_db.select(
        _db.vendors,
      )..where((t) => t.id.equals(partyId))).getSingleOrNull();
      partyName = vendor?.name ?? 'Unknown Vendor';
    }

    // 1. Get current Total Dues from Ledger
    final balanceSummary = await getPartyBalance(
      userId: userId,
      partyId: partyId,
      partyType: partyType,
    );

    double totalDue = balanceSummary.currentBalance;

    // If credit balance (advance payment), no aging needed
    if (balanceSummary.balanceType == 'Cr' || totalDue <= 0) {
      return AgingReport(
        partyId: partyId,
        partyName: partyName,
        totalDue: totalDue,
        generatedAt: DateTime.now(),
        buckets: [
          AgingBucket(label: '0-30 days', amount: 0, startDay: 0, endDay: 30),
          AgingBucket(label: '31-60 days', amount: 0, startDay: 31, endDay: 60),
          AgingBucket(label: '61-90 days', amount: 0, startDay: 61, endDay: 90),
          AgingBucket(label: '90+ days', amount: 0, startDay: 91, endDay: -1),
        ],
      );
    }

    // 2. Fetch Unpaid/Partial Bills to age them
    // Note: In a pure double-entry system, we should match invoices with receipts.
    // For DukanX opacity, we will assume "Oldest Bill is Unpaid first" (FIFO).
    // So we fetch ALL unpaid bills and match them against the total ledger balance.

    // Fetch bills sorted by Date DESC (Latest first)
    // We will allocate the TOTAL DUE to these bills starting from latest (or generally oldest? FIFO means oldest stays unpaid).
    // Actually, for Aging:
    // If Total Due = 1000.
    // Bill A (Today): 500. Bill B (60 days ago): 500.
    // Unpaid is 1000.
    // Bucket 0-30: 500. Bucket 31-60: 500.

    final query = _db.select(_db.bills)
      ..where((t) => t.userId.equals(userId))
      ..where((t) => t.customerId.equals(partyId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.billDate, mode: OrderingMode.desc),
      ]);

    final bills = await query.get();

    // Map buckets
    double bucket0_30 = 0;
    double bucket31_60 = 0;
    double bucket61_90 = 0;
    double bucket91Plus = 0;

    double remainingToAllocate = totalDue;

    for (var bill in bills) {
      if (remainingToAllocate <= 0) break;

      // Ensure we don't allocate more than the bill's grand total
      // (Used 'grandTotal' - 'paidAmount' if we trusted bill status, but we trust Ledger Balance more)
      // So we allocate the minimum of (Bill Amount, Remaining Allocation)
      double allocatable = bill.grandTotal;
      // Optimization: if bill status is 'Partial', we could use (grandTotal - paidAmount).
      // But Ledger is SOT. Let's just attribute 'remainingToAllocate' to this bill up to its full value.

      double allocated = (remainingToAllocate > allocatable)
          ? allocatable
          : remainingToAllocate;

      // Determine Age
      final ageDays = DateTime.now().difference(bill.billDate).inDays;

      if (ageDays <= 30) {
        bucket0_30 += allocated;
      } else if (ageDays <= 60) {
        bucket31_60 += allocated;
      } else if (ageDays <= 90) {
        bucket61_90 += allocated;
      } else {
        bucket91Plus += allocated;
      }

      remainingToAllocate -= allocated;
    }

    // If any remaining (e.g. Opening Balance not linked to bills), put in 90+
    if (remainingToAllocate > 0) {
      bucket91Plus += remainingToAllocate;
    }

    return AgingReport(
      partyId: partyId,
      partyName: bills.isNotEmpty
          ? (bills.first.customerName ?? 'Unknown')
          : 'Customer',
      totalDue: totalDue,
      generatedAt: DateTime.now(),
      buckets: [
        AgingBucket(
          label: '0-30 days',
          amount: bucket0_30,
          startDay: 0,
          endDay: 30,
        ),
        AgingBucket(
          label: '31-60 days',
          amount: bucket31_60,
          startDay: 31,
          endDay: 60,
        ),
        AgingBucket(
          label: '61-90 days',
          amount: bucket61_90,
          startDay: 61,
          endDay: 90,
        ),
        AgingBucket(
          label: '90+ days',
          amount: bucket91Plus,
          startDay: 91,
          endDay: -1,
        ),
      ],
    );
  }

  /// Calculate Simple Interest on Overdue Amount
  ///
  /// rate: Annual Interest Rate (e.g., 24%)
  Future<double> calculateInterest({
    required String userId,
    required String partyId,
    required double annualRate,
  }) async {
    final agingReport = await getAgingAnalysis(
      userId: userId,
      partyId: partyId,
      partyType: 'CUSTOMER',
    );

    // Simple Rule: Interest only on >30 days? Or all?
    // Usually on overdue. Let's assume buckets > 30 are overdue.
    // Daily Rate = annualRate / 365 / 100

    double dailyRate = annualRate / 365 / 100;
    double totalInterest = 0;

    // Bucket 31-60 (Avg 45 days overdue?) - Approximation
    // Better: Calculate per bill in getAging.
    // For simplicity, we use weighted avg days for buckets.

    totalInterest += agingReport.thirtyToSixty * dailyRate * 45; // Midpoint
    totalInterest += agingReport.sixtyToNinety * dailyRate * 75; // Midpoint
    totalInterest += agingReport.ninetyPlus * dailyRate * 120; // Assumed avg

    return totalInterest;
  }
}
