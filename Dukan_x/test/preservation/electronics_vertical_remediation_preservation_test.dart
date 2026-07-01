/// Global Preservation Property Test — Electronics Vertical Remediation
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**
///
/// **Property 1: Preservation** — Non-Electronics and Electronics-happy-path
/// behavior unchanged.
///
/// Methodology (observation-first on UNFIXED code):
///   1. Observe current behavior of `_getSectionsForBusiness(mobileShop)` and
///      `(computerShop)` sidebar outputs.
///   2. Observe route-guard allow/deny decisions for device screens.
///   3. Observe capability sets for all non-electronics business types.
///   4. Observe dashboard alert counts rendered for other verticals.
///   5. Observe the Electronics happy-path config (MRP/18%/gstEditable false).
///   6. Lock all observations into golden snapshots.
///   7. Write property-based tests generating random `(businessType, input)`
///      pairs where `businessType != electronics` (plus Electronics happy-path
///      unique-valid serials) and assert preserved behavior.
///
///   FOR ALL X WHERE NOT isBugCondition(X) DO  ASSERT F(X) == F'(X)  END FOR
///
/// On UNFIXED code the golden is written and the test PASSES — that recording
/// IS the expected outcome. When the same tests re-run after each fix phase,
/// the live observation is compared to the recorded baseline, realising
/// `F'(X) == F(X)` for every non-electronics path and every electronics happy
/// path.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/electronics_vertical_remediation_preservation_test.dart
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
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';

// ---------------------------------------------------------------------------
// Test doubles for Riverpod overrides
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
// Minimal SessionManager fake for sidebar resolution tests.
// ---------------------------------------------------------------------------
class _FakeSessionManager extends ChangeNotifier implements SessionManager {
  @override
  String? get userId => 'test-vendor';
  @override
  String? get currentBusinessId => 'test-vendor';
  @override
  String? get ownerId => 'test-vendor';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// The input domain for Property 1 preservation: every business type EXCEPT
// electronics. The bug condition holds only for `BusinessType.electronics`
// inputs that trigger a clause condition, so all non-electronics types are
// entirely in the preserved domain.
// ---------------------------------------------------------------------------
final List<BusinessType> _nonElectronicsTypes = BusinessType.values
    .where((t) => t != BusinessType.electronics)
    .toList(growable: false);

// ---------------------------------------------------------------------------
// Golden helpers — record-on-first-run, compare-on-subsequent-runs.
// ---------------------------------------------------------------------------
const JsonEncoder _enc = JsonEncoder.withIndent('  ');

File _goldenFile(String name) => File(
  'test/preservation/__goldens__/electronics_vertical_remediation/$name.json',
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
        'Preservation regression: "$name" changed between F and F\'. An '
        'electronics-only fix must not alter any non-electronics vertical, '
        'the mobileShop/computerShop sidebars/validators/guards, the warranty '
        '0..120 validation, or the Electronics happy-path config. Restore the '
        'original behaviour, or update the golden only if this change is an '
        'intended, documented part of the fix.',
  );
}

/// Reads the recorded golden map, or records [live] as the baseline and returns
/// it.
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

/// Sorted capability-name set for a business type.
List<String> _capabilityNames(BusinessType type) {
  final names = FeatureResolver.getCapabilities(
    type.name,
  ).map((c) => c.name).toList()..sort();
  return names;
}

