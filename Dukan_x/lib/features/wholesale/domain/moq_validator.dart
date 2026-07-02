import 'validation_result.dart';

/// Validates Minimum Order Quantity (MOQ) and case-pack configuration
/// for the wholesale vertical.
///
/// Pure, deterministic validation — no side effects, no I/O.
class MoqValidator {
  const MoqValidator();

  /// Validates a bill line against its MOQ constraint.
  ///
  /// Accepts if and only if:
  /// - [moq] is a positive integer (> 0)
  /// - [qty] >= [moq]
  ///
  /// Returns [ValidationSuccess] when acceptable, or [ValidationFailure]
  /// with a descriptive reason otherwise.
  ValidationResult validateLine({required int moq, required int qty}) {
    if (moq <= 0) {
      return const ValidationFailure('MOQ must be a positive integer');
    }
    if (qty < moq) {
      return ValidationFailure(
        'Quantity ($qty) is below the minimum order quantity ($moq)',
      );
    }
    return const ValidationSuccess();
  }

  /// Validates MOQ and conversion-factor values at configuration time.
  ///
  /// Rejects:
  /// - `null` moq or conversionFactor
  /// - Zero or negative moq
  /// - Zero or negative conversionFactor
  ///
  /// Returns [ValidationSuccess] when both values are valid positive integers,
  /// or [ValidationFailure] with a descriptive reason otherwise.
  ValidationResult validateConfig({
    required int? moq,
    required int? conversionFactor,
  }) {
    if (moq == null) {
      return const ValidationFailure('MOQ is required');
    }
    if (moq <= 0) {
      return ValidationFailure('MOQ must be a positive integer, got $moq');
    }
    if (conversionFactor == null) {
      return const ValidationFailure('Conversion factor is required');
    }
    if (conversionFactor <= 0) {
      return ValidationFailure(
        'Conversion factor must be a positive integer, got $conversionFactor',
      );
    }
    return const ValidationSuccess();
  }
}
