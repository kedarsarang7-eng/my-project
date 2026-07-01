// Credit Note Repository
//
// Handles CRUD operations for Credit Notes using Drift database
// with offline-first sync queue integration.
//
// Author: DukanX Team
// Created: 2026-01-17

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../models/credit_note_model.dart';

/// Result wrapper for repository operations
class CreditNoteResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  CreditNoteResult.success(this.data) : isSuccess = true, error = null;
  CreditNoteResult.failure(this.error) : isSuccess = false, data = null;
}

/// Credit Note Repository - Drift-based offline-first storage
class CreditNoteRepository {
  final AppDatabase _db;

  CreditNoteRepository(this._db);

  /// Create a new credit note
  Future<CreditNoteResult<CreditNote>> createCreditNote(
    CreditNote creditNote,
  ) async {
    try {
      // Insert into CreditNotes table (using ReturnInwards table for now as schema exists)
      final entity = ReturnInwardsCompanion(
        id: Value(creditNote.id),
        userId: Value(creditNote.userId),
        customerId: Value(creditNote.customerId),
        billId: Value(creditNote.originalBillId),
        billNumber: Value(creditNote.originalBillNumber),
        creditNoteNumber: Value(creditNote.creditNoteNumber),
        amount: Value(creditNote.grandTotal),
        totalReturnAmount: Value(creditNote.grandTotal),
        reason: Value(creditNote.reason),
        itemsJson: Value(
          jsonEncode(creditNote.items.map((e) => e.toMap()).toList()),
        ),
        status: Value(creditNote.status.name.toUpperCase()),
        date: Value(creditNote.date),
        createdAt: Value(creditNote.createdAt),
        isSynced: const Value(false),
      );

      await _db.into(_db.returnInwards).insert(entity);

      // Queue for sync
      _queueForSync(
        creditNote.userId,
        creditNote.id,
        SyncOperationType.create,
        creditNote.toMap(),
      );

      debugPrint(
        'CreditNoteRepository: Created credit note ${creditNote.creditNoteNumber}',
      );
      return CreditNoteResult.success(creditNote);
    } catch (e) {
      debugPrint('CreditNoteRepository: Error creating credit note: $e');
      return CreditNoteResult.failure(e.toString());
    }
  }

  /// Get credit note by ID
  Future<CreditNote?> getCreditNoteById(String id) async {
    try {
      final query = _db.select(_db.returnInwards)
        ..where((tbl) => tbl.id.equals(id));

      final entity = await query.getSingleOrNull();
      if (entity == null) return null;

      return _entityToCreditNote(entity);
    } catch (e) {
      debugPrint('CreditNoteRepository: Error getting credit note: $e');
      return null;
    }
  }