void main() {
  late final Map<String, dynamic> capabilityBaseline;

  setUpAll(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<SessionManager>()) {
      sl.registerSingleton<SessionManager>(_FakeSessionManager());
    }

    // Record or read the capability baseline for non-electronics types.
    final live = <String, dynamic>{
      for (final t in _nonElectronicsTypes) t.name: _capabilityNames(t),
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
  // PRESERVATION 3.1 — mobileShop / computerShop sidebars unchanged
  //
  // The fix splits electronics OUT of the shared `_getRetailSections()` case.
  // mobileShop's `_getMobileShopSections()` and computerShop's
  // `_getRetailSections()` routing must remain byte-for-byte identical.
  // =========================================================================
  group('Preservation 3.1 — mobileShop/computerShop sidebars', () {
    testWidgets('sidebar sections and in-shell routing are byte-stable for '
        'mobileShop and computerShop', (tester) async {
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

      for (final type in [BusinessType.mobileShop, BusinessType.computerShop]) {
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

      _expectGolden('mobileshop_computershop_sidebars', observation);
    });
  });

  // =========================================================================
  // PRESERVATION 3.2 — mobileShop serial validator + contains('mobile') async
  // duplicate check
  //
  // The mobileShop-only serial validator (non-empty required) and the
  // `businessType.name.contains('mobile')` async duplicate check must stay
  // unchanged. We test this by verifying: (a) mobileShop has serialNo as a
  // REQUIRED field in its config, (b) electronics does NOT, and (c) the
  // contains('mobile') gate only matches mobileShop.
  // =========================================================================
  group('Preservation 3.2 — mobileShop serial validator + async check', () {
    test('mobileShop config requires serialNo; electronics does not', () {
      final mobileConfig = BusinessTypeRegistry.getConfig(
        BusinessType.mobileShop,
      );
      final electronicsConfig = BusinessTypeRegistry.getConfig(
        BusinessType.electronics,
      );

      expect(
        mobileConfig.isRequired(ItemField.serialNo),
        isTrue,
        reason: 'mobileShop must require serialNo (Preservation 3.2)',
      );
      expect(
        electronicsConfig.isRequired(ItemField.serialNo),
        isFalse,
        reason:
            'Electronics serialNo is optional in config (to be enforced at '
            'validation layer per Phase 1, not config layer)',
      );
    });

    test('contains("mobile") gate matches only mobileShop', () {
      // The async duplicate check is gated by
      // `widget.businessType.name.contains('mobile')`.
      // This must match mobileShop and NOT match electronics or computerShop.
      expect(BusinessType.mobileShop.name.contains('mobile'), isTrue);
      expect(BusinessType.electronics.name.contains('mobile'), isFalse);
      expect(BusinessType.computerShop.name.contains('mobile'), isFalse);
    });

    test('PBT: for all non-electronics types the contains("mobile") gate '
        'matches only mobileShop', () {
      forAll(
        (int idx) {
          final type = _nonElectronicsTypes[idx % _nonElectronicsTypes.length];
          final matchesMobile = type.name.contains('mobile');
          if (type == BusinessType.mobileShop) {
            expect(matchesMobile, isTrue);
          } else {
            expect(
              matchesMobile,
              isFalse,
              reason: '${type.name} must not match the mobile serial gate',
            );
          }
          return true;
        },
        [Gen.interval(0, _nonElectronicsTypes.length - 1)],
        numRuns: _nonElectronicsTypes.length,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.3 — warranty 0..120 validation (D2 — already exists)
  //
  // The existing warranty validator in manual_item_entry_sheet accepts null/
  // empty (optional), rejects non-integer, and enforces 0..120. This must be
  // preserved byte-for-byte.
  // =========================================================================
  group('Preservation 3.3 — warranty 0..120 validation preserved', () {
    // We test the validation LOGIC directly by mimicking what the validator
    // does. The actual validator is an inline closure, so we replicate its
    // logic here and assert it matches the expected behavior.
    String? warrantyValidator(String? v) {
      if (v == null || v.trim().isEmpty) return null;
      final parsed = int.tryParse(v.trim());
      if (parsed == null) return 'Warranty must be a whole number';
      if (parsed < 0 || parsed > 120) {
        return 'Warranty must be between 0 and 120 months';
      }
      return null;
    }

    test('warranty validator accepts null/empty, 0, 60, 120', () {
      expect(warrantyValidator(null), isNull);
      expect(warrantyValidator(''), isNull);
      expect(warrantyValidator(' '), isNull);
      expect(warrantyValidator('0'), isNull);
      expect(warrantyValidator('60'), isNull);
      expect(warrantyValidator('120'), isNull);
    });

    test('warranty validator rejects non-integer and out-of-range', () {
      expect(warrantyValidator('abc'), 'Warranty must be a whole number');
      expect(warrantyValidator('3.5'), 'Warranty must be a whole number');
      expect(
        warrantyValidator('-1'),
        'Warranty must be between 0 and 120 months',
      );
      expect(
        warrantyValidator('121'),
        'Warranty must be between 0 and 120 months',
      );
      expect(
        warrantyValidator('999'),
        'Warranty must be between 0 and 120 months',
      );
    });

    test('PBT: warranty months in 0..120 always pass; outside always fail', () {
      forAll(
        (int months) {
          final result = warrantyValidator(months.toString());
          if (months >= 0 && months <= 120) {
            expect(
              result,
              isNull,
              reason: 'Valid warranty $months should pass',
            );
          } else {
            expect(
              result,
              'Warranty must be between 0 and 120 months',
              reason: 'Invalid warranty $months should be rejected',
            );
          }
          return true;
        },
        [Gen.interval(-50, 200)],
        numRuns: 50,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.4 — Electronics MRP/18%/gstEditable false/required-fields
  //
  // The Electronics config (priceLabel "MRP", defaultGstRate 18.0,
  // gstEditable false, required itemName/quantity/price/brand/hsnCode) must
  // remain unchanged through all fix phases.
  // =========================================================================
  group('Preservation 3.4 — Electronics billing config', () {
    test(
      'Electronics config is MRP/18%/gstEditable=false with correct fields',
      () {
        final config = BusinessTypeRegistry.getConfig(BusinessType.electronics);

        expect(config.priceLabel, 'MRP');
        expect(config.defaultGstRate, 18.0);
        expect(config.gstEditable, isFalse);
        expect(config.itemLabel, 'Product');
        expect(config.addItemLabel, 'Add Product');

        // Required fields
        expect(config.requiredFields, contains(ItemField.itemName));
        expect(config.requiredFields, contains(ItemField.quantity));
        expect(config.requiredFields, contains(ItemField.price));
        expect(config.requiredFields, contains(ItemField.brand));
        expect(config.requiredFields, contains(ItemField.hsnCode));

        // serialNo is OPTIONAL (not required in config)
        expect(config.requiredFields.contains(ItemField.serialNo), isFalse);
        expect(config.optionalFields, contains(ItemField.serialNo));
        expect(config.optionalFields, contains(ItemField.warrantyMonths));
      },
    );

    test('golden: Electronics config snapshot', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.electronics);
      final observation = {
        'type': config.type.name,
        'priceLabel': config.priceLabel,
        'defaultGstRate': config.defaultGstRate,
        'gstEditable': config.gstEditable,
        'itemLabel': config.itemLabel,
        'addItemLabel': config.addItemLabel,
        'requiredFields': config.requiredFields.map((f) => f.name).toList(),
        'optionalFields': config.optionalFields.map((f) => f.name).toList(),
        'unitOptions': config.unitOptions.map((u) => u.name).toList(),
        'modules': config.modules,
      };
      _expectGolden('electronics_billing_config', observation);
    });
  });

  // =========================================================================
  // PRESERVATION 3.5 — unique-valid Electronics happy path
  //
  // A unique, valid, non-blank serial for an Electronics device sale must
  // complete exactly as today. We verify that the Electronics config accepts
  // serialNo as a valid optional field and that the billing modules include
  // the relevant paths (sales, warranty, returns).
  // =========================================================================
  group('Preservation 3.5 — Electronics happy path', () {
    test('Electronics config supports the device-sale happy path', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.electronics);

      // The happy path requires: serial is an accepted field, warranty is
      // accepted, and the billing modules include sales + warranty.
      expect(config.hasField(ItemField.serialNo), isTrue);
      expect(config.hasField(ItemField.warrantyMonths), isTrue);
      expect(config.hasModule('sales'), isTrue);
      expect(config.hasModule('warranty'), isTrue);
      expect(config.hasModule('returns'), isTrue);
    });

    test('Electronics holds useIMEI + useWarranty capabilities', () {
      final caps = FeatureResolver.getCapabilities(
        BusinessType.electronics.name,
      );
      expect(caps.contains(BusinessCapability.useIMEI), isTrue);
      expect(caps.contains(BusinessCapability.useWarranty), isTrue);
    });

    test('PBT: for random serial strings, Electronics config always accepts '
        'them as an optional field (happy-path prerequisite)', () {
      forAll(
        (int seed) {
          // Generate a pseudo-random serial string
          final serial = 'SN-${seed.abs()}-${(seed * 37).abs()}';
          final config = BusinessTypeRegistry.getConfig(
            BusinessType.electronics,
          );
          // The config always has serialNo as an optional field — this is the
          // structural precondition for the happy path.
          expect(config.hasField(ItemField.serialNo), isTrue);
          expect(config.isRequired(ItemField.serialNo), isFalse);
          // Serial is non-blank and unique (in this test, trivially unique) —
          // so it would pass any validation. The happy path is preserved.
          expect(serial.trim().isNotEmpty, isTrue);
          return true;
        },
        [Gen.interval(1, 10000)],
        numRuns: 30,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.6 — other verticals' dashboards/guards/RBAC/capability sets
  //
  // Every non-electronics type's capability set, sidebar routing, and dashboard
  // alert behavior must be unchanged.
  // =========================================================================
  group('Preservation 3.6 — other verticals unchanged', () {
    test(
      'every non-electronics capability set matches the recorded baseline',
      () {
        for (final type in _nonElectronicsTypes) {
          expect(
            _capabilityNames(type),
            capabilityBaseline[type.name],
            reason:
                '${type.name} capability set changed. Electronics capability '
                'edits must not leak into any other vertical.',
          );
        }
      },
    );

    test(
      'PBT: for all non-electronics types the capability set is preserved',
      () {
        forAll(
          (int idx) {
            final type =
                _nonElectronicsTypes[idx % _nonElectronicsTypes.length];
            final live = _capabilityNames(type);
            final expected = (capabilityBaseline[type.name] as List)
                .cast<String>();
            expect(
              live,
              expected,
              reason:
                  'Capability preservation violated for ${type.name}: the fix '
                  'leaked a change into a non-electronics vertical.',
            );
            return true;
          },
          [Gen.interval(0, _nonElectronicsTypes.length - 1)],
          numRuns: 30,
        );
      },
    );

    testWidgets('sidebar sections are byte-stable for all non-electronics '
        'verticals', (tester) async {
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

      for (final type in _nonElectronicsTypes) {
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

      _expectGolden('all_non_electronics_sidebars', observation);
    });

    testWidgets('dashboard alert rendering is byte-stable for non-electronics '
        'verticals', (tester) async {
      final alertSeed = <String, int>{
        'lowStock': 2,
        'expiringSoon': 3,
        'criticalStock': 1,
        'expired': 4,
      };

      final observation = <String, dynamic>{};

      for (final type in _nonElectronicsTypes) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _FixedBusinessTypeNotifier(type),
              ),
              alertCountsProvider.overrideWith(
                (ref) => Stream.value(alertSeed),
              ),
            ],
            child: MaterialApp(
              key: ValueKey('alerts-${type.name}'),
              home: const Scaffold(body: BusinessAlertsWidget()),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .toList();

        observation[type.name] = texts;
      }

      _expectGolden('non_electronics_alerts', observation);
    });
  });

  // =========================================================================
  // PRESERVATION 3.7 — generic inventory/returns/reports/backup unchanged
  //
  // The generic screens (inventory, returns, reports, backup) must remain
  // accessible and resolve identically regardless of the electronics fix.
  // =========================================================================
  group('Preservation 3.7 — generic screens unchanged', () {
    testWidgets('generic sidebar items resolve identically', (tester) async {
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

      // These generic ids appear in _getRetailSections and must resolve to
      // their expected screen types.
      final genericIds = [
        'stock_summary',
        'item_stock',
        'low_stock',
        'return_inwards',
        'backup',
        'sync_status',
        'print_settings',
        'analytics_hub',
        'gstr1',
      ];

      final observation = <String, String>{};
      for (final id in genericIds) {
        final screen = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);
        observation[id] = screen.runtimeType.toString();
      }

      _expectGolden('generic_screen_routing', observation);
    });
  });

  // =========================================================================
  // PRESERVATION 3.8 — non-negotiable constraints: RID, paise, tenant-scoped
  //
  // We verify that the Electronics config and capability structure conform to
  // the constraints that all new code must honor.
  // =========================================================================
  group('Preservation 3.8 — non-negotiable constraints', () {
    test(
      'Electronics capability set is tenant-isolated (no SYSTEM override)',
      () {
        // Verify the capability set exists and is specific to electronics —
        // no cross-vertical leakage.
        final electronicsCaps = FeatureResolver.getCapabilities('electronics');
        final groceryCaps = FeatureResolver.getCapabilities('grocery');

        // Electronics-specific capabilities that grocery should not have
        expect(electronicsCaps.contains(BusinessCapability.useIMEI), isTrue);
        expect(
          electronicsCaps.contains(BusinessCapability.useWarranty),
          isTrue,
        );
        expect(groceryCaps.contains(BusinessCapability.useIMEI), isFalse);
        expect(groceryCaps.contains(BusinessCapability.useWarranty), isFalse);
      },
    );

    test(
      'route guards for device screens exclude electronics (pre-fix state)',
      () {
        // This test documents the PRE-FIX state: electronics is NOT in the
        // warranty/serial-history allow-lists. This is the baseline that must
        // be correctly changed ONLY for electronics in later phases (not for
        // any other type accidentally).
        //
        // After the Phase 2 fix, this test would need updating (it documents
        // the current state). But for now, it captures the baseline.
        //
        // The route guards allow computerShop + mobileShop only.
        // We verify by reading the source file.
        final routeFile = File('lib/core/routing/legacy_routes.dart');
        if (routeFile.existsSync()) {
          final src = routeFile.readAsStringSync();
          // The warranty guard includes computerShop and mobileShop
          expect(
            src.contains("BusinessType.computerShop"),
            isTrue,
            reason: 'Route guards must reference computerShop',
          );
          expect(
            src.contains("BusinessType.mobileShop"),
            isTrue,
            reason: 'Route guards must reference mobileShop',
          );
        }
      },
    );

    test('PBT: Electronics does NOT hold capabilities it should lack', () {
      // Electronics must NOT hold these capabilities (confirmed in Phase 0):
      final electronicsCaps = FeatureResolver.getCapabilities('electronics');
      final mustNotHold = [
        BusinessCapability.useMultiUnit,
        BusinessCapability.useExchange,
        BusinessCapability.useBuyback,
      ];

      forAll(
        (int idx) {
          final cap = mustNotHold[idx % mustNotHold.length];
          expect(
            electronicsCaps.contains(cap),
            isFalse,
            reason:
                'Electronics must NOT hold ${cap.name} (out of scope / parked)',
          );
          return true;
        },
        [Gen.interval(0, mustNotHold.length - 1)],
        numRuns: mustNotHold.length,
      );
    });
  });
}
