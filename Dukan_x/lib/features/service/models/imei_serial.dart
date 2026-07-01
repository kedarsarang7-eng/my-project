/// IMEI Serial Model
/// Tracks IMEI/Serial numbers lifecycle for electronics
library;

/// IMEI/Serial status lifecycle
enum IMEISerialStatus {
  inStock, // Available in inventory
  sold, // Sold to customer
  returned, // Returned by customer
  damaged, // Damaged/defective
  inService, // Currently in service/repair
  demo, // Demo/display unit — visible in tracking but excluded from sellable stock
}

extension IMEISerialStatusExtension on IMEISerialStatus {
  String get value {
    switch (this) {
      case IMEISerialStatus.inStock:
        return 'IN_STOCK';
      case IMEISerialStatus.sold:
        return 'SOLD';
      case IMEISerialStatus.returned:
        return 'RETURNED';
      case IMEISerialStatus.damaged:
        return 'DAMAGED';
      case IMEISerialStatus.inService:
        return 'IN_SERVICE';
      case IMEISerialStatus.demo:
        return 'DEMO';
    }
  }

  String get displayName {
    switch (this) {
      case IMEISerialStatus.inStock:
        return 'In Stock';
      case IMEISerialStatus.sold:
        return 'Sold';
      case IMEISerialStatus.returned:
        return 'Returned';
      case IMEISerialStatus.damaged:
        return 'Damaged';
      case IMEISerialStatus.inService:
        return 'In Service';
      case IMEISerialStatus.demo:
        return 'Demo';
    }
  }

  /// Whether this status represents a sellable/available-for-sale state.
  /// Only `inStock` is considered sellable. `demo` units are explicitly
  /// excluded from sellable stock while remaining visible in IMEI tracking.
  bool get isSellable => this == IMEISerialStatus.inStock;

  static IMEISerialStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IN_STOCK':
        return IMEISerialStatus.inStock;
      case 'SOLD':
        return IMEISerialStatus.sold;
      case 'RETURNED':
        return IMEISerialStatus.returned;
      case 'DAMAGED':
        return IMEISerialStatus.damaged;
      case 'IN_SERVICE':
        return IMEISerialStatus.inService;
      case 'DEMO':
        return IMEISerialStatus.demo;
      default:
        return IMEISerialStatus.inStock;
    }
  }
}

/// IMEI/Serial type
enum IMEISerialType {
  imei, // Mobile phones (15 digit)
  serial, // Laptops, desktops, other electronics
}

extension IMEISerialTypeExtension on IMEISerialType {
  String get value {
    switch (this) {
      case IMEISerialType.imei:
        return 'IMEI';
      case IMEISerialType.serial:
        return 'SERIAL';
    }
  }

  static IMEISerialType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IMEI':
        return IMEISerialType.imei;
      case 'SERIAL':
        return IMEISerialType.serial;
      default:
        return IMEISerialType.serial;
    }
  }
}

/// IMEI/Serial model
class IMEISerial {
  final String id;
  final String userId;
  final String productId;

  // Identification
  final String imeiOrSerial;
  final IMEISerialType type;
  final IMEISerialStatus status;

  // Purchase info
  final String? purchaseOrderId;
  final double purchasePrice;
  final DateTime? purchaseDate;
  final String? supplierName;

  // Sale info
  final String? billId;
  final String? customerId;
  final double soldPrice;
  final DateTime? soldDate;

  // Warranty
  final int warrantyMonths;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final bool isUnderWarranty;

  // Device details
  final String? productName;
  final String? brand;
  final String? model;
  final String? color;
  final String? storage;
  final String? ram;

  // Notes
  final String? notes;

  // Second-hand intake (Phase 6)
  final String? condition; // 'excellent', 'good', 'fair', 'poor'
  final String? grade; // 'A', 'B', 'C', 'D'
  final int? valuationPaise; // Integer Paise (1..99999999999)

