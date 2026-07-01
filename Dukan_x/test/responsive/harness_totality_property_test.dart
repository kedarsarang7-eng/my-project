// ============================================================================
// Task 2.2 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 12: Harness matrix
// totality
// **Validates: Requirements 10.2, 10.3, 10.6**
// ============================================================================
// Property 12 (design.md): For any hardening test executed through the
//   Responsive_Test_Harness, the set of (viewport, text-scale) pairs actually
//   exercised must equal EXACTLY the required matrix — viewports
//   {360x640, 393x851, 412x915} x scales {1.0, 1.3, Above_Cap}. Any test that
//   omits at least one required pair fails the coverage (totality) check.
//
// Requirements:
//   10.2 — exercise scales 1.0, 1.3 (cap), and an Above_Cap_Scale.
//   10.3 — exercise viewports 360x640, 393x851, 412x915.
//   10.6 — a test that omits any required (scale x viewport) pair FAILS.
//
// HOW THIS TEST PROVES PROPERTY 12
//   The harness's totality rule is pure set logic: the full required matrix
//   (9 pairs = 3 viewports x 3 scales) minus the pairs a test actually
//   exercised. `pumpResponsiveMatrix` enforces it via the single pure helper
//   `missingMatrixPairs(exercised)` and fails when the result is non-empty.
//   This test drives THAT SAME helper, so it validates the exact rule the
//   harness uses at runtime.
//
//   (a) PROPERTY (dartproptest forAll, numRuns = 200): generate an arbitrary
//       subset of the 9 required pairs via a 9-bit bitmask (0..511). For every
//       subset the totality check reports "complete" (no missing pairs) IF AND
//       ONLY IF the subset is the full matrix, and the missing set is exactly
//       the omitted pairs. So an INCOMPLETE subset always fails the check and
//       the FULL matrix always passes.
//   (b) END-TO-END (testWidgets): actually run `pumpResponsiveMatrix` with a
//       safe (non-overflowing) builder. The full matrix completes; an
//       incomplete matrix (omitting the Above_Cap scale / a viewport) throws a
//       TestFailure naming the missing pairs.
//
// PBT library: dartproptest ^0.2.1 (repo-standard), numRuns 200 — matching
//   `test/tool/responsive_audit_totality_property_test.dart`.
//
// Run: flutter test test/responsive/harness_totality_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // The 9 required matrix pairs in a fixed order (viewport outer, scale inner),
  // mirroring `requiredMatrixKeys`. Bit i of a bitmask selects `allPairs[i]`.
  final List<String> allPairs = <String>[
    for (final v in kRequiredViewports)
      for (final s in kRequiredScales) responsiveMatrixKey(v, s),
  ];

  group('Feature: mobile-text-scale-responsive-hardening, Property 12: Harness '
      'matrix totality', () {
    // -- (a) PROPERTY over arbitrary subsets of the required matrix --------
    test('Property 12: incomplete coverage FAILS the totality check while the '
        'full matrix PASSES — for any subset of the required matrix', () {
      // Sanity: the required matrix is exactly the 9-pair spec matrix.
      expect(allPairs.length, 9);
      expect(allPairs.toSet().length, 9, reason: 'pairs are distinct');

      final held = forAll(
        (int mask) {
          // Build a subset of the required pairs from the bitmask.
          final exercised = <String>{
            for (var i = 0; i < allPairs.length; i++)
              if (((mask >> i) & 1) == 1) allPairs[i],
          };

          // The harness's totality gap (the SAME pure helper it uses).
          final missing = missingMatrixPairs(exercised);

          final bool coversFullMatrix = exercised.length == allPairs.length;

          // Totality rule: complete IFF the full matrix was exercised.
          final bool completeIffFull = missing.isEmpty == coversFullMatrix;

          // The gap is EXACTLY the omitted required pairs — no more, no
          // less — so failures name precisely what was skipped (R10.6).
          final bool gapIsExactlyOmitted = setEquals(
            missing,
            allPairs.toSet().difference(exercised),
          );

          // Any incomplete subset MUST be flagged (totality check fails).
          final bool incompleteAlwaysFlagged =
              coversFullMatrix || missing.isNotEmpty;

          return completeIffFull &&
              gapIsExactlyOmitted &&
              incompleteAlwaysFlagged;
        },
        // A 9-bit mask: 0 = empty subset, 511 = the full required matrix.
        [Gen.interval(0, (1 << 9) - 1)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Deterministic edge examples (guaranteed branch coverage) ----------
    test('Property 12: the full matrix passes; the empty set and every '
        'single-pair omission fail', () {
      // Full matrix → no gap → passes.
      expect(missingMatrixPairs(allPairs.toSet()), isEmpty);

      // Empty coverage → all 9 pairs missing → fails.
      expect(missingMatrixPairs(const <String>{}), hasLength(9));

      // Omitting exactly one required pair always fails, and the gap is
      // precisely that one pair.
      for (final omitted in allPairs) {
        final exercised = allPairs.toSet()..remove(omitted);
        final missing = missingMatrixPairs(exercised);
        expect(missing, <String>{omitted});
      }

      // Omitting an entire scale column (the Above_Cap scale) fails.
      final withoutAboveCap = <String>{
        for (final v in kRequiredViewports)
          for (final s in const <double>[kBaselineScale, kCapScale])
            responsiveMatrixKey(v, s),
      };
      expect(missingMatrixPairs(withoutAboveCap), hasLength(3));
    });

    // -- (b) END-TO-END: drive the real pumpResponsiveMatrix ---------------
    testWidgets(
      'Property 12 (end-to-end): pumpResponsiveMatrix completes on the full '
      'matrix and throws on an incomplete matrix',
      (tester) async {
        // A trivially safe widget that cannot overflow at any scale, so the
        // ONLY thing under test is the totality gate.
        Widget safeBuilder() => const Center(child: Text('ok'));

        // Full matrix → exercises all 9 pairs → no totality failure.
        await pumpResponsiveMatrix(tester, builder: safeBuilder);

        // Incomplete matrix (omit the Above_Cap scale) → totality check
        // fails with a TestFailure that names the missing pairs.
        Object? caughtScales;
        try {
          await pumpResponsiveMatrix(
            tester,
            builder: safeBuilder,
            scales: const <double>[kBaselineScale, kCapScale],
          );
        } catch (e) {
          caughtScales = e;
        }
        expect(
          caughtScales,
          isA<TestFailure>(),
          reason: 'omitting the Above_Cap scale must fail totality (R10.2)',
        );

        // Incomplete matrix (omit a required viewport) → also fails.
        Object? caughtViewports;
        try {
          await pumpResponsiveMatrix(
            tester,
            builder: safeBuilder,
            viewports: const <Size>[Size(360, 640), Size(393, 851)],
          );
        } catch (e) {
          caughtViewports = e;
        }
        expect(
          caughtViewports,
          isA<TestFailure>(),
          reason: 'omitting a required viewport must fail totality (R10.3)',
        );
      },
    );
  });
}
