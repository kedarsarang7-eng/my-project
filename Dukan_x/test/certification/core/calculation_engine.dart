/// Calculation engine for the Certification_System.
///
/// Provides fixed-precision decimal arithmetic for tax, GST, VAT, discounts,
/// invoice totals, payment reconciliation, inventory adjustments, and
/// credit/debit entries. All monetary results are at scale 2 (half-up rounding),
/// and quantity results are at scale 3.
///
/// Invalid inputs (null, non-numeric, illegally negative, or outside the domain
/// [0.01, 999,999,999.99]) return a [CalcError] and persist nothing.
///
/// Requirements: 2.1, 2.2, 2.3, 2.6, 2.7
library;

import 'package:decimal/decimal.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Sealed result type for all calculation outputs.
sealed class CalcResult {
  const CalcResult();
}

/// A successful calculation result carrying a fixed-precision [Decimal] value.
class CalcValue extends CalcResult {
  const CalcValue(this.value);

  /// The computed result. Monetary values are at scale 2; quantities at scale 3.
  final Decimal value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CalcValue && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CalcValue($value)';
}

/// An error result indicating invalid input or a domain violation.
class CalcError extends CalcResult {
  const CalcError(this.code, this.message);

  /// A short machine-readable error code (e.g. 'INVALID_INPUT', 'OUT_OF_DOMAIN').
  final String code;

  /// A human-readable description of what went wrong.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalcError && other.code == code && other.message == message);

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'CalcError($code: $message)';
}

// ---------------------------------------------------------------------------
// Engine implementation
// ---------------------------------------------------------------------------

/// Fixed-precision calculation engine for the Certification_System.
///
/// All monetary operations validate inputs against [kMinMonetary]–[kMaxMonetary]
/// before computing. Quantities are validated as non-negative (≥ 0).
///
/// Rounding: half-up to 2 decimal places for monetary values (Req 2.3).
class CalculationEngine {
  /// Minimum valid monetary input (inclusive).
  static final Decimal kMinMonetary = Decimal.parse('0.01');

  /// Maximum valid monetary input (inclusive).
  static final Decimal kMaxMonetary = Decimal.parse('999999999.99');

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Rounds [raw] half-up to 2 decimal places (Req 2.3).
  ///
  /// This is a pure rounding operation — it does NOT validate against the
  /// monetary domain. Use it for intermediate or final rounding of computed
  /// values.
  CalcResult roundCurrency(Decimal raw) {
    return CalcValue(_roundHalfUp2(raw));
  }

  /// Computes total tax: `amount * rate` where rate is a decimal fraction
  /// (e.g. 0.18 for 18%).
  ///
  /// Both [amount] and [rate] must be within the monetary domain.
  CalcResult taxTotal(Decimal? amount, Decimal? rate) {
    final amountErr = _validateMonetary(amount, 'amount');
    if (amountErr != null) return amountErr;
    final rateErr = _validateRate(rate, 'rate');
    if (rateErr != null) return rateErr;

    final result = amount! * rate!;
    return CalcValue(_roundHalfUp2(result));
  }

  /// Computes GST amount: `amount * gstRate`.
  ///
  /// [amount] must be in the monetary domain; [gstRate] must be a valid rate.
  CalcResult gst(Decimal? amount, Decimal? gstRate) {
    final amountErr = _validateMonetary(amount, 'amount');
    if (amountErr != null) return amountErr;
    final rateErr = _validateRate(gstRate, 'gstRate');
    if (rateErr != null) return rateErr;

    final result = amount! * gstRate!;
    return CalcValue(_roundHalfUp2(result));
  }

  /// Computes VAT amount: `amount * vatRate`.
  ///
  /// [amount] must be in the monetary domain; [vatRate] must be a valid rate.
  CalcResult vat(Decimal? amount, Decimal? vatRate) {
    final amountErr = _validateMonetary(amount, 'amount');
    if (amountErr != null) return amountErr;
    final rateErr = _validateRate(vatRate, 'vatRate');
    if (rateErr != null) return rateErr;

    final result = amount! * vatRate!;
    return CalcValue(_roundHalfUp2(result));
  }

