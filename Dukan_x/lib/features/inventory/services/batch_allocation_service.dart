import '../../../models/bill.dart';
import '../data/product_batch_repository.dart';

/// Service responsible for allocating stock from batches based on FEFO logic.
class BatchAllocationService {
  final ProductBatchRepository productBatchRepository;

  BatchAllocationService({required this.productBatchRepository});

  /// Allocate batches for FEFO (First Expire First Out)
  /// Splits bill items if multiple batches are needed to fulfill quantity
  Future<Bill> allocateBatches(Bill bill) async {
    // Only process for pharmacy-related businesses if needed,
    // but the caller usually decides when to call this.
    // We'll process whatever bill is passed.

    final newItems = <BillItem>[];

    for (final item in bill.items) {
      // Skip if:
      // - Already has batch ID (Manual selection)
      // - Product ID is empty (Custom item)
      // - Quantity is zero
      if (item.batchId != null || item.productId.isEmpty || item.qty <= 0) {
        newItems.add(item);
        continue;
      }

      // Get valid batches sorted by FEFO (Expiry ASC, Created ASC)
      final batches = await productBatchRepository.getBatchesForFefo(
        item.productId,
      );

      // If no batches found, we can't allocate. Keep original item.
      if (batches.isEmpty) {
        newItems.add(item);
        continue;
      }

      double remainingQty = item.qty;

      for (final batch in batches) {
        if (remainingQty <= 0) break;
        if (batch.stockQuantity <= 0) continue; // Skip empty batches

        final qtyToTake = (remainingQty > batch.stockQuantity)
            ? batch.stockQuantity
            : remainingQty;

        // Calculate pro-rated data
        final ratio = qtyToTake / item.qty;
        final newDiscount = item.discount * ratio;

        final newItem = item.copyWith(
          qty: qtyToTake,
          discount: newDiscount,
          batchId: batch.id,
          batchNo: batch.batchNumber,
          expiryDate: batch.expiryDate,
          cgst: item.cgst * ratio,
          sgst: item.sgst * ratio,
          igst: item.igst * ratio,
        );

        newItems.add(newItem);
        remainingQty -= qtyToTake;
      }

      // If we couldn't fulfill the entire quantity from batches
      if (remainingQty > 0.001) {
        // Create a remainder item without batch
        final ratio = remainingQty / item.qty;
        final remainderItem = item.copyWith(
          qty: remainingQty,
          discount: item.discount * ratio,
          cgst: item.cgst * ratio,
          sgst: item.sgst * ratio,
          igst: item.igst * ratio,
        );
        newItems.add(remainderItem);
      }
    }

    // Recalculate bill totals just to be safe (rounding errors in split)
    // Assuming Bill has a method to recalculate or we trust the sum of items?
    // The Bill model doesn't have a 'recalculate' method visible in previous view,
    // but the repository had a helper `_recalculateBillTotals`.
    // Since we are in a service, we should probably do a basic recalculation or rely on Bill constructor?
    // The Bill constructor calculates grandTotal? No, it takes it as arg.

    // Let's implement a safe recalculation here or use Bill.sanitized()?
    // Bill.sanitized() creates safety but doesn't sum totals.
    // Let's replicate the summation logic.

    // Recalculate bill totals
    double newSubtotal = 0;
    double newTax = 0;
    double newDiscount = 0;

    for (var i in newItems) {
      newSubtotal += i.total;
      newTax += i.taxAmount;
      newDiscount += i.discount;
    }

    return bill
        .copyWith(
          items: newItems,
          subtotal: newSubtotal,
          totalTax: newTax,
          discountApplied: newDiscount,
          grandTotal: newSubtotal + newTax,
        )
        .sanitized();
  }
}
