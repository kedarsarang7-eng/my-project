// ============================================================================
// HEURISTIC PARSERS
// ============================================================================
// Logic to extract structured data from raw OCR text based on business context.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

class HeuristicParser {
  /// Extract product details from raw text based on business type
  static Map<String, dynamic> parse(String text, String businessType) {
    // Normalize text
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Default result
    final result = <String, dynamic>{'rawText': text, 'lines': lines};

    // 1. Common Extractions (MRP, Rate, Qty)
    _extractCommonFields(lines, result);

    // 2. Business Specific Logic
    switch (businessType) {
      case 'pharmacy':
        _extractPharmacyFields(lines, result);
        break;
      case 'electronics':
        _extractElectronicsFields(lines, result);
        break;
      case 'grocery':
      default:
        // Already covered by common, but can add specific brand detection
        break;
    }

    return result;
  }

  static void _extractCommonFields(
    List<String> lines,
    Map<String, dynamic> result,
  ) {
    // MRP / Rate Detection
    // Look for patterns like "MRP 100", "Rate: 50.00", "Rs. 299"
    final moneyRegex = RegExp(
      r'(?:MRP|Rate|Price|Rs\.?|₹)\s*:?\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = moneyRegex.firstMatch(line);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          result['detectedPrice'] = double.tryParse(amountStr);
        }
      }
    }

    // Attempt to guess Product Name (usually the first non-numeric, non-header line)
    // Heuristic: First line that is not a date, not a price, and has length > 3
    for (final line in lines) {
      if (line.length > 3 &&
          !line.toLowerCase().contains('date') &&
          !line.contains(RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}')) &&
          !line.startsWith('Rs.')) {
        result['detectedName'] = line;
        break;
      }
    }
  }

  static void _extractPharmacyFields(
    List<String> lines,
    Map<String, dynamic> result,
  ) {
    // Expiry Date
    final expiryRegex = RegExp(
      r'(?:Exp|Expiry|Use Before)\s*:?\s*(\d{1,2}[/-]\d{2,4})',
      caseSensitive: false,
    );

    // Batch No
    final batchRegex = RegExp(
      r'(?:Batch|Lot|B\.No)\s*:?\s*([A-Z0-9]+)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (result['expiryDate'] == null) {
        final expMatch = expiryRegex.firstMatch(line);
        if (expMatch != null) result['expiryDate'] = expMatch.group(1);
      }

      if (result['batchNo'] == null) {
        final batchMatch = batchRegex.firstMatch(line);
        if (batchMatch != null) result['batchNo'] = batchMatch.group(1);
      }
    }
  }

  static void _extractElectronicsFields(
    List<String> lines,
    Map<String, dynamic> result,
  ) {
    // Serial Number / IMEI
    final serialRegex = RegExp(
      r'(?:S\/N|Serial|IMEI)\s*:?\s*([A-Z0-9]+)',
      caseSensitive: false,
    );

    // Model
    final modelRegex = RegExp(
      r'(?:Model)\s*:?\s*([A-Z0-9-]+)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (result['serialNumber'] == null) {
        final snMatch = serialRegex.firstMatch(line);
        if (snMatch != null) result['serialNumber'] = snMatch.group(1);
      }

      if (result['model'] == null) {
        final modelMatch = modelRegex.firstMatch(line);
        if (modelMatch != null) result['model'] = modelMatch.group(1);
      }
    }
  }
}
