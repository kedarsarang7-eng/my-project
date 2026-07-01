// ============================================================================
// TASK 1 — BUG CONDITION EXPLORATION TEST (bugfix workflow)
// Feature: restaurant-vertical-remediation
// Property 1: Bug Condition — Tenant Isolation Breach via Hardcoded vendorId
// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.13, 1.14**
// ============================================================================
//
// CRITICAL — THIS TEST IS EXPECTED TO FAIL ON UNFIXED CODE.
//   A failing run here is the SUCCESS case: it confirms the tenant-isolation
//   bug (and the related OrderType / UserRole gaps) exist. DO NOT "fix" the
//   test or the code in this task. After the P0 fix lands (task 3.x) this same
//   test should PASS unchanged, validating the fix.
//
// Bug condition (design.md — isBugCondition):
//   input.itemId IN ['restaurant_tables','kitchen_display','menu_management',
//                    'daily_summary']
//   AND input.resolvedVendorId == 'SYSTEM'
//   AND SessionManager.currentBusinessId != null
//   AND SessionManager.currentBusinessId != 'SYSTEM'
//
// Expected (post-fix) behaviour encoded as assertions:
//   screen.vendorId == SessionManager.currentBusinessId   (NOT 'SYSTEM')
//
// SEAM: `SidebarNavigationHandler.tryGetScreenForItem` is the single
//   itemId -> Widget resolver. We call it directly and inspect the `vendorId`
//   of the returned (un-mounted) screen widget — the screens are never inserted
//   into the tree, so their service-locator-backed initState never runs.
//
//   The fixed handler is expected to resolve vendorId from
//   `sl<SessionManager>().currentBusinessId`. We register a `FakeSessionManager`
//   (repo-wide pattern: `extends Mock implements SessionManager`) in GetIt with
//   a real businessId so the post-fix code has a tenant to resolve.
//
// PBT library: dartproptest ^0.2.1 (repo-wide). `forAll(pred, [gen], numRuns:)`
//   runs N generated cases and throws a shrinking counterexample on failure.
//   Here the property is SCOPED to the 4 concrete failing restaurant items.
//
// Run: flutter test test/features/restaurant/restaurant_tenant_isolation_bug_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/restaurant/data/models/food_order_model.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

/// Convention across this repo's property suites.
const int kNumRuns = 200;

/// A real, non-'SYSTEM' tenant id — the businessId of "Pizza Palace".
const String kBusinessId = 'usr_pizza_palace_123';

/// The 4 restaurant-specific sidebar items implicated by the tenant isolation
/// breach. Order is stable so generated indices map to a known item.
const List<String> kRestaurantItems = <String>[
  'restaurant_tables',
  'kitchen_display',
  'menu_management',
  'daily_summary',
];

/// A lightweight fake [SessionManager] whose `currentBusinessId` is fixed via
/// the constructor. `Mock` supplies `noSuchMethod` no-ops for every other
/// member; the fixed handler only needs `currentBusinessId` (and `userId` as a
/// fallback), which we override.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager(this._businessId);

  final String? _businessId;

  @override
  String? get currentBusinessId => _businessId;

  @override
  String? get userId => _businessId;
}

