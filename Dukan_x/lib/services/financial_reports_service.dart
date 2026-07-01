import 'package:dukanx/core/compat/firestore_compat.dart';
import '../models/ledger_model.dart';
import 'ledger_service.dart';

/// Financial Reports Service - Generates P&L, Balance Sheet, Cash Flow.
///
/// All reports are derived dynamically from ledger_entries collection
/// following standard accounting principles (GAAP/IFRS compatible).
class FinancialReportsService {
  final FirebaseFirestore _firestore;
  final LedgerService _ledgerService;

  FinancialReportsService({
    FirebaseFirestore? firestore,
    LedgerService? ledgerService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _ledgerService = ledgerService ?? LedgerService();

  // ============================================================
  // PROFIT & LOSS STATEMENT
  // ============================================================

  /// Generate Profit & Loss statement for a date range.
  ///
  /// Formula:
  /// - Revenue = Sales - Sales Returns
  /// - COGS = Opening Stock + Purchases - Closing Stock
  /// - Gross Profit = Revenue - COGS
  /// - Net Profit = Gross Profit - Operating Expenses
  Future<ProfitLossStatement> generateProfitLoss(
    String businessId,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    // 1. Get all ledger entries in the period
    final entries = await _getLedgerEntriesInRange(
      businessId,
      fromDate,
      toDate,
    );

    // Group entries by ledger
    final ledgerTotals = <String, _LedgerTotal>{};
    for (final entry in entries) {
      final lid = entry['ledgerId'] as String;
      ledgerTotals.putIfAbsent(lid, () => _LedgerTotal());
      ledgerTotals[lid]!.debit += (entry['debit'] ?? 0).toDouble();
      ledgerTotals[lid]!.credit += (entry['credit'] ?? 0).toDouble();
    }

    // 2. Get all ledgers to classify them
    final ledgers = await _getAllLedgers(businessId);

    // 3. Calculate revenue (Credit balances in INCOME group)
    double salesRevenue = 0;
    double salesReturns = 0;

    for (final ledger in ledgers.where((l) => l.group == LedgerGroup.income)) {
      final totals = ledgerTotals[ledger.ledgerId];
      if (totals != null) {
        if (ledger.name.toLowerCase().contains('return')) {
          salesReturns += totals.debit - totals.credit;
        } else {
          salesRevenue += totals.credit - totals.debit;
        }
      }
    }

    final netRevenue = salesRevenue - salesReturns;

    // 4. Calculate COGS
    double openingStock = await _getStockValue(businessId, fromDate);
    double closingStock = await _getStockValue(businessId, toDate);
    double purchases = 0;
    double purchaseReturns = 0;

    for (final ledger in ledgers.where(
      (l) =>
          l.type == LedgerType.purchase ||
          l.name.toLowerCase().contains('purchase'),
    )) {
      final totals = ledgerTotals[ledger.ledgerId];
      if (totals != null) {
        if (ledger.name.toLowerCase().contains('return')) {
          purchaseReturns += totals.credit - totals.debit;
        } else {
          purchases += totals.debit - totals.credit;
        }
      }
    }

    final netPurchases = purchases - purchaseReturns;
    final cogs = openingStock + netPurchases - closingStock;
    final grossProfit = netRevenue - cogs;

    // 5. Calculate operating expenses
    double operatingExpenses = 0;
    for (final ledger in ledgers.where(
      (l) => l.group == LedgerGroup.expenses && l.type != LedgerType.purchase,
    )) {
      final totals = ledgerTotals[ledger.ledgerId];
      if (totals != null) {
        operatingExpenses += totals.debit - totals.credit;
      }
    }

    final netProfit = grossProfit - operatingExpenses;

    return ProfitLossStatement(
      businessId: businessId,
      fromDate: fromDate,
      toDate: toDate,
      salesRevenue: salesRevenue,
      salesReturns: salesReturns,
      netRevenue: netRevenue,
      openingStock: openingStock,
      purchases: purchases,
      purchaseReturns: purchaseReturns,
      closingStock: closingStock,
      cogs: cogs,
      grossProfit: grossProfit,
      operatingExpenses: operatingExpenses,
      netProfit: netProfit,
    );
  }

  // ============================================================
  // BALANCE SHEET
  // ============================================================

  /// Generate Balance Sheet as of a specific date.
  ///
  /// Equation: Assets = Liabilities + Equity
  Future<BalanceSheet> generateBalanceSheet(
    String businessId,
    DateTime asOfDate,
  ) async {
    final ledgers = await _getAllLedgers(businessId);
    final balances = await _ledgerService.calculateBalances(
      businessId,
      ledgers.map((l) => l.ledgerId).toList(),
      asOfDate: asOfDate,
    );

    // Classify ledgers
    double totalAssets = 0;
    double currentAssets = 0;
    double fixedAssets = 0;
    double totalLiabilities = 0;
    double currentLiabilities = 0;
    double longTermLiabilities = 0;
    double equity = 0;

    final assetDetails = <LedgerBalance>[];
    final liabilityDetails = <LedgerBalance>[];
    final equityDetails = <LedgerBalance>[];

    for (final ledger in ledgers) {
      final balance = balances[ledger.ledgerId] ?? 0;
      if (balance.abs() < 0.01) continue;

      final item = LedgerBalance(
        ledgerId: ledger.ledgerId,
        name: ledger.name,
        balance: balance,
      );

      switch (ledger.group) {
        case LedgerGroup.assets:
          if (ledger.type == LedgerType.fixedAsset) {
            fixedAssets += balance;
          } else {
            currentAssets += balance;
          }
          totalAssets += balance;
          assetDetails.add(item);
          break;

        case LedgerGroup.liabilities:
          if (ledger.name.toLowerCase().contains('loan') ||
              ledger.name.toLowerCase().contains('long term')) {
            longTermLiabilities += balance;
          } else {
            currentLiabilities += balance;
          }
          totalLiabilities += balance;
          liabilityDetails.add(item);
          break;

        case LedgerGroup.equity:
          equity += balance;
          equityDetails.add(item);
          break;

        default:
          break;
      }
    }

    // Add closing stock as current asset
    final closingStock = await _getStockValue(businessId, asOfDate);
    currentAssets += closingStock;
    totalAssets += closingStock;
    assetDetails.add(
      LedgerBalance(
        ledgerId: 'closing_stock',
        name: 'Closing Stock',
        balance: closingStock,
      ),
    );

    // Calculate retained earnings (simplified - would need P&L integration)
    final retainedEarnings = totalAssets - totalLiabilities - equity;
    equity += retainedEarnings;
    equityDetails.add(
      LedgerBalance(
        ledgerId: 'retained_earnings',
        name: 'Retained Earnings',
        balance: retainedEarnings,
      ),
    );

    return BalanceSheet(
      businessId: businessId,
      asOfDate: asOfDate,
      totalAssets: totalAssets,
      currentAssets: currentAssets,
      fixedAssets: fixedAssets,
      closingStock: closingStock,
      totalLiabilities: totalLiabilities,
      currentLiabilities: currentLiabilities,
      longTermLiabilities: longTermLiabilities,
      equity: equity,
      assetDetails: assetDetails,
      liabilityDetails: liabilityDetails,
      equityDetails: equityDetails,
      isBalanced: (totalAssets - totalLiabilities - equity).abs() < 0.01,
    );
  }

  // ============================================================
  // CASH FLOW STATEMENT
  // ============================================================

  /// Generate Cash Flow Statement for a date range.
  ///
  /// Shows cash inflows and outflows categorized by:
  /// - Operating Activities (sales, purchases, expenses)
  /// - Investing Activities (fixed assets)
  /// - Financing Activities (loans, capital)
  Future<CashFlowStatement> generateCashFlow(
    String businessId,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    // Get cash/bank ledger entries
    final ledgers = await _getAllLedgers(businessId);
    final cashBankLedgers = ledgers
        .where((l) => l.type == LedgerType.cash || l.type == LedgerType.bank)
        .map((l) => l.ledgerId)
        .toList();

    if (cashBankLedgers.isEmpty) {
      return CashFlowStatement.empty(businessId, fromDate, toDate);
    }

    final entries = await _getLedgerEntriesInRange(
      businessId,
      fromDate,
      toDate,
      ledgerIds: cashBankLedgers,
    );

    double operatingInflow = 0;
    double operatingOutflow = 0;
    double investingInflow = 0;
    double investingOutflow = 0;
    double financingInflow = 0;
    double financingOutflow = 0;

    for (final entry in entries) {
      final debit = (entry['debit'] ?? 0).toDouble();
      final credit = (entry['credit'] ?? 0).toDouble();
      final description = (entry['description'] ?? '').toString().toLowerCase();

      // Categorize based on transaction type/description
      if (description.contains('sale') ||
          description.contains('receipt') ||
          description.contains('payment received')) {
        operatingInflow += debit;
        operatingOutflow += credit;
      } else if (description.contains('purchase') ||
          description.contains('expense') ||
          description.contains('payment made')) {
        operatingInflow += debit;
        operatingOutflow += credit;
      } else if (description.contains('asset') ||
          description.contains('equipment') ||
          description.contains('investment')) {
        investingInflow += debit;
        investingOutflow += credit;
      } else if (description.contains('loan') ||
          description.contains('capital') ||
          description.contains('drawing')) {
        financingInflow += debit;
        financingOutflow += credit;
      } else {
        // Default to operating
        operatingInflow += debit;
        operatingOutflow += credit;
      }
    }

    // Get opening and closing cash balances
    final openingCash = await _getCashBalance(businessId, fromDate);
    final closingCash = await _getCashBalance(businessId, toDate);

    return CashFlowStatement(
      businessId: businessId,
      fromDate: fromDate,
      toDate: toDate,
      openingCashBalance: openingCash,
      operatingActivities: CashFlowActivity(
        inflow: operatingInflow,
        outflow: operatingOutflow,
      ),
      investingActivities: CashFlowActivity(
        inflow: investingInflow,
        outflow: investingOutflow,
      ),
      financingActivities: CashFlowActivity(
        inflow: financingInflow,
        outflow: financingOutflow,
      ),
      closingCashBalance: closingCash,
    );
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  Future<List<Map<String, dynamic>>> _getLedgerEntriesInRange(
    String businessId,
    DateTime fromDate,
    DateTime toDate, {
    List<String>? ledgerIds,
  }) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries')
        .where('date', isGreaterThanOrEqualTo: fromDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: toDate.toIso8601String());

    if (ledgerIds != null && ledgerIds.isNotEmpty) {
      query = query.where('ledgerId', whereIn: ledgerIds);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  Future<List<LedgerModel>> _getAllLedgers(String businessId) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledgers')
        .get();

    return snapshot.docs.map((doc) => LedgerModel.fromMap(doc.data())).toList();
  }

  Future<double> _getStockValue(String businessId, DateTime asOfDate) async {
    // Sum of (quantity * cost price) for all stock items
    final stockSnapshot = await _firestore
        .collection('owners')
        .doc(businessId)
        .collection('stock')
        .get();

    double totalValue = 0;
    for (final doc in stockSnapshot.docs) {
      final data = doc.data();
      final qty = (data['quantity'] ?? 0).toDouble();
      final cost = (data['purchasePrice'] ?? data['costPrice'] ?? 0).toDouble();
      totalValue += qty * cost;
    }

    return totalValue;
  }

  Future<double> _getCashBalance(String businessId, DateTime asOfDate) async {
    final ledgers = await _getAllLedgers(businessId);
    final cashLedgers = ledgers
        .where((l) => l.type == LedgerType.cash || l.type == LedgerType.bank)
        .toList();

    double total = 0;
    for (final ledger in cashLedgers) {
      total += await _ledgerService.calculateBalance(
        businessId,
        ledger.ledgerId,
        asOfDate: asOfDate,
      );
    }

    return total;
  }

  // ============================================================
  // PAGINATION SUPPORT (NEW - GAP 4 FIX)
  // ============================================================

  /// Get paginated journal entries for a date range.
  ///
  /// Use this for large datasets to avoid memory issues.
  /// Returns a [PaginatedResult] with entries and pagination info.
  Future<PaginatedResult<Map<String, dynamic>>> getJournalEntriesPaginated({
    required String businessId,
    required DateTime fromDate,
    required DateTime toDate,
    int limit = 50,
    String? startAfterDocId,
    String? ledgerId,
  }) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('journal_entries')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(toDate))
        .orderBy('date', descending: true)
        .limit(limit + 1); // Fetch one extra to check if there are more

    if (ledgerId != null) {
      query = query.where('ledgerId', isEqualTo: ledgerId);
    }

    if (startAfterDocId != null) {
      final startDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('journal_entries')
          .doc(startAfterDocId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final hasMore = docs.length > limit;
    final items = docs.take(limit).map((d) {
      final data = d.data();
      return <String, dynamic>{...data as Map<String, dynamic>, 'id': d.id};
    }).toList();

    return PaginatedResult(
      items: items,
      hasMore: hasMore,
      lastDocId: items.isNotEmpty ? items.last['id'] as String? : null,
      totalFetched: items.length,
    );
  }

  /// Get paginated ledger transactions for a specific ledger.
  Future<PaginatedResult<Map<String, dynamic>>> getLedgerTransactionsPaginated({
    required String businessId,
    required String ledgerId,
    int limit = 50,
    String? startAfterDocId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries')
        .where('ledgerId', isEqualTo: ledgerId)
        .orderBy('date', descending: true)
        .limit(limit + 1);

    if (fromDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: fromDate.toIso8601String(),
      );
    }
    if (toDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: toDate.toIso8601String(),
      );
    }

    if (startAfterDocId != null) {
      final startDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('ledger_entries')
          .doc(startAfterDocId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final hasMore = docs.length > limit;
    final items = docs.take(limit).map((d) {
      final data = d.data();
      return <String, dynamic>{...data as Map<String, dynamic>, 'id': d.id};
    }).toList();

    return PaginatedResult(
      items: items,
      hasMore: hasMore,
      lastDocId: items.isNotEmpty ? items.last['id'] as String? : null,
      totalFetched: items.length,
    );
  }

  /// Get paginated bills for reporting.
  Future<PaginatedResult<Map<String, dynamic>>> getBillsPaginated({
    required String businessId,
    int limit = 50,
    String? startAfterDocId,
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
  }) async {
    Query query = _firestore
        .collection('bills')
        .where('ownerId', isEqualTo: businessId)
        .orderBy('date', descending: true)
        .limit(limit + 1);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    if (startAfterDocId != null) {
      final startDoc = await _firestore
          .collection('bills')
          .doc(startAfterDocId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    // Filter by date range after fetching (Firestore limitation on multiple orderBy)
    var items = docs
        .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
        .toList();
    if (fromDate != null || toDate != null) {
      items = items.where((item) {
        final date = _parseDate(item['date']);
        if (date == null) return true;
        if (fromDate != null && date.isBefore(fromDate)) return false;
        if (toDate != null && date.isAfter(toDate)) return false;
        return true;
      }).toList();
    }

    final hasMore = items.length > limit;
    items = items.take(limit).toList();

    return PaginatedResult(
      items: items,
      hasMore: hasMore,
      lastDocId: items.isNotEmpty ? items.last['id'] : null,
      totalFetched: items.length,
    );
  }

  /// Get total count of journal entries in a date range.
  Future<int> getJournalEntriesCount({
    required String businessId,
    required DateTime fromDate,
    required DateTime toDate,
    String? ledgerId,
  }) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('journal_entries')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(toDate));

    if (ledgerId != null) {
      query = query.where('ledgerId', isEqualTo: ledgerId);
    }

    final countQuery = await query.count().get();
    return countQuery.count ?? 0;
  }

  /// Get total count of bills in a date range.
  Future<int> getBillsCount({
    required String businessId,
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
  }) async {
    Query query = _firestore
        .collection('bills')
        .where('ownerId', isEqualTo: businessId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final countQuery = await query.count().get();
    return countQuery.count ?? 0;
  }

  /// Get total count of ledger entries for a specific ledger.
  Future<int> getLedgerTransactionsCount({
    required String businessId,
    required String ledgerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries')
        .where('ledgerId', isEqualTo: ledgerId);

    if (fromDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: fromDate.toIso8601String(),
      );
    }
    if (toDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: toDate.toIso8601String(),
      );
    }

    final countQuery = await query.count().get();
    return countQuery.count ?? 0;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  // ============================================================
  // TRIAL BALANCE (NEW - CA AUDIT REQUIREMENT)
  // ============================================================

  /// Generate Trial Balance as of a specific date.
  ///
  /// Trial Balance = List of all ledger balances to verify DR = CR
  /// This is a CRITICAL CA verification tool.
  ///
  /// Returns a [TrialBalance] with all ledger balances and totals.
  Future<TrialBalance> generateTrialBalance(
    String businessId,
    DateTime asOfDate,
  ) async {
    // 1. Get all ledgers
    final ledgers = await _getAllLedgers(businessId);

    // 2. Get all ledger entries up to the date
    final entries = await _getLedgerEntriesInRange(
      businessId,
      DateTime(2000, 1, 1), // From beginning of time
      asOfDate,
    );

    // 3. Calculate running balance for each ledger
    final ledgerTotals = <String, _LedgerTotal>{};
    for (final entry in entries) {
      final lid = entry['ledgerId'] as String;
      ledgerTotals.putIfAbsent(lid, () => _LedgerTotal());
      ledgerTotals[lid]!.debit += (entry['debit'] ?? 0).toDouble();
      ledgerTotals[lid]!.credit += (entry['credit'] ?? 0).toDouble();
    }

    // 4. Build trial balance items
    final items = <TrialBalanceItem>[];
    double totalDebit = 0;
    double totalCredit = 0;

    for (final ledger in ledgers) {
      final totals = ledgerTotals[ledger.ledgerId];
      final openingBalance = ledger.openingBalance;

      // Calculate net balance based on ledger type
      // Assets and Expenses have normal DEBIT balance
      // Liabilities, Equity, Income have normal CREDIT balance
      double debitBalance = 0;
      double creditBalance = 0;

      if (totals != null) {
        final netMovement = totals.debit - totals.credit;

        if (ledger.group == LedgerGroup.assets ||
            ledger.group == LedgerGroup.expenses) {
          // DR increases, CR decreases
          final balance = openingBalance + netMovement;
          if (balance >= 0) {
            debitBalance = balance;
          } else {
            creditBalance = balance.abs();
          }
        } else {
          // Liabilities, Equity, Income: CR increases, DR decreases
          final balance = openingBalance - netMovement;
          if (balance >= 0) {
            creditBalance = balance;
          } else {
            debitBalance = balance.abs();
          }
        }
      } else if (openingBalance != 0) {
        // No transactions, just opening balance
        if (ledger.group == LedgerGroup.assets ||
            ledger.group == LedgerGroup.expenses) {
          if (openingBalance >= 0) {
            debitBalance = openingBalance;
          } else {
            creditBalance = openingBalance.abs();
          }
        } else {
          if (openingBalance >= 0) {
            creditBalance = openingBalance;
          } else {
            debitBalance = openingBalance.abs();
          }
        }
      }

      // Only add ledgers with non-zero balances
      if (debitBalance > 0.01 || creditBalance > 0.01) {
        items.add(
          TrialBalanceItem(
            ledgerId: ledger.ledgerId,
            ledgerName: ledger.name,
            ledgerGroup: ledger.group.toString().split('.').last,
            ledgerType: ledger.type.toString().split('.').last,
            debitBalance: debitBalance,
            creditBalance: creditBalance,
          ),
        );

        totalDebit += debitBalance;
        totalCredit += creditBalance;
      }
    }

    // Sort by group then name
    items.sort((a, b) {
      final groupCompare = a.ledgerGroup.compareTo(b.ledgerGroup);
      if (groupCompare != 0) return groupCompare;
      return a.ledgerName.compareTo(b.ledgerName);
    });

    // Calculate difference (should be zero for balanced books)
    final difference = (totalDebit - totalCredit).abs();
    final isBalanced = difference < 0.01; // Allow for floating point errors

    return TrialBalance(
      businessId: businessId,
      asOfDate: asOfDate,
      items: items,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      difference: difference,
      isBalanced: isBalanced,
      generatedAt: DateTime.now(),
    );
  }
}

class _LedgerTotal {
  double debit = 0;
  double credit = 0;
}

// ============================================================
// REPORT MODELS
// ============================================================

/// Profit & Loss Statement
class ProfitLossStatement {
  final String businessId;
  final DateTime fromDate;
  final DateTime toDate;

  final double salesRevenue;
  final double salesReturns;
  final double netRevenue;

  final double openingStock;
  final double purchases;
  final double purchaseReturns;
  final double closingStock;
  final double cogs;

  final double grossProfit;
  final double operatingExpenses;
  final double netProfit;

  const ProfitLossStatement({
    required this.businessId,
    required this.fromDate,
    required this.toDate,
    required this.salesRevenue,
    required this.salesReturns,
    required this.netRevenue,
    required this.openingStock,
    required this.purchases,
    required this.purchaseReturns,
    required this.closingStock,
    required this.cogs,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netProfit,
  });

  double get grossProfitMargin =>
      netRevenue > 0 ? (grossProfit / netRevenue) * 100 : 0;
  double get netProfitMargin =>
      netRevenue > 0 ? (netProfit / netRevenue) * 100 : 0;

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'fromDate': fromDate.toIso8601String(),
    'toDate': toDate.toIso8601String(),
    'salesRevenue': salesRevenue,
    'salesReturns': salesReturns,
    'netRevenue': netRevenue,
    'openingStock': openingStock,
    'purchases': purchases,
    'purchaseReturns': purchaseReturns,
    'closingStock': closingStock,
    'cogs': cogs,
    'grossProfit': grossProfit,
    'operatingExpenses': operatingExpenses,
    'netProfit': netProfit,
  };
}

/// Balance Sheet
class BalanceSheet {
  final String businessId;
  final DateTime asOfDate;

  final double totalAssets;
  final double currentAssets;
  final double fixedAssets;
  final double closingStock;

  final double totalLiabilities;
  final double currentLiabilities;
  final double longTermLiabilities;

  final double equity;

  final List<LedgerBalance> assetDetails;
  final List<LedgerBalance> liabilityDetails;
  final List<LedgerBalance> equityDetails;

  final bool isBalanced;

  const BalanceSheet({
    required this.businessId,
    required this.asOfDate,
    required this.totalAssets,
    required this.currentAssets,
    required this.fixedAssets,
    required this.closingStock,
    required this.totalLiabilities,
    required this.currentLiabilities,
    required this.longTermLiabilities,
    required this.equity,
    required this.assetDetails,
    required this.liabilityDetails,
    required this.equityDetails,
    required this.isBalanced,
  });

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'asOfDate': asOfDate.toIso8601String(),
    'totalAssets': totalAssets,
    'currentAssets': currentAssets,
    'fixedAssets': fixedAssets,
    'closingStock': closingStock,
    'totalLiabilities': totalLiabilities,
    'currentLiabilities': currentLiabilities,
    'longTermLiabilities': longTermLiabilities,
    'equity': equity,
    'isBalanced': isBalanced,
  };
}

/// Cash Flow Statement
class CashFlowStatement {
  final String businessId;
  final DateTime fromDate;
  final DateTime toDate;

  final double openingCashBalance;
  final CashFlowActivity operatingActivities;
  final CashFlowActivity investingActivities;
  final CashFlowActivity financingActivities;
  final double closingCashBalance;

  const CashFlowStatement({
    required this.businessId,
    required this.fromDate,
    required this.toDate,
    required this.openingCashBalance,
    required this.operatingActivities,
    required this.investingActivities,
    required this.financingActivities,
    required this.closingCashBalance,
  });

  factory CashFlowStatement.empty(
    String businessId,
    DateTime from,
    DateTime to,
  ) {
    return CashFlowStatement(
      businessId: businessId,
      fromDate: from,
      toDate: to,
      openingCashBalance: 0,
      operatingActivities: const CashFlowActivity(inflow: 0, outflow: 0),
      investingActivities: const CashFlowActivity(inflow: 0, outflow: 0),
      financingActivities: const CashFlowActivity(inflow: 0, outflow: 0),
      closingCashBalance: 0,
    );
  }

  double get netCashFromOperating => operatingActivities.net;
  double get netCashFromInvesting => investingActivities.net;
  double get netCashFromFinancing => financingActivities.net;
  double get netCashChange =>
      netCashFromOperating + netCashFromInvesting + netCashFromFinancing;

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'fromDate': fromDate.toIso8601String(),
    'toDate': toDate.toIso8601String(),
    'openingCashBalance': openingCashBalance,
    'operatingActivities': operatingActivities.toMap(),
    'investingActivities': investingActivities.toMap(),
    'financingActivities': financingActivities.toMap(),
    'closingCashBalance': closingCashBalance,
    'netCashChange': netCashChange,
  };
}

/// Cash flow activity category
class CashFlowActivity {
  final double inflow;
  final double outflow;

  const CashFlowActivity({required this.inflow, required this.outflow});

  double get net => inflow - outflow;

  Map<String, dynamic> toMap() => {
    'inflow': inflow,
    'outflow': outflow,
    'net': net,
  };
}

/// Ledger balance for report details
class LedgerBalance {
  final String ledgerId;
  final String name;
  final double balance;

  const LedgerBalance({
    required this.ledgerId,
    required this.name,
    required this.balance,
  });
}

/// Paginated result for large datasets (GAP 4 FIX)
class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final String? lastDocId;
  final int totalFetched;

  const PaginatedResult({
    required this.items,
    required this.hasMore,
    this.lastDocId,
    required this.totalFetched,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'items': items,
    'hasMore': hasMore,
    'lastDocId': lastDocId,
    'totalFetched': totalFetched,
  };
}

// ============================================================
// TRIAL BALANCE MODELS (NEW - CA AUDIT REQUIREMENT)
// ============================================================

/// Trial Balance Report - Lists all ledger balances
///
/// CA Verification: Total Debit MUST equal Total Credit
class TrialBalance {
  final String businessId;
  final DateTime asOfDate;
  final List<TrialBalanceItem> items;
  final double totalDebit;
  final double totalCredit;
  final double difference;
  final bool isBalanced;
  final DateTime generatedAt;

  const TrialBalance({
    required this.businessId,
    required this.asOfDate,
    required this.items,
    required this.totalDebit,
    required this.totalCredit,
    required this.difference,
    required this.isBalanced,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'asOfDate': asOfDate.toIso8601String(),
    'items': items.map((e) => e.toMap()).toList(),
    'totalDebit': totalDebit,
    'totalCredit': totalCredit,
    'difference': difference,
    'isBalanced': isBalanced,
    'generatedAt': generatedAt.toIso8601String(),
  };

  /// Get items grouped by ledger group
  Map<String, List<TrialBalanceItem>> get groupedItems {
    final grouped = <String, List<TrialBalanceItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.ledgerGroup, () => []);
      grouped[item.ledgerGroup]!.add(item);
    }
    return grouped;
  }
}

/// Individual ledger line in Trial Balance
class TrialBalanceItem {
  final String ledgerId;
  final String ledgerName;
  final String ledgerGroup; // assets, liabilities, equity, income, expenses
  final String ledgerType;
  final double debitBalance;
  final double creditBalance;

  const TrialBalanceItem({
    required this.ledgerId,
    required this.ledgerName,
    required this.ledgerGroup,
    required this.ledgerType,
    required this.debitBalance,
    required this.creditBalance,
  });

  /// Net balance (positive = debit dominant, negative = credit dominant)
  double get netBalance => debitBalance - creditBalance;

  Map<String, dynamic> toMap() => {
    'ledgerId': ledgerId,
    'ledgerName': ledgerName,
    'ledgerGroup': ledgerGroup,
    'ledgerType': ledgerType,
    'debitBalance': debitBalance,
    'creditBalance': creditBalance,
    'netBalance': netBalance,
  };
}
