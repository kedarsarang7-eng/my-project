/// Bug Condition Exploration Test — Hardware Vertical Remediation
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 1.9, 1.17, 1.18,
/// 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.8, 2.9, 2.17, 2.18**
///
/// Property 1: Bug Condition — Hardware Defect Paths Behave Correctly
///
/// Each test below drives a defective hardware code path with
/// `businessType == BusinessType.hardware` and asserts the intended Section 2
/// (post-fix) behaviour from `bugfix.md`.
///
/// **CRITICAL**: On UNFIXED code these assertions FAIL — failure CONFIRMS the
/// defect exists. DO NOT fix the test or the code when it fails. Failure here is
/// the GOAL of the exploration phase. After the fix (Task 3) these SAME tests
/// re-run (Task 3.8) and are expected to PASS.
///
/// Three kinds of probes are used:
///   • Behavioural — drive the live resolver/provider/widget and assert output
///     (navigation 1.1–1.3/1.9, sidebar 1.4, manifest 1.5/1.6, alerts 1.8).
///   • Real-source probes — read the SHIPPING source (not a mirror) and assert
///     the wiring/fix is present (RBAC 1.9, module/sync wiring 1.17, estimate→
///     invoice field preservation 1.18). These confirm/refute the audit's
///     "unverified" items against the actual code on disk.
///
/// PBT library: dartproptest ^0.2.1 — used where the input domain is naturally
/// broad (the hardware module→capability manifest pairs).
///
/// Run: flutter test test/bug_condition/hardware_vertical_remediation_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/navigation/app_screens.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';
import 'package:dukanx/features/delivery_challan/presentation/screens/delivery_challan_list_screen.dart';
import 'package:dukanx/features/hardware/presentation/screens/hardware_operations_screen.dart';
import 'package:dukanx/models/estimate.dart';
import 'package:dukanx/models/bill.dart';

// ---------------------------------------------------------------------------
// Test doubles for Riverpod overrides.
//
// The real BusinessTypeNotifier.build() listens to the license snapshot and the
// real AuthStateNotifier.build() pulls SessionManager from the service locator.
// Neither is available in a pure widget test, so we override their build() with
// fixed state. This isolates the code under test (sidebar resolution / alert
// rendering) from bootstrap/DI concerns.
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

/// Reads a shipping source file relative to the package root (the cwd when
/// `flutter test` runs). Returns '' if missing so the assertion — not an
/// exception — reports the defect.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// Recursively collects the text of every `.dart` file under [dir].
String _readAllDart(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return '';
  final buf = StringBuffer();
  for (final e in root.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) {
      buf.writeln(e.readAsStringSync());
    }
  }
  return buf.toString();
}

