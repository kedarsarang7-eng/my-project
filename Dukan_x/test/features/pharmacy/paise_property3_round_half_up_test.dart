// ============================================================================
// TASK 1.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 3: Monetary values are
//          integer paise with round-half-up
// **Validates: Requirements 2.1, 2.2, 2.4, 11.5**
// ============================================================================
//
// Property 3 (design.md — Correctness Properties):
//   "For any monetary input to changed code (including fractional/floating-point
//    values), the converted and stored value is a whole-number integer paise
//    equal to the round-half-up of the input, and every monetary arithmetic
//    operation in changed code yields an integer paise result rounded half-up."
//
// Round-half-up means ties go toward +∞:  2.5 -> 3,  -2.5 -> -2  (implemented in
// `Paise` as `floor(value + 0.5)`).
//
// HOW THIS IS PROVEN AS A PROPERTY (independent oracle, not a re-implementation):
//   The unique defining characteristic of round-half-up is integer-exact:
//     roundHalfUp(n/10) == floorDiv(n + 5, 10)
//   for any integer `n` (tenths of a paise). `floorDiv` is computed with pure
//   integer arithmetic in this test — it never calls the production rounding
//   expression — so a regression in `Paise.roundHalfUp` (e.g. switching to
//   banker's rounding, truncation, or round-half-down) is caught. The tie cases
//   (n = 10m ± 5) are exactly representable as IEEE doubles, so the oracle pins
//   the *direction* of tie-breaking with no floating-point ambiguity, and every
//   non-tie tenth sits ≥ 0.1 away from a half-boundary (far beyond float noise).
//
//   `fromRupees` is checked two ways:
//     (a) exact-paise rupee inputs (k/100) must convert to exactly k paise; and
//     (b) ANY sub-paise rupee input must land within ±0.5 paise of input×100
//         (the round-to-nearest bound). (a) pins exactness, (b) pins that
//         arbitrary fractional/floating inputs are rounded to a whole paise.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide (glados is unresolvable here; see the dev_dependency note
//   in pubspec.yaml). Idiomatic usage:
//     forAll((a) => <bool>, [genA], numRuns: N);
//   `forAll` returns true when the property held for every run and throws a
//   shrinking counterexample otherwise.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/paise_property3_round_half_up_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/pharmacy/paise.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// Pure-integer floor division (Dart `~/` truncates toward zero). Used as the
/// independent oracle for round-half-up; never calls the production rounding.
int _floorDiv(int a, int b) {
  final int q = a ~/ b;
  if (a % b != 0 && (a < 0) != (b < 0)) return q - 1;
  return q;
}

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 3: Monetary values are '
      'integer paise with round-half-up — Req 2.1, 2.2, 2.4, 11.5', () {
    // ----------------------------------------------------------------------
    // Generators. Ranges are wide enough to exercise large rupee amounts
    // (up to ₹10,000,000) while staying well inside IEEE-double exact-integer
    // territory (|value| << 2^53), so the integer oracle is reliable.
    // ----------------------------------------------------------------------
    // Tenths-of-a-paise: covers whole paise, fractional paise, exact ties
    // (n ≡ ±5 mod 10), positives and negatives (credit notes / returns).
    final Generator<int> tenthsGen = Gen.interval(-1000000000, 1000000000);
    // Whole-paise amounts for exact rupee→paise conversion.
    final Generator<int> paiseGen = Gen.interval(-100000000, 100000000);
    // Milli-rupees: sub-paise fractional/floating rupee inputs (3 decimals).
    final Generator<int> milliRupeesGen = Gen.interval(-1000000000, 1000000000);

    test(
      'Property 3a: roundHalfUp(n/10) equals the integer round-half-up of n/10 '
      'for every tenth-of-a-paise (ties round toward +∞)',
      () {
        final bool held = forAll(
          (int tenths) {
            final num fractionalPaise = tenths / 10.0;
            final int expected = _floorDiv(tenths + 5, 10);
            return Paise.roundHalfUp(fractionalPaise) == expected;
          },
          [tenthsGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'roundHalfUp must round to the nearest whole paise with '
              'ties going toward +∞.',
        );
      },
    );

    test('Property 3b: fromRupees converts an exact-paise rupee amount (k/100) '
        'to exactly k whole integer paise', () {
      final bool held = forAll(
        (int paise) {
          final num rupees = paise / 100.0;
          return Paise.fromRupees(rupees) == paise;
        },
        [paiseGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'A rupee amount with exact paise precision must convert to '
            'that exact whole integer paise value.',
      );
    });

    test(
      'Property 3c: fromRupees rounds ANY fractional/floating rupee input to '
      'a whole paise within ±0.5 paise of input × 100 (round-to-nearest)',
      () {
        const double tolerance = 1e-6; // absorbs benign float drift only
        final bool held = forAll(
          (int milliRupees) {
            final num rupees = milliRupees / 1000.0; // 3-decimal rupee input
            final int paise = Paise.fromRupees(rupees);
            final num delta = rupees * 100 - paise;
            return delta >= -0.5 - tolerance && delta <= 0.5 + tolerance;
          },
          [milliRupeesGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'fromRupees must round every fractional rupee input to the '
              'nearest whole paise.',
        );
      },
    );

    // Deterministic anchors — prove the property is non-vacuous and pin the
    // tie-break direction and boundary behavior exactly.
    test('Property 3 anchors: exact tie and boundary cases', () {
      // roundHalfUp: ties go toward +∞.
      expect(Paise.roundHalfUp(2.5), 3);
      expect(Paise.roundHalfUp(-2.5), -2);
      expect(Paise.roundHalfUp(0.5), 1);
      expect(Paise.roundHalfUp(-0.5), 0);
      expect(Paise.roundHalfUp(2.4), 2);
      expect(Paise.roundHalfUp(-2.6), -3);
      expect(Paise.roundHalfUp(0), 0);

      // fromRupees: exact-paise conversions and sign handling.
      expect(Paise.fromRupees(1.0), 100);
      expect(Paise.fromRupees(99.99), 9999);
      expect(Paise.fromRupees(-1.5), -150);
      expect(Paise.fromRupees(0), 0);
    });
  });
}
