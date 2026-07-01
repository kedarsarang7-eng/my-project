// ============================================================================
// BANK RECONCILIATION SERVICE
// ============================================================================
// Provides bank statement reconciliation with ledger transactions.
// Enables matching of bank statement entries with system records.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import '../../../core/services/logger_service.dart';
import 'package:uuid/uuid.dart';

/// Bank Reconciliation Service
///
/// Enables CA-grade bank reconciliation by:
/// 1. Importing bank statement entries
/// 2. Auto-matching with ledger transactions
/// 3. Manual reconciliation for unmatched items
/// 4. Generating Bank Reconciliation Statement (BRS)
class BankReconciliationService {
    ApiClient get _api => sl<ApiClient>();
  BankReconciliationService();

  // ============================================================
  // BANK STATEMENT ENTRY MANAGEMENT
  // ============================================================

  /// Import bank statement entries for reconciliation.
  ///
  /// [entries] should contain date, description, debit/credit, and balance.
  Future<ImportResult> importBankStatementEntries({
    required String businessId,
    required String bankAccountId,
    required List<BankStatementEntry> entries}) async {
    try {
      int imported = 0;
      int duplicates = 0;

      final batch = WriteBatch();

      for (final entry in entries) {
        // Check for duplicates (same date, amount, and reference)
        final existing = await _api
            .collection('businesses')
            .doc(businessId)
            .collection('bank_statement_entries')
            .where('bankAccountId', isEqualTo: bankAccountId)
            .where('date', isEqualTo: Timestamp.fromDate(entry.date))
            .where('amount', isEqualTo: entry.amount)
            .where('reference', isEqualTo: entry.reference)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          duplicates++;
          continue;
        }

        final id = const Uuid().v4();
        final docRef = _api
            .collection('businesses')
            .doc(businessId)
            .collection('bank_statement_entries')
            .doc(id);

        batch.set(docRef, {
          'id': id,
          'bankAccountId': bankAccountId,
          'date': Timestamp.fromDate(entry.date),
          'description': entry.description,
          'reference': entry.reference,
          'amount': entry.amount,
          'type': entry.type, // DEBIT or CREDIT
          'balance': entry.balance,
          'isReconciled': false,
          'matchedTransactionId': null,
          'matchConfidence': 0.0,
          'createdAt': FieldValue.serverTimestamp()});

        imported++;
      }

      await batch.commit();

      LoggerService.d('BankRecon', 
        '[BANK_RECON] Imported $imported entries, $duplicates duplicates skipped',
      );

      return ImportResult(
        imported: imported,
        duplicates: duplicates,
        total: entries.length,
      );
    } catch (e) {
      LoggerService.d('BankRecon', '[BANK_RECON] Import failed: $e');
      rethrow;
    }
  }

  // ============================================================
  // AUTO-MATCHING
  // ============================================================

  /// Auto-match bank statement entries with ledger transactions.
  ///
  /// Matching criteria:
  /// 1. Exact amount match
  /// 2. Date within ±3 days
  /// 3. Reference/description similarity
  Future<MatchResult> autoMatchEntries({
    required String businessId,
    required String bankAccountId,
    DateTime? fromDate,
    DateTime? toDate}) async {
    int matched = 0;
    int unmatched = 0;

    // 1. Get unreconciled bank statement entries
    Query query = _api
        .collection('businesses')
        .doc(businessId)
        .collection('bank_statement_entries')
        .where('bankAccountId', isEqualTo: bankAccountId)
        .where('isReconciled', isEqualTo: false);

    if (fromDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
      );
    }
    if (toDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(toDate),
      );
    }

    final unreconciledEntries = await query.get();

    // 2. Get ledger transactions for the bank account
    final ledgerEntries = await _api
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries')
        .where('ledgerId', isEqualTo: 'BANK_$bankAccountId')
        .get();

    // Build a map of unmatched ledger entries by amount
    final ledgerByAmount = <double, List<QueryDocumentSnapshot>>{};
    for (final doc in ledgerEntries.docs) {
      final data = doc.data();
      final amount = ((data['debit'] ?? 0) - (data['credit'] ?? 0)).abs();
      ledgerByAmount.putIfAbsent(amount, () => []).add(doc);
    }

    // 3. Try to match each bank statement entry
    final batch = WriteBatch();

    for (final doc in unreconciledEntries.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num).toDouble();
      final date = (data['date'] as Timestamp).toDate();
      final reference = data['reference'] as String?;

      // Look for matching ledger entries
      final candidates = ledgerByAmount[amount] ?? [];

      QueryDocumentSnapshot? bestMatch;
      double bestConfidence = 0.0;

      for (final candidate in candidates) {
        final candidateData = candidate.data();
        final candidateDate = _parseDate(candidateData['date']);
        final candidateRef = candidateData['referenceId'] as String?;

        if (candidateDate == null) continue;

        // Check date proximity (within 3 days)
        final daysDiff = (date.difference(candidateDate).inDays).abs();
        if (daysDiff > 3) continue;

        // Calculate confidence score
        double confidence = 0.5; // Base score for amount match

        // Date match bonus
        if (daysDiff == 0) {
          confidence += 0.3;
        } else if (daysDiff == 1) {
          confidence += 0.2;
        } else {
          confidence += 0.1;
        }

        // Reference match bonus
        if (reference != null && candidateRef != null) {
          if (reference.toLowerCase().contains(candidateRef.toLowerCase()) ||
              candidateRef.toLowerCase().contains(reference.toLowerCase())) {
            confidence += 0.2;
          }
        }

        if (confidence > bestConfidence) {
          bestConfidence = confidence;
          bestMatch = candidate;
        }
      }

      // Only auto-match if confidence is high enough (>80%)
      if (bestMatch != null && bestConfidence >= 0.8) {
        batch.update(doc.reference, {
          'isReconciled': true,
          'matchedTransactionId': bestMatch.id,
          'matchConfidence': bestConfidence,
          'reconciledAt': FieldValue.serverTimestamp(),
          'reconciledBy': 'AUTO'});

        // Remove from candidates to prevent double-matching
        candidates.remove(bestMatch);
        matched++;
      } else {
        unmatched++;
      }
    }

    await batch.commit();

    LoggerService.d('BankRecon', '[BANK_RECON] Auto-matched $matched, unmatched $unmatched');

    return MatchResult(
      matched: matched,
      unmatched: unmatched,
      total: unreconciledEntries.docs.length,
    );
  }

  // ============================================================
  // MANUAL RECONCILIATION
  // ============================================================

  /// Manually match a bank statement entry with a ledger transaction.
  Future<void> manualMatch({
    required String businessId,
    required String bankStatementEntryId,
    required String ledgerTransactionId,
    required String matchedBy}) async {
    await _api
        .collection('businesses')
        .doc(businessId)
        .collection('bank_statement_entries')
        .doc(bankStatementEntryId)
        .update({
          'isReconciled': true,
          'matchedTransactionId': ledgerTransactionId,
          'matchConfidence': 1.0,
          'reconciledAt': FieldValue.serverTimestamp(),
          'reconciledBy': matchedBy});

    LoggerService.d('BankRecon', 
      '[BANK_RECON] Manually matched $bankStatementEntryId -> $ledgerTransactionId',
    );
  }

  /// Mark a bank statement entry as reconciled without matching.
  ///
  /// Use this for bank charges, interest, or other entries that
  /// don't have a corresponding ledger entry yet.
  Future<void> markAsReconciled({
    required String businessId,
    required String bankStatementEntryId,
    required String reason,
    required String reconciledBy}) async {
    await _api
        .collection('businesses')
        .doc(businessId)
        .collection('bank_statement_entries')
        .doc(bankStatementEntryId)
        .update({
          'isReconciled': true,
          'matchedTransactionId': null,
          'matchConfidence': 0.0,
          'reconciliationNote': reason,
          'reconciledAt': FieldValue.serverTimestamp(),
          'reconciledBy': reconciledBy});
  }

  /// Unmatch a previously reconciled entry.
  Future<void> unmatch({
    required String businessId,
    required String bankStatementEntryId}) async {
    await _api
        .collection('businesses')
        .doc(businessId)
        .collection('bank_statement_entries')
        .doc(bankStatementEntryId)
        .update({
          'isReconciled': false,
          'matchedTransactionId': null,
          'matchConfidence': 0.0,
          'reconciledAt': null,
          'reconciledBy': null,
          'reconciliationNote': null});
  }

  // ============================================================
  // BANK RECONCILIATION STATEMENT (BRS)
  // ============================================================

  /// Generate a Bank Reconciliation Statement.
  ///
  /// The BRS shows:
  /// 1. Balance as per bank statement
  /// 2. Add: Cheques deposited but not credited
  /// 3. Less: Cheques issued but not presented
  /// 4. Add/Less: Other adjustments
  /// 5. Balance as per books
  Future<BankReconciliationStatement> generateBRS({
    required String businessId,
    required String bankAccountId,
    required DateTime asOfDate}) async {
    // 1. Get bank statement balance (latest entry before asOfDate)
    final bankStatementQuery = await _api
        .collection('businesses')
        .doc(businessId)
        .collection('bank_statement_entries')
        .where('bankAccountId', isEqualTo: bankAccountId)
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(asOfDate))
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    double bankBalance = 0;
    if (bankStatementQuery.docs.isNotEmpty) {
      final data = bankStatementQuery.docs.first.data();
      bankBalance = (data['balance'] as num?)?.toDouble() ?? 0;
    }

    // 2. Get unreconciled items - Cheques deposited but not credited (Add)
    final unrecreditedDeposits = await _getUnreconciledItems(
      businessId: businessId,
      bankAccountId: bankAccountId,
      asOfDate: asOfDate,
      type: 'CREDIT', // Our deposits showing as credit in books
      source: 'BOOKS', // From our books
    );

    // 3. Get unreconciled items - Cheques issued but not presented (Less)
    final unpresentedCheques = await _getUnreconciledItems(
      businessId: businessId,
      bankAccountId: bankAccountId,
      asOfDate: asOfDate,
      type: 'DEBIT', // Our payments showing as debit in books
      source: 'BOOKS',
    );

    // 4. Get unreconciled items in bank statement not in books
    final bankOnlyCredits = await _getUnreconciledItems(
      businessId: businessId,
      bankAccountId: bankAccountId,
      asOfDate: asOfDate,
      type: 'CREDIT',
      source: 'BANK',
    );

    final bankOnlyDebits = await _getUnreconciledItems(
      businessId: businessId,
      bankAccountId: bankAccountId,
      asOfDate: asOfDate,
      type: 'DEBIT',
      source: 'BANK',
    );

    // 5. Calculate book balance
    // Bank Balance
    // + Cheques deposited but not credited
    // - Cheques issued but not presented
    // + Bank credits not in books (interest, etc.)
    // - Bank debits not in books (charges, etc.)
    // = Book Balance

    double depositTotal = unrecreditedDeposits.fold(
      0.0,
      (total, item) => total + item.amount,
    );
    double chequeTotal = unpresentedCheques.fold(
      0.0,
      (total, item) => total + item.amount,
    );
    double bankCreditTotal = bankOnlyCredits.fold(
      0.0,
      (total, item) => total + item.amount,
    );
    double bankDebitTotal = bankOnlyDebits.fold(
      0.0,
      (total, item) => total + item.amount,
    );

    double bookBalance =
        bankBalance +
        depositTotal -
        chequeTotal +
        bankCreditTotal -
        bankDebitTotal;

    // 6. Get actual book balance from ledger
    final ledgerBalance = await _getLedgerBalance(
      businessId,
      bankAccountId,
      asOfDate,
    );

    // 7. Calculate difference
    final difference = (bookBalance - ledgerBalance).abs();
    final isReconciled = difference < 0.01;

    return BankReconciliationStatement(
      businessId: businessId,
      bankAccountId: bankAccountId,
      asOfDate: asOfDate,
      bankBalance: bankBalance,
      depositsNotCredited: unrecreditedDeposits,
      chequesNotPresented: unpresentedCheques,
      bankCreditsNotInBooks: bankOnlyCredits,
      bankDebitsNotInBooks: bankOnlyDebits,
      calculatedBookBalance: bookBalance,
      actualBookBalance: ledgerBalance,
      difference: difference,
      isReconciled: isReconciled,
      generatedAt: DateTime.now(),
    );
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  Future<List<ReconciliationItem>> _getUnreconciledItems({
    required String businessId,
    required String bankAccountId,
    required DateTime asOfDate,
    required String type,
    required String source}) async {
    final items = <ReconciliationItem>[];

    if (source == 'BOOKS') {
      // Get ledger entries that are not reflected in bank statement
      final ledgerQuery = await _api
          .collection('businesses')
          .doc(businessId)
          .collection('ledger_entries')
          .where('ledgerId', isEqualTo: 'BANK_$bankAccountId')
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(asOfDate))
          .get();

      // Get all matched transaction IDs
      final matchedIds = await _getMatchedTransactionIds(
        businessId,
        bankAccountId,
      );

      for (final doc in ledgerQuery.docs) {
        final data = doc.data();
        if (!matchedIds.contains(doc.id)) {
          final debit = (data['debit'] ?? 0).toDouble();
          final credit = (data['credit'] ?? 0).toDouble();
          final entryType = debit > credit ? 'DEBIT' : 'CREDIT';

          if (entryType == type) {
            items.add(
              ReconciliationItem(
                id: doc.id,
                date: _parseDate(data['date']) ?? asOfDate,
                description: data['description'] ?? 'Unknown',
                amount: (debit - credit).abs(),
                type: type,
                source: source,
              ),
            );
          }
        }
      }
    } else {
      // Get bank statement entries that are not reconciled
      final bankQuery = await _api
          .collection('businesses')
          .doc(businessId)
          .collection('bank_statement_entries')
          .where('bankAccountId', isEqualTo: bankAccountId)
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(asOfDate))
          .where('isReconciled', isEqualTo: false)
          .where('type', isEqualTo: type)
          .get();

      for (final doc in bankQuery.docs) {
        final data = doc.data();
        items.add(
          ReconciliationItem(
            id: doc.id,
            date: (data['date'] as Timestamp).toDate(),
            description: data['description'] ?? 'Unknown',
            amount: (data['amount'] as num).toDouble(),
            type: type,
            source: source,
          ),
        );
      }
    }

    return items;
  }

  Future<Set<String>> _getMatchedTransactionIds(
    String businessId,
    String bankAccountId,
  ) async {
    final query = await _api
        .collection('businesses')
        .doc(businessId)
        .collection('bank_statement_entries')
        .where('bankAccountId', isEqualTo: bankAccountId)
        .where('isReconciled', isEqualTo: true)
        .get();

    final ids = <String>{};
    for (final doc in query.docs) {
      final data = doc.data();
      final matchedId = data['matchedTransactionId'] as String?;
      if (matchedId != null) {
        ids.add(matchedId);
      }
    }
    return ids;
  }

  Future<double> _getLedgerBalance(
    String businessId,
    String bankAccountId,
    DateTime asOfDate,
  ) async {
    final query = await _api
        .collection('businesses')
        .doc(businessId)
        .collection('ledger_entries')
        .where('ledgerId', isEqualTo: 'BANK_$bankAccountId')
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(asOfDate))
        .get();

    double balance = 0;
    for (final doc in query.docs) {
      final data = doc.data();
      final debit = (data['debit'] ?? 0).toDouble();
      final credit = (data['credit'] ?? 0).toDouble();
      balance += (debit - credit);
    }
    return balance;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

