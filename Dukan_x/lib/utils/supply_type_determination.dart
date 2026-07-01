/// Supply Type Determination
/// 
/// Determines whether a transaction is inter-state (IGST) or intra-state (CGST+SGST)
/// based on buyer and seller state codes derived from GSTIN.
/// 
/// CRITICAL: Supply type must be DERIVED from buyer/seller states, not stored or assumed.
library;

/// Validates GSTIN format (15-character)
bool isValidGstin(String gstin) {
  return gstin.length == 15 && RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z\d{1}$').hasMatch(gstin);
}

/// Extracts state code (first 2 chars) from GSTIN
/// 
/// Returns 2-digit state code (e.g., '27' for Maharashtra)
String extractStateFromGstin(String gstin) {
  if (!isValidGstin(gstin)) {
    throw GstinParseException('Invalid GSTIN: $gstin. Expected 15-character code.');
  }
  return gstin.substring(0, 2);
}

/// Determines supply type (inter-state vs intra-state)
/// 
/// CRITICAL GST Rule: If buyer state ≠ seller state → IGST (18%)
///                    If buyer state = seller state → CGST+SGST (each half)
/// 
/// Returns:
/// - 'igst': Inter-state supply (different states) → use IGST only
/// - 'cgst_sgst': Intra-state supply (same state) → use CGST+SGST
SupplyType deriveSupplyType(String buyerGstin, String sellerGstin) {
  // Validate both GSTINs
  if (!isValidGstin(buyerGstin)) {
    throw GstinParseException('Invalid buyer GSTIN: $buyerGstin');
  }
  if (!isValidGstin(sellerGstin)) {
    throw GstinParseException('Invalid seller GSTIN: $sellerGstin');
  }
  
  final buyerState = extractStateFromGstin(buyerGstin);
  final sellerState = extractStateFromGstin(sellerGstin);
  
  // Compare state codes
  if (buyerState != sellerState) {
    return SupplyType.igst;  // Inter-state → IGST
  } else {
    return SupplyType.cgstSgst;  // Intra-state → CGST+SGST
  }
}

enum SupplyType {
  igst,       // 18% IGST only
  cgstSgst,   // CGST + SGST (half each, or split by rate)
}

/// Custom exception for GSTIN parsing errors
class GstinParseException implements Exception {
  final String message;
  
  GstinParseException(this.message);
  
  @override
  String toString() => 'GSTIN Parse Error: $message';
}

/// GST Compliance Helper
class GstComplianceHelper {
  /// Create a supply type audit record for compliance trail
  static Map<String, dynamic> createSupplyTypeAuditRecord({
    required String invoiceId,
    required String buyerGstin,
    required String sellerGstin,
    required SupplyType derivedType,
    required DateTime invoiceDate,
  }) {
    return {
      'invoiceId': invoiceId,
      'buyerState': extractStateFromGstin(buyerGstin),
      'sellerState': extractStateFromGstin(sellerGstin),
      'supplyType': derivedType.name,
      'derivedAt': invoiceDate.toIso8601String(),
      'reason': derivedType == SupplyType.igst 
        ? 'Inter-state supply: buyer state != seller state' 
        : 'Intra-state supply: buyer state = seller state',
    };
  }
  
  /// Verify supply type consistency across invoice
  /// 
  /// Ensures that all line items use the same supply type
  static bool verifySupplyTypeConsistency(
    List<Map<String, dynamic>> lineItems,
    SupplyType expectedType,
  ) {
    for (final item in lineItems) {
      final itemSupplyType = item['supplyType'] as String?;
      final expectedName = expectedType.name;
      
      if (itemSupplyType != expectedName) {
        return false;  // Inconsistency found
      }
    }
    return true;  // All items consistent
  }
}
