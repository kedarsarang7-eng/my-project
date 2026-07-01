// Subscription tier-gating layer (subscription-plan-tiers feature). These
// imports wire the validated, machine-consumable Gating_Config on top of the
// hard-isolation registry below. The dependency is intentionally one extra
// layer: hard isolation stays the source of truth and is never widened.
import '../subscription/subscription_tier.dart';
import '../subscription/gating_config.dart';
import '../subscription/plan_mapping_builder.dart';
import '../subscription/plan_mapping_validator.dart';

/// Business Capabilities for Hard Isolation
///
/// This file defines granual business capabilities and maps them
/// to specific BusinessTypes. This serves as the "Permission Matrix"
/// for the application.
enum BusinessCapability {
  // ==============================================================================
  // 1. Product / Item Management
  // ==============================================================================
  useProductAdd,
  useProductName,
  useProductSalePrice,
  useProductStockQty,
  useProductUnit,
  useProductTax,
  useProductCategory,

  // ==============================================================================
  // 2. Inventory Management
  // ==============================================================================
  useInventoryList,
  useVisibleStock,
  useDeadStock,
  useInventorySearch,
  useInventoryExport,

  // ==============================================================================
  // 3. Invoice Management
  // ==============================================================================
  useInvoiceList,
  useInvoiceSearch,
  useInvoiceCreate,
  useSalesReturn,
  useProformaInvoice,
  useDispatchNote,

  // ==============================================================================
  // 4. Alerts & Business Health
  // ==============================================================================
  useLowStockAlert,
  useGeneralAlerts,
  useDailySnapshot,
  useRevenueOverview,

  // ==============================================================================
  // 5. Purchase & Stock Flow
  // ==============================================================================
  usePurchaseOrder,
  useStockEntry,
  useStockReversal,
  useSupplierBill,
  usePurchaseRegister,

  // ==============================================================================
  // LEGACY / SPECIALIZED CAPABILITIES (Retained for backward compat)
  // ==============================================================================
  // Prescription / Medical
  usePrescription,
  useDoctorLinking,
  usePatientRegistry,
  useDrugSchedule,
  useSaltSearch, // New: Pharmacy specific
  // UI / Input Methods
  useBarcodeScanner,
  useScanOCR,
  useVoiceInput, // Future ready
  // Inventory / Stock (Legacy aliases or specific behaviors)
  useBatchExpiry,
  useStockManagement, // Alias for useStockEntry + useVisibleStock
  useLowStockAlerts, // Alias for useLowStockAlert
  useMultiUnit, // Box/Pcs handling (Wholesale)
  useNegativeStock, // Allow selling without stock (optional)
  // Hardware / Dimensions
  useDimensions, // Hardware (Sq.ft/Mtr)
  useLooseQuantities,

  // Clothing / Variants
  useVariants, // Clothing (Size/Color)
  useTailoringNotes,

  // Electronics / Serial
  useIMEI, // Electronics
  useWarranty, // Electronics
  useBuyback, // Mobile Shop
  useExchange,

  // Restaurant
  useKOT,
  useTableManagement,
  useWaiterLinking,
  useKitchenDisplay,

  // Petrol Pump
  useFuelManagement,
  usePumpReadings,
  useShiftManagement,
  useVehicleDetails,
  useTankerEntry,

  // Services
  useJobSheets,
  useRepairStatus,
  useServiceStatus,
  useLaborCharges,

  // Broker / Mandi
  useCommission,
  useCrateManagement,
  useFarmerLinking,
  useDailyRates,

  // Wholesale / B2B
  useCreditManagement,
  useTransportDetails, // Delivery Challan/Vehicle No
  useCreditLimit,

  // Clinical / Medical Practice
  useAppointments,
  useConsultationBilling,

  // Book Store
  useISBN,
  usePublisherReturns,
  useSchoolOrders,
  useConsignmentSettlement,

  // Jewellery
  useLoyaltyPoints,
  useGoldRate,
  useGoldRateAlert,
  useMakingCharges,
  useHallmark,
  useOldGoldExchange,
  useCustomOrders,
  useGoldSchemes,
  useJewelleryRepair,

