// ============================================================================
// PHASE 3 — Task 4.3: Capability router-guard focused test
// (go_router navigation migration — security fix S3)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 4.3 — Implement `requiredCapabilityFor` + `AppRouter.capabilityRedirect`.
// Validates: Requirements 6.1, 6.2, 6.3, 6.4
//
// PURPOSE (focused fix verification — full 18-type preservation is Task 4.5):
//   Prove the router-level capability guard:
//     (1) DENIES grocery navigation to each of the six previously-ungated
//         items — the guard redirects to `RoutePaths.denied` (Req 6.1, 6.4),
//     (2) ALLOWS a type that HAS the capability (wholesale for all six;
//         pharmacy for the ones it grants) to reach the screen (Req 6.2),
//     (3) Mirrors the existing sidebar `capability:` bindings (Req 6.x), and
//     (4) Enforces independent of entry path — the decision is keyed off the
//         route's `itemId`, which the guard resolves from BOTH the route name
//         and a deep-link URL path (Req 6.3).
//
// The security-critical allow/deny decision is asserted via the pure,
// deterministic `AppRouter.redirectDecision(itemId, businessType)` (extracted
// from `capabilityRedirect`) so we do not build the heavy real screens. The
// deny ROUTE registration is checked against the live router configuration.
// ============================================================================

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _GuardCase {
  const _GuardCase(this.itemId, this.capability);
  final String itemId;
  final BusinessCapability capability;
}

/// The six previously-ungated grocery items now bound by Task 4.3.
/// `booking_orders -> useDispatchNote` per the Task 4.1 business decision.
const List<_GuardCase> _newlyGated = <_GuardCase>[
  _GuardCase('return_inwards', BusinessCapability.useSalesReturn),
  _GuardCase('proforma_bids', BusinessCapability.useProformaInvoice),
  _GuardCase('dispatch_notes', BusinessCapability.useDispatchNote),
  _GuardCase('booking_orders', BusinessCapability.useDispatchNote),
  _GuardCase('stock_reversal', BusinessCapability.useStockReversal),
  _GuardCase('purchase_register', BusinessCapability.usePurchaseRegister),
];

/// Bindings mirrored 1:1 from `sidebar_configuration.dart` `capability:` fields.
const List<_GuardCase> _mirrored = <_GuardCase>[
  _GuardCase('scan_qr', BusinessCapability.usePatientRegistry),
  _GuardCase('prescriptions', BusinessCapability.usePrescription),
  _GuardCase('medicine_master', BusinessCapability.usePrescription),
  _GuardCase('batch_tracking', BusinessCapability.useBatchExpiry),
  _GuardCase('restaurant_tables', BusinessCapability.useTableManagement),
];

void _collectRoutePaths(List<RouteBase> routes, Set<String> paths) {
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
      _collectRoutePaths(route.routes, paths);
    } else if (route is ShellRouteBase) {
      _collectRoutePaths(route.routes, paths);
    }
  }
}

void main() {
  final String grocery = BusinessType.grocery.name; // 'grocery'
  final String wholesale = BusinessType.wholesale.name; // has all six
  final String pharmacy = BusinessType.pharmacy.name;

  group('Feature: gorouter-navigation-migration — Phase 3 capability guard '
      '(Req 6.1, 6.2, 6.3, 6.4)', () {
    // ----------------------------------------------------------------------
    // requiredCapabilityFor — the route -> capability binding map.
    // ----------------------------------------------------------------------
    test('requiredCapabilityFor binds the six newly-gated grocery items', () {
      for (final c in _newlyGated) {
        expect(
          AppRouter.requiredCapabilityFor(c.itemId),
          c.capability,
          reason: '"${c.itemId}" must bind to ${c.capability.name} (Req 6.4).',
        );
      }
    });

    test('requiredCapabilityFor mirrors the existing sidebar bindings', () {
      for (final c in _mirrored) {
        expect(
          AppRouter.requiredCapabilityFor(c.itemId),
          c.capability,
          reason:
              '"${c.itemId}" must mirror sidebar_configuration.dart binding '
              '${c.capability.name}.',
        );
      }
    });

    test('requiredCapabilityFor returns null for an ungated route', () {
      // new_sale / executive_dashboard carry no capability gate.
      expect(AppRouter.requiredCapabilityFor('new_sale'), isNull);
      expect(AppRouter.requiredCapabilityFor('executive_dashboard'), isNull);
    });

    // ----------------------------------------------------------------------
    // DENY: grocery navigation to each bound item -> deny path (Req 6.1, 6.4).
    // ----------------------------------------------------------------------
    test(
      'grocery navigation to each of the six items REDIRECTS to deny path',
      () {
        for (final c in _newlyGated) {
          expect(
            AppRouter.redirectDecision(c.itemId, grocery),
            RoutePaths.denied,
            reason:
                'grocery lacks ${c.capability.name}, so navigating "${c.itemId}" '
                'must redirect to the deny screen (S3 fix).',
          );
        }
      },
    );

    // ----------------------------------------------------------------------
    // ALLOW: a type WITH the capability reaches the screen (Req 6.2).
    // ----------------------------------------------------------------------
    test('wholesale (has all six) is ALLOWED to navigate every item', () {
      for (final c in _newlyGated) {
        expect(
          AppRouter.redirectDecision(c.itemId, wholesale),
          isNull,
          reason:
              'wholesale grants ${c.capability.name}, so navigation to '
              '"${c.itemId}" must be allowed (null redirect).',
        );
      }
    });

    test('pharmacy is ALLOWED for the items it grants '
        '(return_inwards, stock_reversal, purchase_register)', () {
      for (final itemId in const [
        'return_inwards', // useSalesReturn ✓
        'stock_reversal', // useStockReversal ✓
        'purchase_register', // usePurchaseRegister ✓
      ]) {
        expect(
          AppRouter.redirectDecision(itemId, pharmacy),
          isNull,
          reason: 'pharmacy has the capability for "$itemId"; must be allowed.',
        );
      }
      // pharmacy lacks useDispatchNote / useProformaInvoice -> denied.
      expect(
        AppRouter.redirectDecision('dispatch_notes', pharmacy),
        RoutePaths.denied,
      );
      expect(
        AppRouter.redirectDecision('proforma_bids', pharmacy),
        RoutePaths.denied,
      );
    });

    // ----------------------------------------------------------------------
    // Ungated and foundation/sentinel routes are always allowed (no loop).
    // ----------------------------------------------------------------------
    test('ungated routes and null itemId (foundation/sentinel) are allowed', () {
      expect(AppRouter.redirectDecision('new_sale', grocery), isNull);
      expect(AppRouter.redirectDecision(null, grocery), isNull);
      // The deny route itself carries no binding -> allowed (no redirect loop).
      final denyItemId = RoutePaths.itemIdForPath(RoutePaths.denied);
      expect(AppRouter.redirectDecision(denyItemId, grocery), isNull);
    });

    // ----------------------------------------------------------------------
    // The deny route is registered so the redirect target is reachable.
    // ----------------------------------------------------------------------
    test('the deny route is registered in the router configuration', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      final paths = <String>{};
      _collectRoutePaths(router.configuration.routes, paths);

      expect(
        paths,
        contains(RoutePaths.denied),
        reason:
            'A GoRoute for the deny screen must exist as a redirect target.',
      );
    });
  });
}
