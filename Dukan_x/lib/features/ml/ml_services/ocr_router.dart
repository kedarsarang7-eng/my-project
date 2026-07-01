// ============================================================================
// OCR ROUTER
// ============================================================================
// Routes OCR processing to appropriate parser based on business type.
// Preserves generic OCR for non-pharmacy businesses.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/foundation.dart';

import '../ml_models/ocr_result.dart';
import '../../ml/ml_services/ocr_service.dart';
import '../../ml/parsers/medicine_ocr_parser.dart';
import 'heuristic_parsers.dart';
import '../../../core/billing/business_type_config.dart'; // Added import

/// Routes OCR processing to appropriate parser based on business type
///
/// Usage:
/// ```dart
/// final router = OcrRouter();
/// final result = await router.processForBusinessType(
///   imagePath: '/path/to/image.jpg',
///   businessType: 'pharmacy',
/// );
/// ```
class OcrRouter {
  final MLKitOcrService _defaultOcrService;

  /// Create router with default OCR service
  OcrRouter() : _defaultOcrService = MLKitOcrService();

  /// Create router with custom OCR service (for testing)
  OcrRouter.withService(this._defaultOcrService);

  /// Process image and route to appropriate parser based on business type
  ///
  /// For pharmacy/wholesale:
  /// - Uses medicine-specific parser for batch/expiry extraction
  /// - Enhances result with medicine-specific fields
  ///
  /// For other business types:
  /// - Uses generic OCR parser
  ///
  /// Original OCR result is always preserved for backward compatibility.
  Future<OcrRouterResult> processForBusinessType({
    required String imagePath,
    required String businessType,
  }) async {
    debugPrint('[OcrRouter] Processing for business type: $businessType');

    // 1. Always perform generic OCR first
    final genericResult = await _defaultOcrService.recognizeTextAutoDetect(
      imagePath,
    );

    // 2. Run Heuristic Parser for all types (baseline extraction)
    final parsedMap = HeuristicParser.parse(
      genericResult.rawText,
      businessType,
    );

    // 3. For businesses tracking batches (Pharmacy/Wholesale), run strict medicine parser
    MedicineOcrResult? medicineResult;
    if (_shouldUseMedicineParser(businessType)) {
      medicineResult = MedicineOcrParser.parse(genericResult.rawText);
      debugPrint('[OcrRouter] Medicine parsing result: $medicineResult');
    }

    // 4. Return combined result
    return OcrRouterResult(
      genericResult: genericResult,
      medicineResult: medicineResult,
      parsedResult: parsedMap,
      businessType: businessType,
    );
  }

  /// Check if business type requires medicine-specific OCR (Batch/Expiry)
  bool _shouldUseMedicineParser(String businessTypeStr) {
    try {
      final type = migrateBusinessType(businessTypeStr);
      final config = BusinessTypeRegistry.getConfig(type);
      // If the business tracks batch numbers, we essentially need the medicine parser
      // as it's optimized for finding Batch and Expiry patterns.
      return config.isRequired(ItemField.batchNo) ||
          config.optionalFields.contains(ItemField.batchNo);
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _defaultOcrService.dispose();
  }
}

/// Combined result from OCR routing
///
/// Contains both generic OCR result and medicine-specific parsing result
class OcrRouterResult {
  /// Generic OCR result (always available)
  final OcrResult genericResult;

  /// Medicine-specific result (only for pharmacy/wholesale)
  final MedicineOcrResult? medicineResult;

  final Map<String, dynamic>? parsedResult; // Generic Heuristic Result
  /// Business type used for routing
  final String businessType;

  const OcrRouterResult({
    required this.genericResult,
    this.medicineResult,
    this.parsedResult,
    required this.businessType,
  });

  /// Whether this is a pharmacy-type result
  bool get isPharmacyType {
    try {
      final type = migrateBusinessType(businessType);
      final config = BusinessTypeRegistry.getConfig(type);
      return config.isRequired(ItemField.batchNo) ||
          config.optionalFields.contains(ItemField.batchNo);
    } catch (e) {
      return false;
    }
  }

  /// Whether medicine-specific data was extracted
  bool get hasMedicineData => medicineResult?.hasPharmacyData ?? false;

  /// Get batch number (from medicine result)
  String? get batchNumber => medicineResult?.batchNumber;

  /// Get expiry date (from medicine result)
  DateTime? get expiryDate => medicineResult?.expiryDate;

  /// Get MRP (from medicine result)
  double? get mrp => medicineResult?.mrp;

  /// Get strength (from medicine result)
  String? get strength => medicineResult?.strength;

  /// Get raw text (from generic result)
  String get rawText => genericResult.rawText;

  /// Get items (from generic result)
  List get items => genericResult.items;

  /// Get overall confidence
  double get confidence {
    if (medicineResult != null && medicineResult!.hasPharmacyData) {
      // Average of generic and medicine confidence
      return (genericResult.overallConfidence + medicineResult!.confidence) / 2;
    }
    return genericResult.overallConfidence;
  }

  @override
  String toString() {
    return 'OcrRouterResult(businessType: $businessType, '
        'hasMedicineData: $hasMedicineData, '
        'batch: $batchNumber, expiry: $expiryDate)';
  }
}
