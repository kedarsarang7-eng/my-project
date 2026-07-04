// ============================================================================
// SIDEBAR BASELINE FIXTURE — Electronics & MobileShop
// ============================================================================
// Task 5.1: Captures the pre-change sidebar configuration for electronics and
// mobileShop business types. This baseline is used to verify (task 5.8,
// Property 10) that changes to computerShop do NOT affect these verticals.
//
// Compared attributes: item count, item order, item labels, item icons,
// destination routes/ids.
//
// Requirements: 6.1, 6.2
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

// ---------------------------------------------------------------------------
// Baseline data structures
// ---------------------------------------------------------------------------

/// A lightweight snapshot of a single sidebar menu item for comparison.
class _ItemSnapshot {
  final String id;
  final String label;
  final int iconCodePoint;

  const _ItemSnapshot({
    required this.id,
    required this.label,
    required this.iconCodePoint,
  });
}

/// A lightweight snapshot of a sidebar section for comparison.
class _SectionSnapshot {
  final int index;
  final String title;
  final int iconCodePoint;
  final List<_ItemSnapshot> items;

  const _SectionSnapshot({
    required this.index,
    required this.title,
    required this.iconCodePoint,
    required this.items,
  });
}

// ---------------------------------------------------------------------------
// Baseline: Electronics
// ---------------------------------------------------------------------------

