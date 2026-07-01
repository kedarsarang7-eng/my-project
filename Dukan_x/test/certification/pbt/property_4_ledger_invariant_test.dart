// Feature: comprehensive-test-certification, Property 4
//
// Property 4: Ledger balance invariant.
// For any subtotal, discount in [0..subtotal], and payment received, the
// expected ledger balance equals subtotal − discount − payment, computed at
// scale 2.
//
// **Validates: Requirements 5.2**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_4_ledger_invariant_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/invariants.dart';
import '../pbt/generators.dart';

void main() {
  final ledger = LedgerInvariant();

  group('Feature: comprehensive-test-certification, Property 4: '
      'Ledger balance invariant', () {
    test('Property 4: expectedBalance(subtotal, discount, payment) == '
        'subtotal - discount - payment at scale 2 for all valid inputs', () {
      final held = forAll(
        (Decimal subtotal, Decimal discountRate, Decimal payment) {
          // Derive discount <= subtotal by multiplying subtotal * rate [0, 1].
          // Round to scale 2 to stay in monetary domain.
          final discountRaw = subtotal * discountRate;
          final discount = _roundHalfUpScale2(discountRaw);

          // Compute reference balance independently.
          final rawBalance = subtotal - discount - payment;
          final expectedBalance = _roundHalfUpScale2(rawBalance);

          // The invariant function should yield the same result.
          final actual = ledger.expectedBalance(subtotal, discount, payment);

          return actual == expectedBalance;
        },
        [moneyGen, rateGen, moneyGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}

/// Reference half-up rounding at scale 2 — mirrors the production logic in
/// LedgerInvariant but re-derived here so the property is not tautological.
Decimal _roundHalfUpScale2(Decimal value) {
  final hundred = Decimal.fromInt(100);
  final shifted = value * hundred;
  final truncated = shifted.toBigInt();
  final remainder = shifted - Decimal.parse(truncated.toString());

  final halfPos = Decimal.parse('0.5');
  final halfNeg = Decimal.parse('-0.5');

  BigInt rounded;
  if (remainder >= halfPos) {
    rounded = truncated + BigInt.one;
  } else if (remainder <= halfNeg) {
    rounded = truncated - BigInt.one;
  } else {
    rounded = truncated;
  }

  return (Decimal.parse(rounded.toString()) / hundred).toDecimal();
}
