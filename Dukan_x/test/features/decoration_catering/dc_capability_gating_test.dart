// ============================================================================
// Task 5 — Capability-gating regression-lock test
// Feature: decoration-catering-remediation
// **Validates: Requirement 2.4**
// ============================================================================
//
// Regression-lock only (Status: DONE per design.md) — this test does not
// change production code. It locks in the audit's resolved capability-bypass
// concern: a DcTenant must never be granted a product/inventory capability,
// and the DC sidebar must never surface a BuyFlow, Inventory & Stock, or
// Tax & Compliance section.
//
// Asserts:
//   1. `businessCapabilityRegistry['decorationCatering']` does not contain
//      any product/inventory capability (e.g. useProductAdd,
//      useInventoryList, useStockEntry) (Requirement 2.4 AC1).
//   2. `getSectionsForBusinessType(BusinessType.decorationCatering)` never
//      returns a section titled "BuyFlow", "Inventory & Stock", or
//      "Tax & Compliance" — reusing Task 1's (Requirement 1.1 AC3) sidebar-
//      section assertion pattern (Requirement 2.4 AC2).
//   3. This test itself is the regression lock named by AC3: it will fail if
//      a future change grants DC an inventory/product capability or
//      reintroduces a forbidden sidebar section, without a deliberate,
//      accompanying update to this test.
//
// Run: flutter test test/features/decoration_catering/dc_capability_gating_test.dart
// ============================================================================
library;

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Product/inventory capabilities that a Service_Only_Type such as
/// `decorationCatering` must never be granted (Requirement 2.4 AC1).
const Set<BusinessCapability> kProductInventoryCapabilities =
    <BusinessCapability>{
      BusinessCapability.useProductAdd,
      BusinessCapability.useProductName,
      BusinessCapability.useProductSalePrice,
      BusinessCapability.useProductStockQty,
      BusinessCapability.useProductUnit,
      BusinessCapability.useProductTax,
      BusinessCapability.useProductCategory,
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useDeadStock,
      BusinessCapability.useInventorySearch,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useStockEntry,
    };

/// Reused from Task 1's DcReachabilityGateTest (Requirement 1.1 AC3).
const List<String> kForbiddenSectionTitles = <String>[
  'BuyFlow',
  'Inventory & Stock',
  'Tax & Compliance',
];

void main() {
  group('DcCapabilityGatingTest — Requirement 2.4', () {
    // -------------------------------------------------------------------
    // AC1: no product/inventory capability granted to decorationCatering
    // -------------------------------------------------------------------
    test("businessCapabilityRegistry['decorationCatering'] does not grant any "
        'product/inventory capability (AC1)', () {
      final granted = businessCapabilityRegistry['decorationCatering'];

      expect(
        granted,
        isNotNull,
        reason:
            "decorationCatering must be a registered entry in "
            'businessCapabilityRegistry.',
      );

      final leaked = granted!.intersection(kProductInventoryCapabilities);

      expect(
        leaked,
        isEmpty,
        reason:
            'Requirement 2.4 AC1: decorationCatering must not be granted '
            'any product/inventory capability — found: '
            '${leaked.map((c) => c.name)}. This is the capability-bypass '
            'regression this test locks in against.',
      );

      // Spot-check the three example capabilities named explicitly in
      // Requirement 2.4 AC1.
      expect(
        granted.contains(BusinessCapability.useProductAdd),
        isFalse,
        reason: 'decorationCatering must not be granted useProductAdd.',
      );
      expect(
        granted.contains(BusinessCapability.useInventoryList),
        isFalse,
        reason: 'decorationCatering must not be granted useInventoryList.',
      );
      expect(
        granted.contains(BusinessCapability.useStockEntry),
        isFalse,
        reason: 'decorationCatering must not be granted useStockEntry.',
      );
    });

    // -------------------------------------------------------------------
    // AC2: no BuyFlow / Inventory & Stock / Tax & Compliance sidebar
    // section for a DcTenant — reuses Task 1's sidebar-section assertion.
    // -------------------------------------------------------------------
    test('no BuyFlow/Inventory & Stock/Tax & Compliance section appears for a '
        'DcTenant (AC2, reusing Requirement 1.1 AC3 assertion)', () {
      final sections = getSectionsForBusinessType(
        BusinessType.decorationCatering,
      );
      final titles = sections.map((s) => s.title).toSet();

      for (final forbidden in kForbiddenSectionTitles) {
        expect(
          titles.contains(forbidden),
          isFalse,
          reason:
              'Requirement 2.4 AC2: DcTenant sidebar must never include a '
              '"$forbidden" section — found it in $titles.',
        );
      }
    });
  });
}
