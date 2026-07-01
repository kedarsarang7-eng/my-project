// ============================================================================
// PHASE 5 — Task 6.2: OCR scan-bill route registration test
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 6.2 — Rebuild OCR scan-bill as a GoRouter route reusing the existing
//            AWS Textract "Smart Inventory Import" pipeline.
// Validates: Requirements 8.4, 8.5
//
// WHAT THIS PROVES:
//   1) REGISTRATION (Req 8.4): the live `appRouterProvider` GoRouter registers
//      exactly one child `GoRoute` named `scan_bill` at path `/app/scan-bill`,
//      UNDER the main `ShellRoute`.
//   2) PIPELINE REUSE (Req 8.4, 8.5): the route's screen resolves to the
//      EXISTING pipeline entry screen `ScanBillImagePickerScreen` (from
//      `features/purchase/scan_bill.dart`), wired with the active business
//      type as its `verticalType` — NO new OCR is built. We assert this via
//      the pure `AppRouter.buildScanBillScreen` seam (constructing the widget
//      runs no `createState()`/IO).
//   3) CAPABILITY BINDING + GUARD (Req 8.4): `scan_bill` is bound to
//      `useScanOCR`, so the router guard ALLOWS grocery (granted useScanOCR)
//      and DENIES a type lacking it (wholesale / restaurant). The decision is
//      driven through the pure `AppRouter.redirectDecision` seam, mirroring the
//      Phase 3 capability-guard tests.
//   4) LEGACY-INVENTORY ISOLATION: `scan_bill` is a NEW post-legacy route, so
//      it does NOT pollute the frozen 90-id legacy inventory contracts
//      (`knownItemIds` / `isKnownItemId` / `pathForItemId`). It resolves only
//      through the `nav*` helpers used by the sidebar dispatch and the guard.
//
// TEST-ONLY: no production behavior is changed by this task.
//
// Run: flutter test test/core/routing/phase5_scan_bill_route_test.dart
// ============================================================================

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/features/purchase/presentation/screens/scan_bill_image_picker_screen.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Recursively collects every registered [GoRoute] (name -> path) and the set
/// of all declared paths, descending through [ShellRouteBase] / sub-routes.
void _collectGoRoutes(
  List<RouteBase> routes,
  Map<String, String> pathByName,
  Map<String, int> pathCounts,
) {
  for (final route in routes) {
    if (route is GoRoute) {
      pathCounts[route.path] = (pathCounts[route.path] ?? 0) + 1;
      final name = route.name;
      if (name != null) pathByName[name] = route.path;
      _collectGoRoutes(route.routes, pathByName, pathCounts);
    } else if (route is ShellRouteBase) {
      _collectGoRoutes(route.routes, pathByName, pathCounts);
    }
  }
}

void main() {
  // The active business type name the live router passes as verticalType
  // (`ref.read(businessTypeProvider).type.name`).
  const String grocery = 'grocery'; // BusinessType.grocery.name

  group('Feature: gorouter-navigation-migration — Phase 5 OCR scan-bill route '
      '(Req 8.4, 8.5)', () {
    final Map<String, String> pathByName = <String, String>{};
    final Map<String, int> pathCounts = <String, int>{};
    late ProviderContainer container;

    setUpAll(() {
      container = ProviderContainer();
      final GoRouter router = container.read(appRouterProvider);
      _collectGoRoutes(router.configuration.routes, pathByName, pathCounts);
    });

    tearDownAll(() => container.dispose());

    // ----------------------------------------------------------------------
    // 1) Registration: exactly one `scan_bill` route at `/app/scan-bill`.
    // ----------------------------------------------------------------------
    test('a single scan_bill GoRoute is registered at /app/scan-bill', () {
      expect(
        pathByName[RoutePaths.scanBillName],
        RoutePaths.scanBill,
        reason:
            'The router must register a route named "scan_bill" at '
            '"${RoutePaths.scanBill}".',
      );
      expect(RoutePaths.scanBill, '/app/scan-bill');
      expect(
        pathCounts[RoutePaths.scanBill],
        1,
        reason: 'Exactly one GoRoute must declare "/app/scan-bill".',
      );
    });

    // ----------------------------------------------------------------------
    // 2) Pipeline reuse: the route screen IS the existing pipeline entry
    //    screen, wired with the active business type as verticalType.
    // ----------------------------------------------------------------------
    test('the route reuses the existing ScanBillImagePickerScreen pipeline '
        'entry (no new OCR), scoped to the active business type', () {
      final screen = AppRouter.buildScanBillScreen(grocery);
      expect(
        screen,
        isA<ScanBillImagePickerScreen>(),
        reason: 'Task 6.2 must REUSE the existing pipeline entry screen.',
      );
      expect(
        (screen as ScanBillImagePickerScreen).verticalType,
        grocery,
        reason: 'The pipeline session must be scoped to the active vertical.',
      );
    });

    // ----------------------------------------------------------------------
    // 3) Capability binding + guard: useScanOCR — grocery allowed, a type
    //    lacking it denied (entry-path independent, via the pure seam).
    // ----------------------------------------------------------------------
    test('scan_bill is bound to useScanOCR', () {
      expect(
        AppRouter.requiredCapabilityFor('scan_bill'),
        BusinessCapability.useScanOCR,
      );
    });

    test('grocery (granted useScanOCR) is ALLOWED to the scan_bill route', () {
      // Precondition: grocery genuinely grants useScanOCR.
      expect(
        FeatureResolver.canAccess(grocery, BusinessCapability.useScanOCR),
        isTrue,
      );
      expect(
        AppRouter.redirectDecision('scan_bill', grocery),
        isNull,
        reason: 'grocery must reach the scan-bill route (allow).',
      );
    });

    test('a business type lacking useScanOCR is DENIED the scan_bill route', () {
      // wholesale and restaurant are NOT granted useScanOCR (audit-confirmed).
      for (final type in <String>[
        BusinessType.wholesale.name,
        BusinessType.restaurant.name,
      ]) {
        // Precondition: the type genuinely lacks the capability.
        expect(
          FeatureResolver.canAccess(type, BusinessCapability.useScanOCR),
          isFalse,
          reason: '"$type" must NOT grant useScanOCR for the deny premise.',
        );
        expect(
          AppRouter.redirectDecision('scan_bill', type),
          RoutePaths.denied,
          reason:
              'A type lacking useScanOCR must be denied the scan-bill '
              'route (S3 gate applies to the new route too).',
        );
      }
    });

    // ----------------------------------------------------------------------
    // 4) Navigable resolution + legacy-inventory isolation.
    // ----------------------------------------------------------------------
    test(
      'scan_bill resolves via the nav* helpers (sidebar dispatch + guard)',
      () {
        expect(RoutePaths.isNavItemId('scan_bill'), isTrue);
        expect(RoutePaths.navPathForItemId('scan_bill'), RoutePaths.scanBill);
        expect(RoutePaths.navItemIdForPath(RoutePaths.scanBill), 'scan_bill');
      },
    );

    test('scan_bill does NOT pollute the frozen 90-id legacy inventory', () {
      expect(
        RoutePaths.isKnownItemId('scan_bill'),
        isFalse,
        reason: 'scan_bill is a NEW route, not a legacy dispatch itemId.',
      );
      expect(
        RoutePaths.knownItemIds,
        hasLength(90),
        reason: 'The legacy inventory must remain exactly 90 ids.',
      );
      expect(
        RoutePaths.pathForItemId('scan_bill'),
        RoutePaths.notFound,
        reason: 'The legacy-only resolver must not resolve the new route.',
      );
    });
  });
}
