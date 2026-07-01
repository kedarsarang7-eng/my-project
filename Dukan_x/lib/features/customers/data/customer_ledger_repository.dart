// ============================================================================
// CUSTOMER LEDGER REPOSITORY
// ============================================================================
// Manages ledger entries (debit/credit) for customer dashboard
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/sync_queue_state_machine.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/di/service_locator.dart';

// ============================================================================
// MODELS
// ============================================================================

enum LedgerEntryType { debit, credit, opening, adjustment }

/// Ledger entry for customer view
class LedgerEntry {
  final String id;
  final String customerId;
  final String vendorId;
  final LedgerEntryType entryType;
  final double amount;
  final double runningBalance;
  final String? referenceType;
  final String? referenceId;
  final String? referenceNumber;
  final String? description;
  final String? notes;
  final DateTime entryDate;
  final bool isSynced;
  final DateTime createdAt;

  LedgerEntry({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.entryType,
    required this.amount,
    required this.runningBalance,
    this.referenceType,
    this.referenceId,
    this.referenceNumber,
    this.description,
    this.notes,
    required this.entryDate,
    this.isSynced = false,
    required this.createdAt,
  });

  factory LedgerEntry.fromEntity(CustomerLedgerEntity e) {
    return LedgerEntry(
      id: e.id,
      customerId: e.customerId,
      vendorId: e.vendorId,
      entryType: _parseEntryType(e.entryType),
      amount: e.amount,
      runningBalance: e.runningBalance,
      referenceType: e.referenceType,
      referenceId: e.referenceId,
      referenceNumber: e.referenceNumber,
      description: e.description,
      notes: e.notes,
      entryDate: e.entryDate,
      isSynced: e.isSynced,
      createdAt: e.createdAt,
    );
  }

  static LedgerEntryType _parseEntryType(String type) {
    switch (type.toUpperCase()) {
      case 'DEBIT':
        return LedgerEntryType.debit;
      case 'CREDIT':
        return LedgerEntryType.credit;
      case 'OPENING':
        return LedgerEntryType.opening;
      case 'ADJUSTMENT':
        return LedgerEntryType.adjustment;
      default:
        return LedgerEntryType.debit;
    }
  }

  String get entryTypeString => entryType.name.toUpperCase();

  bool get isDebit => entryType == LedgerEntryType.debit;
  bool get isCredit => entryType == LedgerEntryType.credit;

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'customerId': customerId,
    'vendorId': vendorId,
    'entryType': entryTypeString,
    'amount': amount,
    'runningBalance': runningBalance,
    'referenceType': referenceType,
    'referenceId': referenceId,
    'referenceNumber': referenceNumber,
    'description': description,
    'notes': notes,
    'entryDate': entryDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Monthly ledger summary
class MonthlyLedgerSummary {
  final int year;
  final int month;
  final double openingBalance;
  final double closingBalance;
  final double totalDebit;
  final double totalCredit;
  final int transactionCount;

  MonthlyLedgerSummary({
    required this.year,
    required this.month,
    required this.openingBalance,
    required this.closingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.transactionCount,
  });

  String get monthName {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month - 1]} $year';
  }
}

// ============================================================================
// REPOSITORY
// ============================================================================

class CustomerLedgerRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  CustomerLedgerRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  // ============================================
  // LEDGER ENTRIES
  // ============================================

  /// Get all ledger entries for a customer-vendor pair
  Future<RepositoryResult<List<LedgerEntry>>> getLedgerEntries({
    required String customerId,
    required String vendorId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return errorHandler.runSafe(() async {
      var query = database.select(database.customerLedger)
        ..where((t) => t.customerId.equals(customerId))
        ..where((t) => t.vendorId.equals(vendorId));

      if (fromDate != null) {
        query = query..where((t) => t.entryDate.isBiggerOrEqualValue(fromDate));
      }
      if (toDate != null) {
        query = query..where((t) => t.entryDate.isSmallerOrEqualValue(toDate));
      }

      query.orderBy([(t) => OrderingTerm.desc(t.entryDate)]);

      final entities = await query.get();
      return entities.map(LedgerEntry.fromEntity).toList();
    }, 'getLedgerEntries');
  }

  /// Watch ledger entries stream
  Stream<List<LedgerEntry>> watchLedgerEntries({
    required String customerId,
    required String vendorId,
  }) {
    return (database.select(database.customerLedger)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.vendorId.equals(vendorId))
          ..orderBy([(t) => OrderingTerm.desc(t.entryDate)]))
        .watch()
        .map((entities) => entities.map(LedgerEntry.fromEntity).toList());
  }

  /// Add a ledger entry
  Future<RepositoryResult<LedgerEntry>> addLedgerEntry({
    required String customerId,
    required String vendorId,
    required LedgerEntryType entryType,
    required double amount,
    String? referenceType,
    String? referenceId,
    String? referenceNumber,
    String? description,
    String? notes,
    DateTime? entryDate,
  }) async {
    return errorHandler.runSafe(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();

      // Get current balance
      final lastEntry =
          await (database.select(database.customerLedger)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.vendorId.equals(vendorId))
                ..orderBy([(t) => OrderingTerm.desc(t.entryDate)])
                ..limit(1))
              .getSingleOrNull();

      final currentBalance = lastEntry?.runningBalance ?? 0;
      final newBalance =
          entryType == LedgerEntryType.debit ||
              entryType == LedgerEntryType.opening
          ? currentBalance + amount
          : currentBalance - amount;

      final entity = CustomerLedgerCompanion.insert(
        id: id,
        customerId: customerId,
        vendorId: vendorId,
        entryType: entryType.name.toUpperCase(),
        amount: amount,
        runningBalance: newBalance,
        referenceType: Value(referenceType),
        referenceId: Value(referenceId),
        referenceNumber: Value(referenceNumber),
        description: Value(description),
        notes: Value(notes),
        entryDate: entryDate ?? now,
        createdAt: now,
      );

      await database.into(database.customerLedger).insert(entity);

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: customerId,
          operationType: SyncOperationType.create,
          targetCollection: 'customer_ledger',
          documentId: id,
          payload: {
            'id': id,
            'customerId': customerId,
            'vendorId': vendorId,
            'entryType': entryType.name.toUpperCase(),
            'amount': amount,
            'runningBalance': newBalance,
            'referenceType': referenceType,
            'referenceId': referenceId,
            'referenceNumber': referenceNumber,
            'description': description,
            'notes': notes,
            'entryDate': (entryDate ?? now).toIso8601String(),
            'createdAt': now.toIso8601String(),
          },
        ),
      );

      final result = await (database.select(
        database.customerLedger,
      )..where((t) => t.id.equals(id))).getSingle();

      return LedgerEntry.fromEntity(result);
    }, 'addLedgerEntry');
  }

  // ============================================
  // BALANCE QUERIES
  // ============================================

  /// Get current balance for a customer-vendor pair
  Future<RepositoryResult<double>> getCurrentBalance({
    required String customerId,
    required String vendorId,
  }) async {
    return errorHandler.runSafe(() async {
      final lastEntry =
          await (database.select(database.customerLedger)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.vendorId.equals(vendorId))
                ..orderBy([(t) => OrderingTerm.desc(t.entryDate)])
                ..limit(1))
              .getSingleOrNull();

      return lastEntry?.runningBalance ?? 0;
    }, 'getCurrentBalance');
  }

  /// Get monthly summary
  Future<RepositoryResult<MonthlyLedgerSummary>> getMonthlySummary({
    required String customerId,
    required String vendorId,
    required int year,
    required int month,
  }) async {
    return errorHandler.runSafe(() async {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Get opening balance (last entry before this month)
      final openingEntry =
          await (database.select(database.customerLedger)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.vendorId.equals(vendorId))
                ..where((t) => t.entryDate.isSmallerThanValue(startDate))
                ..orderBy([(t) => OrderingTerm.desc(t.entryDate)])
                ..limit(1))
              .getSingleOrNull();

      final openingBalance = openingEntry?.runningBalance ?? 0;

      // Get entries for this month
      final monthEntries =
          await (database.select(database.customerLedger)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.vendorId.equals(vendorId))
                ..where((t) => t.entryDate.isBiggerOrEqualValue(startDate))
                ..where((t) => t.entryDate.isSmallerOrEqualValue(endDate)))
              .get();

      double totalDebit = 0;
      double totalCredit = 0;

      for (final entry in monthEntries) {
        if (entry.entryType == 'DEBIT' || entry.entryType == 'OPENING') {
          totalDebit += entry.amount;
        } else {
          totalCredit += entry.amount;
        }
      }

      final closingBalance = openingBalance + totalDebit - totalCredit;

      return MonthlyLedgerSummary(
        year: year,
        month: month,
        openingBalance: openingBalance,
        closingBalance: closingBalance,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        transactionCount: monthEntries.length,
      );
    }, 'getMonthlySummary');
  }
}

// ============================================================================
// RIVERPOD PROVIDERS
// ============================================================================

/// Provider for CustomerLedgerRepository
final customerLedgerRepositoryProvider = Provider<CustomerLedgerRepository>((
  ref,
) {
  return CustomerLedgerRepository(
    database: AppDatabase.instance,
    syncManager: sl<SyncManager>(),
    errorHandler: sl<ErrorHandler>(),
  );
});

/// Provider for ledger entries
final customerLedgerEntriesProvider =
    StreamProvider.family<
      List<LedgerEntry>,
      ({String customerId, String vendorId})
    >((ref, params) {
      final repo = ref.watch(customerLedgerRepositoryProvider);
      return repo.watchLedgerEntries(
        customerId: params.customerId,
        vendorId: params.vendorId,
      );
    });
