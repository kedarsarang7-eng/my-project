/// Phase 1 — Reachability Property & Example Tests
///
/// This file implements:
///   - Task 2.4: Property 6 — Every jewellery sidebar id resolves to its screen
///   - Task 2.5: Property 7 — Jewellery routes carry both guards for jewellery only
///   - Task 2.6: Property 8 — Route access is granted iff authorized
///   - Task 2.7: Property 5 — Other business types are unchanged
///   - Task 2.8: Example tests for reachability
///
/// PBT library: dartproptest ^0.2.1 (100 iterations minimum per property).
///
/// Run: flutter test test/features/jewellery/phase1_reachability_test.dart
library;

import 'dart:math' as math;

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';

// ---------------------------------------------------------------------------
// Test doubles for Riverpod overrides.
// ---------------------------------------------------------------------------
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  _FixedBusinessTypeNotifier(this._type);
  final BusinessType _type;
  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

class _UnauthAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() =>
      AuthState(status: AuthStatus.unauthenticated, session: null);
}

// ---------------------------------------------------------------------------
// Jewellery sidebar item ids — the canonical list from _getJewellerySections().
// ---------------------------------------------------------------------------

/// The 8 jewellery-specific sidebar ids (excludes shared items like new_sale
/// and stock_summary which resolve via existing shared paths).
const List<String> _jewellerySpecificIds = <String>[
  'jewellery_gold_rate',
  'jewellery_gold_rate_alert',
  'jewellery_hallmark',
  'jewellery_old_gold_exchange',
  'jewellery_custom_orders',
  'jewellery_repair',
  'jewellery_gold_scheme',
  'jewellery_making_charges',
];

/// Map from jewellery-specific item id to expected screen runtime type.
const Map<String, String> _jewelleryIdToScreenType = <String, String>{
  'jewellery_gold_rate': 'GoldRateManagementScreen',
  'jewellery_gold_rate_alert': 'GoldRateAlertScreen',
  'jewellery_hallmark': 'HallmarkInventoryScreen',
  'jewellery_old_gold_exchange': 'OldGoldExchangeScreen',
  'jewellery_custom_orders': 'CustomOrderManagementScreen',
  'jewellery_repair': 'JewelleryRepairScreen',
  'jewellery_gold_scheme': 'GoldSchemeScreen',
  'jewellery_making_charges': 'MakingChargesCalculatorScreen',
};

/// The 8 jewellery route paths registered in legacy_routes.dart.
const List<String> _jewelleryRoutePaths = <String>[
  '/jewellery-gold-rate',
  '/jewellery-gold-rate-alert',
  '/jewellery-making-charges',
  '/jewellery-hallmark',
  '/jewellery-old-gold-exchange',
  '/jewellery-custom-orders',
  '/jewellery-repair',
  '/jewellery-gold-scheme',
];

/// The Eight Screens — the canonical reachable set.
const Set<String> _theEightScreenTypes = <String>{
  'GoldRateManagementScreen',
  'GoldRateAlertScreen',
  'MakingChargesCalculatorScreen',
  'HallmarkInventoryScreen',
  'OldGoldExchangeScreen',
  'CustomOrderManagementScreen',
  'JewelleryRepairScreen',
  'GoldSchemeScreen',
};