  // Decoration & Catering
  useDecorationThemes,
  useCateringMenu,
  useCateringKitchen,
  useVenueManagement,
  useEventBooking,
  useEventInventory,
  useEventStaffAllocation,
  useEventReports,

  // School ERP
  useStudentRegistry,
  useFeeCollection,
  useAttendanceTracking,
  useTimetable,
  useTestResults,
  useCertificates,
  useScholarshipDiscount,
  useParentNotifications,
  useCourseMaterial,
  useDemoClasses,

  // General / Shared
  useBatchManagement,
  useStaffManagement,
}

/// Registry that maps Business Types to their allowed Capabilities
///
/// RULE: Hard Isolation. If a capability is not listed here,
/// it is STRICTLY FORBIDDEN for that business type.
final Map<String, Set<BusinessCapability>> businessCapabilityRegistry = {
  'grocery': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,
    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useDeadStock,
    BusinessCapability.useInventorySearch,
    // Export CSV: ⚠️ (Optional/Limited) - Excluding for now or add if "Limited" means yes
    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    // Returns: ⚠️
    // Proforma: ❌
    // Dispatch: ❌
    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useGeneralAlerts,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,
    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    // Reversal: ⚠️
    BusinessCapability.useSupplierBill,
    // Purchase Register: ⚠️

    // Legacy / Extras
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useScanOCR,
    BusinessCapability.useStockManagement,
    BusinessCapability.useLowStockAlerts,
    BusinessCapability.useBatchExpiry,
    BusinessCapability.useVoiceInput,
  },
  'pharmacy': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,
    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useDeadStock,
    BusinessCapability.useInventorySearch,
    // Export CSV: ⚠️
    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useSalesReturn,
    // Proforma: ⚠️
    // Dispatch: ⚠️
    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useGeneralAlerts,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,
    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useStockReversal,
    BusinessCapability.useSupplierBill,
    BusinessCapability
        .usePurchaseRegister, // ⚠️ -> Included based on 'Optional' logic or check
    // Specialized
    BusinessCapability.usePrescription,
    BusinessCapability.useDoctorLinking,
    BusinessCapability.usePatientRegistry,
    BusinessCapability.useDrugSchedule,
    BusinessCapability.useSaltSearch,
    BusinessCapability.useBatchExpiry,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useScanOCR,
    BusinessCapability.useStockManagement,
    BusinessCapability.useLowStockAlerts,
  },
  'restaurant': {
    // 1. Product
    // Add Item: ⚠️ (Limited)
    // Item Name: ⚠️
    // Sale Price: ⚠️
    // Stock Qty: ⚠️
    // Unit: ⚠️
    // Tax Select: ⚠️
    // Category: ⚠️
    // NOTE: Even if limited, we enable the base capability, logic handles limits
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    // List: ⚠️
    // Stock: ⚠️
    // Dead Stock: ⚠️ (Warining/Optional) -> Checklist says 'Limited' or 'Optional', enabling for now
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useDeadStock,
    BusinessCapability.useInventorySearch,
    // Export: ❌

    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    // Returns: ⚠️
    // Proforma: ❌
    // Dispatch: ❌

    // 4. Alerts
    BusinessCapability.useLowStockAlert, // List says ✅
    BusinessCapability.useGeneralAlerts,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    // Reversal: ⚠️
    BusinessCapability.useSupplierBill,
    // Register: ⚠️

    // Specialized
    BusinessCapability.useKOT,
    BusinessCapability.useTableManagement,
    BusinessCapability.useWaiterLinking,
    BusinessCapability.useKitchenDisplay,
  },
  'clothing': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    // Dead Stock: ⚠️
    BusinessCapability.useInventorySearch,
    // Export: ⚠️

    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    // Clothing vertical remediation (Requirement 11.4): grant useSalesReturn
    // so the clothing sidebar can surface Sales Return / Exchange flows.
    BusinessCapability.useSalesReturn,
    // Proforma: ⚠️
    // Dispatch: ⚠️

    // 4. Alerts
    // Low Stock Alert: ⚠️
    // Alerts: ⚠️
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    // Reversal: ⚠️
    BusinessCapability.useSupplierBill,
    // Register: ⚠️

    // Specialized
    BusinessCapability.useVariants,
    BusinessCapability.useTailoringNotes,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useScanOCR,
    BusinessCapability.useStockManagement,
  },
  'electronics': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    // Dead Stock: ⚠️
    BusinessCapability.useInventorySearch,
    // Export: ⚠️

    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    // Returns: ⚠️
    // Proforma: ⚠️
    // Dispatch: ⚠️

    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    // Alerts: ⚠️
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    // Reversal: ⚠️
    BusinessCapability.useSupplierBill,
    // Register: ⚠️

    // Specialized
    BusinessCapability.useIMEI,
    BusinessCapability.useWarranty,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useScanOCR,
    BusinessCapability.useStockManagement,
  },
  'mobileShop': {
    // Checkbox says same as Electronics mostly
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory - Same as Electronics
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useInventorySearch,

    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,

    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useSupplierBill,

    // Specialized
    BusinessCapability.useIMEI,
    BusinessCapability.useWarranty,
    BusinessCapability.useBuyback,
    BusinessCapability.useExchange,
    BusinessCapability.useJobSheets, // For repairs
    BusinessCapability.useRepairStatus,
    BusinessCapability.useStockManagement,
    BusinessCapability.useBarcodeScanner,
  },
  'computerShop': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useInventorySearch,

    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,

    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useSupplierBill,

    // Specialized
    BusinessCapability.useIMEI,
    BusinessCapability.useWarranty,
    BusinessCapability.useJobSheets, // Custom builds/Repairs
    BusinessCapability.useRepairStatus,
    BusinessCapability.useStockManagement,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useMultiUnit, // Parts
  },
  'hardware': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useInventorySearch,
    // Export: ⚠️

    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    // Manifest reconciliation (bugfix.md 2.5/2.6): the hardware `modules` list
    // in business_type_config.dart advertises 'returns' and 'quotations'.
    // Grant the matching capabilities so the module manifest and the isolation
    // registry agree, and so the hardware sidebar's `return_inwards` /
    // `proforma_bids` items (gated on these capabilities) surface correctly.
    BusinessCapability.useSalesReturn, // ↔ 'returns' module
    BusinessCapability.useProformaInvoice, // ↔ 'quotations' module
    // Dispatch: ⚠️ (no 'dispatch' module advertised — intentionally not granted)

    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    // Alerts: ⚠️
    BusinessCapability.useDailySnapshot, // ⚠️
    BusinessCapability.useRevenueOverview, // ⚠️
    // 5. Purchase
    BusinessCapability
        .usePurchaseOrder, // ❌ (Checklist says NO for Purchase Orders for Hardware? Wait, Checklist says ✅ for Purchase Orders for Hardware)
    // Checking Checklist: Hardware -> Purchase Orders ✅
    BusinessCapability.useStockEntry,
    // Reversal: ⚠️
    BusinessCapability.useSupplierBill,
    // Register: ⚠️

    // Specialized
    BusinessCapability.useDimensions,
    BusinessCapability.useLooseQuantities,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useStockManagement,
    BusinessCapability.useTransportDetails,
    // Multi-unit handling (bugfix.md 2.13): hardware works in mixed units
    // (ft↔mtr, box↔pcs). Grant useMultiUnit so the line-item flow can offer
    // unit conversion via UnitConversionService. Hardware entry ONLY — no
    // other vertical's capability set is touched.
    BusinessCapability.useMultiUnit,
    // Contractor credit (bugfix.md 2.7): contractor credit IS in scope for
    // hardware (HardwareCreditControlScreen + hardware_contractor_credit module
    // exist, and the hardware dashboard's "Overdue Contractor Bills" alert is
    // gated on accessCreditLimit). Grant the credit capabilities so
    // accessCreditLimit resolves true and the alert / hardware_credit_control
    // sidebar item are reachable rather than dead.
    BusinessCapability.useCreditManagement,
    BusinessCapability.useCreditLimit,
  },
  'service': {
    // 1. Product (Service has ❌ for most item management in checklist?? No, Checklist says:
    // Service: Add Item ❌, Item Name ❌... Wait.
    // Checklist: Service -> Add Item ❌.
    // This implies Service business doesn't add "Items" but "Services" or "Jobs".
    // Keeping STRICT enabled only for what's checked.
    // However, they likely need SOME way to define services.
    // Checklist:
    // Add Item: ❌
    // Item Name: ❌
    // Sale Price: ❌
    // Stock Qty: ❌
    // Unit: ❌
    // Tax Select: ❌
    // Category: ❌
    // 2. Inventory
    // Inventory List: ❌
    // Available Stock: ❌
    // Dead Stock: ❌
    // Search: ❌
    // Export CSV: ❌
    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    // Returns: ❌
    // Proforma: ⚠️
    // Dispatch: ❌
    // 4. Alerts
    // Low Stock: ❌
    // Alerts: ⚠️
    // Daily Snapshot: ⚠️
    // Revenue: ⚠️
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,
    // 5. Purchase
    // Purchase Orders: ❌
    // Stock Entry: ❌
    // Reversal: ❌
    // Supplier Bills: ❌
    // Purchase Register: ❌

    // Specialized
    BusinessCapability.useJobSheets,
    BusinessCapability.useServiceStatus,
    BusinessCapability.useLaborCharges,
    BusinessCapability.useAppointments,
  },
  'wholesale': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useDeadStock,
    BusinessCapability.useInventorySearch,
    BusinessCapability.useInventoryExport, // ✅
    // 3. Invoice
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useSalesReturn,
    BusinessCapability.useProformaInvoice, // ✅
    BusinessCapability.useDispatchNote, // ✅
    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useGeneralAlerts,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useStockReversal,
    BusinessCapability.useSupplierBill,
    BusinessCapability.usePurchaseRegister,

    // Specialized
    BusinessCapability.useStockManagement,
    BusinessCapability.useMultiUnit,
    BusinessCapability.useCreditManagement,
    BusinessCapability.useCreditLimit,
    BusinessCapability.useTransportDetails,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useBatchExpiry,
  },
  'petrolPump': {
    // 1. Product
    // Add Item: ⚠️
    // Item Name: ⚠️
    // Sale Price: ⚠️
    // Stock Qty: ⚠️
    // Unit: ⚠️
    // Tax Select: ⚠️
    // Category: ⚠️
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    // Inventory List: ⚠️
    // Available Stock: ⚠️
    // Dead Stock: ❌
    // Search: ⚠️
    // Export: ❌
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useInventorySearch,

    // 3. Invoice
    BusinessCapability.useInvoiceList,
    // Search: ⚠️
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate, // ✅ in logic, though checklist says ✅
    // Returns: ⚠️
    // Proforma: ❌
    // Dispatch: ❌

    // 4. Alerts
    // Low Stock: ⚠️
    // Alerts: ⚠️
    // Snapshot: ⚠️
    // Revenue: ⚠️
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    // PO: ⚠️
    // Entry: ⚠️
    // Reversal: ❌
    // Bills: ⚠️
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useSupplierBill,

    // Specialized
    BusinessCapability.useFuelManagement,
    BusinessCapability.usePumpReadings,
    BusinessCapability.useShiftManagement,
    BusinessCapability.useVehicleDetails,
    BusinessCapability.useTankerEntry,
    BusinessCapability.useStockManagement, // Fuel stock
  },
  'vegetablesBroker': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    // Tax: ⚠️ (Mandi often no tax)
    // Category: ✅
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    // Dead Stock: ⚠️
    BusinessCapability.useInventorySearch,
    // Export: ⚠️

    // 3. Invoice
    // Invoice List: ⚠️
    // Search: ⚠️
    // Create: ⚠️
    // Returns: ⚠️
    // Proforma: ⚠️
    // Dispatch: ⚠️
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,

    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    // Alerts: ⚠️
    // Snapshot: ⚠️
    // Revenue: ⚠️
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    // Reversal: ⚠️
    BusinessCapability.useSupplierBill, // ⚠️
    // Register: ⚠️

    // Specialized
    BusinessCapability.useCommission,
    BusinessCapability.useCrateManagement,
    BusinessCapability.useFarmerLinking,
    BusinessCapability.useDailyRates,
    BusinessCapability.useCreditManagement,
  },
  'clinic': {
    // 1. Product
    // Add Item: ❌ (Doctors don't add items usually, they add Services/Meds in a different flow)
    // Item Name: ❌
    // ... All ❌ for Product ??
    // Checklist: Clinic -> ❌ for all Product features.
    // 2. Inventory
    // All ❌
    // 3. Invoice
    // Invoice List: ⚠️
    // Search: ⚠️
    // Create: ⚠️
    // Returns: ❌
    // Proforma: ❌
    // Dispatch: ❌
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useInvoiceCreate,

    // 4. Alerts
    // Low Stock: ❌
    // Alerts: ⚠️
    // Snapshot: ⚠️
    // Revenue: ⚠️
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    // All ❌

    // Specialized
    BusinessCapability.useAppointments,
    BusinessCapability.useConsultationBilling,
    BusinessCapability.usePatientRegistry,
    BusinessCapability.usePrescription,
    BusinessCapability.useDoctorLinking,
  },
  'bookStore': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useDeadStock,
    BusinessCapability.useInventorySearch,
    BusinessCapability.useInventoryExport,

    // 3. Invoice
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useSalesReturn,

    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useGeneralAlerts,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useSupplierBill,
    BusinessCapability.usePurchaseRegister,

    // Specialized
    BusinessCapability.useISBN,
    BusinessCapability.usePublisherReturns,
    BusinessCapability.useLoyaltyPoints,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useScanOCR,
    BusinessCapability.useStockManagement,
    BusinessCapability.useSchoolOrders,
    BusinessCapability.useConsignmentSettlement,
  },
  // ──────────────────────────────────────────────────────────────────────────
  // Jewellery vertical — Phase 3 capability grant (Requirement 9.1, 9.2, 9.5).
  //
  // Blast radius: this entry ONLY. The 8 new domain capabilities
  // (useGoldRate … useJewelleryRepair) are granted exclusively to jewellery
  // and to no other business type. The two shared capabilities (useProductUnit,
  // useProductTax) already exist in other type grants — they are merely ADDED
  // here; no other type's set is modified.
  // ──────────────────────────────────────────────────────────────────────────
  'jewellery': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit, // shared — also granted to other types
    BusinessCapability.useProductTax, // shared — also granted to other types
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useInventorySearch,

    // 3. Invoice
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,

    // 4. Alerts
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useSupplierBill,

    // Specialized (existing)
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useLoyaltyPoints,
    BusinessCapability.useStockManagement,

    // Jewellery-domain capabilities (Requirement 9.1, 9.2, 9.5)
    // These 8 capabilities are granted ONLY to jewellery — no other type.
    BusinessCapability.useGoldRate,
    BusinessCapability.useGoldRateAlert,
    BusinessCapability.useMakingCharges,
    BusinessCapability.useHallmark,
    BusinessCapability.useOldGoldExchange,
    BusinessCapability.useCustomOrders,
    BusinessCapability.useGoldSchemes,
    BusinessCapability.useJewelleryRepair,
  },
  'autoParts': {
    // 1. Product
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,

    // 2. Inventory
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useInventorySearch,

    // 3. Invoice
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,

    // 4. Alerts
    BusinessCapability.useLowStockAlert,
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,

    // 5. Purchase
    BusinessCapability.usePurchaseOrder,
    BusinessCapability.useStockEntry,
    BusinessCapability.useSupplierBill,

    // Specialized
    BusinessCapability.useJobSheets,
    BusinessCapability.useRepairStatus,
    BusinessCapability.useWarranty,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useStockManagement,
  },
  'decorationCatering': {
    // Service-only: no product or inventory capabilities
    // 3. Invoice
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
    BusinessCapability.useProformaInvoice,

    // Specialized (vertical)
    BusinessCapability.useDecorationThemes,
    BusinessCapability.useCateringMenu,
    BusinessCapability.useCateringKitchen,
    BusinessCapability.useVenueManagement,
    BusinessCapability.useEventBooking,
    BusinessCapability.useEventInventory,
    BusinessCapability.useEventStaffAllocation,
    BusinessCapability.useEventReports,
    BusinessCapability.useAppointments,
    BusinessCapability.useLaborCharges,
  },
  'schoolErp': {
    // Service-only: no product or inventory capabilities
    // 3. Invoice
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,

    // Specialized (vertical)
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
    BusinessCapability.useAppointments,
    BusinessCapability.useStaffManagement,
    BusinessCapability.useBatchManagement,

    // Alerts
    BusinessCapability.useDailySnapshot,
    BusinessCapability.useRevenueOverview,
    BusinessCapability.useGeneralAlerts,
  },
  'other': {
    // Default safe features
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useStockManagement,
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useInvoiceList,
  },
};

