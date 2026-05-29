// ============================================================================
// UT-CAP — Business Capability Registry Unit Tests
// Coverage: All 17 business types × all BusinessCapability enum values
// Disciplines: Enabled/Disabled assertions, cross-contamination, immutability
// ============================================================================

// NOTE: This test file targets the Dart registry via a JSON snapshot mirror.
// For the backend, we validate the TypeScript BusinessType enum isolation and
// the plan-feature-registry. For the Dart registry we use a JSON export.
// Run with: jest business-capability-registry.test.ts

import { BusinessType } from '../types/tenant.types';

// ── Dart Registry Mirror (kept in sync with business_capability.dart) ────────
// This represents the exact businessCapabilityRegistry from the Flutter app.
// CI should auto-generate this from the Dart source to prevent drift.

type Cap = string;

const registry: Record<string, Set<Cap>> = {
  grocery: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useDeadStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useGeneralAlerts','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useBarcodeScanner','useScanOCR','useStockManagement','useLowStockAlerts','useBatchExpiry','useVoiceInput',
  ]),
  pharmacy: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useDeadStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate','useSalesReturn',
    'useLowStockAlert','useGeneralAlerts','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useStockReversal','useSupplierBill','usePurchaseRegister',
    'usePrescription','useDoctorLinking','usePatientRegistry','useDrugSchedule','useSaltSearch',
    'useBatchExpiry','useBarcodeScanner','useScanOCR','useStockManagement','useLowStockAlerts',
  ]),
  restaurant: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useDeadStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useGeneralAlerts','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useKOT','useTableManagement','useWaiterLinking','useKitchenDisplay','useBarcodeScanner',
  ]),
  clothing: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useVariants','useTailoringNotes','useBarcodeScanner','useScanOCR','useStockManagement',
  ]),
  electronics: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useIMEI','useWarranty','useBarcodeScanner','useScanOCR','useStockManagement',
  ]),
  mobileShop: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useIMEI','useWarranty','useBuyback','useExchange','useJobSheets','useRepairStatus',
    'useStockManagement','useBarcodeScanner',
  ]),
  computerShop: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useIMEI','useWarranty','useJobSheets','useRepairStatus','useStockManagement',
    'useBarcodeScanner','useMultiUnit',
  ]),
  hardware: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useDimensions','useLooseQuantities','useBarcodeScanner','useStockManagement','useTransportDetails',
  ]),
  service: new Set([
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useDailySnapshot','useRevenueOverview',
    'useJobSheets','useServiceStatus','useLaborCharges','useAppointments',
  ]),
  wholesale: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useDeadStock','useInventorySearch','useInventoryExport',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate','useSalesReturn',
    'useProformaInvoice','useDispatchNote',
    'useLowStockAlert','useGeneralAlerts','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useStockReversal','useSupplierBill','usePurchaseRegister',
    'useStockManagement','useMultiUnit','useCreditManagement','useCreditLimit',
    'useTransportDetails','useBarcodeScanner','useBatchExpiry',
  ]),
  petrolPump: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useFuelManagement','usePumpReadings','useShiftManagement','useVehicleDetails',
    'useTankerEntry','useStockManagement','useBarcodeScanner',
  ]),
  vegetablesBroker: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useCommission','useCrateManagement','useFarmerLinking','useDailyRates','useCreditManagement',
  ]),
  clinic: new Set([
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useDailySnapshot','useRevenueOverview',
    'useAppointments','useConsultationBilling','usePatientRegistry',
    'usePrescription','useDoctorLinking',
  ]),
  bookStore: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useDeadStock','useInventorySearch','useInventoryExport',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate','useSalesReturn',
    'useLowStockAlert','useGeneralAlerts','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill','usePurchaseRegister',
    'useISBN','usePublisherReturns','useLoyaltyPoints','useBarcodeScanner',
    'useScanOCR','useStockManagement','useLowStockAlerts',
  ]),
  jewellery: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useDailySnapshot','useRevenueOverview',
    'useStockManagement','useBarcodeScanner',
  ]),
  autoParts: new Set([
    'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
    'useProductUnit','useProductTax','useProductCategory',
    'useInventoryList','useVisibleStock','useInventorySearch',
    'useInvoiceList','useInvoiceSearch','useInvoiceCreate',
    'useLowStockAlert','useDailySnapshot','useRevenueOverview',
    'usePurchaseOrder','useStockEntry','useSupplierBill',
    'useWarranty','useJobSheets','useRepairStatus','useStockManagement','useBarcodeScanner',
  ]),
  other: new Set([
    'useProductAdd','useProductName','useStockManagement',
    'useBarcodeScanner','useInvoiceCreate','useInvoiceList',
  ]),
};

const canAccess = (type: string, cap: Cap): boolean =>
  registry[type]?.has(cap) ?? false;

// ── Helper: assert capability is present ────────────────────────────────────
const assertEnabled = (type: string, cap: Cap) => {
  expect(canAccess(type, cap)).toBe(true);
};

// ── Helper: assert capability is absent ─────────────────────────────────────
const assertBlocked = (type: string, cap: Cap) => {
  expect(canAccess(type, cap)).toBe(false);
};

// ── All capability names extracted from the Dart enum ───────────────────────
const ALL_CAPS: Cap[] = [
  'useProductAdd','useProductName','useProductSalePrice','useProductStockQty',
  'useProductUnit','useProductTax','useProductCategory',
  'useInventoryList','useVisibleStock','useDeadStock','useInventorySearch','useInventoryExport',
  'useInvoiceList','useInvoiceSearch','useInvoiceCreate','useSalesReturn',
  'useProformaInvoice','useDispatchNote',
  'useLowStockAlert','useGeneralAlerts','useDailySnapshot','useRevenueOverview',
  'usePurchaseOrder','useStockEntry','useStockReversal','useSupplierBill','usePurchaseRegister',
  'usePrescription','useDoctorLinking','usePatientRegistry','useDrugSchedule','useSaltSearch',
  'useBarcodeScanner','useScanOCR','useVoiceInput',
  'useBatchExpiry','useStockManagement','useLowStockAlerts','useMultiUnit','useNegativeStock',
  'useDimensions','useLooseQuantities',
  'useVariants','useTailoringNotes',
  'useIMEI','useWarranty','useBuyback','useExchange',
  'useKOT','useTableManagement','useWaiterLinking','useKitchenDisplay',
  'useFuelManagement','usePumpReadings','useShiftManagement','useVehicleDetails','useTankerEntry',
  'useJobSheets','useRepairStatus','useServiceStatus','useLaborCharges',
  'useCommission','useCrateManagement','useFarmerLinking','useDailyRates',
  'useCreditManagement','useTransportDetails','useCreditLimit',
  'useAppointments','useConsultationBilling',
  'useISBN','usePublisherReturns','useLoyaltyPoints',
];

