// Decoration & catering — domain rules.
//
// Owns quote-to-invoice conversion math. The percentage-based model
// (computeQuoteTotalPct) is the canonical implementation; the old absolute-
// discount model (computeQuoteTotal) is retained but deprecated.
//
// Also owns the AdvanceConfig for quote→booking conversion (Requirement 11).

import 'package:decimal/decimal.dart';
import '../../../core/accounting/money_math.dart';
import 'dc_money_math.dart';

// ---------------------------------------------------------------------------
// AdvanceConfig — configurable advance percentage for quote→booking conversion
// ---------------------------------------------------------------------------
// Per Requirement 11.1: replace "advance defaults to 100%" with a configurable
// advance percentage. Default 50%, accepted range [30, 50] inclusive.
// Per Requirement 11.2: values outside [30, 50] are rejected, prior value
// retained, and a range error presented.
// ---------------------------------------------------------------------------

/// Configurable advance percentage applied on quote→booking conversion.
/// Default 50%, accepted range [30, 50] inclusive. Stored per tenant/business config.
class AdvanceConfig {
  /// Integer percent in [30, 50]; default 50.
  final int advancePct;

  const AdvanceConfig({this.advancePct = 50});

  /// Whether this configuration holds a valid advance percentage.
  bool get isValid => advancePct >= 30 && advancePct <= 50;

  /// Computes the advance amount in integer paise from a total (paise).
  ///
  /// Uses `DcMoneyMath.round2` for half-up rounding:
  /// `advanceAmount = round2(totalPaise * advancePct / 100)`
  ///
  /// Returns null if the computed amount is out of bounds (< 0 or > total),
  /// which should reject the conversion per Requirement 11.5.
  int? computeAdvancePaise(int totalPaise) {
    if (!isValid) return null;
    final advanceAmount = DcMoneyMath.round2(totalPaise * advancePct / 100.0);
    // Validate: 0 <= advanceAmount <= total (Requirement 11.4)
    if (advanceAmount < 0 || advanceAmount > totalPaise) return null;
    return advanceAmount;
  }

  /// Creates a new [AdvanceConfig] from [newPct] if valid, otherwise returns
  /// null (caller retains the previous config and presents a range error).
  static AdvanceConfig? tryCreate(int newPct) {
    final config = AdvanceConfig(advancePct: newPct);
    return config.isValid ? config : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvanceConfig &&
          runtimeType == other.runtimeType &&
          advancePct == other.advancePct;

  @override
  int get hashCode => advancePct.hashCode;

  @override
  String toString() => 'AdvanceConfig(advancePct: $advancePct)';
}

// ---------------------------------------------------------------------------
// Discount Validation Result — used by validateDiscountPct
// ---------------------------------------------------------------------------

/// Result of a discount percentage validation attempt.
///
/// If [isValid] is true, [value] contains the validated discount percentage.
/// If [isValid] is false, [error] contains a human-readable error message
/// and [value] is null (caller should retain the previous valid discount).
class DiscountValidationResult {
  final double? value;
  final String? error;

  const DiscountValidationResult.success(double validValue)
    : value = validValue,
      error = null;

  const DiscountValidationResult.failure(String errorMessage)
    : value = null,
      error = errorMessage;

  bool get isValid => value != null;

  @override
  String toString() => isValid
      ? 'DiscountValidationResult.success($value)'
      : 'DiscountValidationResult.failure($error)';
}

class DecorationCateringBusinessRules {
  DecorationCateringBusinessRules._();

  // ─────────────────────────────────────────────────────────────────────────
  // Discount percentage validation (Requirement 10.5)
  // ─────────────────────────────────────────────────────────────────────────