// =============================================================================
// Subscription tier-gating layer (subscription-plan-tiers feature, Req 3.3,
// 19.1, 19.5).
//
// This layer is ADDITIVE. It sits on top of the hard-isolation
// `businessCapabilityRegistry` above and narrows access by subscription tier.
// It never widens access: a capability that is not registered for a business
// type can never be granted at any tier (hard isolation remains the source of
// truth). Existing isolation consumers (e.g. `FeatureResolver`) are untouched.
//
// The mapping is derived deterministically and only takes effect once it has
// been independently validated:
//
//   PlanMappingBuilder.buildAll()
//     -> PlanMappingValidator.validateAll()
//     -> GatingConfig.fromMappings()
//
// If the mapping fails validation, or the pipeline cannot run for any reason,
// the validated config is treated as unavailable and tier-gating defaults to
// DENY (fail-safe, Req 3.3). The hard-isolation check still applies in every
// case, so denial is the conservative outcome.
// =============================================================================

/// Tier-aware capability gating built on top of hard isolation.
///
/// [TierGating] consults a validated [GatingConfig] to decide whether a
/// business type may use a capability at a given subscription tier. It is a
/// thin, additive layer over [businessCapabilityRegistry]:
///
/// * Hard isolation always wins — an unregistered capability is denied at every
///   tier (the tier layer can only narrow, never widen access).
/// * The Gating_Config must be produced by the builder, pass the independent
///   validator, and serialize cleanly before it can grant anything. Until then,
///   and whenever no validated grant exists for a `(type, tier)`, the answer is
///   DENY (default-deny, Req 3.3).
///
/// The validated config is built lazily and cached so the (pure, deterministic)
/// pipeline runs at most once per process. [resetCache] clears it, which is
/// useful for tests that inject a different registry state.
class TierGating {
  TierGating._();

