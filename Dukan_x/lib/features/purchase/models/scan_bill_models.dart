// ============================================================================
// Scan Bill Models — Data classes for OCR-based Purchase Entry
// ============================================================================

/// Raw line from Textract OCR
class RawLine {
  final String text;
  final int lineIndex;
  final double confidence;

  RawLine({
    required this.text,
    required this.lineIndex,
    required this.confidence,
  });

  factory RawLine.fromJson(Map<String, dynamic> json) => RawLine(
    text: json['text'] ?? '',
    lineIndex: json['lineIndex'] ?? 0,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Parsed line item from OCR
class ParsedLineItem {
  final String rawText;
  String productName;
  double? quantity;
  String? unit;
  double? unitPrice;
  double? totalPrice;
  String? hsnCode;
  String? batchNo;
  String? expiryDate;
  final String confidence;
  final List<String> parseWarnings;

  ParsedLineItem({
    required this.rawText,
    required this.productName,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.totalPrice,
    this.hsnCode,
    this.batchNo,
    this.expiryDate,
    required this.confidence,
    this.parseWarnings = const [],
  });

  factory ParsedLineItem.fromJson(Map<String, dynamic> json) => ParsedLineItem(
    rawText: json['rawText'] ?? '',
    productName: json['productName'] ?? '',
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: json['unit'],
    unitPrice: (json['unitPrice'] as num?)?.toDouble(),
    totalPrice: (json['totalPrice'] as num?)?.toDouble(),
    hsnCode: json['hsnCode'],
    batchNo: json['batchNo'],
    expiryDate: json['expiryDate'],
    confidence: json['confidence'] ?? 'low',
    parseWarnings:
        (json['parseWarnings'] as List?)?.map((e) => e.toString()).toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'rawText': rawText,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    'hsnCode': hsnCode,
    'batchNo': batchNo,
    'expiryDate': expiryDate,
    'confidence': confidence,
    'parseWarnings': parseWarnings,
  };

  /// Calculate total if not provided
  double get calculatedTotal {
    if (totalPrice != null) return totalPrice!;
    if (quantity != null && unitPrice != null) {
      return quantity! * unitPrice!;
    }
    return 0.0;
  }

  /// Check if this item has valid quantity and price
  bool get isValid =>
      productName.isNotEmpty &&
      productName != 'Unknown Product' &&
      quantity != null &&
      quantity! > 0 &&
      (unitPrice != null || totalPrice != null);
}

/// Matched product from catalog
class MatchedProduct {
  final String id;
  final String name;
  final String? displayName;
  final String? sku;
  final String? barcode;
  final String? category;
  final String? brand;
  final String? hsnCode;
  final String unit;
  final double currentStock;
  final double salePrice;
  final double? purchasePrice;
  final double gstRate;

  MatchedProduct({
    required this.id,
    required this.name,
    this.displayName,
    this.sku,
    this.barcode,
    this.category,
    this.brand,
    this.hsnCode,
    required this.unit,
    required this.currentStock,
    required this.salePrice,
    this.purchasePrice,
    required this.gstRate,
  });

  factory MatchedProduct.fromJson(Map<String, dynamic> json) => MatchedProduct(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    displayName: json['displayName'],
    sku: json['sku'],
    barcode: json['barcode'],
    category: json['category'],
    brand: json['brand'],
    hsnCode: json['hsnCode'],
    unit: json['unit'] ?? 'pcs',
    currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0.0,
    salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0.0,
    purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
    gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Match result for a single line item
class MatchResult {
  final ParsedLineItem parsedItem;
  final MatchedProduct? matchedProduct;
  final String matchConfidence;
  final List<MatchedProduct> alternativeSuggestions;
  final bool requiresManualReview;

  MatchResult({
    required this.parsedItem,
    this.matchedProduct,
    required this.matchConfidence,
    this.alternativeSuggestions = const [],
    required this.requiresManualReview,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    parsedItem: ParsedLineItem.fromJson(json['parsedItem'] ?? {}),
    matchedProduct: json['matchedProduct'] != null
        ? MatchedProduct.fromJson(json['matchedProduct'])
        : null,
    matchConfidence: json['matchConfidence'] ?? 'none',
    alternativeSuggestions:
        (json['alternativeSuggestions'] as List?)
            ?.map((e) => MatchedProduct.fromJson(e))
            .toList() ??
        [],
    requiresManualReview: json['requiresManualReview'] ?? true,
  );
}

/// Review line item (mutable during review phase)
class ReviewLineItem {
  String id;
  String? productId;
  String productName;
  double quantity;
  String unit;
  double unitPrice;
  double totalPrice;
  String? hsnCode;
  String? batchNo;
  String? expiryDate;
  bool isNewProduct;
  NewProductData? newProductData;
  String matchConfidence;
  bool isDeleted;
  bool isSelected; // For bulk actions

  ReviewLineItem({
    required this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.hsnCode,
    this.batchNo,
    this.expiryDate,
    this.isNewProduct = false,
    this.newProductData,
    this.matchConfidence = 'none',
    this.isDeleted = false,
    this.isSelected = false,
  });

  factory ReviewLineItem.fromMatchResult(MatchResult result) {
    final parsed = result.parsedItem;
    final matched = result.matchedProduct;

    return ReviewLineItem(
      id:
          DateTime.now().millisecondsSinceEpoch.toString() +
          (result.hashCode.abs() % 1000).toString(),
      productId: matched?.id,
      productName: matched?.name ?? parsed.productName,
      quantity: parsed.quantity ?? 1.0,
      unit: matched?.unit ?? parsed.unit ?? 'pcs',
      unitPrice:
          parsed.unitPrice ??
          matched?.purchasePrice ??
          (parsed.totalPrice != null && parsed.quantity != null
              ? parsed.totalPrice! / parsed.quantity!
              : 0.0),
      totalPrice: parsed.totalPrice ?? 0.0,
      hsnCode: parsed.hsnCode ?? matched?.hsnCode,
      batchNo: parsed.batchNo,
      expiryDate: parsed.expiryDate,
      isNewProduct: matched == null,
      matchConfidence: result.matchConfidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    'hsnCode': hsnCode,
    'batchNo': batchNo,
    'expiryDate': expiryDate,
    'isNewProduct': isNewProduct,
    'newProductData': newProductData?.toJson(),
  };

  /// Recalculate total when quantity or price changes
  void recalculateTotal() {
    totalPrice = quantity * unitPrice;
  }

  /// Check if item is valid for submission
  bool get isValid =>
      !isDeleted && productName.isNotEmpty && quantity > 0 && unitPrice >= 0;
}

/// Data for creating a new product
class NewProductData {
  String? category;
  double? gstRate;
  String? hsnCode;

  NewProductData({this.category, this.gstRate, this.hsnCode});

  Map<String, dynamic> toJson() => {
    'category': category,
    'gstRate': gstRate,
    'hsnCode': hsnCode,
  };
}

/// Supplier details
class SupplierDetails {
  String? supplierId;
  String? supplierName;
  String? billNumber;
  DateTime? billDate;
  String paymentStatus;
  String? creditTerms;

  SupplierDetails({
    this.supplierId,
    this.supplierName,
    this.billNumber,
    this.billDate,
    this.paymentStatus = 'unpaid',
    this.creditTerms,
  });

  factory SupplierDetails.fromJson(Map<String, dynamic> json) =>
      SupplierDetails(
        supplierId: json['supplierId'],
        supplierName: json['supplierName'],
        billNumber: json['billNumber'],
        billDate: json['billDate'] != null
            ? DateTime.parse(json['billDate'])
            : null,
        paymentStatus: json['paymentStatus'] ?? 'unpaid',
        creditTerms: json['creditTerms'],
      );

  Map<String, dynamic> toJson() => {
    'supplierId': supplierId,
    'supplierName': supplierName,
    'billNumber': billNumber,
    'billDate': billDate?.toIso8601String(),
    'paymentStatus': paymentStatus,
    'creditTerms': creditTerms,
  };
}

/// Purchase entry (created after confirmation)
class PurchaseEntry {
  final String rid;
  final String? supplierId;
  final String? supplierName;
  final String? billNumber;
  final String billDate;
  final String billImageS3Key;
  final List<Map<String, dynamic>> lineItems;
  final double totalAmount;
  final double? gstAmount;
  final String paymentStatus;
  final String verticalType;
  final String entryMethod;
  final String createdBy;
  final String createdAt;

  PurchaseEntry({
    required this.rid,
    this.supplierId,
    this.supplierName,
    this.billNumber,
    required this.billDate,
    required this.billImageS3Key,
    required this.lineItems,
    required this.totalAmount,
    this.gstAmount,
    required this.paymentStatus,
    required this.verticalType,
    required this.entryMethod,
    required this.createdBy,
    required this.createdAt,
  });

  factory PurchaseEntry.fromJson(Map<String, dynamic> json) => PurchaseEntry(
    rid: json['rid'] ?? '',
    supplierId: json['supplierId'],
    supplierName: json['supplierName'],
    billNumber: json['billNumber'],
    billDate: json['billDate'] ?? '',
    billImageS3Key: json['billImageS3Key'] ?? '',
    lineItems: (json['lineItems'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    gstAmount: (json['gstAmount'] as num?)?.toDouble(),
    paymentStatus: json['paymentStatus'] ?? 'unpaid',
    verticalType: json['verticalType'] ?? 'grocery',
    entryMethod: json['entryMethod'] ?? 'scan',
    createdBy: json['createdBy'] ?? '',
    createdAt: json['createdAt'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'rid': rid,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'billNumber': billNumber,
    'billDate': billDate,
    'billImageS3Key': billImageS3Key,
    'lineItems': lineItems,
    'totalAmount': totalAmount,
    'gstAmount': gstAmount,
    'paymentStatus': paymentStatus,
    'verticalType': verticalType,
    'entryMethod': entryMethod,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}

/// API Response for extraction
class ExtractionResult {
  final String rid;
  final String s3ImageKey;
  final String presignedUrl;
  final List<RawLine> rawLines;
  final List<ParsedLineItem> parsedLines;
  final String? warning;
  final Map<String, dynamic> extractionStats;

  ExtractionResult({
    required this.rid,
    required this.s3ImageKey,
    required this.presignedUrl,
    required this.rawLines,
    required this.parsedLines,
    this.warning,
    required this.extractionStats,
  });

  factory ExtractionResult.fromJson(Map<String, dynamic> json) =>
      ExtractionResult(
        rid: json['rid'] ?? '',
        s3ImageKey: json['s3ImageKey'] ?? '',
        presignedUrl: json['presignedUrl'] ?? '',
        rawLines:
            (json['rawLines'] as List?)
                ?.map((e) => RawLine.fromJson(e))
                .toList() ??
            [],
        parsedLines:
            (json['parsedLines'] as List?)
                ?.map((e) => ParsedLineItem.fromJson(e))
                .toList() ??
            [],
        warning: json['warning'],
        extractionStats: json['extractionStats'] ?? {},
      );
}

/// API Response for matching
class MatchResultResponse {
  final String rid;
  final List<MatchResult> matchResults;
  final Map<String, int> matchStats;

  MatchResultResponse({
    required this.rid,
    required this.matchResults,
    required this.matchStats,
  });

  factory MatchResultResponse.fromJson(Map<String, dynamic> json) =>
      MatchResultResponse(
        rid: json['rid'] ?? '',
        matchResults:
            (json['matchResults'] as List?)
                ?.map((e) => MatchResult.fromJson(e))
                .toList() ??
            [],
        matchStats:
            (json['matchStats'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v as int),
            ) ??
            {},
      );
}

/// Scan session state for persistence
class ScanSessionState {
  final String rid;
  final String? imagePath;
  final List<String> imagePaths; // Multi-image support
  final String? s3ImageKey;
  final List<String> s3ImageKeys; // Multi-image support
  final String? presignedUrl;
  final List<String> presignedUrls; // Multi-image support
  final String verticalType;
  final ExtractionResult? extractionResult;
  final List<ReviewLineItem>? reviewLineItems;
  final SupplierDetails? supplierDetails;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMultiPage; // Flag for multi-page bills

  ScanSessionState({
    required this.rid,
    this.imagePath,
    this.imagePaths = const [],
    this.s3ImageKey,
    this.s3ImageKeys = const [],
    this.presignedUrl,
    this.presignedUrls = const [],
    required this.verticalType,
    this.extractionResult,
    this.reviewLineItems,
    this.supplierDetails,
    required this.createdAt,
    required this.updatedAt,
    this.isMultiPage = false,
  });

  factory ScanSessionState.fromJson(Map<String, dynamic> json) =>
      ScanSessionState(
        rid: json['rid'] ?? '',
        imagePath: json['imagePath'],
        s3ImageKey: json['s3ImageKey'],
        presignedUrl: json['presignedUrl'],
        verticalType: json['verticalType'] ?? 'grocery',
        extractionResult: json['extractionResult'] != null
            ? ExtractionResult.fromJson(json['extractionResult'])
            : null,
        reviewLineItems:
            (json['reviewLineItems'] as List?)
                ?.map(
                  (e) => ReviewLineItem.fromMatchResult(
                    MatchResult.fromJson({
                      'parsedItem': e,
                      'matchConfidence': 'none',
                      'requiresManualReview': true,
                    }),
                  ),
                )
                .toList() ??
            [],
        supplierDetails: json['supplierDetails'] != null
            ? SupplierDetails.fromJson(json['supplierDetails'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'rid': rid,
    'imagePath': imagePath,
    's3ImageKey': s3ImageKey,
    'presignedUrl': presignedUrl,
    'verticalType': verticalType,
    'extractionResult': extractionResult != null
        ? {
            'rid': extractionResult!.rid,
            's3ImageKey': extractionResult!.s3ImageKey,
            'presignedUrl': extractionResult!.presignedUrl,
            'parsedLines': extractionResult!.parsedLines
                .map((e) => e.toJson())
                .toList(),
          }
        : null,
    'reviewLineItems': reviewLineItems?.map((e) => e.toJson()).toList(),
    'supplierDetails': supplierDetails?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ScanSessionState copyWith({
    String? rid,
    String? imagePath,
    String? s3ImageKey,
    String? presignedUrl,
    String? verticalType,
    ExtractionResult? extractionResult,
    List<ReviewLineItem>? reviewLineItems,
    SupplierDetails? supplierDetails,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ScanSessionState(
    rid: rid ?? this.rid,
    imagePath: imagePath ?? this.imagePath,
    s3ImageKey: s3ImageKey ?? this.s3ImageKey,
    presignedUrl: presignedUrl ?? this.presignedUrl,
    verticalType: verticalType ?? this.verticalType,
    extractionResult: extractionResult ?? this.extractionResult,
    reviewLineItems: reviewLineItems ?? this.reviewLineItems,
    supplierDetails: supplierDetails ?? this.supplierDetails,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