void main() {
  // =========================================================================
  // 1.1 / 2.1 — Delivery Challan dead link
  // Expected (post-fix): AppScreen.deliveryChallans resolves to
  // DeliveryChallanListScreen through the in-shell resolver.
  // Unfixed: 'delivery_challans' has no resolver case → tryGetScreenForItem
  // returns null → the shell shows the "Feature Not Found" placeholder.
  // =========================================================================
  group('Bug Condition 1.1 — Delivery Challan navigation', () {
    testWidgets(
      'AppScreen.deliveryChallans resolves to DeliveryChallanListScreen',
      (tester) async {
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

        final resolved = SidebarNavigationHandler.tryGetScreenForItem(
          AppScreen.deliveryChallans.id, // 'delivery_challans'
          ctx,
        );

        expect(
          resolved,
          isA<DeliveryChallanListScreen>(),
          reason:
              'COUNTEREXAMPLE (1.1): AppScreen.deliveryChallans (id '
              '"${AppScreen.deliveryChallans.id}") does not resolve through the '
              'in-shell resolver — it returns null and the shell renders the '
              '"Feature Not Found" placeholder instead of DeliveryChallanListScreen.',
        );
      },
    );
  });

  // =========================================================================
  // 1.2 / 2.2 — Projects (HardwareOperations) dead link
  // =========================================================================
  group('Bug Condition 1.2 — Projects / Hardware Operations navigation', () {
    testWidgets(
      'AppScreen.hardwareOperations resolves to HardwareOperationsScreen',
      (tester) async {
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

        final resolved = SidebarNavigationHandler.tryGetScreenForItem(
          AppScreen.hardwareOperations.id, // 'hardware_operations'
          ctx,
        );

        expect(
          resolved,
          isA<HardwareOperationsScreen>(),
          reason:
              'COUNTEREXAMPLE (1.2): AppScreen.hardwareOperations (id '
              '"${AppScreen.hardwareOperations.id}") does not resolve — returns '
              'null → "Feature Not Found" placeholder instead of '
              'HardwareOperationsScreen.',
        );
      },
    );
  });

  // =========================================================================
  // 1.3 / 2.3 — Orphaned hardware screens are unreachable from the shell
  // Expected (post-fix): each orphaned screen id resolves to a reachable
  // (non-null, non-placeholder) screen.
  // Unfixed: none of these ids has a resolver case → all return null.
  //
  // NOTE: the exact ids are the snake_case forms the fix (Task 3.1) is expected
  // to register. If 3.1 chooses different ids it MUST update them here so 3.8
  // re-runs green.
  // =========================================================================
  group('Bug Condition 1.3 — orphaned hardware screens are unreachable', () {
    const orphanIds = <String>[
      'hardware_command_center',
      'hardware_supplier_management',
      'hardware_phase12_workspace',
      'hardware_credit_control',
      'hardware_invoice_profile',
    ];

    for (final id in orphanIds) {
      testWidgets('orphaned screen id "$id" resolves to a reachable screen', (
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

        final resolved = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);

        expect(
          resolved,
          isNotNull,
          reason:
              'COUNTEREXAMPLE (1.3): orphaned hardware screen id "$id" has no '
              'in-shell resolver case — it returns null, so the built screen and '
              'its backing HardwareOpsRepository endpoints are unreachable from '
              'the live UI.',
        );
      });
    }
  });

  // =========================================================================
  // 1.4 / 2.4 — Hardware sidebar falls through to the retail sidebar
  // Expected (post-fix): the hardware sidebar exposes dedicated hardware
  // sections (Projects/Indents/Deposits, Estimates, Delivery Challans,
  // Contractor Credit, Supplier Rate Compare).
  // Unfixed: _getSectionsForBusiness has no `case BusinessType.hardware` so it
  // returns the generic retail sections.
  // =========================================================================
  group('Bug Condition 1.4 — hardware sidebar', () {
    test('sidebar for BusinessType.hardware returns hardware sections', () {
      final container = ProviderContainer(
        overrides: [
          businessTypeProvider.overrideWith(
            () => _FixedBusinessTypeNotifier(BusinessType.hardware),
          ),
          authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final sections = container.read(sidebarSectionsProvider);
      final titles = sections.map((s) => s.title.toLowerCase()).toList();

      bool mentions(String needle) => titles.any((t) => t.contains(needle));

      final hasHardwareSection =
          mentions('project') ||
          mentions('indent') ||
          mentions('estimate') ||
          mentions('delivery challan') ||
          mentions('contractor') ||
          mentions('supplier rate') ||
          mentions('deposit');

      expect(
        hasHardwareSection,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.4): the hardware sidebar equals the generic '
            'retail sidebar. Resolved section titles were $titles — none are '
            'hardware-specific (no Projects/Indents/Deposits, Estimates, '
            'Delivery Challans, Contractor Credit, or Supplier Rate Compare).',
      );
    });
  });

  // =========================================================================
  // 1.5 / 1.6 / 2.5 / 2.6 — Capability/module manifest contradiction
  // Expected (post-fix): every advertised hardware module has a matching
  // granted capability (or the conflicting module is removed).
  // Unfixed: modules list contains 'returns' & 'quotations' but the hardware
  // capability set grants neither useSalesReturn nor useProformaInvoice.
  // =========================================================================
  group('Bug Condition 1.5/1.6 — manifest ↔ capability consistency', () {
    // The module identifiers that map 1:1 to a required capability.
    const moduleToCapability = <String, BusinessCapability>{
      'returns': BusinessCapability.useSalesReturn,
      'quotations': BusinessCapability.useProformaInvoice,
    };

    final hardwareModules = BusinessTypeRegistry.getConfig(
      BusinessType.hardware,
    ).modules;
    final hardwareCaps = FeatureResolver.getCapabilities(
      BusinessType.hardware.name,
    );

    moduleToCapability.forEach((module, capability) {
      test('module "$module" implies capability $capability is granted', () {
        if (!hardwareModules.contains(module)) {
          // If the fix removed the module, the contradiction is resolved.
          return;
        }
        expect(
          hardwareCaps.contains(capability),
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.5/1.6): hardware advertises the "$module" '
              'module but its capability set does NOT grant $capability. The '
              'module manifest and the isolation registry contradict each other.',
        );
      });
    });

    test('PBT: every module→capability pair is internally consistent', () {
      final pairs = moduleToCapability.entries.toList();
      final held = forAll(
        (int i) {
          final entry = pairs[i];
          if (!hardwareModules.contains(entry.key)) return true;
          return hardwareCaps.contains(entry.value);
        },
        [Gen.interval(0, pairs.length - 1)],
        numRuns: 15,
      );
      expect(
        held,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.5/1.6): at least one advertised hardware module '
            'has no matching granted capability (returns/useSalesReturn and/or '
            'quotations/useProformaInvoice drift).',
      );
    });
  });

  // =========================================================================
  // 1.8 / 2.8 — Hardware dashboard alert counts are hardcoded literals
  // Expected (post-fix): the hardware alert counts track the seeded
  // alertCountsProvider data.
  // Unfixed: the hardware branch ignores `counts` and renders '7'/'4'/'3'.
  // Probe: seed alertCountsProvider with a distinctive sentinel (42) under many
  // plausible keys; the rendered hardware alerts must surface that sentinel.
  // =========================================================================
  group('Bug Condition 1.8 — hardware alert counts track real data', () {
    testWidgets('seeded alert counts appear in the hardware alert widget', (
      tester,
    ) async {
      const sentinel = 42;
      final seed = <String, int>{
        'lowStock': sentinel,
        'expiringSoon': sentinel,
        'pendingQuotes': sentinel,
        'pending_quotes': sentinel,
        'activeProjects': sentinel,
        'active_projects': sentinel,
        'openIndents': sentinel,
        'open_indents': sentinel,
        'depositLiability': sentinel,
        'overdueContractorBills': sentinel,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessTypeProvider.overrideWith(
              () => _FixedBusinessTypeNotifier(BusinessType.hardware),
            ),
            alertCountsProvider.overrideWith((ref) => Stream.value(seed)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BusinessAlertsWidget()),
          ),
        ),
      );

      // Let the StreamProvider emit and the data branch build (avoid
      // pumpAndSettle: the loading state shows an indeterminate spinner).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('$sentinel'),
        findsWidgets,
        reason:
            'COUNTEREXAMPLE (1.8): the hardware dashboard alert counts do not '
            'reflect the seeded alertCountsProvider value ($sentinel). The '
            'hardware branch renders the hardcoded literals "7"/"4"/"3" '
            'regardless of the real data.',
      );
    });
  });

  // =========================================================================
  // 1.9 / 2.9 — In-shell navigation bypasses the VendorRoleGuard that the
  // named-route layer applies.
  // Expected (post-fix): the in-shell resolver wraps hardware screens in the
  // same VendorRoleGuard used by the GoRouter route table.
  // Unfixed: sidebar_navigation_handler.dart has no VendorRoleGuard reference,
  // while the route table wraps /delivery_challans and /hardware/operations in
  // VendorRoleGuard.
  // =========================================================================
  group('Bug Condition 1.9 — RBAC parity on the in-shell path', () {
    test('in-shell resolver applies VendorRoleGuard like the route table', () {
      final resolverSrc = _readSource(
        'lib/widgets/desktop/sidebar_navigation_handler.dart',
      );
      final routesSrc = _readSource('lib/core/routing/legacy_routes.dart');

      // Sanity: the route layer DOES guard these hardware routes today.
      expect(
        routesSrc.contains('VendorRoleGuard'),
        isTrue,
        reason:
            'Precondition: the GoRouter route table is expected to wrap routes '
            'in VendorRoleGuard.',
      );

      expect(
        resolverSrc.contains('VendorRoleGuard'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.9): sidebar_navigation_handler.dart (the in-shell '
            'resolver) never references VendorRoleGuard, so hardware screens '
            'opened through the shell bypass the staff-role permission checks '
            'that app/routes apply to the same screens.',
      );
    });
  });

  // =========================================================================
  // 1.17 / 2.17 — Hardware module/sync/ws handlers are not wired into the live
  // app (audit marked this "unverified").
  // Expected (post-fix): HardwareModule routes + HardwareSyncHandler +
  // HardwareWsHandler are attached to the live app.
  // Finding: the `modules/` tree does not exist; these identifiers are absent
  // from the entire `lib/` source — so the wiring is not live. CONFIRMED.
  // =========================================================================
  group('Bug Condition 1.17 — hardware module/sync/ws wiring is live', () {
    final libSrc = _readAllDart('lib');

    test('HardwareSyncHandler is wired into the live app', () {
      expect(
        libSrc.contains('HardwareSyncHandler'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.17): no reference to HardwareSyncHandler exists '
            'anywhere under lib/ — hardware offline sync is not wired into the '
            'live app. (The modules/ tree referenced by the audit is absent.)',
      );
    });

    test('HardwareWsHandler is wired into the live app', () {
      expect(
        libSrc.contains('HardwareWsHandler'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.17): no reference to HardwareWsHandler exists '
            'anywhere under lib/ — hardware realtime events are not wired into '
            'the live app.',
      );
    });

    test('HardwareModule routes are attached to the live app', () {
      expect(
        libSrc.contains('HardwareModule'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.17): no reference to HardwareModule exists '
            'anywhere under lib/ — hardware module routes are not attached to '
            'the live router.',
      );
    });
  });

  // =========================================================================
  // 1.18 / 2.18 — Estimate→Invoice conversion drops hardware fields (audit
  // marked this "unverified").
  // Expected (post-fix): the conversion preserves brand/grade/HSN/dimensions.
  // Findings against the SHIPPING source/model:
  //   • BillItem CAN hold brand/dimensions/hsn (target supports them).
  //   • EstimateService.convertToInvoice maps EstimateItem→BillItem WITHOUT
  //     passing `brand` (and the EstimateItem model has no grade/dimensions
  //     fields at all) → brand/grade/dimensions are LOST on conversion.
  //     CONFIRMED (HSN is preserved; brand/grade/dimensions are not).
  // =========================================================================
  group('Bug Condition 1.18 — estimate→invoice field preservation', () {
    test('BillItem (the conversion target) can carry brand & dimensions', () {
      // Sanity precondition — confirms the loss is in the mapping, not the model.
      final bi = BillItem(
        productId: 'p1',
        productName: 'TMT Bar',
        qty: 10,
        price: 550,
        brand: 'Tata Tiscon',
        dimensions: '12mm x 12m',
        hsn: '7214',
      );
      expect(bi.brand, 'Tata Tiscon');
      expect(bi.dimensions, '12mm x 12m');
      expect(bi.hsn, '7214');
    });

    test('EstimateService.convertToInvoice maps brand onto the Bill item', () {
      final src = _readSource('lib/core/services/estimate_service.dart');
      expect(
        src.isNotEmpty,
        isTrue,
        reason: 'estimate_service.dart must exist to verify the conversion.',
      );

      // Isolate the BillItem(...) construction inside convertToInvoice.
      final mapStart = src.indexOf('estimate.items.map');
      expect(
        mapStart,
        greaterThanOrEqualTo(0),
        reason: 'Could not locate the EstimateItem→BillItem mapping.',
      );
      final billItemStart = src.indexOf('BillItem(', mapStart);
      final billItemEnd = src.indexOf('.toList()', mapStart);
      final mappingBlock = (billItemStart >= 0 && billItemEnd > billItemStart)
          ? src.substring(billItemStart, billItemEnd)
          : '';

      expect(
        mappingBlock.contains('brand'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.18): convertToInvoice maps EstimateItem→BillItem '
            'without carrying `brand` (mapping block: <<<$mappingBlock>>>). An '
            'estimate carrying a brand converts to an invoice that loses it. '
            '(grade/dimensions are not even present on the EstimateItem model.)',
      );
    });

    test('EstimateItem exposes the hardware fields needed for preservation', () {
      // The estimate builder must carry brand/grade/HSN/dimensions (2.18).
      // Today EstimateItem has brand, specifications and hsn — but NO grade and
      // NO dimensions field. toMap() therefore cannot round-trip them.
      final ei = EstimateItem(
        productId: 'p1',
        productName: 'TMT Bar',
        qty: 10,
        unitPrice: 550,
        hsn: '7214',
        brand: 'Tata Tiscon',
      );
      final map = ei.toMap();

      expect(
        map.containsKey('dimensions'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.18): EstimateItem has no `dimensions` field, so a '
            'hardware estimate cannot carry dimensions through to the invoice.',
      );
    });
  });
}