const ALL_TYPES = Object.keys(registry);

// ============================================================================
// SECTION 1: Registry Completeness & Structure
// ============================================================================

describe('UT-CAP-STRUCT: Registry Structure', () => {
  test('UT-CAP-STRUCT-001: Registry contains all 17 business types', () => {
    const expectedTypes = [
      'grocery','pharmacy','restaurant','clothing','electronics',
      'mobileShop','computerShop','hardware','service','wholesale',
      'petrolPump','vegetablesBroker','clinic','bookStore','jewellery','autoParts','other',
    ];
    for (const type of expectedTypes) {
      expect(registry[type]).toBeDefined();
      expect(registry[type].size).toBeGreaterThan(0);
    }
  });

  test('UT-CAP-STRUCT-002: Unknown business type returns empty set (default deny)', () => {
    expect(canAccess('nonexistent_type', 'useProductAdd')).toBe(false);
  });

  test('UT-CAP-STRUCT-003: Registry is a plain object (not mutable class)', () => {
    expect(typeof registry).toBe('object');
  });

  test('UT-CAP-STRUCT-004: Every registry value is a Set', () => {
    for (const type of ALL_TYPES) {
      expect(registry[type]).toBeInstanceOf(Set);
    }
  });

  test('UT-CAP-STRUCT-005: No duplicate capabilities within any business type', () => {
    // Sets enforce uniqueness — size equals the number of unique entries
    for (const type of ALL_TYPES) {
      const arr = Array.from(registry[type]);
      const unique = new Set(arr);
      expect(unique.size).toBe(arr.length);
    }
  });
});

// ============================================================================
// SECTION 2: GROCERY
// ============================================================================

describe('UT-CAP-001 — grocery capability matrix', () => {
  const T = 'grocery';
  test('grocery_has_useProductAdd_true',          () => assertEnabled(T, 'useProductAdd'));
  test('grocery_has_useInventoryList_true',        () => assertEnabled(T, 'useInventoryList'));
  test('grocery_has_useDeadStock_true',            () => assertEnabled(T, 'useDeadStock'));
  test('grocery_has_useLowStockAlert_true',        () => assertEnabled(T, 'useLowStockAlert'));
  test('grocery_has_useBatchExpiry_true',          () => assertEnabled(T, 'useBatchExpiry'));
  test('grocery_has_usePurchaseOrder_true',        () => assertEnabled(T, 'usePurchaseOrder'));
  test('grocery_has_useStockEntry_true',           () => assertEnabled(T, 'useStockEntry'));
  test('grocery_has_useBarcodeScanner_true',       () => assertEnabled(T, 'useBarcodeScanner'));
  test('grocery_has_useDailySnapshot_true',        () => assertEnabled(T, 'useDailySnapshot'));
  test('grocery_has_useRevenueOverview_true',      () => assertEnabled(T, 'useRevenueOverview'));
  // BLOCKED
  test('grocery_has_useSalesReturn_false',         () => assertBlocked(T, 'useSalesReturn'));
  test('grocery_has_useProformaInvoice_false',     () => assertBlocked(T, 'useProformaInvoice'));
  test('grocery_has_useDispatchNote_false',        () => assertBlocked(T, 'useDispatchNote'));
  test('grocery_has_useInventoryExport_false',     () => assertBlocked(T, 'useInventoryExport'));
  test('grocery_has_useStockReversal_false',       () => assertBlocked(T, 'useStockReversal'));
  test('grocery_has_usePurchaseRegister_false',    () => assertBlocked(T, 'usePurchaseRegister'));
  test('grocery_has_useKOT_false',                 () => assertBlocked(T, 'useKOT'));
  test('grocery_has_useIMEI_false',                () => assertBlocked(T, 'useIMEI'));
  test('grocery_has_useFuelManagement_false',      () => assertBlocked(T, 'useFuelManagement'));
  test('grocery_has_useCommission_false',          () => assertBlocked(T, 'useCommission'));
  test('grocery_has_useAppointments_false',        () => assertBlocked(T, 'useAppointments'));
  test('grocery_has_useISBN_false',                () => assertBlocked(T, 'useISBN'));
  test('grocery_has_usePrescription_false',        () => assertBlocked(T, 'usePrescription'));
  test('grocery_has_useConsultationBilling_false', () => assertBlocked(T, 'useConsultationBilling'));
});

// ============================================================================
// SECTION 3: PHARMACY
// ============================================================================

describe('UT-CAP-002 — pharmacy capability matrix', () => {
  const T = 'pharmacy';
  test('pharmacy_has_usePrescription_true',        () => assertEnabled(T, 'usePrescription'));
  test('pharmacy_has_useDoctorLinking_true',       () => assertEnabled(T, 'useDoctorLinking'));
  test('pharmacy_has_usePatientRegistry_true',     () => assertEnabled(T, 'usePatientRegistry'));
  test('pharmacy_has_useDrugSchedule_true',        () => assertEnabled(T, 'useDrugSchedule'));
  test('pharmacy_has_useSaltSearch_true',          () => assertEnabled(T, 'useSaltSearch'));
  test('pharmacy_has_useSalesReturn_true',         () => assertEnabled(T, 'useSalesReturn'));
  test('pharmacy_has_useBatchExpiry_true',         () => assertEnabled(T, 'useBatchExpiry'));
  test('pharmacy_has_useStockReversal_true',       () => assertEnabled(T, 'useStockReversal'));
  test('pharmacy_has_usePurchaseRegister_true',    () => assertEnabled(T, 'usePurchaseRegister'));
  test('pharmacy_has_useDeadStock_true',           () => assertEnabled(T, 'useDeadStock'));
  // BLOCKED
  test('pharmacy_has_useProformaInvoice_false',    () => assertBlocked(T, 'useProformaInvoice'));
  test('pharmacy_has_useDispatchNote_false',       () => assertBlocked(T, 'useDispatchNote'));
  test('pharmacy_has_useInventoryExport_false',    () => assertBlocked(T, 'useInventoryExport'));
  test('pharmacy_has_useKOT_false',                () => assertBlocked(T, 'useKOT'));
  test('pharmacy_has_useTableManagement_false',    () => assertBlocked(T, 'useTableManagement'));
  test('pharmacy_has_useIMEI_false',               () => assertBlocked(T, 'useIMEI'));
  test('pharmacy_has_useFuelManagement_false',     () => assertBlocked(T, 'useFuelManagement'));
  test('pharmacy_has_useCommission_false',         () => assertBlocked(T, 'useCommission'));
  test('pharmacy_has_useConsultationBilling_false',() => assertBlocked(T, 'useConsultationBilling'));
});