  /// Cached, lazily-built validated config. `null` means "not yet built";
  /// after a build attempt it is either a valid [GatingConfig] or stays `null`
  /// when validation/serialization failed (so gating keeps defaulting to deny).
  static GatingConfig? _validatedConfig;

  /// Whether a build has been attempted. Distinguishes "not built yet" from
  /// "built but unavailable" so a failed build is not retried on every call.
  static bool _buildAttempted = false;

  /// Returns the validated [GatingConfig], or `null` when it is unavailable.
  ///
  /// The config is built once (builder -> validator -> Gating_Config) and
  /// cached. If validation reports any violation, or the pipeline throws, the
  /// result is `null` and the caller must default to deny (Req 3.3).
  static GatingConfig? get validatedConfig {
    if (_buildAttempted) {
      return _validatedConfig;
    }
    _buildAttempted = true;
    _validatedConfig = _buildValidatedConfig();
    return _validatedConfig;
  }

  /// Builds the Gating_Config and only returns it when it is fully validated.
  ///
  /// Any failure (build infeasibility, validation violations, serialization
  /// rejection, or any unexpected error) collapses to `null` so tier-gating
  /// fails safe to deny.
  static GatingConfig? _buildValidatedConfig() {
    try {
      final mappings = PlanMappingBuilder().buildAll();
      final result = PlanMappingValidator().validateAll(mappings);
      if (!result.isValid) {
        // The mapping did not survive every invariant; do not let it take
        // effect (Req 3.3 default deny).
        return null;
      }
      return GatingConfig.fromMappings(mappings);
    } catch (_) {
      // Fail-safe: never let an error widen access. Deny by returning null.
      return null;
    }
  }

