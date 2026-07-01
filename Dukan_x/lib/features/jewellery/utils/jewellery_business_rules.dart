// Jewellery — domain rules (clause 2.16 of `bugfix.md`).
//
// Owns purity conversion, making-charges math, and the old-gold-exchange
// credit formula.
//
// CANONICAL PRICING ENGINE (Requirements 7.1, 7.4, 7.5, 1.1, 1.2, 8.4):
// `billTotalPaisa` is the SINGLE canonical pricing engine for jewellery sale
// totals. All money values are integer paise — no doubles/floats for currency.
// The formula multiplies Rate/Gm by metalWeight (via grossWeightMilligrams),
// NEVER by quantity.
//
// Legacy `billTotal` (double-based) is retained for backward compatibility but
// is DEPRECATED — all new callers must use `billTotalPaisa`.

import 'package:decimal/decimal.dart';
import '../../../core/accounting/money_math.dart';

/// Standard documented purities with BIS-standard fineness ratios.
///
/// Each purity maps to a numerator/denominator pair used for integer
/// arithmetic in the canonical pricing engine:
///   - 24K: 999/1000 (essentially pure gold per BIS standard)
///   - 22K: 916/1000 (916 KDM hallmark)
///   - 18K: 750/1000
///   - 14K: 585/1000
enum GoldPurity {
  k24,
  k22,
  k18,
  k14;

  /// BIS-standard fineness numerator for integer arithmetic.
  /// The denominator is always 1000.
  int get finenessNumerator {
    switch (this) {
      case GoldPurity.k24:
        return 999;
      case GoldPurity.k22:
        return 916;
      case GoldPurity.k18:
        return 750;
      case GoldPurity.k14:
        return 585;
    }
  }

  /// Common denominator for all fineness ratios.
  static const int finenessDenominator = 1000;

  // ---------------------------------------------------------------------------
  // DISPLAY & SERIALIZATION (Requirement 15.6)
  // ---------------------------------------------------------------------------

  /// Human-readable label used in UI dropdowns and serialized to BillItem.purity.
  ///
  /// This is the canonical String representation stored in the shared BillItem
  /// model. Use [GoldPurity.tryFromString] to parse it back.
  String get displayLabel {
    switch (this) {
      case GoldPurity.k24:
        return '24K';
      case GoldPurity.k22:
        return '22K';
      case GoldPurity.k18:
        return '18K';
      case GoldPurity.k14:
        return '14K';
    }
  }

  // ---------------------------------------------------------------------------
  // PARSING HELPERS (Requirement 15.6)
  // ---------------------------------------------------------------------------

  /// Parses a purity string to [GoldPurity], returning `null` if unrecognized.
  ///
  /// Accepts common representations:
  ///   - Display labels: '24K', '22K', '18K', '14K' (case-insensitive)
  ///   - BIS codes: '999', '916', '750', '585'
  ///   - Enum names: 'k24', 'k22', 'k18', 'k14'
  ///
  /// Used to validate that BillItem.purity contains a valid GoldPurity value
  /// on the jewellery billing path, without changing BillItem's type (which is
  /// shared across all business types).
  static GoldPurity? tryFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      // Display labels (canonical form stored in BillItem.purity)
      case '24k':
        return GoldPurity.k24;
      case '22k':
        return GoldPurity.k22;
      case '18k':
        return GoldPurity.k18;
      case '14k':
        return GoldPurity.k14;
      // BIS fineness codes
      case '999':
        return GoldPurity.k24;
      case '916':
        return GoldPurity.k22;
      case '750':
        return GoldPurity.k18;
      case '585':
        return GoldPurity.k14;
      // Enum .name values
      case 'k24':
        return GoldPurity.k24;
      case 'k22':
        return GoldPurity.k22;
      case 'k18':
        return GoldPurity.k18;
      case 'k14':
        return GoldPurity.k14;
      default:
        return null;
    }
  }

  /// Parses a purity string to [GoldPurity], throwing [ArgumentError] if
  /// the value is not a recognized purity representation.
  ///
  /// Prefer [tryFromString] in UI/form paths where invalid input is expected.
  /// Use this in domain paths where an invalid purity indicates a programming
  /// error or data corruption.
  static GoldPurity fromString(String value) {
    final result = tryFromString(value);
    if (result == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Not a valid GoldPurity string. '
            'Expected one of: 24K, 22K, 18K, 14K, 999, 916, 750, 585, '
            'k24, k22, k18, k14.',
      );
    }
    return result;
  }

  /// Whether the given string is a valid [GoldPurity] representation.
  ///
  /// Use this for validation without allocating a result — e.g., form validators
  /// or BillItem validation on the jewellery billing path.
  static bool isValid(String? value) => tryFromString(value) != null;
}

