// ============================================================================
// Task 2.3 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 13: Harness fails
// on overflow
// **Validates: Requirements 10.4**
// ============================================================================
// Property 13 (design.md): For ANY target widget, the Responsive_Test_Harness
//   reports failure IF AND ONLY IF the target produces an Overflow_Failure in
//   at least one tested (viewport, text-scale) combination — an overflow-free
//   target passes and an overflowing target fails, with the offending viewport
//   and scale named.
//
// Requirement 10.4: "WHEN a target produces a RenderFlex / layout Overflow at
//   any tested (viewport, text-scale) combination, THE Responsive_Test_Harness
//   SHALL fail the test and name the offending viewport and scale."
//
// HOW THIS TEST PROVES THE BICONDITIONAL
//   The unit under test is `pumpResponsiveMatrix` from
//   `responsive_test_harness.dart`, which throws a `TestFailure` (via `fail`)
//   the moment it captures a `RenderFlex overflowed` error, embedding the
//   offending viewport + requested scale in the message.
//
//   We drive it with a fixed-width `Row` whose single child is a `SizedBox` of
//   a GENERATED width. Overflow is then a pure, deterministic function of that
//   width versus the viewport width (text scale cannot change a fixed box), so
//   the expected side of the biconditional is computable without rendering:
//
//       overflowExpected  <=>  width > min(required viewport widths)
//
//   For every generated case we assert the full biconditional:
//     * SAFE widget        → `pumpResponsiveMatrix` completes WITHOUT throwing.
//     * OVERFLOWING widget → `pumpResponsiveMatrix` THROWS a `TestFailure`
//       whose message names a viewport + scale and mentions overflow.
//
// GENERATED SWEEP (not a single forAll closure):
//   The harness is asynchronous and mutates the test binding (it installs a
//   scoped `FlutterError.onError` and pumps real frames), so re-pumping many
//   generated widgets inside ONE `testWidgets` body corrupts the binding after
//   the first `fail()`. Instead we draw a deterministic, seeded SAMPLE of cases
//   from a `dartproptest` `Generator` at suite-build time and run each case in
//   its OWN isolated `testWidgets`. This is the dartproptest equivalent of a
//   `forAll` over a mix of safe vs deliberately-overflowing widgets, with each
//   case fully isolated so a legitimate failure cannot poison its neighbours.
//   The seed is fixed so the sweep is reproducible.
//
// PBT library: dartproptest ^0.2.1 (the repo-standard QuickCheck/Hypothesis-
//   inspired library).
//
// Run: flutter test test/responsive/harness_overflow_detection_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

/// A single generated scenario: a fixed [width] for the box inside the target
/// `Row`, paired with whether the harness MUST report an overflow for it.
class _OverflowCase {
  const _OverflowCase(this.width, this.overflowExpected);

  /// Logical width of the single fixed box inside the target [Row].
  final double width;

  /// Whether `pumpResponsiveMatrix` must fail for this width (i.e. the box
  /// overflows in at least one required viewport).
  final bool overflowExpected;

  @override
  String toString() =>
      'width=${width.toStringAsFixed(1)}, overflowExpected=$overflowExpected';
}

/// The smallest required viewport width — a box wider than this overflows in at
/// least one tested (viewport, scale) combination.
final double _minViewportWidth = kRequiredViewports
    .map((v) => v.width)
    .reduce((a, b) => a < b ? a : b);

/// Builds the target: a `Row` whose single fixed-width child overflows
/// horizontally exactly when [width] exceeds the available viewport width.
/// A `SizedBox` is used (not `Text`) so overflow is a pure function of [width]
/// and is independent of the applied text scale — keeping the biconditional
/// deterministic across the whole matrix.
Widget _fixedBoxRow(double width) {
  return Row(
    children: <Widget>[
      SizedBox(
        width: width,
        height: 24,
        child: const ColoredBox(color: Color(0xFF2196F3)),
      ),
    ],
  );
}

/// Generator: a 50/50 mix of SAFE and OVERFLOW cases.
///   regime 0 → SAFE     width in [20, 279]   (< 360 = smallest viewport)
///   regime 1 → OVERFLOW width in [700, 1700] (> 412 = largest viewport)
/// The two bands deliberately skip the (360, 412] gray zone so the expected
/// outcome is unambiguous. `overflowExpected` is recomputed from the width vs
/// the real required-viewport set, so the case never lies about itself.
final Generator<_OverflowCase> _caseGen =
    Gen.tuple([
      Gen.interval(0, 1), // 0: regime (0 safe, 1 overflow)
      Gen.interval(0, 1000), // 1: magnitude within the regime band
    ]).map((parts) {
      final int regime = parts[0] as int;
      final int magnitude = parts[1] as int;

      final double width = regime == 0
          ? 20.0 +
                (magnitude % 260) // 20..279  → safe
          : 700.0 + magnitude.toDouble(); // 700..1700 → overflow

      return _OverflowCase(width, width > _minViewportWidth);
    });