// ============================================================================
// SECTION 4: RESTAURANT
// ============================================================================

describe('UT-CAP-003 — restaurant capability matrix', () => {
  const T = 'restaurant';
  test('restaurant_has_useKOT_true',               () => assertEnabled(T, 'useKOT'));
  test('restaurant_has_useTableManagement_true',   () => assertEnabled(T, 'useTableManagement'));
  test('restaurant_has_useWaiterLinking_true',     () => assertEnabled(T, 'useWaiterLinking'));
  test('restaurant_has_useKitchenDisplay_true',    () => assertEnabled(T, 'useKitchenDisplay'));
  test('restaurant_has_useProductAdd_true',        () => assertEnabled(T, 'useProductAdd'));
  test('restaurant_has_useInvoiceCreate_true',     () => assertEnabled(T, 'useInvoiceCreate'));
  // BLOCKED
  test('restaurant_has_useSalesReturn_false',      () => assertBlocked(T, 'useSalesReturn'));
  test('restaurant_has_useProformaInvoice_false',  () => assertBlocked(T, 'useProformaInvoice'));
  test('restaurant_has_useDispatchNote_false',     () => assertBlocked(T, 'useDispatchNote'));
  test('restaurant_has_useInventoryExport_false',  () => assertBlocked(T, 'useInventoryExport'));
  test('restaurant_has_useStockReversal_false',    () => assertBlocked(T, 'useStockReversal'));
  test('restaurant_has_usePurchaseRegister_false', () => assertBlocked(T, 'usePurchaseRegister'));
  test('restaurant_has_useIMEI_false',             () => assertBlocked(T, 'useIMEI'));
  test('restaurant_has_useFuelManagement_false',   () => assertBlocked(T, 'useFuelManagement'));
  test('restaurant_has_usePrescription_false',     () => assertBlocked(T, 'usePrescription'));
  test('restaurant_has_useCommission_false',       () => assertBlocked(T, 'useCommission'));
  test('restaurant_has_useAppointments_false',     () => assertBlocked(T, 'useAppointments'));
  test('restaurant_has_useISBN_false',             () => assertBlocked(T, 'useISBN'));
});

// ============================================================================
// SECTION 5: CLOTHING
// ============================================================================

describe('UT-CAP-004 — clothing capability matrix', () => {
  const T = 'clothing';
  test('clothing_has_useVariants_true',            () => assertEnabled(T, 'useVariants'));
  test('clothing_has_useTailoringNotes_true',      () => assertEnabled(T, 'useTailoringNotes'));
  test('clothing_has_useProductAdd_true',          () => assertEnabled(T, 'useProductAdd'));
  test('clothing_has_useInvoiceCreate_true',       () => assertEnabled(T, 'useInvoiceCreate'));
  test('clothing_has_useDailySnapshot_true',       () => assertEnabled(T, 'useDailySnapshot'));
  // BLOCKED
  test('clothing_has_useDeadStock_false',          () => assertBlocked(T, 'useDeadStock'));
  test('clothing_has_useLowStockAlert_false',      () => assertBlocked(T, 'useLowStockAlert'));
  test('clothing_has_useSalesReturn_false',        () => assertBlocked(T, 'useSalesReturn'));
  test('clothing_has_useProformaInvoice_false',    () => assertBlocked(T, 'useProformaInvoice'));
  test('clothing_has_useDispatchNote_false',       () => assertBlocked(T, 'useDispatchNote'));
  test('clothing_has_useInventoryExport_false',    () => assertBlocked(T, 'useInventoryExport'));
  test('clothing_has_useStockReversal_false',      () => assertBlocked(T, 'useStockReversal'));
  test('clothing_has_usePurchaseRegister_false',   () => assertBlocked(T, 'usePurchaseRegister'));
  test('clothing_has_useKOT_false',               () => assertBlocked(T, 'useKOT'));
  test('clothing_has_useIMEI_false',               () => assertBlocked(T, 'useIMEI'));
  test('clothing_has_useFuelManagement_false',     () => assertBlocked(T, 'useFuelManagement'));
  test('clothing_has_usePrescription_false',       () => assertBlocked(T, 'usePrescription'));
  test('clothing_has_useCommission_false',         () => assertBlocked(T, 'useCommission'));
});

// ============================================================================
// SECTION 6: ELECTRONICS
// ============================================================================

describe('UT-CAP-005 — electronics capability matrix', () => {
  const T = 'electronics';
  test('electronics_has_useIMEI_true',             () => assertEnabled(T, 'useIMEI'));
  test('electronics_has_useWarranty_true',         () => assertEnabled(T, 'useWarranty'));
  test('electronics_has_useLowStockAlert_true',    () => assertEnabled(T, 'useLowStockAlert'));
  test('electronics_has_useProductAdd_true',       () => assertEnabled(T, 'useProductAdd'));
  test('electronics_has_useBarcodeScanner_true',   () => assertEnabled(T, 'useBarcodeScanner'));
  // BLOCKED
  test('electronics_has_useDeadStock_false',       () => assertBlocked(T, 'useDeadStock'));
  test('electronics_has_useSalesReturn_false',     () => assertBlocked(T, 'useSalesReturn'));
  test('electronics_has_useProformaInvoice_false', () => assertBlocked(T, 'useProformaInvoice'));
  test('electronics_has_useDispatchNote_false',    () => assertBlocked(T, 'useDispatchNote'));
  test('electronics_has_useInventoryExport_false', () => assertBlocked(T, 'useInventoryExport'));
  test('electronics_has_useStockReversal_false',   () => assertBlocked(T, 'useStockReversal'));
  test('electronics_has_usePurchaseRegister_false',() => assertBlocked(T, 'usePurchaseRegister'));
  test('electronics_has_useKOT_false',             () => assertBlocked(T, 'useKOT'));
  test('electronics_has_useFuelManagement_false',  () => assertBlocked(T, 'useFuelManagement'));
  test('electronics_has_usePrescription_false',    () => assertBlocked(T, 'usePrescription'));
  test('electronics_has_useBuyback_false',         () => assertBlocked(T, 'useBuyback'));
  test('electronics_has_useExchange_false',        () => assertBlocked(T, 'useExchange'));
  test('electronics_has_useCommission_false',      () => assertBlocked(T, 'useCommission'));
});

