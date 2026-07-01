import 'package:dukanx/models/bill.dart' as model_bill;
import 'package:dukanx/features/billing/domain/entities/bill.dart'
    as domain_bill;
import 'package:dukanx/features/billing/domain/entities/bill_item.dart'
    as domain_item;
import 'package:dukanx/models/purchase_bill.dart' as purchase;
import '../../../core/repository/purchase_repository.dart';

class BillMapper {
  static model_bill.Bill toModel(domain_bill.Bill domainBill) {
    return model_bill.Bill(
      id: domainBill.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : domainBill.id,
      date: domainBill.date,
      customerId: '', // OCR doesn't know customer ID initially
      invoiceNumber: '', // Generated later
      items: domainBill.items.map((e) => toModelItem(e)).toList(),
      subtotal: domainBill.subtotal,
      grandTotal: domainBill
          .totalAmount, // Domain bill likely uses totalAmount as final
      shopName: domainBill.shopName ?? '',
      source: 'SCAN', // Explicitly mark as from scan
    );
  }

  static model_bill.BillItem toModelItem(domain_item.BillItem domainItem) {
    return model_bill.BillItem(
      productId: domainItem.productId.isEmpty
          ? domainItem.name.hashCode.toString()
          : domainItem.productId,
      productName: domainItem.name,
      qty: domainItem.quantity,
      price: domainItem.rate,
      unit: domainItem.unit,
    );
  }

  static purchase.PurchaseBill toPurchaseBill(
    domain_bill.Bill domainBill,
    String ownerId,
  ) {
    return purchase.PurchaseBill(
      id: '',
      billNumber: '',
      supplierId: '',
      supplierName: domainBill.shopName ?? '',
      date: domainBill.date,
      items: domainBill.items.map((e) => toPurchaseItem(e)).toList(),
      subtotal: domainBill.subtotal,
      grandTotal: domainBill.totalAmount,
      paidAmount: domainBill.totalAmount,
      status: 'Paid',
      paymentMode: 'Cash',
      ownerId: ownerId,
    );
  }

  static purchase.PurchaseBillItem toPurchaseItem(
    domain_item.BillItem domainItem,
  ) {
    return purchase.PurchaseBillItem(
      itemId: domainItem.productId,
      itemName: domainItem.name,
      qty: domainItem.quantity,
      rate: domainItem.rate,
      total: domainItem.amount,
      unit: domainItem.unit,
    );
  }

  static PurchaseOrder toPurchaseOrder(
    domain_bill.Bill domainBill,
    String ownerId,
  ) {
    return PurchaseOrder(
      id: '',
      userId: ownerId,
      vendorName: domainBill.shopName ?? 'Unknown Vendor',
      invoiceNumber: '',
      purchaseDate: domainBill.date,
      items: domainBill.items.map((e) => toPurchaseOrderItem(e)).toList(),
      totalAmount: domainBill.totalAmount,
      paidAmount: 0,
      status: 'PENDING',
      paymentMode: 'Credit',
      createdAt: DateTime.now(),
      // updatedAt: DateTime.now(), // Not in constructor
    );
  }

  static PurchaseItem toPurchaseOrderItem(domain_item.BillItem domainItem) {
    return PurchaseItem(
      id: '', // Generated later
      productId: domainItem.productId,
      productName: domainItem.name,
      quantity: domainItem.quantity,
      costPrice: domainItem.rate,
      totalAmount: domainItem.amount,
      unit: domainItem.unit,
    );
  }
}
