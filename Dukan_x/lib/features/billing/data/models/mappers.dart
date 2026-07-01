import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_item.dart';

import '../../../../models/bill.dart' as db; // Existing Model

// Bill Mapper
extension BillMapper on Bill {
  db.Bill toModel() {
    return db.Bill(
      id: id,
      customerId: '', // Handle if needed
      customerName: customerName ?? 'Unknown',
      customerPhone: customerPhone ?? '',
      date: date,
      items: items.map((e) => e.toModel()).toList(),
      subtotal: subtotal,
      totalTax: tax,
      grandTotal: totalAmount,
      discountApplied: discount,
      paymentType: paymentMethod,
      source: source.toString().split('.').last.toUpperCase(),
      status: 'Paid', // Default?
    );
  }
}

extension BillModelMapper on db.Bill {
  Bill toEntity() {
    return Bill(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      date: date,
      items: items.map((e) => e.toEntity()).toList(),
      subtotal: subtotal,
      tax: totalTax,
      discount: discountApplied,
      totalAmount: grandTotal,
      paymentMethod: paymentType,
      source: _parseSource(source),
    );
  }

  BillSource _parseSource(String source) {
    try {
      return BillSource.values.firstWhere(
        (e) => e.toString().split('.').last.toUpperCase() == source,
      );
    } catch (_) {
      return BillSource.manual;
    }
  }
}

// BillItem Mapper
extension BillItemMapper on BillItem {
  db.BillItem toModel() {
    return db.BillItem(
      productId: productId,
      productName: name,
      qty: quantity,
      price: rate,
      unit: unit,
      discount: discount,
      // Calculate totals if needed, model does it in constructor
    );
  }
}

extension BillItemModelMapper on db.BillItem {
  BillItem toEntity() {
    return BillItem(
      productId: productId,
      name: productName,
      quantity: qty,
      rate: price,
      amount: total,
      unit: unit,
      discount: discount,
      taxAmount: (cgst + sgst + igst),
    );
  }
}
