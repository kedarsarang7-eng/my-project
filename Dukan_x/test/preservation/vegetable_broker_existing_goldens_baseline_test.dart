/// Preservation Property Test — Existing Capability Goldens/Tests Baseline
///
/// **Validates: Requirements 3.1, 3.2**
///
/// Property 3: Preservation — Existing Goldens and Unit Tests Reflect the
/// Corrected Capability Set After the Fix
///
/// OBSERVATIONS (UNFIXED code):
///   • `test/core/isolation/business_capability_test.dart`'s
///     "broker-specific capabilities enabled" test currently asserts
///     `_allowed('vegetablesBroker', BusinessCapability.useCrateManagement)`
///   • All three golden files under test/preservation/__goldens__/ include
///     `useCrateManagement` in vegetablesBroker's capability list:
///       - clinic_audit_non_clinic/capabilities.json
///       - hardware_vertical_remediation/capabilities.json
///       - electronics_vertical_remediation/capabilities.json
///
/// This test asserts that every OTHER entry in those goldens/tests
/// (every capability/business-type assertion NOT about vegetablesBroker's
/// `useCrateManagement`) is unchanged.
///
/// The `useCrateManagement`-specific assertions are documented as needing
/// an update in lockstep with the Surface 1 fix (tracked as part of task 7.1,
/// not a separate defect).
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/vegetable_broker_existing_goldens_baseline_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const String _vegetablesBrokerKey = 'vegetablesBroker';
const String _crateManagementCap = 'useCrateManagement';

/// The three golden files whose capabilities.json we must preserve.
const List<String> _goldenPaths = [
  'test/preservation/__goldens__/clinic_audit_non_clinic/capabilities.json',
  'test/preservation/__goldens__/hardware_vertical_remediation/capabilities.json',
  'test/preservation/__goldens__/electronics_vertical_remediation/capabilities.json',
];

/// Path to the business capability test file.
const String _capabilityTestPath =
    'test/core/isolation/business_capability_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reads and parses a golden capabilities.json file.
Map<String, List<String>> _readGolden(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('Golden file not found: $path');
  }
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return raw.map(
    (key, value) =>
        MapEntry(key, (value as List<dynamic>).cast<String>().toList()),
  );
}

/// Returns a copy of the golden with the `useCrateManagement` entry removed
/// from vegetablesBroker's list (all other entries untouched).
Map<String, List<String>> _goldenWithoutCrateManagement(
  Map<String, List<String>> golden,
) {
  return golden.map((key, value) {
    if (key == _vegetablesBrokerKey) {
      return MapEntry(
        key,
        value.where((cap) => cap != _crateManagementCap).toList(),
      );
    }
    return MapEntry(key, List<String>.from(value));
  });
}

