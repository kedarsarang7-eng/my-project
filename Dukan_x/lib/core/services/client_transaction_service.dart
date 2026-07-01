import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
import '../../../models/bill.dart';
import '../../../models/payment.dart';

/// Service to handle atomic business transactions via API Gateway.
/// All operations go through API Gateway ? Lambda ? DynamoDB.
class ClientTransactionService {
  ApiClient get _api => sl<ApiClient>();

  /// ATOMIC: Create Sale ? Update Stock ? Update Balance ? Ledger
  /// Server handles atomicity via DynamoDB TransactWriteItems
  Future<void> createSaleTransaction(String userId, Bill bill) async {
    final saleData = bill.toMap();
    saleData['createdAt'] = DateTime.now().toUtc().toIso8601String();
    saleData['status'] = bill.paidAmount >= bill.grandTotal
        ? 'PAID'
        : (bill.paidAmount > 0 ? 'PARTIAL' : 'UNPAID');

    // Send full sale transaction to server — server handles:
    // 1. Stock reduction  2. Customer balance update  3. Ledger entry
    await _api.post('/api/v1/bills', body: {
      ...saleData,
      'customerId': bill.customerId,
      'grandTotal': bill.grandTotal,
      'paidAmount': bill.paidAmount,
      'items': bill.items.map((item) => {
        'itemName': item.itemName,
        'vegId': item.vegId,
        'qty': item.qty,
        'price': item.price,
        'total': item.total,
      }).toList(),
    });

    // If instant payment, record it separately
    if (bill.paidAmount > 0) {
      await _api.post('/api/v1/payments', body: {
        'customerId': bill.customerId,
        'amount': bill.paidAmount,
        'paymentMode': 'CASH',
        'linkedBillNumber': bill.invoiceNumber,
      });
    }
  }

  /// ATOMIC: Record Payment ? Update Balance ? Update Invoices ? Ledger
  /// Server handles atomicity
  Future<void> createPaymentTransaction(String userId, Payment payment) async {
    await _api.post('/api/v1/payments', body: {
      ...payment.toMap(),
      'customerId': payment.customerId,
      'amount': payment.amount,
      'method': payment.method,
    });
  }
}
