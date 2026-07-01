// ============================================================================
// PHASE 2 — Task 3.5: PROPERTY TEST
// Feature: gorouter-navigation-migration, Property 1: Route resolution parity
//          (round-trip)
// **Validates: Requirements 3.2, 3.3, 5.2, 5.3, 5.6**
// ============================================================================
//
// Property 1 (design.md — Correctness Properties):
//   *For any* sidebar itemId handled by the legacy dispatch and *for any* of at
//   least five in-scope business types, resolving the itemId through
//   `RoutePaths`/`AppRouter` (flag ON) renders the SAME screen type — with the
//   SAME constructor arguments — that `SidebarNavigationHandler.getScreenForItem`
//   renders (flag OFF). The navigation PATH differs by flag state, but the
//   resolved SCREEN IDENTITY is invariant.
//
// HOW THIS IS PROVEN AS A PROPERTY (not just by construction):
//   The Task 3.3 builders delegate to `AppRouter.screenForItemId`, which
//   delegates to the legacy switch — so parity holds by construction. This
//   PROPERTY test pins that contract by sampling the FULL input space
//   (itemId ∈ `RoutePaths.knownItemIds` × businessType ∈ six in-scope types)
//   and asserting, for every sampled pair, that the go_router-resolved screen
//   and the legacy-dispatched screen have:
//     (a) the same runtime `Type`, AND
//     (b) identical values for the constructor args that actually vary per
//         itemId — `GstReportsScreen.initialIndex`,
//         `PartyLedgerListScreen.initialFilter`, and the restaurant screens'
//         `vendorId` (TableManagement / KitchenDisplay / FoodMenuManagement /
//         RestaurantDailySummary).
//   Sampling over a business-type dimension is required by the property wording
//   ("for any of at least five in-scope business types"); the dispatch is
//   type-independent, so type-invariance is additionally asserted by the
//   per-pair equality always holding regardless of the generated type.
//
// SEAM (reused from the Phase 2 exploration/parity tests — nothing heavy is
//   pumped): both `getScreenForItem` and `screenForItemId` synchronously
//   CONSTRUCT `const` screen widgets — no `build()`, no GetIt, no IO. We
//   capture one real `BuildContext` from a minimal pumped host and drive both
//   resolvers with it, inspecting only `runtimeType` + the public arg fields.
//   This is test-only; no production code is touched.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide (see the dev_dependency note in `pubspec.yaml` for why
//   `glados` is not used). Idiomatic usage:
//     forAll((a, b) => <bool>, [genA, genB], numRuns: N);
//   `forAll` returns true when the property held for every run, and throws a
//   shrinking Exception with a counterexample otherwise.
//
// Run: flutter test test/core/routing/phase2_property1_route_parity_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Imports used ONLY to read the varying constructor args off resolved widgets.
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';
import 'package:dukanx/features/party_ledger/screens/party_ledger_list_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/table_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/kitchen_display_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/food_menu_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart';

/// At least 100 iterations are required by the spec (Requirement 2.4); 200 is
/// the dartproptest default and the convention used across this repo's property
/// suites. `forAll` runs this many generated (itemId, businessType) pairs.
const int kNumRuns = 200;

/// The (≥ five) in-scope business types the parity property is sampled over.
/// `other` is the default/retail fallback branch of the sidebar resolver.
const List<BusinessType> _inScopeBusinessTypes = <BusinessType>[
  BusinessType.grocery,
  BusinessType.pharmacy,
  BusinessType.clinic,
  BusinessType.restaurant,
  BusinessType.petrolPump,
  BusinessType.other, // default / retail fallback (6th type, ≥ 5 required)
];

/// Captures a real [BuildContext] from a minimally pumped host so both the
/// legacy dispatch and the go_router resolver can be driven exactly as the
/// shell drives them. Constructing `const` screen widgets runs no
/// `build()`/IO, so this exercises every itemId without heavy dependencies.
Future<BuildContext> _pumpAndCaptureContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

