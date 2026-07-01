import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import 'package:drift/drift.dart';

import '../../../features/inventory/services/inventory_service.dart';

/// Purchase Order Workflow Service
/// Handles the lifecycle of Purchase Orders: PO -> GRN -> Purchase Bill
class PurchaseOrderService {
  final AppDatabase _db;
  final InventoryService? _inventoryService;

  PurchaseOrderService(this._db, {InventoryService? inventoryService}) 
    : _inventoryService = inventoryService;

  /// 1. Create a Draft or Issued PO
  Future<String> createPurchaseOrder({
    required String userId,
    required String vendorId,
    required String vendorName,
    required double totalAmount,
    required String notes,
    required List<Map<String, dynamic>> items, // Contains productId, qty, unitPrice
    String status = 'PENDING', // PENDING meaning "Issued to Vendor"
  }) async {
    final poId = const Uuid().v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.purchaseOrders).insert(
        PurchaseOrdersCompanion.insert(
          id: poId,
          userId: userId,
          vendorId: Value(vendorId),
          vendorName: Value(vendorName),
          purchaseDate: now,
          totalAmount: totalAmount,
          status: Value(status),
          notes: Value(notes),
          createdAt: now,
          updatedAt: now,
        )
      );

      // Insert Items
      for (final item in items) {
        final qty = (item['qty'] as num).toDouble();
        final unitPrice = (item['unitPrice'] as num).toDouble();
        await _db.into(_db.purchaseItems).insert(
          PurchaseItemsCompanion.insert(
            id: const Uuid().v4(),
            purchaseId: poId,
            productId: Value(item['productId'] as String?),
            productName: (item['productName'] as String?) ?? '',
            quantity: qty,
            costPrice: unitPrice,
            totalAmount: qty * unitPrice,
            createdAt: now,
          )
        );
      }
    });

    return poId;
  }

  /// 2. Receive Goods (GRN) and Convert to Completed Purchase Bill
  /// This updates stock logic and marks PO as COMPLETED
  Future<void> receiveGoodsAndCreateBill({
    required String userId,
    required String poId,
    required String invoiceNumber, // The vendor's bill number
    required double amountPaid,
    required String paymentMode,
  }) async {
    await _db.transaction(() async {
      // Fetch PO
      final po = await (_db.select(_db.purchaseOrders)..where((t) => t.id.equals(poId))).getSingleOrNull();
      if (po == null) throw Exception('Purchase Order not found');

      if (po.status == 'COMPLETED') {
        throw Exception('Purchase Order is already received/completed.');
      }

      final now = DateTime.now();

      // Update PO to status COMPLETED (Acting as Purchase Bill now)
      await (_db.update(_db.purchaseOrders)..where((t) => t.id.equals(poId))).write(
        PurchaseOrdersCompanion(
          status: const Value('COMPLETED'),
          invoiceNumber: Value(invoiceNumber),
          paidAmount: Value(amountPaid),
          paymentMode: Value(paymentMode),
          updatedAt: Value(now),
          isSynced: const Value(false)
        )
      );

      // Fetch Items to increase Stock
      final items = await (_db.select(_db.purchaseItems)..where((t) => t.purchaseId.equals(poId))).get();

      final inv = _inventoryService;
      if (inv != null) {
        for (final item in items) {
          final pid = item.productId;
          if (pid == null || pid.isEmpty) continue;
          await inv.addStockMovement(
            userId: userId,
            productId: pid,
            type: 'IN',
            reason: 'PURCHASE',
            quantity: item.quantity,
            referenceId: poId,
            description: 'PO Receipt $invoiceNumber',
            newCostPrice: item.costPrice,
            date: now,
          );
        }
      }

      // Update Vendor Balance (if credit purchase)
      final balanceToAdd = po.totalAmount - amountPaid;
      if (balanceToAdd > 0 && po.vendorId != null) {
        final vendorId = po.vendorId!;
        final vendor = await (_db.select(_db.vendors)..where((t) => t.id.equals(vendorId))).getSingleOrNull();
        if (vendor != null) {
          await (_db.update(_db.vendors)..where((t) => t.id.equals(vendorId))).write(
            VendorsCompanion(
              totalPurchased: Value(vendor.totalPurchased + po.totalAmount),
              totalPaid: Value(vendor.totalPaid + amountPaid),
              totalOutstanding: Value(vendor.totalOutstanding + balanceToAdd),
              updatedAt: Value(now),
              isSynced: const Value(false)
            )
          );
        }
      }
    });
  }

  /// 3. Cancel a PO
  Future<void> cancelPurchaseOrder(String poId) async {
    await (_db.update(_db.purchaseOrders)..where((t) => t.id.equals(poId))).write(
      PurchaseOrdersCompanion(
        status: const Value('CANCELLED'),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false)
      )
    );
  }
}
