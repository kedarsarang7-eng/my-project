// ============================================================================
// PAISE — pharmacy-scoped integer-money helper
// ============================================================================
// Centralizes round-half-up conversion so that MRP, GST, and credit-note math
// in the pharmacy vertical all agree on the same rounding rule.
//
// All monetary values are integer paise (₹1 = 100 paise). Floating-point money
// types are never stored or compared — `double`/`num` appears ONLY at the input
// boundary (`fromRupees`) and is converted to integer paise immediately.
//
// Rounding rule: round-half-up (ties go toward positive infinity).
//   2.5  -> 3      (tie rounds up)
//  -2.5  -> -2     (tie rounds up, toward +∞)
//   2.4  -> 2
//  -2.6  -> -3
//
// Validates: Requirements 2.1, 2.2, 2.4 (integer paise, round-half-up,
// boundary conversion of non-integer inputs).
//
// This helper is pharmacy-scoped and does not modify the shared
// `core/billing/paise_calculator.dart` used by other verticals.
// ============================================================================

/// Integer-paise money helper for the pharmacy vertical.
///
/// Static-only utility: there is nothing to instantiate.
class Paise {
  const Paise._();

  /// Convert a rupee amount to integer paise, rounding to the nearest whole
  /// paise using round-half-up.
  ///
  /// Use this at the boundary where a legacy `double`/`num` rupee value enters
  /// changed pharmacy code (Requirement 2.4). The returned value is a whole
  /// integer paise carrying no fractional component (Requirement 2.1).
  static int fromRupees(num rupees) => roundHalfUp(rupees * 100);

  /// Round a (possibly fractional) paise result to the nearest whole paise
  /// using round-half-up (ties toward positive infinity).
  ///
  /// Use this whenever a paise arithmetic operation can produce a fractional
  /// result, e.g. applying a GST rate to a taxable amount (Requirement 2.2).
  ///
  /// `floor(value + 0.5)` implements round-half-up for both positive and
  /// negative values (negative amounts occur for credit notes / returns).
  static int roundHalfUp(num fractionalPaise) =>
      (fractionalPaise + 0.5).floor();

  /// Render an integer paise value as a rupee string with exactly two decimal
  /// places (Requirement 2.3): `paise / 100` shown as `rupees.pp`.
  ///
  /// Formatting is done with integer arithmetic to avoid floating-point error
  /// on large amounts. Negative values keep a leading sign, e.g. -150 → "-1.50".
  static String toDisplay(int paise) {
    final bool isNegative = paise < 0;
    final int absolutePaise = paise.abs();
    final int rupees = absolutePaise ~/ 100;
    final int fraction = absolutePaise % 100;
    final String fractionPart = fraction.toString().padLeft(2, '0');
    final String sign = isNegative ? '-' : '';
    return '$sign$rupees.$fractionPart';
  }
}
