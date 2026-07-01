// ============================================================================
// Task 1.2 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 1: Form_Factor classification
// is correct at every width
// **Validates: Requirements 1.2, 1.3, 1.4, 1.8, 2.3, 2.4**
// ============================================================================
// Property 1 (design.md): For any logical width w >= 0, the Responsive_System
//   classifier returns
//     * Mobile  if and only if w < 600,
//     * Tablet  if and only if 600 <= w < 1100,
//     * Desktop if and only if w >= 1100.
//   The generated widths MUST include the exact boundary values
//   599, 600, 1099, and 1100.
//
// Unit under test: `ResponsiveBreakpoints.classify(double width)` returning a
// `FormFactor`, from `package:dukanx/core/responsive/responsive_breakpoints.dart`.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/classification_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/responsive/responsive_breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // The exact Breakpoint_Strategy boundary values that must be exercised, plus
  // the lower edge (0) and a large desktop width. Including them in the
  // generated stream guarantees the off-by-one edges around 600 and 1100 are
  // covered by the property itself (in addition to the explicit test below).
  const List<int> kBoundaryWidths = <int>[0, 599, 600, 1099, 1100, 3840];

  // Width generator over [0, 3840] logical pixels. With ~1-in-4 probability it
  // emits one of the boundary widths so the exact edges 599/600/1099/1100 are
  // sampled frequently; otherwise it emits a uniformly drawn width across the
  // full supported range. Integers are converted to doubles on use, exactly
  // matching how a real MediaQuery width feeds `classify`.
  final Generator<int> widthGen =
      Gen.tuple([
        Gen.interval(0, 3840),
        Gen.interval(0, kBoundaryWidths.length * 4 - 1),
      ]).map((parts) {
        final int raw = parts[0] as int;
        final int selector = parts[1] as int;
        if (selector < kBoundaryWidths.length) return kBoundaryWidths[selector];
        return raw;
      });

  group('Feature: cross-platform-responsive-ui, Property 1: Form_Factor '
      'classification is correct at every width', () {
    // -- Property: classify obeys the three biconditionals at every width ---
    test('Property 1: classify(w) == Mobile iff w < 600, == Tablet iff '
        '600 <= w < 1100, == Desktop iff w >= 1100', () {
      final held = forAll(
        (int widthInt) {
          final double w = widthInt.toDouble();
          final FormFactor ff = ResponsiveBreakpoints.classify(w);

          // Each clause is a biconditional (iff): the classifier returns the
          // band X exactly when w lies in band X's range. Asserting all three
          // simultaneously also proves classification is total and disjoint.
          final bool mobileIff = (ff == FormFactor.mobile) == (w < 600);
          final bool tabletIff =
              (ff == FormFactor.tablet) == (w >= 600 && w < 1100);
          final bool desktopIff = (ff == FormFactor.desktop) == (w >= 1100);

          return mobileIff && tabletIff && desktopIff;
        },
        [widthGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Explicit boundary assertions (guaranteed edge coverage) ------------
    // Direct, deterministic checks of the off-by-one edges and the extremes,
    // so the exact boundary behavior is verified even independent of the
    // generator's sampling.
    test(
      'Property 1: exact boundary and extreme widths classify correctly',
      () {
        expect(ResponsiveBreakpoints.classify(0), FormFactor.mobile);
        expect(ResponsiveBreakpoints.classify(599), FormFactor.mobile);
        expect(ResponsiveBreakpoints.classify(600), FormFactor.tablet);
        expect(ResponsiveBreakpoints.classify(1099), FormFactor.tablet);
        expect(ResponsiveBreakpoints.classify(1100), FormFactor.desktop);
        expect(ResponsiveBreakpoints.classify(3840), FormFactor.desktop);
      },
    );
  });
}
