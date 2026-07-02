import 'moq_validator.dart';
import 'validation_result.dart';

/// Validates wholesale bill lines against product MOQ constraints.
///
/// Used in the wholesale billing path to reject lines whose quantity
/// is below the item's configured MOQ. Only wholesale bill lines
/// enforce MOQ — other verticals are unaffected (§14, Requirement 7.3).
///
/// When a product has no MOQ configured (null), the line is always accepted.
class WholesaleBillValidator {
  final MoqValidator _moqValidator;

  const WholesaleBillValidator({MoqValidator? moqValidator})
      : _moqValidator = moqValidator ?? const MoqValidator();

  /// Validates a single bill line against the product's MOQ.
  ///
  /// - If [productMoq] is `null`, the product has no MOQ configured and the
  ///   line is always accepted (no enforcement).
  /// - If [productMoq] is set and [lineQty] < [productMoq], the line is
  ///   rejected with a [ValidationFailure] identifying the minimum.
  /// - Nothing is persisted for a rejected line.
  ///
  /// Returns [ValidationSuccess] if the line is acceptable, or
  /// [ValidationFailure] with a human-readable reason otherwise.
  ValidationResult validateLine({
    required int? productMoq,
    required int lineQty,
  }) {
    // No MOQ configured — always accept (null = no enforcement).
    if (productMoq == null) {
      return const ValidationSuccess();
    }

    // Delegate to the pure domain validator.
    return _moqValidator.validateLine(moq: productMoq, qty: lineQty);
  }

  /// Validates multiple bill lines at once, returning the first failure
  /// or [ValidationSuccess] if all lines pass.
  ///
  /// Each entry in [lines] is a tuple of (productMoq, lineQty).
  /// A line with a null productMoq is always accepted.
  ValidationResult validateLines(
    List<({int? productMoq, int lineQty})> lines,
  ) {
    for (final line in lines) {
      final result = validateLine(
        productMoq: line.productMoq,
        lineQty: line.lineQty,
      );
      if (result.isInvalid) {
        return result;
      }
    }
    return const ValidationSuccess();
  }
}
