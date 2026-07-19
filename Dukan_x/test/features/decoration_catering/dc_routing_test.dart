// ============================================================================
// Task 2.2 — Routing regression-lock test for the 8 previously-unrouted DC
// screens (Calendar, Quotes, Profitability, ShoppingList, VendorPayments,
// EventDetail, QuoteConversion, StaffAttendance)
// Feature: decoration-catering-remediation
// **Validates: Requirements 2.1 (AC3)**
// ============================================================================
//
// design.md: "THE LegacyRoutes registry SHALL register guarded `GoRoute`s for
// all 8 previously-unrouted DC screens (Calendar, Quotes, Profitability,
// ShoppingList, VendorPayments, EventDetail, QuoteConversion,
// StaffAttendance), locked in by a routing test enumerating each route."
//
// Regression-lock only — per design.md's Current State Assessment these 8
// routes are already registered in `legacy_routes.dart`; this test does not
// change production code, it locks the existing wiring in so a future change
// to `legacy_routes.dart` cannot silently drop one of these routes or its
// guards without breaking the build.
//
// WHAT THIS PROVES, for each of the 8 paths:
//   1. `LegacyRoutes.routes()` registers EXACTLY ONE top-level `GoRoute` for
//      the path.
//   2. That route's builder resolves (structurally, no widget pumping needed)
//      to a `VendorRoleGuard` carrying the expected `requiredPermission`.
//   3. Wrapping a `BusinessGuard` whose `allowedTypes` includes
//      `BusinessType.decorationCatering` (the business-isolation guard).
//   4. Wrapping the correct target screen widget type.
//
// SEAM: each `GoRoute.builder` is a pure `(BuildContext, GoRouterState) =>
// Widget` function that (for these 8 routes) does not call `context` methods
// and only reads `state.extra` for the two argument-bearing routes
// (`/dc/event_detail`, `/dc/quote_conversion`). So the returned widget TREE
// (an actual object graph: VendorRoleGuard -> BusinessGuard -> Screen) can be
// inspected directly via field access, with no `pumpWidget`/`build()` call
// needed for the guard-wrapper assertions — mirroring the direct-builder-call
// technique used elsewhere in this repo's routing tests (e.g.
// `test/core/routing/phase2_sidebar_dispatch_test.dart`).
//
// A real `BuildContext` + `GoRouterState` (with `extra` set where needed) is
// captured cheaply via a tiny harness `GoRouter` push — no production
// screens, sessions, or API clients are pumped/mocked.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/decoration_catering/dc_routing_test.dart --reporter expanded
// ============================================================================

import 'package:dukanx/config/permissions.dart';
import 'package:dukanx/core/auth/role_guard.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/features/core/auth/business_type_guard.dart';
import 'package:dukanx/features/decoration_catering/data/models/dc_models.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_calendar_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_event_detail_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_profitability_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_quotes_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_shopping_list_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_staff_attendance_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_vendor_payments_screen.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Recursively collects every [GoRoute] reachable from [routes], descending
/// into nested `routes` (mirrors the established helper used across
/// `test/core/routing/*.dart`).
List<GoRoute> _allGoRoutes(List<RouteBase> routes) {
  final List<GoRoute> result = <GoRoute>[];
  for (final RouteBase route in routes) {
    if (route is GoRoute) {
      result.add(route);
    }
    if (route.routes.isNotEmpty) {
      result.addAll(_allGoRoutes(route.routes));
    }
  }
  return result;
}

/// A minimal, valid [DcQuote] fixture used as the `extra` payload for
/// `/dc/quote_conversion` (its builder's success branch requires a `DcQuote`
/// instance, falling back to `DcQuotesScreen` otherwise — see
/// `kExpectedDcRoutes` below for the fallback case).
final DcQuote _sampleQuote = DcQuote(
  id: 'quote_dc_routing_test_001',
  quoteNumber: 'Q-TEST-001',
  customerName: 'Routing Test Customer',
  customerPhone: '9999999999',
  eventType: 'Wedding',
  subtotal: 10000,
  gstAmount: 1800,
  total: 11800,
  createdAt: DateTime(2024, 1, 1),
);

