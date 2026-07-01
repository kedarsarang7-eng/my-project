/// Preservation Property Tests — Hardware Vertical Remediation
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.8, 3.9**
///
/// Property 2: Preservation — Non-Hardware and Already-Correct Paths Unchanged
///
/// These tests follow the OBSERVATION-FIRST methodology used across the repo's
/// preservation suites (`preservation_property_test.dart`,
/// `fuel_gst_compliance_preservation_test.dart`,
/// `device_settings_gst_reports_mobile_ui_preservation_test.dart`):
///
///   FOR ALL X WHERE NOT isBugCondition(X) DO  ASSERT F(X) == F'(X)  END FOR
///
/// On UNFIXED code (F) every observation is recorded as a golden under
/// `test/preservation/__goldens__/hardware_vertical_remediation/` and the test
/// PASSES — that recording IS the EXPECTED OUTCOME for Task 2 (it captures the
/// baseline to preserve). When the SAME tests re-run after the fix (Task 3.9),
/// the live observation is compared to the recorded baseline, realising
/// `F'(X) == F(X)` for every non-hardware vertical and every already-correct
/// hardware path.
///
/// Why property-based: preservation is a UNIVERSAL property ("for all
/// non-hardware inputs"). The fix adds a `case BusinessType.hardware` to
/// `_getSectionsForBusiness`, edits the hardware capability set, rebinds the
/// hardware dashboard-alert branch, and adds new in-shell resolver entries.
/// Every one of those edits must be additive and hardware-guarded; the only
/// way to prove no leak into the other 18 verticals is to enumerate them all.
/// `dartproptest` generates indices across the full non-hardware domain so a
/// capability silently leaking into another vertical's set is caught.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/hardware_vertical_remediation_preservation_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:get_it/get_it.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';

// Shared screens (Preservation 3.5) + already-correct hardware paths (3.8).
import 'package:dukanx/features/revenue/screens/proforma_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/print_menu_screen.dart';
import 'package:dukanx/features/backup/screens/backup_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/all_transactions_screen.dart';
import 'package:dukanx/features/buy_flow/screens/buy_flow_dashboard.dart';
import 'package:dukanx/features/buy_flow/screens/procurement_log_screen.dart';
import 'package:dukanx/features/buy_flow/screens/buy_orders_screen.dart';
import 'package:dukanx/features/inventory/presentation/screens/damage_logs_screen.dart';

// ---------------------------------------------------------------------------
// Test doubles for Riverpod overrides (mirrors the exploration test).
//
// The real BusinessTypeNotifier.build() listens to the license snapshot and
// AuthStateNotifier.build() pulls SessionManager from the service locator —
// neither is available in a pure widget test. Overriding build() with fixed
// state isolates the code under test (sidebar resolution / alert rendering).
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
// The input domain for Property 2: every business type EXCEPT hardware. The
// bug condition holds only for `BusinessType.hardware`, so these are exactly
// the inputs where `NOT isBugCondition(X)`.
// ---------------------------------------------------------------------------
final List<BusinessType> _nonHardwareTypes = BusinessType.values
    .where((t) => t != BusinessType.hardware)
    .toList(growable: false);

/// Deterministic alert-count seed used for the dashboard-alert snapshot. The
/// non-hardware alert branches read these keys (or ignore them and render
/// literals); either way the rendered text is a pure function of (type, seed),
/// so it is identical before and after a hardware-only fix.
const Map<String, int> _alertSeed = <String, int>{
  'lowStock': 2,
  'expiringSoon': 3,
  'criticalStock': 1,
  'expired': 4,
};

// ---------------------------------------------------------------------------
// Golden helpers — record-on-first-run, compare-on-subsequent-runs. Identical
// semantics to `preservation_walker.dart`'s `expectMatchesGolden`, kept local
// so this suite carries no extra dependencies. `flutter test` runs with the
// package root (Dukan_x) as the cwd, so the relative path resolves correctly.
// ---------------------------------------------------------------------------
const JsonEncoder _enc = JsonEncoder.withIndent('  ');

