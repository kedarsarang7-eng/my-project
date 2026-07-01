import 'package:dukanx/core/compat/firestore_compat.dart';

class DueModel {
  final String id;
  final String ownerId;
  final String customerId;
  final double amount;
  final DateTime dueDate;
  final bool cleared;

  DueModel({
    required this.id,
    required this.ownerId,
    required this.customerId,
    required this.amount,
    required this.dueDate,
    this.cleared = false,
  });

  factory DueModel.fromMap(String id, Map<String, dynamic> map) {
    return DueModel(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cleared: map['cleared'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'customerId': customerId,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'cleared': cleared,
    };
  }
}
