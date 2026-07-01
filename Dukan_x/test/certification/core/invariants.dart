/// Ledger and inventory invariants for the Certification_System.
///
/// These pure functions compute expected balances (ledger) and on-hand
/// quantities (inventory) using the same fixed-precision, half-up rounding
/// convention as the application's BillCalculator and MoneyMath helpers.
///
/// Requirements: 5.2, 5.3
library;

import 'package:decimal/decimal.dart';

/// Expected ledger balance = subtotal - discount - paymentReceived (Req 5.2).
/// Computed at scale 2 (monetary).
class LedgerInvariant {
  /// Returns the expected ledger entry balance after a retail scenario:
  ///   balance = subtotal − discount − payment
  ///
  /// The result is rounded half-up to 2 decimal places, matching the
  /// documented monetary rounding convention in BillCalculator.
  Decimal expectedBalance(Decimal subtotal, Decimal discount, Decimal payment) {
    final raw = subtotal - discount - payment;
    return _roundHalfUpScale2(raw);
  }

  /// Half-up rounding to scale 2 (paise / cents).
  /// Stays entirely within Decimal/BigInt arithmetic — no double escape.
  static Decimal _roundHalfUpScale2(Decimal value) {
    // Shift left by 2 decimals, apply half-up via BigInt, shift back.
    final shifted = value * _hundred;
    final truncated = shifted.toBigInt();
    final remainder = shifted - Decimal.parse(truncated.toString());

    BigInt rounded;
    if (remainder >= _halfPos) {
      rounded = truncated + BigInt.one;
    } else if (remainder <= _halfNeg) {
      rounded = truncated - BigInt.one;
    } else {
      rounded = truncated;
    }

    return (Decimal.parse(rounded.toString()) / _hundred).toDecimal();
  }

  static final Decimal _hundred = Decimal.fromInt(100);
  static final Decimal _halfPos = Decimal.parse('0.5');
  static final Decimal _halfNeg = Decimal.parse('-0.5');
}

/// Expected on-hand = received - invoiced (Req 5.3).
/// Computed at scale 3 (quantity).
class InventoryInvariant {
  /// Returns the expected on-hand inventory quantity:
  ///   onHand = received − invoiced
  ///
  /// The result is rounded half-up to 3 decimal places, matching the
  /// documented quantity precision convention.
  Decimal expectedOnHand(Decimal received, Decimal invoiced) {
    final raw = received - invoiced;
    return _roundHalfUpScale3(raw);
  }

  /// Half-up rounding to scale 3 (fractional units, e.g. kg, litres).
  /// Stays entirely within Decimal/BigInt arithmetic — no double escape.
  static Decimal _roundHalfUpScale3(Decimal value) {
    // Shift left by 3 decimals, apply half-up via BigInt, shift back.
    final shifted = value * _thousand;
    final truncated = shifted.toBigInt();
    final remainder = shifted - Decimal.parse(truncated.toString());

    BigInt rounded;
    if (remainder >= _halfPos) {
      rounded = truncated + BigInt.one;
    } else if (remainder <= _halfNeg) {
      rounded = truncated - BigInt.one;
    } else {
      rounded = truncated;
    }

    return (Decimal.parse(rounded.toString()) / _thousand).toDecimal();
  }

  static final Decimal _thousand = Decimal.fromInt(1000);
  static final Decimal _halfPos = Decimal.parse('0.5');
  static final Decimal _halfNeg = Decimal.parse('-0.5');
}
