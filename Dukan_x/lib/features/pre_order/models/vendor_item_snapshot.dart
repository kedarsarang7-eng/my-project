/// VendorItemSnapshot - Read-optimized snapshot for customer catalog browsing.
/// This is the ONLY collection customers read for product listings.
/// Updated asynchronously when stock changes.
class VendorItemSnapshot {
  final String vendorId;
  final List<SnapshotItem> items;
  final DateTime snapshotUpdatedAt;

  VendorItemSnapshot({
    required this.vendorId,
    required this.items,
    required this.snapshotUpdatedAt,
  });

  factory VendorItemSnapshot.fromMap(
    String vendorId,
    Map<String, dynamic> map,
  ) {
    return VendorItemSnapshot(
      vendorId: vendorId,
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => SnapshotItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      snapshotUpdatedAt: map['snapshotUpdatedAt'] != null
          ? DateTime.parse(map['snapshotUpdatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'vendorId': vendorId,
    'items': items.map((e) => e.toMap()).toList(),
    'snapshotUpdatedAt': snapshotUpdatedAt.toIso8601String(),
  };

  VendorItemSnapshot copyWith({
    String? vendorId,
    List<SnapshotItem>? items,
    DateTime? snapshotUpdatedAt,
  }) {
    return VendorItemSnapshot(
      vendorId: vendorId ?? this.vendorId,
      items: items ?? this.items,
      snapshotUpdatedAt: snapshotUpdatedAt ?? this.snapshotUpdatedAt,
    );
  }
}

/// Individual item in the snapshot
class SnapshotItem {
  final String itemId;
  final String name;
  final String unit;
  final double price;
  final double stockQty;
  final double lowStockThreshold;
  final DateTime updatedAt;

  SnapshotItem({
    required this.itemId,
    required this.name,
    required this.unit,
    required this.price,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.updatedAt,
  });

  /// Stock status for UI display
  StockStatus get stockStatus {
    if (stockQty <= 0) return StockStatus.outOfStock;
    if (stockQty <= lowStockThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  bool get isAvailable => stockQty > 0;

  factory SnapshotItem.fromMap(Map<String, dynamic> map) {
    return SnapshotItem(
      itemId: map['itemId'] ?? '',
      name: map['name'] ?? '',
      unit: map['unit'] ?? 'pcs',
      price: (map['price'] ?? map['sellingPrice'] ?? 0).toDouble(),
      stockQty: (map['stockQty'] ?? 0).toDouble(),
      lowStockThreshold: (map['lowStockThreshold'] ?? 10).toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'name': name,
    'unit': unit,
    'price': price,
    'stockQty': stockQty,
    'lowStockThreshold': lowStockThreshold,
    'updatedAt': updatedAt.toIso8601String(),
  };

  SnapshotItem copyWith({
    String? itemId,
    String? name,
    String? unit,
    double? price,
    double? stockQty,
    double? lowStockThreshold,
    DateTime? updatedAt,
  }) {
    return SnapshotItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      stockQty: stockQty ?? this.stockQty,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Stock status enum for UI
enum StockStatus { inStock, lowStock, outOfStock }
