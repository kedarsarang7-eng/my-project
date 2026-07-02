// ============================================================================
// PROPERTY TEST: Integer-Paise Money Invariant
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 1: Integer-paise money invariant
//
// **Validates: Requirements 1.1, 1.2, 7.5, 9.8, 11.3, 12.7**
//
// Tests PaiseMoney helpers: rupeesToPaise, wholeRupees, fractionalPaise,
// formatRupees, add, subtract, multiply.
//
// ForAll 200 iterations: generate random int values and verify:
//   - All operations produce `int` results (enforced by type system + runtime)
//   - multiply(perUnitPaise: x, quantity: y) == x * y
//   - formatRupees produces correct ₹X.YY format
//   - Rupee/paise decomposition is consistent: wholeRupees * 100 + fractional == abs(paise)
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_paise_money_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/paise_money.dart';

void main() {
  const int kNumRuns = 200;

  group(
    'Feature: wholesale-vertical-remediation, Property 1: Integer-paise money invariant',
    () {
      // -----------------------------------------------------------------------
      // Property 1a: rupeesToPaise always produces an int equal to rupees * 100.
      // -----------------------------------------------------------------------
      test(
        'Property 1a (forAll): rupeesToPaise(r) == r * 100 for all int r',
        () {
          final held = forAll(
            (int r) {
              final paise = PaiseMoney.rupeesToPaise(r);
              // Result must be int (enforced by Dart type system).
              // Verify correctness: rupeesToPaise(r) == r * 100
              return paise == r * 100;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(held, isTrue, reason: 'rupeesToPaise must equal r * 100');
        },
      );

      // -----------------------------------------------------------------------
      // Property 1b: wholeRupees and fractionalPaise decompose correctly.
      // For non-negative paise: wholeRupees(p) * 100 + fractionalPaise(p) == p
      // fractionalPaise is always in 0..99 for any input.
      // -----------------------------------------------------------------------
      test('Property 1b (forAll): wholeRupees(p)*100 + fractionalPaise(p) == p '
          'for non-negative p, fractionalPaise always in [0,99]', () {
        final held = forAll(
          (int p) {
            final absP = p.abs(); // Money domain uses non-negative paise
            final whole = PaiseMoney.wholeRupees(absP);
            final frac = PaiseMoney.fractionalPaise(absP);
            // fractionalPaise is 0..99
            if (frac < 0 || frac > 99) return false;
            // Decomposition identity for non-negative values
            if ((whole * 100 + frac) != absP) return false;
            // Also verify fractionalPaise is always 0..99 even for negatives
            final fracNeg = PaiseMoney.fractionalPaise(p);
            return fracNeg >= 0 && fracNeg <= 99;
          },
          [Gen.interval(-500000, 500000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Paise decomposition must satisfy '
              'wholeRupees*100 + fractionalPaise == p for non-negative p, '
              'and fractionalPaise is always in [0, 99]',
        );
      });

      // -----------------------------------------------------------------------
      // Property 1c: add(a, b) == a + b (pure integer addition).
      // -----------------------------------------------------------------------
      test('Property 1c (forAll): add(a, b) == a + b', () {
        final held = forAll(
          (int a) {
            // Use a derived b from the single generator to get two values
            final b = a ~/ 2 + 7;
            return PaiseMoney.add(a, b) == a + b;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(held, isTrue, reason: 'add must be pure integer addition');
      });

      // -----------------------------------------------------------------------
      // Property 1d: subtract(a, b) == a - b (pure integer subtraction).
      // -----------------------------------------------------------------------
      test('Property 1d (forAll): subtract(a, b) == a - b', () {
        final held = forAll(
          (int a) {
            final b = a ~/ 3 + 11;
            return PaiseMoney.subtract(a, b) == a - b;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'subtract must be pure integer subtraction',
        );
      });

      // -----------------------------------------------------------------------
      // Property 1e: multiply(perUnitPaise: x, quantity: y) == x * y.
      // -----------------------------------------------------------------------
      test(
        'Property 1e (forAll): multiply(perUnitPaise: x, quantity: y) == x * y',
        () {
          final held = forAll(
            (int x) {
              final y = (x % 50).abs() + 1; // derive a positive quantity
              return PaiseMoney.multiply(perUnitPaise: x, quantity: y) == x * y;
            },
            [Gen.interval(-10000, 10000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'multiply must be pure integer multiplication',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 1f: formatRupees produces correct ₹X.YY format.
      // Pattern: optional '-', then '₹', then digits, '.', exactly 2 digits.
      // -----------------------------------------------------------------------
      test('Property 1f (forAll): formatRupees produces valid ₹X.YY format', () {
        final formatPattern = RegExp(r'^-?₹\d+\.\d{2}$');

        final held = forAll(
          (int paise) {
            final formatted = PaiseMoney.formatRupees(paise);
            // Must match the ₹X.YY format
            if (!formatPattern.hasMatch(formatted)) return false;
            // Verify numeric consistency:
            // Extract the rupee and paise parts and compare
            final isNeg = paise < 0;
            final absP = paise.abs();
            final expectedRupees = absP ~/ 100;
            final expectedFrac = absP % 100;
            final expectedSign = isNeg ? '-' : '';
            final expected =
                '$expectedSign₹$expectedRupees.${expectedFrac.toString().padLeft(2, '0')}';
            return formatted == expected;
          },
          [Gen.interval(-999999, 999999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'formatRupees must produce ₹X.YY with correct values',
        );
      });

      // -----------------------------------------------------------------------
      // Property 1g: All operations return int types (compile-time guarantee,
      // but runtime double-check via runtimeType).
      // -----------------------------------------------------------------------
      test('Property 1g (forAll): all PaiseMoney operations return int', () {
        final held = forAll(
          (int v) {
            final r2p = PaiseMoney.rupeesToPaise(v);
            final whole = PaiseMoney.wholeRupees(v);
            final frac = PaiseMoney.fractionalPaise(v);
            final added = PaiseMoney.add(v, v);
            final subtracted = PaiseMoney.subtract(v, v ~/ 2);
            final multiplied = PaiseMoney.multiply(
              perUnitPaise: v,
              quantity: 3,
            );

            return r2p is int &&
                whole is int &&
                frac is int &&
                added is int &&
                subtracted is int &&
                multiplied is int;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'All PaiseMoney operations must return int, never double',
        );
      });
    },
  );
}