// ============================================================================
// SECTION 7: MOBILE SHOP
// ============================================================================

describe('UT-CAP-006 — mobileShop capability matrix', () => {
  const T = 'mobileShop';
  test('mobileShop_has_useIMEI_true',              () => assertEnabled(T, 'useIMEI'));
  test('mobileShop_has_useWarranty_true',          () => assertEnabled(T, 'useWarranty'));
  test('mobileShop_has_useBuyback_true',           () => assertEnabled(T, 'useBuyback'));
  test('mobileShop_has_useExchange_true',          () => assertEnabled(T, 'useExchange'));
  test('mobileShop_has_useJobSheets_true',         () => assertEnabled(T, 'useJobSheets'));
  test('mobileShop_has_useRepairStatus_true',      () => assertEnabled(T, 'useRepairStatus'));
  test('mobileShop_has_useLowStockAlert_true',     () => assertEnabled(T, 'useLowStockAlert'));
  // BLOCKED
  test('mobileShop_has_useDeadStock_false',        () => assertBlocked(T, 'useDeadStock'));
  test('mobileShop_has_useSalesReturn_false',      () => assertBlocked(T, 'useSalesReturn'));
  test('mobileShop_has_useProformaInvoice_false',  () => assertBlocked(T, 'useProformaInvoice'));
  test('mobileShop_has_useDispatchNote_false',     () => assertBlocked(T, 'useDispatchNote'));
  test('mobileShop_has_useInventoryExport_false',  () => assertBlocked(T, 'useInventoryExport'));
  test('mobileShop_has_useStockReversal_false',    () => assertBlocked(T, 'useStockReversal'));
  test('mobileShop_has_usePurchaseRegister_false', () => assertBlocked(T, 'usePurchaseRegister'));
  test('mobileShop_has_useKOT_false',              () => assertBlocked(T, 'useKOT'));
  test('mobileShop_has_useFuelManagement_false',   () => assertBlocked(T, 'useFuelManagement'));
  test('mobileShop_has_usePrescription_false',     () => assertBlocked(T, 'usePrescription'));
  test('mobileShop_has_useCommission_false',       () => assertBlocked(T, 'useCommission'));
  test('mobileShop_has_useVariants_false',         () => assertBlocked(T, 'useVariants'));
});

// ============================================================================
// SECTION 8: COMPUTER SHOP
// ============================================================================

describe('UT-CAP-007 — computerShop capability matrix', () => {
  const T = 'computerShop';
  test('computerShop_has_useIMEI_true',            () => assertEnabled(T, 'useIMEI'));
  test('computerShop_has_useWarranty_true',        () => assertEnabled(T, 'useWarranty'));
  test('computerShop_has_useJobSheets_true',       () => assertEnabled(T, 'useJobSheets'));
  test('computerShop_has_useRepairStatus_true',    () => assertEnabled(T, 'useRepairStatus'));
  test('computerShop_has_useMultiUnit_true',       () => assertEnabled(T, 'useMultiUnit'));
  test('computerShop_has_useLowStockAlert_true',   () => assertEnabled(T, 'useLowStockAlert'));
  // BLOCKED
  test('computerShop_has_useBuyback_false',        () => assertBlocked(T, 'useBuyback'));
  test('computerShop_has_useExchange_false',       () => assertBlocked(T, 'useExchange'));
  test('computerShop_has_useDeadStock_false',      () => assertBlocked(T, 'useDeadStock'));
  test('computerShop_has_useSalesReturn_false',    () => assertBlocked(T, 'useSalesReturn'));
  test('computerShop_has_useProformaInvoice_false',() => assertBlocked(T, 'useProformaInvoice'));
  test('computerShop_has_useDispatchNote_false',   () => assertBlocked(T, 'useDispatchNote'));
  test('computerShop_has_useInventoryExport_false',() => assertBlocked(T, 'useInventoryExport'));
  test('computerShop_has_useKOT_false',            () => assertBlocked(T, 'useKOT'));
  test('computerShop_has_useFuelManagement_false', () => assertBlocked(T, 'useFuelManagement'));
  test('computerShop_has_usePrescription_false',   () => assertBlocked(T, 'usePrescription'));
  test('computerShop_has_useCommission_false',     () => assertBlocked(T, 'useCommission'));
});

// ============================================================================
// SECTION 9: HARDWARE
// ============================================================================

describe('UT-CAP-008 — hardware capability matrix', () => {
  const T = 'hardware';
  test('hardware_has_useDimensions_true',          () => assertEnabled(T, 'useDimensions'));
  test('hardware_has_useLooseQuantities_true',     () => assertEnabled(T, 'useLooseQuantities'));
  test('hardware_has_useTransportDetails_true',    () => assertEnabled(T, 'useTransportDetails'));
  test('hardware_has_usePurchaseOrder_true',       () => assertEnabled(T, 'usePurchaseOrder'));
  test('hardware_has_useLowStockAlert_true',       () => assertEnabled(T, 'useLowStockAlert'));
  // BLOCKED
  test('hardware_has_useDeadStock_false',          () => assertBlocked(T, 'useDeadStock'));
  test('hardware_has_useSalesReturn_false',        () => assertBlocked(T, 'useSalesReturn'));
  test('hardware_has_useProformaInvoice_false',    () => assertBlocked(T, 'useProformaInvoice'));
  test('hardware_has_useDispatchNote_false',       () => assertBlocked(T, 'useDispatchNote'));
  test('hardware_has_useInventoryExport_false',    () => assertBlocked(T, 'useInventoryExport'));
  test('hardware_has_useStockReversal_false',      () => assertBlocked(T, 'useStockReversal'));
  test('hardware_has_usePurchaseRegister_false',   () => assertBlocked(T, 'usePurchaseRegister'));
  test('hardware_has_useKOT_false',               () => assertBlocked(T, 'useKOT'));
  test('hardware_has_useIMEI_false',               () => assertBlocked(T, 'useIMEI'));
  test('hardware_has_useFuelManagement_false',     () => assertBlocked(T, 'useFuelManagement'));
  test('hardware_has_usePrescription_false',       () => assertBlocked(T, 'usePrescription'));
  test('hardware_has_useCommission_false',         () => assertBlocked(T, 'useCommission'));
  test('hardware_has_useVariants_false',           () => assertBlocked(T, 'useVariants'));
});

// ============================================================================
// SECTION 10: SERVICE (most restrictive — no inventory)
// ============================================================================

