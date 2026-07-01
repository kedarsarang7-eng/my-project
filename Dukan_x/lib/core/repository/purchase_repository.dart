// ============================================================================
// PURCHASE REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages purchase orders and inward stock with Drift persistence
//
// Author: DukanX Engineering
// Version: 2.1.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';
import '../../features/inventory/services/inventory_service.dart';
import '../../features/inventory/data/product_batch_repository.dart';
import '../../services/purchase_accounting_service.dart';
import '../../services/accounting_engine.dart';
import '../../services/daybook_service.dart';
import 'bank_repository.dart';
import '../../features/accounting/services/accounting_service.dart';

/// Purchase Order model for UI
class PurchaseOrder {
  final String id;
  final String userId;
  final String? vendorId;
  final String? vendorName;
  final String? invoiceNumber;
  final DateTime purchaseDate;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final String? paymentMode;
  final String? notes;
  final List<PurchaseItem> items;
  final bool isSynced;
  final DateTime createdAt;

  PurchaseOrder({
    required this.id,
    required this.userId,
    this.vendorId,
    this.vendorName,
    this.invoiceNumber,
    required this.purchaseDate,
    required this.totalAmount,
    this.paidAmount = 0,
    this.status = 'COMPLETED',
    this.paymentMode,
    this.notes,
    this.items = const [],
    this.isSynced = false,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'vendorId': vendorId,
    'vendorName': vendorName,
    'invoiceNumber': invoiceNumber,
    'purchaseDate': purchaseDate.toIso8601String(),
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'status': status,
    'paymentMode': paymentMode,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((i) => i.toFirestoreMap()).toList(),
  };
}

/// Purchase Item model for UI
class PurchaseItem {
  final String id;
  final String? productId;
  final String productName;
  final double quantity;
  final String unit;
  final double costPrice;
  final double taxRate;
  final double totalAmount;

  // Pharmacy / Batch Info
  final String? batchNumber;
  final DateTime? expiryDate;

  PurchaseItem({
    required this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'pcs',
    required this.costPrice,
    this.taxRate = 0,
    required this.totalAmount,
    this.batchNumber,
    this.expiryDate,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'costPrice': costPrice,
    'taxRate': taxRate,
    'totalAmount': totalAmount,
    'batchNumber': batchNumber,
    'expiryDate': expiryDate?.toIso8601String(),
  };
}

/// Purchase Repository
class PurchaseRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  final InventoryService? inventoryService;
  final ProductBatchRepository? productBatchRepository;

  // GAP-1 PATCH: Optional accounting integration (non-breaking)
  final PurchaseAccountingService? purchaseAccountingService;
  final AccountingEngine? accountingEngine;

  // AUDIT FIX: Optional DayBook and bank integration for proper reversals
  final DayBookService? dayBookService;
  final BankRepository? bankRepository;
  final AccountingService? accountingService;

  PurchaseRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
    this.inventoryService,
    this.productBatchRepository,
    this.purchaseAccountingService,
    this.accountingEngine,
    this.dayBookService,
    this.bankRepository,
    this.accountingService,
  });

  String get collectionName => 'purchaseOrders';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Create a purchase order
  Future<RepositoryResult<PurchaseOrder>> createPurchaseOrder({
    required String userId,
    String? vendorId,
    String? vendorName,
    String? invoiceNumber,
    required double totalAmount,
    double paidAmount = 0,
    String status = 'COMPLETED',
    String? paymentMode,
    String? notes,
    required List<PurchaseItem> items,
  }) async {
    return await errorHandler.runSafe<PurchaseOrder>(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();

      await database.transaction(() async {
        // 1. Insert Purchase Order
        await database
            .into(database.purchaseOrders)
            .insert(
              PurchaseOrdersCompanion.insert(
                id: id,
                userId: userId,
                vendorId: Value(vendorId),
                vendorName: Value(vendorName),
                invoiceNumber: Value(invoiceNumber),
                purchaseDate: now,
                totalAmount: totalAmount,
                paidAmount: Value(paidAmount),
                status: Value(status),
                paymentMode: Value(paymentMode),
                notes: Value(notes),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 2. Insert Items and Update Stock
        for (final item in items) {
          final itemId = const Uuid().v4();

          await database
              .into(database.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  id: itemId,
                  purchaseId: id,
                  productId: Value(item.productId),
                  productName: item.productName,
                  quantity: item.quantity,
                  unit: Value(item.unit),
                  costPrice: item.costPrice,
                  taxRate: Value(item.taxRate),
                  totalAmount: item.totalAmount,
                  batchNumber: Value(item.batchNumber),
                  expiryDate: Value(item.expiryDate),
                  createdAt: now,
                ),
              );

          // 3. Update Inventory if product exists and order is COMPLETED
          if (item.productId != null &&
              status == 'COMPLETED' &&
              inventoryService != null) {
            // Handle Batch Logic (Pharmacy Compliance)
            String? batchId;
            if (item.batchNumber != null && productBatchRepository != null) {
              // Check if batch exists
              final existingBatch = await productBatchRepository!
                  .getBatchByNumber(item.productId!, item.batchNumber!);

              if (existingBatch != null) {
                batchId = existingBatch.id;
              } else {
                // Create new batch
                batchId = const Uuid().v4();
                await productBatchRepository!.createBatch(
                  ProductBatchesCompanion(
                    id: Value(batchId),
                    productId: Value(item.productId!),
                    userId: Value(userId),
                    batchNumber: Value(item.batchNumber!),
                    expiryDate: Value(item.expiryDate),
                    stockQuantity: const Value(
                      0,
                    ), // Will be increased by addStockMovement
                    openingQuantity: const Value(0),
                    purchaseRate: Value(item.costPrice),
                    sellingRate: Value(
                      0.0,
                    ), // Unknown here, kept 0 or fetch product price?
                    status: const Value('ACTIVE'),
                    createdAt: Value(now),
                    updatedAt: Value(now),
                    isSynced: const Value(false),
                  ),
                );
              }
            }

            await inventoryService!.addStockMovement(
              userId: userId,
              productId: item.productId!,
              type: 'IN',
              reason: 'PURCHASE',
              quantity: item.quantity,
              referenceId: id,
              date: now,
              description: 'Purchase Order: $invoiceNumber',
              newCostPrice: item.costPrice,
              createdBy: 'SYSTEM',
              batchId: batchId,
              batchNumber: item.batchNumber,
            );
          }
        }

        // 4. Update Vendor Ledger (Critical Fix)
        if (vendorId != null) {
          final vendor = await (database.select(
            database.vendors,
          )..where((t) => t.id.equals(vendorId))).getSingleOrNull();

          if (vendor != null) {
            final newTotalPurchased = vendor.totalPurchased + totalAmount;
            final newTotalOutstanding =
                vendor.totalOutstanding + (totalAmount - paidAmount);

            await (database.update(
              database.vendors,
            )..where((t) => t.id.equals(vendorId))).write(
              VendorsCompanion(
                totalPurchased: Value(newTotalPurchased),
                totalOutstanding: Value(newTotalOutstanding),
                updatedAt: Value(now),
                isSynced: const Value(false),
              ),
            );

            // Queue vendor sync
            await syncManager.enqueue(
              SyncQueueItem.create(
                userId: userId,
                operationType: SyncOperationType.update,
                targetCollection: 'vendors',
                documentId: vendorId,
                payload: {
                  'totalPurchased': newTotalPurchased,
                  'totalOutstanding': newTotalOutstanding,
                  'updatedAt': now.toIso8601String(),
                },
              ),
            );
          }
        }
      });

      final order = PurchaseOrder(
        id: id,
        userId: userId,
        vendorId: vendorId,
        vendorName: vendorName,
        invoiceNumber: invoiceNumber,
        purchaseDate: now,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        status: status,
        paymentMode: paymentMode,
        notes: notes,
        items: items,
        createdAt: now,
      );

      // 5. Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.create,
          targetCollection: collectionName,
          documentId: id,
          payload: order.toFirestoreMap(),
        ),
      );

      // ============================================================
      // GAP-1 PATCH: Double-Entry Accounting (Fire-and-Forget)
      // ============================================================
      // This creates proper ledger entries for the purchase:
      // DR: Inventory/Expense (asset increases OR expense recorded)
      // CR: Accounts Payable / Cash (liability increases OR cash decreases)
      //
      // CRITICAL: Wrapped in try/catch - accounting failure MUST NOT
      // fail the purchase creation. Existing flow remains unchanged.
      // ============================================================
      if (accountingEngine != null && status == 'COMPLETED') {
        try {
          // Calculate GST breakdown from items if available
          double cgst = 0, sgst = 0, igst = 0;
          for (final item in items) {
            // Simplified: assume taxRate is total GST %, split 50/50 for CGST/SGST
            final itemTax =
                item.totalAmount *
                (item.taxRate / 100) /
                (1 + item.taxRate / 100);
            cgst += itemTax / 2;
            sgst += itemTax / 2;
          }

          // Post purchase transaction directly via AccountingEngine
          await accountingEngine!.postPurchase(
            purchaseId: id,
            businessId: userId,
            vendorId: vendorId,
            vendorName: vendorName ?? 'Cash Purchase',
            invoiceNumber: invoiceNumber ?? id,
            invoiceDate: now,
            subtotal: totalAmount - (cgst + sgst + igst),
            cgst: cgst,
            sgst: sgst,
            igst: igst,
            grandTotal: totalAmount,
            paidAmount: paidAmount,
          );
          debugPrint('[ACCOUNTING] Purchase ledger entry posted: $id');
        } catch (e) {
          // Log but DO NOT fail the purchase creation
          debugPrint('[ACCOUNTING WARNING] Failed to post purchase ledger: $e');
          // Optionally: Queue for retry or audit logging
        }
      }

      return order;
    }, 'createPurchaseOrder');
  }

  /// Update a purchase order
  Future<RepositoryResult<PurchaseOrder>> updatePurchaseOrder({
    required String id,
    required String userId,
    String? vendorId,
    String? vendorName,
    String? invoiceNumber,
    required double totalAmount,
    double paidAmount = 0,
    String? paymentMode,
    String? notes,
    required List<PurchaseItem> items,
  }) async {
    return await errorHandler.runSafe<PurchaseOrder>(() async {
      final now = DateTime.now();

      await database.transaction(() async {
        // 1. Update Purchase Order
        await (database.update(
          database.purchaseOrders,
        )..where((t) => t.id.equals(id))).write(
          PurchaseOrdersCompanion(
            vendorId: Value(vendorId),
            vendorName: Value(vendorName),
            invoiceNumber: Value(invoiceNumber),
            totalAmount: Value(totalAmount),
            paidAmount: Value(paidAmount),
            paymentMode: Value(paymentMode),
            notes: Value(notes),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

        // 2. Refresh Items (Delete and Re-insert is simplest for nested items)
        await (database.delete(
          database.purchaseItems,
        )..where((t) => t.purchaseId.equals(id))).go();

        for (final item in items) {
          final itemId = const Uuid().v4();
          await database
              .into(database.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  id: itemId,
                  purchaseId: id,
                  productId: Value(item.productId),
                  productName: item.productName,
                  quantity: item.quantity,
                  unit: Value(item.unit),
                  costPrice: item.costPrice,
                  taxRate: Value(item.taxRate),
                  totalAmount: item.totalAmount,
                  batchNumber: Value(item.batchNumber),
                  expiryDate: Value(item.expiryDate),
                  createdAt: now,
                ),
              );
        }
      });

      final order = PurchaseOrder(
        id: id,
        userId: userId,
        vendorId: vendorId,
        vendorName: vendorName,
        invoiceNumber: invoiceNumber,
        purchaseDate:
            now, // Keeping original or updating? Usually keep original but repository model might vary
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        paymentMode: paymentMode,
        notes: notes,
        items: items,
        createdAt: now, // Should fetch from DB if we want true original
      );

      // 3. Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: id,
          payload: order.toFirestoreMap(),
        ),
      );

      return order;
    }, 'updatePurchaseOrder');
  }

  /// Complete a pending purchase order and update inventory
  Future<RepositoryResult<bool>> completePurchaseOrder({
    required String id,
    required String userId,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();

      await database.transaction(() async {
        // 1. Get the order and items
        final results = await (database.select(
          database.purchaseOrders,
        )..where((t) => t.id.equals(id))).get();
        if (results.isEmpty) throw Exception('Order not found');
        final order = results.first;

        if (order.status == 'COMPLETED') return; // Already completed

        final items = await (database.select(
          database.purchaseItems,
        )..where((t) => t.purchaseId.equals(id))).get();

        // 2. Update status to COMPLETED
        await (database.update(
          database.purchaseOrders,
        )..where((t) => t.id.equals(id))).write(
          PurchaseOrdersCompanion(
            status: const Value('COMPLETED'),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

        // 3. Update Inventory for each item
        if (inventoryService != null) {
          for (final item in items) {
            if (item.productId != null) {
              await inventoryService!.addStockMovement(
                userId: userId,
                productId: item.productId!,
                type: 'IN',
                reason: 'PURCHASE',
                quantity: item.quantity,
                referenceId: id,
                date: now,
                description:
                    'Purchase Order Completed: ${order.invoiceNumber ?? id}',
                newCostPrice: item.costPrice,
                createdBy: 'SYSTEM',
              );
            }
          }
        }
      });

      // 4. Queue order update for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: id,
          payload: {'status': 'COMPLETED', 'updatedAt': now.toIso8601String()},
        ),
      );

      return true;
    }, 'completePurchaseOrder');
  }

  /// Delete a purchase order with STOCK REVERSAL
  ///
  /// CRITICAL FIX: This method now:
  /// 1. REVERSES STOCK for all items if order was COMPLETED
  /// 2. Reverses vendor ledger if applicable
  /// 3. Soft deletes the order for audit trail
  Future<RepositoryResult<bool>> deletePurchaseOrder({
    required String id,
    required String userId,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();

      await database.transaction(() async {
        // 1. Fetch the purchase order
        final order = await (database.select(
          database.purchaseOrders,
        )..where((t) => t.id.equals(id))).getSingleOrNull();

        if (order == null) {
          throw Exception('Purchase order not found: $id');
        }

        // 2. Fetch all items for this order
        final items = await (database.select(
          database.purchaseItems,
        )..where((t) => t.purchaseId.equals(id))).get();

        // 3. STOCK REVERSAL - Only if order was COMPLETED (stock was added)
        if (order.status == 'COMPLETED' && inventoryService != null) {
          for (final item in items) {
            if (item.productId != null && item.quantity > 0) {
              // Reverse the stock - remove what was added by purchase
              await inventoryService!.addStockMovement(
                userId: userId,
                productId: item.productId!,
                type: 'OUT',
                reason: 'PURCHASE_DELETE_REVERSAL',
                quantity: item.quantity,
                referenceId: id,
                description:
                    'Stock reversed due to purchase deletion: ${order.invoiceNumber ?? id}',
                createdBy: 'SYSTEM',
              );
            }
          }
        }

        // 4. Reverse vendor ledger if applicable
        if (order.vendorId != null) {
          final vendor = await (database.select(
            database.vendors,
          )..where((t) => t.id.equals(order.vendorId!))).getSingleOrNull();

          if (vendor != null) {
            // Reverse: totalPurchased decreases, totalOutstanding decreases
            final reversedTotalPurchased =
                (vendor.totalPurchased - order.totalAmount).clamp(
                  0.0,
                  double.infinity,
                );
            final reversedTotalOutstanding =
                (vendor.totalOutstanding -
                        (order.totalAmount - order.paidAmount))
                    .clamp(0.0, double.infinity);

            await (database.update(
              database.vendors,
            )..where((t) => t.id.equals(order.vendorId!))).write(
              VendorsCompanion(
                totalPurchased: Value(reversedTotalPurchased),
                totalOutstanding: Value(reversedTotalOutstanding),
                updatedAt: Value(now),
                isSynced: const Value(false),
              ),
            );

            // Queue vendor sync
            await syncManager.enqueue(
              SyncQueueItem.create(
                userId: userId,
                operationType: SyncOperationType.update,
                targetCollection: 'vendors',
                documentId: order.vendorId!,
                payload: {
                  'totalPurchased': reversedTotalPurchased,
                  'totalOutstanding': reversedTotalOutstanding,
                  'updatedAt': now.toIso8601String(),
                },
              ),
            );
          }
        }

        // 5. Soft delete the purchase order
        await (database.update(
          database.purchaseOrders,
        )..where((t) => t.id.equals(id))).write(
          PurchaseOrdersCompanion(
            deletedAt: Value(now),
            isSynced: const Value(false),
            updatedAt: Value(now),
          ),
        );
      });

      // ================================================================
      // AUDIT FIX: Reverse DayBook entry for purchase deletion
      // ================================================================
      // This ensures DayBook totals remain accurate after deletion.
      // Fire-and-forget: failure here should not fail the deletion.
      // ================================================================
      if (dayBookService != null) {
        try {
          final order = await (database.select(
            database.purchaseOrders,
          )..where((t) => t.id.equals(id))).getSingleOrNull();

          if (order != null) {
            final wasCashPurchase =
                order.paymentMode?.toUpperCase() == 'CASH' ||
                order.paidAmount >= order.totalAmount;

            await dayBookService!.reversePurchaseRealtime(
              businessId: userId,
              purchaseDate: order.purchaseDate,
              amount: order.totalAmount,
              wasCashPurchase: wasCashPurchase,
            );
            debugPrint('[DAYBOOK] Purchase reversal recorded for: $id');
          }
        } catch (e) {
          // Log but DO NOT fail the deletion
          debugPrint('[DAYBOOK WARNING] Failed to reverse DayBook entry: $e');
        }
      }

      // ================================================================
      // AUDIT FIX: Reverse bank transaction if paid via bank
      // ================================================================
      if (bankRepository != null) {
        try {
          final order = await (database.select(
            database.purchaseOrders,
          )..where((t) => t.id.equals(id))).getSingleOrNull();

          if (order != null && order.paidAmount > 0) {
            // Get primary account for reversal
            final accounts = await bankRepository!.getAccounts(userId: userId);
            final primaryAccount = accounts.data?.firstWhere(
              (a) => a.isPrimary,
              orElse: () => accounts.data!.first,
            );

            if (primaryAccount != null) {
              // Create a credit entry to reverse the original debit
              await bankRepository!.recordTransaction(
                userId: userId,
                accountId: primaryAccount.id,
                amount: order.paidAmount,
                type: 'CREDIT',
                category: 'PURCHASE_REVERSAL',
                referenceId: id,
                description:
                    'Reversed: Purchase ${order.invoiceNumber ?? id} deleted',
                date: now,
              );
              debugPrint('[BANK] Purchase payment reversal recorded for: $id');
            }
          }
        } catch (e) {
          // Log but DO NOT fail the deletion
          debugPrint('[BANK WARNING] Failed to reverse bank transaction: $e');
        }
      }

      // Quote sync for the deleted purchase order
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.delete,
          targetCollection: collectionName,
          documentId: id,
          payload: {'deletedAt': now.toIso8601String()},
        ),
      );

      // ================================================================
      // AUDIT FIX: Reverse Ledger Entry (Acid Compliant)
      // ================================================================
      if (accountingService != null) {
        await accountingService!.reverseTransaction(
          userId: userId,
          sourceType: 'PURCHASEORDER',
          sourceId: id,
          reason: 'Purchase Order Deleted',
          reversalDate: now,
        );
      }

      return true;
    }, 'deletePurchaseOrder');
  }

  /// Get all purchase orders
  Future<RepositoryResult<List<PurchaseOrder>>> getAll({
    required String userId,
  }) async {
    return await errorHandler.runSafe<List<PurchaseOrder>>(() async {
      final results =
          await (database.select(database.purchaseOrders)
                ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.desc(t.purchaseDate)]))
              .get();

      final orders = <PurchaseOrder>[];
      for (final r in results) {
        final items = await (database.select(
          database.purchaseItems,
        )..where((t) => t.purchaseId.equals(r.id))).get();

        orders.add(_entityToOrder(r, items));
      }
      return orders;
    }, 'getAll');
  }

  /// Watch purchase orders
  Stream<List<PurchaseOrder>> watchAll({required String userId}) {
    return (database.select(database.purchaseOrders)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.purchaseDate)]))
        .watch()
        .asyncMap((rows) async {
          final orders = <PurchaseOrder>[];
          for (final r in rows) {
            final items = await (database.select(
              database.purchaseItems,
            )..where((t) => t.purchaseId.equals(r.id))).get();
            orders.add(_entityToOrder(r, items));
          }
          return orders;
        });
  }

  // ============================================
  // HELPERS
  // ============================================

  PurchaseOrder _entityToOrder(
    PurchaseOrderEntity e,
    List<PurchaseItemEntity> items,
  ) => PurchaseOrder(
    id: e.id,
    userId: e.userId,
    vendorId: e.vendorId,
    vendorName: e.vendorName,
    invoiceNumber: e.invoiceNumber,
    purchaseDate: e.purchaseDate,
    totalAmount: e.totalAmount,
    paidAmount: e.paidAmount,
    status: e.status,
    paymentMode: e.paymentMode,
    notes: e.notes,
    items: items
        .map(
          (i) => PurchaseItem(
            id: i.id,
            productId: i.productId,
            productName: i.productName,
            quantity: i.quantity,
            unit: i.unit,
            costPrice: i.costPrice,
            taxRate: i.taxRate,
            totalAmount: i.totalAmount,
            batchNumber: i.batchNumber,
            expiryDate: i.expiryDate,
          ),
        )
        .toList(),
    isSynced: e.isSynced,
    createdAt: e.createdAt,
  );
}
