// ============================================================================
// DC MONEY MATH — integer-paise arithmetic for Decoration & Catering
// ============================================================================
// Per Requirement 1.3 / 1.4 all money in touched DC code is integer paise.
// This helper provides the half-up rounding seam and paise ↔ rupee conversion
// utilities used by the DC business rules, billing, and repository layers.
//
// All monetary computations operate on `int` paise. The `round2` method
// performs banker-neutral half-up rounding of a fractional paise value to the
// nearest integer paise — the same semantic as `MoneyMath.roundTo2` but
// operating on integer-paise arithmetic rather than rupee-doubles.
//
// Usage:
//   final discount = DcMoneyMath.round2(subtotal * discountPct ~/ 100);
//   final rupees = DcMoneyMath.paiseToRupees(amountPaise);
//   final paise = DcMoneyMath.rupeesToPaise(amountRupees);
// ============================================================================

/// Integer-paise monetary helpers for the DC vertical.
///
/// Enforces the cross-cutting constraint that all money in touched DC code
/// is integer paise (Requirement 1.3) with no `double` currency types
/// introduced (Requirement 1.4).
class DcMoneyMath {
  DcMoneyMath._();

  /// Half-up rounds a fractional paise value (expressed as a `double`) to the
  /// nearest integer paise.
  ///
  /// This is the rounding seam used by all DC percentage-based calculations:
  /// ```dart
  /// discountAmount = DcMoneyMath.round2(subtotal * discountPct / 100);
  /// gstAmount = DcMoneyMath.round2(postDiscount * gstPct / 100);
  /// advanceAmount = DcMoneyMath.round2(total * advancePct / 100);
  /// ```
  ///
  /// Half-up rounding: 0.5 rounds away from zero (standard commercial rounding).
  /// Examples:
  ///   round2(149.5) → 150
  ///   round2(149.4) → 149
  ///   round2(-149.5) → -150
  static int round2(double fractionalPaise) {
    if (fractionalPaise >= 0) {
      return (fractionalPaise + 0.5).floor();
    } else {
      return (fractionalPaise - 0.5).ceil();
    }
  }

  /// Converts integer paise to a rupee `double` for display/serialization only.
  ///
  /// Do NOT use the returned double for further arithmetic — convert back to
  /// paise first. This exists solely for UI formatting and API boundary
  /// compatibility with the existing `_paisa`/`_toPaisa` pattern.
  static double paiseToRupees(int paise) => paise / 100.0;

  /// Converts a rupee `double` to integer paise using half-up rounding.
  ///
  /// Use this at the API/model boundary where existing DC models expose
  /// rupee doubles but internal computations need integer paise.
  static int rupeesToPaise(double rupees) => round2(rupees * 100);

  /// Formats an integer paise amount as a rupee string with 2 decimal places.
  ///
  /// Example: `formatPaise(1050)` → `'₹10.50'`
  static String formatPaise(int paise) {
    final rupees = paiseToRupees(paise);
    return '₹${rupees.toStringAsFixed(2)}';
  }

  /// Computes percentage of an integer-paise amount with half-up rounding.
  ///
  /// `percentOf(10000, 18.0)` → `1800` (18% of ₹100.00)
  /// `percentOf(999, 50.0)` → `500` (50% of ₹9.99 = 499.5, rounded up)
  static int percentOf(int amountPaise, double percent) {
    return round2(amountPaise * percent / 100.0);
  }

  /// Clamps an integer-paise amount to the range [min, max].
  ///
  /// Returns [min] if amount < min, [max] if amount > max, otherwise amount.
  static int clamp(int amountPaise, {required int min, required int max}) {
    if (amountPaise < min) return min;
    if (amountPaise > max) return max;
    return amountPaise;
  }
}