/// Draws [count] reproducible cases from [_caseGen] using a fixed seed, then
/// pins two guaranteed extremes so BOTH sides of the biconditional are always
/// exercised regardless of sampling.
List<_OverflowCase> _sampleCases(int count) {
  final random = Random('mobile-text-scale-hardening-property-13');
  final cases = <_OverflowCase>[
    // Guaranteed edge coverage: a clearly-safe and a clearly-overflowing box.
    _OverflowCase(40, 40 > _minViewportWidth),
    _OverflowCase(1600, 1600 > _minViewportWidth),
  ];
  for (var i = 0; i < count; i++) {
    cases.add(_caseGen.generate(random).value);
  }
  return cases;
}

/// Runs the harness against [c] and asserts the Property 13 biconditional for
/// that single, isolated case. Captures the `TestFailure` thrown by
/// `pumpResponsiveMatrix` locally so the assertion can inspect it.
Future<void> _assertBiconditional(WidgetTester tester, _OverflowCase c) async {
  TestFailure? failure;
  try {
    await pumpResponsiveMatrix(tester, builder: () => _fixedBoxRow(c.width));
  } on TestFailure catch (e) {
    failure = e;
  }

  if (c.overflowExpected) {
    // Overflowing target → MUST fail, naming a viewport + scale and overflow.
    expect(
      failure,
      isNotNull,
      reason: 'an overflowing target ($c) must make pumpResponsiveMatrix fail',
    );
    final message = failure!.message ?? failure.toString();
    expect(
      message.toLowerCase(),
      contains('overflow'),
      reason: 'failure must identify the overflow',
    );
    expect(
      message,
      contains('viewport'),
      reason: 'failure must name the offending viewport',
    );
    expect(
      message,
      contains('scale'),
      reason: 'failure must name the offending scale',
    );
  } else {
    // Safe target → MUST pass (no throw at all).
    expect(
      failure,
      isNull,
      reason: 'a safe target ($c) must pass the matrix without failing',
    );
  }
}

void main() {
  // A representative seeded sweep: >= 24 generated cases plus 2 pinned
  // extremes, covering both regimes across the full required matrix.
  final cases = _sampleCases(24);

  group('Feature: mobile-text-scale-responsive-hardening, Property 13: Harness '
      'fails on overflow', () {
    for (var i = 0; i < cases.length; i++) {
      final c = cases[i];
      testWidgets(
        'Property 13 [#$i $c]: harness fails IFF the target overflows',
        (WidgetTester tester) async {
          await _assertBiconditional(tester, c);
        },
      );
    }

    // Explicit multi-box overflow example: pins the exact offending viewport
    // named in the message (the first exercised viewport, 360x640).
    testWidgets('Property 13: an overflowing widget fails, naming the '
        'offending viewport 360x640', (WidgetTester tester) async {
      Widget overflowing() => Row(
        children: const <Widget>[
          SizedBox(
            width: 900,
            height: 24,
            child: ColoredBox(color: Color(0xFFF44336)),
          ),
          SizedBox(
            width: 900,
            height: 24,
            child: ColoredBox(color: Color(0xFFF44336)),
          ),
        ],
      );

      TestFailure? failure;
      try {
        await pumpResponsiveMatrix(tester, builder: overflowing);
      } on TestFailure catch (e) {
        failure = e;
      }

      expect(failure, isNotNull);
      final message = failure!.message ?? failure.toString();
      expect(message.toLowerCase(), contains('overflow'));
      expect(message, contains('viewport'));
      expect(message, contains('scale'));
      expect(message, contains('360x640'));
    });

    // Explicit safe example: a small column of primitives passes the matrix.
    testWidgets('Property 13: a safe widget passes the matrix without '
        'failing', (WidgetTester tester) async {
      Widget safe() => const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 80,
            height: 20,
            child: ColoredBox(color: Color(0xFF4CAF50)),
          ),
          Text('ok'),
        ],
      );

      TestFailure? failure;
      try {
        await pumpResponsiveMatrix(tester, builder: safe);
      } on TestFailure catch (e) {
        failure = e;
      }

      expect(
        failure,
        isNull,
        reason: 'a safe widget must not trigger an overflow failure',
      );
    });
  });
}
