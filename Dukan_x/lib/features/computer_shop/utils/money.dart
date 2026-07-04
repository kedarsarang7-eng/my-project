// Money boundary helper for the ComputerShop module.
//
// All paise↔rupee conversions happen here. This is the single documented
// boundary between the backend (paise) and models/UI (rupees).
// Invoked exclusively inside [ComputerRepository] JSON mapping.

/// Exception thrown when an incoming paise value is invalid.
class MoneyFormatException implements Exception {
  MoneyFormatException(this.message);

  final String message;

  @override
  String toString() => 'MoneyFormatException: $message';
}

/// Paise↔rupee conversion utilities.
///
/// - Incoming JSON money fields → [paiseToRupees]
/// - Outgoing request money fields → [rupeesToPaise]
/// - Models store rupees as [double]; UI formats via `CurrencyService`.
class Money {
  Money._();

  /// Converts backend paise (integer) to rupees (double, 2 decimal places).
  ///
  /// Throws [MoneyFormatException] when [paise] is:
  /// - `null`
  /// - negative
  /// - fractional (not a whole number)
  static double paiseToRupees(num? paise) {
    if (paise == null) {
      throw MoneyFormatException('Paise value is null');
    }
    if (paise < 0) {
      throw MoneyFormatException('Paise value is negative: $paise');
    }
    if (paise is double && paise != paise.roundToDouble()) {
      throw MoneyFormatException('Paise value is fractional: $paise');
    }
    // Convert to rupees: divide by 100, retain exactly 2 decimal places.
    final rupees = paise.toInt() / 100.0;
    return double.parse(rupees.toStringAsFixed(2));
  }

  /// Safe variant that returns [fallback] when the input is invalid
  /// instead of throwing.
  ///
  /// Use this to retain the last known valid value on bad input.
  static double paiseToRupeesOr(num? paise, double fallback) {
    try {
      return paiseToRupees(paise);
    } on MoneyFormatException {
      return fallback;
    }
  }

  /// Converts rupees (double) to backend paise (integer).
  ///
  /// Multiplies by 100 and rounds half-up to the nearest whole paise.
  static int rupeesToPaise(double rupees) {
    // Multiply by 100 and apply half-up rounding.
    // Dart's .round() uses "round half to even" (banker's rounding),
    // so we implement half-up explicitly.
    final raw = rupees * 100;
    return _roundHalfUp(raw);
  }

  /// Rounds [value] to the nearest integer using half-up rounding.
  /// When the fractional part is exactly 0.5, rounds toward +∞.
  static int _roundHalfUp(double value) {
    return (value + 0.5).floor();
  }
}
