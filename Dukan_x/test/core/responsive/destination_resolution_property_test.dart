// ============================================================================
// Task 7.2 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 6: Destination resolution
// outcome
// **Validates: Requirements 3.4, 3.6, 9.6**
// ============================================================================
// Property 6 (design.md): For any destination id and the navigable screen set
// for the active business context, resolving the id yields EXACTLY ONE of two
// outcomes:
//   (a) `resolved`     with a concrete AppScreen equal to AppScreen.fromId(id),
//                      when that screen is known AND navigable (selection
//                      navigates to that screen); or
//   (b) `unavailable`  when AppScreen.fromId(id) is `unknown` OR the screen is
//                      not navigable (the current screen is retained, no
//                      navigation occurs).
// The two outcomes are mutually exclusive and total over all ids.
//
// Unit under test:
//   `DestinationResolver.resolve(String id, Set<AppScreen> navigable)`
//   returning `(DestinationResolution, AppScreen)`, from
//   `package:dukanx/core/responsive/navigation_destinations.dart`.
//   Id->screen mapping comes from `AppScreen.fromId` in
//   `package:dukanx/core/navigation/app_screens.dart`.
//
// Oracle: the expected outcome is re-derived INDEPENDENTLY from `fromId` and a
// plain `navigable.contains` membership check, exactly as the spec states. The
// property then asserts `resolve`'s outcome equals that single expected
// outcome for every input — which simultaneously proves the outcomes are
// disjoint (never both) and total (always exactly one).
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/destination_resolution_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/navigation/app_screens.dart';
import 'package:dukanx/core/responsive/navigation_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single generated resolution scenario: a destination [id] (valid or
/// garbage) paired with a [navigable] screen set for the active business
/// context.
class _ResolveCase {
  const _ResolveCase(this.id, this.navigable);
  final String id;
  final Set<AppScreen> navigable;
}

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // Curated list of REAL destination ids known to `AppScreen.fromId` (drawn
  // from its explicit case mappings). Each maps to a concrete, non-unknown
  // screen, so it exercises the `resolved` branch whenever the screen is
  // navigable. `daily_appointments` and `alert` are intentional aliases that
  // map onto `appointments`/`alerts`.
  const List<String> kValidIds = <String>[
    'executive_dashboard',
    'new_sale',
    'sales_register',
    'stock_summary',
    'item_stock',
    'customers',
    'party_ledger',
    'outstanding',
    'gstr1',
    'transaction_reports',
    'device_settings',
    'settings',
    'patients_list',
    'prescriptions',
    'appointments',
    'add_patient',
    'clinic_dashboard',
    'daily_appointments',
    'restaurant_tables',
    'service_jobs',
    'exchanges',
    'revenue_overview',
    'receipt_entry',
    'proforma_bids',
    'booking_orders',
    'dispatch_notes',
    'return_inwards',
    'alert',
    'alerts',
    'daily_snapshot',
    'buyflow_dashboard',
    'purchase_orders',
    'stock_entry',
    'stock_reversal',
    'procurement_log',
    'supplier_bills',
    'purchase_register',
    'insights',
    'daybook',
    'credit_notes',
    'backup',
    'analytics_hub',
    'catalogue',
  ];

  // Composite generator producing a `_ResolveCase`. It deliberately mixes:
  //   * the id source — ~70% a curated REAL id, ~30% a random/garbage string
  //     that almost always maps to AppScreen.unknown; and
  //   * the navigable set — shaped so BOTH outcomes are exercised heavily:
  //     forced-resolved (add the resolved screen), forced-navigable-superset
  //     (all screens), mixed (raw subset), and forced-unavailable (empty).
  // Because the oracle re-derives the expected outcome from `fromId`, the exact
  // distribution only affects coverage, never correctness of the assertion.
  final Generator<_ResolveCase> caseGen =
      Gen.tuple([
        Gen.interval(0, 9), // 0: id mode (valid vs garbage)
        Gen.elementOf<String>(kValidIds), // 1: a curated valid id
        Gen.string(minLength: 0, maxLength: 10), // 2: garbage id
        Gen.set<AppScreen>(
          Gen.elementOf<AppScreen>(AppScreen.values),
          minSize: 0,
          maxSize: 30,
        ), // 3: base navigable subset
        Gen.interval(0, 9), // 4: navigable mode
      ]).map((parts) {
        final int idMode = parts[0] as int;
        final String validId = parts[1] as String;
        final String garbage = parts[2] as String;
        final Set<AppScreen> base = parts[3] as Set<AppScreen>;
        final int navMode = parts[4] as int;

        // ~70% curated valid id, ~30% garbage (mostly -> unknown).
        final String id = idMode < 7 ? validId : garbage;
        final AppScreen resolvedScreen = AppScreen.fromId(id);

        final Set<AppScreen> navigable = <AppScreen>{...base};
        if (navMode <= 3) {
          // Bias toward the `resolved` branch for known ids.
          if (resolvedScreen != AppScreen.unknown)
            navigable.add(resolvedScreen);
        } else if (navMode <= 5) {
          // Every known id is navigable here.
          navigable.addAll(AppScreen.values);
        } else if (navMode >= 8) {
          // Force the `unavailable` (not-navigable) branch.
          navigable.clear();
        }
        // navMode 6..7: leave the raw subset untouched (mixed coverage).

        return _ResolveCase(id, navigable);
      });

  group('Feature: cross-platform-responsive-ui, Property 6: Destination '
      'resolution outcome', () {
    // -- Property: resolve == exactly the one expected outcome --------------
    test('Property 6: resolve yields `resolved` (screen known and navigable) '
        'or `unavailable` (unknown or not navigable) — mutually exclusive and '
        'total over all ids', () {
      final held = forAll(
        (_ResolveCase c) {
          final String id = c.id;
          final Set<AppScreen> navigable = c.navigable;

          final (DestinationResolution res, AppScreen screen) =
              DestinationResolver.resolve(id, navigable);

          // Independent oracle (Req 3.4/3.6/9.6 wording): a destination is
          // unavailable iff fromId is unknown OR the screen is not navigable.
          final AppScreen expectedScreen = AppScreen.fromId(id);
          final bool expectUnavailable =
              expectedScreen == AppScreen.unknown ||
              !navigable.contains(expectedScreen);

          // The resolver always reports the screen `fromId` computes, in BOTH
          // outcomes (the design returns the resolved/unknown screen alongside
          // the outcome).
          if (screen != expectedScreen) return false;

          // Asserting `res` equals the single expected outcome proves the two
          // outcomes are disjoint (never both) and total (always exactly one),
          // because `DestinationResolution` has exactly these two values.
          if (expectUnavailable) {
            return res == DestinationResolution.unavailable;
          }
          return res == DestinationResolution.resolved &&
              navigable.contains(screen) &&
              screen != AppScreen.unknown;
        },
        [caseGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Explicit edge cases (deterministic coverage of each branch) --------
    test('Property 6: a known, navigable id resolves and navigates', () {
      final navigable = {AppScreen.newSale, AppScreen.customers};
      final (res, screen) = DestinationResolver.resolve('new_sale', navigable);
      expect(res, DestinationResolution.resolved);
      expect(screen, AppScreen.newSale);
      expect(navigable.contains(screen), isTrue);
    });

    test('Property 6: a known id that is NOT navigable is unavailable and '
        'retains the (current) screen mapping without resolving', () {
      // `new_sale` is known but absent from the navigable set.
      final navigable = {AppScreen.customers};
      final (res, screen) = DestinationResolver.resolve('new_sale', navigable);
      expect(res, DestinationResolution.unavailable);
      expect(screen, AppScreen.newSale);
    });

    test('Property 6: an unknown/garbage id is always unavailable, even when '
        'the navigable set contains every screen', () {
      final navigable = AppScreen.values.toSet();
      final (res, screen) = DestinationResolver.resolve(
        '##no-such-destination##',
        navigable,
      );
      expect(res, DestinationResolution.unavailable);
      expect(screen, AppScreen.unknown);
    });

    test('Property 6: an empty navigable set makes every id unavailable', () {
      final (res, screen) = DestinationResolver.resolve(
        'settings',
        <AppScreen>{},
      );
      expect(res, DestinationResolution.unavailable);
      expect(screen, AppScreen.settings);
    });
  });
}
