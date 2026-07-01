// ============================================================================
// EXPENSES REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages expenses with Drift persistence
//
// CRITICAL: Now integrates with AccountingService to create ledger entries
// for proper P&L accuracy.
//
// Author: DukanX Engineering
// Version: 2.0.0 (Accounting Integration Added)
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';
import '../../features/accounting/services/accounting_service.dart';

/// Expense model for UI
class ExpenseModel {
  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime date;
  final String ownerId;
  final bool isSynced;
  final DateTime createdAt;
  final String paymentMode; // CASH or BANK

  ExpenseModel({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.ownerId,
    this.isSynced = false,
    required this.createdAt,
    this.paymentMode = 'CASH',
  });

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'paymentMode': paymentMode,
  };
}

/// Expenses Repository
///
/// CRITICAL: This repository now integrates with AccountingService to:
/// 1. Create proper ledger entries (DR: Expense, CR: Cash/Bank)
/// 2. Ensure expenses appear in P&L statement
/// 3. Update cash/bank balances correctly
class ExpensesRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  final AccountingService? _accountingService;

  ExpensesRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
    AccountingService? accountingService,
  }) : _accountingService = accountingService;

  String get collectionName => 'expenses';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Create an expense with PROPER ACCOUNTING INTEGRATION
  ///
  /// This method now:
  /// 1. Stores expense in local database
  /// 2. Creates journal entry (DR: Expense, CR: Cash/Bank)
  /// 3. Updates P&L via ledger impact
  /// 4. Queues for cloud sync
  Future<RepositoryResult<ExpenseModel>> createExpense({
    required String ownerId,
    required String category,
    required String description,
    required double amount,
    DateTime? date,
    String paymentMode = 'CASH', // CASH or BANK
  }) async {
    return await errorHandler.runSafe<ExpenseModel>(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();
      final expenseDate = date ?? now;

      final expense = ExpenseModel(
        id: id,
        ownerId: ownerId,
        category: category,
        description: description,
        amount: amount,
        date: expenseDate,
        createdAt: now,
        paymentMode: paymentMode,
      );

      // 1. Insert into local database
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: id,
              userId: ownerId,
              category: category,
              description: description,
              amount: amount,
              expenseDate: expenseDate,
              updatedAt: now,
              createdAt: now,
              isSynced: const Value(false),
            ),
          );

      // 2. CRITICAL: Create accounting journal entry
      // This creates: DR: Expense Account, CR: Cash/Bank Account
      if (_accountingService != null) {
        try {
          await _accountingService.createExpenseEntry(
            userId: ownerId,
            expenseId: id,
            expenseCategory: category,
            amount: amount,
            paymentMode: paymentMode,
            expenseDate: expenseDate,
            description: description,
          );
        } catch (e) {
          // Log but don't fail - expense is created, accounting can be fixed
          // In production, this should be a critical alert
          debugPrint(
            '[EXPENSES] WARNING: Failed to create accounting entry: $e',
          );
        }
      }

      // 3. Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: ownerId,
          operationType: SyncOperationType.create,
          targetCollection: collectionName,
          documentId: id,
          payload: expense.toFirestoreMap(),
        ),
      );

      return expense;
    }, 'createExpense');
  }

  /// Get all expenses
  Future<RepositoryResult<List<ExpenseModel>>> getAll({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await errorHandler.runSafe<List<ExpenseModel>>(() async {
      var query = database.select(database.expenses)
        ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull());

      if (fromDate != null) {
        query = query
          ..where((t) => t.expenseDate.isBiggerOrEqualValue(fromDate));
      }
      if (toDate != null) {
        query = query
          ..where((t) => t.expenseDate.isSmallerOrEqualValue(toDate));
      }

      final rows =
          await (query..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
              .get();

      return rows.map((e) => _entityToModel(e)).toList();
    }, 'getAllExpenses');
  }

  /// Watch expenses
  Stream<List<ExpenseModel>> watchAll({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var query = database.select(database.expenses)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull());

    if (fromDate != null) {
      query = query..where((t) => t.expenseDate.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query = query..where((t) => t.expenseDate.isSmallerOrEqualValue(toDate));
    }

    return (query..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .watch()
        .map((rows) => rows.map((e) => _entityToModel(e)).toList());
  }

  /// Update an expense
  Future<RepositoryResult<void>> updateExpense({
    required String id,
    required String userId,
    String? category,
    String? description,
    double? amount,
    DateTime? date,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final updateCompanion = ExpensesCompanion(
        category: category != null ? Value(category) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        expenseDate: date != null ? Value(date) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      );

      await (database.update(
        database.expenses,
      )..where((t) => t.id.equals(id))).write(updateCompanion);

      // Queue for sync
      // Fetch updated record to get full payload if needed, or just send partial
      // For simplicity/robustness, we'll send partial updates usually, but here we can just queue the changed fields
      final payload = <String, dynamic>{};
      if (category != null) payload['category'] = category;
      if (description != null) payload['description'] = description;
      if (amount != null) payload['amount'] = amount;
      if (date != null) payload['date'] = date.toIso8601String();
      payload['updatedAt'] = DateTime.now().toIso8601String();

      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: id,
          payload: payload,
        ),
      );
    }, 'updateExpense');
  }

  /// Delete an expense
  Future<RepositoryResult<void>> deleteExpense({
    required String id,
    required String userId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      await (database.update(
        database.expenses,
      )..where((t) => t.id.equals(id))).write(
        ExpensesCompanion(
          deletedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.delete,
          targetCollection: collectionName,
          documentId: id,
          payload: {},
        ),
      );

      // CRITICAL: Reverse accounting entry
      if (_accountingService != null) {
        await _accountingService.reverseTransaction(
          userId: userId,
          sourceType: 'EXPENSE',
          sourceId: id,
          reason: 'Expense Deleted',
          reversalDate: DateTime.now(),
        );
      }
    }, 'deleteExpense');
  }

  // ============================================
  // HELPERS
  // ============================================

  ExpenseModel _entityToModel(ExpenseEntity e) => ExpenseModel(
    id: e.id,
    category: e.category,
    description: e.description,
    amount: e.amount,
    date: e.expenseDate,
    ownerId: e.userId,
    isSynced: e.isSynced,
    createdAt: e.createdAt,
  );
}
