/// GSTIN Validation Service for Indian GST compliance
///
/// GSTIN Format: 2 State Code + 10 PAN + 1 Entity Code + 1 Check Digit + 1 Z
/// Example: 27AABCU9603R1ZM
class GstinValidator {
  /// GSTIN regex pattern as per GST guidelines
  static final RegExp gstinPattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );

  /// PAN pattern (10 characters within GSTIN)
  static final RegExp panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

  /// Validates GSTIN format
  static ValidationResult validateGstin(String? gstin) {
    if (gstin == null || gstin.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'GSTIN is required',
      );
    }

    // Remove spaces and convert to uppercase
    final cleanGstin = gstin.toUpperCase().replaceAll(' ', '');

    // Check length
    if (cleanGstin.length != 15) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'GSTIN must be exactly 15 characters',
      );
    }

    // Check pattern
    if (!gstinPattern.hasMatch(cleanGstin)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Invalid GSTIN format',
      );
    }

    // Validate state code (01-38)
    final stateCode = cleanGstin.substring(0, 2);
    final stateCodeInt = int.tryParse(stateCode);
    if (stateCodeInt == null || stateCodeInt < 1 || stateCodeInt > 38) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Invalid state code: $stateCode',
      );
    }

    // Validate check digit
    if (!_validateCheckDigit(cleanGstin)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Invalid GSTIN check digit',
      );
    }

    return ValidationResult(
      isValid: true,
      stateCode: stateCode,
      pan: cleanGstin.substring(2, 12),
      entityCode: cleanGstin[12],
    );
  }

  /// Extract state code from GSTIN
  static String? getStateCode(String? gstin) {
    if (gstin == null || gstin.length < 2) return null;
    return gstin.substring(0, 2);
  }

  /// Extract PAN from GSTIN
  static String? getPan(String? gstin) {
    if (gstin == null || gstin.length < 12) return null;
    return gstin.substring(2, 12);
  }

  /// Validate check digit using Luhn algorithm (mod 36)
  static bool _validateCheckDigit(String gstin) {
    // GST check digit validation using weighted sum
    const characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    int sum = 0;
    for (int i = 0; i < 14; i++) {
      final charIndex = characters.indexOf(gstin[i]);
      if (charIndex == -1) return false;

      int value = charIndex;
      if (i % 2 == 0) {
        // Even position (0, 2, 4, ...)
        value = charIndex;
      } else {
        // Odd position (1, 3, 5, ...)
        value = charIndex * 2;
        if (value > 35) {
          value = (value ~/ 36) + (value % 36);
        }
      }
      sum += value;
    }

    final remainder = sum % 36;
    final checkDigit = (36 - remainder) % 36;
    final expectedCheckDigit = characters[checkDigit];

    return gstin[14] == expectedCheckDigit;
  }

  /// Check if two GSTINs are from same state (for interstate/intrastate)
  static bool isSameState(String? gstin1, String? gstin2) {
    final state1 = getStateCode(gstin1);
    final state2 = getStateCode(gstin2);
    if (state1 == null || state2 == null) return false;
    return state1 == state2;
  }

  /// Determine if supply is interstate or intrastate
  static bool isInterstate(String? sellerGstin, String? buyerGstin) {
    return !isSameState(sellerGstin, buyerGstin);
  }

  /// Format GSTIN for display (add spaces)
  static String formatGstin(String gstin) {
    if (gstin.length != 15) return gstin;
    // Format: 27 AABCU9603R 1 Z M
    return '${gstin.substring(0, 2)} ${gstin.substring(2, 12)} ${gstin.substring(12)}';
  }
}

/// Validation result with details
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? stateCode;
  final String? pan;
  final String? entityCode;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.stateCode,
    this.pan,
    this.entityCode,
  });

  @override
  String toString() {
    if (isValid) {
      return 'Valid GSTIN - State: $stateCode, PAN: $pan, Entity: $entityCode';
    }
    return 'Invalid GSTIN: $errorMessage';
  }
}