  /// Computes discount amount: `amount * discountRate`.
  ///
  /// [amount] must be in the monetary domain; [discountRate] must be a valid
  /// rate in [0, 1].
  CalcResult discount(Decimal? amount, Decimal? discountRate) {
    final amountErr = _validateMonetary(amount, 'amount');
    if (amountErr != null) return amountErr;
    final rateErr = _validateRate(discountRate, 'discountRate');
    if (rateErr != null) return rateErr;

    final result = amount! * discountRate!;
    return CalcValue(_roundHalfUp2(result));
  }

  /// Computes invoice total: `subtotal + taxAmount - discountAmount`.
  ///
  /// All three inputs must be in the monetary domain.
  CalcResult invoiceTotal(
    Decimal? subtotal,
    Decimal? taxAmount,
    Decimal? discountAmount,
  ) {
    final subtotalErr = _validateMonetary(subtotal, 'subtotal');
    if (subtotalErr != null) return subtotalErr;
    final taxErr = _validateMonetary(taxAmount, 'taxAmount');
    if (taxErr != null) return taxErr;
    final discountErr = _validateNonNegativeMonetary(
      discountAmount,
      'discountAmount',
    );
    if (discountErr != null) return discountErr;

    final result = subtotal! + taxAmount! - discountAmount!;
    return CalcValue(_roundHalfUp2(result));
  }

  /// Reconciles a payment against an outstanding amount.
  ///
  /// Returns the remaining balance: `outstanding - payment`.
  /// Both must be in the monetary domain.
  CalcResult reconcilePayment(Decimal? outstanding, Decimal? payment) {
    final outErr = _validateMonetary(outstanding, 'outstanding');
    if (outErr != null) return outErr;
    final payErr = _validateMonetary(payment, 'payment');
    if (payErr != null) return payErr;

    final result = outstanding! - payment!;
    return CalcValue(_roundHalfUp2(result));
  }

  /// Adjusts inventory: `currentQty + adjustment`.
  ///
  /// [currentQty] must be non-negative (≥ 0). [adjustment] may be negative
  /// (stock reduction) or positive (stock addition). Result is at scale 3.
  CalcResult inventoryAdjustment(Decimal? currentQty, Decimal? adjustment) {
    final currentErr = _validateQuantity(currentQty, 'currentQty');
    if (currentErr != null) return currentErr;
    final adjErr = _validateAdjustment(adjustment, 'adjustment');
    if (adjErr != null) return adjErr;

    final result = currentQty! + adjustment!;
    return CalcValue(_roundScale3(result));
  }

  /// Records a credit entry (amount added to an account).
  ///
  /// [amount] must be in the monetary domain.
  CalcResult creditEntry(Decimal? amount) {
    final err = _validateMonetary(amount, 'amount');
    if (err != null) return err;

    return CalcValue(_roundHalfUp2(amount!));
  }

  /// Records a debit entry (amount subtracted from an account).
  ///
  /// [amount] must be in the monetary domain.
  CalcResult debitEntry(Decimal? amount) {
    final err = _validateMonetary(amount, 'amount');
    if (err != null) return err;

    // Debit is the negation of the amount.
    return CalcValue(_roundHalfUp2(-amount!));
  }

  // -------------------------------------------------------------------------
  // Validation helpers
  // -------------------------------------------------------------------------

  /// Validates a monetary input is non-null and within [kMinMonetary, kMaxMonetary].
  CalcError? _validateMonetary(Decimal? value, String field) {
    if (value == null) {
      return CalcError('NULL_INPUT', '$field must not be null');
    }
    if (value < kMinMonetary) {
      return CalcError(
        'OUT_OF_DOMAIN',
        '$field ($value) is below minimum $kMinMonetary',
      );
    }
    if (value > kMaxMonetary) {
      return CalcError(
        'OUT_OF_DOMAIN',
        '$field ($value) exceeds maximum $kMaxMonetary',
      );
    }
    return null;
  }

