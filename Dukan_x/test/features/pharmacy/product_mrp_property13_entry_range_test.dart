// ============================================================================
// TASK 3.5 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 13: Product MRP entry range
//          validation
// **Validates: Requirements 8.5, 8.6**
// ============================================================================
//
// Property 13 (design.md — Correctness Properties):
//   "For any MRP value entered in the product sheet, it is accepted if and only
//    if it is an integer paise value in the inclusive range [1, 99,999,999];
//    otherwise it is rejected and the product is not saved."
//
// The pharmacy branch of `add_product_sheet.dart` (Task 3.4) parses the rupee
// MRP string into whole integer paise and accepts it only when the result lies
// in [1, 99,999,999] paise (₹0.01 .. ₹999,999.99). That rule is extracted into
// the pure, side-effect-free `ProductMrpEntryValidator` so it can be exercised
// directly; the widget calls the same helper, so this test pins the production
// behavior the save path relies on.
//
// HOW THIS IS PROVEN AS A PROPERTY (independent oracle, not a re-implementation):
//   * WELL-FORMED entries: the generator builds a rupee string from a whole
//     rupees component and 0/1/2 explicit decimal digits, and computes — with
//     pure integer arithmetic that never calls the validator — the exact paise
//     value that string denotes. The oracle for acceptance is then simply
//         1 <= paise <= 99,999,999.
//     `isAccepted(text)` must equal that oracle for every generated string, and
//     `rupeesToWholePaise(text)` must reproduce the oracle's paise exactly. The
//     rupees range spans both sides of the upper bound so the [1, 99,999,999]
//     boundary is straddled, and the decimal-place choice exercises the 0-, 1-,
//     and 2-fraction-digit shapes the field accepts.
//   * MALFORMED entries: a guaranteed-3-decimal-digit string (e.g. "12.345")
//     can never map cleanly to whole paise, so the acceptance oracle is a
//     constant `false`. This proves non-integer-paise precision is rejected
//     without re-stating the validator's regex.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. `forAll((a) => <bool>, [genA], numRuns: N)` returns true
//   when the property held for every run and throws a shrinking counterexample
//   otherwise.
//
// Run: flutter test test/features/pharmacy/product_mrp_property13_entry_range_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/pharmacy/product_mrp_entry_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// Inclusive accepted range, restated here as the independent oracle bound so a
/// regression that widens/narrows the production bounds is caught.
const int kMinPaise = 1;
const int kMaxPaise = 99999999; // ₹999,999.99

// ---------------------------------------------------------------------------
// Case model + generators
// ---------------------------------------------------------------------------

/// A well-formed rupee MRP string paired with the exact whole-paise value it
/// denotes (computed by pure integer arithmetic, never by the validator).
class _WellFormed {
  const _WellFormed(this.text, this.paise);
  final String text;
  final int paise;
}

/// Builds rupee strings with 0, 1, or 2 decimal places. The whole-rupees range
/// runs past ₹999,999.99 so the upper bound (99,999,999 paise) is straddled by
/// both accepted and rejected cases; the lower bound (1 paise) is straddled by
/// the zero/near-zero values.
final Generator<_WellFormed> _wellFormedGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 1000005), // 0: whole rupees (past the ₹999,999 ceiling)
      Gen.interval(0, 2), // 1: decimal-place mode (0, 1, or 2 digits)
      Gen.interval(0, 99), // 2: fractional component (paise / tenths source)
    ]).map((parts) {
      final int rupees = parts[0] as int;
      final int mode = parts[1] as int;
      final int frac = parts[2] as int;

      String text;
      int paise;
      if (mode == 0) {
        // Integer rupees, no decimal point (e.g. "50" → 5000 paise).
        text = '$rupees';
        paise = rupees * 100;
      } else if (mode == 1) {
        // One decimal digit (e.g. "50.5" → 5050 paise).
        final int d = frac % 10;
        text = '$rupees.$d';
        paise = rupees * 100 + d * 10;
      } else {
        // Two decimal digits (e.g. "50.07" → 5007 paise).
        final String dd = frac.toString().padLeft(2, '0');
        text = '$rupees.$dd';
        paise = rupees * 100 + frac;
      }
      return _WellFormed(text, paise);
    });

/// Builds rupee strings with EXACTLY three decimal digits (e.g. "734.501").
/// Three-decimal precision is finer than a whole paise, so such an entry can
/// never be accepted — the acceptance oracle is a constant `false`.
final Generator<String> _threeDecimalGen = Gen.tuple(<Generator<dynamic>>[
  Gen.interval(0, 1000000), // whole rupees
  Gen.interval(100, 999), // exactly three fractional digits
]).map((parts) => '${parts[0] as int}.${parts[1] as int}');

