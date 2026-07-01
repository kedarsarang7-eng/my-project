// ============================================================================
// BANK REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages bank accounts and transactions with Drift as source of truth
//
// Author: DukanX Engineering
// Version: 2.1.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

/// Bank Account Model
class BankAccount {
  final String id;
  final String userId;
  final String accountName;
  final String? bankName;
  final String? accountNumber;
  final String? ifsc; // Added
  final double openingBalance;
  final double currentBalance;
  final bool isPrimary;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankAccount({
    required this.id,
    required this.userId,
    required this.accountName,
    this.bankName,
    this.accountNumber,
    this.ifsc,
    this.openingBalance = 0,
    this.currentBalance = 0,
    this.isPrimary = false,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'accountName': accountName,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'ifsc': ifsc,
    'openingBalance': openingBalance,
    'currentBalance': currentBalance,
    'isPrimary': isPrimary,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Bank Transaction Model for UI
class BankTransaction {
  final String id;
  final String accountId;
  final double amount;
  final String type;
  final String category;
  final String? description;
  final String? referenceId;
  final DateTime date;

  BankTransaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    this.referenceId,
    required this.date,
  });

  factory BankTransaction.fromEntity(BankTransactionEntity e) =>
      BankTransaction(
        id: e.id,
        accountId: e.accountId,
        amount: e.amount,
        type: e.type,
        category: e.category,
        description: e.description,
        referenceId: e.referenceId,
        date: e.transactionDate,
      );
}

/// Bank Repository
class BankRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  BankRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'bankAccounts';

  // ============================================
  // ACCOUNT OPERATIONS
  // ============================================

  /// Create a bank account
  Future<RepositoryResult<BankAccount>> createAccount({
    required String userId,
    required String accountName,
    String? bankName,
    String? accountNumber,
    double openingBalance = 0,
    bool isPrimary = false,
  }) async {
    return await errorHandler.runSafe<BankAccount>(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();

      final account = BankAccount(
        id: id,
        userId: userId,
        accountName: accountName,
        bankName: bankName,
        accountNumber: accountNumber,
        openingBalance: openingBalance,
        currentBalance: openingBalance,
        isPrimary: isPrimary,
        createdAt: now,
        updatedAt: now,
      );

      await database
          .into(database.bankAccounts)
          .insert(
            BankAccountsCompanion.insert(
              id: id,
              userId: userId,
              accountName: accountName,
              bankName: Value(bankName),
              accountNumber: Value(accountNumber),
              openingBalance: Value(openingBalance),
              currentBalance: Value(openingBalance),
              isPrimary: Value(isPrimary),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: id,
        payload: account.toFirestoreMap(),
      );
      await syncManager.enqueue(item);

      return account;
    }, 'createAccount');
  }

  /// Get all bank accounts
  Future<RepositoryResult<List<BankAccount>>> getAccounts({
    required String userId,
  }) async {
    return await errorHandler.runSafe<List<BankAccount>>(() async {
      final results = await (database.select(
        database.bankAccounts,
      )..where((t) => t.userId.equals(userId) & t.isActive.equals(true))).get();

      return results.map(_entityToAccount).toList();
    }, 'getAccounts');
  }

  /// Watch bank accounts
  Stream<List<BankAccount>> watchAccounts({required String userId}) {
    return (database.select(database.bankAccounts)
          ..where((t) => t.userId.equals(userId) & t.isActive.equals(true)))
        .watch()
        .map((rows) => rows.map(_entityToAccount).toList());
  }

  /// Watch a single bank account
  Stream<BankAccount> watchAccount(String id) {
    return (database.select(
      database.bankAccounts,
    )..where((t) => t.id.equals(id))).watchSingle().map(_entityToAccount);
  }

  /// Watch transactions for an account
  Stream<List<BankTransaction>> watchTransactions(String accountId) {
    return (database.select(database.bankTransactions)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .watch()
        .map((rows) => rows.map(BankTransaction.fromEntity).toList());
  }

  /// Get total balance across all accounts
  Future<RepositoryResult<double>> getTotalBalance({
    required String userId,
  }) async {
    return await errorHandler.runSafe<double>(() async {
      final query = database.select(database.bankAccounts)
        ..where((t) => t.userId.equals(userId) & t.isActive.equals(true));

      final accounts = await query.get();
      return accounts.fold<double>(0, (sum, a) => sum + a.currentBalance);
    }, 'getTotalBalance');
  }

  // ============================================
  // TRANSACTION OPERATIONS
  // ============================================

  /// Record a transaction (Credit/Debit)
  Future<RepositoryResult<bool>> recordTransaction({
    required String userId,
    required String accountId,
    required double amount,
    required String type, // CREDIT, DEBIT
    required String category,
    String? referenceId,
    String? description,
    DateTime? date,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();

      // Start database transaction
      await database.transaction(() async {
        // 1. Get current account
        final account = await (database.select(
          database.bankAccounts,
        )..where((t) => t.id.equals(accountId))).getSingleOrNull();

        if (account == null) throw Exception('Account not found');

        // 2. Calculate new balance
        final newBalance = type == 'CREDIT'
            ? account.currentBalance + amount
            : account.currentBalance - amount;

        // 3. Update account balance
        await (database.update(
          database.bankAccounts,
        )..where((t) => t.id.equals(accountId))).write(
          BankAccountsCompanion(
            currentBalance: Value(newBalance),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

        // 4. Insert transaction record
        await database
            .into(database.bankTransactions)
            .insert(
              BankTransactionsCompanion.insert(
                id: id,
                userId: userId,
                accountId: accountId,
                amount: amount,
                type: type,
                category: category,
                referenceId: Value(referenceId),
                description: Value(description),
                transactionDate: date ?? now,
                createdAt: now,
              ),
            );

        // 5. Queue for sync (Account update)
        final accountUpdate = SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: accountId,
          payload: {
            'currentBalance': newBalance,
            'updatedAt': now.toIso8601String(),
          },
        );
        await syncManager.enqueue(accountUpdate);
      });

      // 6. Queue for sync (Transaction record)
      final txOp = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.create,
        targetCollection: 'bankTransactions',
        documentId: id,
        payload: {
          'id': id,
          'accountId': accountId,
          'amount': amount,
          'type': type,
          'category': category,
          'referenceId': referenceId,
          'description': description,
          'transactionDate': (date ?? now).toIso8601String(),
        },
      );
      await syncManager.enqueue(txOp);

      return true;
    }, 'recordTransaction');
  }

  // ============================================
  // HELPERS
  // ============================================

  BankAccount _entityToAccount(BankAccountEntity e) => BankAccount(
    id: e.id,
    userId: e.userId,
    accountName: e.accountName,
    bankName: e.bankName,
    accountNumber: e.accountNumber,
    openingBalance: e.openingBalance,
    currentBalance: e.currentBalance,
    isPrimary: e.isPrimary,
    isActive: e.isActive,
    isSynced: e.isSynced,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
  );
}
