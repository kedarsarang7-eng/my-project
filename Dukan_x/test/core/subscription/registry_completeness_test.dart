// ============================================================================
// Task 2.3 — Registry completeness and new-type membership
// Spec: subscription-plan-tiers (Requirements 4.1, 4.3, 4.4, 4.5, 4.6, 4.7)
// ============================================================================
// Asserts that `businessCapabilityRegistry` is the confirmed source of truth
// for all 19 business types, and that each of the five Newly_Registered_Types
// (bookStore, jewellery, autoParts, decorationCatering, schoolErp) carries the
// vertical identifiers the design assigns it (design §"Newly registered
// registry entries", Req 4.3–4.7).
//
// Run: flutter test test/core/subscription/registry_completeness_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';

void main() {
  group('UT-REG-COMPLETE: registry holds all 19 business types (Req 4.1)', () {
    // The full target set: 14 pre-existing types + 5 Newly_Registered_Types.
    const expectedTypes = <String>{
      'grocery',
      'pharmacy',
      'restaurant',
      'clothing',
      'electronics',
      'mobileShop',
      'computerShop',
      'hardware',
      'service',
      'wholesale',
      'petrolPump',
      'vegetablesBroker',
      'clinic',
      'other',
      // Newly_Registered_Types (Req 4.1)
      'bookStore',
      'jewellery',
      'autoParts',
      'decorationCatering',
      'schoolErp',
    };

    test('contains exactly the 19 expected business types', () {
      expect(businessCapabilityRegistry.keys.toSet(), equals(expectedTypes));
      expect(businessCapabilityRegistry.length, equals(19));
    });

    test('every business type maps to a non-empty capability set', () {
      businessCapabilityRegistry.forEach((type, capabilities) {
        expect(
          capabilities,
          isNotEmpty,
          reason: '$type must have at least one registered capability',
        );
      });
    });

    test('the five Newly_Registered_Types are all present', () {
      const newTypes = [
        'bookStore',
        'jewellery',
        'autoParts',
        'decorationCatering',
        'schoolErp',
      ];
      for (final type in newTypes) {
        expect(
          businessCapabilityRegistry.containsKey(type),
          isTrue,
          reason: '$type must be a confirmed registry entry (Req 4.1)',
        );
      }
    });
  });

  group('UT-REG-NEWTYPE: Newly_Registered_Type vertical identifiers '
      '(Req 4.3–4.7)', () {
    // Each new type must contain at least the vertical/required identifiers the
    // design assigns it. We assert containsAll (superset) so the standard
    // product/inventory/invoice/purchase members are free to also be present.
    const requiredByType = <String, Set<BusinessCapability>>{
      // Req 4.3 — bookStore: useISBN, usePublisherReturns + standard product,
      // inventory, invoice, purchase capabilities.
      'bookStore': {
        BusinessCapability.useISBN,
        BusinessCapability.usePublisherReturns,
        // standard invoice (Billing_Core)
        BusinessCapability.useInvoiceCreate,
        BusinessCapability.useInvoiceList,
        BusinessCapability.useInvoiceSearch,
        // standard purchase
        BusinessCapability.usePurchaseOrder,
        BusinessCapability.useStockEntry,
        BusinessCapability.useSupplierBill,
      },
      // Req 4.4 — jewellery: useLoyaltyPoints + standard product, inventory,
      // invoice capabilities.
      'jewellery': {
        BusinessCapability.useLoyaltyPoints,
        BusinessCapability.useInvoiceCreate,
        BusinessCapability.useInvoiceList,
        BusinessCapability.useInvoiceSearch,
      },
      // Req 4.5 — autoParts: useJobSheets, useRepairStatus, useWarranty +
      // standard product, inventory, invoice, purchase capabilities.
      'autoParts': {
        BusinessCapability.useJobSheets,
        BusinessCapability.useRepairStatus,
        BusinessCapability.useWarranty,
        BusinessCapability.useInvoiceCreate,
        BusinessCapability.useInvoiceList,
        BusinessCapability.useInvoiceSearch,
        BusinessCapability.usePurchaseOrder,
        BusinessCapability.useStockEntry,
        BusinessCapability.useSupplierBill,
      },
      // Req 4.6 — decorationCatering: the eight event/catering vertical
      // identifiers + invoice capabilities.
      'decorationCatering': {
        BusinessCapability.useDecorationThemes,
        BusinessCapability.useCateringMenu,
        BusinessCapability.useCateringKitchen,
        BusinessCapability.useVenueManagement,
        BusinessCapability.useEventBooking,
        BusinessCapability.useEventInventory,
        BusinessCapability.useEventStaffAllocation,
        BusinessCapability.useEventReports,
        BusinessCapability.useInvoiceCreate,
        BusinessCapability.useInvoiceList,
        BusinessCapability.useInvoiceSearch,
      },
      // Req 4.7 — schoolErp: the ten school-ERP vertical identifiers + invoice
      // capabilities.
      'schoolErp': {
        BusinessCapability.useStudentRegistry,
        BusinessCapability.useFeeCollection,
        BusinessCapability.useAttendanceTracking,
        BusinessCapability.useTimetable,
        BusinessCapability.useTestResults,
        BusinessCapability.useCertificates,
        BusinessCapability.useScholarshipDiscount,
        BusinessCapability.useParentNotifications,
        BusinessCapability.useCourseMaterial,
        BusinessCapability.useDemoClasses,
        BusinessCapability.useInvoiceCreate,
        BusinessCapability.useInvoiceList,
        BusinessCapability.useInvoiceSearch,
      },
    };

    requiredByType.forEach((type, required) {
      test('$type registry entry contains all its required identifiers', () {
        final actual = businessCapabilityRegistry[type];
        expect(actual, isNotNull, reason: '$type must be registered');
        expect(
          actual,
          containsAll(required),
          reason:
              '$type is missing one or more required identifiers: '
              '${required.difference(actual ?? {}).map((c) => c.name)}',
        );
      });
    });

    test('decorationCatering and schoolErp are service-only (no product or '
        'inventory capabilities)', () {
      const productInventory = <BusinessCapability>{
        BusinessCapability.useProductAdd,
        BusinessCapability.useProductName,
        BusinessCapability.useProductSalePrice,
        BusinessCapability.useProductStockQty,
        BusinessCapability.useProductUnit,
        BusinessCapability.useProductTax,
        BusinessCapability.useProductCategory,
        BusinessCapability.useInventoryList,
        BusinessCapability.useVisibleStock,
        BusinessCapability.useInventorySearch,
        BusinessCapability.useInventoryExport,
        BusinessCapability.useDeadStock,
      };
      for (final type in ['decorationCatering', 'schoolErp']) {
        final caps = businessCapabilityRegistry[type]!;
        expect(
          caps.intersection(productInventory),
          isEmpty,
          reason:
              '$type is a Service_Only_Type and must not carry product '
              'or inventory capabilities',
        );
      }
    });
  });
}
