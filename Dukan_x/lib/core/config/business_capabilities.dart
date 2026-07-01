import '../../models/business_type.dart';
import '../../core/isolation/feature_resolver.dart' as iso;
import '../../core/isolation/business_capability.dart';

/// Defines what features are available for each business type
/// Now powered by the Hard Isolation Registry.
class BusinessCapabilities {
  // ==============================================================================
  // 1. PRODUCT / ITEM MANAGEMENT
  // ==============================================================================
  final bool accessProductAdd;
  final bool accessProductName;
  final bool accessProductSalePrice;
  final bool accessProductStockQty;
  final bool accessProductUnit;
  final bool accessProductTax;
  final bool accessProductCategory;

  // ==============================================================================
  // 2. INVENTORY MANAGEMENT
  // ==============================================================================
  final bool accessInventoryList;
  final bool accessVisibleStock;
  final bool accessDeadStock;
  final bool accessInventorySearch;
  final bool accessInventoryExport;

  // ==============================================================================
  // 3. INVOICE MANAGEMENT
  // ==============================================================================
  final bool accessInvoiceList;
  final bool accessInvoiceSearch;
  final bool accessInvoiceCreate;
  final bool accessSalesReturn;
  final bool accessProformaInvoice;
  final bool accessDispatchNote;

  // ==============================================================================
  // 4. ALERTS & BUSINESS HEALTH
  // ==============================================================================
  final bool accessLowStockAlert;
  final bool accessGeneralAlerts;
  final bool accessDailySnapshot;
  final bool accessRevenueOverview;

  // ==============================================================================
  // 5. PURCHASE & STOCK FLOW
  // ==============================================================================
  final bool accessPurchaseOrder;
  final bool accessStockEntry;
  final bool accessStockReversal;
  final bool accessSupplierBill;
  final bool accessPurchaseRegister;

  // ==============================================================================
  // LEGACY / SPECIALIZED
  // ==============================================================================
  final bool supportsBarcodeScan;
  final bool supportsTextOCR;
  final bool supportsExpiry;
  final bool supportsBatch;
  final bool supportsSerialNumber; // For IMEI
  final bool supportsStock;
  final bool supportsGymMode; // E.g. for service business
  final bool supportsPrescriptions;
  final String ocrFocus; // Description for UI hint

  // Specialized Extras
  final bool accessKOT;
  final bool accessTableManagement;
  final bool accessCreditLimit;
  final bool accessServiceStatus;

  const BusinessCapabilities({
    // 1. Product
    required this.accessProductAdd,
    required this.accessProductName,
    required this.accessProductSalePrice,
    required this.accessProductStockQty,
    required this.accessProductUnit,
    required this.accessProductTax,
    required this.accessProductCategory,

    // 2. Inventory
    required this.accessInventoryList,
    required this.accessVisibleStock,
    required this.accessDeadStock,
    required this.accessInventorySearch,
    required this.accessInventoryExport,

    // 3. Invoice
    required this.accessInvoiceList,
    required this.accessInvoiceSearch,
    required this.accessInvoiceCreate,
    required this.accessSalesReturn,
    required this.accessProformaInvoice,
    required this.accessDispatchNote,

    // 4. Alerts
    required this.accessLowStockAlert,
    required this.accessGeneralAlerts,
    required this.accessDailySnapshot,
    required this.accessRevenueOverview,

    // 5. Purchase
    required this.accessPurchaseOrder,
    required this.accessStockEntry,
    required this.accessStockReversal,
    required this.accessSupplierBill,
    required this.accessPurchaseRegister,

    // Legacy
    required this.supportsBarcodeScan,
    required this.supportsTextOCR,
    required this.supportsExpiry,
    required this.supportsBatch,
    required this.supportsSerialNumber,
    required this.supportsStock,
    required this.supportsGymMode,
    required this.supportsPrescriptions,
    required this.ocrFocus,
    required this.accessKOT,
    required this.accessTableManagement,
    required this.accessCreditLimit,
    required this.accessServiceStatus,
  });

  /// Get capabilities for a specific business type
  /// Derives strict permissions from [iso.FeatureResolver].
  static BusinessCapabilities get(BusinessType type) {
    final t = type.name;

    return BusinessCapabilities(
      // 1. Product
      accessProductAdd: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProductAdd,
      ),
      accessProductName: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProductName,
      ),
      accessProductSalePrice: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProductSalePrice,
      ),
      accessProductStockQty: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProductStockQty,
      ),
      accessProductUnit: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProductUnit,
      ),
      accessProductTax: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProductTax,
      ),
      accessProductCategory: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProductCategory,
      ),

      // 2. Inventory
      accessInventoryList: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useInventoryList,
      ),
      accessVisibleStock: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useVisibleStock,
      ),
      accessDeadStock: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useDeadStock,
      ),
      accessInventorySearch: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useInventorySearch,
      ),
      accessInventoryExport: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useInventoryExport,
      ),

      // 3. Invoice
      accessInvoiceList: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useInvoiceList,
      ),
      accessInvoiceSearch: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useInvoiceSearch,
      ),
      accessInvoiceCreate: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useInvoiceCreate,
      ),
      accessSalesReturn: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useSalesReturn,
      ),
      accessProformaInvoice: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useProformaInvoice,
      ),
      accessDispatchNote: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useDispatchNote,
      ),

      // 4. Alerts
      accessLowStockAlert: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useLowStockAlert,
      ),
      accessGeneralAlerts: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useGeneralAlerts,
      ),
      accessDailySnapshot: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useDailySnapshot,
      ),
      accessRevenueOverview: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useRevenueOverview,
      ),

      // 5. Purchase
      accessPurchaseOrder: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.usePurchaseOrder,
      ),
      accessStockEntry: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useStockEntry,
      ),
      accessStockReversal: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useStockReversal,
      ),
      accessSupplierBill: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useSupplierBill,
      ),
      accessPurchaseRegister: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.usePurchaseRegister,
      ),

      // Legacy
      supportsBarcodeScan: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useBarcodeScanner,
      ),
      supportsTextOCR: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useScanOCR,
      ),
      supportsExpiry: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useBatchExpiry,
      ),
      supportsBatch: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useBatchExpiry,
      ),
      supportsSerialNumber: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useIMEI,
      ),
      supportsStock: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useStockManagement,
      ),
      supportsGymMode: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useJobSheets,
      ),
      supportsPrescriptions: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.usePrescription,
      ),
      ocrFocus: _getOcrFocus(type),
      accessKOT: iso.FeatureResolver.canAccess(t, BusinessCapability.useKOT),
      accessTableManagement: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useTableManagement,
      ),
      accessCreditLimit: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useCreditLimit,
      ),
      accessServiceStatus: iso.FeatureResolver.canAccess(
        t,
        BusinessCapability.useServiceStatus,
      ),
    );
  }

  static String _getOcrFocus(BusinessType type) {
    switch (type) {
      case BusinessType.grocery:
        return 'Name, Rate, Qty';
      case BusinessType.pharmacy:
      case BusinessType.clinic:
      case BusinessType.wholesale:
        return 'Name, Batch, Expiry, MRP';
      case BusinessType.clothing:
        return 'Name, Size, MRP';
      case BusinessType.electronics:
      case BusinessType.computerShop:
        return 'Name, Model, Serial/IMEI';
      case BusinessType.mobileShop:
        return ''; // OCR denied — useScanOCR not granted (Phase 8 decision)
      case BusinessType.hardware:
        return 'Name, Size, Brand, Rate';
      default:
        return 'Product Details';
    }
  }
}
