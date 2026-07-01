// Petrol pump â€” domain rules (clause 2.16 of `bugfix.md`).
//
// Owns nozzle totalizer math, shift settlement, and the
// dispensed-volume formula used at the bowser.

import 'package:decimal/decimal.dart';
import '../../../core/accounting/money_math.dart';

class PetrolPumpBusinessRules {
  PetrolPumpBusinessRules._();

  /// Documented totalizer rollover ceiling. Mechanical totalizers wrap at
  /// 1,000,000 litres; the formula must handle a nozzle whose end reading
  /// is numerically smaller than its start (rolled over once).
  static const double totalizerRolloverLitres = 1000000.0;

  /// Litres dispensed by a single nozzle in a shift, accounting for
  /// totalizer rollover. If [end] >= [start] the answer is `end - start`;
  /// otherwise we add one rollover cycle.
  static double dispensedLitres({
    required double startReading,
    required double endReading,
  }) {
    if (startReading < 0 || endReading < 0) return 0;
    if (endReading >= startReading) {
      return _round3(endReading - startReading);
    }
    return _round3(totalizerRolloverLitres - startReading + endReading);
  }

  /// Sale value for a nozzle = dispensedLitres Ã— pricePerLitre. Rounded
  /// half-up to paise via `MoneyMath`.
  static double saleValue({
    required double dispensedLitres,
    required double pricePerLitre,
  }) {
    if (dispensedLitres < 0 || pricePerLitre < 0) return 0;
    final value =
        Decimal.parse(dispensedLitres.toString()) *
        Decimal.parse(pricePerLitre.toString());
    return MoneyMath.roundTo2(value).toDouble();
  }

  /// Shift cash variance = expectedCash âˆ’ reportedCash. Positive variance
  /// means the cashier is short; negative means surplus.
  static double cashVariance({
    required double expectedCash,
    required double reportedCash,
  }) {
    final v =
        Decimal.parse(expectedCash.toString()) -
        Decimal.parse(reportedCash.toString());
    return MoneyMath.roundTo2(v).toDouble();
  }

  static double _round3(double v) => (v * 1000).roundToDouble() / 1000;
}
