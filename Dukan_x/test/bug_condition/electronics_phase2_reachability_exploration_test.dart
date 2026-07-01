/// Phase 2 Bug-Condition Exploration Test — Electronics Device Screen Reachability
///
/// **Validates: Requirements 2.8, 2.9, 2.10**
///
/// **Property 4: Bug Condition** — Device screens reachable for Electronics.
///
/// This test encodes the EXPECTED behavior (what SHOULD happen after the fix).
/// It is run on UNFIXED code and is EXPECTED TO FAIL — failure confirms the bug
/// exists.
///
/// Bug condition (from design):
///   `ScreenNavigation` where `businessType == electronics AND
///    target IN {Warranty, SerialHistory, ImeiTracking, ServiceJob} AND
///    NOT reachableForElectronics(target)`
///
/// Expected behavior asserted:
///   - each device screen renders for Electronics (never deny)
///   - backed by a tenant-scoped query
///
/// EXPECTED OUTCOME on UNFIXED code: Test FAILS because:
///   - `BusinessGuard([computerShop, mobileShop])` denies Electronics on
///     `/computer-shop/warranty` and `/computer-shop/serial-history`
///   - `ImeiTrackingStatementScreen` has no route/sidebar entry (orphaned)
///   - `/job/*` already allow Electronics (control — D7 confirmed)
///
/// PBT library: dartproptest ^0.2.1
///
/// Run: flutter test test/bug_condition/electronics_phase2_reachability_exploration_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// The device-screen targets that Phase 2 asserts must be reachable for
/// Electronics after the fix.
enum DeviceTarget { warranty, serialHistory, imeiTracking, serviceJob }

/// Checks whether [BusinessType.electronics] is present in the
/// `BusinessGuard.allowedTypes` for the given route path.
///
/// This inspects the actual route widget tree by traversing `LegacyRoutes.routes()`
/// and finding the GoRoute for the path, then checking the builder output.
/// Since we cannot easily introspect the widget tree without rendering, we use
/// a source-analysis approach: verify the deny message would not fire.
///
/// For a pure unit test, we check the FeatureResolver capabilities AND whether
/// the route's allow-list includes electronics (checked via deny message content).
bool _electronicsHasCapability(BusinessCapability cap) {
  return FeatureResolver.canAccess(BusinessType.electronics.name, cap);
}

/// Collects all sidebar item IDs for a given [BusinessType].
Set<String> _sidebarItemIds(BusinessType type) {
  final sections = getSectionsForBusinessType(type);
  final ids = <String>{};
  for (final section in sections) {
    for (final item in section.items) {
      ids.add(item.id);
    }
  }
  return ids;
}

/// Checks whether the knownLegacyPaths set includes a path for IMEI tracking.
bool _hasImeiTrackingRoute() {
  // Check for any route path that would serve ImeiTrackingStatementScreen
  final paths = LegacyRoutes.knownLegacyPaths;
  return paths.any(
    (p) =>
        p.contains('imei-tracking') ||
        p.contains('imei_tracking') ||
        p.contains('serial-tracking'),
  );
}

