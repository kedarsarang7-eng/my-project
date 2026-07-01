// ============================================================================
// PHASE 2 — Task 3.7: PROPERTY TEST — duplicate mappings preserved
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration, Property 3: Duplicate mappings
//          preserved
// Validates: Requirements 5.4
//
// PROPERTY 3 (design.md):
//   For ANY documented duplicate itemId pair (purchase_register/
//   procurement_log, invoice_margin/income_statement, funds_flow/cash_bank,
//   gstr1/b2b_b2c, print_settings/doc_templates, and the AllTransactionsScreen
//   cluster ledger_history/turnover_analysis/daily_activity/activity_logs/
//   audit_trail/transaction_reports), BOTH itemIds resolve to the SAME shared
//   screen type under go_router (same runtimeType, and — for gstr1/b2b_b2c —
//   the same `initialIndex` arg), WITH NO deduplication during Phase 2 (their
//   `RoutePaths` paths remain DISTINCT whenever the itemIds differ).
//
// SEAMS (test-only — no production code touched):
//   * Resolver:  `AppRouter.screenForItemId(itemId, context)` — delegates to
//                the legacy `SidebarNavigationHandler.getScreenForItem` switch
//                (single source of truth), so this checks the go_router
//                resolution path.
//   * Paths:     `RoutePaths.pathForItemId(itemId)` — the pure itemId->path map.
//
// WHY a pumped-host context works with `forAll`:
//   `screenForItemId` needs a real `BuildContext`, and the duplicate screens
//   are `const`-constructed (constructing them runs NO build()/IO — see the
//   sibling exploration test). We capture ONE context from a minimal pumped
//   host and then run `forAll` SYNCHRONOUSLY against that captured context —
//   the property predicate NEVER re-pumps the binding (which would corrupt it),
//   it only inspects `runtimeType`/args + path strings. This is the same seam
//   used by `phase2_route_registration_parity_test.dart`.
//
// GENERATOR DESIGN:
//   (A) WITHIN-GROUP pairs: a tuple [groupIdx, a, b] is generated; `groupIdx`
//       selects one of the 6 documented duplicate groups, and `a`/`b` (large
//       ints reduced modulo the group length) select two members of THAT group
//       (possibly the same member). This draws random ordered pairs from inside
//       the same group, including same-member pairs, across >=100 runs.
//   (B) CROSS-GROUP pairs (anti-triviality): a tuple [gA, off, a, b] selects two
//       DIFFERENT groups (gB = (gA + 1 + off) % N) and one member from each,
//       asserting their screen types AND paths differ — so the within-group
//       "same screen" property is not trivially true of all itemIds.
//
// PBT library: dartproptest ^0.2.1 (repo-standard QuickCheck/Hypothesis-inspired
//   library; `glados` is unresolvable here — see pubspec dev_dependency note and
//   the sibling property suites). numRuns = 200 (>= the required 100).
//
// Run: flutter test test/core/routing/phase2_property3_duplicates_preserved_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Imported ONLY to read the varying `initialIndex` arg off the GstReportsScreen
// duplicate group (gstr1 / b2b_b2c must share the same tab index).
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';

/// The documented duplicate GROUPS (design Model 2). Each inner list is a set
/// of itemIds the LEGACY dispatch maps to the SAME screen type. De-dup is a
/// Phase 6 decision — in Phase 2 these are PRESERVED with distinct paths.
const List<List<String>> _duplicateGroups = <List<String>>[
  // -> ProcurementLogScreen
  <String>['purchase_register', 'procurement_log'],
  // -> PnlScreen
  <String>['invoice_margin', 'income_statement'],
  // -> CashflowScreen
  <String>['funds_flow', 'cash_bank'],
  // -> GstReportsScreen(initialIndex: 0)  (the only group with a varying arg)
  <String>['gstr1', 'b2b_b2c'],
  // -> PrintMenuScreen
  <String>['print_settings', 'doc_templates'],
  // -> AllTransactionsScreen (cluster)
  <String>[
    'ledger_history',
    'turnover_analysis',
    'daily_activity',
    'activity_logs',
    'audit_trail',
    'transaction_reports',
  ],
];