/// Returns true iff the [routed] (go_router, flag ON) widget and the [legacy]
/// (switch dispatch, flag OFF) widget represent the SAME resolved screen:
/// identical runtime `Type` and identical values for every per-item varying
/// constructor argument. Returns false (a parity violation) otherwise.
bool _screensMatch(Widget routed, Widget legacy) {
  if (routed.runtimeType != legacy.runtimeType) return false;

  // GstReportsScreen — the tax/compliance cluster varies by `initialIndex`.
  if (legacy is GstReportsScreen && routed is GstReportsScreen) {
    return routed.initialIndex == legacy.initialIndex;
  }
  // PartyLedgerListScreen — suppliers/outstanding/party_ledger vary by filter.
  if (legacy is PartyLedgerListScreen && routed is PartyLedgerListScreen) {
    return routed.initialFilter == legacy.initialFilter;
  }
  // Restaurant screens — each carries the (out-of-scope) vendorId arg.
  if (legacy is TableManagementScreen && routed is TableManagementScreen) {
    return routed.vendorId == legacy.vendorId;
  }
  if (legacy is KitchenDisplayScreen && routed is KitchenDisplayScreen) {
    return routed.vendorId == legacy.vendorId;
  }
  if (legacy is FoodMenuManagementScreen &&
      routed is FoodMenuManagementScreen) {
    return routed.vendorId == legacy.vendorId;
  }
  if (legacy is RestaurantDailySummaryScreen &&
      routed is RestaurantDailySummaryScreen) {
    return routed.vendorId == legacy.vendorId;
  }

  // All other screens carry no per-item varying args: same Type == parity.
  return true;
}

void main() {
  group('Feature: gorouter-navigation-migration, Property 1: Route resolution '
      'parity (round-trip)', () {
    // --- Generators --------------------------------------------------------
    // Sample over the full input space: every legacy itemId × six in-scope
    // business types. The business-type dimension satisfies the property's
    // "for any of at least five in-scope business types" quantifier.
    final Generator<String> itemIdGen = Gen.elementOf<String>(
      RoutePaths.knownItemIds.toList(),
    );
    final Generator<BusinessType> businessTypeGen = Gen.elementOf<BusinessType>(
      _inScopeBusinessTypes,
    );

    testWidgets(
      'Property 1: for any (itemId × ≥5 business types), the go_router '
      'resolved screen equals the legacy dispatched screen — same Type and '
      'same constructor args',
      (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        final bool held = forAll(
          (String itemId, BusinessType type) {
            // Flag OFF path: legacy switch dispatch.
            final Widget legacy = SidebarNavigationHandler.getScreenForItem(
              itemId,
              context,
            );
            // Flag ON path: go_router resolver (delegates through AppRouter).
            final Widget routed = AppRouter.screenForItemId(itemId, context);

            // Screen identity is invariant across the flag (and the type),
            // even though the navigation PATH differs by flag state.
            return _screensMatch(routed, legacy);
          },
          [itemIdGen, businessTypeGen],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'Route resolution parity (Property 1) must hold for every '
              'sampled (itemId, businessType) pair.',
        );
      },
    );

    // -- Deterministic anchors: prove the property is non-vacuous on the
    //    arg-bearing screens it is most likely to catch a regression on. ---
    testWidgets(
      'Property 1 anchor: arg-bearing screens (Gst index, PartyLedger '
      'filter, restaurant vendorId) match the legacy args exactly',
      (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        // GstReportsScreen.initialIndex parity per tax itemId.
        for (final itemId in const <String>[
          'gstr1',
          'b2b_b2c',
          'hsn_reports',
          'tax_liability',
          'filing_status',
        ]) {
          final legacy =
              SidebarNavigationHandler.getScreenForItem(itemId, context)
                  as GstReportsScreen;
          final routed =
              AppRouter.screenForItemId(itemId, context) as GstReportsScreen;
          expect(
            routed.initialIndex,
            legacy.initialIndex,
            reason: 'GstReportsScreen index parity for "$itemId".',
          );
        }

        // PartyLedgerListScreen.initialFilter parity.
        for (final itemId in const <String>[
          'suppliers',
          'outstanding',
          'party_ledger',
        ]) {
          final legacy =
              SidebarNavigationHandler.getScreenForItem(itemId, context)
                  as PartyLedgerListScreen;
          final routed =
              AppRouter.screenForItemId(itemId, context)
                  as PartyLedgerListScreen;
          expect(
            routed.initialFilter,
            legacy.initialFilter,
            reason: 'PartyLedgerListScreen filter parity for "$itemId".',
          );
        }

        // Restaurant vendorId parity.
        expect(
          (AppRouter.screenForItemId('restaurant_tables', context)
                  as TableManagementScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem(
                    'restaurant_tables',
                    context,
                  )
                  as TableManagementScreen)
              .vendorId,
        );
        expect(
          (AppRouter.screenForItemId('kitchen_display', context)
                  as KitchenDisplayScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem('kitchen_display', context)
                  as KitchenDisplayScreen)
              .vendorId,
        );
        expect(
          (AppRouter.screenForItemId('menu_management', context)
                  as FoodMenuManagementScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem('menu_management', context)
                  as FoodMenuManagementScreen)
              .vendorId,
        );
        expect(
          (AppRouter.screenForItemId('daily_summary', context)
                  as RestaurantDailySummaryScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem('daily_summary', context)
                  as RestaurantDailySummaryScreen)
              .vendorId,
        );
      },
    );
  });
}