class JewelleryBusinessRules {
  JewelleryBusinessRules._();

  // ---------------------------------------------------------------------------
  // UPPER BOUND CONSTANT (Requirement 15.1)
  // ---------------------------------------------------------------------------

  /// Maximum allowed bill/credit total in paise: ₹10 crore = 10,00,00,000 rupees
  /// = 10_000_000_00 paise = 1_000_000_000 (10 billion paise).
  ///
  /// Any computed result exceeding this bound is clamped to this value rather
  /// than returning an invalid or absurdly large total. This guards against
  /// accidental typos in weight/rate fields (e.g., entering grams as milligrams
  /// or per-10g rate as per-gram) that could produce multi-hundred-crore totals.
  static const int maxTotalPaisa = 10000000000; // ₹10 crore in paise

  // ---------------------------------------------------------------------------
  // CANONICAL INTEGER-PAISE PRICING ENGINE
  // Requirements: 7.1, 7.4, 7.5, 1.1, 1.2, 8.4
  // ---------------------------------------------------------------------------

  /// Computes the jewellery bill total in integer paise using pure integer
  /// arithmetic with documented half-up rounding.
  ///
  /// This is the SINGLE CANONICAL pricing engine for all jewellery sale totals.
  /// The formula multiplies Rate/Gm by metal weight (never by quantity).
  ///
  /// ## Formula
  ///
  /// ```
  /// metalValuePaisa = halfUpRound(
  ///   grossWeightMilligrams * finenessNumerator * ratePerGram24KPaisa
  ///   / (1000 * finenessDenominator)
  /// )
  ///
  /// total = metalValuePaisa + makingChargesPaisa + taxPaisa - discountPaisa
  /// ```
  ///
  /// ## Rounding rule (documented half-up to paise)
  ///
  /// The division `(numerator) / (1000 * 1000)` i.e. `/ 1_000_000` uses
  /// integer half-up rounding:
  ///   result = (dividend + divisor ~/ 2) ~/ divisor
  ///
  /// This rounds 0.5 paise UP (toward positive infinity), matching the
  /// convention used in Indian jewellery trade billing.
  ///
  /// ## Why milligrams?
  ///
  /// Weight is carried as integer milligrams (1 gram = 1000 milligrams) so
  /// the entire computation stays in integer arithmetic without introducing
  /// floating-point for sub-gram weights (e.g., 10.5g = 10500 milligrams).
  ///
  /// ## Example
  ///
  /// ```dart
  /// // 10g 22K gold at Rs.6000/g, Rs.500 making, no tax/discount
  /// billTotalPaisa(
  ///   grossWeightMilligrams: 10000,    // 10g
  ///   purity: GoldPurity.k22,          // fineness 916/1000
  ///   ratePerGram24KPaisa: 600000,     // Rs.6000.00 per gram
  ///   makingChargesPaisa: 50000,       // Rs.500.00
  /// );
  /// // metalValue = halfUp(10000 * 916 * 600000 / 1_000_000)
  /// //           = halfUp(5_496_000_000_000 / 1_000_000)
  /// //           = 5_496_000 paise = Rs.54,960.00
  /// // total     = 5_496_000 + 50_000 = 5_546_000 paise = Rs.55,460.00
  /// ```
  static int billTotalPaisa({
    required int grossWeightMilligrams,
    required GoldPurity purity,
    required int ratePerGram24KPaisa,
    int makingChargesPaisa = 0,
    int taxPaisa = 0,
    int discountPaisa = 0,
  }) {
    // Guard: negative or zero weight yields zero (no sale).
    if (grossWeightMilligrams <= 0) return 0;

    // Guard: negative rate is invalid — yield zero rather than a negative total.
    if (ratePerGram24KPaisa < 0) return 0;

    final int metalValuePaisa = _metalValuePaisa(
      grossWeightMilligrams: grossWeightMilligrams,
      purity: purity,
      ratePerGram24KPaisa: ratePerGram24KPaisa,
    );

    final int total =
        metalValuePaisa + makingChargesPaisa + taxPaisa - discountPaisa;

    // Clamp to [0, maxTotalPaisa] — a negative total (e.g., massive discount)
    // is not valid, and totals beyond the upper bound indicate an input error
    // (Requirement 15.1).
    if (total < 0) return 0;
    if (total > maxTotalPaisa) return maxTotalPaisa;
    return total;
  }

