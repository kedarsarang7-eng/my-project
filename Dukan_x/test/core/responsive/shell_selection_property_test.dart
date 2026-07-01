// ============================================================================
// Task 8.2 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 4: Shell selection is a total
// function of Form_Factor
// **Validates: Requirements 5.1, 9.1, 9.2, 9.3, 13.4**
// ============================================================================
// Property 4 (design.md): For any logical width w (and orientation), the
//   Adaptive_Shell selects
//     * the Desktop_Shell  if and only if w >= 1100,
//     * the Tablet_Shell   if and only if 600 <= w < 1100 (choosing the
//       landscape or portrait variant according to the current orientation),
//     * the Mobile_Shell   if and only if w < 600.
//   The Tablet_Shell is selected only in the Tablet band and never on Mobile
//   or Desktop. The generated widths must include the exact boundary values
//   599, 600, 1099, and 1100, and both orientations.
//
// Unit under test: the PURE `selectShell(double width, Orientation orientation)`
//   returning a `Shell` enum, from
//   `package:dukanx/core/responsive/adaptive_shell.dart`. This is the single
//   decision point the AdaptiveShell.build() switches on, so testing it
//   directly proves the selection invariant without building a widget tree.
//
//   `Shell` has four members:
//     * Shell.desktop          -> Desktop_Shell
//     * Shell.tabletLandscape  -> Tablet_Shell (landscape variant)
//     * Shell.tabletPortrait   -> Tablet_Shell (portrait variant)
//     * Shell.mobile           -> Mobile_Shell
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/shell_selection_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/responsive/adaptive_shell.dart';
import 'package:flutter/material.dart' show Orientation;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // The exact Breakpoint_Strategy boundary values that must be exercised, plus
  // the lower edge (0) and a large desktop width. Including them in the
  // generated stream guarantees the off-by-one edges around 600 and 1100 are
  // sampled by the property itself (in addition to the explicit test below).
  const List<int> kBoundaryWidths = <int>[0, 599, 600, 1099, 1100, 4000];

  // True iff [shell] is one of the two Tablet_Shell variants.
  bool isTablet(Shell shell) =>
      shell == Shell.tabletLandscape || shell == Shell.tabletPortrait;

  // Width generator over [0, 4000] logical pixels. With ~1-in-4 probability it
  // emits one of the boundary widths so the exact edges 599/600/1099/1100 are
  // sampled frequently; otherwise it emits a uniformly drawn width across the
  // full supported range. Integers are converted to doubles on use, exactly
  // matching how a real MediaQuery width feeds `selectShell`.
  final Generator<int> widthGen =
      Gen.tuple([
        Gen.interval(0, 4000),
        Gen.interval(0, kBoundaryWidths.length * 4 - 1),
      ]).map((parts) {
        final int raw = parts[0] as int;
        final int selector = parts[1] as int;
        if (selector < kBoundaryWidths.length) return kBoundaryWidths[selector];
        return raw;
      });

  // A generated scenario: a width paired with an orientation. Both orientations
  // (portrait/landscape) are sampled so the Tablet variant selection is
  // exercised under each.
  final caseGen = Gen.tuple([
    widthGen,
    Gen.elementOf<Orientation>(Orientation.values),
  ]);

  group('Feature: cross-platform-responsive-ui, Property 4: Shell selection is '
      'a total function of Form_Factor', () {
    // -- Property: selectShell obeys the band biconditionals + variant rule --
    test('Property 4: selectShell == Desktop iff w >= 1100, == a Tablet '
        'variant iff 600 <= w < 1100 (matching orientation), == Mobile iff '
        'w < 600; Tablet never on Mobile/Desktop', () {
      final held = forAll(
        (List<dynamic> scenario) {
          final double w = (scenario[0] as int).toDouble();
          final Orientation orientation = scenario[1] as Orientation;

          final Shell shell = selectShell(w, orientation);

          // Each clause is a biconditional (iff): the shell is band X exactly
          // when w lies in band X's range. Asserting all three simultaneously
          // also proves selection is total and disjoint over the three bands.
          final bool desktopIff = (shell == Shell.desktop) == (w >= 1100);
          final bool tabletIff = isTablet(shell) == (w >= 600 && w < 1100);
          final bool mobileIff = (shell == Shell.mobile) == (w < 600);

          // The Tablet band picks its variant from the orientation; outside the
          // Tablet band neither variant may be selected.
          final bool variantMatchesOrientation =
              !isTablet(shell) ||
              (orientation == Orientation.landscape
                  ? shell == Shell.tabletLandscape
                  : shell == Shell.tabletPortrait);

          // Tablet is selected ONLY in the Tablet band (never Mobile/Desktop).
          final bool tabletOnlyInBand =
              !isTablet(shell) || (w >= 600 && w < 1100);

          return desktopIff &&
              tabletIff &&
              mobileIff &&
              variantMatchesOrientation &&
              tabletOnlyInBand;
        },
        [caseGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Explicit boundary assertions (guaranteed edge coverage) ------------
    // Direct, deterministic checks of the off-by-one edges and the extremes
    // under both orientations, so the exact boundary behavior is verified even
    // independent of the generator's sampling.
    test('Property 4: exact boundary and extreme widths select the correct '
        'shell under both orientations', () {
      // Mobile band: w < 600 -> Mobile regardless of orientation.
      for (final o in Orientation.values) {
        expect(selectShell(0, o), Shell.mobile);
        expect(selectShell(599, o), Shell.mobile);
      }

      // Tablet band: 600 <= w < 1100 -> variant chosen by orientation.
      expect(selectShell(600, Orientation.portrait), Shell.tabletPortrait);
      expect(selectShell(600, Orientation.landscape), Shell.tabletLandscape);
      expect(selectShell(1099, Orientation.portrait), Shell.tabletPortrait);
      expect(selectShell(1099, Orientation.landscape), Shell.tabletLandscape);

      // Desktop band: w >= 1100 -> Desktop regardless of orientation.
      for (final o in Orientation.values) {
        expect(selectShell(1100, o), Shell.desktop);
        expect(selectShell(4000, o), Shell.desktop);
      }
    });
  });
}
