import 'package:dukanx/core/compat/firestore_compat.dart';

class PaymentModel {
  final String id;
  final String billId;
  final String customerId;
  final String ownerId;
  final double amount;
  final DateTime paidAt;
  final String method; // cash, online, etc.

  PaymentModel({
    required this.id,
    required this.billId,
    required this.customerId,
    required this.ownerId,
    required this.amount,
    required this.paidAt,
    required this.method,
  });

  factory PaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentModel(
      id: id,
      billId: map['billId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidAt: (map['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: map['method'] as String? ?? 'cash',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'customerId': customerId,
      'ownerId': ownerId,
      'amount': amount,
      'paidAt': Timestamp.fromDate(paidAt),
      'method': method,
    };
  }
}
