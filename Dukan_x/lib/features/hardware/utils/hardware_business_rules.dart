// Hardware â€” domain rules (clause 2.16 of `bugfix.md`).
//
// Owns dimension math (length / area / volume) for the hardware module's
// cut-to-size SKUs (paint, plywood, pipe, wire). Centralised so callers
// share the same rounding mode and unit-conversion factors.

class HardwareBusinessRules {
  HardwareBusinessRules._();

  /// Square feet for a rectangle measured in feet.
  static double squareFeet(double lengthFt, double widthFt) {
    if (lengthFt < 0 || widthFt < 0) return 0;
    return _round2(lengthFt * widthFt);
  }

  /// Cubic feet for a box measured in feet.
  static double cubicFeet(double lengthFt, double widthFt, double heightFt) {
    if (lengthFt < 0 || widthFt < 0 || heightFt < 0) return 0;
    return _round2(lengthFt * widthFt * heightFt);
  }

  /// Convert millimetres to feet. 1 ft = 304.8 mm.
  static double mmToFeet(double mm) => _round2(mm / 304.8);

  /// Convert metres to feet. 1 ft = 0.3048 m.
  static double metersToFeet(double m) => _round2(m / 0.3048);

  /// Charge for cut-to-size: priced as `pricePerUnit × ceil(units)` so a
  /// 1.1-foot cut bills as 2 feet. Shop convention; documented in spec.
  static double cutToSizeCharge(double pricePerUnit, double units) {
    if (pricePerUnit < 0 || units < 0) return 0;
    final billable = units.ceilToDouble();
    return _round2(pricePerUnit * billable);
  }

  /// Whether a cut-to-size charge rounded the measured [units] up to the next
  /// whole unit (bugfix.md 2.27). Used to decide whether the invoice must
  /// disclose the round-up.
  static bool cutToSizeWasRoundedUp(double units) {
    if (units <= 0) return false;
    return units.ceilToDouble() != units;
  }

  /// Human-readable disclosure of the cut-to-size round-up convention for the
  /// invoice line (bugfix.md 2.27). Returns `null` when no rounding occurred
  /// (the measured units are already whole), so the note is shown only when it
  /// is actually relevant — making a 1.1 ft cut billed as 2 ft transparent.
  static String? cutToSizeRoundingNote(
    double units, {
    String unitLabel = 'unit',
  }) {
    if (units <= 0) return null;
    final billable = units.ceilToDouble();
    if (billable == units) return null;
    return 'Cut-to-size billed as ${_trim(billable)} $unitLabel '
        '(measured ${_trim(units)} $unitLabel, rounded up to the next whole '
        '$unitLabel).';
  }

  /// Formats a double without a trailing `.0` for whole numbers.
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}