/// One entry per previously-unrouted DC screen (Requirement 2.1 AC3),
/// describing the exact guard/permission/screen contract each registered
/// `GoRoute` must satisfy.
class _ExpectedDcRoute {
  const _ExpectedDcRoute({
    required this.path,
    required this.requiredPermission,
    required this.screenType,
    this.extra,
  });

  final String path;
  final String requiredPermission;
  final Type screenType;
  final Object? extra;
}

final List<_ExpectedDcRoute> kExpectedDcRoutes = <_ExpectedDcRoute>[
  _ExpectedDcRoute(
    path: '/dc/calendar',
    requiredPermission: Permissions.viewInvoices,
    screenType: DcCalendarScreen,
  ),
  _ExpectedDcRoute(
    path: '/dc/quotes',
    requiredPermission: Permissions.viewInvoices,
    screenType: DcQuotesScreen,
  ),
  _ExpectedDcRoute(
    path: '/dc/profitability',
    requiredPermission: Permissions.viewReports,
    screenType: DcProfitabilityScreen,
  ),
  _ExpectedDcRoute(
    path: '/dc/shopping_list',
    requiredPermission: Permissions.viewInvoices,
    screenType: DcShoppingListScreen,
  ),
  _ExpectedDcRoute(
    path: '/dc/vendor_payments',
    requiredPermission: Permissions.viewInvoices,
    screenType: DcVendorPaymentsScreen,
  ),
  _ExpectedDcRoute(
    path: '/dc/event_detail',
    requiredPermission: Permissions.viewInvoices,
    screenType: DcEventDetailScreen,
    extra: 'evt_dc_routing_test_001',
  ),
  _ExpectedDcRoute(
    path: '/dc/quote_conversion',
    requiredPermission: Permissions.createInvoices,
    screenType: DcQuoteConversionScreen,
    extra: _sampleQuote,
  ),
  _ExpectedDcRoute(
    // Requirement 3.7 (AC4): staff_attendance now requires the fine-grained
    // `manageStaff` permission instead of the borrowed `viewInvoices`
    // (Task 18.1, decoration-catering-remediation).
    path: '/dc/staff_attendance',
    requiredPermission: Permissions.manageStaff,
    screenType: DcStaffAttendanceScreen,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<GoRoute> registeredRoutes = _allGoRoutes(LegacyRoutes.routes());

  group('Feature: decoration-catering-remediation, Requirement 2.1 (AC3) — all 8 '
      'previously-unrouted DC screens have a registered guarded GoRoute', () {
    // ----------------------------------------------------------------
    // Precondition sanity: exactly 8 fixtures, matching the requirement's
    // named list of screens (documents the enumeration this test locks).
    // ----------------------------------------------------------------
    test('precondition: this test enumerates exactly the 8 named screens', () {
      expect(kExpectedDcRoutes.length, 8);
      expect(
        kExpectedDcRoutes.map((e) => e.screenType).toSet(),
        equals(<Type>{
          DcCalendarScreen,
          DcQuotesScreen,
          DcProfitabilityScreen,
          DcShoppingListScreen,
          DcVendorPaymentsScreen,
          DcEventDetailScreen,
          DcQuoteConversionScreen,
          DcStaffAttendanceScreen,
        }),
      );
    });

    for (final expected in kExpectedDcRoutes) {
      testWidgets('"${expected.path}" is registered exactly once, guarded by '
          'VendorRoleGuard(requiredPermission: ${expected.requiredPermission}) '
          '+ BusinessGuard([decorationCatering]), resolving to '
          '${expected.screenType}', (tester) async {
        // ------------------------------------------------------------
        // 1) Exactly one registered GoRoute for this path.
        // ------------------------------------------------------------
        final List<GoRoute> matches = registeredRoutes
            .where((r) => r.path == expected.path)
            .toList();
        expect(
          matches.length,
          1,
          reason:
              'Requirement 2.1 AC3: "${expected.path}" must be registered '
              'by exactly one top-level GoRoute in LegacyRoutes.routes(); '
              'found ${matches.length}.',
        );
        final GoRoute route = matches.first;
        expect(
          route.builder,
          isNotNull,
          reason: '"${expected.path}" must have a non-null builder.',
        );

        // ------------------------------------------------------------
        // Capture a real BuildContext + GoRouterState (with `extra` set
        // where the route needs it) via a tiny harness push — no
        // production screens/sessions/API clients involved.
        // ------------------------------------------------------------
        late BuildContext capturedContext;
        late GoRouterState capturedState;
        final tinyRouter = GoRouter(
          initialLocation: '/harness-home',
          routes: <RouteBase>[
            GoRoute(
              path: '/harness-home',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push('/harness-target', extra: expected.extra),
                    child: const Text('GO'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/harness-target',
              builder: (context, state) {
                capturedContext = context;
                capturedState = state;
                return const SizedBox.shrink();
              },
            ),
          ],
        );
        addTearDown(tinyRouter.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: tinyRouter));
        await tester.pumpAndSettle();
        await tester.tap(find.text('GO'));
        await tester.pumpAndSettle();

        // ------------------------------------------------------------
        // 2) The route's builder resolves (structurally) to a
        //    VendorRoleGuard carrying the expected requiredPermission.
        // ------------------------------------------------------------
        final Widget built = route.builder!(capturedContext, capturedState);
        expect(
          built,
          isA<VendorRoleGuard>(),
          reason:
              'Requirement 2.1 AC3: "${expected.path}" must be wrapped in '
              'a VendorRoleGuard, got ${built.runtimeType}.',
        );
        final VendorRoleGuard roleGuard = built as VendorRoleGuard;
        expect(
          roleGuard.requiredPermission,
          expected.requiredPermission,
          reason:
              '"${expected.path}" must require permission '
              '"${expected.requiredPermission}", got '
              '"${roleGuard.requiredPermission}".',
        );

        // ------------------------------------------------------------
        // 3) Wrapping a BusinessGuard restricted to decorationCatering.
        // ------------------------------------------------------------
        expect(
          roleGuard.child,
          isA<BusinessGuard>(),
          reason:
              'Requirement 2.1 AC3: "${expected.path}" must nest a '
              'BusinessGuard inside its VendorRoleGuard, got '
              '${roleGuard.child.runtimeType}.',
        );
        final BusinessGuard businessGuard = roleGuard.child as BusinessGuard;
        expect(
          businessGuard.allowedTypes,
          contains(BusinessType.decorationCatering),
          reason:
              '"${expected.path}" BusinessGuard.allowedTypes must include '
              'decorationCatering, got ${businessGuard.allowedTypes}.',
        );

        // ------------------------------------------------------------
        // 4) Wrapping the correct target screen widget type.
        // ------------------------------------------------------------
        expect(
          businessGuard.child.runtimeType,
          expected.screenType,
          reason:
              '"${expected.path}" must resolve to ${expected.screenType}, '
              'got ${businessGuard.child.runtimeType}.',
        );

        // Argument-bearing routes: confirm the `extra` payload was
        // actually threaded through to the screen (not silently dropped).
        if (expected.path == '/dc/event_detail') {
          expect(
            (businessGuard.child as DcEventDetailScreen).eventId,
            expected.extra,
          );
        } else if (expected.path == '/dc/quote_conversion') {
          expect(
            (businessGuard.child as DcQuoteConversionScreen).quote,
            same(expected.extra),
          );
        }
      });
    }

    // --------------------------------------------------------------------
    // No-duplicate sanity across the full set: the 8 paths together
    // register exactly 8 GoRoutes (reinforces the per-path exactly-one
    // assertions above with a single aggregate check).
    // --------------------------------------------------------------------
    test('the 8 previously-unrouted DC paths together register exactly 8 '
        'GoRoutes (no duplicates, none missing)', () {
      final Set<String> expectedPaths = kExpectedDcRoutes
          .map((e) => e.path)
          .toSet();
      final List<String> matchingRegisteredPaths = registeredRoutes
          .map((r) => r.path)
          .where(expectedPaths.contains)
          .toList();

      expect(
        matchingRegisteredPaths.length,
        8,
        reason:
            'Expected exactly 8 registered GoRoutes across the named '
            'paths, found ${matchingRegisteredPaths.length}: '
            '$matchingRegisteredPaths',
      );
      expect(matchingRegisteredPaths.toSet(), equals(expectedPaths));
    });
  });

  _dcVendorsRoutingLockGroup();
}

// ============================================================================
// Task 2.1 — Routing regression lock: /dc/vendors -> DcVendorPaymentsScreen
// **Validates: Requirement 2.1 (AC2)**
// ============================================================================
//
// Requirement 2.1 AC2: "THE LegacyRoutes registry SHALL map `/dc/vendors` to
// `DcVendorPaymentsScreen`, locked in by a routing test asserting the route
// target class." Regression-lock only — the mapping is already correct
// (NOT DcStaffScreen, the original audit's stale claim).
// ============================================================================

void _dcVendorsRoutingLockGroup() {
  group('Feature: decoration-catering-remediation — Requirement 2.1 AC2: '
      '/dc/vendors routing regression lock', () {
    test('LegacyRoutes.routes() registers exactly one top-level GoRoute for '
        '"/dc/vendors"', () {
      final matches = LegacyRoutes.routes()
          .whereType<GoRoute>()
          .where((route) => route.path == '/dc/vendors')
          .toList();

      expect(
        matches,
        hasLength(1),
        reason:
            'Exactly one GoRoute must be registered for "/dc/vendors" in '
            'LegacyRoutes.routes().',
      );
    });

    testWidgets('the "/dc/vendors" GoRoute\'s builder resolves — through its '
        'VendorRoleGuard(child: BusinessGuard(child: ...)) wrapper chain — '
        'to DcVendorPaymentsScreen as the route target class '
        '(NOT DcStaffScreen, the original audit\'s stale claim)', (
      tester,
    ) async {
      late BuildContext capturedContext;
      late GoRouterState capturedState;
      final tinyRouter = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) {
              capturedContext = context;
              capturedState = state;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(tinyRouter.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: tinyRouter));
      await tester.pumpAndSettle();

      final dcVendorsRoute = LegacyRoutes.routes()
          .whereType<GoRoute>()
          .firstWhere((route) => route.path == '/dc/vendors');

      final built = dcVendorsRoute.builder!(capturedContext, capturedState);

      expect(
        built,
        isA<VendorRoleGuard>(),
        reason:
            '"/dc/vendors" must resolve to its lifted VendorRoleGuard '
            'wrapper.',
      );
      final vendorRoleGuard = built as VendorRoleGuard;

      expect(
        vendorRoleGuard.child,
        isA<BusinessGuard>(),
        reason: '"/dc/vendors" VendorRoleGuard must wrap a BusinessGuard.',
      );
      final businessGuard = vendorRoleGuard.child as BusinessGuard;
      expect(
        businessGuard.allowedTypes,
        equals(const <BusinessType>[BusinessType.decorationCatering]),
      );

      expect(
        businessGuard.child,
        isA<DcVendorPaymentsScreen>(),
        reason:
            'Requirement 2.1 AC2: "/dc/vendors" must map to '
            'DcVendorPaymentsScreen as its route target class.',
      );
    });
  });
}
