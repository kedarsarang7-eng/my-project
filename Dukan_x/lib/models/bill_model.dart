import 'package:dukanx/core/compat/firestore_compat.dart';

class BillModel {
  final String id;
  final String ownerId;
  final String customerId;
  final double totalAmount;
  final List<Map<String, dynamic>>
  items; // list of {vegId, name, qtyKg, pricePerKg, amount}
  final DateTime createdAt;
  final bool paid;

  BillModel({
    required this.id,
    required this.ownerId,
    required this.customerId,
    required this.totalAmount,
    required this.items,
    required this.createdAt,
    this.paid = false,
  });

  factory BillModel.fromMap(String id, Map<String, dynamic> map) {
    return BillModel(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      items: List<Map<String, dynamic>>.from(map['items'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paid: map['paid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'customerId': customerId,
      'totalAmount': totalAmount,
      'items': items,
      'createdAt': Timestamp.fromDate(createdAt),
      'paid': paid,
    };
  }
}
