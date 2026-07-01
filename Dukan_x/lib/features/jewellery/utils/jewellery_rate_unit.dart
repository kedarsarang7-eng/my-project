/// Single conversion boundary: per-10g paise ↔ per-gram paise.
///
/// **Why this class exists:**
/// [GoldRateCard] stores rates as per-10-gram paise values
/// (`gold24KPer10gPaisa`, etc.), but [JewelleryBusinessRules] consumes
/// per-gram values. This helper is the ONE AND ONLY place that conversion
/// happens. Callers MUST NOT re-divide or re-multiply the returned value.
///
/// **Rounding rule (Requirement 6.4):**
/// Integer truncation via Dart's `~/` operator (floor division for
/// non-negative paise). For a per-10g value not evenly divisible by 10,
/// the fractional sub-paise remainder is truncated (lost).
///
/// Example: 54321 per-10g → 5432 per-gram (truncates 0.1 paise).
///
/// This is the SINGLE DOCUMENTED BOUNDARY for rate-unit conversion.
/// Requirements: 6.1, 6.2, 6.4.
class JewelleryRateUnit {
  JewelleryRateUnit._();

  /// Converts a per-10-gram paise value to a per-gram paise value.
  ///
  /// Uses integer division (`~/`) — no floating-point arithmetic is involved.
  /// The result truncates any fractional paise (floor for non-negative values).
  ///
  /// ```dart
  /// JewelleryRateUnit.perGramFromPer10g(54321); // => 5432
  /// JewelleryRateUnit.perGramFromPer10g(50000); // => 5000
  /// ```
  static int perGramFromPer10g(int per10gPaisa) {
    return per10gPaisa ~/ 10;
  }

  /// Inverse conversion: per-gram paise back to per-10g paise.
  ///
  /// Provided for documentation and testing symmetry. Note that
  /// `per10gFromPerGram(perGramFromPer10g(x))` may not equal `x` when
  /// `x` is not evenly divisible by 10 (the truncation in [perGramFromPer10g]
  /// is lossy by up to 9 paise).
  ///
  /// ```dart
  /// JewelleryRateUnit.per10gFromPerGram(5432); // => 54320
  /// ```
  static int per10gFromPerGram(int perGramPaisa) {
    return perGramPaisa * 10;
  }
}