// ============================================================
// DATA MODELS
// ============================================================

/// Bank Statement Entry for import
class BankStatementEntry {
  final DateTime date;
  final String description;
  final String? reference;
  final double amount;
  final String type; // DEBIT or CREDIT
  final double balance;

  const BankStatementEntry({
    required this.date,
    required this.description,
    this.reference,
    required this.amount,
    required this.type,
    required this.balance});

  factory BankStatementEntry.fromMap(Map<String, dynamic> map) {
    return BankStatementEntry(
      date: DateTime.parse(map['date']),
      description: map['description'] ?? '',
      reference: map['reference'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] ?? 'DEBIT',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Import result
class ImportResult {
  final int imported;
  final int duplicates;
  final int total;

  const ImportResult({
    required this.imported,
    required this.duplicates,
    required this.total});
}

/// Match result
class MatchResult {
  final int matched;
  final int unmatched;
  final int total;

  const MatchResult({
    required this.matched,
    required this.unmatched,
    required this.total});

  double get matchRate => total > 0 ? matched / total : 0;
}

/// Individual reconciliation item
class ReconciliationItem {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final String type;
  final String source;

  const ReconciliationItem({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.source});

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'description': description,
    'amount': amount,
    'type': type,
    'source': source};
}

/// Bank Reconciliation Statement
class BankReconciliationStatement {
  final String businessId;
  final String bankAccountId;
  final DateTime asOfDate;
  final double bankBalance;
  final List<ReconciliationItem> depositsNotCredited;
  final List<ReconciliationItem> chequesNotPresented;
  final List<ReconciliationItem> bankCreditsNotInBooks;
  final List<ReconciliationItem> bankDebitsNotInBooks;
  final double calculatedBookBalance;
  final double actualBookBalance;
  final double difference;
  final bool isReconciled;
  final DateTime generatedAt;

  const BankReconciliationStatement({
    required this.businessId,
    required this.bankAccountId,
    required this.asOfDate,
    required this.bankBalance,
    required this.depositsNotCredited,
    required this.chequesNotPresented,
    required this.bankCreditsNotInBooks,
    required this.bankDebitsNotInBooks,
    required this.calculatedBookBalance,
    required this.actualBookBalance,
    required this.difference,
    required this.isReconciled,
    required this.generatedAt});

  /// Total of deposits not yet credited
  double get totalDepositsNotCredited =>
      depositsNotCredited.fold(0.0, (total, item) => total + item.amount);

  /// Total of cheques not yet presented
  double get totalChequesNotPresented =>
      chequesNotPresented.fold(0.0, (total, item) => total + item.amount);

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'bankAccountId': bankAccountId,
    'asOfDate': asOfDate.toIso8601String(),
    'bankBalance': bankBalance,
    'depositsNotCredited': depositsNotCredited.map((e) => e.toMap()).toList(),
    'chequesNotPresented': chequesNotPresented.map((e) => e.toMap()).toList(),
    'bankCreditsNotInBooks': bankCreditsNotInBooks
        .map((e) => e.toMap())
        .toList(),
    'bankDebitsNotInBooks': bankDebitsNotInBooks.map((e) => e.toMap()).toList(),
    'calculatedBookBalance': calculatedBookBalance,
    'actualBookBalance': actualBookBalance,
    'difference': difference,
    'isReconciled': isReconciled,
    'generatedAt': generatedAt.toIso8601String()};
}
