import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, upi, bankTransfer, cheque, card, other }

class CustomerPayment extends Equatable {
  final String id;
  final String tenantId;
  final String customerId;
  final String vendorId;
  final String vendorName;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final DateTime paymentDate;
  final DateTime createdAt;

  const CustomerPayment({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.vendorId,
    required this.vendorName,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    required this.paymentDate,
    required this.createdAt,
  });

  factory CustomerPayment.fromJson(Map<String, dynamic> json) {
    return CustomerPayment(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      customerId: json['customerId'] as String,
      vendorId: json['vendorId'] as String,
      vendorName: json['vendorName'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: _methodFromString(json['paymentMethod'] as String? ?? 'other'),
      referenceNumber: json['referenceNumber'] as String?,
      notes: json['notes'] as String?,
      paymentDate: DateTime.parse(json['paymentDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static PaymentMethod _methodFromString(String s) {
    switch (s.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'upi':
        return PaymentMethod.upi;
      case 'banktransfer':
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'cheque':
        return PaymentMethod.cheque;
      case 'card':
        return PaymentMethod.card;
      default:
        return PaymentMethod.other;
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'customerId': customerId,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'amount': amount,
        'paymentMethod': paymentMethod.name,
        'referenceNumber': referenceNumber,
        'notes': notes,
        'paymentDate': paymentDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, tenantId, customerId, vendorId, amount, paymentMethod, paymentDate];
}