/// The expected baseline for `BusinessType.electronics`.
///
/// Section 0: "Devices & Service" (5 items)
///   - imei_tracking / Serial / IMEI Tracking / Icons.qr_code_scanner_outlined
///   - warranty / Warranty Register / Icons.verified_user_outlined
///   - service_jobs / Service / Repair Jobs / Icons.build_circle_outlined
///   - return_inwards / Returns (with serial) / Icons.assignment_return_outlined
///   - serial_stock / Serial-wise Stock / Icons.inventory_2_outlined
///
/// Sections 1–3: Common sections (Parties & Ledger, Reports & Analytics, System)
final List<_SectionSnapshot> _electronicsBaseline = [
  _SectionSnapshot(
    index: 0,
    title: 'Devices & Service',
    iconCodePoint: Icons.devices_other_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'imei_tracking',
        label: 'Serial / IMEI Tracking',
        iconCodePoint: Icons.qr_code_scanner_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'warranty',
        label: 'Warranty Register',
        iconCodePoint: Icons.verified_user_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'service_jobs',
        label: 'Service / Repair Jobs',
        iconCodePoint: Icons.build_circle_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'return_inwards',
        label: 'Returns (with serial)',
        iconCodePoint: Icons.assignment_return_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'serial_stock',
        label: 'Serial-wise Stock',
        iconCodePoint: Icons.inventory_2_outlined.codePoint,
      ),
    ],
  ),
  // Common section 1: Parties & Ledger
  _SectionSnapshot(
    index: 1,
    title: 'Parties & Ledger',
    iconCodePoint: Icons.people_alt_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'customers',
        label: 'Customers',
        iconCodePoint: Icons.person_outline.codePoint,
      ),
      _ItemSnapshot(
        id: 'suppliers',
        label: 'Suppliers',
        iconCodePoint: Icons.storefront_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'party_ledger',
        label: 'Party Ledger',
        iconCodePoint: Icons.account_balance_wallet_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'outstanding',
        label: 'Outstanding',
        iconCodePoint: Icons.pending_actions_outlined.codePoint,
      ),
    ],
  ),
  // Common section 2: Reports & Analytics
  _SectionSnapshot(
    index: 2,
    title: 'Reports & Analytics',
    iconCodePoint: Icons.insights_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'analytics_hub',
        label: 'Analytics Hub',
        iconCodePoint: Icons.hub_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'product_performance',
        label: 'Product Performance',
        iconCodePoint: Icons.auto_graph_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'invoice_margin',
        label: 'Profit & Loss',
        iconCodePoint: Icons.money_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'gstr1',
        label: 'GST Reports',
        iconCodePoint: Icons.receipt_outlined.codePoint,
      ),
    ],
  ),
  // Common section 3: System
  _SectionSnapshot(
    index: 3,
    title: 'System',
    iconCodePoint: Icons.settings_applications_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'print_settings',
        label: 'Printing',
        iconCodePoint: Icons.print_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'backup',
        label: 'Backup',
        iconCodePoint: Icons.backup_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'error_logs',
        label: 'System Logs',
        iconCodePoint: Icons.error_outline.codePoint,
      ),
      _ItemSnapshot(
        id: 'device_settings',
        label: 'Settings',
        iconCodePoint: Icons.devices_outlined.codePoint,
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Baseline: MobileShop
// ---------------------------------------------------------------------------

/// The expected baseline for `BusinessType.mobileShop`.
///
/// Section 0: "Service & Repairs" (5 items)
///   - service_jobs / Service Jobs / Icons.build_circle_outlined
///   - exchanges / Exchanges / Icons.swap_horiz_outlined
///   - imei_tracking / IMEI Tracking / Icons.qr_code_scanner_outlined
///   - warranty / Warranty / Icons.verified_user_outlined
///   - second_hand_intake / Second-Hand Intake / Icons.phone_android_outlined
///
/// Sections 1–3: Common sections (Parties & Ledger, Reports & Analytics, System)
final List<_SectionSnapshot> _mobileShopBaseline = [
  _SectionSnapshot(
    index: 0,
    title: 'Service & Repairs',
    iconCodePoint: Icons.build_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'service_jobs',
        label: 'Service Jobs',
        iconCodePoint: Icons.build_circle_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'exchanges',
        label: 'Exchanges',
        iconCodePoint: Icons.swap_horiz_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'imei_tracking',
        label: 'IMEI Tracking',
        iconCodePoint: Icons.qr_code_scanner_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'warranty',
        label: 'Warranty',
        iconCodePoint: Icons.verified_user_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'second_hand_intake',
        label: 'Second-Hand Intake',
        iconCodePoint: Icons.phone_android_outlined.codePoint,
      ),
    ],
  ),
  // Common section 1: Parties & Ledger
  _SectionSnapshot(
    index: 1,
    title: 'Parties & Ledger',
    iconCodePoint: Icons.people_alt_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'customers',
        label: 'Customers',
        iconCodePoint: Icons.person_outline.codePoint,
      ),
      _ItemSnapshot(
        id: 'suppliers',
        label: 'Suppliers',
        iconCodePoint: Icons.storefront_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'party_ledger',
        label: 'Party Ledger',
        iconCodePoint: Icons.account_balance_wallet_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'outstanding',
        label: 'Outstanding',
        iconCodePoint: Icons.pending_actions_outlined.codePoint,
      ),
    ],
  ),
  // Common section 2: Reports & Analytics
  _SectionSnapshot(
    index: 2,
    title: 'Reports & Analytics',
    iconCodePoint: Icons.insights_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'analytics_hub',
        label: 'Analytics Hub',
        iconCodePoint: Icons.hub_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'product_performance',
        label: 'Product Performance',
        iconCodePoint: Icons.auto_graph_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'invoice_margin',
        label: 'Profit & Loss',
        iconCodePoint: Icons.money_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'gstr1',
        label: 'GST Reports',
        iconCodePoint: Icons.receipt_outlined.codePoint,
      ),
    ],
  ),
  // Common section 3: System
  _SectionSnapshot(
    index: 3,
    title: 'System',
    iconCodePoint: Icons.settings_applications_rounded.codePoint,
    items: [
      _ItemSnapshot(
        id: 'print_settings',
        label: 'Printing',
        iconCodePoint: Icons.print_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'backup',
        label: 'Backup',
        iconCodePoint: Icons.backup_outlined.codePoint,
      ),
      _ItemSnapshot(
        id: 'error_logs',
        label: 'System Logs',
        iconCodePoint: Icons.error_outline.codePoint,
      ),
      _ItemSnapshot(
        id: 'device_settings',
        label: 'Settings',
        iconCodePoint: Icons.devices_outlined.codePoint,
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Asserts that the actual sections match the expected baseline on all
/// compared attributes: count, order, labels, icons, and ids.
void _assertSectionsMatchBaseline(
  List<SidebarSection> actual,
  List<_SectionSnapshot> expected,
  String businessTypeName,
) {
  // Section count
  expect(
    actual.length,
    expected.length,
    reason: '$businessTypeName: section count mismatch',
  );

  for (int s = 0; s < expected.length; s++) {
    final actualSection = actual[s];
    final expectedSection = expected[s];

    // Section-level attributes
    expect(
      actualSection.index,
      expectedSection.index,
      reason: '$businessTypeName section[$s]: index mismatch',
    );
    expect(
      actualSection.title,
      expectedSection.title,
      reason: '$businessTypeName section[$s]: title mismatch',
    );
    expect(
      actualSection.icon.codePoint,
      expectedSection.iconCodePoint,
      reason: '$businessTypeName section[$s]: icon mismatch',
    );

    // Item count within section
    expect(
      actualSection.items.length,
      expectedSection.items.length,
      reason:
          '$businessTypeName section[$s] "${expectedSection.title}": item count mismatch',
    );

    // Item-level: order, id, label, icon
    for (int i = 0; i < expectedSection.items.length; i++) {
      final actualItem = actualSection.items[i];
      final expectedItem = expectedSection.items[i];

      expect(
        actualItem.id,
        expectedItem.id,
        reason:
            '$businessTypeName section[$s] item[$i]: id mismatch '
            '(expected "${expectedItem.id}", got "${actualItem.id}")',
      );
      expect(
        actualItem.label,
        expectedItem.label,
        reason:
            '$businessTypeName section[$s] item[$i] "${expectedItem.id}": '
            'label mismatch',
      );
      expect(
        actualItem.icon.codePoint,
        expectedItem.iconCodePoint,
        reason:
            '$businessTypeName section[$s] item[$i] "${expectedItem.id}": '
            'icon mismatch',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Sidebar Baseline Fixture — Regression Isolation (Reqs 6.1, 6.2)', () {
    test(
      'electronics sidebar matches baseline on count, order, labels, icons, ids',
      () {
        final sections = getSectionsForBusinessType(BusinessType.electronics);
        _assertSectionsMatchBaseline(
          sections,
          _electronicsBaseline,
          'electronics',
        );
      },
    );

    test(
      'mobileShop sidebar matches baseline on count, order, labels, icons, ids',
      () {
        final sections = getSectionsForBusinessType(BusinessType.mobileShop);
        _assertSectionsMatchBaseline(
          sections,
          _mobileShopBaseline,
          'mobileShop',
        );
      },
    );

    test('electronics total item count is 17 (5 dedicated + 12 common)', () {
      final sections = getSectionsForBusinessType(BusinessType.electronics);
      final totalItems = sections.fold<int>(
        0,
        (sum, s) => sum + s.items.length,
      );
      expect(totalItems, 17);
    });

    test('mobileShop total item count is 17 (5 dedicated + 12 common)', () {
      final sections = getSectionsForBusinessType(BusinessType.mobileShop);
      final totalItems = sections.fold<int>(
        0,
        (sum, s) => sum + s.items.length,
      );
      expect(totalItems, 17);
    });

    test('electronics section count is 4 (1 dedicated + 3 common)', () {
      final sections = getSectionsForBusinessType(BusinessType.electronics);
      expect(sections.length, 4);
    });

    test('mobileShop section count is 4 (1 dedicated + 3 common)', () {
      final sections = getSectionsForBusinessType(BusinessType.mobileShop);
      expect(sections.length, 4);
    });

    test('electronics dedicated section ids are in expected order', () {
      final sections = getSectionsForBusinessType(BusinessType.electronics);
      final dedicatedIds = sections.first.items.map((i) => i.id).toList();
      expect(dedicatedIds, [
        'imei_tracking',
        'warranty',
        'service_jobs',
        'return_inwards',
        'serial_stock',
      ]);
    });

    test('mobileShop dedicated section ids are in expected order', () {
      final sections = getSectionsForBusinessType(BusinessType.mobileShop);
      final dedicatedIds = sections.first.items.map((i) => i.id).toList();
      expect(dedicatedIds, [
        'service_jobs',
        'exchanges',
        'imei_tracking',
        'warranty',
        'second_hand_intake',
      ]);
    });
  });
}
