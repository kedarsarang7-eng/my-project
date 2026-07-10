/// Preservation Property Test — VegetablesBroker's Other Capabilities and
/// Mandi Screens Unaffected
///
/// **Validates: Requirements 3.2, 3.4, 3.5**
///
/// Property 3: Preservation — VegetablesBroker's Other Capabilities,
/// `useDailyRates`, and the Five Mandi Screens Unaffected
///
/// This test observes on UNFIXED code that:
///   - `businessCapabilityRegistry['vegetablesBroker']` contains `useCommission`,
///     `useFarmerLinking`, `useDailyRates`, `useCreditManagement`
///   - The five Mandi sidebar items (`mandi_lot_register`, `mandi_farmer_ledger`,
///     `mandi_commission_report`, `mandi_settlement`, `mandi_rate_board`) all
///     resolve to their respective real screens via `SidebarNavigationHandler`
///
/// The test generates arbitrary lookups of these four capabilities and five
/// sidebar IDs and asserts their presence/resolution is unchanged. Only
/// `useCrateManagement`'s membership may flip — all other capabilities and
/// every Mandi screen/sidebar item must remain stable.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/vegetable_broker_capabilities_mandi_screens_preservation_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:dukanx/features/vegetable_broker/presentation/screens/lot_register_screen.dart';
import 'package:dukanx/features/vegetable_broker/presentation/screens/farmer_ledger_entry_screen.dart';
import 'package:dukanx/features/vegetable_broker/presentation/screens/mandi_commission_report_screen.dart';
import 'package:dukanx/features/vegetable_broker/presentation/screens/settlement_screen.dart';
import 'package:dukanx/features/vegetable_broker/presentation/screens/rate_board_screen.dart';

// ---------------------------------------------------------------------------
// Domain: the four vegetablesBroker capabilities that MUST survive the fix.
// `useCrateManagement` is intentionally excluded — it is the one being removed.
// ---------------------------------------------------------------------------
const List<BusinessCapability> _preservedCapabilities = [
  BusinessCapability.useCommission,
  BusinessCapability.useFarmerLinking,
  BusinessCapability.useDailyRates,
  BusinessCapability.useCreditManagement,
];

// ---------------------------------------------------------------------------
// Domain: the five Mandi sidebar item IDs and their expected screen types.
// ---------------------------------------------------------------------------
const List<String> _mandiSidebarIds = [
  'mandi_lot_register',
  'mandi_farmer_ledger',
  'mandi_commission_report',
  'mandi_settlement',
  'mandi_rate_board',
];

/// Maps each Mandi sidebar ID to its expected runtime Type.
final Map<String, Type> _expectedScreenTypes = {
  'mandi_lot_register': LotRegisterScreen,
  'mandi_farmer_ledger': FarmerLedgerEntryScreen,
  'mandi_commission_report': MandiCommissionReportScreen,
  'mandi_settlement': SettlementScreen,
  'mandi_rate_board': RateBoardScreen,
};

