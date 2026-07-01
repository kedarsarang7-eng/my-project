import 'package:decimal/decimal.dart';

/// MoneyMath — fixed-precision aggregation helpers for monetary `double`s.
///
/// Per `bugfix.md` clause 2.6 every monetary calculation must use
/// fixed-precision arithmetic so floating-point drift does not creep into
/// invoices, GST returns, ledgers, or payroll. The shipped
/// `BillCalculator` already performs per-bill totals with `Decimal`; this
/// helper is the equivalent for code that *aggregates* already-computed
/// `double` totals (GST returns, ledger summaries, dashboard rollups,
/// commission settlements).
///
/// Public API is intentionally minimal:
///   * `sum` — fixed-precision sum of an iterable of doubles.
///   * `addAll` — same, but returns a `Decimal` (caller decides rounding).
///   * `roundTo2` — half-up rounding to paise, matching `BillCalculator`.
///
/// All callers that previously did `total += value` over a stream of
/// monetary doubles should switch to `MoneyMath.sum` so the running
/// accumulator stays in `Decimal` until the final `toDouble()` call.
class MoneyMath {
  MoneyMath._();

  /// Fixed-precision sum of monetary doubles, returned as a `double`
  /// rounded to 2 decimals (paise). Pass an empty iterable to get 0.0.
  static double sum(Iterable<double> values) {
    return roundTo2(addAll(values)).toDouble();
  }

  /// Fixed-precision sum returned as a raw `Decimal`. Use this when the
  /// caller needs to keep aggregating before rounding.
  static Decimal addAll(Iterable<double> values) {
    var acc = Decimal.zero;
    for (final v in values) {
      // `Decimal.parse(v.toString())` matches the `BillCalculator`
      // convention and avoids double-precision artefacts that would creep
      // in via `Decimal.parse(v.toStringAsFixed(...))` on rare edge cases.
      acc += Decimal.parse(v.toString());
    }
    return acc;
  }

  /// Half-up rounding to 2 decimal places (paise). Centralises the
  /// rounding mode so every monetary aggregation matches the documented
  /// rule. Mirrors the private helper used in `BillCalculator`.
  static Decimal roundTo2(Decimal value) {
    final shifted = (value * Decimal.fromInt(100)).round();
    return (shifted.toBigInt().toInt() / 100).toString().let(
      (s) => Decimal.parse(s),
    );
  }
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
