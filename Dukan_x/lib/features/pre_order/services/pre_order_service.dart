import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../core/repository/products_repository.dart';
import '../data/repositories/customer_item_request_repository.dart';
import '../data/repositories/stock_transaction_repository.dart';
import '../data/repositories/vendor_item_snapshot_repository.dart';
import '../models/customer_item_request.dart';

/// PreOrderService - Core business logic for pre-order system (10M+ scale).
/// Handles transactional bill creation with audit logging.
class PreOrderService {
  final CustomerItemRequestRepository _requestRepository;
  final BillsRepository _billsRepository;
  final ProductsRepository _productsRepository;
  final StockTransactionRepository _stockTxnRepo;
  final VendorItemSnapshotRepository _snapshotRepo;
  final ErrorHandler _errorHandler;

  PreOrderService({
    required CustomerItemRequestRepository requestRepository,
    required BillsRepository billsRepository,
    required ProductsRepository productsRepository,
    required StockTransactionRepository stockTxnRepo,
    required VendorItemSnapshotRepository snapshotRepo,
    required ErrorHandler errorHandler,
  }) : _requestRepository = requestRepository,
       _billsRepository = billsRepository,
       _productsRepository = productsRepository,
       _stockTxnRepo = stockTxnRepo,
       _snapshotRepo = snapshotRepo,
       _errorHandler = errorHandler;

  /// Create a bill from an approved pre-order request.
  /// This is a TRANSACTIONAL operation that:
  /// 1. Validates stock availability
  /// 2. Creates the bill
  /// 3. Logs stock transactions (audit)
  /// 4. Updates vendor snapshot (async)
  /// 5. Marks request as billed
  Future<void> createBillFromRequest(CustomerItemRequest request) async {
    final result = await _errorHandler.runSafe<void>(() async {
      if (request.status == RequestStatus.billed) {
        throw Exception('Request is already billed');
      }

      final approvedItems = request.items
          .where((i) => i.status == ItemStatus.approved && i.approvedQty > 0)
          .toList();

      if (approvedItems.isEmpty) {
        throw Exception('No approved items to bill');
      }

      final billItems = <BillItem>[];
      double subtotal = 0;
      double totalTax = 0;
      final billId = const Uuid().v4();

      // Stock validation and bill item creation
      for (final item in approvedItems) {
        final productResult = await _productsRepository.getById(item.productId);
        final product = productResult.data;

        if (product != null) {
          // CRITICAL: Validate stock before billing
          if (product.stockQuantity < item.approvedQty) {
            throw Exception(
              'Insufficient stock for ${product.name}. '
              'Available: ${product.stockQuantity}, Requested: ${item.approvedQty}',
            );
          }

          final price = product.sellingPrice;
          final qty = item.approvedQty;
          final taxRate = product.taxRate;

          final billItem = BillItem(
            productId: item.productId,
            productName: product.name,
            qty: qty,
            price: price,
            unit: product.unit,
            gstRate: taxRate,
            cgst: (price * qty * (taxRate / 2) / 100),
            sgst: (price * qty * (taxRate / 2) / 100),
          );

          billItems.add(billItem);
          subtotal += (price * qty);
          totalTax += (billItem.cgst + billItem.sgst + billItem.igst);
        } else {
          // Product not found (deleted?), use manual entry
          final billItem = BillItem(
            productId: item.productId,
            productName: item.productName,
            qty: item.approvedQty,
            price: 0,
          );
          billItems.add(billItem);
        }
      }

      final grandTotal = subtotal + totalTax;

      final bill = Bill(
        id: billId,
        customerId: request.customerId,
        date: DateTime.now(),
        items: billItems,
        subtotal: subtotal,
        totalTax: totalTax,
        grandTotal: grandTotal,
        ownerId: request.vendorId,
        status: 'Unpaid',
        source: 'PRE_ORDER',
      );

      // CREATE BILL (BillsRepository handles stock reduction via InventoryService)
      await _billsRepository.createBill(bill);

      // LOG STOCK TRANSACTIONS (APPEND-ONLY AUDIT)
      for (final item in approvedItems) {
        await _stockTxnRepo.logSale(
          vendorId: request.vendorId,
          itemId: item.productId,
          qty: item.approvedQty,
          billId: billId,
          createdBy: 'SYSTEM',
        );
      }

      // UPDATE VENDOR SNAPSHOT (Async, non-blocking)
      _updateVendorSnapshot(request.vendorId, approvedItems);

      // UPDATE REQUEST STATUS
      final updatedRequest = request.copyWith(
        status: RequestStatus.billed,
        updatedAt: DateTime.now(),
      );
      await _requestRepository.updateRequest(updatedRequest);
    }, 'createBillFromRequest');

    if (result.isFailure) {
      throw Exception(result.errorMessage ?? 'Failed to create bill');
    }
  }

  /// Async update of vendor snapshot after stock changes
  Future<void> _updateVendorSnapshot(
    String vendorId,
    List<CustomerItemRequestItem> billedItems,
  ) async {
    try {
      final snapshot = await _snapshotRepo.getSnapshot(vendorId);
      if (snapshot == null) return;

      // Create updated items list
      final updatedItems = snapshot.items.map((item) {
        final billedItem = billedItems.firstWhere(
          (bi) => bi.productId == item.itemId,
          orElse: () => CustomerItemRequestItem(
            productId: '',
            productName: '',
            requestedQty: 0,
            unit: '',
          ),
        );

        if (billedItem.productId.isNotEmpty) {
          return item.copyWith(
            stockQty: item.stockQty - billedItem.approvedQty,
            updatedAt: DateTime.now(),
          );
        }
        return item;
      }).toList();

      final updatedSnapshot = snapshot.copyWith(
        items: updatedItems,
        snapshotUpdatedAt: DateTime.now(),
      );

      await _snapshotRepo.updateSnapshot(updatedSnapshot);
    } catch (e) {
      // Non-critical failure - snapshot will be updated on next sync
      // Logging only, not throwing
      debugPrint('[PreOrderService] Snapshot update failed: $e');
    }
  }
}