  // Sync
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  IMEISerial({
    required this.id,
    required this.userId,
    required this.productId,
    required this.imeiOrSerial,
    this.type = IMEISerialType.imei,
    this.status = IMEISerialStatus.inStock,
    this.purchaseOrderId,
    this.purchasePrice = 0,
    this.purchaseDate,
    this.supplierName,
    this.billId,
    this.customerId,
    this.soldPrice = 0,
    this.soldDate,
    this.warrantyMonths = 0,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.isUnderWarranty = false,
    this.productName,
    this.brand,
    this.model,
    this.color,
    this.storage,
    this.ram,
    this.notes,
    this.condition,
    this.grade,
    this.valuationPaise,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if currently under warranty based on date
  bool get isWarrantyActive {
    if (warrantyEndDate == null) return false;
    return DateTime.now().isBefore(warrantyEndDate!);
  }

  /// Device display name
  String get displayName {
    final parts = <String>[];
    if (brand != null && brand!.isNotEmpty) parts.add(brand!);
    if (model != null && model!.isNotEmpty) parts.add(model!);
    if (storage != null && storage!.isNotEmpty) parts.add(storage!);
    if (color != null && color!.isNotEmpty) parts.add(color!);
    return parts.isEmpty ? imeiOrSerial : parts.join(' ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'productId': productId,
      'imeiOrSerial': imeiOrSerial,
      'type': type.value,
      'status': status.value,
      'purchaseOrderId': purchaseOrderId,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'supplierName': supplierName,
      'billId': billId,
      'customerId': customerId,
      'soldPrice': soldPrice,
      'soldDate': soldDate?.toIso8601String(),
      'warrantyMonths': warrantyMonths,
      'warrantyStartDate': warrantyStartDate?.toIso8601String(),
      'warrantyEndDate': warrantyEndDate?.toIso8601String(),
      'isUnderWarranty': isUnderWarranty,
      'productName': productName,
      'brand': brand,
      'model': model,
      'color': color,
      'storage': storage,
      'ram': ram,
      'notes': notes,
      'condition': condition,
      'grade': grade,
      'valuationPaise': valuationPaise,
      'isSynced': isSynced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory IMEISerial.fromMap(Map<String, dynamic> map) {
    return IMEISerial(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      productId: map['productId'] ?? '',
      imeiOrSerial: map['imeiOrSerial'] ?? '',
      type: IMEISerialTypeExtension.fromString(map['type'] ?? 'IMEI'),
      status: IMEISerialStatusExtension.fromString(map['status'] ?? 'IN_STOCK'),
      purchaseOrderId: map['purchaseOrderId'],
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      purchaseDate: map['purchaseDate'] != null
          ? DateTime.tryParse(map['purchaseDate'])
          : null,
      supplierName: map['supplierName'],
      billId: map['billId'],
      customerId: map['customerId'],
      soldPrice: (map['soldPrice'] ?? 0).toDouble(),
      soldDate: map['soldDate'] != null
          ? DateTime.tryParse(map['soldDate'])
          : null,
      warrantyMonths: map['warrantyMonths'] ?? 0,
      warrantyStartDate: map['warrantyStartDate'] != null
          ? DateTime.tryParse(map['warrantyStartDate'])
          : null,
      warrantyEndDate: map['warrantyEndDate'] != null
          ? DateTime.tryParse(map['warrantyEndDate'])
          : null,
      isUnderWarranty: map['isUnderWarranty'] == true,
      productName: map['productName'],
      brand: map['brand'],
      model: map['model'],
      color: map['color'],
      storage: map['storage'],
      ram: map['ram'],
      notes: map['notes'],
      condition: map['condition'],
      grade: map['grade'],
      valuationPaise: map['valuationPaise'] != null
          ? (map['valuationPaise'] as num).toInt()
          : null,
      isSynced: map['isSynced'] == true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  IMEISerial copyWith({
    String? id,
    String? userId,
    String? productId,
    String? imeiOrSerial,
    IMEISerialType? type,
    IMEISerialStatus? status,
    String? purchaseOrderId,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? supplierName,
    String? billId,
    String? customerId,
    double? soldPrice,
    DateTime? soldDate,
    int? warrantyMonths,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    bool? isUnderWarranty,
    String? productName,
    String? brand,
    String? model,
    String? color,
    String? storage,
    String? ram,
    String? notes,
    String? condition,
    String? grade,
    int? valuationPaise,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IMEISerial(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      imeiOrSerial: imeiOrSerial ?? this.imeiOrSerial,
      type: type ?? this.type,
      status: status ?? this.status,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierName: supplierName ?? this.supplierName,
      billId: billId ?? this.billId,
      customerId: customerId ?? this.customerId,
      soldPrice: soldPrice ?? this.soldPrice,
      soldDate: soldDate ?? this.soldDate,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      isUnderWarranty: isUnderWarranty ?? this.isUnderWarranty,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      storage: storage ?? this.storage,
      ram: ram ?? this.ram,
      notes: notes ?? this.notes,
      condition: condition ?? this.condition,
      grade: grade ?? this.grade,
      valuationPaise: valuationPaise ?? this.valuationPaise,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