File _goldenFile(String name) => File(
  'test/preservation/__goldens__/hardware_vertical_remediation/$name.json',
);

/// Asserts [observation] matches the recorded golden [name]. On the first run
/// (UNFIXED code) the golden is written and the assertion is a no-op PASS —
/// this is the baseline capture. On later runs the recorded baseline is read
/// and compared, realising `F'(X) == F(X)`.
void _expectGolden(String name, Object observation) {
  final f = _goldenFile(name);
  final live = _enc.convert(observation);
  if (!f.existsSync()) {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(live);
    return; // baseline recorded — EXPECTED OUTCOME on unfixed code
  }
  final golden = _enc.convert(jsonDecode(f.readAsStringSync()));
  expect(
    live,
    golden,
    reason:
        'Preservation regression: "$name" changed between F and F\'. A '
        'hardware-only fix must not alter any non-hardware vertical or any '
        'already-correct hardware path. Restore the original behaviour, or '
        'update the golden only if this change is an intended, documented part '
        'of the fix.',
  );
}

/// Reads the recorded golden map, or records [live] as the baseline and returns
/// it. Used so the PBT can compare against the SAME baseline the snapshot test
/// records, independent of test ordering.
Map<String, dynamic> _readOrWriteGoldenMap(
  String name,
  Map<String, dynamic> live,
) {
  final f = _goldenFile(name);
  if (!f.existsSync()) {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(_enc.convert(live));
    return live;
  }
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
}

/// The sorted capability-name set a business type is granted today.
List<String> _capabilityNames(BusinessType type) {
  final names = FeatureResolver.getCapabilities(
    type.name,
  ).map((c) => c.name).toList()..sort();
  return names;
}

// ---------------------------------------------------------------------------
// Minimal SessionManager fake for sidebar resolution tests. Several
// SidebarNavigationHandler cases resolve a `vendorId` from
// `sl<SessionManager>().currentBusinessId` — this fake avoids importing the
// full Firebase/Cognito stack while supplying the needed getter.
// ---------------------------------------------------------------------------
class _FakeSessionManager extends ChangeNotifier implements SessionManager {
  @override
  String? get userId => 'test-vendor';
  @override
  String? get currentBusinessId => 'test-vendor';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // The recorded capability baseline (Preservation 3.3), resolved once so the
  // snapshot test and the PBT compare against the identical baseline.
  late final Map<String, dynamic> capabilityBaseline;

  setUpAll(() {
    // Register a fake SessionManager so SidebarNavigationHandler.tryGetScreenForItem
    // can resolve vendorId without pulling in the full Firebase/Cognito stack.
    final sl = GetIt.instance;
    if (!sl.isRegistered<SessionManager>()) {
      sl.registerSingleton<SessionManager>(_FakeSessionManager());
    }

    final live = <String, dynamic>{
      for (final t in _nonHardwareTypes) t.name: _capabilityNames(t),
    };
    capabilityBaseline = _readOrWriteGoldenMap('capabilities', live);
  });

