import '../models/models.dart';
import '../repositories/accounting_repository.dart';

/// Financial Reports Service - Generates Tally-style accounting reports
///
/// Supports:
/// - Trial Balance
/// - Profit & Loss Statement
/// - Balance Sheet
/// - General Ledger
class FinancialReportsService {
  final AccountingRepository _repo;

  FinancialReportsService({AccountingRepository? repo})
    : _repo = repo ?? AccountingRepository();

  // ============================================================================
  // TRIAL BALANCE
  // ============================================================================

  /// Generate Trial Balance for a period
  /// Shows all ledgers with their debit/credit balances
  ///
  /// Pass [businessId] to scope the report to a single business (multi-tenant
  /// isolation). When omitted, all of the user's ledgers are aggregated.
  Future<TrialBalanceReport> generateTrialBalance({
    required String userId,
    required DateTime asOfDate,
    String? businessId,
  }) async {
    final ledgers = await _repo.getAllLedgerAccounts(
      userId,
      businessId: businessId,
    );
    final entries = await _repo.getAllJournalEntries(
      userId,
      endDate: asOfDate,
      businessId: businessId,
    );

    // Calculate running balance for each ledger
    final balances = <String, double>{};
    for (final ledger in ledgers) {
      balances[ledger.id] = ledger.effectiveOpeningBalance;
    }

    // Apply all journal entries
    for (final entry in entries) {
      if (entry.entryDate.isAfter(asOfDate)) continue;
      for (final line in entry.entries) {
        balances[line.ledgerId] =
            (balances[line.ledgerId] ?? 0) + line.debit - line.credit;
      }
    }

    final items = <TrialBalanceItem>[];
    double totalDebit = 0;
    double totalCredit = 0;

    for (final ledger in ledgers) {
      final balance = balances[ledger.id] ?? 0;
      if (balance == 0) continue; // Skip zero balances

      final isDebitBalance = balance >= 0;
      final absBalance = balance.abs();

      if (isDebitBalance) {
        totalDebit += absBalance;
      } else {
        totalCredit += absBalance;
      }

      items.add(
        TrialBalanceItem(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          group: ledger.group,
          type: ledger.type,
          debit: isDebitBalance ? absBalance : 0,
          credit: isDebitBalance ? 0 : absBalance,
        ),
      );
    }

    // Sort by group then name
    items.sort((a, b) {
      final groupCompare = a.group.index.compareTo(b.group.index);
      if (groupCompare != 0) return groupCompare;
      return a.ledgerName.compareTo(b.ledgerName);
    });

    return TrialBalanceReport(
      asOfDate: asOfDate,
      items: items,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
    );
  }

  // ============================================================================
  // PROFIT & LOSS STATEMENT
  // ============================================================================

  /// Generate Profit & Loss Statement for a period
  /// Shows Income - Expenses = Net Profit/Loss
  ///
  /// Pass [businessId] to scope the report to a single business (multi-tenant
  /// isolation). When omitted, all of the user's ledgers are aggregated.
  Future<ProfitLossReport> generateProfitLoss({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    String? businessId,
  }) async {
    final ledgers = await _repo.getAllLedgerAccounts(
      userId,
      businessId: businessId,
    );
    final entries = await _repo.getAllJournalEntries(
      userId,
      startDate: startDate,
      endDate: endDate,
      businessId: businessId,
    );

    // Separate income and expense ledgers
    final incomeLedgers = ledgers
        .where((l) => l.group == AccountGroup.income)
        .toList();
    final expenseLedgers = ledgers
        .where((l) => l.group == AccountGroup.expenses)
        .toList();

    // Calculate balances for the period
    final balances = <String, double>{};
    for (final entry in entries) {
      for (final line in entry.entries) {
        balances[line.ledgerId] =
            (balances[line.ledgerId] ?? 0) + line.credit - line.debit;
      }
    }

    // Build income items
    final incomeItems = <ProfitLossItem>[];
    double totalIncome = 0;
    for (final ledger in incomeLedgers) {
      final amount = balances[ledger.id] ?? 0;
      if (amount == 0) continue;
      totalIncome += amount;
      incomeItems.add(
        ProfitLossItem(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          amount: amount,
        ),
      );
    }

    // Build expense items
    final expenseItems = <ProfitLossItem>[];
    double totalExpenses = 0;
    for (final ledger in expenseLedgers) {
      final amount = -(balances[ledger.id] ?? 0); // Negate for expenses
      if (amount == 0) continue;
      totalExpenses += amount;
      expenseItems.add(
        ProfitLossItem(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          amount: amount,
        ),
      );
    }

    return ProfitLossReport(
      startDate: startDate,
      endDate: endDate,
      incomeItems: incomeItems,
      expenseItems: expenseItems,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netProfit: totalIncome - totalExpenses,
    );
  }

