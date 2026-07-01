import 'package:dukanx/core/compat/firestore_compat.dart';

/// Tank entity for fuel storage management
/// Tracks stock levels, purchases, and sales deductions
class Tank {
  final String tankId;
  final String tankName;
  final String fuelTypeId;
  final String? fuelTypeName; // Denormalized for display
  final double capacity; // Maximum capacity in litres
  final double openingStock; // Stock at shift/day start
  final double purchaseQuantity; // Purchases added during period
  final double salesDeduction; // Sales deducted during period
  final double currentStock; // Actual stock (may differ from calculated)
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastDipReading; // Last physical dip reading time
  final bool isActive;

  Tank({
    required this.tankId,
    required this.tankName,
    required this.fuelTypeId,
    this.fuelTypeName,
    required this.capacity,
    this.openingStock = 0.0,
    this.purchaseQuantity = 0.0,
    this.salesDeduction = 0.0,
    double? currentStock,
    required this.ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastDipReading,
    this.isActive = true,
  }) : currentStock =
           currentStock ?? (openingStock + purchaseQuantity - salesDeduction),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Calculated stock based on opening + purchases - sales
  double get calculatedStock =>
      openingStock + purchaseQuantity - salesDeduction;

  /// Stock variance (difference between actual and calculated)
  double get stockVariance => currentStock - calculatedStock;

  /// Stock percentage (for UI visualization)
  double get stockPercentage =>
      capacity > 0 ? (currentStock / capacity) * 100 : 0;

  /// Check if stock is low (below 20%)
  bool get isLowStock => stockPercentage < 20;

  /// Check if tank is empty
  bool get isEmpty => currentStock <= 0;

  /// Available capacity for purchase
  double get availableCapacity => capacity - currentStock;

  Tank copyWith({
    String? tankId,
    String? tankName,
    String? fuelTypeId,
    String? fuelTypeName,
    double? capacity,
    double? openingStock,
    double? purchaseQuantity,
    double? salesDeduction,
    double? currentStock,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastDipReading,
    bool? isActive,
  }) {
    return Tank(
      tankId: tankId ?? this.tankId,
      tankName: tankName ?? this.tankName,
      fuelTypeId: fuelTypeId ?? this.fuelTypeId,
      fuelTypeName: fuelTypeName ?? this.fuelTypeName,
      capacity: capacity ?? this.capacity,
      openingStock: openingStock ?? this.openingStock,
      purchaseQuantity: purchaseQuantity ?? this.purchaseQuantity,
      salesDeduction: salesDeduction ?? this.salesDeduction,
      currentStock: currentStock ?? this.currentStock,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastDipReading: lastDipReading ?? this.lastDipReading,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Add purchase to tank
  Tank addPurchase(double quantity) {
    final newPurchase = purchaseQuantity + quantity;
    final newStock = currentStock + quantity;
    return copyWith(
      purchaseQuantity: newPurchase,
      currentStock: newStock.clamp(0, capacity),
    );
  }

  /// Deduct sales from tank
  Tank deductSales(double quantity) {
    final newSales = salesDeduction + quantity;
    final newStock = currentStock - quantity;
    return copyWith(
      salesDeduction: newSales,
      currentStock: newStock.clamp(0, capacity),
    );
  }

  /// Update with dip reading (manual stock check)
  Tank updateWithDipReading(double actualStock) {
    return copyWith(
      currentStock: actualStock.clamp(0, capacity),
      lastDipReading: DateTime.now(),
    );
  }

  /// Reset for new day/period
  Tank resetForNewPeriod() {
    return copyWith(
      openingStock: currentStock,
      purchaseQuantity: 0.0,
      salesDeduction: 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'tankId': tankId,
    'tankName': tankName,
    'fuelTypeId': fuelTypeId,
    'fuelTypeName': fuelTypeName,
    'capacity': capacity,
    'openingStock': openingStock,
    'purchaseQuantity': purchaseQuantity,
    'salesDeduction': salesDeduction,
    'currentStock': currentStock,
    'calculatedStock': calculatedStock,
    'stockVariance': stockVariance,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastDipReading': lastDipReading?.toIso8601String(),
    'isActive': isActive,
  };

  factory Tank.fromMap(String id, Map<String, dynamic> map) {
    return Tank(
      tankId: id,
      tankName: map['tankName'] as String? ?? 'Tank',
      fuelTypeId: map['fuelTypeId'] as String? ?? '',
      fuelTypeName: map['fuelTypeName'] as String?,
      capacity: (map['capacity'] as num?)?.toDouble() ?? 0.0,
      openingStock: (map['openingStock'] as num?)?.toDouble() ?? 0.0,
      purchaseQuantity: (map['purchaseQuantity'] as num?)?.toDouble() ?? 0.0,
      salesDeduction: (map['salesDeduction'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['currentStock'] as num?)?.toDouble(),
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      lastDipReading: map['lastDipReading'] != null
          ? _parseDateTime(map['lastDipReading'])
          : null,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
