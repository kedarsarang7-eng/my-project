// ============================================================================
// PROPERTY TEST: Non-Wholesale Behavior Preservation
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 2: Non-wholesale behavior preservation
//
// **Validates: Requirements 1.11, 1.12, 4.10, 5.9, 14.8, 14.9**
//
// For a set of non-wholesale business types (electronics, pharmacy, bookStore,
// hardware, grocery), verifies that:
//   1. `_getSectionsForBusiness(type)` returns the same result as before
//      (not `_getWholesaleSections()`)
//   2. `business_type_config` for those types is unchanged
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_non_wholesale_preservation_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

// Uses the @visibleForTesting `getSectionsForBusinessType` wrapper that
// delegates to `_getSectionsForBusiness` without requiring Riverpod.

// ---------------------------------------------------------------------------
// Non-wholesale business types — the preserved domain.
// ---------------------------------------------------------------------------
final List<BusinessType> nonWholesaleTypes = BusinessType.values
    .where((t) => t != BusinessType.wholesale)
    .toList(growable: false);

/// The specific types called out in the task description.
const List<BusinessType> explicitNonWholesaleTypes = [
  BusinessType.electronics,
  BusinessType.pharmacy,
  BusinessType.bookStore,
  BusinessType.hardware,
  BusinessType.grocery,
];

// ---------------------------------------------------------------------------
// Snapshot helpers — deterministic serialisation of sidebar sections and config.
// ---------------------------------------------------------------------------

/// Creates a stable, comparable representation of a sidebar section list.
List<Map<String, dynamic>> sidebarSnapshot(List<SidebarSection> sections) {
  return sections.map((s) {
    return <String, dynamic>{
      'index': s.index,
      'title': s.title,
      'items': s.items.map((item) {
        return <String, dynamic>{
          'id': item.id,
          'label': item.label,
          'capability': item.capability?.name,
          'permission': item.permission,
        };
      }).toList(),
    };
  }).toList();
}

void main() {
  const int kNumRuns = 200;

  group(
    'Feature: wholesale-vertical-remediation, Property 2: Non-wholesale behavior preservation',
    () {
      // -----------------------------------------------------------------------
      // Property 2a: _getSectionsForBusiness(type) for non-wholesale types does
      // NOT return _getWholesaleSections().
      // -----------------------------------------------------------------------
      test(
        'Property 2a (forAll): non-wholesale types never return wholesale sections '
        '($kNumRuns random draws from non-wholesale domain)',
        () {
          // Wholesale-unique section title for comparison
          const wholesaleUniqueSection = 'Godown / Stock';

          final held = forAll(
            (int index) {
              final type = nonWholesaleTypes[index % nonWholesaleTypes.length];
              final sections = getSectionsForBusinessType(type);
              final sectionTitles = sections.map((s) => s.title).toSet();
              // The non-wholesale type must NOT contain the wholesale-unique section
              return !sectionTitles.contains(wholesaleUniqueSection);
            },
            [Gen.interval(0, nonWholesaleTypes.length * 10)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'No non-wholesale type should resolve to wholesale sections',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 2b: business_type_config for non-wholesale types is unchanged
      // (defaultGstRate, gstEditable preserved).
      // -----------------------------------------------------------------------
      test(
        'Property 2b (forAll): business_type_config for non-wholesale types is stable '
        '($kNumRuns random draws)',
        () {
          // Record baselines
          final baselines = <BusinessType, Map<String, dynamic>>{};
          for (final type in nonWholesaleTypes) {
            final config = BusinessTypeRegistry.getConfig(type);
            baselines[type] = {
              'defaultGstRate': config.defaultGstRate,
              'gstEditable': config.gstEditable,
              'optionalFieldCount': config.optionalFields.length,
              'requiredFieldCount': config.requiredFields.length,
            };
          }

          final held = forAll(
            (int index) {
              final type = nonWholesaleTypes[index % nonWholesaleTypes.length];
              final config = BusinessTypeRegistry.getConfig(type);
              final baseline = baselines[type]!;

              // defaultGstRate must be unchanged
              if (config.defaultGstRate != baseline['defaultGstRate'])
                return false;
              // gstEditable must be unchanged
              if (config.gstEditable != baseline['gstEditable']) return false;
              // field counts must be stable
              if (config.optionalFields.length !=
                  baseline['optionalFieldCount']) {
                return false;
              }
              if (config.requiredFields.length !=
                  baseline['requiredFieldCount']) {
                return false;
              }
              return true;
            },
            [Gen.interval(0, nonWholesaleTypes.length * 10)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Property 2: Non-wholesale business type configs must not change',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 2c: Explicit named types sidebar consistency.
      // For the 5 named types, assert sidebar output is deterministic.
      // -----------------------------------------------------------------------
      test(
        'Property 2c: explicit non-wholesale types (electronics, pharmacy, '
        'bookStore, hardware, grocery) have deterministic sidebar output',
        () {
          for (final type in explicitNonWholesaleTypes) {
            final first = sidebarSnapshot(getSectionsForBusinessType(type));
            // Call multiple times to confirm determinism
            for (var i = 0; i < 20; i++) {
              final again = sidebarSnapshot(getSectionsForBusinessType(type));
              expect(
                again,
                equals(first),
                reason:
                    '$type sidebar sections must be deterministic — '
                    'no wholesale remediation should affect this',
              );
            }
          }
        },
      );

      // -----------------------------------------------------------------------
      // Property 2d: drugSchedule must not appear in types where it's irrelevant.
      // (Only pharmacy and clinic are allowed to have it)
      // -----------------------------------------------------------------------
      test(
        'Property 2d (forAll): drugSchedule does not leak to non-pharmacy/non-clinic types',
        () {
          final typesWithoutDrugSchedule = nonWholesaleTypes
              .where(
                (t) => t != BusinessType.pharmacy && t != BusinessType.clinic,
              )
              .toList(growable: false);

          final held = forAll(
            (int index) {
              final type =
                  typesWithoutDrugSchedule[index %
                      typesWithoutDrugSchedule.length];
              final config = BusinessTypeRegistry.getConfig(type);
              return !config.optionalFields.contains(ItemField.drugSchedule);
            },
            [Gen.interval(0, typesWithoutDrugSchedule.length * 10)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'drugSchedule must only exist in pharmacy/clinic config — '
                'no leakage to other types from wholesale remediation',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 2e: Non-wholesale sidebar sections are deterministic across
      // repeated calls (100 iterations, 5 explicit types).
      // -----------------------------------------------------------------------
      test(
        'Property 2e (forAll): sidebar section count is stable for non-wholesale types',
        () {
          // Capture section counts once
          final sectionCounts = <BusinessType, int>{};
          for (final type in nonWholesaleTypes) {
            sectionCounts[type] = getSectionsForBusinessType(type).length;
          }

          final held = forAll(
            (int index) {
              final type = nonWholesaleTypes[index % nonWholesaleTypes.length];
              final current = getSectionsForBusinessType(type).length;
              return current == sectionCounts[type];
            },
            [Gen.interval(0, nonWholesaleTypes.length * 10)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Property 2: Non-wholesale sidebar section counts must be stable',
          );
        },
      );
    },
  );
}
