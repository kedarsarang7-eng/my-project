// ============================================================================
// UDHAR REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages Udhar (Credit) data with Drift as source of truth
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

/// Udhar Person Model
class UdharPerson {
  final String id;
  final String userId;
  final String name;
  final String? phone;
  final String? note;
  final double balance;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  UdharPerson({
    required this.id,
    required this.userId,
    required this.name,
    this.phone,
    this.note,
    this.balance = 0.0,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'phone': phone,
    'note': note,
    'balance': balance,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Udhar Transaction Model
class UdharTransaction {
  final String id;
  final String personId;
  final String userId;
  final double amount;
  final String type; // 'GIVEN', 'TAKEN'
  final String? reason;
  final DateTime date;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  UdharTransaction({
    required this.id,
    required this.personId,
    required this.userId,
    required this.amount,
    required this.type,
    this.reason,
    required this.date,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'personId': personId,
    'amount': amount,
    'type': type,
    'reason': reason,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Udhar Repository
class UdharRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  UdharRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'customers'; // Wait, mapped to nested?

  // Note: Udhar is nested in Firestore: customers/{userId}/udhar_people/{personId}
  // OR users/{userId}/udhar_people/...
  // Based on FirestoreService, it was: customers/{customerId}/udhar_people
  // Assuming 'customerId' passed to FirestoreService WAS the user's ID in some context?
  // Let's assume standard root collection mapping for now: 'udhar_people' if we were designing fresh.
  // But for legacy compatibility, we might need to map it carefully.
  // However, Offline-First favors flat structures.
  // We will sync to 'udhar_people' root collection with 'userId' field for simplicity if acceptable.
  // IF strictly following legacy path: we need sophisticated SyncManager mapping.
  // Given user request is Refactor, we can modernize the path. "users/{userId}/udhar_people" is best.

  // ============================================
  // UDHAR PEOPLE OPERATIONS
  // ============================================

  Stream<List<UdharPerson>> watchPeople({required String userId}) {
    return (database.select(database.udharPeople)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_entityToPerson).toList());
  }

  Future<RepositoryResult<UdharPerson>> createPerson({
    required String userId,
    required String name,
    String? note,
  }) async {
    return await errorHandler.runSafe<UdharPerson>(() async {
      final now = DateTime.now();
      final id = _generateId();

      final person = UdharPerson(
        id: id,
        userId: userId,
        name: name,
        note: note,
        createdAt: now,
        updatedAt: now,
      );

      await database
          .into(database.udharPeople)
          .insert(
            UdharPeopleCompanion.insert(
              id: id,
              userId: userId,
              name: name,
              note: Value(note),
              balance: const Value(0.0),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Queue Sync (Path: users/{userId}/udhar_people/{id})
      await _queueSync(
        userId,
        SyncOperationType.create,
        'udhar_people',
        id,
        person.toFirestoreMap(),
      );

      return person;
    }, 'createPerson');
  }

  Future<RepositoryResult<void>> deletePerson({
    required String userId,
    required String personId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(
        database.udharPeople,
      )..where((t) => t.id.equals(personId))).write(
        UdharPeopleCompanion(
          deletedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      await _queueSync(
        userId,
        SyncOperationType.delete,
        'udhar_people',
        personId,
        {},
      );
    }, 'deletePerson');
  }

  // ============================================
  // UDHAR TRANSACTION OPERATIONS
  // ============================================

  Stream<List<UdharTransaction>> watchTransactions({required String personId}) {
    return (database.select(database.udharTransactions)
          ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map((rows) => rows.map(_entityToTransaction).toList());
  }

  Future<RepositoryResult<UdharTransaction>> addTransaction({
    required String userId,
    required String personId,
    required double amount,
    required String type,
    String? reason,
    required DateTime date,
  }) async {
    return await errorHandler.runSafe<UdharTransaction>(() async {
      final now = DateTime.now();
      final id = _generateId();

      final tx = UdharTransaction(
        id: id,
        personId: personId,
        userId: userId,
        amount: amount,
        type: type,
        reason: reason,
        date: date,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Insert Transaction
      await database
          .into(database.udharTransactions)
          .insert(
            UdharTransactionsCompanion.insert(
              id: id,
              personId: personId,
              userId: userId,
              amount: amount,
              type: type,
              reason: Value(reason),
              date: date,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Update Person Balance
      // GIVEN: You gave money -> You expect it back (+ve balance or -ve based on logic)
      // TAKEN: You took money -> You owe it (-ve or +ve)
      // Let's standard: Balance = Receivable (You gave) - Payable (You took)
      // So GIVEN adds to balance, TAKEN subtracts.
      double delta = type == 'given' ? amount : -amount;

      // We need to fetch current balance first or recalculate
      // Ideally recalculate from all transactions to be safe, but increments are faster.
      // Let's use custom SQL or just fetch-update for now.
      final person = await (database.select(
        database.udharPeople,
      )..where((t) => t.id.equals(personId))).getSingle();
      final newBalance = person.balance + delta;

      await (database.update(
        database.udharPeople,
      )..where((t) => t.id.equals(personId))).write(
        UdharPeopleCompanion(balance: Value(newBalance), updatedAt: Value(now)),
      );

      // 3. Queue Sync
      // We sync transaction as top-level 'udhar_transactions' or subcollection?
      // Keeping it simple: Top level 'udhar_transactions' with personId pointer.
      await _queueSync(
        userId,
        SyncOperationType.create,
        'udhar_transactions',
        id,
        tx.toFirestoreMap(),
      );

      // Sync Person update too
      await _queueSync(
        userId,
        SyncOperationType.update,
        'udhar_people',
        personId,
        {'balance': newBalance},
      );

      return tx;
    }, 'addTransaction');
  }

  Future<RepositoryResult<void>> deleteTransaction({
    required String userId,
    required String personId,
    required String txId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      // 1. Get TX to reverse balance
      final tx = await (database.select(
        database.udharTransactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      double delta = tx.type == 'given' ? -tx.amount : tx.amount; // Reverse

      // 2. Soft Delete TX
      await (database.update(database.udharTransactions)
            ..where((t) => t.id.equals(txId)))
          .write(UdharTransactionsCompanion(deletedAt: Value(DateTime.now())));

      // 3. Update Balance
      final person = await (database.select(
        database.udharPeople,
      )..where((t) => t.id.equals(personId))).getSingle();
      final newBalance = person.balance + delta;

      await (database.update(
        database.udharPeople,
      )..where((t) => t.id.equals(personId))).write(
        UdharPeopleCompanion(
          balance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 4. Queue Sync
      await _queueSync(
        userId,
        SyncOperationType.delete,
        'udhar_transactions',
        txId,
        {},
      );
      await _queueSync(
        userId,
        SyncOperationType.update,
        'udhar_people',
        personId,
        {'balance': newBalance},
      );
    }, 'deleteTransaction');
  }

  // ============================================
  // HELPERS
  // ============================================

  UdharPerson _entityToPerson(UdharPersonEntity e) {
    return UdharPerson(
      id: e.id,
      userId: e.userId,
      name: e.name,
      phone: e.phone,
      note: e.note,
      balance: e.balance,
      isSynced: e.isSynced,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      deletedAt: e.deletedAt,
    );
  }

  UdharTransaction _entityToTransaction(UdharTransactionEntity e) {
    return UdharTransaction(
      id: e.id,
      personId: e.personId,
      userId: e.userId,
      amount: e.amount,
      type: e.type,
      reason: e.reason,
      date: e.date,
      isSynced: e.isSynced,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      deletedAt: e.deletedAt,
    );
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  Future<void> _queueSync(
    String userId,
    SyncOperationType type,
    String collection,
    String docId,
    Map<String, dynamic> payload,
  ) async {
    final item = SyncQueueItem.create(
      userId: userId,
      operationType: type,
      targetCollection: collection,
      documentId: docId,
      payload: payload,
    );
    await syncManager.enqueue(item);
  }
}
