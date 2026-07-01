/// Validates all Mandi sale inputs before a sale is recorded.
///
/// Rejects:
/// - Non-numeric, negative, or over-maximum gross/tare/rate/commission
/// - gross < tare
/// - sale amount == 0
///
/// On success, returns validated numeric values with net weight = gross − tare.
///
/// (Requirements 8.1, 8.2, 8.3, 8.4, 8.5)
class MandiSaleValidator {
  const MandiSaleValidator._();

  /// Maximum allowed value for any weight or monetary field.
  /// 999,999,999.99 expressed as the raw double limit.
  static const double maxValue = 999999999.99;

  /// Validates raw string inputs from the Mandi entry sheet.
  ///
  /// Returns a [MandiSaleValidationResult] which is either:
  /// - [MandiSaleValidationSuccess] with validated numeric values and net weight
  /// - [MandiSaleValidationFailure] with field-specific error messages
  static MandiSaleValidationResult validate({
    required String grossStr,
    required String tareStr,
    required String rateStr,
    required String commissionStr,
  }) {
    final errors = <String, String>{};

    // --- Validate gross weight (Requirement 8.3) ---
    final gross = _parseAndValidateField(grossStr, 'gross weight', errors);

    // --- Validate tare weight (Requirement 8.3) ---
    final tare = _parseAndValidateField(tareStr, 'tare weight', errors);

    // --- Validate rate (Requirement 8.2) ---
    final rate = _parseAndValidateField(rateStr, 'rate', errors);

    // --- Validate commission (Requirement 8.2) ---
    final commission = _parseAndValidateField(
      commissionStr,
      'commission',
      errors,
    );

    // If any field failed basic parsing/range checks, return errors now.
    if (errors.isNotEmpty) {
      return MandiSaleValidationFailure(errors);
    }

    // All fields parsed successfully — now check cross-field rules.

    // --- Reject gross < tare (Requirement 8.1) ---
    if (gross! < tare!) {
      errors['gross weight'] =
          'gross weight must be greater than or equal to tare weight';
      return MandiSaleValidationFailure(errors);
    }

    // --- Compute net weight (Requirement 8.5) ---
    final netWeight = gross - tare;

    // --- Compute sale amount and reject if == 0 (Requirement 8.4) ---
    final saleAmount = netWeight * rate!;
    if (saleAmount == 0) {
      errors['sale amount'] = 'sale amount must be greater than 0';
      return MandiSaleValidationFailure(errors);
    }

    return MandiSaleValidationSuccess(
      gross: gross,
      tare: tare,
      netWeight: netWeight,
      rate: rate,
      commission: commission!,
      saleAmount: saleAmount,
    );
  }

  /// Parses and validates a single numeric field.
  ///
  /// Returns the parsed double on success, or null if validation fails
  /// (with an error added to [errors]).
  static double? _parseAndValidateField(
    String rawValue,
    String fieldName,
    Map<String, String> errors,
  ) {
    final trimmed = rawValue.trim();

    // Non-numeric check
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      errors[fieldName] = '$fieldName must be a valid number';
      return null;
    }

    // Negative check
    if (parsed < 0) {
      errors[fieldName] = '$fieldName must not be negative';
      return null;
    }

    // Over-maximum check
    if (parsed > maxValue) {
      errors[fieldName] = '$fieldName must not exceed $maxValue';
      return null;
    }

    return parsed;
  }
}

/// The result of validating Mandi sale inputs.
sealed class MandiSaleValidationResult {
  const MandiSaleValidationResult();

  /// Whether the validation succeeded.
  bool get isValid => this is MandiSaleValidationSuccess;

  /// Whether the validation failed.
  bool get isInvalid => this is MandiSaleValidationFailure;
}

/// Successful validation result with all parsed numeric values.
class MandiSaleValidationSuccess extends MandiSaleValidationResult {
  /// Validated gross weight.
  final double gross;

  /// Validated tare weight.
  final double tare;

  /// Computed net weight = gross − tare.
  final double netWeight;

  /// Validated rate per unit.
  final double rate;

  /// Validated commission value.
  final double commission;

  /// Computed sale amount = netWeight × rate.
  final double saleAmount;

  const MandiSaleValidationSuccess({
    required this.gross,
    required this.tare,
    required this.netWeight,
    required this.rate,
    required this.commission,
    required this.saleAmount,
  });
}

/// Failed validation result with field-specific error messages.
class MandiSaleValidationFailure extends MandiSaleValidationResult {
  /// Map of field name → error message.
  /// Keys are: 'gross weight', 'tare weight', 'rate', 'commission',
  /// or 'sale amount'.
  final Map<String, String> errors;

  const MandiSaleValidationFailure(this.errors);

  /// Returns the first error message (convenience for single-error display).
  String get firstError => errors.values.first;

  /// Returns a combined error message joining all field errors.
  String get combinedError =>
      errors.entries.map((e) => '${e.key}: ${e.value}').join('; ');
}
