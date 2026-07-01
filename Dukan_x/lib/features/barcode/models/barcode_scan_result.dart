// ============================================================================
// BARCODE SCAN RESULT MODELS
// ============================================================================
// Data models for barcode scan results with business-type specific fields
//
// Phase 1: Grocery, Pharmacy, Hardware support
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

// ============================================================================
// SCANNED PRODUCT MODEL
// ============================================================================

class ScannedProduct {
  final String id;
  final String tenantId;
  final String? businessId;
  final String name;
  final String? displayName;
  final String? sku;
  final String? barcode;
  final List<String>? altBarcodes;
  final String? category;
  final String? subcategory;
  final String? brand;
  final String? hsnCode;
  final String unit;
  
  // Prices (stored in cents for precision)
  final int salePriceCents;
  final int? purchasePriceCents;
  final int? mrpCents;
  final int? wholesalePriceCents;
  
  // Tax rates (in basis points: 1800 = 18%)
  final int cgstRateBp;
  final int sgstRateBp;
  final int igstRateBp;
  
  // Stock
  final double currentStock;
  final double lowStockThreshold;
  final double? reorderQty;
  
  // Status
  final bool isActive;
  final bool isArchived;
  
  // Media
  final String? imageUrl;
  
  // Attributes (business-type specific)
  final Map<String, dynamic> attributes;
  
  // Pharmacy-specific fields
  final String? batchNumber;
  final DateTime? expiryDate;
  final String? drugSchedule;
  final String? fssaiLicense;
  
  // Electronics-specific fields
  final String? imei;
  final String? serialNumber;
  final int? warrantyMonths;
  
  // Clothing-specific fields
  final String? size;
  final String? color;
  
  // Jewelry-specific fields
  final String? purity;
  final double? metalWeight;
  final double? makingCharges;
  final String? hallmark;
  