bool _oracleAccepted(int paise) => paise >= kMinPaise && paise <= kMaxPaise;

void main() {
  group(
    'Feature: pharmacy-vertical-remediation, Property 13: Product MRP entry '
    'range validation — Req 8.5, 8.6',
    () {
      // ----------------------------------------------------------------------
      // (A) WELL-FORMED: accepted iff the denoted paise value is in
      //     [1, 99,999,999], and the parsed paise equals the denoted paise.
      //     (R8.5, R8.6)
      // ----------------------------------------------------------------------
      test('Property 13a: a well-formed MRP entry is accepted iff its integer '
          'paise value is in [1, 99,999,999]', () {
        final bool held = forAll(
          (_WellFormed entry) {
            final bool accepted = ProductMrpEntryValidator.isAccepted(
              entry.text,
            );
            final int? parsed = ProductMrpEntryValidator.rupeesToWholePaise(
              entry.text,
            );
            // The string must parse to exactly the paise it denotes...
            if (parsed != entry.paise) return false;
            // ...and acceptance must match the inclusive-range oracle.
            return accepted == _oracleAccepted(entry.paise);
          },
          [_wellFormedGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'A well-formed MRP entry is accepted exactly when it maps to an '
              'integer paise value in [1, 99,999,999].',
        );
      });

      // ----------------------------------------------------------------------
      // (B) MALFORMED: a finer-than-paise (3-decimal) entry is always rejected,
      //     because it is not an integer paise value. (R8.6)
      // ----------------------------------------------------------------------
      test('Property 13b: an entry with sub-paise (three-decimal) precision is '
          'always rejected', () {
        final bool held = forAll(
          (String text) {
            return ProductMrpEntryValidator.isAccepted(text) == false &&
                ProductMrpEntryValidator.rupeesToWholePaise(text) == null;
          },
          [_threeDecimalGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'A value that cannot be represented as a whole paise (more than '
              'two decimal places) must be rejected.',
        );
      });

      // ----------------------------------------------------------------------
      // Deterministic anchors — pin the range boundaries and the malformed
      // rejections, proving the property is non-vacuous.
      // ----------------------------------------------------------------------
      test('Property 13 anchors: inclusive-range boundaries', () {
        // Lower boundary: 1 paise accepted, 0 paise rejected.
        expect(ProductMrpEntryValidator.isAccepted('0.01'), isTrue); // 1 paise
        expect(ProductMrpEntryValidator.isAccepted('0.00'), isFalse); // 0 paise
        expect(ProductMrpEntryValidator.isAccepted('0'), isFalse); // 0 paise

        // Upper boundary: 99,999,999 paise accepted, one paise over rejected.
        expect(
          ProductMrpEntryValidator.isAccepted('999999.99'),
          isTrue,
        ); // 99,999,999
        expect(
          ProductMrpEntryValidator.isAccepted('1000000.00'),
          isFalse,
        ); // 100,000,000
        expect(
          ProductMrpEntryValidator.isAccepted('1000000'),
          isFalse,
        ); // 100,000,000

        // Mid-range, all three decimal shapes.
        expect(ProductMrpEntryValidator.isAccepted('50'), isTrue); // 5000 paise
        expect(
          ProductMrpEntryValidator.isAccepted('50.5'),
          isTrue,
        ); // 5050 paise
        expect(
          ProductMrpEntryValidator.isAccepted('49.50'),
          isTrue,
        ); // 4950 paise

        // Leading/trailing whitespace is trimmed before validation.
        expect(ProductMrpEntryValidator.isAccepted('  50.00  '), isTrue);
      });

      test(
        'Property 13 anchors: malformed and out-of-shape entries are rejected',
        () {
          // Sub-paise precision.
          expect(ProductMrpEntryValidator.isAccepted('12.345'), isFalse);
          // Empty / whitespace-only.
          expect(ProductMrpEntryValidator.isAccepted(''), isFalse);
          expect(ProductMrpEntryValidator.isAccepted('   '), isFalse);
          // Non-numeric / signed / malformed numerics.
          expect(ProductMrpEntryValidator.isAccepted('abc'), isFalse);
          expect(ProductMrpEntryValidator.isAccepted('-5.00'), isFalse);
          expect(ProductMrpEntryValidator.isAccepted('1.2.3'), isFalse);
          expect(ProductMrpEntryValidator.isAccepted('₹50'), isFalse);
          expect(ProductMrpEntryValidator.isAccepted('1,000.00'), isFalse);
        },
      );
    },
  );
}
