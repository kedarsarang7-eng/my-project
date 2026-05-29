import 'package:equatable/equatable.dart';

enum TransactionType { invoice, payment, creditNote, adjustment }

class CustomerTransaction extends Equatable {
  final String id;
  final String customerId;
  final String vendorId;
  final String vendorName;
  final TransactionType type;
  final double amount;
  final String? referenceNumber;
  final String? description;
  final DateTime transactionDate;
  final DateTime createdAt;

  const CustomerTransaction({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.vendorName,
    required this.type,
    required this.amount,
    this.referenceNumber,
    this.description,
    required this.transactionDate,
    required this.createdAt,
  });

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) {
    return CustomerTransaction(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      vendorId: json['vendorId'] as String,
      vendorName: json['vendorName'] as String? ?? '',
      type: _typeFromString(json['type'] as String? ?? 'invoice'),
      amount: (json['amount'] as num).toDouble(),
      referenceNumber: json['referenceNumber'] as String?,
      description: json['description'] as String?,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static TransactionType _typeFromString(String s) {
    switch (s.toLowerCase()) {
      case 'payment':
        return TransactionType.payment;
      case 'creditnote':
      case 'credit_note':
        return TransactionType.creditNote;
      case 'adjustment':
        return TransactionType.adjustment;
      default:
        return TransactionType.invoice;
    }
  }

  @override
  List<Object?> get props => [id, customerId, vendorId, type, amount, transactionDate];
}