void main() {
  // =========================================================================
  // PRESERVATION 3.2 — VegetablesBroker's other capabilities are retained
  //
  // The vegetablesBroker fix removes ONLY useCrateManagement. The other four
  // specialized capabilities (useCommission, useFarmerLinking, useDailyRates,
  // useCreditManagement) MUST remain granted.
  // =========================================================================
  group('Preservation 3.2 — vegetablesBroker other capabilities retained', () {
    test('all four preserved capabilities are present in the registry', () {
      final caps = FeatureResolver.getCapabilities('vegetablesBroker');
      for (final cap in _preservedCapabilities) {
        expect(
          caps.contains(cap),
          isTrue,
          reason:
              '${cap.name} must remain granted to vegetablesBroker — the fix '
              'only removes useCrateManagement, not any other specialized '
              'capability.',
        );
      }
    });

    test('FeatureResolver.canAccess returns true for each preserved '
        'capability', () {
      for (final cap in _preservedCapabilities) {
        expect(
          FeatureResolver.canAccess('vegetablesBroker', cap),
          isTrue,
          reason:
              'FeatureResolver.canAccess(vegetablesBroker, ${cap.name}) must '
              'return true — the fix must not revoke this capability.',
        );
      }
    });

    test('PBT: for all preserved capabilities, membership is stable', () {
      forAll(
        (int idx) {
          final cap =
              _preservedCapabilities[idx % _preservedCapabilities.length];
          final granted = FeatureResolver.canAccess('vegetablesBroker', cap);
          expect(
            granted,
            isTrue,
            reason:
                'Preservation violated: ${cap.name} no longer granted to '
                'vegetablesBroker after the fix. Only useCrateManagement may '
                'be removed.',
          );
          return true;
        },
        [Gen.interval(0, _preservedCapabilities.length - 1)],
        numRuns: 100,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.4 — Five Mandi sidebar items present in sidebar config
  //
  // The five Mandi sidebar items must remain in the vegetablesBroker sidebar
  // configuration with their correct IDs.
  // =========================================================================
  group('Preservation 3.4 — Mandi sidebar items present', () {
    late List<String> brokerSidebarIds;

    setUpAll(() {
      final sections = getSectionsForBusinessType(
        BusinessType.vegetablesBroker,
      );
      brokerSidebarIds = sections
          .expand((s) => s.items)
          .map((item) => item.id)
          .toList();
    });

    test('all five Mandi sidebar IDs are present in the vegetablesBroker '
        'sidebar', () {
      for (final id in _mandiSidebarIds) {
        expect(
          brokerSidebarIds.contains(id),
          isTrue,
          reason:
              'Sidebar item "$id" must be present in the vegetablesBroker '
              'sidebar — the fix must not remove any Mandi screen navigation.',
        );
      }
    });

    test('PBT: for all five Mandi sidebar IDs, presence is stable', () {
      forAll(
        (int idx) {
          final id = _mandiSidebarIds[idx % _mandiSidebarIds.length];
          expect(
            brokerSidebarIds.contains(id),
            isTrue,
            reason:
                'Preservation violated: sidebar item "$id" missing from '
                'vegetablesBroker sidebar after the fix.',
          );
          return true;
        },
        [Gen.interval(0, _mandiSidebarIds.length - 1)],
        numRuns: 100,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.5 — Mandi sidebar IDs resolve to correct screens
  //
  // Each of the five Mandi sidebar IDs must resolve to its respective screen
  // widget via SidebarNavigationHandler (the same code path used at runtime).
  // =========================================================================
  group('Preservation 3.5 — Mandi sidebar ID → screen resolution', () {
    testWidgets('each Mandi sidebar ID resolves to the correct screen type', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              for (final entry in _expectedScreenTypes.entries) {
                final screen = SidebarNavigationHandler.tryGetScreenForItem(
                  entry.key,
                  context,
                );
                expect(
                  screen,
                  isNotNull,
                  reason:
                      'Sidebar item "${entry.key}" must resolve to a screen, '
                      'not null.',
                );
                expect(
                  screen.runtimeType,
                  entry.value,
                  reason:
                      'Sidebar item "${entry.key}" must resolve to '
                      '${entry.value}, got ${screen.runtimeType}.',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('PBT: for all Mandi sidebar IDs, screen resolution is stable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              forAll(
                (int idx) {
                  final id = _mandiSidebarIds[idx % _mandiSidebarIds.length];
                  final expectedType = _expectedScreenTypes[id]!;
                  final screen = SidebarNavigationHandler.tryGetScreenForItem(
                    id,
                    context,
                  );
                  expect(
                    screen,
                    isNotNull,
                    reason: '"$id" resolution returned null after fix.',
                  );
                  expect(
                    screen.runtimeType,
                    expectedType,
                    reason:
                        '"$id" resolved to ${screen.runtimeType} instead of '
                        '$expectedType — screen resolution must not change.',
                  );
                  return true;
                },
                [Gen.interval(0, _mandiSidebarIds.length - 1)],
                numRuns: 100,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  // =========================================================================
  // COMBINED PBT — arbitrary lookups of capabilities + sidebar IDs
  //
  // Generates arbitrary indices into both the preserved-capabilities list
  // and the mandi-sidebar-IDs list, asserting presence/resolution is stable.
  // This combines Requirements 3.2, 3.4, 3.5 into a single property.
  // =========================================================================
  group('Combined PBT — capabilities + sidebar IDs stable', () {
    test('for all combinations of capability and sidebar ID lookups, '
        'preservation holds', () {
      forAll(
        (int capIdx, int sidebarIdx) {
          // 1. Capability preservation
          final cap =
              _preservedCapabilities[capIdx % _preservedCapabilities.length];
          expect(
            FeatureResolver.canAccess('vegetablesBroker', cap),
            isTrue,
            reason: '${cap.name} must remain granted to vegetablesBroker.',
          );

          // 2. Sidebar presence preservation
          final sections = getSectionsForBusinessType(
            BusinessType.vegetablesBroker,
          );
          final ids = sections.expand((s) => s.items).map((i) => i.id).toSet();
          final sidebarId =
              _mandiSidebarIds[sidebarIdx % _mandiSidebarIds.length];
          expect(
            ids.contains(sidebarId),
            isTrue,
            reason:
                'Sidebar item "$sidebarId" must remain in vegetablesBroker '
                'sidebar.',
          );

          return true;
        },
        [
          Gen.interval(0, _preservedCapabilities.length - 1),
          Gen.interval(0, _mandiSidebarIds.length - 1),
        ],
        numRuns: 100,
      );
    });
  });
}
