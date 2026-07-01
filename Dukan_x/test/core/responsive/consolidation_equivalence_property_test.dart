// ============================================================================
// Task 1.3 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 2: Consolidation preserves
// classification (model-based)
// **Validates: Requirements 2.2**
// ============================================================================
// Property 2 (design.md): For any logical width w, the consolidated
//   Responsive_System classifier returns the same Form_Factor that the
//   pre-consolidation core classifier (`getScreenSize` with
//   `Breakpoints.mobile = 600`, `Breakpoints.tablet = 1100`) returned for that
//   width, so existing consumers observe no change.
//
// Unit under test: `ResponsiveBreakpoints.classify(double width)` returning a
// `FormFactor`, from `package:dukanx/core/responsive/responsive_breakpoints.dart`.
//
// MODEL (the pre-consolidation core classifier): the legacy
// `lib/core/responsive/responsive_layout.dart` defines
//     enum ScreenSize { mobile, tablet, desktop }
//     class Breakpoints { static const mobile = 600; static const tablet = 1100; }
//     ScreenSize getScreenSize(context) {
//       final width = MediaQuery.of(context).size.width;
//       if (width < Breakpoints.mobile) return ScreenSize.mobile;   // w < 600
//       if (width < Breakpoints.tablet) return ScreenSize.tablet;   // 600 <= w < 1100
//       return ScreenSize.desktop;                                  // w >= 1100
//     }
//   To keep this model-based property SELF-CONTAINED and COMPILING, the legacy
//   classifier's *pure decision* is re-encoded here as a small local band
//   function `_legacyBand` (0 = mobile, 1 = tablet, 2 = desktop) rather than
//   imported. The legacy file pulls in the broken app import graph and would
//   introduce ambiguous-extension / name-collision compile errors (it also
//   declares `enum ScreenSize` and `extension ResponsiveContext`, which clash
//   with the consolidated system). Re-encoding the exact thresholds keeps the
//   test independent and pins the model to the documented legacy values.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/consolidation_equivalence_property_test.dart
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
  // matching how a real MediaQuery width feeds the classifiers.
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

  // ---------------------------------------------------------------------------
  // MODEL: the pre-consolidation core classifier, as a pure band function.
  // Mirrors the legacy `getScreenSize` decision with `Breakpoints.mobile = 600`
  // and `Breakpoints.tablet = 1100`:
  //   w < 600           -> 0 (ScreenSize.mobile)
  //   600 <= w < 1100   -> 1 (ScreenSize.tablet)
  //   w >= 1100         -> 2 (ScreenSize.desktop)
  // ---------------------------------------------------------------------------
  int legacyBand(double w) => w < 600 ? 0 : (w < 1100 ? 1 : 2);

  // Maps the consolidated classifier's FormFactor to the same 0/1/2 band so the
  // two systems can be compared as equal bands.
  int consolidatedBand(double w) {
    switch (ResponsiveBreakpoints.classify(w)) {
      case FormFactor.mobile:
        return 0;
      case FormFactor.tablet:
        return 1;
      case FormFactor.desktop:
        return 2;
    }
  }

  group('Feature: cross-platform-responsive-ui, Property 2: Consolidation '
      'preserves classification (model-based)', () {
    // -- Property: consolidated classify agrees with the legacy model -------
    test('Property 2: ResponsiveBreakpoints.classify(w) yields the same band '
        'as the pre-consolidation core classifier for every width', () {
      final held = forAll(
        (int widthInt) {
          final double w = widthInt.toDouble();
          // Model equivalence: the consolidated classifier must produce the
          // exact same Form_Factor band the legacy core classifier produced.
          return consolidatedBand(w) == legacyBand(w);
        },
        [widthGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Explicit boundary assertions (guaranteed edge coverage) ------------
    // Direct, deterministic checks that the consolidated classifier matches the
    // legacy model exactly at the off-by-one edges and the extremes, even
    // independent of the generator's sampling.
    test('Property 2: consolidated classifier matches the legacy model at the '
        'exact boundary and extreme widths', () {
      for (final int w in <int>[0, 599, 600, 1099, 1100, 3840]) {
        final double width = w.toDouble();
        expect(
          consolidatedBand(width),
          legacyBand(width),
          reason: 'consolidated classify diverged from legacy model at w=$w',
        );
      }

      // Spell out the expected legacy bands at the boundaries so a regression
      // in the model encoding itself is also caught.
      expect(legacyBand(0), 0);
      expect(legacyBand(599), 0);
      expect(legacyBand(600), 1);
      expect(legacyBand(1099), 1);
      expect(legacyBand(1100), 2);
      expect(legacyBand(3840), 2);
    });
  });
}