  /// Validates a discount percentage value.
  ///
  /// A discount percentage outside [0, 100] is rejected, the previous valid
  /// value should be retained by the caller, and an out-of-range error is
  /// returned (Requirement 10.5 / Property 17).
  ///
  /// Returns [DiscountValidationResult.success] with the validated value if
  /// within bounds, or [DiscountValidationResult.failure] with an error
  /// message identifying the out-of-range discount.
  static DiscountValidationResult validateDiscountPct(double discountPct) {
    if (discountPct < 0 || discountPct > 100) {
      return DiscountValidationResult.failure(
        'Discount percentage $discountPct is out of range. '
        'Must be between 0% and 100%.',
      );
    }
    return DiscountValidationResult.success(discountPct);
  }

  /// **DEPRECATED** — Use [computeQuoteTotalPct] instead.
  ///
  /// This method uses an absolute-discount model which is superseded by the
  /// unified percentage-based discount/tax model (Requirement 10).
  /// Retained for backward compatibility with pre-migration data.
  ///
  /// Quote total = perHeadPrice * headcount - discount + tax.
  /// All monetary inputs are paise-friendly doubles; the result is
  /// half-up rounded to paise via `MoneyMath`.
  @Deprecated('Use computeQuoteTotalPct for the unified percentage-based model')
  static double computeQuoteTotal({
    required double perHeadPrice,
    required int headcount,
    double discount = 0,
    double taxAmount = 0,
  }) {
    if (headcount < 0) return 0;
    final base =
        Decimal.parse(perHeadPrice.toString()) * Decimal.fromInt(headcount);
    final gross =
        base -
        Decimal.parse(discount.toString()) +
        Decimal.parse(taxAmount.toString());
    return MoneyMath.roundTo2(gross).toDouble();
  }

  /// Unified percentage-based discount/tax computation (Requirement 10).
  ///
  /// All amounts are integer **paise**. Both `computeQuoteTotalPct` and
  /// `dc_billing_screen.dart` use this identical formula so grand totals
  /// match to the paise (zero variance):
  ///
  /// ```
  /// discountAmount = round2(subtotalPaise * discountPct / 100)
  /// postDiscount   = subtotalPaise - discountAmount
  /// gstAmount      = round2(postDiscount * gstPct / 100)
  /// grandTotal     = postDiscount + gstAmount
  /// ```
  ///
  /// [subtotalPaise] — sum of line-item amounts in integer paise.
  /// [discountPct]   — discount percentage in [0, 100] with <= 2 dp.
  /// [gstPct]        — GST percentage in [0, 28]; default 18%.
  ///
  /// Returns a record containing all intermediate and final amounts in paise.
  static ({int discountAmount, int postDiscount, int gstAmount, int grandTotal})
  computeQuoteTotalPct({
    required int subtotalPaise,
    required double discountPct,
    required double gstPct,
  }) {
    final discountAmount = DcMoneyMath.round2(
      subtotalPaise * discountPct / 100.0,
    );
    final postDiscount = subtotalPaise - discountAmount;
    final gstAmount = DcMoneyMath.round2(postDiscount * gstPct / 100.0);
    final grandTotal = postDiscount + gstAmount;
    return (
      discountAmount: discountAmount,
      postDiscount: postDiscount,
      gstAmount: gstAmount,
      grandTotal: grandTotal,
    );
  }

  /// Advance booking lock-in window: a customer-side cancellation within
  /// [lockInDays] of the event date forfeits their advance. `forfeit` is
  /// true if the cancellation is inside the window.
  ///
  /// DISPOSITION (Phase 8 / Req 14.4–14.7): This method awaits sign-off to
  /// determine whether it should be wired into the cancellation flow or
  /// removed. Code is unchanged until explicit recorded sign-off is obtained.
  /// Decision options:
  ///   • Wire: integrate into booking-cancellation handler so advance
  ///     forfeiture is evaluated automatically on cancel.
  ///   • Remove: delete this method and its tests (requires sign-off first).
  static bool advanceForfeitedOnCancel(
    DateTime eventDate,
    DateTime cancelDate, {
    int lockInDays = 7,
  }) {
    final cutoff = eventDate.subtract(Duration(days: lockInDays));
    return !cancelDate.isBefore(cutoff);
  }
}
