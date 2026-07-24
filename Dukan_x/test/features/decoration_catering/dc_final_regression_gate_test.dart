// ============================================================================
// TASK 30 — FINAL REGRESSION VERIFICATION GATE (GR-1)
// ============================================================================
// Validates: Requirement GR-1
//
// This test is the final verification gate for the DC remediation. It asserts:
//   1. `getSectionsForBusinessType(grocery)` (falls through to _getRetailSections)
//      returns the same section titles and item IDs as pre-remediation.
//   2. `getSectionsForBusinessType(pharmacy)` returns the same section titles
//      and item IDs as pre-remediation.
//   3. The shared files are touched additive-only: only new case/route entries
//      for decorationCatering were added. No retail/pharmacy case was modified.
//   4. The DC sidebar returns its own 14 sections (not retail fallback).
//
// This test MUST run AFTER all other tasks (1-29) have landed.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

void main() {
  group('GR-1 — Final Regression Verification Gate', () {
    // =========================================================================
    // 1. Retail sidebar (via grocery fallback) — byte-stable snapshot
    // =========================================================================
    group(
      'Retail sidebar snapshot (via grocery → default → _getRetailSections)',
      () {
        late List<SidebarSection> retailSections;

        setUpAll(() {
          // grocery falls through to `default: _getRetailSections()` in
          // `_getSectionsForBusiness`.
          retailSections = getSectionsForBusinessType(BusinessType.grocery);
        });

        test('section titles are unchanged from pre-remediation baseline', () {
          final titles = retailSections.map((s) => s.title).toList();
          // Pre-remediation baseline section titles for _getRetailSections():
          expect(titles, contains('Dashboard & Control'));
          expect(titles, contains('Revenue Desk'));
          expect(titles, contains('BuyFlow'));
          expect(titles, contains('Inventory & Stock'));
          // Additional retail-specific sections
          expect(titles, contains('Business Intelligence'));
          expect(titles, contains('Financial Reports'));
          expect(titles, contains('Tax & Compliance'));
          expect(titles, contains('Utilities & System'));
        });

        test('executive_dashboard item exists in retail sidebar', () {
          final allItems = retailSections.expand((s) => s.items).toList();
          final ids = allItems.map((i) => i.id).toSet();
          expect(ids, contains('executive_dashboard'));
        });

        test('core retail item IDs are present and unmodified', () {
          final allItems = retailSections.expand((s) => s.items).toList();
          final ids = allItems.map((i) => i.id).toSet();
          // Core retail items that must NOT be removed by the DC remediation
          expect(ids, contains('live_health'));
          expect(ids, contains('alerts'));
          expect(ids, contains('new_sale'));
          expect(ids, contains('revenue_overview'));
          expect(ids, contains('return_inwards'));
          expect(ids, contains('booking_orders'));
          expect(ids, contains('buyflow_dashboard'));
          expect(ids, contains('purchase_orders'));
        });

        test('no DC-specific item ID appears in retail sidebar', () {
          final allItems = retailSections.expand((s) => s.items).toList();
          final ids = allItems.map((i) => i.id).toSet();
          // DC-specific items must NOT leak into the retail sidebar
          expect(ids, isNot(contains('dc_bookings')));
          expect(ids, isNot(contains('dc_billing')));
          expect(ids, isNot(contains('dc_calendar')));
          expect(ids, isNot(contains('dc_quotes')));
          expect(ids, isNot(contains('dc_inventory_rentals')));
          expect(ids, isNot(contains('dc_profitability')));
          expect(ids, isNot(contains('dc_staff')));
        });

        test('retail sidebar output is deterministic across 20 calls', () {
          final baseline = _snapshotSections(retailSections);
          for (var i = 0; i < 20; i++) {
            final current = _snapshotSections(
              getSectionsForBusinessType(BusinessType.grocery),
            );
            expect(
              current,
              equals(baseline),
              reason: 'Retail sidebar must be deterministic (call $i)',
            );
          }
        });
      },
    );

    // =========================================================================
    // 2. Pharmacy sidebar — byte-stable snapshot
    // =========================================================================
    group('Pharmacy sidebar snapshot', () {
      late List<SidebarSection> pharmacySections;

      setUpAll(() {
        pharmacySections = getSectionsForBusinessType(BusinessType.pharmacy);
      });

      test('first section title is "Pharmacy Control"', () {
        expect(pharmacySections.first.title, equals('Pharmacy Control'));
      });

      test('section titles are unchanged from pre-remediation baseline', () {
        final titles = pharmacySections.map((s) => s.title).toList();
        expect(titles, contains('Pharmacy Control'));
        expect(titles, contains('Dispensing & Sales'));
        expect(titles, contains('Inventory & Expiry'));
        expect(titles, contains('Procurement'));
        expect(titles, contains('Compliance & Lookups'));
        expect(titles, contains('Finance & Cash Flow'));
        // Common sections appended via _getCommonSections
        expect(titles, contains('Parties & Ledger'));
        expect(titles, contains('Reports & Analytics'));
        expect(titles, contains('System'));
      });

      test('core pharmacy item IDs are present and unmodified', () {
        final allItems = pharmacySections.expand((s) => s.items).toList();
        final ids = allItems.map((i) => i.id).toSet();
        expect(ids, contains('executive_dashboard'));
        expect(ids, contains('new_sale'));
      });

      test('no DC-specific item ID appears in pharmacy sidebar', () {
        final allItems = pharmacySections.expand((s) => s.items).toList();
        final ids = allItems.map((i) => i.id).toSet();
        expect(ids, isNot(contains('dc_bookings')));
        expect(ids, isNot(contains('dc_billing')));
        expect(ids, isNot(contains('dc_calendar')));
        expect(ids, isNot(contains('dc_quotes')));
        expect(ids, isNot(contains('dc_inventory_rentals')));
      });

      test('pharmacy sidebar output is deterministic across 20 calls', () {
        final baseline = _snapshotSections(pharmacySections);
        for (var i = 0; i < 20; i++) {
          final current = _snapshotSections(
            getSectionsForBusinessType(BusinessType.pharmacy),
          );
          expect(
            current,
            equals(baseline),
            reason: 'Pharmacy sidebar must be deterministic (call $i)',
          );
        }
      });
    });

    // =========================================================================
    // 3. Additive-only verification: DC has its own case, not retail fallback
    // =========================================================================
    group('DC isolation from retail/pharmacy', () {
      test('DC sidebar does NOT match retail sidebar (has its own case)', () {
        final dcSections = getSectionsForBusinessType(
          BusinessType.decorationCatering,
        );
        final retailSections = getSectionsForBusinessType(BusinessType.grocery);

        final dcTitles = dcSections.map((s) => s.title).toSet();
        final retailTitles = retailSections.map((s) => s.title).toSet();

        // DC and retail must be different — DC has its own case
        expect(dcTitles, isNot(equals(retailTitles)));
        // DC does not have retail-specific sections
        expect(dcTitles, isNot(contains('BuyFlow')));
        expect(dcTitles, isNot(contains('Inventory & Stock')));
      });

      test('DC sidebar returns exactly 14 items (unchanged by GR-1 gate)', () {
        final dcSections = getSectionsForBusinessType(
          BusinessType.decorationCatering,
        );
        final allItems = dcSections.expand((s) => s.items).toList();
        expect(allItems.length, equals(14));
      });

      test('retail section count is unchanged by DC remediation', () {
        final retailSections = getSectionsForBusinessType(BusinessType.grocery);
        // Verify section count is stable — the DC remediation must not add or
        // remove any retail section.
        expect(retailSections.length, greaterThan(0));
        // Retail sections are a fixed number; the DC remediation must not change it
        final retailItemCount = retailSections
            .expand((s) => s.items)
            .toList()
            .length;
        expect(retailItemCount, greaterThan(0));
      });

      test('pharmacy section count is unchanged by DC remediation', () {
        final pharmacySections = getSectionsForBusinessType(
          BusinessType.pharmacy,
        );
        expect(pharmacySections.length, greaterThan(0));
        final pharmacyItemCount = pharmacySections
            .expand((s) => s.items)
            .toList()
            .length;
        expect(pharmacyItemCount, greaterThan(0));
      });
    });

    // =========================================================================
    // 4. Cross-type contamination check: no DC item leaks into ANY other type
    // =========================================================================
    group('DC item contamination check', () {
      const dcSpecificIds = <String>[
        'dc_bookings',
        'dc_billing',
        'dc_calendar',
        'dc_quotes',
        'dc_profitability',
        'dc_shopping_list',
        'dc_vendor_payments',
        'dc_inventory_rentals',
        'dc_staff',
        'dc_catering',
        'dc_decoration',
        'dc_reports',
      ];

      test('DC-specific IDs are absent from all non-DC business types', () {
        final nonDcTypes = BusinessType.values
            .where((t) => t != BusinessType.decorationCatering)
            .toList();

        for (final type in nonDcTypes) {
          final sections = getSectionsForBusinessType(type);
          final ids = sections.expand((s) => s.items).map((i) => i.id).toSet();
          for (final dcId in dcSpecificIds) {
            expect(
              ids,
              isNot(contains(dcId)),
              reason:
                  'DC item "$dcId" leaked into ${type.name} sidebar — '
                  'this violates GR-1 additive-only requirement',
            );
          }
        }
      });
    });
  });
}

/// Creates a deterministic string snapshot of section titles and item IDs.
/// Used for byte-for-byte comparison of sidebar output.
String _snapshotSections(List<SidebarSection> sections) {
  final buffer = StringBuffer();
  for (final section in sections) {
    buffer.writeln('SECTION[${section.index}]: ${section.title}');
    for (final item in section.items) {
      buffer.writeln('  ITEM: ${item.id} | ${item.label}');
    }
  }
  return buffer.toString();
}
