import '../core/data/data_guard.dart';

class SubscriptionItem {
  String id;
  String subscriptionId;
  String? productId;
  String productName;
  double quantity;
  String unit;
  double unitPrice;
  double taxRate;
  double taxAmount;
  double discountAmount;
  double totalAmount;
  int sortOrder;
  DateTime createdAt;

  SubscriptionItem({
    required this.id,
    required this.subscriptionId,
    this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'subscriptionId': subscriptionId,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'taxRate': taxRate,
    'taxAmount': taxAmount,
    'discountAmount': discountAmount,
    'totalAmount': totalAmount,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SubscriptionItem.fromMap(Map<String, dynamic> m) {
    return SubscriptionItem(
      id: DataGuard.safeString(m['id']),
      subscriptionId: DataGuard.safeString(m['subscriptionId']),
      productId: m['productId']?.toString(),
      productName: DataGuard.safeString(m['productName']),
      quantity: DataGuard.safeDouble(m['quantity']),
      unit: DataGuard.safeString(m['unit'], fallback: 'pcs'),
      unitPrice: DataGuard.safeDouble(m['unitPrice']),
      taxRate: DataGuard.safeDouble(m['taxRate']),
      taxAmount: DataGuard.safeDouble(m['taxAmount']),
      discountAmount: DataGuard.safeDouble(m['discountAmount']),
      totalAmount: DataGuard.safeDouble(m['totalAmount']),
      sortOrder: DataGuard.safeInt(m['sortOrder']),
      createdAt: DataGuard.safeDate(m['createdAt']) ?? DateTime.now(),
    );
  }
}
