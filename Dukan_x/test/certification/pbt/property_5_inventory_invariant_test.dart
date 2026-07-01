// Feature: comprehensive-test-certification, Property 5
// ============================================================================
// Property 5: Inventory on-hand invariant
// **Validates: Requirements 5.3**
// ============================================================================
// For any received quantity and any invoiced quantity, the expected final
// on-hand = received − invoiced, computed at scale 3.
//
// Unit under test: `InventoryInvariant.expectedOnHand(received, invoiced)`
// from `../core/invariants.dart`.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_5_inventory_invariant_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/invariants.dart';
import 'generators.dart';

void main() {
  group('Property 5: Inventory on-hand invariant', () {
    final invariant = InventoryInvariant();

    test('expectedOnHand(received, invoiced) == received - invoiced at scale 3 '
        'for any received and invoiced quantities', () {
      final held = forAll(
        (Decimal received, Decimal invoiced) {
          final result = invariant.expectedOnHand(received, invoiced);
          final expected = received - invoiced;

          // The result should equal received - invoiced, rounded half-up
          // to scale 3. Since our generators already produce values at
          // scale 3, the subtraction of two scale-3 values is at most
          // scale 3, so no rounding should change the value. We verify
          // the invariant holds exactly.
          return result == _roundHalfUpScale3(expected);
        },
        [quantityGen, quantityGen],
        numRuns: kNumRuns,
      );

      expect(held, isTrue);
    });
  });
}

/// Reference implementation of half-up rounding to scale 3 for verification.
Decimal _roundHalfUpScale3(Decimal value) {
  final thousand = Decimal.fromInt(1000);
  final halfPos = Decimal.parse('0.5');
  final halfNeg = Decimal.parse('-0.5');

  final shifted = value * thousand;
  final truncated = shifted.toBigInt();
  final remainder = shifted - Decimal.parse(truncated.toString());

  BigInt rounded;
  if (remainder >= halfPos) {
    rounded = truncated + BigInt.one;
  } else if (remainder <= halfNeg) {
    rounded = truncated - BigInt.one;
  } else {
    rounded = truncated;
  }

  return (Decimal.parse(rounded.toString()) / thousand).toDecimal();
}
