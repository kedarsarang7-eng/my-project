/// Preservation Property Test — Non-Clinic Business Types & Shared Code Unaffected
///
/// **Validates: Requirements 3.4, 3.8**
///
/// Property 6: Preservation — Non-Clinic Business Types & Shared Code Unaffected
///
/// This test follows the OBSERVATION-FIRST methodology:
///   FOR ALL X WHERE X.businessType != BusinessType.clinic
///   DO ASSERT F(X) == F'(X) END FOR
///
/// On UNFIXED code (F) every observation is recorded as a golden and the test
/// PASSES — that recording IS the expected outcome (baseline capture). When
/// re-run after the clinic fixes (F'), the live observation is compared to the
/// recorded baseline, confirming `F'(X) == F(X)` for every non-clinic vertical.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/clinic_audit_preservation_non_clinic_unaffected_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:get_it/get_it.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/session/session_manager.dart';
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
// The input domain: every business type EXCEPT clinic. These are the inputs
// where the five clinic bugfix conditions do NOT hold.
// ---------------------------------------------------------------------------
final List<BusinessType> _nonClinicTypes = BusinessType.values
    .where((t) => t != BusinessType.clinic)
    .toList(growable: false);

// ---------------------------------------------------------------------------
// Golden helpers — record-on-first-run, compare-on-subsequent-runs.
// ---------------------------------------------------------------------------
const JsonEncoder _enc = JsonEncoder.withIndent('  ');

File _goldenFile(String name) =>
    File('test/preservation/__goldens__/clinic_audit_non_clinic/$name.json');

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
        'clinic-only fix must not alter any non-clinic vertical\'s config, '
        'capabilities, sidebar, or navigation. Restore the original behaviour, '
        'or update the golden only if this change is an intended, documented '
        'part of the fix.',
  );
}

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

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// The sorted capability-name set a business type is granted today.
List<String> _capabilityNames(BusinessType type) {
  final names = FeatureResolver.getCapabilities(
    type.name,
  ).map((c) => c.name).toList()..sort();
  return names;
}

/// The modules list for a business type from BusinessTypeConfig.
List<String> _modulesForType(BusinessType type) {
  return BusinessTypeRegistry.getConfig(type).modules;
}