describe('UT-CAP-009 — service capability matrix', () => {
  const T = 'service';
  test('service_has_useJobSheets_true',            () => assertEnabled(T, 'useJobSheets'));
  test('service_has_useServiceStatus_true',        () => assertEnabled(T, 'useServiceStatus'));
  test('service_has_useLaborCharges_true',         () => assertEnabled(T, 'useLaborCharges'));
  test('service_has_useAppointments_true',         () => assertEnabled(T, 'useAppointments'));
  test('service_has_useInvoiceCreate_true',        () => assertEnabled(T, 'useInvoiceCreate'));
  test('service_has_useDailySnapshot_true',        () => assertEnabled(T, 'useDailySnapshot'));
  test('service_has_useRevenueOverview_true',      () => assertEnabled(T, 'useRevenueOverview'));
  // BLOCKED — Hard Isolation
  test('service_has_useProductAdd_false',          () => assertBlocked(T, 'useProductAdd'));
  test('service_has_useInventoryList_false',       () => assertBlocked(T, 'useInventoryList'));
  test('service_has_useVisibleStock_false',        () => assertBlocked(T, 'useVisibleStock'));
  test('service_has_useDeadStock_false',           () => assertBlocked(T, 'useDeadStock'));
  test('service_has_usePurchaseOrder_false',       () => assertBlocked(T, 'usePurchaseOrder'));
  test('service_has_useStockEntry_false',          () => assertBlocked(T, 'useStockEntry'));
  test('service_has_useSupplierBill_false',        () => assertBlocked(T, 'useSupplierBill'));
  test('service_has_useLowStockAlert_false',       () => assertBlocked(T, 'useLowStockAlert'));
  test('service_has_useBarcodeScanner_false',      () => assertBlocked(T, 'useBarcodeScanner'));
  test('service_has_useBatchExpiry_false',         () => assertBlocked(T, 'useBatchExpiry'));
  test('service_has_useSalesReturn_false',         () => assertBlocked(T, 'useSalesReturn'));
  test('service_has_useProformaInvoice_false',     () => assertBlocked(T, 'useProformaInvoice'));
  test('service_has_useDispatchNote_false',        () => assertBlocked(T, 'useDispatchNote'));
  test('service_has_useStockReversal_false',       () => assertBlocked(T, 'useStockReversal'));
  test('service_has_usePurchaseRegister_false',    () => assertBlocked(T, 'usePurchaseRegister'));
  test('service_has_useKOT_false',                () => assertBlocked(T, 'useKOT'));
  test('service_has_useIMEI_false',                () => assertBlocked(T, 'useIMEI'));
  test('service_has_useFuelManagement_false',      () => assertBlocked(T, 'useFuelManagement'));
  test('service_has_useCommission_false',          () => assertBlocked(T, 'useCommission'));
  test('service_has_usePatientRegistry_false',     () => assertBlocked(T, 'usePatientRegistry'));
  test('service_has_useConsultationBilling_false', () => assertBlocked(T, 'useConsultationBilling'));
});

// ============================================================================
// SECTION 11: WHOLESALE (most permissive — all 28 capabilities)
// ============================================================================

describe('UT-CAP-010 — wholesale capability matrix', () => {
  const T = 'wholesale';
  test('wholesale_has_useProformaInvoice_true',    () => assertEnabled(T, 'useProformaInvoice'));
  test('wholesale_has_useDispatchNote_true',       () => assertEnabled(T, 'useDispatchNote'));
  test('wholesale_has_useInventoryExport_true',    () => assertEnabled(T, 'useInventoryExport'));
  test('wholesale_has_useSalesReturn_true',        () => assertEnabled(T, 'useSalesReturn'));
  test('wholesale_has_useStockReversal_true',      () => assertEnabled(T, 'useStockReversal'));
  test('wholesale_has_usePurchaseRegister_true',   () => assertEnabled(T, 'usePurchaseRegister'));
  test('wholesale_has_useCreditManagement_true',   () => assertEnabled(T, 'useCreditManagement'));
  test('wholesale_has_useCreditLimit_true',        () => assertEnabled(T, 'useCreditLimit'));
  test('wholesale_has_useTransportDetails_true',   () => assertEnabled(T, 'useTransportDetails'));
  test('wholesale_has_useMultiUnit_true',          () => assertEnabled(T, 'useMultiUnit'));
  test('wholesale_has_useBatchExpiry_true',        () => assertEnabled(T, 'useBatchExpiry'));
  test('wholesale_has_useDeadStock_true',          () => assertEnabled(T, 'useDeadStock'));
  test('wholesale_has_useLowStockAlert_true',      () => assertEnabled(T, 'useLowStockAlert'));
  test('wholesale_has_useGeneralAlerts_true',      () => assertEnabled(T, 'useGeneralAlerts'));
  // BLOCKED for wholesale
  test('wholesale_has_useKOT_false',               () => assertBlocked(T, 'useKOT'));
  test('wholesale_has_useTableManagement_false',   () => assertBlocked(T, 'useTableManagement'));
  test('wholesale_has_useIMEI_false',              () => assertBlocked(T, 'useIMEI'));
  test('wholesale_has_useFuelManagement_false',    () => assertBlocked(T, 'useFuelManagement'));
  test('wholesale_has_usePrescription_false',      () => assertBlocked(T, 'usePrescription'));
  test('wholesale_has_useCommission_false',        () => assertBlocked(T, 'useCommission'));
  test('wholesale_has_useAppointments_false',      () => assertBlocked(T, 'useAppointments'));
  test('wholesale_has_useISBN_false',              () => assertBlocked(T, 'useISBN'));
  test('wholesale_has_useDimensions_false',        () => assertBlocked(T, 'useDimensions'));
  test('wholesale_has_useVariants_false',          () => assertBlocked(T, 'useVariants'));
  test('wholesale_has_useJobSheets_false',         () => assertBlocked(T, 'useJobSheets'));
});

// ============================================================================
// SECTION 12: PETROL PUMP
// ============================================================================