  // Bookstore-specific fields
  final String? isbn;
  final String? author;
  final String? publisher;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  ScannedProduct({
    required this.id,
    required this.tenantId,
    this.businessId,
    required this.name,
    this.displayName,
    this.sku,
    this.barcode,
    this.altBarcodes,
    this.category,
    this.subcategory,
    this.brand,
    this.hsnCode,
    this.unit = 'pcs',
    required this.salePriceCents,
    this.purchasePriceCents,
    this.mrpCents,
    this.wholesalePriceCents,
    this.cgstRateBp = 0,
    this.sgstRateBp = 0,
    this.igstRateBp = 0,
    required this.currentStock,
    this.lowStockThreshold = 10.0,
    this.reorderQty,
    this.isActive = true,
    this.isArchived = false,
    this.imageUrl,
    this.attributes = const {},
    this.batchNumber,
    this.expiryDate,
    this.drugSchedule,
    this.fssaiLicense,
    this.imei,
    this.serialNumber,
    this.warrantyMonths,
    this.size,
    this.color,
    this.purity,
    this.metalWeight,
    this.makingCharges,
    this.hallmark,
    this.isbn,
    this.author,
    this.publisher,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScannedProduct.fromJson(Map<String, dynamic> json) {
    return ScannedProduct(
      id: json['id'] ?? '',
      tenantId: json['tenantId'] ?? '',
      businessId: json['businessId'],
      name: json['name'] ?? '',
      displayName: json['displayName'],
      sku: json['sku'],
      barcode: json['barcode'],
      altBarcodes: json['altBarcodes'] != null
          ? List<String>.from(json['altBarcodes'])
          : null,
      category: json['category'],
      subcategory: json['subcategory'],
      brand: json['brand'],
      hsnCode: json['hsnCode'],
      unit: json['unit'] ?? 'pcs',
      salePriceCents: json['salePriceCents'] ?? 0,
      purchasePriceCents: json['purchasePriceCents'],
      mrpCents: json['mrpCents'],
      wholesalePriceCents: json['wholesalePriceCents'],
      cgstRateBp: json['cgstRateBp'] ?? 0,
      sgstRateBp: json['sgstRateBp'] ?? 0,
      igstRateBp: json['igstRateBp'] ?? 0,
      currentStock: (json['currentStock'] ?? 0).toDouble(),
      lowStockThreshold: (json['lowStockThreshold'] ?? 10).toDouble(),
      reorderQty: json['reorderQty']?.toDouble(),
      isActive: json['isActive'] ?? true,
      isArchived: json['isArchived'] ?? false,
      imageUrl: json['imageUrl'],
      attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
      batchNumber: json['batchNumber'],
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'])
          : null,
      drugSchedule: json['drugSchedule'],
      fssaiLicense: json['fssaiLicense'],
      imei: json['imei'],
      serialNumber: json['serialNumber'],
      warrantyMonths: json['warrantyMonths'],
      size: json['size'],
      color: json['color'],
      purity: json['purity'],
      metalWeight: json['metalWeight']?.toDouble(),
      makingCharges: json['makingCharges']?.toDouble(),
      hallmark: json['hallmark'],
      isbn: json['isbn'],
      author: json['author'],
      publisher: json['publisher'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenantId': tenantId,
    'businessId': businessId,
    'name': name,
    'displayName': displayName,
    'sku': sku,
    'barcode': barcode,
    'altBarcodes': altBarcodes,
    'category': category,
    'subcategory': subcategory,
    'brand': brand,
    'hsnCode': hsnCode,
    'unit': unit,
    'salePriceCents': salePriceCents,
    'purchasePriceCents': purchasePriceCents,
    'mrpCents': mrpCents,
    'wholesalePriceCents': wholesalePriceCents,
    'cgstRateBp': cgstRateBp,
    'sgstRateBp': sgstRateBp,
    'igstRateBp': igstRateBp,
    'currentStock': currentStock,
    'lowStockThreshold': lowStockThreshold,
    'reorderQty': reorderQty,
    'isActive': isActive,
    'isArchived': isArchived,
    'imageUrl': imageUrl,
    'attributes': attributes,
    'batchNumber': batchNumber,
    'expiryDate': expiryDate?.toIso8601String(),
    'drugSchedule': drugSchedule,
    'fssaiLicense': fssaiLicense,
    'imei': imei,
    'serialNumber': serialNumber,
    'warrantyMonths': warrantyMonths,
    'size': size,
    'color': color,
    'purity': purity,
    'metalWeight': metalWeight,
    'makingCharges': makingCharges,
    'hallmark': hallmark,
    'isbn': isbn,
    'author': author,
    'publisher': publisher,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  // Helper getters
  String get displayTitle => displayName ?? name;
  
  double get salePrice => salePriceCents / 100;
  double? get purchasePrice => purchasePriceCents != null ? purchasePriceCents! / 100 : null;
  double? get mrp => mrpCents != null ? mrpCents! / 100 : null;
  
  double get gstRate => (cgstRateBp + sgstRateBp) / 100;
  
  bool get isLowStock => currentStock <= lowStockThreshold;
  
  /// BUG-026 FIX: Use date-only comparison (clear time component)
  /// Prevents inconsistent expiry warnings during day boundary
  bool get isExpired {
    if (expiryDate == null) return false;
    final today = _dateOnly(DateTime.now());
    final expiry = _dateOnly(expiryDate!);
    return expiry.isBefore(today);
  }
  
  /// BUG-026 FIX: Days until expiry using date-only comparison
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final today = _dateOnly(DateTime.now());
    final expiry = _dateOnly(expiryDate!);
    return expiry.difference(today).inDays;
  }
  
  /// Helper: Clear time component for date-only comparison
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Computed expiry warning based on expiryDate.
  /// Returns critical if expired, warning if expiring within 90 days.
  /// BUG-026 FIX: Uses date-only comparison for consistent results
  ExpiryWarning? get expiryWarning {
    if (expiryDate == null) return null;
    // Use the same date-only calculation as daysUntilExpiry
    final days = daysUntilExpiry ?? 0;
    if (days < 0) {
      return ExpiryWarning(
        level: ExpiryLevel.critical,
        message: 'Expired ${days.abs()} days ago',
        daysUntilExpiry: days,
      );
    }
    if (days <= 90) {
      return ExpiryWarning(
        level: ExpiryLevel.warning,
        message: 'Expires in $days days',
        daysUntilExpiry: days,
      );
    }
    return null;
  }
}

// ============================================================================
// EXPIRY WARNING MODEL
// ============================================================================

class ExpiryWarning {
  final ExpiryLevel level;
  final String message;
  final int daysUntilExpiry;

  ExpiryWarning({
    required this.level,
    required this.message,
    required this.daysUntilExpiry,
  });

  factory ExpiryWarning.fromJson(Map<String, dynamic> json) {
    return ExpiryWarning(
      level: ExpiryLevel.values.firstWhere(
        (e) => e.name == json['level'].toString().toLowerCase(),
        orElse: () => ExpiryLevel.warning,
      ),
      message: json['message'] ?? '',
      daysUntilExpiry: json['days'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level.name.toUpperCase(),
    'message': message,
    'days': daysUntilExpiry,
  };
}

enum ExpiryLevel {
  warning,   // Expiring soon (orange)
  critical,  // Expired (red)
}

// ============================================================================
// BARCODE VALIDATION UTILS
// ============================================================================

class BarcodeValidator {
  /// Validate and identify barcode format
  static BarcodeValidationResult validate(String barcode) {
    if (barcode.isEmpty) {
      return BarcodeValidationResult.invalid('Empty barcode');
    }

    if (barcode.length > 48) {
      return BarcodeValidationResult.invalid('Barcode too long (max 48 chars)');
    }

    // EAN-13: 13 digits
    if (RegExp(r'^\d{13}$').hasMatch(barcode)) {
      if (!_verifyEan13CheckDigit(barcode)) {
        return BarcodeValidationResult.invalid(
          'Invalid EAN-13 check digit',
          format: BarcodeFormat.ean13,
        );
      }
      return BarcodeValidationResult.valid(BarcodeFormat.ean13);
    }

    // EAN-8: 8 digits
    if (RegExp(r'^\d{8}$').hasMatch(barcode)) {
      if (!_verifyEan8CheckDigit(barcode)) {
        return BarcodeValidationResult.invalid(
          'Invalid EAN-8 check digit',
          format: BarcodeFormat.ean8,
        );
      }
      return BarcodeValidationResult.valid(BarcodeFormat.ean8);
    }

    // UPC-A: 12 digits
    if (RegExp(r'^\d{12}$').hasMatch(barcode)) {
      return BarcodeValidationResult.valid(BarcodeFormat.upca);
    }

    // ISBN-13 (starts with 978 or 979)
    if (RegExp(r'^(978|979)\d{10}$').hasMatch(barcode)) {
      return BarcodeValidationResult.valid(BarcodeFormat.isbn13);
    }

    // Code-128 / Generic: Alphanumeric
    if (RegExp(r'^[A-Za-z0-9\-_]{6,48}$').hasMatch(barcode)) {
      return BarcodeValidationResult.valid(BarcodeFormat.code128);
    }

    return BarcodeValidationResult.invalid('Invalid barcode format');
  }

  static bool _verifyEan13CheckDigit(String ean) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(ean[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(ean[12]);
  }

  static bool _verifyEan8CheckDigit(String ean) {
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final digit = int.parse(ean[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(ean[7]);
  }
}

class BarcodeValidationResult {
  final bool valid;
  final BarcodeFormat? format;
  final String? error;

  BarcodeValidationResult._({
    required this.valid,
    this.format,
    this.error,
  });

  factory BarcodeValidationResult.valid(BarcodeFormat format) {
    return BarcodeValidationResult._(valid: true, format: format);
  }

  factory BarcodeValidationResult.invalid(String error, {BarcodeFormat? format}) {
    return BarcodeValidationResult._(valid: false, format: format, error: error);
  }
}

enum BarcodeFormat {
  ean13,
  ean8,
  upca,
  isbn13,
  code128,
  generic,
}
