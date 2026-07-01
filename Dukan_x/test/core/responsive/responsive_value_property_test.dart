// ============================================================================
// Task 2.4 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 3: Responsive value selection
// and fallback
// **Validates: Requirements 1.5, 1.7**
// ============================================================================
// Property 3 (design.md): Given a partial per-Form_Factor value specification
// in which AT LEAST ONE of {mobile, tablet, desktop} is defined, and a current
// Form_Factor, `resolveResponsiveValue(factor, ...)`:
//   * returns the value for the current Form_Factor when one is defined
//     (Req 1.5), otherwise falls back to the next-smaller defined value, else
//     the smallest defined value (Req 1.7), per the documented order:
//       - Desktop : desktop ?? tablet  ?? mobile
//       - Tablet  : tablet  ?? mobile  ?? desktop
//       - Mobile  : mobile  ?? tablet  ?? desktop
//   * is never null.
//
// Unit under test: the PURE core
//   `T resolveResponsiveValue<T>(FormFactor factor,
//                                {T? mobile, T? tablet, T? desktop})`
// from `package:dukanx/core/responsive/responsive_value.dart`. Testing the
// pure function needs no `BuildContext`/widget pumping; the BuildContext-based
// `responsiveValue` simply delegates to it after classifying the width.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/responsive_value_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/responsive/responsive_breakpoints.dart';
import 'package:dukanx/core/responsive/responsive_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // Distinct, non-overlapping value ranges per Form_Factor so that a returned
  // value unambiguously identifies WHICH source (mobile/tablet/desktop) was
  // selected — mobile in [100,199], tablet in [200,299], desktop in [300,399].
  const int kMobileBase = 100;
  const int kTabletBase = 200;
  const int kDesktopBase = 300;

  // Independent re-derivation of the documented resolution order. Deliberately
  // re-implemented here (rather than calling the unit under test) so the
  // property compares the production function against a from-scratch fallback.
  int? expectedFor(FormFactor factor, int? mobile, int? tablet, int? desktop) {
    switch (factor) {
      case FormFactor.desktop:
        return desktop ?? tablet ?? mobile;
      case FormFactor.tablet:
        return tablet ?? mobile ?? desktop;
      case FormFactor.mobile:
        return mobile ?? tablet ?? desktop;
    }
  }

  // Generates a partial spec + current factor as a tuple:
  //   [0] presence mask in 1..7 — bit0=mobile, bit1=tablet, bit2=desktop.
  //       The range starts at 1, guaranteeing AT LEAST ONE value is defined
  //       (the precondition of resolveResponsiveValue).
  //   [1] mobile value offset  0..99  -> kMobileBase + offset
  //   [2] tablet value offset  0..99  -> kTabletBase + offset
  //   [3] desktop value offset 0..99  -> kDesktopBase + offset
  //   [4] current FormFactor
  final specGen = Gen.tuple([
    Gen.interval(1, 7),
    Gen.interval(0, 99),
    Gen.interval(0, 99),
    Gen.interval(0, 99),
    Gen.elementOf<FormFactor>(FormFactor.values),
  ]);

  group('Feature: cross-platform-responsive-ui, Property 3: Responsive value '
      'selection and fallback', () {
    // -- Property: resolution order + non-null result over partial specs ---
    test('Property 3: resolveResponsiveValue follows the documented resolution '
        'order (current factor, else next-smaller defined, else smallest '
        'defined) and is never null when at least one value is defined', () {
      final held = forAll(
        (List<dynamic> spec) {
          final int mask = spec[0] as int;
          final int? mobile = (mask & 1) != 0
              ? kMobileBase + (spec[1] as int)
              : null;
          final int? tablet = (mask & 2) != 0
              ? kTabletBase + (spec[2] as int)
              : null;
          final int? desktop = (mask & 4) != 0
              ? kDesktopBase + (spec[3] as int)
              : null;
          final FormFactor factor = spec[4] as FormFactor;

          final int actual = resolveResponsiveValue<int>(
            factor,
            mobile: mobile,
            tablet: tablet,
            desktop: desktop,
          );

          final int? expected = expectedFor(factor, mobile, tablet, desktop);

          // The result must equal the independently re-derived value and,
          // because at least one source is defined, must never be null.
          return expected != null && actual == expected;
        },
        [specGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });

  // -- Deterministic example coverage (Req 1.5 and 1.7) ---------------------
  // Concrete cases that pin down the exact selection/fallback behavior,
  // complementing the generated property above.
  group('Feature: cross-platform-responsive-ui, Property 3: Responsive value '
      'selection and fallback — examples', () {
    test('only tablet defined -> returned for every Form_Factor (Req 1.7)', () {
      for (final factor in FormFactor.values) {
        expect(
          resolveResponsiveValue<String>(factor, tablet: 'T'),
          'T',
          reason: 'tablet is the only/smallest defined value for $factor',
        );
      }
    });

    test('only mobile defined -> returned for every Form_Factor (Req 1.7)', () {
      for (final factor in FormFactor.values) {
        expect(resolveResponsiveValue<String>(factor, mobile: 'M'), 'M');
      }
    });

    test(
      'only desktop defined -> returned for every Form_Factor (Req 1.7)',
      () {
        for (final factor in FormFactor.values) {
          expect(resolveResponsiveValue<String>(factor, desktop: 'D'), 'D');
        }
      },
    );

    test('all defined -> current Form_Factor value is selected (Req 1.5)', () {
      expect(
        resolveResponsiveValue<String>(
          FormFactor.mobile,
          mobile: 'M',
          tablet: 'T',
          desktop: 'D',
        ),
        'M',
      );
      expect(
        resolveResponsiveValue<String>(
          FormFactor.tablet,
          mobile: 'M',
          tablet: 'T',
          desktop: 'D',
        ),
        'T',
      );
      expect(
        resolveResponsiveValue<String>(
          FormFactor.desktop,
          mobile: 'M',
          tablet: 'T',
          desktop: 'D',
        ),
        'D',
      );
    });

    test('mixed: mobile + desktop defined, tablet missing (Req 1.7)', () {
      // Tablet falls back to mobile (next-smaller defined).
      expect(
        resolveResponsiveValue<String>(
          FormFactor.tablet,
          mobile: 'M',
          desktop: 'D',
        ),
        'M',
      );
      // Desktop query uses its own defined value.
      expect(
        resolveResponsiveValue<String>(
          FormFactor.desktop,
          mobile: 'M',
          desktop: 'D',
        ),
        'D',
      );
      // Mobile query uses its own defined value.
      expect(
        resolveResponsiveValue<String>(
          FormFactor.mobile,
          mobile: 'M',
          desktop: 'D',
        ),
        'M',
      );
    });

    test('mixed: tablet + desktop defined, mobile missing (Req 1.7)', () {
      // Mobile falls back to tablet (next-smaller defined is tablet).
      expect(
        resolveResponsiveValue<String>(
          FormFactor.mobile,
          tablet: 'T',
          desktop: 'D',
        ),
        'T',
      );
      // Desktop uses its own defined value.
      expect(
        resolveResponsiveValue<String>(
          FormFactor.desktop,
          tablet: 'T',
          desktop: 'D',
        ),
        'D',
      );
      // Tablet uses its own defined value.
      expect(
        resolveResponsiveValue<String>(
          FormFactor.tablet,
          tablet: 'T',
          desktop: 'D',
        ),
        'T',
      );
    });
  });
}