/// Captures a real [BuildContext] from a minimally pumped host so the resolver
/// can be driven exactly as the shell drives it. Constructing the `const`
/// duplicate screens runs no `build()`/IO.
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

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  group(
    'Feature: gorouter-navigation-migration, Property 3: Duplicate mappings '
    'preserved (Req 5.4)',
    () {
      // ----------------------------------------------------------------------
      // Sanity: the groups are well-formed and each maps to ONE distinct screen
      // type (a precondition for the cross-group anti-triviality property).
      // ----------------------------------------------------------------------
      testWidgets('the 6 documented duplicate groups each share one screen '
          'type, and the groups are pairwise distinct screens', (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        String typeOf(String itemId) =>
            AppRouter.screenForItemId(itemId, context).runtimeType.toString();

        final groupScreenTypes = <String>[];
        for (final group in _duplicateGroups) {
          expect(group.length, greaterThanOrEqualTo(2));
          final first = typeOf(group.first);
          for (final id in group) {
            expect(
              typeOf(id),
              first,
              reason: 'itemId "$id" must share its group\'s screen type.',
            );
            expect(
              RoutePaths.isKnownItemId(id),
              isTrue,
              reason: 'itemId "$id" must be a known migrated itemId.',
            );
          }
          groupScreenTypes.add(first);
        }
        // All six group screen types are distinct (no two groups overlap),
        // so cross-group pairs are a meaningful negative control.
        expect(
          groupScreenTypes.toSet(),
          hasLength(_duplicateGroups.length),
          reason: 'each duplicate group must map to a DISTINCT screen type.',
        );
      });

      // ----------------------------------------------------------------------
      // PROPERTY 3 (within-group): random pairs from the SAME group resolve to
      // the same screen type (+ same initialIndex for the gst group) but keep
      // DISTINCT paths whenever the itemIds differ (no dedup).
      // ----------------------------------------------------------------------
      testWidgets('Property 3: within-group pairs share the screen (and gst '
          'initialIndex) yet keep distinct paths — for any generated pair', (
        tester,
      ) async {
        final context = await _pumpAndCaptureContext(tester);

        // tuple: [groupIdx, memberSelectorA, memberSelectorB]
        final Generator<List<dynamic>> withinGroupGen = Gen.tuple(<Generator>[
          Gen.interval(0, _duplicateGroups.length - 1),
          Gen.interval(0, 100000),
          Gen.interval(0, 100000),
        ]);

        final held = forAll(
          (List<dynamic> parts) {
            final group = _duplicateGroups[parts[0] as int];
            final String idA = group[(parts[1] as int) % group.length];
            final String idB = group[(parts[2] as int) % group.length];

            final Widget screenA = AppRouter.screenForItemId(idA, context);
            final Widget screenB = AppRouter.screenForItemId(idB, context);

            // (1) Same shared screen TYPE.
            final bool sameType = screenA.runtimeType == screenB.runtimeType;

            // (2) Same key args where applicable: the gst group must agree on
            //     `initialIndex` (both gstr1 and b2b_b2c are tab 0).
            bool sameArgs = true;
            if (screenA is GstReportsScreen && screenB is GstReportsScreen) {
              sameArgs = screenA.initialIndex == screenB.initialIndex;
            }

            // (3) No dedup: distinct itemIds keep DISTINCT paths; the SAME
            //     itemId trivially shares its own path.
            final String pathA = RoutePaths.pathForItemId(idA);
            final String pathB = RoutePaths.pathForItemId(idB);
            final bool pathsConsistent = (idA == idB)
                ? (pathA == pathB)
                : (pathA != pathB);

            return sameType && sameArgs && pathsConsistent;
          },
          [withinGroupGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // ----------------------------------------------------------------------
      // ANTI-TRIVIALITY (cross-group): random pairs drawn from DIFFERENT groups
      // resolve to DIFFERENT screen types AND have DISTINCT paths — so the
      // within-group property is not vacuously true of every itemId.
      // ----------------------------------------------------------------------
      testWidgets('Property 3 (negative control): cross-group pairs differ in '
          'screen type and path — for any generated pair', (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        // tuple: [groupA, groupOffset(1..N-1), memberA, memberB]
        final int n = _duplicateGroups.length;
        final Generator<List<dynamic>> crossGroupGen = Gen.tuple(<Generator>[
          Gen.interval(0, n - 1),
          Gen.interval(0, n - 2), // 0..n-2 -> offset 1..n-1 after +1
          Gen.interval(0, 100000),
          Gen.interval(0, 100000),
        ]);

        final held = forAll(
          (List<dynamic> parts) {
            final int gA = parts[0] as int;
            final int gB = (gA + 1 + (parts[1] as int)) % n;
            final groupA = _duplicateGroups[gA];
            final groupB = _duplicateGroups[gB];
            final String idA = groupA[(parts[2] as int) % groupA.length];
            final String idB = groupB[(parts[3] as int) % groupB.length];

            final Type typeA = AppRouter.screenForItemId(
              idA,
              context,
            ).runtimeType;
            final Type typeB = AppRouter.screenForItemId(
              idB,
              context,
            ).runtimeType;

            final bool differentScreens = typeA != typeB;
            final bool distinctPaths =
                RoutePaths.pathForItemId(idA) != RoutePaths.pathForItemId(idB);

            return differentScreens && distinctPaths;
          },
          [crossGroupGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });
    },
  );
}