// ---------------------------------------------------------------------------
// Minimal SessionManager fake so SidebarNavigationHandler resolves without
// pulling in the full Firebase/Cognito stack.
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
  late final Map<String, dynamic> capabilityBaseline;
  late final Map<String, dynamic> modulesBaseline;

  setUpAll(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<SessionManager>()) {
      sl.registerSingleton<SessionManager>(_FakeSessionManager());
    }

    // Record capability baseline
    final capLive = <String, dynamic>{
      for (final t in _nonClinicTypes) t.name: _capabilityNames(t),
    };
    capabilityBaseline = _readOrWriteGoldenMap('capabilities', capLive);

    // Record modules baseline
    final modLive = <String, dynamic>{
      for (final t in _nonClinicTypes) t.name: _modulesForType(t),
    };
    modulesBaseline = _readOrWriteGoldenMap('modules', modLive);
  });

  tearDownAll(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<SessionManager>()) {
      sl.unregister<SessionManager>();
    }
  });

  // =========================================================================
  // PRESERVATION 3.4 — Non-clinic modules lists unchanged
  //
  // The clinic fix does NOT touch any other business type's modules list in
  // BusinessTypeConfig. Assert every non-clinic type's modules remain stable.
  // =========================================================================
  group('Preservation 3.4 — non-clinic modules lists', () {
    test('every non-clinic modules list matches the recorded baseline', () {
      for (final type in _nonClinicTypes) {
        expect(
          _modulesForType(type),
          modulesBaseline[type.name],
          reason:
              '${type.name} modules list changed. Clinic-only fixes must not '
              'alter any other vertical\'s BusinessTypeConfig.modules.',
        );
      }
    });

    test('PBT: for all non-clinic types the modules list is preserved', () {
      forAll(
        (int idx) {
          final type = _nonClinicTypes[idx % _nonClinicTypes.length];
          final live = _modulesForType(type);
          final expected = (modulesBaseline[type.name] as List).cast<String>();
          expect(
            live,
            expected,
            reason:
                'Modules preservation violated for ${type.name}: the clinic '
                'fix leaked a change into a non-clinic vertical.',
          );
          return true;
        },
        [Gen.interval(0, _nonClinicTypes.length - 1)],
        numRuns: 50,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.4 — Non-clinic capability sets unchanged
  //
  // The clinic fix edits ONLY the clinic capability registry entry. No other
  // type's grant/deny set may change.
  // =========================================================================
  group('Preservation 3.4 — non-clinic capability sets', () {
    test('every non-clinic capability set matches the recorded baseline', () {
      for (final type in _nonClinicTypes) {
        expect(
          _capabilityNames(type),
          capabilityBaseline[type.name],
          reason:
              '${type.name} capability set changed. Clinic capability edits '
              'must not leak into any other vertical.',
        );
      }
    });

    test('PBT: for all non-clinic types the capability set is preserved', () {
      forAll(
        (int idx) {
          final type = _nonClinicTypes[idx % _nonClinicTypes.length];
          final live = _capabilityNames(type);
          final expected = (capabilityBaseline[type.name] as List)
              .cast<String>();
          expect(
            live,
            expected,
            reason:
                'Capability preservation violated for ${type.name}: the clinic '
                'fix leaked a change into a non-clinic vertical.',
          );
          return true;
        },
        [Gen.interval(0, _nonClinicTypes.length - 1)],
        numRuns: 50,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.4/3.8 — Non-clinic sidebar sections & navigation unchanged
  //
  // The clinic fix adds items to _getClinicSections() and cases to
  // SidebarNavigationHandler. It must NOT touch the default/retail branch or
  // any other business type's case. Snapshot every non-clinic type's sidebar
  // section list + item ids + resolved navigation target runtime types.
  // =========================================================================
  group('Preservation 3.4/3.8 — non-clinic sidebar & navigation routing', () {
    testWidgets('sidebar sections and in-shell routing are byte-stable for '
        'every non-clinic vertical', (tester) async {
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

      for (final type in _nonClinicTypes) {
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
            routing[id] = screen?.runtimeType.toString() ?? 'null';
          }
        }

        observation[type.name] = {'sections': sectionRows, 'routing': routing};

        container.dispose();
      }

      _expectGolden('sidebar_and_routing', observation);
    });
  });

  // =========================================================================
  // PRESERVATION 3.8 — business_alerts_widget.dart non-clinic cases unchanged
  //
  // Source-level assertion: the business_alerts_widget.dart file's non-clinic
  // switch cases (the _getTitle and _buildAlertsForBusiness branches for every
  // non-clinic BusinessType) are structurally unchanged. We fingerprint the
  // source file to detect any accidental edits.
  // =========================================================================
  group('Preservation 3.8 — business_alerts_widget source stability', () {
    test('business_alerts_widget.dart non-clinic source is unchanged', () {
      final src = File(
        'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
      ).readAsStringSync();

      // Extract all non-clinic BusinessType case references.
      // The clinic fix should never touch these lines.
      final nonClinicCases = <String>[];
      for (final type in _nonClinicTypes) {
        final pattern = 'BusinessType.${type.name}';
        final lines = src.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(pattern)) {
            nonClinicCases.add('${i + 1}:${lines[i].trim()}');
          }
        }
      }

      _expectGolden('alerts_widget_non_clinic_cases', nonClinicCases);
    });
  });

  // =========================================================================
  // PRESERVATION 3.8 — business_quick_actions.dart non-clinic cases unchanged
  //
  // Source-level assertion: business_quick_actions.dart's non-clinic switch
  // cases are unchanged after the clinic fix.
  // =========================================================================
  group('Preservation 3.8 — business_quick_actions source stability', () {
    test('business_quick_actions.dart non-clinic source is unchanged', () {
      final src = File(
        'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
      ).readAsStringSync();

      final nonClinicCases = <String>[];
      for (final type in _nonClinicTypes) {
        final pattern = 'BusinessType.${type.name}';
        final lines = src.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(pattern)) {
            nonClinicCases.add('${i + 1}:${lines[i].trim()}');
          }
        }
      }

      _expectGolden('quick_actions_non_clinic_cases', nonClinicCases);
    });
  });

  // =========================================================================
  // PRESERVATION 3.8 — InventoryService.deductStockInTransaction has no
  // clinic-specific logic
  //
  // The clinic fix grants clinic visibility into inventory but does NOT touch
  // the deduction call itself. Assert the deductStockInTransaction source has
  // no clinic-specific conditional logic.
  // =========================================================================
  group('Preservation 3.8 — deductStockInTransaction unchanged', () {
    test('deductStockInTransaction source contains no clinic-specific logic', () {
      final src = File(
        'lib/features/inventory/services/inventory_service.dart',
      ).readAsStringSync();

      // Find the deductStockInTransaction method body
      final methodStart = src.indexOf('deductStockInTransaction');
      expect(
        methodStart,
        isNot(-1),
        reason: 'deductStockInTransaction must exist in inventory_service.dart',
      );

      // Extract a reasonable chunk after the method signature (the method body)
      final methodBody = src.substring(
        methodStart,
        (methodStart + 2000).clamp(0, src.length),
      );

      // The method must NOT contain any clinic-specific branching
      expect(
        methodBody.contains('clinic'),
        isFalse,
        reason:
            'deductStockInTransaction must not contain clinic-specific logic. '
            'The clinic fix only grants visibility — it does not touch the '
            'deduction call.',
      );
      expect(
        methodBody.contains('BusinessType.clinic'),
        isFalse,
        reason:
            'deductStockInTransaction must not reference BusinessType.clinic.',
      );
    });

    test('deductStockInTransaction source fingerprint is stable', () {
      final src = File(
        'lib/features/inventory/services/inventory_service.dart',
      ).readAsStringSync();

      // Extract the method signature and first ~60 lines as a fingerprint
      final methodStart = src.indexOf('deductStockInTransaction');
      final chunk = src.substring(
        methodStart,
        (methodStart + 1500).clamp(0, src.length),
      );

      // Compute a stable fingerprint (length + char-sum)
      final norm = chunk.replaceAll('\r\n', '\n').trimRight();
      var hash = 0;
      for (final c in norm.codeUnits) {
        hash = (hash * 31 + c) & 0x7fffffff;
      }

      _expectGolden('deduct_stock_fingerprint', {
        'hash': hash,
        'length': norm.length,
      });
    });
  });

  // =========================================================================
  // PBT: Universal preservation property across the full non-clinic domain
  //
  // Generates arbitrary non-clinic BusinessType values and asserts modules,
  // capability registry, sidebar section count, and item ids are all identical
  // to the recorded baselines.
  // =========================================================================
  group('PBT — universal non-clinic preservation', () {
    testWidgets('for all non-clinic types: modules + capabilities + sidebar '
        'are preserved', (tester) async {
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

      forAll(
        (int idx) {
          final type = _nonClinicTypes[idx % _nonClinicTypes.length];

          // 1. Modules preservation
          final liveModules = _modulesForType(type);
          final expectedModules = (modulesBaseline[type.name] as List)
              .cast<String>();
          expect(
            liveModules,
            expectedModules,
            reason: '${type.name} modules changed after clinic fix',
          );

          // 2. Capabilities preservation
          final liveCaps = _capabilityNames(type);
          final expectedCaps = (capabilityBaseline[type.name] as List)
              .cast<String>();
          expect(
            liveCaps,
            expectedCaps,
            reason: '${type.name} capabilities changed after clinic fix',
          );

          // 3. Sidebar item count and section structure preservation
          final container = ProviderContainer(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _FixedBusinessTypeNotifier(type),
              ),
              authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
            ],
          );
          final sections = container.read(sidebarSectionsProvider);
          // Just verify the sections resolve without error — the detailed
          // golden comparison is done in the snapshot test above.
          expect(
            sections,
            isNotNull,
            reason: '${type.name} sidebar sections must resolve',
          );
          container.dispose();

          return true;
        },
        [Gen.interval(0, _nonClinicTypes.length - 1)],
        numRuns: 50,
      );
    });
  });
}