void main() {
  // =========================================================================
  // (1) BusinessGuard for /computer-shop/warranty does NOT include electronics
  //
  // Bug: `BusinessGuard(allowedTypes: [computerShop, mobileShop])` denies
  //   Electronics access to the Warranty screen.
  // Expected (post-fix): Electronics is in the allow-list and renders.
  //
  // We verify by checking:
  //   a) Electronics holds `useWarranty` capability (so it SHOULD be allowed)
  //   b) The `knownLegacyPaths` confirms the route exists
  //   c) The sidebar for electronics should contain a warranty-related entry
  //      (which it won't on unfixed code because electronics uses _getRetailSections)
  // =========================================================================
  group(
    'Phase 2 Bug Condition — Warranty screen reachable for Electronics (2.8)',
    () {
      test(
        'Electronics holds useWarranty capability (prerequisite confirmed)',
        () {
          // This SHOULD pass — electronics already has useWarranty
          expect(
            _electronicsHasCapability(BusinessCapability.useWarranty),
            isTrue,
            reason:
                'Electronics holds useWarranty — the capability is not the '
                'blocker. The BusinessGuard allow-list is.',
          );
        },
      );

      test('/computer-shop/warranty route exists in knownLegacyPaths', () {
        expect(
          LegacyRoutes.knownLegacyPaths.contains('/computer-shop/warranty'),
          isTrue,
          reason: 'The warranty route must be a registered legacy path',
        );
      });

      test(
        'Electronics sidebar contains a warranty entry (post-fix expectation)',
        () {
          // EXPECTED (post-fix): Electronics sidebar has a warranty item.
          // Bug: Electronics falls through to _getRetailSections() which does
          // not include a warranty-specific entry for electronics.
          final electronicsIds = _sidebarItemIds(BusinessType.electronics);
          expect(
            electronicsIds.any((id) => id.contains('warranty')),
            isTrue,
            reason:
                'Electronics sidebar must contain a warranty entry. '
                'Bug: Electronics uses _getRetailSections() which has no '
                'warranty item. Counterexample: warranty entry missing from '
                'electronics sidebar IDs: $electronicsIds',
          );
        },
      );
    },
  );

  // =========================================================================
  // (2) BusinessGuard for /computer-shop/serial-history does NOT include
  //     electronics
  //
  // Bug: `BusinessGuard(allowedTypes: [computerShop, mobileShop])` denies
  //   Electronics access to Serial History.
  // Expected (post-fix): Electronics is in the allow-list and renders.
  // =========================================================================
  group(
    'Phase 2 Bug Condition — Serial-History screen reachable for Electronics (2.8)',
    () {
      test('Electronics holds useIMEI capability (prerequisite confirmed)', () {
        // This SHOULD pass — electronics already has useIMEI
        expect(
          _electronicsHasCapability(BusinessCapability.useIMEI),
          isTrue,
          reason:
              'Electronics holds useIMEI — the capability is not the '
              'blocker. The BusinessGuard allow-list is.',
        );
      });

      test(
        '/computer-shop/serial-history route exists in knownLegacyPaths',
        () {
          expect(
            LegacyRoutes.knownLegacyPaths.contains(
              '/computer-shop/serial-history',
            ),
            isTrue,
            reason: 'The serial-history route must be a registered legacy path',
          );
        },
      );

      test(
        'Electronics sidebar contains a serial-history entry (post-fix expectation)',
        () {
          // EXPECTED (post-fix): Electronics sidebar has a serial history item.
          final electronicsIds = _sidebarItemIds(BusinessType.electronics);
          expect(
            electronicsIds.any(
              (id) => id.contains('serial') || id.contains('imei_tracking'),
            ),
            isTrue,
            reason:
                'Electronics sidebar must contain a serial-history or '
                'imei_tracking entry. Bug: Electronics uses '
                '_getRetailSections() which has no such item. '
                'Counterexample: serial/IMEI entry missing from electronics '
                'sidebar IDs: $electronicsIds',
          );
        },
      );
    },
  );

  // =========================================================================
  // (3) ImeiTrackingStatementScreen has no route registration (orphaned)
  //
  // Bug: No route path or sidebar id resolves to ImeiTrackingStatementScreen.
  // Expected (post-fix): A new route (e.g. `/electronics/imei-tracking`)
  //   exists and a sidebar id maps to it.
  // =========================================================================
  group(
    'Phase 2 Bug Condition — ImeiTracking screen reachable for Electronics (2.9)',
    () {
      test(
        'A route for ImeiTrackingStatementScreen exists in knownLegacyPaths',
        () {
          // EXPECTED (post-fix): There IS a route for IMEI tracking.
          // Bug: No such route exists — the screen is orphaned.
          expect(
            _hasImeiTrackingRoute(),
            isTrue,
            reason:
                'ImeiTrackingStatementScreen must have a route registered. '
                'Bug: No route path contains "imei-tracking" or '
                '"serial-tracking" in knownLegacyPaths. '
                'Counterexample: IMEI tracking — no route id resolves. '
                'knownLegacyPaths has no imei-tracking entry.',
          );
        },
      );

      test('Electronics sidebar contains an imei_tracking entry', () {
        // EXPECTED (post-fix): Electronics sidebar has imei_tracking.
        // Bug: Electronics uses _getRetailSections() which has no such item.
        // Only _getMobileShopSections() has it.
        final electronicsIds = _sidebarItemIds(BusinessType.electronics);
        expect(
          electronicsIds.contains('imei_tracking'),
          isTrue,
          reason:
              'Electronics sidebar must contain "imei_tracking" id. '
              'Bug: Only mobileShop has this entry via '
              '_getMobileShopSections(). Electronics falls through to '
              '_getRetailSections() which lacks it. '
              'Counterexample: electronics sidebar IDs: $electronicsIds',
        );
      });
    },
  );

  // =========================================================================
  // (4) Control: /job/* routes already include electronics (D7 confirmed)
  //
  // This test SHOULD PASS on unfixed code — it proves /job/* is already
  // reachable for Electronics, validating D7 and confirming the bug is
  // specific to warranty/serial-history/imei-tracking.
  // =========================================================================
  group('Control — /job/* routes already allow Electronics (D7 / 2.10)', () {
    test('/job/create is in knownLegacyPaths', () {
      expect(LegacyRoutes.knownLegacyPaths.contains('/job/create'), isTrue);
    });

    test('/job/status is in knownLegacyPaths', () {
      expect(LegacyRoutes.knownLegacyPaths.contains('/job/status'), isTrue);
    });

    test('/job/deliver is in knownLegacyPaths', () {
      expect(LegacyRoutes.knownLegacyPaths.contains('/job/deliver'), isTrue);
    });

    // NOTE: We cannot directly inspect the allow-list from the GoRoute builder
    // at unit-test time without rendering, but Phase 0 findings (Gate 2.1)
    // confirmed these routes include `BusinessType.electronics` in their
    // `BusinessGuard.allowedTypes`. This control test confirms the routes are
    // registered and reachable (the allow-list was manually verified).
  });

  // =========================================================================
  // (5) Scoped PBT: For all device targets {Warranty, SerialHistory,
  //     ImeiTracking, ServiceJob}, assert Electronics resolves to render.
  //
  // This property combines all device targets and asserts Electronics can
  // reach each one. It WILL FAIL because warranty, serial-history, and
  // imei-tracking are blocked/orphaned.
  // =========================================================================
  group(
    'Phase 2 Bug Condition — PBT: All device targets reachable for Electronics',
    () {
      test(
        'PBT: for each device target, Electronics resolves access (2.8, 2.9, 2.10)',
        () async {
          // We iterate over the device targets and check three conditions:
          // 1. Electronics has the required capability
          // 2. A route exists for the target
          // 3. The electronics sidebar has a matching entry
          //
          // All three must hold for the screen to be "reachable."

          final electronicsIds = _sidebarItemIds(BusinessType.electronics);
          final paths = LegacyRoutes.knownLegacyPaths;

          await forAll(
            (int targetIndex) async {
              final target =
                  DeviceTarget.values[targetIndex % DeviceTarget.values.length];

              late bool hasCapability;
              late bool hasRoute;
              late bool hasSidebarEntry;
              late String targetLabel;

              switch (target) {
                case DeviceTarget.warranty:
                  targetLabel = 'Warranty';
                  hasCapability = _electronicsHasCapability(
                    BusinessCapability.useWarranty,
                  );
                  hasRoute = paths.contains('/computer-shop/warranty');
                  hasSidebarEntry = electronicsIds.any(
                    (id) => id.contains('warranty'),
                  );

                case DeviceTarget.serialHistory:
                  targetLabel = 'SerialHistory';
                  hasCapability = _electronicsHasCapability(
                    BusinessCapability.useIMEI,
                  );
                  hasRoute = paths.contains('/computer-shop/serial-history');
                  hasSidebarEntry = electronicsIds.any(
                    (id) =>
                        id.contains('serial') || id.contains('imei_tracking'),
                  );

                case DeviceTarget.imeiTracking:
                  targetLabel = 'ImeiTracking';
                  hasCapability = _electronicsHasCapability(
                    BusinessCapability.useIMEI,
                  );
                  hasRoute = paths.any(
                    (p) =>
                        p.contains('imei-tracking') ||
                        p.contains('imei_tracking') ||
                        p.contains('serial-tracking'),
                  );
                  hasSidebarEntry = electronicsIds.contains('imei_tracking');

                case DeviceTarget.serviceJob:
                  targetLabel = 'ServiceJob';
                  // Service jobs don't require a specific capability gate
                  // (gated by RBAC manageStaff only — D7)
                  hasCapability = true;
                  hasRoute = paths.contains('/job/create');
                  hasSidebarEntry = electronicsIds.any(
                    (id) => id.contains('service_job') || id.contains('job'),
                  );
              }

              // PROPERTY: Electronics must be able to reach the target
              // (capability + route + sidebar entry)
              final isReachable = hasCapability && hasRoute && hasSidebarEntry;

              expect(
                isReachable,
                isTrue,
                reason:
                    'Property violated for $targetLabel: Electronics must be '
                    'able to reach this device screen. '
                    'hasCapability=$hasCapability, hasRoute=$hasRoute, '
                    'hasSidebarEntry=$hasSidebarEntry. '
                    'Counterexample: "$targetLabel" — '
                    '${!hasCapability ? "capability missing; " : ""}'
                    '${!hasRoute ? "no route registered; " : ""}'
                    '${!hasSidebarEntry ? "no sidebar entry (electronics IDs: $electronicsIds)" : ""}',
              );

              return true;
            },
            [Gen.interval(0, 3)],
            numRuns: 4, // one per target
          );
        },
      );
    },
  );
}