  // ============================================================================
  // BALANCE SHEET
  // ============================================================================

  /// Generate Balance Sheet as of a date
  /// Assets = Liabilities + Equity
  ///
  /// Pass [businessId] to scope the report to a single business (multi-tenant
  /// isolation). When omitted, all of the user's ledgers are aggregated.
  Future<BalanceSheetReport> generateBalanceSheet({
    required String userId,
    required DateTime asOfDate,
    String? businessId,
  }) async {
    final ledgers = await _repo.getAllLedgerAccounts(
      userId,
      businessId: businessId,
    );
    final entries = await _repo.getAllJournalEntries(
      userId,
      endDate: asOfDate,
      businessId: businessId,
    );

    // Calculate running balance for each ledger
    final balances = <String, double>{};
    for (final ledger in ledgers) {
      balances[ledger.id] = ledger.effectiveOpeningBalance;
    }

    // Apply all journal entries
    for (final entry in entries) {
      if (entry.entryDate.isAfter(asOfDate)) continue;
      for (final line in entry.entries) {
        balances[line.ledgerId] =
            (balances[line.ledgerId] ?? 0) + line.debit - line.credit;
      }
    }

    // Calculate P&L for current period (to include in retained earnings)
    double netProfit = 0;
    for (final ledger in ledgers) {
      if (ledger.group == AccountGroup.income) {
        netProfit -= balances[ledger.id] ?? 0; // Credit increases income
      } else if (ledger.group == AccountGroup.expenses) {
        netProfit += balances[ledger.id] ?? 0; // Debit increases expenses
      }
    }

    // Build asset items
    final assetItems = <BalanceSheetItem>[];
    double totalAssets = 0;
    for (final ledger in ledgers.where((l) => l.group == AccountGroup.assets)) {
      final balance = balances[ledger.id] ?? 0;
      if (balance == 0) continue;
      totalAssets += balance;
      assetItems.add(
        BalanceSheetItem(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          type: ledger.type,
          amount: balance,
        ),
      );
    }

    // Build liability items
    final liabilityItems = <BalanceSheetItem>[];
    double totalLiabilities = 0;
    for (final ledger in ledgers.where(
      (l) => l.group == AccountGroup.liabilities,
    )) {
      final balance = -(balances[ledger.id] ?? 0); // Negate for display
      if (balance == 0) continue;
      totalLiabilities += balance;
      liabilityItems.add(
        BalanceSheetItem(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          type: ledger.type,
          amount: balance,
        ),
      );
    }

    // Build equity items
    final equityItems = <BalanceSheetItem>[];
    double totalEquity = 0;
    for (final ledger in ledgers.where((l) => l.group == AccountGroup.equity)) {
      final balance = -(balances[ledger.id] ?? 0);
      if (balance == 0) continue;
      totalEquity += balance;
      equityItems.add(
        BalanceSheetItem(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          type: ledger.type,
          amount: balance,
        ),
      );
    }

    // Add current period P&L to equity
    equityItems.add(
      BalanceSheetItem(
        ledgerId: 'current_pl',
        ledgerName: 'Current Period Profit/Loss',
        type: AccountType.reserve,
        amount: netProfit,
      ),
    );
    totalEquity += netProfit;

    return BalanceSheetReport(
      asOfDate: asOfDate,
      assetItems: assetItems,
      liabilityItems: liabilityItems,
      equityItems: equityItems,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      totalEquity: totalEquity,
    );
  }

  // ============================================================================
  // GENERAL LEDGER
  // ============================================================================

