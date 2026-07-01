// ============================================================================
// Task 1.2 — PROPERTY TESTS for the text-scale clamp arithmetic
// Feature: mobile-text-scale-responsive-hardening
//
// Unit under test: the PURE function `clampTextScaleFactor(double, {bool})` and
//   the constant `kMaxTextScaleFactor` exported from `package:dukanx/app/app.dart`.
//   The function has no Flutter/platform dependencies, so it is fully
//   property-testable in isolation.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. `forAll((arg) => boolExpr, [generator], numRuns: 200)`
//   runs `numRuns` generated cases and returns whether the predicate held.
//
// Generators: doubles are produced by mapping an int interval generator
//   (`Gen.interval(0, 5000).map((i) => i / 1000.0)` => 0.0–5.0), which spans the
//   required input space: values < 1.0, exactly the cap (1.3 == 1300/1000), and
//   values well above the cap (up to 5.0). The platform flag is drawn from
//   `Gen.elementOf<bool>([true, false])`.
//
// Run: flutter test test/responsive/clamp_text_scale_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/app/app.dart';

/// A single generated clamp scenario: a [requested] text-scale factor paired
/// with the platform flag [isWindows].
class _ClampCase {
  const _ClampCase(this.requested, this.isWindows);
  final double requested;
  final bool isWindows;
}

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // Doubles across a wide range, including fractional values < 1.0, the cap
  // (1300 / 1000 == 1.3), and values well above the cap (up to 5.0).
  final Generator<double> requestedGen = Gen.interval(
    0,
    5000,
  ).map((i) => (i as int) / 1000.0);

  // Combined (requested x platform) generator for the cross-platform properties.
  final Generator<_ClampCase> caseGen =
      Gen.tuple([
        Gen.interval(0, 5000),
        Gen.elementOf<bool>(<bool>[true, false]),
      ]).map((parts) {
        final double requested = (parts[0] as int) / 1000.0;
        final bool isWindows = parts[1] as bool;
        return _ClampCase(requested, isWindows);
      });

  group('Feature: mobile-text-scale-responsive-hardening, clamp arithmetic', () {
    // Feature: mobile-text-scale-responsive-hardening, Property 1: Non-Windows
    // clamp invariant — for any requested factor on a non-Windows platform,
    // clampTextScaleFactor(requested, isWindows: false) is within
    // [1.0, kMaxTextScaleFactor] and equals min(max(requested, 1.0), 1.3).
    // **Validates: Requirements 1.2, 1.3, 1.4**
    test('Property 1: Non-Windows clamp invariant', () {
      final held = forAll(
        (double requested) {
          final double result = clampTextScaleFactor(
            requested,
            isWindows: false,
          );

          // Independently computed min(max(requested, 1.0), 1.3).
          final double expected;
          if (requested < 1.0) {
            expected = 1.0;
          } else if (requested > kMaxTextScaleFactor) {
            expected = kMaxTextScaleFactor;
          } else {
            expected = requested;
          }

          final bool withinBounds =
              result >= 1.0 && result <= kMaxTextScaleFactor;
          final bool equalsMinMax = result == expected;

          return withinBounds && equalsMinMax;
        },
        [requestedGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // Feature: mobile-text-scale-responsive-hardening, Property 2: Windows
    // pass-through — for any requested factor on Windows,
    // clampTextScaleFactor(requested, isWindows: true) == requested (no cap).
    // **Validates: Requirements 11.1**
    test('Property 2: Windows pass-through', () {
      final held = forAll(
        (double requested) {
          return clampTextScaleFactor(requested, isWindows: true) == requested;
        },
        [requestedGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // Feature: mobile-text-scale-responsive-hardening, Property 3: Clamp
    // idempotence — for any requested factor and platform flag, clamping a
    // second time yields the same result as clamping once, so the single
    // pipeline can never compound scaling.
    // **Validates: Requirements 1.1, 1.5, 2.2**
    test('Property 3: Clamp idempotence (single application)', () {
      final held = forAll(
        (_ClampCase c) {
          final double once = clampTextScaleFactor(
            c.requested,
            isWindows: c.isWindows,
          );
          final double twice = clampTextScaleFactor(
            once,
            isWindows: c.isWindows,
          );
          return twice == once;
        },
        [caseGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
