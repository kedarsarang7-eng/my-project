enum ProductType { goods, service }

class StockItem {
  String id;
  String name;
  String category;
  String sku; // Stock Keeping Unit / Code
  String hsn; // HSN Code for GST
  double purchasePrice;
  double sellingPrice;
  double gstRate; // 0, 5, 12, 18, 28
  double quantity;
  String unit; // kg, pcs, box, etc.
  double lowStockThreshold;
  String? description;
  DateTime? expiryDate;
  String ownerId;
  ProductType type; // New: Distinguish Goods vs Services
  final Map<String, dynamic>
  metadata; // Flexible container for Business-Specific Fields

  // --- Helpers for Type-Specific Data ---
  String? get batchNumber => metadata['batchNumber'];
  String? get imei => metadata['imei'];
  String? get serialNumber => metadata['serialNumber'];
  String? get size => metadata['size'];
  String? get color => metadata['color'];
  String? get brand => metadata['brand'];
  DateTime? get manufactureDate {
    if (metadata['manufactureDate'] == null) return null;
    return DateTime.tryParse(metadata['manufactureDate']);
  }

  StockItem({
    required this.id,
    required this.name,
    this.category = 'General',
    this.sku = '',
    this.hsn = '',
    this.purchasePrice = 0.0,
    required this.sellingPrice,
    this.gstRate = 0.0,
    this.quantity = 0.0,
    this.unit = 'pcs',
    this.lowStockThreshold = 10.0,
    this.description,
    this.expiryDate,
    required this.ownerId,
    this.type = ProductType.goods, // Default to Goods
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'sku': sku,
      'hsn': hsn,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'gstRate': gstRate,
      'quantity': quantity,
      'unit': unit,
      'lowStockThreshold': lowStockThreshold,
      'description': description,
      'expiryDate': expiryDate?.toIso8601String(),
      'ownerId': ownerId,
      'type': type.name, // Serialize enum name
      'metadata': metadata,
    };
  }

  factory StockItem.fromMap(String id, Map<String, dynamic> map) {
    return StockItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      sku: map['sku'] ?? '',
      hsn: map['hsn'] ?? '',
      purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
      sellingPrice: (map['sellingPrice'] ?? 0.0).toDouble(),
      gstRate: (map['gstRate'] ?? 0.0).toDouble(),
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? 'pcs',
      lowStockThreshold: (map['lowStockThreshold'] ?? 10.0).toDouble(),
      description: map['description'],
      expiryDate: map['expiryDate'] != null
          ? DateTime.tryParse(map['expiryDate'])
          : null,
      ownerId: map['ownerId'] ?? '',
      type: map['type'] != null
          ? ProductType.values.firstWhere(
              (e) => e.name == map['type'],
              orElse: () => ProductType.goods,
            )
          : ProductType.goods,
      metadata: map['metadata'] ?? {},
    );
  }

  StockItem copyWith({
    String? name,
    String? category,
    String? sku,
    String? hsn,
    double? purchasePrice,
    double? sellingPrice,
    double? gstRate,
    double? quantity,
    String? unit,
    double? lowStockThreshold,
    String? description,
    DateTime? expiryDate,
    ProductType? type,
    Map<String, dynamic>? metadata,
  }) {
    return StockItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      hsn: hsn ?? this.hsn,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      gstRate: gstRate ?? this.gstRate,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      description: description ?? this.description,
      expiryDate: expiryDate ?? this.expiryDate,
      type: type ?? this.type,
      ownerId: ownerId,
      metadata: metadata ?? this.metadata,
    );
  }
}