  /// Computes the metal value in paise using integer arithmetic with half-up
  /// rounding.
  ///
  /// Formula:
  ///   metalValuePaisa = halfUp(
  ///     grossWeightMilligrams * finenessNumerator * ratePerGram24KPaisa
  ///     / (1000 * finenessDenominator)
  ///   )
  ///
  /// The divisor is 1000 (mg->g) * 1000 (finenessDenominator) = 1_000_000.
  static int _metalValuePaisa({
    required int grossWeightMilligrams,
    required GoldPurity purity,
    required int ratePerGram24KPaisa,
  }) {
    // Compute the dividend. Using BigInt to avoid overflow for large weights/rates.
    // e.g., 100_000 mg * 999 * 10_000_00 paise could overflow int64.
    final BigInt dividend =
        BigInt.from(grossWeightMilligrams) *
        BigInt.from(purity.finenessNumerator) *
        BigInt.from(ratePerGram24KPaisa);

    // Divisor = 1000 (mg-to-gram) * 1000 (fineness denominator) = 1_000_000
    const int divisorInt = 1000 * GoldPurity.finenessDenominator; // 1_000_000
    final BigInt divisor = BigInt.from(divisorInt);

    // Half-up rounding: (dividend + divisor ~/ 2) ~/ divisor
    // This rounds 0.5 UP (toward positive infinity), the standard Indian
    // jewellery trade rounding rule for paise.
    final BigInt rounded = (dividend + divisor ~/ BigInt.two) ~/ divisor;

    return rounded.toInt();
  }

  /// Old-gold-exchange credit in integer paise: grossWeight * fineness * buybackRate.
  ///
  /// Uses the same integer arithmetic and half-up rounding as [billTotalPaisa].
  /// Buyback rate is typically a few rupees below the day's selling rate;
  /// the caller passes whatever rate the shop honours.
  ///
  /// Guarded: negative weight/rate yields 0; result clamped to [maxTotalPaisa]
  /// (Requirement 15.1).
  static int exchangeCreditPaisa({
    required int grossWeightMilligrams,
    required GoldPurity purity,
    required int buybackRatePerGram24KPaisa,
  }) {
    // Guard: negative or zero weight yields zero.
    if (grossWeightMilligrams <= 0) return 0;

    // Guard: negative buyback rate is invalid — yield zero.
    if (buybackRatePerGram24KPaisa < 0) return 0;

    final int credit = _metalValuePaisa(
      grossWeightMilligrams: grossWeightMilligrams,
      purity: purity,
      ratePerGram24KPaisa: buybackRatePerGram24KPaisa,
    );

    // Clamp to upper bound (Requirement 15.1).
    if (credit > maxTotalPaisa) return maxTotalPaisa;
    return credit;
  }

  // ---------------------------------------------------------------------------
  // LEGACY API (DEPRECATED — retained for backward compatibility)
  // ---------------------------------------------------------------------------

  /// Fineness (0..1) for a documented purity. 24K -> 1.0, 22K -> 22/24, etc.
  ///
  /// @Deprecated('Use GoldPurity.finenessNumerator / GoldPurity.finenessDenominator instead')
  static double finenessFor(GoldPurity p) {
    switch (p) {
      case GoldPurity.k24:
        return 1.0;
      case GoldPurity.k22:
        return 22 / 24;
      case GoldPurity.k18:
        return 18 / 24;
      case GoldPurity.k14:
        return 14 / 24;
    }
  }

  /// Bill total = (gross weight * fineness * ratePerGram24K) +
  /// makingCharges + tax - discount.
  ///
  /// @Deprecated('Use billTotalPaisa instead — the canonical integer-paise engine')
  static double billTotal({
    required double grossWeightGrams,
    required GoldPurity purity,
    required double ratePerGram24K,
    double makingCharges = 0,
    double taxAmount = 0,
    double discount = 0,
  }) {
    if (grossWeightGrams < 0) return 0;
    final fineness = Decimal.parse(finenessFor(purity).toString());
    final goldValue =
        Decimal.parse(grossWeightGrams.toString()) *
        fineness *
        Decimal.parse(ratePerGram24K.toString());
    final gross =
        goldValue +
        Decimal.parse(makingCharges.toString()) +
        Decimal.parse(taxAmount.toString()) -
        Decimal.parse(discount.toString());
    return MoneyMath.roundTo2(gross).toDouble();
  }

  /// Old-gold-exchange credit: gross weight * fineness * buybackRate.
  ///
  /// @Deprecated('Use exchangeCreditPaisa instead — the canonical integer-paise engine')
  static double exchangeCredit({
    required double grossWeightGrams,
    required GoldPurity purity,
    required double buybackRatePerGram24K,
  }) {
    if (grossWeightGrams < 0) return 0;
    final fineness = Decimal.parse(finenessFor(purity).toString());
    final value =
        Decimal.parse(grossWeightGrams.toString()) *
        fineness *
        Decimal.parse(buybackRatePerGram24K.toString());
    return MoneyMath.roundTo2(value).toDouble();
  }
}