/// Reads the `vendorId` from any of the 4 restaurant screen widgets without
/// caring about their concrete type (each declares `final String vendorId`).
String? _vendorIdOf(Widget? screen) {
  if (screen == null) return null;
  return (screen as dynamic).vendorId as String?;
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    // The fixed handler resolves vendorId via sl<SessionManager>(); register a
    // real tenant so the post-fix path has something to resolve. The UNFIXED
    // handler ignores this entirely and hardcodes 'SYSTEM'.
    GetIt.I.registerSingleton<SessionManager>(FakeSessionManager(kBusinessId));
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('Property 1: Bug Condition — Tenant Isolation Breach via vendorId', () {
    testWidgets(
      'PBT (scoped): for every restaurant sidebar item, the resolved screen '
      'vendorId equals SessionManager.currentBusinessId and is never "SYSTEM"',
      (tester) async {
        // Capture a real BuildContext (the restaurant cases do not read it, but
        // the resolver signature requires one).
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final session = GetIt.I<SessionManager>();

        // Property scoped to the 4 concrete failing items via their index.
        final bool held = forAll(
          (int idx) {
            final itemId = kRestaurantItems[idx];
            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              itemId,
              context,
            );
            final vendorId = _vendorIdOf(screen);

            // Expected post-fix behaviour:
            //   vendorId == currentBusinessId  AND  vendorId != 'SYSTEM'
            return vendorId == session.currentBusinessId &&
                vendorId != 'SYSTEM';
          },
          <Generator<dynamic>>[Gen.interval(0, kRestaurantItems.length - 1)],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'Tenant isolation breach: a restaurant screen was constructed '
              'with vendorId != currentBusinessId ($kBusinessId). On unfixed '
              'code every screen receives the hardcoded literal "SYSTEM".',
        );
      },
    );

    // --- Per-item explicit counterexamples (clear, deterministic output) ---
    for (final itemId in kRestaurantItems) {
      testWidgets(
        'screen for "$itemId" must use currentBusinessId, not "SYSTEM"',
        (tester) async {
          late BuildContext context;
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (ctx) {
                  context = ctx;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          final screen = SidebarNavigationHandler.tryGetScreenForItem(
            itemId,
            context,
          );
          final vendorId = _vendorIdOf(screen);

          // Counterexample on unfixed code:
          //   vendorId == 'SYSTEM' while currentBusinessId == 'usr_pizza_palace_123'
          expect(
            vendorId,
            isNot('SYSTEM'),
            reason:
                '$itemId resolved to vendorId "SYSTEM" — tenant data bucket '
                'is shared across all restaurant tenants.',
          );
          expect(
            vendorId,
            kBusinessId,
            reason:
                '$itemId should be scoped to the authenticated tenant '
                '($kBusinessId).',
          );
        },
      );
    }
  });

  group('Property: OrderType enum completeness (Req 1.13)', () {
    test('OrderType.fromString("DELIVERY") resolves to a DELIVERY value '
        '(not a dineIn fallback)', () {
      final resolved = OrderType.fromString('DELIVERY');
      // On unfixed code there is no DELIVERY value, so fromString falls back
      // to dineIn (value == 'DINE_IN'). Counterexample: 'DINE_IN' != 'DELIVERY'.
      expect(
        resolved.value,
        'DELIVERY',
        reason:
            'OrderType is missing a delivery member; fromString("DELIVERY") '
            'silently falls back to dineIn.',
      );
    });

    test('OrderType supports a parcel value (Req 1.13)', () {
      final hasParcel = OrderType.values.any((e) => e.value == 'PARCEL');
      expect(
        hasParcel,
        isTrue,
        reason: 'OrderType is missing a parcel member.',
      );
    });
  });

  group('Property: RBAC role completeness (Req 1.14)', () {
    test('UserRole parsing for "waiter" resolves to a waiter role '
        '(not an unknown fallback)', () {
      // Mirrors SessionManager role parsing: unknown roles fall back to
      // UserRole.unknown. We avoid referencing UserRole.waiter directly
      // (it does not exist on unfixed code) by matching on the enum name.
      final resolved = UserRole.values.firstWhere(
        (r) => r.name == 'waiter',
        orElse: () => UserRole.unknown,
      );
      expect(
        resolved.name,
        'waiter',
        reason:
            'UserRole is missing the "waiter" role; staff role parsing '
            'falls back to unknown.',
      );
    });

    test('UserRole supports chef and captain roles (Req 1.14)', () {
      final names = UserRole.values.map((r) => r.name).toSet();
      expect(
        names.containsAll(<String>{'chef', 'captain'}),
        isTrue,
        reason: 'UserRole is missing the chef and/or captain roles.',
      );
    });
  });
}