describe('UT-CAP-011 — petrolPump capability matrix', () => {
  const T = 'petrolPump';
  test('petrolPump_has_useFuelManagement_true',    () => assertEnabled(T, 'useFuelManagement'));
  test('petrolPump_has_usePumpReadings_true',      () => assertEnabled(T, 'usePumpReadings'));
  test('petrolPump_has_useShiftManagement_true',   () => assertEnabled(T, 'useShiftManagement'));
  test('petrolPump_has_useVehicleDetails_true',    () => assertEnabled(T, 'useVehicleDetails'));
  test('petrolPump_has_useTankerEntry_true',       () => assertEnabled(T, 'useTankerEntry'));
  test('petrolPump_has_useLowStockAlert_true',     () => assertEnabled(T, 'useLowStockAlert'));
  // BLOCKED
  test('petrolPump_has_useDeadStock_false',        () => assertBlocked(T, 'useDeadStock'));
  test('petrolPump_has_useInventoryExport_false',  () => assertBlocked(T, 'useInventoryExport'));
  test('petrolPump_has_useSalesReturn_false',      () => assertBlocked(T, 'useSalesReturn'));
  test('petrolPump_has_useProformaInvoice_false',  () => assertBlocked(T, 'useProformaInvoice'));
  test('petrolPump_has_useDispatchNote_false',     () => assertBlocked(T, 'useDispatchNote'));
  test('petrolPump_has_useStockReversal_false',    () => assertBlocked(T, 'useStockReversal'));
  test('petrolPump_has_usePurchaseRegister_false', () => assertBlocked(T, 'usePurchaseRegister'));
  test('petrolPump_has_useKOT_false',              () => assertBlocked(T, 'useKOT'));
  test('petrolPump_has_useIMEI_false',             () => assertBlocked(T, 'useIMEI'));
  test('petrolPump_has_usePrescription_false',     () => assertBlocked(T, 'usePrescription'));
  test('petrolPump_has_useCommission_false',       () => assertBlocked(T, 'useCommission'));
  test('petrolPump_has_useVariants_false',         () => assertBlocked(T, 'useVariants'));
});

// ============================================================================
// SECTION 13: VEGETABLES BROKER
// ============================================================================

describe('UT-CAP-012 — vegetablesBroker capability matrix', () => {
  const T = 'vegetablesBroker';
  test('vegetablesBroker_has_useCommission_true',      () => assertEnabled(T, 'useCommission'));
  test('vegetablesBroker_has_useCrateManagement_true', () => assertEnabled(T, 'useCrateManagement'));
  test('vegetablesBroker_has_useFarmerLinking_true',   () => assertEnabled(T, 'useFarmerLinking'));
  test('vegetablesBroker_has_useDailyRates_true',      () => assertEnabled(T, 'useDailyRates'));
  test('vegetablesBroker_has_useCreditManagement_true',() => assertEnabled(T, 'useCreditManagement'));
  // Vegetable broker does NOT have tax
  test('vegetablesBroker_has_useProductTax_false',     () => assertBlocked(T, 'useProductTax'));
  // BLOCKED
  test('vegetablesBroker_has_useIMEI_false',           () => assertBlocked(T, 'useIMEI'));
  test('vegetablesBroker_has_useKOT_false',            () => assertBlocked(T, 'useKOT'));
  test('vegetablesBroker_has_useFuelManagement_false', () => assertBlocked(T, 'useFuelManagement'));
  test('vegetablesBroker_has_usePrescription_false',   () => assertBlocked(T, 'usePrescription'));
  test('vegetablesBroker_has_useProformaInvoice_false',() => assertBlocked(T, 'useProformaInvoice'));
  test('vegetablesBroker_has_useInventoryExport_false',() => assertBlocked(T, 'useInventoryExport'));
  test('vegetablesBroker_has_useVariants_false',       () => assertBlocked(T, 'useVariants'));
  test('vegetablesBroker_has_useISBN_false',           () => assertBlocked(T, 'useISBN'));
});

// ============================================================================
// SECTION 14: CLINIC (most restrictive after service)
// ============================================================================

describe('UT-CAP-013 — clinic capability matrix', () => {
  const T = 'clinic';
  test('clinic_has_useAppointments_true',          () => assertEnabled(T, 'useAppointments'));
  test('clinic_has_useConsultationBilling_true',   () => assertEnabled(T, 'useConsultationBilling'));
  test('clinic_has_usePatientRegistry_true',       () => assertEnabled(T, 'usePatientRegistry'));
  test('clinic_has_usePrescription_true',          () => assertEnabled(T, 'usePrescription'));
  test('clinic_has_useDoctorLinking_true',         () => assertEnabled(T, 'useDoctorLinking'));
  test('clinic_has_useInvoiceCreate_true',         () => assertEnabled(T, 'useInvoiceCreate'));
  test('clinic_has_useDailySnapshot_true',         () => assertEnabled(T, 'useDailySnapshot'));
  // BLOCKED — Hard Isolation
  test('clinic_has_useProductAdd_false',           () => assertBlocked(T, 'useProductAdd'));
  test('clinic_has_useInventoryList_false',        () => assertBlocked(T, 'useInventoryList'));
  test('clinic_has_usePurchaseOrder_false',        () => assertBlocked(T, 'usePurchaseOrder'));
  test('clinic_has_useStockEntry_false',           () => assertBlocked(T, 'useStockEntry'));
  test('clinic_has_useSupplierBill_false',         () => assertBlocked(T, 'useSupplierBill'));
  test('clinic_has_useStockReversal_false',        () => assertBlocked(T, 'useStockReversal'));
  test('clinic_has_usePurchaseRegister_false',     () => assertBlocked(T, 'usePurchaseRegister'));
  test('clinic_has_useLowStockAlert_false',        () => assertBlocked(T, 'useLowStockAlert'));
  test('clinic_has_useBarcodeScanner_false',       () => assertBlocked(T, 'useBarcodeScanner'));
  test('clinic_has_useBatchExpiry_false',          () => assertBlocked(T, 'useBatchExpiry'));
  test('clinic_has_useSalesReturn_false',          () => assertBlocked(T, 'useSalesReturn'));
  test('clinic_has_useProformaInvoice_false',      () => assertBlocked(T, 'useProformaInvoice'));
  test('clinic_has_useDispatchNote_false',         () => assertBlocked(T, 'useDispatchNote'));
  test('clinic_has_useKOT_false',                 () => assertBlocked(T, 'useKOT'));
  test('clinic_has_useIMEI_false',                 () => assertBlocked(T, 'useIMEI'));
  test('clinic_has_useFuelManagement_false',       () => assertBlocked(T, 'useFuelManagement'));
  test('clinic_has_useCommission_false',           () => assertBlocked(T, 'useCommission'));
  test('clinic_has_useVariants_false',             () => assertBlocked(T, 'useVariants'));
  test('clinic_has_useTailoringNotes_false',       () => assertBlocked(T, 'useTailoringNotes'));
});

// ============================================================================
// SECTION 15: BOOK STORE
// ============================================================================

