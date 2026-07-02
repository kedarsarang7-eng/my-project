/// Integer-paise money helpers for the wholesale domain.
///
/// All monetary values in the wholesale vertical are represented as `int`
/// (Indian Paise — 1/100th of a Rupee). No `double`, `float`, or `Decimal`
/// type is used for currency. Rupee display is a presentation-time conversion
/// only (`paise ~/ 100` for whole rupees, `paise % 100` for the fractional part).
///
/// This eliminates floating-point rounding errors in billing, pricing,
/// and settlement calculations.
class PaiseMoney {
  // Private constructor — this is a utility class, not instantiable.
  PaiseMoney._();

  /// Converts a whole-rupee integer amount to paise.
  ///
  /// Example: `rupeesToPaise(150)` → `15000`
  static int rupeesToPaise(int rupees) => rupees * 100;

  /// Extracts the whole-rupee component from a paise value.
  ///
  /// Example: `wholeRupees(15075)` → `150`
  static int wholeRupees(int paise) => paise ~/ 100;

  /// Extracts the fractional paise component (0–99) from a paise value.
  ///
  /// Example: `fractionalPaise(15075)` → `75`
  static int fractionalPaise(int paise) => paise.abs() % 100;

  /// Formats a paise value as a rupee string (e.g., "₹150.75").
  ///
  /// Uses integer division only — no floating-point intermediary.
  static String formatRupees(int paise) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupees = absPaise ~/ 100;
    final fraction = absPaise % 100;
    final sign = isNegative ? '-' : '';
    return '$sign₹$rupees.${fraction.toString().padLeft(2, '0')}';
  }

  /// Adds two paise amounts (pure integer addition).
  static int add(int a, int b) => a + b;

  /// Subtracts [b] from [a] in paise (pure integer subtraction).
  static int subtract(int a, int b) => a - b;

  /// Multiplies a per-unit paise rate by a quantity.
  ///
  /// Example: `multiply(perUnitPaise: 500, quantity: 12)` → `6000`
  /// (i.e., ₹5.00 × 12 = ₹60.00)
  static int multiply({required int perUnitPaise, required int quantity}) =>
      perUnitPaise * quantity;
}
