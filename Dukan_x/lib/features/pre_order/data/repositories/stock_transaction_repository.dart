import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../models/stock_transaction.dart';

/// Repository for stock transactions (append-only audit log).
/// NEVER update. NEVER delete.
class StockTransactionRepository {
  final FirebaseFirestore _firestore;
  final SyncManager _syncManager;

  static const String _collectionName = 'stock_transactions';

  StockTransactionRepository({
    required FirebaseFirestore firestore,
    required SyncManager syncManager,
  }) : _firestore = firestore,
       _syncManager = syncManager;

  /// Log a stock transaction (APPEND-ONLY)
  Future<String> logTransaction(StockTransaction txn) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(txn.txnId)
          .set(txn.toMap());
      return txn.txnId;
    } catch (e) {
      // Queue for later sync if offline
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: txn.vendorId,
          operationType: SyncOperationType.create,
          targetCollection: _collectionName,
          documentId: txn.txnId,
          payload: txn.toMap(),
        ),
      );
      return txn.txnId;
    }
  }

  /// Log a sale transaction (stock out)
  Future<String> logSale({
    required String vendorId,
    required String itemId,
    required double qty,
    required String billId,
    String? createdBy,
  }) async {
    final txn = StockTransaction.sale(
      txnId: const Uuid().v4(),
      vendorId: vendorId,
      itemId: itemId,
      qty: qty,
      billId: billId,
      createdBy: createdBy,
    );
    return logTransaction(txn);
  }

  /// Log a restock transaction (stock in)
  Future<String> logRestock({
    required String vendorId,
    required String itemId,
    required double qty,
    String? purchaseId,
    String? createdBy,
  }) async {
    final txn = StockTransaction.restock(
      txnId: const Uuid().v4(),
      vendorId: vendorId,
      itemId: itemId,
      qty: qty,
      purchaseId: purchaseId,
      createdBy: createdBy,
    );
    return logTransaction(txn);
  }

  /// Log an adjustment transaction
  Future<String> logAdjustment({
    required String vendorId,
    required String itemId,
    required double deltaQty,
    String? description,
    String? createdBy,
  }) async {
    final txn = StockTransaction.adjustment(
      txnId: const Uuid().v4(),
      vendorId: vendorId,
      itemId: itemId,
      deltaQty: deltaQty,
      description: description,
      createdBy: createdBy,
    );
    return logTransaction(txn);
  }

  /// Get transactions for an item (for audit view)
  Future<List<StockTransaction>> getTransactionsForItem({
    required String vendorId,
    required String itemId,
    int limit = 50,
  }) async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('vendorId', isEqualTo: vendorId)
          .where('itemId', isEqualTo: itemId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => StockTransaction.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      ErrorHandler.handle(
        e,
        userMessage: 'Failed to get transactions for item',
      );
      return [];
    }
  }

  /// Get all transactions for a vendor (for reports)
  Future<List<StockTransaction>> getTransactionsForVendor({
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collectionName)
          .where('vendorId', isEqualTo: vendorId);

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: startDate.toIso8601String(),
        );
      }
      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: endDate.toIso8601String(),
        );
      }

      final result = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return result.docs
          .map((doc) => StockTransaction.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      ErrorHandler.handle(e, userMessage: 'Failed to get vendor transactions');
      return [];
    }
  }

  /// Watch recent transactions (for live audit view)
  Stream<List<StockTransaction>> watchRecentTransactions({
    required String vendorId,
    int limit = 20,
  }) {
    return _firestore
        .collection(_collectionName)
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => StockTransaction.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
