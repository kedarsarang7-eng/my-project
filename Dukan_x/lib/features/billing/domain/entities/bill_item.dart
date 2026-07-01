import 'package:equatable/equatable.dart';

class BillItem extends Equatable {
  final String productId;
  final String name;
  final double quantity;
  final double rate;
  final double amount;
  final String unit;
  final double discount;
  final double taxAmount;

  const BillItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.rate,
    required this.amount,
    this.unit = 'unit',
    this.discount = 0.0,
    this.taxAmount = 0.0,
  });

  @override
  List<Object> get props => [
    productId,
    name,
    quantity,
    rate,
    amount,
    unit,
    discount,
    taxAmount,
  ];

  BillItem copyWith({
    String? productId,
    String? name,
    double? quantity,
    double? rate,
    double? amount,
    String? unit,
    double? discount,
    double? taxAmount,
  }) {
    return BillItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
    );
  }
}