  tearDownAll(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<SessionManager>()) {
      sl.unregister<SessionManager>();
    }
  });

  // =========================================================================
  // PRESERVATION 3.1 / 3.2 / 3.9 — Non-hardware sidebar + in-shell routing
  //
  // For every non-hardware type we snapshot:
  //   * the resolved sidebar sections (title + ordered item ids), and
  //   * the runtime type each item id resolves to via the shared in-shell
  //     resolver (`SidebarNavigationHandler.tryGetScreenForItem`).
  //
  // The fix adds a `case BusinessType.hardware` to `_getSectionsForBusiness`
  // and new resolver entries; it must NOT touch the `default`/retail branch or
  // any existing resolver case. So this snapshot must reproduce byte-for-byte
  // after the fix for every other vertical (3.1, 3.2) and they must route
  // identically (3.9).
  // =========================================================================
  group('Preservation 3.1/3.2/3.9 — non-hardware sidebar & routing', () {
    testWidgets('sidebar sections and in-shell routing are byte-stable for '
        'every non-hardware vertical', (tester) async {
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

      final observation = <String, dynamic>{};

      for (final type in _nonHardwareTypes) {
        final container = ProviderContainer(
          overrides: [
            businessTypeProvider.overrideWith(
              () => _FixedBusinessTypeNotifier(type),
            ),
            authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
          ],
        );

        final sections = container.read(sidebarSectionsProvider);

        final sectionRows = <Map<String, dynamic>>[];
        final routing = <String, String>{};
        for (final section in sections) {
          final itemIds = section.items.map((i) => i.id).toList();
          sectionRows.add({'title': section.title, 'items': itemIds});
          for (final id in itemIds) {
            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              id,
              ctx,
            );
            routing[id] = screen.runtimeType.toString();
          }
        }

        observation[type.name] = {'sections': sectionRows, 'routing': routing};

        container.dispose();
      }

      _expectGolden('sidebar_and_routing', observation);
    });
  });

  // =========================================================================
  // PRESERVATION 3.3 — Non-hardware capability sets unchanged
  //
  // The fix edits ONLY the hardware capability set (e.g. to reconcile the
  // returns/quotations manifest drift). No other type's grant/deny set may
  // change. Snapshot every non-hardware capability set, then assert via PBT
  // across the full domain.
  // =========================================================================
  group('Preservation 3.3 — non-hardware capability sets', () {
    test('every non-hardware capability set matches the recorded baseline', () {
      for (final type in _nonHardwareTypes) {
        expect(
          _capabilityNames(type),
          capabilityBaseline[type.name],
          reason:
              '${type.name} capability set changed. Hardware capability edits '
              'must not leak into any other vertical.',
        );
      }
    });

    test('PBT: for all non-hardware types the capability set is preserved', () {
      forAll(
        (int idx) {
          final type = _nonHardwareTypes[idx % _nonHardwareTypes.length];
          final live = _capabilityNames(type);
          final expected = (capabilityBaseline[type.name] as List)
              .cast<String>();
          expect(
            live,
            expected,
            reason:
                'Capability preservation violated for ${type.name}: the fix '
                'leaked a change into a non-hardware vertical.',
          );
          return true;
        },
        [Gen.interval(0, _nonHardwareTypes.length - 1)],
        numRuns: 25,
      );
    });

    test('hardware IS NOW granted the contested capabilities after the fix '
        '(intended flip, deliberately changed from the pre-fix baseline)', () {
      // Documents the deliberate, intended flip for the contradictions in
      // bugfix.md 1.5/1.6: the pre-fix baseline did NOT grant these to
      // hardware, and Task 3.3 reconciled the capability/module manifest by
      // granting them. This marker is NOT part of any preserved golden — it
      // exists only to document that this flip is expected, not a regression.
      final hw = FeatureResolver.getCapabilities(BusinessType.hardware.name);
      expect(hw.contains(BusinessCapability.useSalesReturn), isTrue);
      expect(hw.contains(BusinessCapability.useProformaInvoice), isTrue);
    });
  });

  // =========================================================================
  // PRESERVATION 3.4 — Non-hardware dashboard alert branches unchanged
  //
  // The fix rebinds ONLY the `case BusinessType.hardware` branch of
  // `business_alerts_widget.dart` to real data. Every other branch must render
  // the same titles/counts. We render the widget for each non-hardware type
  // with a fixed alert-count seed and snapshot the rendered text in tree order.
  // =========================================================================
  group('Preservation 3.4 — non-hardware dashboard alerts', () {
    testWidgets('alert titles/subtitles/counts are byte-stable for every '
        'non-hardware vertical', (tester) async {
      final observation = <String, dynamic>{};

      for (final type in _nonHardwareTypes) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _FixedBusinessTypeNotifier(type),
              ),
              alertCountsProvider.overrideWith(
                (ref) => Stream.value(_alertSeed),
              ),
            ],
            child: MaterialApp(
              key: ValueKey('alerts-${type.name}'),
              home: const Scaffold(body: BusinessAlertsWidget()),
            ),
          ),
        );

        // Emit the seeded stream and build the data branch (avoid
        // pumpAndSettle: the loading state shows an indeterminate spinner).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .toList();

        observation[type.name] = texts;
      }

      _expectGolden('non_hardware_alerts', observation);
    });
  });

  // =========================================================================
  // PRESERVATION 3.5 — Shared screens resolve identically for non-hardware
  //
  // AllTransactionsScreen, PrintMenuScreen, BackupScreen, ProformaScreen and
  // BillingReportsScreen are shared across verticals. The fix may add new
  // resolver entries / de-dup on the hardware path only — these existing
  // mappings must be untouched.
  // =========================================================================
  group('Preservation 3.5 — shared screens resolve identically', () {
    testWidgets('proforma/print/backup/all-transactions resolve to their '
        'shared screens via the in-shell resolver', (tester) async {
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

      expect(
        SidebarNavigationHandler.tryGetScreenForItem('proforma_bids', ctx),
        isA<ProformaScreen>(),
      );
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('print_settings', ctx),
        isA<PrintMenuScreen>(),
      );
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('doc_templates', ctx),
        isA<PrintMenuScreen>(),
      );
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('backup', ctx),
        isA<BackupScreen>(),
      );
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('sync_status', ctx),
        isA<BackupScreen>(),
      );
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('ledger_history', ctx),
        isA<AllTransactionsScreen>(),
      );
    });

    test('content_host keeps the shared BillingReportsScreen mapping for '
        'transaction reports (no fix touches this)', () {
      final src = File(
        'lib/widgets/desktop/content_host.dart',
      ).readAsStringSync();
      final norm = src.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        norm.contains(
          'AppScreen.transactionReports: () => const BillingReportsScreen()',
        ),
        isTrue,
        reason:
            'The shared BillingReportsScreen mapping for transactionReports '
            'must remain unchanged for non-hardware callers.',
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.8 — Already-correct hardware paths behave as today
  //
  // Some hardware paths already work: "New Quote" -> ProformaScreen, the
  // BuyFlow procurement flow, damage_logs, and the correctly-HIDDEN,
  // capability-gated batch_tracking (hardware is not granted useBatchExpiry).
  // These must not regress from adjacent fixes.
  // =========================================================================
  group('Preservation 3.8 — already-correct hardware paths', () {
    testWidgets('proforma/buyflow/procurement/damage_logs resolve to their '
        'real screens', (tester) async {
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

      // "New Quote" already resolves to ProformaScreen.
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('proforma_bids', ctx),
        isA<ProformaScreen>(),
      );
      // BuyFlow procurement flow.
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('buyflow_dashboard', ctx),
        isA<BuyFlowDashboard>(),
      );
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('procurement_log', ctx),
        isA<ProcurementLogScreen>(),
      );
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('purchase_orders', ctx),
        isA<BuyOrdersScreen>(),
      );
      // Inventory damage/adjustment.
      expect(
        SidebarNavigationHandler.tryGetScreenForItem('damage_logs', ctx),
        isA<DamageLogsScreen>(),
      );
    });

    test('capability-gated batch_tracking stays HIDDEN for hardware '
        '(useBatchExpiry not granted)', () {
      // The sidebar gates `batch_tracking` on BusinessCapability.useBatchExpiry.
      // Hardware is not granted it today and must remain so — the item is
      // correctly hidden and that must not regress.
      expect(
        FeatureResolver.canAccess(
          BusinessType.hardware.name,
          BusinessCapability.useBatchExpiry,
        ),
        isFalse,
        reason:
            'Hardware must remain WITHOUT useBatchExpiry so the gated '
            'batch_tracking sidebar item stays correctly hidden.',
      );
    });
  });
}
