import 'package:uuid/uuid.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';

class ReturnExchangeService {
  final BillsRepository billsRepository;
  final ProductsRepository productsRepository;
  final SessionManager sessionManager;

  ReturnExchangeService({
    required this.billsRepository,
    required this.productsRepository,
    required this.sessionManager,
  });

  /// Process a return for specific items in a bill
  /// Returns the ID of the generated Credit Note or Refund Bill
  Future<String> processReturn({
    required Bill originalBill,
    required List<BillItem> returnedItems,
    required String reason,
    required bool restockItems,
    String? newBillId, // If exchange, link to new bill
  }) async {
    final userId = sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    // 1. Validate Return
    if (returnedItems.isEmpty) throw Exception('No items to return');

    // 2. Calculate Refund Totals
    double refundSubtotal = 0;
    double refundTax = 0;
    double refundTotal = 0;

    for (var item in returnedItems) {
      refundSubtotal += item.totalAmount - item.taxAmount;
      refundTax += item.taxAmount;
      refundTotal += item.totalAmount;
    }

    // 3. Create Return Record (Negative Bill or specific Return Entity)
    // For now, we create a Credit Note (conceptual) represented as a negative Bill
    // or a "Return" status bill.
    // Ideally, we should have a `CreditNote` entity, but reusing Bill with type 'Return'
    // is a common pattern in simple apps.
    // Let's assume we use a "Return" bill type or note.

    final returnBillId = const Uuid().v4();
    final returnBill = Bill(
      id: returnBillId,
      invoiceNumber: 'RET-${originalBill.invoiceNumber}',
      customerId: originalBill.customerId,
      customerName: originalBill.customerName,
      customerPhone: originalBill.customerPhone,
      date: DateTime.now(),
      items: returnedItems,
      subtotal: -refundSubtotal, // Negative for return
      totalTax: -refundTax,
      grandTotal: -refundTotal,
      paidAmount: -refundTotal, // Refunded
      status: 'Returned',
      paymentType: 'Cash', // Or original payment mode
      ownerId: userId,
      source: 'RETURN',
      businessType: originalBill.businessType,
    );

    await billsRepository.createBill(returnBill);

    // 4. Update Stock (Restock)
    if (restockItems) {
      for (var item in returnedItems) {
        await productsRepository.adjustStock(
          productId: item.productId,
          quantity: item.qty, // Add back quantity
          userId: userId,
        );
      }
    }

    return returnBillId;
  }
}
