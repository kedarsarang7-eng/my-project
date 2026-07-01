// ============================================================================
// Task 8.4 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 7: Active destination
// reflects the current screen
// **Validates: Requirements 9.7, 5.4**
// ============================================================================
// Property 7 (design.md): For any `currentScreen` value, the active selection
// reported by each navigation surface (drawer highlight, bottom-nav index,
// desktop sidebar selection) corresponds to that `currentScreen` under the
// surface's id/index mapping, and changing `currentScreen` changes the
// reported active selection to match.
//
// Requirement 9.7: "WHEN the current screen changes, THE Application SHALL
// reflect the active destination in the navigation surface for the current
// Form_Factor within 500 milliseconds."
// Requirement 5.4: "WHEN the End_User selects a navigation destination on
// Desktop, THE Desktop_Shell SHALL mark that destination as the active
// selection."
//
// Units under test — pure, side-effect-free mappings (no widget pumping
// needed). The navigation surfaces derive their active selection solely from
// `currentScreen` via these functions, so the property is expressed entirely
// over the pure mappings:
//   * Bottom nav (mobile/tablet): `screenForIndex` / `selectedIndexForScreen`
//     from `package:dukanx/core/responsive/mobile_bottom_nav.dart`.
//   * Drawer highlight + desktop sidebar: `AppScreen.id` / `AppScreen.fromId`
//     from `package:dukanx/core/navigation/app_screens.dart`.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/active_destination_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/navigation/app_screens.dart';
import 'package:dukanx/core/responsive/mobile_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  /// The effective bottom-nav selection the [MobileBottomNav] widget reports
  /// for [screen]: the highlighted destination, or the dashboard (index 0)
  /// fallback when the screen is drawer-only. This mirrors exactly what the
  /// widget computes (`selectedIndexForScreen(currentScreen) ?? 0`), so the
  /// property reasons about the *reported* active selection.
  int effectiveBottomNavIndex(AppScreen screen) =>
      selectedIndexForScreen(screen) ?? 0;

  // Generator over every defined AppScreen — the full `currentScreen` space.
  final Generator<AppScreen> screenGen = Gen.elementOf<AppScreen>(
    AppScreen.values,
  );

  // Generator over bottom-nav indices 0..kBottomNavPrimaryCount-1.
  final Generator<int> navIndexGen = Gen.interval(
    0,
    kBottomNavPrimaryCount - 1,
  );

  // Generator over a wide int range (including negatives and out-of-range
  // values) to prove `screenForIndex` is total and exception-free.
  final Generator<int> anyIndexGen = Gen.interval(-100, 1000);

  group('Feature: cross-platform-responsive-ui, Property 7: Active destination '
      'reflects the current screen', () {
    // -- Facet (a): bottom-nav index <-> screen round trip ------------------
    // For every primary destination index i, mapping i -> screen -> index must
    // return i. This is the documented round-trip guarantee that lets the
    // bottom nav highlight the destination matching the current screen.
    test('Property 7 (a): selectedIndexForScreen(screenForIndex(i)) == i for '
        'every primary index i in [0, kBottomNavPrimaryCount-1]', () {
      final held = forAll(
        (int i) {
          final AppScreen screen = screenForIndex(i);
          return selectedIndexForScreen(screen) == i;
        },
        [navIndexGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Facet (b): bottom-nav mapping is total and exception-free ----------
    // `selectedIndexForScreen` returns null (drawer-only) or a valid primary
    // index for ANY screen and never throws; `screenForIndex` returns a real
    // AppScreen for ANY int (out-of-range falls back to the dashboard) and
    // never throws. Totality keeps the navigation surface crash-free.
    test('Property 7 (b): selectedIndexForScreen is null or in '
        '[0, kBottomNavPrimaryCount-1] and screenForIndex always returns a '
        'valid AppScreen — both exception-free', () {
      final indexHeld = forAll(
        (int anyIndex) {
          final AppScreen screen = screenForIndex(anyIndex);
          // Always a defined enum value, never throws.
          return AppScreen.values.contains(screen);
        },
        [anyIndexGen],
        numRuns: kNumRuns,
      );
      expect(indexHeld, isTrue);

      final screenHeld = forAll(
        (AppScreen screen) {
          final int? idx = selectedIndexForScreen(screen);
          // Either drawer-only (null) or a valid primary index.
          return idx == null || (idx >= 0 && idx < kBottomNavPrimaryCount);
        },
        [screenGen],
        numRuns: kNumRuns,
      );
      expect(screenHeld, isTrue);
    });

    // -- Facet (c): desktop sidebar / drawer id mapping round trip ----------
    // The desktop sidebar marks `currentScreen.id` as active and the drawer
    // highlights the item whose `AppScreen.fromId(item.id) == currentScreen`.
    // For ANY screen: its id is non-empty (a usable selection key) and the id
    // round-trips back to the same screen, so the highlighted destination
    // always corresponds to `currentScreen`.
    test(
      'Property 7 (c): screen.id is non-empty and AppScreen.fromId(screen.id) '
      '== screen for every screen (sidebar/drawer highlight corresponds to '
      'currentScreen)',
      () {
        final held = forAll(
          (AppScreen screen) {
            final String id = screen.id;
            if (id.isEmpty) {
              return false;
            }
            return AppScreen.fromId(id) == screen;
          },
          [screenGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // -- Facet (d): the reported selection is a function of currentScreen,
    //               and updates when currentScreen changes category/id --------
    // (1) Determinism: equal currentScreen values yield equal reported
    //     selections on every surface (the selection is a pure function of
    //     currentScreen — no hidden state).
    // (2) Updates on change: distinct screens always have distinct sidebar ids
    //     (the id mapping is injective), so any change of currentScreen changes
    //     the desktop sidebar selection; and when two screens belong to
    //     different bottom-nav categories (different non-null indices) the
    //     reported bottom-nav selection differs accordingly.
    test('Property 7 (d): the active selection is a deterministic function of '
        'currentScreen and changes when currentScreen moves to a different '
        'id/category', () {
      final held = forAll(
        (AppScreen a, AppScreen b) {
          // (1) Determinism / function-of-currentScreen: two independent
          // evaluations of the same input must agree (no hidden state).
          final int firstEval = effectiveBottomNavIndex(a);
          final int secondEval = effectiveBottomNavIndex(a);
          if (firstEval != secondEval) {
            return false;
          }

          if (a == b) {
            // Same currentScreen -> identical reported selection on each
            // surface.
            return effectiveBottomNavIndex(a) == effectiveBottomNavIndex(b) &&
                a.id == b.id;
          }

          // Different currentScreen -> the desktop sidebar selection (the id)
          // must change, because the id mapping is injective.
          if (a.id == b.id) {
            return false;
          }

          // When the two screens map to different (non-null) bottom-nav
          // categories, the reported bottom-nav index must differ too.
          final int? ia = selectedIndexForScreen(a);
          final int? ib = selectedIndexForScreen(b);
          if (ia != null && ib != null && ia != ib) {
            return effectiveBottomNavIndex(a) != effectiveBottomNavIndex(b);
          }
          return true;
        },
        [screenGen, screenGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Deterministic example tests: the five known primary destinations ---
    test('Property 7: known primary screens map to their fixed bottom-nav '
        'indices', () {
      expect(selectedIndexForScreen(AppScreen.executiveDashboard), 0);
      expect(selectedIndexForScreen(AppScreen.newSale), 1);
      expect(selectedIndexForScreen(AppScreen.stockSummary), 2);
      expect(selectedIndexForScreen(AppScreen.customers), 3);
      expect(selectedIndexForScreen(AppScreen.settings), 4);
    });

    test('Property 7: bottom-nav indices map back to the canonical primary '
        'screens', () {
      expect(screenForIndex(0), AppScreen.executiveDashboard);
      expect(screenForIndex(1), AppScreen.newSale);
      expect(screenForIndex(2), AppScreen.stockSummary);
      expect(screenForIndex(3), AppScreen.customers);
      expect(screenForIndex(4), AppScreen.settings);
    });

    test('Property 7: a drawer-only screen has no bottom-nav index (null) and '
        'the widget falls back to the dashboard', () {
      // `gstr1` is a real screen reachable only via the drawer, not one of the
      // five bottom-nav categories.
      expect(selectedIndexForScreen(AppScreen.gstr1), isNull);
      expect(effectiveBottomNavIndex(AppScreen.gstr1), 0);
    });

    test('Property 7: out-of-range bottom-nav indices fall back to the '
        'dashboard without throwing', () {
      expect(screenForIndex(-1), AppScreen.executiveDashboard);
      expect(screenForIndex(99), AppScreen.executiveDashboard);
    });
  });
}