  /// Whether [businessType] may use [capability] at [tier].
  ///
  /// Two gates must both pass:
  /// 1. **Hard isolation** — [capability] must be a Registered_Capability for
  ///    [businessType] in [businessCapabilityRegistry] (the same source of
  ///    truth used by `FeatureResolver`). This ensures the tier layer can never
  ///    grant a forbidden capability.
  /// 2. **Tier grant** — the validated Gating_Config must grant [capability] to
  ///    [businessType] at [tier]. When the config is unavailable, or has no
  ///    grant for that `(type, tier)`, the result is `false` (default deny,
  ///    Req 3.3).
  static bool isAllowedAtTier(
    String businessType,
    BusinessCapability capability,
    SubscriptionTier tier,
  ) {
    final typeKey = _normalizeType(businessType);

    // Gate 1: hard isolation is the source of truth and is never widened.
    final registered = businessCapabilityRegistry[typeKey];
    if (registered == null || !registered.contains(capability)) {
      return false;
    }

    // Gate 2: a validated tier grant must exist (default deny otherwise).
    final config = validatedConfig;
    if (config == null) {
      return false;
    }
    return config.capabilitiesFor(typeKey, tier).contains(capability);
  }

  /// The cumulative set of capabilities granted to [businessType] at [tier]
  /// under the validated Gating_Config.
  ///
  /// Returns an empty set when the config is unavailable or has no grant for
  /// the `(type, tier)` pair (default deny, Req 3.3). The returned set is always
  /// a subset of the registered capabilities for the type (hard isolation), so
  /// it never widens access.
  static Set<BusinessCapability> capabilitiesForTier(
    String businessType,
    SubscriptionTier tier,
  ) {
    final typeKey = _normalizeType(businessType);
    final config = validatedConfig;
    if (config == null) {
      return const <BusinessCapability>{};
    }
    final registered =
        businessCapabilityRegistry[typeKey] ?? const <BusinessCapability>{};
    final granted = config.capabilitiesFor(typeKey, tier);
    // Intersect with hard isolation as a belt-and-suspenders guard so the tier
    // layer can only ever narrow the registered set, never widen it.
    return granted.intersection(registered);
  }