  /// Validates a monetary input that may be zero (e.g. discount amount can be 0).
  CalcError? _validateNonNegativeMonetary(Decimal? value, String field) {
    if (value == null) {
      return CalcError('NULL_INPUT', '$field must not be null');
    }
    if (value < Decimal.zero) {
      return CalcError(
        'NEGATIVE_NOT_PERMITTED',
        '$field ($value) must not be negative',
      );
    }
    if (value > kMaxMonetary) {
      return CalcError(
        'OUT_OF_DOMAIN',
        '$field ($value) exceeds maximum $kMaxMonetary',
      );
    }
    return null;
  }

  /// Validates a rate (percentage as fraction). Must be non-null and in [0, 1].
  CalcError? _validateRate(Decimal? value, String field) {
    if (value == null) {
      return CalcError('NULL_INPUT', '$field must not be null');
    }
    if (value < Decimal.zero) {
      return CalcError(
        'NEGATIVE_NOT_PERMITTED',
        '$field ($value) must not be negative',
      );
    }
    if (value > Decimal.one) {
      return CalcError(
        'OUT_OF_DOMAIN',
        '$field ($value) exceeds maximum 1.0 (100%)',
      );
    }
    return null;
  }

  /// Validates a quantity (non-negative).
  CalcError? _validateQuantity(Decimal? value, String field) {
    if (value == null) {
      return CalcError('NULL_INPUT', '$field must not be null');
    }
    if (value < Decimal.zero) {
      return CalcError(
        'NEGATIVE_NOT_PERMITTED',
        '$field ($value) must not be negative',
      );
    }
    return null;
  }

  /// Validates an inventory adjustment (may be negative for reductions, but
  /// must not be null).
  CalcError? _validateAdjustment(Decimal? value, String field) {
    if (value == null) {
      return CalcError('NULL_INPUT', '$field must not be null');
    }
    // Adjustments can be negative (stock reduction) — no further constraint.
    return null;
  }

  // -------------------------------------------------------------------------
  // Rounding helpers
  // -------------------------------------------------------------------------

  /// Rounds [value] half-up to 2 decimal places.
  ///
  /// Half-up: when the digit immediately after the rounding position is exactly
  /// 5, the value is rounded away from zero.
  ///
  /// Examples:
  ///   2.345 → 2.35
  ///   2.344 → 2.34
  ///   -2.345 → -2.35
  static Decimal _roundHalfUp2(Decimal value) {
    // Shift left by 2 decimal places, apply half-up rounding, shift back.
    // Uses string-based conversion to avoid Rational return from division.
    final shifted = value * Decimal.fromInt(100);

    // Dart's BigInt division truncates toward zero; for half-up we need to add
    // 0.5 (or subtract for negatives) before truncating.
    final BigInt truncated;
    if (shifted >= Decimal.zero) {
      // positive or zero: add 0.5 then floor
      truncated = (shifted + Decimal.parse('0.5')).floor().toBigInt();
    } else {
      // negative: subtract 0.5 then ceil (round away from zero)
      truncated = (shifted - Decimal.parse('0.5')).ceil().toBigInt();
    }

    // Convert integer back to Decimal at scale 2 via string formatting.
    final intVal = truncated.toInt();
    final sign = intVal < 0 ? '-' : '';
    final abs = intVal.abs();
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    return Decimal.parse('$sign$whole.$frac');
  }

  /// Rounds [value] to 3 decimal places (quantity scale).
  static Decimal _roundScale3(Decimal value) {
    final shifted = value * Decimal.fromInt(1000);

    final BigInt truncated;
    if (shifted >= Decimal.zero) {
      truncated = (shifted + Decimal.parse('0.5')).floor().toBigInt();
    } else {
      truncated = (shifted - Decimal.parse('0.5')).ceil().toBigInt();
    }

    // Convert integer back to Decimal at scale 3 via string formatting.
    final intVal = truncated.toInt();
    final sign = intVal < 0 ? '-' : '';
    final abs = intVal.abs();
    final whole = abs ~/ 1000;
    final frac = (abs % 1000).toString().padLeft(3, '0');
    return Decimal.parse('$sign$whole.$frac');
  }
}
