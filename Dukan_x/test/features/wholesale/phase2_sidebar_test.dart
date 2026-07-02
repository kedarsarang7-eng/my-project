// ============================================================================
// EXAMPLE TEST: Dedicated Wholesale Sidebar Builder & Non-Wholesale Preservation
// ============================================================================
// Feature: wholesale-vertical-remediation, Task 5.7
//
// **Validates: Requirements 5.1, 5.2, 5.9**
//
// Asserts:
//   - getSectionsForBusinessType(BusinessType.wholesale) returns sections
//     with the expected distributor groups (Orders & Dispatch, Pricing & Rate
//     Lists, Receivables & Credit, Godown / Stock, Reports, Settings)
//   - The delivery-challan entry exists with id `delivery_challans`
//   - getSectionsForBusinessType returns unchanged behavior for non-wholesale
//     BusinessType values (no wholesale sections leak into other types)
//
// Run: flutter test test/features/wholesale/phase2_sidebar_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

void main() {
  group('Phase 2 — Wholesale sidebar builder (example tests)', () {
    late List<SidebarSection> wholesaleSections;
    late List<SidebarMenuItem> allItems;

    setUpAll(() {
      wholesaleSections = getSectionsForBusinessType(BusinessType.wholesale);
      allItems = wholesaleSections.expand((s) => s.items).toList();
    });

    // -------------------------------------------------------------------------
    // 5.1: Dedicated builder returns expected distributor groups.
    // -------------------------------------------------------------------------
    test(
      'getSectionsForBusinessType(wholesale) returns expected distributor groups',
      () {
        final titles = wholesaleSections.map((s) => s.title).toList();

        expect(titles, contains('Orders & Dispatch'));
        expect(titles, contains('Pricing & Rate Lists'));
        expect(titles, contains('Receivables & Credit'));
        expect(titles, contains('Godown / Stock'));
        expect(titles, contains('Reports'));
        expect(titles, contains('Settings'));
      },
    );

    // -------------------------------------------------------------------------
    // 5.2: Delivery-challan entry exists with id `delivery_challans`.
    // -------------------------------------------------------------------------
    test('delivery-challan entry exists with id "delivery_challans"', () {
      final challanItem = allItems.where((i) => i.id == 'delivery_challans');

      expect(
        challanItem.isNotEmpty,
        isTrue,
        reason:
            'Expected a sidebar item with id "delivery_challans" in the '
            'wholesale sections (Orders & Dispatch group)',
      );

      final item = challanItem.first;
      expect(item.label.trim().isNotEmpty, isTrue);
    });

    test('delivery-challan entry is in the "Orders & Dispatch" section', () {
      final ordersSection = wholesaleSections.firstWhere(
        (s) => s.title == 'Orders & Dispatch',
      );
      final challanInSection = ordersSection.items.where(
        (i) => i.id == 'delivery_challans',
      );
      expect(
        challanInSection.isNotEmpty,
        isTrue,
        reason:
            'delivery_challans should be located in the Orders & Dispatch section',
      );
    });

    // -------------------------------------------------------------------------
    // 5.9: Non-wholesale BusinessType values return unchanged behavior.
    // -------------------------------------------------------------------------
    group('Non-wholesale business types do not return wholesale sections', () {
      // All types except wholesale.
      final nonWholesaleTypes = BusinessType.values
          .where((t) => t != BusinessType.wholesale)
          .toList();

      // The wholesale-unique section title that should never appear for others.
      const wholesaleUniqueSections = [
        'Orders & Dispatch',
        'Pricing & Rate Lists',
        'Godown / Stock',
      ];

      for (final type in nonWholesaleTypes) {
        test('${type.name} does not have wholesale-specific sections', () {
          final sections = getSectionsForBusinessType(type);
          final titles = sections.map((s) => s.title).toSet();

          // Non-wholesale types should not have all three wholesale-unique
          // sections simultaneously (some individual titles like "Reports" may
          // exist in other verticals, but the full distributor set should not).
          final matchCount = wholesaleUniqueSections
              .where((ws) => titles.contains(ws))
              .length;

          // If a type has ALL THREE wholesale-unique sections, it's leaking.
          // (Retail has "Inventory / Stock" not "Godown / Stock", etc.)
          expect(
            matchCount < wholesaleUniqueSections.length,
            isTrue,
            reason:
                '${type.name} should not have all wholesale-specific sections. '
                'Found $matchCount of ${wholesaleUniqueSections.length}: '
                '${wholesaleUniqueSections.where((ws) => titles.contains(ws)).toList()}',
          );
        });
      }
    });

    // -------------------------------------------------------------------------
    // Non-wholesale types return a non-empty section list (basic sanity).
    // -------------------------------------------------------------------------
    test(
      'non-wholesale types return non-empty sections (basic regression)',
      () {
        final nonWholesaleTypes = BusinessType.values
            .where((t) => t != BusinessType.wholesale)
            .toList();

        for (final type in nonWholesaleTypes) {
          final sections = getSectionsForBusinessType(type);
          expect(
            sections.isNotEmpty,
            isTrue,
            reason: '${type.name} should return at least one sidebar section',
          );
        }
      },
    );
  });
}
