// ============================================================================
// PHARMACY COMPLIANCE EXCEPTION
// ============================================================================
// Typed exception for pharmacy/wholesale compliance violations.
// Used to block sales of expired products or items missing mandatory fields.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

/// Exception thrown when pharmacy compliance rules are violated
///
/// Error codes:
/// - `EXPIRED_PRODUCT`: Attempting to sell an expired product
/// - `MISSING_BATCH_NUMBER`: Batch number required but not provided
/// - `MISSING_EXPIRY_DATE`: Expiry date required but not provided
/// - `MISSING_PRESCRIPTION`: Scheduled drug sold without a prescription id
/// - `MRP_CEILING_VIOLATION`: One or more line items sold above their MRP
/// - `NEAR_EXPIRY_WARNING`: Product expires within 30 days (warning, not blocking)
class PharmacyComplianceException implements Exception {
  /// Error code for programmatic handling
  final String code;

  /// Human-readable error message
  final String message;

  /// Additional details about the violation
  final Map<String, dynamic>? details;

  const PharmacyComplianceException({
    required this.code,
    required this.message,
    this.details,
  });

  /// Factory for expired product errors
  factory PharmacyComplianceException.expiredProduct({
    required String productName,
    DateTime? expiryDate,
  }) {
    return PharmacyComplianceException(
      code: 'EXPIRED_PRODUCT',
      message: 'Cannot sell expired product: $productName',
      details: {
        'productName': productName,
        'expiryDate': expiryDate?.toIso8601String(),
        'severity': 'BLOCKING',
        'issueType': 'expired',
      },
    );
  }

  /// Factory for missing batch number errors
  factory PharmacyComplianceException.missingBatchNumber({
    required String productName,
  }) {
    return PharmacyComplianceException(
      code: 'MISSING_BATCH_NUMBER',
      message: 'Batch number is mandatory for: $productName',
      details: {'productName': productName, 'severity': 'BLOCKING'},
    );
  }

  /// Factory for missing expiry date errors
  factory PharmacyComplianceException.missingExpiryDate({
    required String productName,
  }) {
    return PharmacyComplianceException(
      code: 'MISSING_EXPIRY_DATE',
      message: 'Expiry date is mandatory for: $productName',
      details: {'productName': productName, 'severity': 'BLOCKING'},
    );
  }

  /// Factory for MRP ceiling violations (Requirements 8.3, 8.4).
  ///
  /// Raised when one or more line items have a selling price strictly greater
  /// than their MRP. The entire bill is rejected and left unsaved; [violators]
  /// identifies every offending line item (productId, itemName, sellingPaise,
  /// mrpPaise, message) so the caller can report which lines failed.
  factory PharmacyComplianceException.mrpCeilingViolation({
    required List<Map<String, dynamic>> violators,
  }) {
    final names = violators
        .map((v) => v['itemName']?.toString() ?? 'Unknown item')
        .join(', ');
    return PharmacyComplianceException(
      code: 'MRP_CEILING_VIOLATION',
      message: 'Selling price exceeds MRP for: $names',
      details: {
        'severity': 'BLOCKING',
        'issueType': 'mrp_violation',
        'violators': violators,
      },
    );
  }

  /// Check if this is a blocking error (sale should not proceed)
  bool get isBlocking => code != 'NEAR_EXPIRY_WARNING';

  @override
  String toString() => 'PharmacyComplianceException[$code]: $message';
}
