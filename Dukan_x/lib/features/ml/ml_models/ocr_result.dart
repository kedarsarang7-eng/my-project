// OCR Result Model
//
// Structured output from ML Kit Text Recognition.
// Includes raw text, parsed items, and confidence scores. for validation.

import 'package:equatable/equatable.dart';
import 'scanned_item.dart';

/// Confidence threshold for automatic acceptance
const double kConfidenceThreshold = 0.7;

/// Result of OCR text recognition
class OcrResult extends Equatable {
  /// Raw text from ML Kit
  final String rawText;

  /// Parsed items with confidence scores
  final List<ScannedItem> items;

  /// Detected GST/tax amount
  final double gst;

  /// Detected total amount
  final double totalAmount;

  /// Detected shop/vendor name
  final String shopName;

  /// Detected date on bill
  final DateTime? billDate;

  /// BCP-47 language code (e.g., "hi", "mr", "en")
  final String detectedLanguage;

  /// True if any item has confidence below threshold
  final bool needsReview;

  /// Overall confidence score (0.0-1.0)
  final double overallConfidence;

  const OcrResult({
    required this.rawText,
    required this.items,
    this.gst = 0.0,
    this.totalAmount = 0.0,
    this.shopName = '',
    this.billDate,
    this.detectedLanguage = 'en',
    this.needsReview = false,
    this.overallConfidence = 0.0,
  });

  /// Create empty result for failed OCR
  factory OcrResult.empty() =>
      const OcrResult(rawText: '', items: [], needsReview: true);

  /// Calculate if review is needed based on item confidence
  bool get requiresUserReview =>
      needsReview ||
      items.any((item) => item.confidence < kConfidenceThreshold);

  /// Get low confidence items that need review
  List<ScannedItem> get lowConfidenceItems =>
      items.where((item) => item.confidence < kConfidenceThreshold).toList();

  @override
  List<Object?> get props => [
    rawText,
    items,
    gst,
    totalAmount,
    shopName,
    billDate,
    detectedLanguage,
    needsReview,
    overallConfidence,
  ];

  OcrResult copyWith({
    String? rawText,
    List<ScannedItem>? items,
    double? gst,
    double? totalAmount,
    String? shopName,
    DateTime? billDate,
    String? detectedLanguage,
    bool? needsReview,
    double? overallConfidence,
  }) {
    return OcrResult(
      rawText: rawText ?? this.rawText,
      items: items ?? this.items,
      gst: gst ?? this.gst,
      totalAmount: totalAmount ?? this.totalAmount,
      shopName: shopName ?? this.shopName,
      billDate: billDate ?? this.billDate,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      needsReview: needsReview ?? this.needsReview,
      overallConfidence: overallConfidence ?? this.overallConfidence,
    );
  }
}
