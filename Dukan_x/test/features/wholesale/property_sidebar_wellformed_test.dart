// ============================================================================
// PROPERTY TEST: Wholesale Sidebar Items Are Well-Formed
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 6: Wholesale sidebar items are well-formed
//
// **Validates: Requirements 5.3**
//
// For every item in `_getWholesaleSections()`, verifies:
//   - id is non-empty and unique across all wholesale sidebar items
//   - label is non-empty (at least one non-whitespace character)
//   - icon is not null
//
// Since the sidebar config is static/deterministic, this is run 100+ iterations
// to verify the invariant holds consistently (deterministic re-verification).
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_sidebar_wellformed_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

void main() {
  const int kNumRuns = 200;

  group(
    'Feature: wholesale-vertical-remediation, Property 6: Wholesale sidebar items are well-formed',
    () {
      // Retrieve the wholesale sections once — they are static/deterministic.
      late List<SidebarSection> wholesaleSections;
      late List<SidebarMenuItem> allItems;

      setUpAll(() {
        wholesaleSections = getSectionsForBusinessType(BusinessType.wholesale);
        allItems = wholesaleSections.expand((s) => s.items).toList();
      });

      // -----------------------------------------------------------------------
      // Property 6a: Every item id is non-empty.
      // -----------------------------------------------------------------------
      test('Property 6a: every wholesale sidebar item has a non-empty id', () {
        for (final item in allItems) {
          expect(
            item.id.isNotEmpty,
            isTrue,
            reason:
                'Wholesale sidebar item must have a non-empty id. '
                'Found empty id in section with label "${item.label}"',
          );
        }
      });

      // -----------------------------------------------------------------------
      // Property 6b: All item ids are unique across the entire wholesale sidebar.
      // -----------------------------------------------------------------------
      test('Property 6b: all wholesale sidebar item ids are unique', () {
        final ids = <String>{};
        for (final item in allItems) {
          expect(
            ids.add(item.id),
            isTrue,
            reason:
                'Duplicate wholesale sidebar item id found: "${item.id}". '
                'All wholesale sidebar item ids must be unique.',
          );
        }
      });

      // -----------------------------------------------------------------------
      // Property 6c: Every item label is non-empty and contains at least one
      // non-whitespace character.
      // -----------------------------------------------------------------------
      test(
        'Property 6c: every wholesale sidebar item has a non-empty label with at least one non-whitespace char',
        () {
          for (final item in allItems) {
            expect(
              item.label.isNotEmpty,
              isTrue,
              reason: 'Wholesale sidebar item id="${item.id}" has empty label',
            );
            expect(
              item.label.trim().isNotEmpty,
              isTrue,
              reason:
                  'Wholesale sidebar item id="${item.id}" has whitespace-only '
                  'label: "${item.label}"',
            );
          }
        },
      );

      // -----------------------------------------------------------------------
      // Property 6d: Every item icon is not null.
      // -----------------------------------------------------------------------
      test('Property 6d: every wholesale sidebar item has a non-null icon', () {
        for (final item in allItems) {
          // IconData is non-nullable in the model, but this test confirms
          // the contract is enforced at the data level.
          expect(
            item.icon.codePoint > 0,
            isTrue,
            reason: 'Wholesale sidebar item id="${item.id}" has invalid icon',
          );
        }
      });

      // -----------------------------------------------------------------------
      // Property 6e: Section titles are non-empty and sections have items.
      // -----------------------------------------------------------------------
      test(
        'Property 6e: every wholesale section has a non-empty title and at least one item',
        () {
          for (final section in wholesaleSections) {
            expect(
              section.title.trim().isNotEmpty,
              isTrue,
              reason:
                  'Wholesale section at index ${section.index} has empty title',
            );
            expect(
              section.items.isNotEmpty,
              isTrue,
              reason: 'Wholesale section "${section.title}" has no items',
            );
          }
        },
      );

      // -----------------------------------------------------------------------
      // Property 6 (forAll): Deterministic re-verification over 200 iterations.
      // Since the config is static, each iteration re-reads and re-validates
      // the same invariants, confirming no non-determinism or mutation occurs.
      // -----------------------------------------------------------------------
      test(
        'Property 6 (forAll): wholesale sidebar well-formedness holds across '
        '$kNumRuns iterations (deterministic re-verification)',
        () {
          final held = forAll(
            (int iteration) {
              // Re-fetch the sections each iteration to confirm determinism
              final sections = getSectionsForBusinessType(
                BusinessType.wholesale,
              );
              final items = sections.expand((s) => s.items).toList();

              if (items.isEmpty) return false;

              final ids = <String>{};
              for (final item in items) {
                // id is non-empty
                if (item.id.isEmpty) return false;
                // id is unique
                if (!ids.add(item.id)) return false;
                // label has at least one non-whitespace char
                if (item.label.trim().isEmpty) return false;
                // icon has a valid codePoint (non-nullable IconData contract)
                if (item.icon.codePoint <= 0) return false;
              }

              // Section titles are non-empty
              for (final section in sections) {
                if (section.title.trim().isEmpty) return false;
                if (section.items.isEmpty) return false;
              }

              return true;
            },
            [Gen.interval(0, kNumRuns)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Property 6: Wholesale sidebar items must be well-formed '
                'across all iterations — non-empty unique ids, non-whitespace '
                'labels, non-null icons',
          );
        },
      );
    },
  );
}
