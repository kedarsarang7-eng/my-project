import '../../models/business_type.dart';
import '../../core/isolation/feature_resolver.dart' as iso;
import '../../core/isolation/business_capability.dart';

/// Central logic for enabling/disabling features based on Business Type
/// Delegates to strict [iso.FeatureResolver] enforcement.
class FeatureResolver {
  final BusinessType type;

  FeatureResolver(this.type);

  // --- CORE MODES (Derived from Type) ---
  // These are convenience getters for layout switching,
  // but specific features should use capabilities below.

  bool get isMandiMode => type == BusinessType.vegetablesBroker;

  bool get isRetailMode =>
      type == BusinessType.grocery ||
      type == BusinessType.pharmacy ||
      type == BusinessType.clothing ||
      type == BusinessType.electronics ||
      type == BusinessType.mobileShop ||
      type == BusinessType.computerShop ||
      type == BusinessType.hardware;

  bool get isServiceMode =>
      type == BusinessType.service ||
      type == BusinessType.mobileShop ||
      type == BusinessType.computerShop;

  bool get isRestaurantMode => type == BusinessType.restaurant;

  bool get isPetrolPumpMode => type == BusinessType.petrolPump;

  // --- SPECIFIC FEATURES ( delegated to Isolation Engine ) ---

  /// Should show Supplier/Farmer management?
  bool get showSupplierManagement =>
      iso.FeatureResolver.canAccess(
        type.name,
        BusinessCapability.useStockManagement,
      ) ||
      iso.FeatureResolver.canAccess(
        type.name,
        BusinessCapability.useCommission,
      );

  /// Should show Commission logic?
  bool get showCommissionLogic => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useCommission,
  );

  /// Should show Weight-First billing (Gross/Tare)?
  bool get showWeightBilling => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useCommission,
  );

  /// Should show MRP/Retail Price logic?
  bool get showRetailPriceLogic =>
      isRetailMode; // Keep as Mode for pricing strategy

  /// Should show Barcode Scanner?
  bool get showBarcodeScanner => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useBarcodeScanner,
  );

  /// Should show generic "Add Item" button?
  bool get showGenericAddItem => !isMandiMode; // Layout preference

  /// Should show "Sell Vegetables" instead of "New Bill"?
  bool get useMandiTerminology => isMandiMode;

  /// Should show Wastage Tracker?
  bool get showWastageTracker => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useStockManagement,
  );

  /// Should show Inventory/Stock Management features?
  bool get showStockManagement => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useStockManagement,
  );

  /// Should show Udhar/Credit Ledger?
  bool get showCreditLedger => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useCreditManagement,
  );

  // --- NEW GRANULAR TOGGLES (Post-Refactor) ---

  bool get showRevenueOverview => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useRevenueOverview,
  );

  bool get showLowStockAlerts => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useLowStockAlert,
  );

  bool get showDailySnapshot => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useDailySnapshot,
  );

  bool get showPurchaseFlow => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.usePurchaseOrder,
  );

  bool get showProductTax => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useProductTax,
  );

  bool get showBatchExpiry => iso.FeatureResolver.canAccess(
    type.name,
    BusinessCapability.useBatchExpiry,
  );
}
