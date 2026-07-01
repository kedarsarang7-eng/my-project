import 'package:equatable/equatable.dart';
import 'bill_item.dart';

enum BillSource { manual, voice, scan }

class Bill extends Equatable {
  final String id;
  final String? shopName;
  final String? customerName;
  final String? customerPhone;
  final DateTime date;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double totalAmount;
  final String paymentMethod;
  final BillSource source;

  const Bill({
    required this.id,
    this.shopName,
    this.customerName,
    this.customerPhone,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.totalAmount,
    this.paymentMethod = 'Cash',
    this.source = BillSource.manual,
  });

  @override
  List<Object?> get props => [
    id,
    shopName,
    customerName,
    customerPhone,
    date,
    items,
    subtotal,
    tax,
    discount,
    totalAmount,
    paymentMethod,
    source,
  ];

  Bill copyWith({
    String? id,
    String? shopName,
    String? customerName,
    String? customerPhone,
    DateTime? date,
    List<BillItem>? items,
    double? subtotal,
    double? tax,
    double? discount,
    double? totalAmount,
    String? paymentMethod,
    BillSource? source,
  }) {
    return Bill(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      date: date ?? this.date,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      source: source ?? this.source,
    );
  }
}
