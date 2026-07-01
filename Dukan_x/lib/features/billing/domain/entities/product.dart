import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String category;
  final double price;
  final double stockQuantity;
  final String unit;
  final DateTime? expiryDate;
  final double lowStockThreshold;
  final String? barcode;
  final String? size;
  final String? color;
  final String? brand;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stockQuantity,
    this.unit = 'unit',
    this.expiryDate,
    this.lowStockThreshold = 10.0,
    this.barcode,
    this.size,
    this.color,
    this.brand,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    price,
    stockQuantity,
    unit,
    expiryDate,
    lowStockThreshold,
    barcode,
    size,
    color,
    brand,
  ];
}