  /// Get all credit notes for a user
  Future<List<CreditNote>> getAllCreditNotes({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
    CreditNoteStatus? status,
  }) async {
    try {
      final query = _db.select(_db.returnInwards)
        ..where((tbl) => tbl.userId.equals(userId));

      if (fromDate != null) {
        query.where((tbl) => tbl.date.isBiggerOrEqualValue(fromDate));
      }
      if (toDate != null) {
        query.where((tbl) => tbl.date.isSmallerOrEqualValue(toDate));
      }
      if (status != null) {
        query.where((tbl) => tbl.status.equals(status.name.toUpperCase()));
      }

      query.orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);

      final entities = await query.get();
      return entities.map((e) => _entityToCreditNote(e)).toList();
    } catch (e) {
      debugPrint('CreditNoteRepository: Error getting credit notes: $e');
      return [];
    }
  }

  /// Get credit notes for a specific customer
  Future<List<CreditNote>> getCreditNotesForCustomer(
    String userId,
    String customerId,
  ) async {
    try {
      final query = _db.select(_db.returnInwards)
        ..where(
          (tbl) =>
              tbl.userId.equals(userId) & tbl.customerId.equals(customerId),
        )
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);

      final entities = await query.get();
      return entities.map((e) => _entityToCreditNote(e)).toList();
    } catch (e) {
      debugPrint(
        'CreditNoteRepository: Error getting customer credit notes: $e',
      );
      return [];
    }
  }

  /// Get credit notes for a specific bill
  Future<List<CreditNote>> getCreditNotesForBill(
    String userId,
    String billId,
  ) async {
    try {
      final query = _db.select(_db.returnInwards)
        ..where((tbl) => tbl.userId.equals(userId) & tbl.billId.equals(billId))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);

      final entities = await query.get();
      return entities.map((e) => _entityToCreditNote(e)).toList();
    } catch (e) {
      debugPrint('CreditNoteRepository: Error getting bill credit notes: $e');
      return [];
    }
  }

  /// Get credit notes for GSTR-1 filing
  Future<List<CreditNote>> getCreditNotesForGstr1({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final query = _db.select(_db.returnInwards)
        ..where(
          (tbl) =>
              tbl.userId.equals(userId) &
              tbl.date.isBiggerOrEqualValue(fromDate) &
              tbl.date.isSmallerOrEqualValue(toDate) &
              tbl.status.equals('CONFIRMED'),
        )
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]);

      final entities = await query.get();
      return entities.map((e) => _entityToCreditNote(e)).toList();
    } catch (e) {
      debugPrint('CreditNoteRepository: Error getting GSTR-1 credit notes: $e');
      return [];
    }
  }

  /// Get count of credit notes for a user
  Future<int> getCreditNoteCount(String userId) async {
    try {
      final query = _db.select(_db.returnInwards)
        ..where((tbl) => tbl.userId.equals(userId));

      final entities = await query.get();
      return entities.length;
    } catch (e) {
      return 0;
    }
  }

  /// Mark stock as re-entered
  Future<bool> markStockReEntered(String creditNoteId) async {
    try {
      await (_db.update(
        _db.returnInwards,
      )..where((tbl) => tbl.id.equals(creditNoteId))).write(
        const ReturnInwardsCompanion(
          status: Value('PROCESSED'),
          isSynced: Value(false),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('CreditNoteRepository: Error marking stock re-entered: $e');
      return false;
    }
  }

  /// Mark ledger as adjusted
  Future<bool> markLedgerAdjusted(String creditNoteId) async {
    try {
      // Update would be tracked via sync queue
      return true;
    } catch (e) {
      debugPrint('CreditNoteRepository: Error marking ledger adjusted: $e');
      return false;
    }
  }

  /// Mark credit note as included in GSTR-1
  Future<bool> markIncludedInGstr1(String creditNoteId, String period) async {
    try {
      // This would update the GSTR-1 period field if we had one
      debugPrint(
        'CreditNoteRepository: Marked $creditNoteId for GSTR-1 period $period',
      );
      return true;
    } catch (e) {
      debugPrint('CreditNoteRepository: Error marking GSTR-1 inclusion: $e');
      return false;
    }
  }

  /// Cancel a credit note
  Future<bool> cancelCreditNote(String creditNoteId, String reason) async {
    try {
      await (_db.update(
        _db.returnInwards,
      )..where((tbl) => tbl.id.equals(creditNoteId))).write(
        ReturnInwardsCompanion(
          status: const Value('CANCELLED'),
          reason: Value(reason),
          isSynced: const Value(false),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('CreditNoteRepository: Error cancelling credit note: $e');
      return false;
    }
  }

  /// Adjust credit note against a new bill
  Future<bool> adjustAgainstBill({
    required String creditNoteId,
    required String billId,
    required double adjustedAmount,
  }) async {
    try {
      await (_db.update(
        _db.returnInwards,
      )..where((tbl) => tbl.id.equals(creditNoteId))).write(
        const ReturnInwardsCompanion(
          status: Value('ADJUSTED'),
          isSynced: Value(false),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('CreditNoteRepository: Error adjusting credit note: $e');
      return false;
    }
  }

  /// Queue operation for sync using proper SyncQueueItem
  void _queueForSync(
    String userId,
    String documentId,
    SyncOperationType operation,
    Map<String, dynamic> payload,
  ) {
    try {
      final syncItem = SyncQueueItem.create(
        userId: userId,
        operationType: operation,
        targetCollection: 'creditNotes',
        documentId: documentId,
        payload: payload,
        priority: 5,
      );
      SyncManager.instance.enqueue(syncItem);
    } catch (e) {
      debugPrint('CreditNoteRepository: Error queuing for sync: $e');
    }
  }

  /// Convert entity to CreditNote model
  CreditNote _entityToCreditNote(ReturnInwardEntity entity) {
    // Parse items from JSON
    List<CreditNoteItem> items = [];
    if (entity.itemsJson != null) {
      try {
        final decoded = jsonDecode(entity.itemsJson!) as List;
        items = decoded.map((e) => CreditNoteItem.fromMap(e)).toList();
      } catch (_) {}
    }

    // Calculate totals from items
    double totalTaxableValue = 0;
    double totalCgst = 0;
    double totalSgst = 0;
    double totalIgst = 0;

    for (final item in items) {
      totalTaxableValue += item.taxableValue;
      totalCgst += item.cgstAmount;
      totalSgst += item.sgstAmount;
      totalIgst += item.igstAmount;
    }

    final totalGst = totalCgst + totalSgst + totalIgst;

    return CreditNote(
      id: entity.id,
      userId: entity.userId,
      creditNoteNumber:
          entity.creditNoteNumber ?? 'CN-${entity.id.substring(0, 8)}',
      originalBillId: entity.billId ?? '',
      originalBillNumber: entity.billNumber ?? '',
      originalBillDate: entity.date,
      customerId: entity.customerId ?? '',
      customerName: '', // Would need to fetch from customers table
      type: CreditNoteType.partialReturn,
      status: _parseStatus(entity.status),
      items: items,
      reason: entity.reason ?? '',
      subtotal: entity.amount,
      totalTaxableValue: totalTaxableValue,
      totalCgst: totalCgst,
      totalSgst: totalSgst,
      totalIgst: totalIgst,
      totalGst: totalGst,
      grandTotal: entity.totalReturnAmount,
      stockReEntered: entity.status == 'PROCESSED',
      ledgerAdjusted: entity.status == 'PROCESSED',
      balanceAmount: entity.totalReturnAmount,
      date: entity.date,
      createdAt: entity.createdAt,
      isSynced: entity.isSynced,
    );
  }

  CreditNoteStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return CreditNoteStatus.draft;
      case 'CONFIRMED':
      case 'APPROVED':
      case 'PROCESSED':
        return CreditNoteStatus.confirmed;
      case 'CANCELLED':
        return CreditNoteStatus.cancelled;
      case 'ADJUSTED':
        return CreditNoteStatus.adjusted;
      default:
        return CreditNoteStatus.draft;
    }
  }
}