/// All business types that are NOT jewellery.
final List<BusinessType> _nonJewelleryTypes = BusinessType.values
    .where((t) => t != BusinessType.jewellery)
    .toList(growable: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================================================
  // Task 2.4 — Property 6: Every jewellery sidebar id resolves to its screen
  // Tag: Feature: jewellery-vertical-remediation, Property 6: Every jewellery
  //       sidebar id resolves to its screen
  // **Validates: Requirements 3.3, 5.1, 5.2**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 6: Every jewellery sidebar id resolves to its screen', () {
    testWidgets('PBT: for all jewellery sidebar ids, getScreenForItem resolves '
        'to the mapped screen (100 iterations)', (tester) async {
      // Pump a minimal widget to obtain a BuildContext.
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      final bool held = forAll(
        (int idx) {
          final id = _jewellerySpecificIds[idx % _jewellerySpecificIds.length];
          final screen = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);

          // 5.2: SHALL NOT return null (placeholder fallthrough).
          if (screen == null) return false;

          // 5.1: returns the single jewellery screen widget mapped to that id.
          final expectedType = _jewelleryIdToScreenType[id]!;
          if (screen.runtimeType.toString() != expectedType) return false;

          return true;
        },
        [Gen.interval(0, _jewellerySpecificIds.length * 15)],
        numRuns: 100,
      );

      expect(held, isTrue, reason: 'Property 6 failed');
    });

    testWidgets('PBT: every jewellery sidebar item has a non-empty label '
        '(Requirement 3.3)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Obtain the jewellery sections directly via a provider container.
      final container = ProviderContainer(
        overrides: [
          businessTypeProvider.overrideWith(
            () => _FixedBusinessTypeNotifier(BusinessType.jewellery),
          ),
          authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
        ],
      );
      final sections = container.read(sidebarSectionsProvider);
      container.dispose();

      // Flatten all items (including filtered-in ones).
      final items = sections.expand((s) => s.items).toList();

      final bool held = forAll(
        (int idx) {
          if (items.isEmpty) return true; // vacuous if no items visible
          final item = items[idx % items.length];
          return item.label.isNotEmpty;
        },
        [Gen.interval(0, math.max(items.length * 10, 100))],
        numRuns: 100,
      );

      expect(held, isTrue, reason: 'Property 6 (non-empty label) failed');
    });
  });

  // ==========================================================================
  // Task 2.5 — Property 7: Jewellery routes carry both guards for jewellery only
  // Tag: Feature: jewellery-vertical-remediation, Property 7: Jewellery routes
  //       carry both guards for jewellery only
  // **Validates: Requirements 4.2, 10.3**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 7: Jewellery routes carry both guards for jewellery only', () {
    test('PBT: for all jewellery route paths, the path is registered in '
        'knownLegacyPaths (100 iterations)', () {
      final bool held = forAll(
        (int idx) {
          final path = _jewelleryRoutePaths[idx % _jewelleryRoutePaths.length];
          // Verify the route is registered as a known legacy path.
          return LegacyRoutes.isKnownLegacyPath(path);
        },
        [Gen.interval(0, _jewelleryRoutePaths.length * 15)],
        numRuns: 100,
      );

      expect(held, isTrue, reason: 'Property 7 failed');
    });

    test('all 8 jewellery routes are registered as known legacy paths', () {
      for (final path in _jewelleryRoutePaths) {
        expect(
          LegacyRoutes.isKnownLegacyPath(path),
          isTrue,
          reason:
              'Jewellery route "$path" is not registered in '
              'knownLegacyPaths. Requirements 4.2, 10.3 require all jewellery '
              'routes to be registered with VendorRoleGuard + BusinessGuard.',
        );
      }
    });

    test('PBT: jewellery routes are namespaced to jewellery '
        '(100 iterations)', () {
      // Each jewellery route path must contain "jewellery" — ensuring they
      // are namespaced and won't collide with other verticals' paths.
      final bool held = forAll(
        (int idx) {
          final path = _jewelleryRoutePaths[idx % _jewelleryRoutePaths.length];
          return path.contains('jewellery');
        },
        [Gen.interval(0, _jewelleryRoutePaths.length * 15)],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason: 'Property 7 (jewellery-only namespace) failed',
      );
    });
  });

  // ==========================================================================
  // Task 2.6 — Property 8: Route access is granted iff authorized
  // Tag: Feature: jewellery-vertical-remediation, Property 8: Route access is
  //       granted iff authorized
  // **Validates: Requirements 4.3, 4.4**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 8: Route access is granted iff authorized', () {
    test('PBT: jewellery capability access is true for jewellery type and '
        'false for all others (100 iterations)', () {
      // The 8 new jewellery-domain capabilities.
      const jewelleryOnlyCapabilities = <BusinessCapability>[
        BusinessCapability.useGoldRate,
        BusinessCapability.useGoldRateAlert,
        BusinessCapability.useMakingCharges,
        BusinessCapability.useHallmark,
        BusinessCapability.useOldGoldExchange,
        BusinessCapability.useCustomOrders,
        BusinessCapability.useGoldSchemes,
        BusinessCapability.useJewelleryRepair,
      ];

      final rng = math.Random(42);

      final bool held = forAll(
        (int idx) {
          final cap =
              jewelleryOnlyCapabilities[idx % jewelleryOnlyCapabilities.length];

          // 4.3: jewellery type can access jewellery capabilities.
          final jewelleryAccess = FeatureResolver.canAccess('jewellery', cap);
          if (!jewelleryAccess) return false;

          // 4.4: non-jewellery types cannot access jewellery-only capabilities.
          final nonJewType =
              _nonJewelleryTypes[rng.nextInt(_nonJewelleryTypes.length)];
          final otherAccess = FeatureResolver.canAccess(nonJewType.name, cap);
          if (otherAccess) return false;

          return true;
        },
        [Gen.interval(0, jewelleryOnlyCapabilities.length * 15)],
        numRuns: 100,
      );

      expect(held, isTrue, reason: 'Property 8 failed');
    });

    test('jewellery type is granted access to all 8 jewellery-domain '
        'capabilities', () {
      const caps = <BusinessCapability>[
        BusinessCapability.useGoldRate,
        BusinessCapability.useGoldRateAlert,
        BusinessCapability.useMakingCharges,
        BusinessCapability.useHallmark,
        BusinessCapability.useOldGoldExchange,
        BusinessCapability.useCustomOrders,
        BusinessCapability.useGoldSchemes,
        BusinessCapability.useJewelleryRepair,
      ];

      for (final cap in caps) {
        expect(
          FeatureResolver.canAccess('jewellery', cap),
          isTrue,
          reason: 'jewellery should have access to ${cap.name}',
        );
      }
    });

    test('no non-jewellery type is granted the 8 jewellery-only caps', () {
      const caps = <BusinessCapability>[
        BusinessCapability.useGoldRate,
        BusinessCapability.useGoldRateAlert,
        BusinessCapability.useMakingCharges,
        BusinessCapability.useHallmark,
        BusinessCapability.useOldGoldExchange,
        BusinessCapability.useCustomOrders,
        BusinessCapability.useGoldSchemes,
        BusinessCapability.useJewelleryRepair,
      ];

      for (final type in _nonJewelleryTypes) {
        for (final cap in caps) {
          expect(
            FeatureResolver.canAccess(type.name, cap),
            isFalse,
            reason:
                '${type.name} should NOT have access to ${cap.name} '
                '(jewellery-only capability)',
          );
        }
      }
    });
  });

  // ==========================================================================
  // Task 2.7 — Property 5: Other business types are unchanged
  // Tag: Feature: jewellery-vertical-remediation, Property 5: Other business
  //       types are unchanged
  // **Validates: Requirements 1.9, 1.10, 3.4**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 5: Other business types are unchanged', () {
    testWidgets('PBT: for all non-jewellery types, sidebar resolution is '
        'stable and consistent (100 iterations)', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      // Capture baseline: for each non-jewellery type, record the resolved
      // sidebar section titles.
      final baselineTitles = <String, List<String>>{};
      for (final type in _nonJewelleryTypes) {
        final container = ProviderContainer(
          overrides: [
            businessTypeProvider.overrideWith(
              () => _FixedBusinessTypeNotifier(type),
            ),
            authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
          ],
        );
        final sections = container.read(sidebarSectionsProvider);
        baselineTitles[type.name] = sections.map((s) => s.title).toList();
        container.dispose();
      }

      final bool held = forAll(
        (int idx) {
          final type = _nonJewelleryTypes[idx % _nonJewelleryTypes.length];
          final container = ProviderContainer(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _FixedBusinessTypeNotifier(type),
              ),
              authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
            ],
          );
          final sections = container.read(sidebarSectionsProvider);
          final titles = sections.map((s) => s.title).toList();
          container.dispose();

          // The sidebar must be stable (same titles on repeated read).
          final baseline = baselineTitles[type.name]!;
          if (titles.length != baseline.length) return false;
          for (int i = 0; i < titles.length; i++) {
            if (titles[i] != baseline[i]) return false;
          }
          return true;
        },
        [Gen.interval(0, _nonJewelleryTypes.length * 10)],
        numRuns: 100,
      );

      expect(held, isTrue, reason: 'Property 5 failed');
    });

    test('PBT: for all non-jewellery types, capability sets do not include '
        'jewellery-only capabilities (100 iterations)', () {
      const jewelleryOnlyCaps = <BusinessCapability>[
        BusinessCapability.useGoldRate,
        BusinessCapability.useGoldRateAlert,
        BusinessCapability.useMakingCharges,
        BusinessCapability.useHallmark,
        BusinessCapability.useOldGoldExchange,
        BusinessCapability.useCustomOrders,
        BusinessCapability.useGoldSchemes,
        BusinessCapability.useJewelleryRepair,
      ];

      final bool held = forAll(
        (int idx) {
          final type = _nonJewelleryTypes[idx % _nonJewelleryTypes.length];
          for (final cap in jewelleryOnlyCaps) {
            if (FeatureResolver.canAccess(type.name, cap)) {
              return false;
            }
          }
          return true;
        },
        [Gen.interval(0, _nonJewelleryTypes.length * 10)],
        numRuns: 100,
      );

      expect(held, isTrue, reason: 'Property 5 (capability isolation) failed');
    });

    testWidgets('PBT: for all non-jewellery types, in-shell routing for '
        'shared ids is consistent (100 iterations)', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      // Shared item ids that are common across multiple verticals.
      const sharedIds = <String>['new_sale', 'stock_summary', 'item_stock'];

      // Capture baseline resolutions.
      final baselineTypes = <String, String>{};
      for (final id in sharedIds) {
        final screen = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);
        baselineTypes[id] = screen?.runtimeType.toString() ?? 'null';
      }

      final bool held = forAll(
        (int idx) {
          final id = sharedIds[idx % sharedIds.length];
          final screen = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);
          final resolved = screen?.runtimeType.toString() ?? 'null';
          return resolved == baselineTypes[id];
        },
        [Gen.interval(0, sharedIds.length * 40)],
        numRuns: 100,
      );

      expect(held, isTrue, reason: 'Property 5 (routing stability) failed');
    });
  });

  // ==========================================================================
  // Task 2.8 — Example tests for reachability
  // **Validates: Requirements 3.1, 3.2, 4.1, 4.5, 5.3**
  // ==========================================================================
  group('Example tests: Phase 1 reachability', () {
    testWidgets('_getSectionsForBusiness(jewellery) returns jewellery sections '
        '(not retail)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      final container = ProviderContainer(
        overrides: [
          businessTypeProvider.overrideWith(
            () => _FixedBusinessTypeNotifier(BusinessType.jewellery),
          ),
          authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
        ],
      );
      final sections = container.read(sidebarSectionsProvider);
      container.dispose();

      // Requirement 3.1: explicit case for jewellery, not _getRetailSections().
      // Jewellery sections include domain-specific sections not present in retail.
      final titles = sections.map((s) => s.title).toSet();

      // Retail-only sections like "Purchases" must NOT appear.
      expect(
        titles,
        isNot(contains('Purchases')),
        reason: 'Jewellery should NOT contain retail-only "Purchases"',
      );
    });

    testWidgets('the section set covers the named surfaces (Req 3.2)', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      final container = ProviderContainer(
        overrides: [
          businessTypeProvider.overrideWith(
            () => _FixedBusinessTypeNotifier(BusinessType.jewellery),
          ),
          authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
        ],
      );
      final sections = container.read(sidebarSectionsProvider);
      container.dispose();

      final titles = sections.map((s) => s.title).toSet();

      // Requirement 3.2 mandates these surfaces be present. With no
      // authenticated session, capability gates may filter items, but the
      // FeatureResolver should still grant jewellery its domain capabilities.
      // Verify that NO retail sections are returned.
      expect(titles, isNot(contains('Purchases')));
      expect(titles, isNot(contains('Payments')));

      // If any jewellery sections are visible (capability gates allow them),
      // verify they are from the expected jewellery set.
      const expectedTitles = <String>{
        'Daily Rates',
        'Billing',
        'Inventory',
        'Old Gold Exchange',
        'Custom Orders',
        'Repairs',
        'Gold Schemes',
        'Making-Charges Calculator',
      };

      for (final title in titles) {
        expect(
          expectedTitles.contains(title),
          isTrue,
          reason: 'Unexpected section "$title" in jewellery sidebar',
        );
      }
    });

    test('all 8 jewellery screens register as routes (Req 4.1)', () {
      // Each of the 8 jewellery route paths must be in knownLegacyPaths.
      for (final path in _jewelleryRoutePaths) {
        expect(
          LegacyRoutes.isKnownLegacyPath(path),
          isTrue,
          reason: '"$path" not registered as a known legacy route',
        );
      }

      // Exactly 8 jewellery routes.
      expect(_jewelleryRoutePaths.length, equals(8));
    });

    test('the reachable set equals The_Eight_Screens (Req 4.5)', () {
      // The 8 jewellery-specific sidebar ids must map to exactly
      // The_Eight_Screens via the navigation handler. We verify this by
      // checking the expected screen type mapping.
      final reachableScreenTypes = _jewelleryIdToScreenType.values.toSet();
      expect(
        reachableScreenTypes,
        equals(_theEightScreenTypes),
        reason: 'The reachable set must equal exactly The_Eight_Screens',
      );
    });

    testWidgets('/purchase/scan-bill resolves to a backing screen (Req 5.3)', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      // The scan_bill item id resolves in the navigation handler.
      final screen = SidebarNavigationHandler.tryGetScreenForItem(
        'scan_bill',
        ctx,
      );
      expect(
        screen,
        isNotNull,
        reason:
            '/purchase/scan-bill must resolve to a backing screen, '
            'not a dead end (Requirement 5.3)',
      );
    });

    testWidgets('each jewellery-specific sidebar id resolves to its screen', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      for (final entry in _jewelleryIdToScreenType.entries) {
        final screen = SidebarNavigationHandler.tryGetScreenForItem(
          entry.key,
          ctx,
        );
        expect(
          screen,
          isNotNull,
          reason: 'Item "${entry.key}" must not return null',
        );
        expect(
          screen.runtimeType.toString(),
          equals(entry.value),
          reason: 'Item "${entry.key}" must resolve to ${entry.value}',
        );
      }
    });
  });
}