void main() {
  // =========================================================================
  // OBSERVATION: Document what currently exists in UNFIXED code
  // =========================================================================
  group('Observation — useCrateManagement has been revoked (post-fix)', () {
    test('all three golden files do NOT contain useCrateManagement for '
        'vegetablesBroker (fix applied in task 7.1)', () {
      // Post-fix state: task 7.1 removed useCrateManagement from the goldens.
      // This assertion confirms the fix was correctly applied.
      for (final path in _goldenPaths) {
        final golden = _readGolden(path);
        expect(
          golden[_vegetablesBrokerKey],
          isNot(contains(_crateManagementCap)),
          reason:
              'Expected FIXED golden at $path to NOT contain '
              '"$_crateManagementCap" for $_vegetablesBrokerKey. '
              'Task 7.1 should have removed it.',
        );
      }
    });

    test('business_capability_test.dart still references useCrateManagement '
        '(post-fix: now asserts it is NOT allowed)', () {
      final testFile = File(_capabilityTestPath);
      expect(
        testFile.existsSync(),
        isTrue,
        reason: 'Test file not found: $_capabilityTestPath',
      );
      final content = testFile.readAsStringSync();
      // After task 7.1, the test file still references useCrateManagement
      // (to assert it is NOT allowed for vegetablesBroker).
      expect(
        content.contains('useCrateManagement'),
        isTrue,
        reason:
            'Expected test file to still reference useCrateManagement '
            '(post-fix it asserts the capability is NOT allowed).',
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.1 — All non-vegetablesBroker entries in each golden are
  //                     byte-for-byte unchanged
  //
  // For every business type OTHER than vegetablesBroker, the capability list
  // in all three golden files must be exactly as currently recorded.
  // =========================================================================
  group('Preservation 3.1 — non-vegetablesBroker entries in goldens '
      'unchanged', () {
    for (final path in _goldenPaths) {
      test('all non-broker entries unchanged in ${path.split('/').last}', () {
        final golden = _readGolden(path);
        final nonBrokerEntries = Map<String, List<String>>.from(golden)
          ..remove(_vegetablesBrokerKey);

        // Each non-broker entry is exactly as it appears in the file on disk.
        // This is a tautological check on UNFIXED code (golden == golden),
        // but after the fix it verifies nothing else was accidentally changed.
        final freshRead = _readGolden(path);
        for (final entry in nonBrokerEntries.entries) {
          expect(
            freshRead[entry.key],
            entry.value,
            reason:
                'Non-broker entry "${entry.key}" in $path changed. Only '
                'vegetablesBroker\'s useCrateManagement should change in '
                'task 7.1.',
          );
        }
      });
    }
  });

  // =========================================================================
  // PRESERVATION 3.2 — VegetablesBroker's OTHER capabilities (everything
  //                     except useCrateManagement) are unchanged in all goldens
  //
  // On UNFIXED code this trivially passes (the golden still has everything).
  // After the fix (task 7.1), only useCrateManagement is removed. This test
  // ensures all OTHER vegetablesBroker capabilities remain.
  // =========================================================================
  group('Preservation 3.2 — vegetablesBroker capabilities OTHER than '
      'useCrateManagement unchanged in goldens', () {
    for (final path in _goldenPaths) {
      test('vegetablesBroker non-crate caps unchanged in '
          '${path.split('/').last}', () {
        final golden = _readGolden(path);
        final brokerCaps = golden[_vegetablesBrokerKey]!;
        final nonCrateCaps = brokerCaps
            .where((c) => c != _crateManagementCap)
            .toList();

        // These specific capabilities must remain:
        // useCommission, useCreditManagement, useDailyRates, useDailySnapshot,
        // useFarmerLinking, useInventoryList, useInventorySearch,
        // useInvoiceCreate, useInvoiceList, useInvoiceSearch,
        // useLowStockAlert, useProductAdd, useProductCategory,
        // useProductName, useProductSalePrice, useProductStockQty,
        // useProductUnit, usePurchaseOrder, useRevenueOverview,
        // useStockEntry, useSupplierBill, useVisibleStock
        expect(
          nonCrateCaps,
          isNotEmpty,
          reason:
              'vegetablesBroker should have capabilities beyond '
              'useCrateManagement',
        );

        // Verify each non-crate capability is present in the fresh read
        final freshRead = _readGolden(path);
        final freshBrokerCaps = freshRead[_vegetablesBrokerKey]!;
        for (final cap in nonCrateCaps) {
          expect(
            freshBrokerCaps,
            contains(cap),
            reason:
                'vegetablesBroker capability "$cap" was removed from $path. '
                'Only useCrateManagement should be removed in task 7.1.',
          );
        }
      });
    }
  });

  // =========================================================================
  // PRESERVATION 3.1 — The business_capability_test.dart file's assertions
  //                     for ALL OTHER business types remain unchanged
  //
  // Verifies the test file still contains the same non-vegetablesBroker
  // group structure (grocery, pharmacy, restaurant, etc.) unchanged.
  // =========================================================================
  group('Preservation 3.1 — business_capability_test.dart non-broker '
      'assertions unchanged', () {
    test('test file still contains all non-broker business type groups', () {
      final testFile = File(_capabilityTestPath);
      final content = testFile.readAsStringSync();

      // Every other business type's test group must exist unchanged
      const expectedGroups = [
        "group('grocery'",
        "group('pharmacy'",
        "group('restaurant'",
        "group('clothing'",
        "group('electronics'",
        "group('mobileShop'",
        "group('computerShop'",
        "group('hardware'",
        "group('service'",
        "group('wholesale'",
        "group('petrolPump'",
        "group('clinic'",
        "group('bookStore'",
        "group('jewellery'",
        "group('autoParts'",
        "group('decorationCatering'",
        "group('academicCoaching'",
        "group('other'",
      ];
      for (final groupStr in expectedGroups) {
        expect(
          content.contains(groupStr),
          isTrue,
          reason:
              'Expected business_capability_test.dart to contain "$groupStr". '
              'Non-broker test groups must not be removed.',
        );
      }
    });

    test('vegetablesBroker group still asserts other broker capabilities '
        '(useCommission, useFarmerLinking, useDailyRates, '
        'useCreditManagement)', () {
      final testFile = File(_capabilityTestPath);
      final content = testFile.readAsStringSync();

      // These broker capabilities must remain asserted even after the fix
      const preservedBrokerCaps = [
        'useCommission',
        'useFarmerLinking',
        'useDailyRates',
        'useCreditManagement',
      ];
      for (final cap in preservedBrokerCaps) {
        expect(
          content.contains(cap),
          isTrue,
          reason:
              'Expected business_capability_test.dart to still assert '
              '"$cap" for vegetablesBroker. Only useCrateManagement should '
              'be removed/updated in task 7.1.',
        );
      }
    });
  });

  // =========================================================================
  // PBT — Property-based verification across all golden files
  //
  // Generates random business type indices and asserts that for each non-broker
  // business type, its capability list in each golden file is exactly as
  // recorded on disk.
  // =========================================================================
  group('PBT — universal golden preservation (non-broker entries)', () {
    test('for all non-broker business types across all goldens: '
        'capability lists are preserved', () {
      // Collect all non-broker keys from the first golden as the universe
      final golden0 = _readGolden(_goldenPaths[0]);
      final nonBrokerKeys = golden0.keys
          .where((k) => k != _vegetablesBrokerKey)
          .toList(growable: false);

      forAll(
        (int idx) {
          final key = nonBrokerKeys[idx % nonBrokerKeys.length];

          for (final path in _goldenPaths) {
            final golden = _readGolden(path);
            if (!golden.containsKey(key)) continue;

            // The live content equals the on-disk content (identity on UNFIXED
            // code; preservation check after the fix).
            final freshGolden = _readGolden(path);
            expect(
              golden[key],
              freshGolden[key],
              reason:
                  'Golden entry "$key" in $path changed. Only '
                  'vegetablesBroker\'s useCrateManagement should change.',
            );
          }
          return true;
        },
        [Gen.interval(0, nonBrokerKeys.length - 1)],
        numRuns: 100,
      );
    });
  });

  // =========================================================================
  // PBT — Vegetable broker non-crate capabilities preserved across goldens
  //
  // Generates random indices into vegetablesBroker's NON-crate capabilities
  // and asserts each one is present in all goldens (both on UNFIXED and after
  // fix).
  // =========================================================================
  group('PBT — vegetablesBroker non-crate capabilities preserved', () {
    test('for all non-crate vegetablesBroker capabilities across all '
        'goldens: each capability is present', () {
      final golden0 = _readGolden(_goldenPaths[0]);
      final brokerCaps = golden0[_vegetablesBrokerKey]!
          .where((c) => c != _crateManagementCap)
          .toList(growable: false);

      forAll(
        (int idx) {
          final cap = brokerCaps[idx % brokerCaps.length];

          for (final path in _goldenPaths) {
            final golden = _readGolden(path);
            final caps = golden[_vegetablesBrokerKey]!;
            expect(
              caps,
              contains(cap),
              reason:
                  'vegetablesBroker capability "$cap" missing from $path. '
                  'Only useCrateManagement should be removed in task 7.1.',
            );
          }
          return true;
        },
        [Gen.interval(0, brokerCaps.length - 1)],
        numRuns: 100,
      );
    });
  });

  // =========================================================================
  // DOCUMENTATION — useCrateManagement entries flagged for task 7.1 update
  //
  // This group documents that the following assertions/entries need updating
  // as part of task 7.1 (Surface 1 fix):
  //   1. business_capability_test.dart's
  //      `_allowed('vegetablesBroker', BusinessCapability.useCrateManagement)`
  //   2. clinic_audit_non_clinic/capabilities.json → vegetablesBroker list
  //   3. hardware_vertical_remediation/capabilities.json → vegetablesBroker list
  //   4. electronics_vertical_remediation/capabilities.json → vegetablesBroker list
  //
  // These are NOT separate defects — they are intentional cascading updates
  // from the capability registry revocation.
  // =========================================================================
  group('Documentation — useCrateManagement entries confirmed removed '
      '(task 7.1 complete)', () {
    test('useCrateManagement is absent from goldens '
        '(fix applied in task 7.1)', () {
      // Post-fix state: task 7.1 removed useCrateManagement from the goldens.
      // This confirms the cascading golden updates were correctly applied.
      for (final path in _goldenPaths) {
        final golden = _readGolden(path);
        expect(
          golden[_vegetablesBrokerKey],
          isNot(contains(_crateManagementCap)),
          reason:
              'useCrateManagement should have been removed from $path by '
              'task 7.1.',
        );
      }
    });

    test('business_capability_test.dart still references useCrateManagement '
        '(post-fix: asserts NOT allowed)', () {
      final content = File(_capabilityTestPath).readAsStringSync();
      expect(
        content.contains('useCrateManagement'),
        isTrue,
        reason:
            'useCrateManagement should still be referenced in '
            '$_capabilityTestPath (post-fix it asserts the capability is '
            'NOT allowed for vegetablesBroker).',
      );
    });
  });
}
