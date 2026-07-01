// Scanned Item Model
//
// Represents a single item extracted from a bill.
// Includes confidence score for verification. and user review.

import 'package:equatable/equatable.dart';

/// Single item parsed from OCR text
class ScannedItem extends Equatable {
  /// Item name extracted from bill
  final String name;

  /// Quantity (defaults to 1 if not detected)
  final double quantity;

  /// Unit price per item
  final double price;

  /// Total amount (quantity Ã— price)
  final double amount;

  /// Unit of measurement (pc, kg, etc.)
  final String unit;

  /// Confidence score from 0.0 to 1.0
  /// Lower confidence items should be marked for review
  final double confidence;

  /// Original text line from which this item was parsed
  final String? rawLine;

  const ScannedItem({
    required this.name,
    this.quantity = 1.0,
    this.price = 0.0,
    this.amount = 0.0,
    this.unit = 'pc',
    this.confidence = 0.0,
    this.rawLine,
  });

  /// Check if item needs manual review
  bool get needsReview => confidence < 0.7;

  /// Get confidence level as string
  String get confidenceLevel {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    return 'Low';
  }

  @override
  List<Object?> get props => [
    name,
    quantity,
    price,
    amount,
    unit,
    confidence,
    rawLine,
  ];

  ScannedItem copyWith({
    String? name,
    double? quantity,
    double? price,
    double? amount,
    String? unit,
    double? confidence,
    String? rawLine,
  }) {
    return ScannedItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      confidence: confidence ?? this.confidence,
      rawLine: rawLine ?? this.rawLine,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': quantity,
    'price': price,
    'amount': amount,
    'unit': unit,
    'confidence': confidence,
  };

  factory ScannedItem.fromJson(Map<String, dynamic> json) => ScannedItem(
    name: json['name']?.toString() ?? 'Unknown',
    quantity: (json['qty'] ?? 1).toDouble(),
    price: (json['price'] ?? 0).toDouble(),
    amount: (json['amount'] ?? 0).toDouble(),
    unit: json['unit']?.toString() ?? 'pc',
    confidence: (json['confidence'] ?? 0).toDouble(),
  );
}