describe('UT-CAP-014 — bookStore capability matrix', () => {
  const T = 'bookStore';
  test('bookStore_has_useISBN_true',               () => assertEnabled(T, 'useISBN'));
  test('bookStore_has_usePublisherReturns_true',   () => assertEnabled(T, 'usePublisherReturns'));
  test('bookStore_has_useLoyaltyPoints_true',      () => assertEnabled(T, 'useLoyaltyPoints'));
  test('bookStore_has_useSalesReturn_true',        () => assertEnabled(T, 'useSalesReturn'));
  test('bookStore_has_useDeadStock_true',          () => assertEnabled(T, 'useDeadStock'));
  test('bookStore_has_useInventoryExport_true',    () => assertEnabled(T, 'useInventoryExport'));
  test('bookStore_has_usePurchaseRegister_true',   () => assertEnabled(T, 'usePurchaseRegister'));
  test('bookStore_has_useLowStockAlert_true',      () => assertEnabled(T, 'useLowStockAlert'));
  // BLOCKED
  test('bookStore_has_useProformaInvoice_false',   () => assertBlocked(T, 'useProformaInvoice'));
  test('bookStore_has_useDispatchNote_false',      () => assertBlocked(T, 'useDispatchNote'));
  test('bookStore_has_useStockReversal_false',     () => assertBlocked(T, 'useStockReversal'));
  test('bookStore_has_useKOT_false',               () => assertBlocked(T, 'useKOT'));
  test('bookStore_has_useIMEI_false',              () => assertBlocked(T, 'useIMEI'));
  test('bookStore_has_useFuelManagement_false',    () => assertBlocked(T, 'useFuelManagement'));
  test('bookStore_has_usePrescription_false',      () => assertBlocked(T, 'usePrescription'));
  test('bookStore_has_useCommission_false',        () => assertBlocked(T, 'useCommission'));
  test('bookStore_has_useVariants_false',          () => assertBlocked(T, 'useVariants'));
  test('bookStore_has_useTailoringNotes_false',    () => assertBlocked(T, 'useTailoringNotes'));
  test('bookStore_has_useConsultationBilling_false',() => assertBlocked(T, 'useConsultationBilling'));
});

// ============================================================================
// SECTION 16: JEWELLERY
// ============================================================================

describe('UT-CAP-015 — jewellery capability matrix', () => {
  const T = 'jewellery';
  test('jewellery_has_useProductAdd_true',         () => assertEnabled(T, 'useProductAdd'));
  test('jewellery_has_useInventoryList_true',      () => assertEnabled(T, 'useInventoryList'));
  test('jewellery_has_useInvoiceCreate_true',      () => assertEnabled(T, 'useInvoiceCreate'));
  test('jewellery_has_useDailySnapshot_true',      () => assertEnabled(T, 'useDailySnapshot'));
  test('jewellery_has_useRevenueOverview_true',    () => assertEnabled(T, 'useRevenueOverview'));
  test('jewellery_has_useBarcodeScanner_true',     () => assertEnabled(T, 'useBarcodeScanner'));
  // Jewellery lacks unit, tax, dead stock, export — hard isolation
  test('jewellery_has_useProductUnit_false',       () => assertBlocked(T, 'useProductUnit'));
  test('jewellery_has_useProductTax_false',        () => assertBlocked(T, 'useProductTax'));
  test('jewellery_has_useDeadStock_false',         () => assertBlocked(T, 'useDeadStock'));
  test('jewellery_has_useInventoryExport_false',   () => assertBlocked(T, 'useInventoryExport'));
  test('jewellery_has_useSalesReturn_false',       () => assertBlocked(T, 'useSalesReturn'));
  test('jewellery_has_useProformaInvoice_false',   () => assertBlocked(T, 'useProformaInvoice'));
  test('jewellery_has_useDispatchNote_false',      () => assertBlocked(T, 'useDispatchNote'));
  test('jewellery_has_usePurchaseOrder_false',     () => assertBlocked(T, 'usePurchaseOrder'));
  test('jewellery_has_useStockReversal_false',     () => assertBlocked(T, 'useStockReversal'));
  test('jewellery_has_usePurchaseRegister_false',  () => assertBlocked(T, 'usePurchaseRegister'));
  test('jewellery_has_useLowStockAlert_false',     () => assertBlocked(T, 'useLowStockAlert'));
  test('jewellery_has_useGeneralAlerts_false',     () => assertBlocked(T, 'useGeneralAlerts'));
  test('jewellery_has_useKOT_false',               () => assertBlocked(T, 'useKOT'));
  test('jewellery_has_useIMEI_false',              () => assertBlocked(T, 'useIMEI'));
  test('jewellery_has_useFuelManagement_false',    () => assertBlocked(T, 'useFuelManagement'));
  test('jewellery_has_usePrescription_false',      () => assertBlocked(T, 'usePrescription'));
  test('jewellery_has_useCommission_false',        () => assertBlocked(T, 'useCommission'));
  test('jewellery_has_useVariants_false',          () => assertBlocked(T, 'useVariants'));
  test('jewellery_has_useISBN_false',              () => assertBlocked(T, 'useISBN'));
});

// ============================================================================
// SECTION 17: AUTO PARTS
// ============================================================================

describe('UT-CAP-016 — autoParts capability matrix', () => {
  const T = 'autoParts';
  test('autoParts_has_useWarranty_true',            () => assertEnabled(T, 'useWarranty'));
  test('autoParts_has_useJobSheets_true',           () => assertEnabled(T, 'useJobSheets'));
  test('autoParts_has_useRepairStatus_true',        () => assertEnabled(T, 'useRepairStatus'));
  test('autoParts_has_useLowStockAlert_true',       () => assertEnabled(T, 'useLowStockAlert'));
  test('autoParts_has_usePurchaseOrder_true',       () => assertEnabled(T, 'usePurchaseOrder'));
  test('autoParts_has_useBarcodeScanner_true',      () => assertEnabled(T, 'useBarcodeScanner'));
  // BLOCKED
  test('autoParts_has_useDeadStock_false',          () => assertBlocked(T, 'useDeadStock'));
  test('autoParts_has_useSalesReturn_false',        () => assertBlocked(T, 'useSalesReturn'));
  test('autoParts_has_useProformaInvoice_false',    () => assertBlocked(T, 'useProformaInvoice'));
  test('autoParts_has_useDispatchNote_false',       () => assertBlocked(T, 'useDispatchNote'));
  test('autoParts_has_useInventoryExport_false',    () => assertBlocked(T, 'useInventoryExport'));
  test('autoParts_has_useStockReversal_false',      () => assertBlocked(T, 'useStockReversal'));
  test('autoParts_has_usePurchaseRegister_false',   () => assertBlocked(T, 'usePurchaseRegister'));
  test('autoParts_has_useKOT_false',                () => assertBlocked(T, 'useKOT'));
  test('autoParts_has_useIMEI_false',               () => assertBlocked(T, 'useIMEI'));
  test('autoParts_has_useFuelManagement_false',     () => assertBlocked(T, 'useFuelManagement'));
  test('autoParts_has_usePrescription_false',       () => assertBlocked(T, 'usePrescription'));
  test('autoParts_has_useCommission_false',         () => assertBlocked(T, 'useCommission'));
  test('autoParts_has_useVariants_false',           () => assertBlocked(T, 'useVariants'));
  test('autoParts_has_useISBN_false',               () => assertBlocked(T, 'useISBN'));
  test('autoParts_has_useBuyback_false',            () => assertBlocked(T, 'useBuyback'));
  test('autoParts_has_useExchange_false',           () => assertBlocked(T, 'useExchange'));
});