  /// Get ledger statement (all transactions for a ledger)
  ///
  /// Pass [businessId] to scope entries to a single business (multi-tenant
  /// isolation). When omitted, all of the user's entries are considered.
  Future<LedgerStatement> getLedgerStatement({
    required String userId,
    required String ledgerId,
    required DateTime startDate,
    required DateTime endDate,
    String? businessId,
  }) async {
    final ledger = await _repo.getLedgerById(ledgerId);
    if (ledger == null) {
      throw Exception('Ledger not found');
    }

    final entries = await _repo.getAllJournalEntries(
      userId,
      endDate: endDate,
      businessId: businessId,
    );

    // Calculate opening balance
    double openingBalance = ledger.effectiveOpeningBalance;
    for (final entry in entries) {
      if (entry.entryDate.isBefore(startDate)) {
        for (final line in entry.entries.where((l) => l.ledgerId == ledgerId)) {
          openingBalance += line.debit - line.credit;
        }
      }
    }

    // Build transaction list
    final transactions = <LedgerTransaction>[];
    double runningBalance = openingBalance;

    for (final entry in entries) {
      if (entry.entryDate.isBefore(startDate) ||
          entry.entryDate.isAfter(endDate)) {
        continue;
      }

      for (final line in entry.entries.where((l) => l.ledgerId == ledgerId)) {
        runningBalance += line.debit - line.credit;
        transactions.add(
          LedgerTransaction(
            date: entry.entryDate,
            voucherNumber: entry.voucherNumber,
            voucherType: entry.voucherType,
            narration: entry.narration ?? '',
            debit: line.debit,
            credit: line.credit,
            balance: runningBalance,
          ),
        );
      }
    }

    // Sort by date
    transactions.sort((a, b) => a.date.compareTo(b.date));

    return LedgerStatement(
      ledger: ledger,
      startDate: startDate,
      endDate: endDate,
      openingBalance: openingBalance,
      transactions: transactions,
      closingBalance: runningBalance,
    );
  }
}

// ============================================================================
// REPORT MODELS
// ============================================================================

/// Trial Balance Report
class TrialBalanceReport {
  final DateTime asOfDate;
  final List<TrialBalanceItem> items;
  final double totalDebit;
  final double totalCredit;

  TrialBalanceReport({
    required this.asOfDate,
    required this.items,
    required this.totalDebit,
    required this.totalCredit,
  });

  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;
}

class TrialBalanceItem {
  final String ledgerId;
  final String ledgerName;
  final AccountGroup group;
  final AccountType type;
  final double debit;
  final double credit;

  TrialBalanceItem({
    required this.ledgerId,
    required this.ledgerName,
    required this.group,
    required this.type,
    required this.debit,
    required this.credit,
  });
}

/// Profit & Loss Report
class ProfitLossReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<ProfitLossItem> incomeItems;
  final List<ProfitLossItem> expenseItems;
  final double totalIncome;
  final double totalExpenses;
  final double netProfit;

  ProfitLossReport({
    required this.startDate,
    required this.endDate,
    required this.incomeItems,
    required this.expenseItems,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netProfit,
  });

  bool get isProfitable => netProfit >= 0;
}

class ProfitLossItem {
  final String ledgerId;
  final String ledgerName;
  final double amount;

  ProfitLossItem({
    required this.ledgerId,
    required this.ledgerName,
    required this.amount,
  });
}

/// Balance Sheet Report
class BalanceSheetReport {
  final DateTime asOfDate;
  final List<BalanceSheetItem> assetItems;
  final List<BalanceSheetItem> liabilityItems;
  final List<BalanceSheetItem> equityItems;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;

  BalanceSheetReport({
    required this.asOfDate,
    required this.assetItems,
    required this.liabilityItems,
    required this.equityItems,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
  });

  double get liabilitiesAndEquity => totalLiabilities + totalEquity;
  bool get isBalanced => (totalAssets - liabilitiesAndEquity).abs() < 0.01;
}

class BalanceSheetItem {
  final String ledgerId;
  final String ledgerName;
  final AccountType type;
  final double amount;

  BalanceSheetItem({
    required this.ledgerId,
    required this.ledgerName,
    required this.type,
    required this.amount,
  });
}

/// Ledger Statement
class LedgerStatement {
  final LedgerAccountModel ledger;
  final DateTime startDate;
  final DateTime endDate;
  final double openingBalance;
  final List<LedgerTransaction> transactions;
  final double closingBalance;

  LedgerStatement({
    required this.ledger,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.transactions,
    required this.closingBalance,
  });
}

class LedgerTransaction {
  final DateTime date;
  final String voucherNumber;
  final VoucherType voucherType;
  final String narration;
  final double debit;
  final double credit;
  final double balance;

  LedgerTransaction({
    required this.date,
    required this.voucherNumber,
    required this.voucherType,
    required this.narration,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  /// Alias for balance (running balance)
  double get runningBalance => balance;
}
