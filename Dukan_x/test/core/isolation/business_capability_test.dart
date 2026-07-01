// =============================================================================
// BUSINESS CAPABILITY REGISTRY — ISOLATION VALIDATION TESTS
// =============================================================================
// Validates the Hard Isolation rule:
//   "If a capability is not listed for a BusinessType, it is STRICTLY FORBIDDEN."
//
// Coverage:
//   • Every capability that MUST be enabled per BUSINESS_TYPE_FEATURES_LIST.md
//   • Key cross-type isolation assertions (wrong type must not access)
//   • Unknown / unregistered type → strict deny
//   • SecurityException enforcement
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';

// Helper: assert a capability is accessible for a given type
void _allowed(String type, BusinessCapability cap) {
  expect(
    FeatureResolver.canAccess(type, cap),
    isTrue,
    reason: '[$type] should have [${cap.name}]',
  );
}

// Helper: assert a capability is denied for a given type
void _denied(String type, BusinessCapability cap) {
  expect(
    FeatureResolver.canAccess(type, cap),
    isFalse,
    reason: '[$type] must NOT have [${cap.name}]',
  );
}

void main() {
  // ===========================================================================
  // 1. GROCERY
  // ===========================================================================
  group('grocery', () {
    const t = 'grocery';

    test('product management enabled', () {
      _allowed(t, BusinessCapability.useProductAdd);
      _allowed(t, BusinessCapability.useProductName);
      _allowed(t, BusinessCapability.useProductSalePrice);
      _allowed(t, BusinessCapability.useProductStockQty);
      _allowed(t, BusinessCapability.useProductUnit);
      _allowed(t, BusinessCapability.useProductTax);
      _allowed(t, BusinessCapability.useProductCategory);
    });

    test('inventory enabled', () {
      _allowed(t, BusinessCapability.useInventoryList);
      _allowed(t, BusinessCapability.useVisibleStock);
      _allowed(t, BusinessCapability.useDeadStock);
      _allowed(t, BusinessCapability.useInventorySearch);
    });

    test('invoice enabled', () {
      _allowed(t, BusinessCapability.useInvoiceList);
      _allowed(t, BusinessCapability.useInvoiceSearch);
      _allowed(t, BusinessCapability.useInvoiceCreate);
    });

    test('alerts enabled', () {
      _allowed(t, BusinessCapability.useLowStockAlert);
      _allowed(t, BusinessCapability.useGeneralAlerts);
      _allowed(t, BusinessCapability.useDailySnapshot);
      _allowed(t, BusinessCapability.useRevenueOverview);
    });

    test('purchase flow enabled', () {
      _allowed(t, BusinessCapability.usePurchaseOrder);
      _allowed(t, BusinessCapability.useStockEntry);
      _allowed(t, BusinessCapability.useSupplierBill);
    });

    test('specialized: barcode, OCR, batch/expiry, voice enabled', () {
      _allowed(t, BusinessCapability.useBarcodeScanner);
      _allowed(t, BusinessCapability.useScanOCR);
      _allowed(t, BusinessCapability.useBatchExpiry);
      _allowed(t, BusinessCapability.useVoiceInput);
      _allowed(t, BusinessCapability.useStockManagement);
    });

    test('restaurant features strictly denied', () {
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.useTableManagement);
      _denied(t, BusinessCapability.useWaiterLinking);
      _denied(t, BusinessCapability.useKitchenDisplay);
    });

    test('academic features strictly denied', () {
      _denied(t, BusinessCapability.useStudentRegistry);
      _denied(t, BusinessCapability.useBatchManagement);
      _denied(t, BusinessCapability.useFeeCollection);
    });

    test('export CSV denied', () {
      _denied(t, BusinessCapability.useInventoryExport);
    });
  });

  // ===========================================================================
  // 2. PHARMACY
  // ===========================================================================
  group('pharmacy', () {
    const t = 'pharmacy';

    test('all product management enabled', () {
      _allowed(t, BusinessCapability.useProductAdd);
      _allowed(t, BusinessCapability.useProductName);
      _allowed(t, BusinessCapability.useProductSalePrice);
      _allowed(t, BusinessCapability.useProductStockQty);
      _allowed(t, BusinessCapability.useProductUnit);
      _allowed(t, BusinessCapability.useProductTax);
      _allowed(t, BusinessCapability.useProductCategory);
    });

    test('pharmacy-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.usePrescription);
      _allowed(t, BusinessCapability.useDoctorLinking);
      _allowed(t, BusinessCapability.usePatientRegistry);
      _allowed(t, BusinessCapability.useDrugSchedule);
      _allowed(t, BusinessCapability.useSaltSearch);
      _allowed(t, BusinessCapability.useBatchExpiry);
      _allowed(t, BusinessCapability.useSalesReturn);
      _allowed(t, BusinessCapability.useStockReversal);
      _allowed(t, BusinessCapability.usePurchaseRegister);
    });

    test('restaurant/clothing features denied', () {
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.useVariants);
      _denied(t, BusinessCapability.useIMEI);
    });
  });

  // ===========================================================================
  // 3. RESTAURANT
  // ===========================================================================
  group('restaurant', () {
    const t = 'restaurant';

    test('restaurant-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useKOT);
      _allowed(t, BusinessCapability.useTableManagement);
      _allowed(t, BusinessCapability.useWaiterLinking);
      _allowed(t, BusinessCapability.useKitchenDisplay);
    });

    test('core invoice enabled', () {
      _allowed(t, BusinessCapability.useInvoiceList);
      _allowed(t, BusinessCapability.useInvoiceSearch);
      _allowed(t, BusinessCapability.useInvoiceCreate);
    });

    test('pharmacy / IMEI features denied', () {
      _denied(t, BusinessCapability.usePrescription);
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useVariants);
      _denied(t, BusinessCapability.useInventoryExport);
    });

    test('proforma and dispatch denied', () {
      _denied(t, BusinessCapability.useProformaInvoice);
      _denied(t, BusinessCapability.useDispatchNote);
    });
  });

  // ===========================================================================
  // 4. CLOTHING
  // ===========================================================================
  group('clothing', () {
    const t = 'clothing';

    test('clothing-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useVariants);
      _allowed(t, BusinessCapability.useTailoringNotes);
      _allowed(t, BusinessCapability.useBarcodeScanner);
      _allowed(t, BusinessCapability.useScanOCR);
    });

    test('IMEI / prescription / KOT denied', () {
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.usePrescription);
      _denied(t, BusinessCapability.useKOT);
    });

    test('low stock alert and general alerts denied', () {
      _denied(t, BusinessCapability.useLowStockAlert);
      _denied(t, BusinessCapability.useGeneralAlerts);
    });
  });

  // ===========================================================================
  // 5. ELECTRONICS
  // ===========================================================================
  group('electronics', () {
    const t = 'electronics';

    test('IMEI and warranty enabled', () {
      _allowed(t, BusinessCapability.useIMEI);
      _allowed(t, BusinessCapability.useWarranty);
    });

    test('low stock alert enabled', () {
      _allowed(t, BusinessCapability.useLowStockAlert);
    });

    test('buyback / exchange / KOT denied', () {
      _denied(t, BusinessCapability.useBuyback);
      _denied(t, BusinessCapability.useExchange);
      _denied(t, BusinessCapability.useKOT);
    });
  });

  // ===========================================================================
  // 6. MOBILE SHOP
  // ===========================================================================
  group('mobileShop', () {
    const t = 'mobileShop';

    test('mobile-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useIMEI);
      _allowed(t, BusinessCapability.useWarranty);
      _allowed(t, BusinessCapability.useBuyback);
      _allowed(t, BusinessCapability.useExchange);
      _allowed(t, BusinessCapability.useJobSheets);
      _allowed(t, BusinessCapability.useRepairStatus);
    });

    test('prescription / KOT denied', () {
      _denied(t, BusinessCapability.usePrescription);
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.useTableManagement);
    });
  });

  // ===========================================================================
  // 7. COMPUTER SHOP
  // ===========================================================================
  group('computerShop', () {
    const t = 'computerShop';

    test('computer-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useIMEI);
      _allowed(t, BusinessCapability.useWarranty);
      _allowed(t, BusinessCapability.useJobSheets);
      _allowed(t, BusinessCapability.useRepairStatus);
      _allowed(t, BusinessCapability.useMultiUnit);
    });

    test('buyback / exchange denied (computer shop vs mobile shop)', () {
      _denied(t, BusinessCapability.useBuyback);
      _denied(t, BusinessCapability.useExchange);
    });
  });

  // ===========================================================================
  // 8. HARDWARE
  // ===========================================================================
  group('hardware', () {
    const t = 'hardware';

    test('hardware-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useDimensions);
      _allowed(t, BusinessCapability.useLooseQuantities);
      _allowed(t, BusinessCapability.useTransportDetails);
      _allowed(t, BusinessCapability.useBarcodeScanner);
    });

    test('IMEI / KOT / prescription denied', () {
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.usePrescription);
    });
  });

  // ===========================================================================
  // 9. SERVICE
  // ===========================================================================
  group('service', () {
    const t = 'service';

    test('service-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useJobSheets);
      _allowed(t, BusinessCapability.useServiceStatus);
      _allowed(t, BusinessCapability.useLaborCharges);
      _allowed(t, BusinessCapability.useAppointments);
      _allowed(t, BusinessCapability.useInvoiceList);
      _allowed(t, BusinessCapability.useInvoiceCreate);
    });

    test('ALL product management denied', () {
      _denied(t, BusinessCapability.useProductAdd);
      _denied(t, BusinessCapability.useProductName);
      _denied(t, BusinessCapability.useProductSalePrice);
      _denied(t, BusinessCapability.useProductStockQty);
      _denied(t, BusinessCapability.useProductUnit);
      _denied(t, BusinessCapability.useProductTax);
      _denied(t, BusinessCapability.useProductCategory);
    });

    test('ALL inventory denied', () {
      _denied(t, BusinessCapability.useInventoryList);
      _denied(t, BusinessCapability.useVisibleStock);
      _denied(t, BusinessCapability.useDeadStock);
      _denied(t, BusinessCapability.useInventorySearch);
    });

    test('purchase flow denied', () {
      _denied(t, BusinessCapability.usePurchaseOrder);
      _denied(t, BusinessCapability.useStockEntry);
      _denied(t, BusinessCapability.useSupplierBill);
    });

    test('low stock alert denied', () {
      _denied(t, BusinessCapability.useLowStockAlert);
    });
  });

  // ===========================================================================
  // 10. WHOLESALE
  // ===========================================================================
  group('wholesale', () {
    const t = 'wholesale';

    test('wholesale-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useInventoryExport);
      _allowed(t, BusinessCapability.useProformaInvoice);
      _allowed(t, BusinessCapability.useDispatchNote);
      _allowed(t, BusinessCapability.useSalesReturn);
      _allowed(t, BusinessCapability.useStockReversal);
      _allowed(t, BusinessCapability.usePurchaseRegister);
      _allowed(t, BusinessCapability.useMultiUnit);
      _allowed(t, BusinessCapability.useCreditManagement);
      _allowed(t, BusinessCapability.useCreditLimit);
      _allowed(t, BusinessCapability.useTransportDetails);
    });

    test('full alerts enabled', () {
      _allowed(t, BusinessCapability.useLowStockAlert);
      _allowed(t, BusinessCapability.useGeneralAlerts);
      _allowed(t, BusinessCapability.useDailySnapshot);
      _allowed(t, BusinessCapability.useRevenueOverview);
    });

    test('KOT / IMEI / prescription denied', () {
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.usePrescription);
    });
  });

  // ===========================================================================
  // 11. PETROL PUMP
  // ===========================================================================
  group('petrolPump', () {
    const t = 'petrolPump';

    test('petrol-pump-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useFuelManagement);
      _allowed(t, BusinessCapability.usePumpReadings);
      _allowed(t, BusinessCapability.useShiftManagement);
      _allowed(t, BusinessCapability.useVehicleDetails);
      _allowed(t, BusinessCapability.useTankerEntry);
    });

    test('dead stock and export denied', () {
      _denied(t, BusinessCapability.useDeadStock);
      _denied(t, BusinessCapability.useInventoryExport);
    });

    test('proforma, dispatch, purchase register denied', () {
      _denied(t, BusinessCapability.useProformaInvoice);
      _denied(t, BusinessCapability.useDispatchNote);
      _denied(t, BusinessCapability.useStockReversal);
    });
  });

  // ===========================================================================
  // 12. VEGETABLES BROKER
  // ===========================================================================
  group('vegetablesBroker', () {
    const t = 'vegetablesBroker';

    test('broker-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useCommission);
      _allowed(t, BusinessCapability.useCrateManagement);
      _allowed(t, BusinessCapability.useFarmerLinking);
      _allowed(t, BusinessCapability.useDailyRates);
      _allowed(t, BusinessCapability.useCreditManagement);
    });

    test('product tax denied (mandi typically no tax)', () {
      _denied(t, BusinessCapability.useProductTax);
    });

    test('IMEI / KOT / prescription denied', () {
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.usePrescription);
    });
  });

  // ===========================================================================
  // 13. CLINIC
  // ===========================================================================
  group('clinic', () {
    const t = 'clinic';

    test('clinic-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useAppointments);
      _allowed(t, BusinessCapability.useConsultationBilling);
      _allowed(t, BusinessCapability.usePatientRegistry);
      _allowed(t, BusinessCapability.usePrescription);
      _allowed(t, BusinessCapability.useDoctorLinking);
      _allowed(t, BusinessCapability.useInvoiceList);
      _allowed(t, BusinessCapability.useInvoiceCreate);
    });

    test('ALL product management denied', () {
      _denied(t, BusinessCapability.useProductAdd);
      _denied(t, BusinessCapability.useProductName);
      _denied(t, BusinessCapability.useProductSalePrice);
      _denied(t, BusinessCapability.useProductStockQty);
    });

    test('ALL inventory denied', () {
      _denied(t, BusinessCapability.useInventoryList);
      _denied(t, BusinessCapability.useVisibleStock);
      _denied(t, BusinessCapability.useInventorySearch);
    });

    test('ALL purchase flow denied', () {
      _denied(t, BusinessCapability.usePurchaseOrder);
      _denied(t, BusinessCapability.useStockEntry);
      _denied(t, BusinessCapability.useSupplierBill);
    });

    test('KOT / IMEI / barcode denied', () {
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useBarcodeScanner);
    });
  });

  // ===========================================================================
  // 14. BOOK STORE
  // ===========================================================================
  group('bookStore', () {
    const t = 'bookStore';

    test('book-store-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useISBN);
      _allowed(t, BusinessCapability.usePublisherReturns);
      _allowed(t, BusinessCapability.useLoyaltyPoints);
      _allowed(t, BusinessCapability.useBarcodeScanner);
      _allowed(t, BusinessCapability.useScanOCR);
      _allowed(t, BusinessCapability.useInventoryExport);
      _allowed(t, BusinessCapability.useSalesReturn);
    });

    test('IMEI / KOT / prescription denied', () {
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.usePrescription);
    });
  });

  // ===========================================================================
  // 15. JEWELLERY
  // ===========================================================================
  group('jewellery', () {
    const t = 'jewellery';

    test('jewellery core capabilities enabled', () {
      _allowed(t, BusinessCapability.useProductAdd);
      _allowed(t, BusinessCapability.useProductName);
      _allowed(t, BusinessCapability.useProductSalePrice);
      _allowed(t, BusinessCapability.useProductStockQty);
      _allowed(t, BusinessCapability.useProductCategory);
      _allowed(t, BusinessCapability.useInvoiceList);
      _allowed(t, BusinessCapability.useInvoiceCreate);
      _allowed(t, BusinessCapability.useDailySnapshot);
      _allowed(t, BusinessCapability.useRevenueOverview);
      _allowed(t, BusinessCapability.useBarcodeScanner);
    });

    test('tax/unit denied (jewellery typically no GST units)', () {
      _denied(t, BusinessCapability.useProductTax);
      _denied(t, BusinessCapability.useProductUnit);
    });

    test('IMEI / KOT / prescription denied', () {
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.usePrescription);
    });

    test('sales return and purchase register denied', () {
      _denied(t, BusinessCapability.useSalesReturn);
      _denied(t, BusinessCapability.usePurchaseRegister);
    });
  });

  // ===========================================================================
  // 16. AUTO PARTS
  // ===========================================================================
  group('autoParts', () {
    const t = 'autoParts';

    test('auto-parts capabilities enabled', () {
      _allowed(t, BusinessCapability.useWarranty);
      _allowed(t, BusinessCapability.useJobSheets);
      _allowed(t, BusinessCapability.useRepairStatus);
      _allowed(t, BusinessCapability.useBarcodeScanner);
      _allowed(t, BusinessCapability.useLowStockAlert);
      _allowed(t, BusinessCapability.usePurchaseOrder);
    });

    test('IMEI / KOT / prescription denied', () {
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.usePrescription);
    });
  });

  // ===========================================================================
  // 17. DECORATION & CATERING
  // ===========================================================================
  group('decorationCatering', () {
    const t = 'decorationCatering';

    test('event-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useEventBooking);
      _allowed(t, BusinessCapability.useDecorationThemes);
      _allowed(t, BusinessCapability.useCateringMenu);
      _allowed(t, BusinessCapability.useEventStaffAllocation);
      _allowed(t, BusinessCapability.useVenueManagement);
      _allowed(t, BusinessCapability.useEventInventory);
      _allowed(t, BusinessCapability.useCateringKitchen);
      _allowed(t, BusinessCapability.useEventReports);
      _allowed(t, BusinessCapability.useAppointments);
      _allowed(t, BusinessCapability.useLaborCharges);
    });

    test('invoice and proforma enabled', () {
      _allowed(t, BusinessCapability.useInvoiceList);
      _allowed(t, BusinessCapability.useInvoiceCreate);
      _allowed(t, BusinessCapability.useProformaInvoice);
    });

    test('stock qty / tax / inventory search denied', () {
      _denied(t, BusinessCapability.useProductStockQty);
      _denied(t, BusinessCapability.useProductTax);
      _denied(t, BusinessCapability.useInventorySearch);
    });

    test('IMEI / KOT / prescription denied', () {
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.usePrescription);
    });
  });

  // ===========================================================================
  // 18. ACADEMIC COACHING
  // ===========================================================================
  group('academicCoaching', () {
    const t = 'academicCoaching';

    test('ALL academic-specific capabilities enabled', () {
      _allowed(t, BusinessCapability.useStudentRegistry);
      _allowed(t, BusinessCapability.useBatchManagement);
      _allowed(t, BusinessCapability.useFeeCollection);
      _allowed(t, BusinessCapability.useAttendanceTracking);
      _allowed(t, BusinessCapability.useTestResults);
      _allowed(t, BusinessCapability.useCourseMaterial);
      _allowed(t, BusinessCapability.useTimetable);
      _allowed(t, BusinessCapability.useStaffManagement);
      _allowed(t, BusinessCapability.useParentNotifications);
      _allowed(t, BusinessCapability.useCertificates);
      _allowed(t, BusinessCapability.useScholarshipDiscount);
      _allowed(t, BusinessCapability.useDemoClasses);
      _allowed(t, BusinessCapability.useAppointments);
    });

    test('invoice (fee receipts) enabled', () {
      _allowed(t, BusinessCapability.useInvoiceList);
      _allowed(t, BusinessCapability.useInvoiceSearch);
      _allowed(t, BusinessCapability.useInvoiceCreate);
    });

    test('alerts enabled', () {
      _allowed(t, BusinessCapability.useDailySnapshot);
      _allowed(t, BusinessCapability.useRevenueOverview);
      _allowed(t, BusinessCapability.useGeneralAlerts);
    });

    test('ALL product management denied (no physical products)', () {
      _denied(t, BusinessCapability.useProductAdd);
      _denied(t, BusinessCapability.useProductName);
      _denied(t, BusinessCapability.useProductSalePrice);
      _denied(t, BusinessCapability.useProductStockQty);
      _denied(t, BusinessCapability.useProductUnit);
      _denied(t, BusinessCapability.useProductTax);
      _denied(t, BusinessCapability.useProductCategory);
    });

    test('ALL inventory denied', () {
      _denied(t, BusinessCapability.useInventoryList);
      _denied(t, BusinessCapability.useVisibleStock);
      _denied(t, BusinessCapability.useDeadStock);
      _denied(t, BusinessCapability.useInventorySearch);
      _denied(t, BusinessCapability.useInventoryExport);
    });

    test('ALL purchase flow denied', () {
      _denied(t, BusinessCapability.usePurchaseOrder);
      _denied(t, BusinessCapability.useStockEntry);
      _denied(t, BusinessCapability.useStockReversal);
      _denied(t, BusinessCapability.useSupplierBill);
      _denied(t, BusinessCapability.usePurchaseRegister);
    });

    test('KOT / IMEI / barcode / prescription denied', () {
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useBarcodeScanner);
      _denied(t, BusinessCapability.usePrescription);
    });
  });

  // ===========================================================================
  // 19. OTHER / GENERAL
  // ===========================================================================
  group('other', () {
    const t = 'other';

    test('minimal safe capabilities enabled', () {
      _allowed(t, BusinessCapability.useProductAdd);
      _allowed(t, BusinessCapability.useProductName);
      _allowed(t, BusinessCapability.useStockManagement);
      _allowed(t, BusinessCapability.useBarcodeScanner);
      _allowed(t, BusinessCapability.useInvoiceCreate);
      _allowed(t, BusinessCapability.useInvoiceList);
    });

    test('specialized features denied', () {
      _denied(t, BusinessCapability.useKOT);
      _denied(t, BusinessCapability.usePrescription);
      _denied(t, BusinessCapability.useIMEI);
      _denied(t, BusinessCapability.useStudentRegistry);
      _denied(t, BusinessCapability.useEventBooking);
    });
  });

  // ===========================================================================
  // CROSS-TYPE ISOLATION — HARD BOUNDARY ASSERTIONS
  // ===========================================================================
  group('cross-type isolation', () {
    test('KOT is exclusive to restaurant', () {
      _allowed('restaurant', BusinessCapability.useKOT);
      for (final t in [
        'grocery', 'pharmacy', 'clothing', 'electronics', 'mobileShop',
        'computerShop', 'hardware', 'service', 'wholesale', 'petrolPump',
        'vegetablesBroker', 'clinic', 'bookStore', 'jewellery', 'autoParts',
        'decorationCatering', 'academicCoaching', 'other',
      ]) {
        _denied(t, BusinessCapability.useKOT);
      }
    });

    test('prescription only for pharmacy and clinic', () {
      _allowed('pharmacy', BusinessCapability.usePrescription);
      _allowed('clinic', BusinessCapability.usePrescription);
      for (final t in [
        'grocery', 'restaurant', 'clothing', 'electronics', 'mobileShop',
        'computerShop', 'hardware', 'service', 'wholesale', 'petrolPump',
        'vegetablesBroker', 'bookStore', 'jewellery', 'autoParts',
        'decorationCatering', 'academicCoaching', 'other',
      ]) {
        _denied(t, BusinessCapability.usePrescription);
      }
    });

    test('student registry exclusive to academicCoaching', () {
      _allowed('academicCoaching', BusinessCapability.useStudentRegistry);
      for (final t in [
        'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
        'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale',
        'petrolPump', 'vegetablesBroker', 'clinic', 'bookStore', 'jewellery',
        'autoParts', 'decorationCatering', 'other',
      ]) {
        _denied(t, BusinessCapability.useStudentRegistry);
      }
    });

    test('fuel management exclusive to petrolPump', () {
      _allowed('petrolPump', BusinessCapability.useFuelManagement);
      for (final t in [
        'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
        'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale',
        'vegetablesBroker', 'clinic', 'bookStore', 'jewellery', 'autoParts',
        'decorationCatering', 'academicCoaching', 'other',
      ]) {
        _denied(t, BusinessCapability.useFuelManagement);
      }
    });

    test('event booking exclusive to decorationCatering', () {
      _allowed('decorationCatering', BusinessCapability.useEventBooking);
      for (final t in [
        'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
        'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale',
        'petrolPump', 'vegetablesBroker', 'clinic', 'bookStore', 'jewellery',
        'autoParts', 'academicCoaching', 'other',
      ]) {
        _denied(t, BusinessCapability.useEventBooking);
      }
    });

    test('commission exclusive to vegetablesBroker', () {
      _allowed('vegetablesBroker', BusinessCapability.useCommission);
      for (final t in [
        'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
        'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale',
        'petrolPump', 'clinic', 'bookStore', 'jewellery', 'autoParts',
        'decorationCatering', 'academicCoaching', 'other',
      ]) {
        _denied(t, BusinessCapability.useCommission);
      }
    });

    test('IMEI only for electronics, mobileShop, computerShop', () {
      _allowed('electronics', BusinessCapability.useIMEI);
      _allowed('mobileShop', BusinessCapability.useIMEI);
      _allowed('computerShop', BusinessCapability.useIMEI);
      for (final t in [
        'grocery', 'pharmacy', 'restaurant', 'clothing', 'hardware',
        'service', 'wholesale', 'petrolPump', 'vegetablesBroker', 'clinic',
        'bookStore', 'jewellery', 'autoParts', 'decorationCatering',
        'academicCoaching', 'other',
      ]) {
        _denied(t, BusinessCapability.useIMEI);
      }
    });
  });

  // ===========================================================================
  // UNKNOWN / UNREGISTERED BUSINESS TYPE — STRICT DENY
  // ===========================================================================
  group('unknown business type', () {
    test('completely unknown type returns false for all capabilities', () {
      _denied('unknownType', BusinessCapability.useProductAdd);
      _denied('unknownType', BusinessCapability.useInvoiceCreate);
      _denied('unknownType', BusinessCapability.useBarcodeScanner);
    });

    test('empty string returns false', () {
      _denied('', BusinessCapability.useProductAdd);
    });

    test('enum.toString format is normalized correctly', () {
      // FeatureResolver normalizes 'BusinessType.grocery' → 'grocery'
      expect(
        FeatureResolver.canAccess('BusinessType.grocery', BusinessCapability.useProductAdd),
        isTrue,
      );
      expect(
        FeatureResolver.canAccess('BusinessType.academicCoaching', BusinessCapability.useStudentRegistry),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // SecurityException ENFORCEMENT
  // ===========================================================================
  group('SecurityException enforcement', () {
    test('enforceAccess throws for denied capability', () {
      expect(
        () => FeatureResolver.enforceAccess('grocery', BusinessCapability.useKOT),
        throwsA(isA<SecurityException>()),
      );
    });

    test('enforceAccess does not throw for allowed capability', () {
      expect(
        () => FeatureResolver.enforceAccess('grocery', BusinessCapability.useProductAdd),
        returnsNormally,
      );
    });

    test('SecurityException message contains type and capability name', () {
      try {
        FeatureResolver.enforceAccess('grocery', BusinessCapability.useKOT);
        fail('Expected SecurityException');
      } on SecurityException catch (e) {
        expect(e.message, contains('grocery'));
        expect(e.message, contains('useKOT'));
      }
    });

    test('enforceAccess throws for unknown business type', () {
      expect(
        () => FeatureResolver.enforceAccess('hackerType', BusinessCapability.useProductAdd),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  // ===========================================================================
  // getCapabilities helper
  // ===========================================================================
  group('getCapabilities', () {
    test('returns correct count for academicCoaching (19 capabilities)', () {
      final caps = FeatureResolver.getCapabilities('academicCoaching');
      expect(caps.length, 19);
    });

    test('returns correct count for service (9 capabilities)', () {
      final caps = FeatureResolver.getCapabilities('service');
      expect(caps.length, 9);
    });

    test('returns correct count for other (6 capabilities)', () {
      final caps = FeatureResolver.getCapabilities('other');
      expect(caps.length, 6);
    });

    test('returns empty set for unknown type', () {
      final caps = FeatureResolver.getCapabilities('nonExistent');
      expect(caps, isEmpty);
    });
  });
}