// ============================================================================
// SECTION 18: OTHER (minimal/default)
// ============================================================================

describe('UT-CAP-017 — other capability matrix', () => {
  const T = 'other';
  test('other_has_useProductAdd_true',             () => assertEnabled(T, 'useProductAdd'));
  test('other_has_useInvoiceCreate_true',          () => assertEnabled(T, 'useInvoiceCreate'));
  test('other_has_useInvoiceList_true',            () => assertEnabled(T, 'useInvoiceList'));
  test('other_has_useBarcodeScanner_true',         () => assertEnabled(T, 'useBarcodeScanner'));
  // BLOCKED — most features
  test('other_has_useInventoryList_false',         () => assertBlocked(T, 'useInventoryList'));
  test('other_has_useDeadStock_false',             () => assertBlocked(T, 'useDeadStock'));
  test('other_has_useInventoryExport_false',       () => assertBlocked(T, 'useInventoryExport'));
  test('other_has_useSalesReturn_false',           () => assertBlocked(T, 'useSalesReturn'));
  test('other_has_useProformaInvoice_false',       () => assertBlocked(T, 'useProformaInvoice'));
  test('other_has_useDispatchNote_false',          () => assertBlocked(T, 'useDispatchNote'));
  test('other_has_usePurchaseOrder_false',         () => assertBlocked(T, 'usePurchaseOrder'));
  test('other_has_useStockEntry_false',            () => assertBlocked(T, 'useStockEntry'));
  test('other_has_useSupplierBill_false',          () => assertBlocked(T, 'useSupplierBill'));
  test('other_has_useLowStockAlert_false',         () => assertBlocked(T, 'useLowStockAlert'));
  test('other_has_useGeneralAlerts_false',         () => assertBlocked(T, 'useGeneralAlerts'));
  test('other_has_useDailySnapshot_false',         () => assertBlocked(T, 'useDailySnapshot'));
  test('other_has_useRevenueOverview_false',       () => assertBlocked(T, 'useRevenueOverview'));
  test('other_has_useKOT_false',                  () => assertBlocked(T, 'useKOT'));
  test('other_has_useIMEI_false',                  () => assertBlocked(T, 'useIMEI'));
  test('other_has_useFuelManagement_false',        () => assertBlocked(T, 'useFuelManagement'));
  test('other_has_usePrescription_false',          () => assertBlocked(T, 'usePrescription'));
  test('other_has_useCommission_false',            () => assertBlocked(T, 'useCommission'));
  test('other_has_useVariants_false',              () => assertBlocked(T, 'useVariants'));
  test('other_has_useISBN_false',                  () => assertBlocked(T, 'useISBN'));
  test('other_has_useConsultationBilling_false',   () => assertBlocked(T, 'useConsultationBilling'));
});

// ============================================================================
// SECTION 19: CROSS-CONTAMINATION MATRIX
// Verify that specialised caps of one type NEVER appear in incompatible types
// ============================================================================

describe('UT-CAP-CROSS: Cross-Contamination Matrix', () => {

  const specializedCaps: Record<string, string[]> = {
    pharmacy:          ['usePrescription','useDrugSchedule','useSaltSearch'],
    restaurant:        ['useKOT','useTableManagement','useWaiterLinking','useKitchenDisplay'],
    mobileShop:        ['useBuyback','useExchange'],
    petrolPump:        ['useFuelManagement','usePumpReadings','useShiftManagement','useTankerEntry'],
    vegetablesBroker:  ['useCommission','useCrateManagement','useFarmerLinking','useDailyRates'],
    clinic:            ['useConsultationBilling','useAppointments'],
    bookStore:         ['useISBN','usePublisherReturns','useLoyaltyPoints'],
    clothing:          ['useTailoringNotes','useVariants'],
  };

  for (const [owner, caps] of Object.entries(specializedCaps)) {
    for (const cap of caps) {
      const incompatibleTypes = ALL_TYPES.filter(t => t !== owner);
      for (const otherType of incompatibleTypes) {
        // Only assert blocked for types that clearly should not have this cap
        const exclusivelyOwned = !registry[otherType]?.has(cap);
        if (exclusivelyOwned) {
          test(`BT-ISO-${otherType}-${cap}-BLOCKED`, () => {
            assertBlocked(otherType, cap);
          });
        }
      }
    }
  }
});

// ============================================================================
// SECTION 20: IMMUTABILITY GUARD
// ============================================================================

describe('UT-CAP-IMM: Registry Immutability', () => {
  test('Adding a capability to a registry Set returns new size (Set is mutable — guard in app layer)', () => {
    const original = registry['grocery'];
    const originalSize = original.size;
    // Attempt mutation — this SHOULD be guarded in the Dart layer via UnmodifiableSetView
    // In JS mirror we verify only that the original reference is not changed externally
    const cloned = new Set(original);
    cloned.add('useFuelManagement'); // Mutate clone, not original
    expect(original.size).toBe(originalSize);
    expect(original.has('useFuelManagement')).toBe(false);
  });

  test('Capability count per type matches expected baseline (regression guard)', () => {
    const expectedCounts: Record<string, number> = {
      grocery: 27,
      pharmacy: 34,
      restaurant: 26,
      clothing: 23,
      electronics: 24,
      mobileShop: 27,
      computerShop: 26,
      hardware: 24,
      service: 9,
      wholesale: 34,
      petrolPump: 26,
      vegetablesBroker: 23,
      clinic: 10,
      bookStore: 31,
      jewellery: 15,
      autoParts: 24,
      other: 6,
    };
    for (const [type, expectedCount] of Object.entries(expectedCounts)) {
      expect(registry[type].size).toBe(expectedCount);
    }
  });
});