  /// Normalizes a business-type string to a `businessCapabilityRegistry` key.
  ///
  /// Accepts both raw keys (e.g. `'grocery'`) and enum-style strings
  /// (e.g. `'BusinessType.grocery'`), mirroring the normalization used by the
  /// existing isolation layer so callers can pass either form.
  static String _normalizeType(String type) {
    String normalized = type;
    if (normalized.contains('.')) {
      normalized = normalized.split('.').last;
    }
    final lower = normalized.toLowerCase();
    if (lower == 'academiccoaching' ||
        lower == 'academic_coaching' ||
        lower == 'schoolerp' ||
        lower == 'school_erp') {
      return 'schoolErp';
    }
    if (lower == 'mobileshop') {
      return 'mobileShop';
    }
    if (lower == 'computershop') {
      return 'computerShop';
    }
    if (lower == 'petrolpump') {
      return 'petrolPump';
    }
    if (lower == 'vegetablesbroker') {
      return 'vegetablesBroker';
    }
    if (lower == 'bookstore') {
      return 'bookStore';
    }
    if (lower == 'autoparts') {
      return 'autoParts';
    }
    if (lower == 'decorationcatering') {
      return 'decorationCatering';
    }
    return normalized;
  }

  /// Clears the cached validated config so the next access rebuilds it.
  ///
  /// Intended for tests (e.g. the integration test that exercises the full
  /// pipeline) that need a fresh build; not used on the normal runtime path.
  static void resetCache() {
    _validatedConfig = null;
    _buildAttempted = false;
  }
}
