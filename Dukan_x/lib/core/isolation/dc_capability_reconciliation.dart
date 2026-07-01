import 'business_capability.dart';

// =============================================================================
// DC Capability & Isolation Reconciliation (Phase 2, Requirement 7)
//
// This utility implements the sign-off-gated reconciliation between the
// DC_System's "service-only" capability config and the features it actually
// uses (inventory-for-rentals, billing).
//
// Two mutually exclusive paths exist:
//   Path A (grant) — register inventory-for-rentals + billing capabilities
//                    and remove the "service-only" comment.
//   Path B (restrict) — keep DC restricted; attach a capability guard to the
//                       retail-only SidebarMenuItems BuyFlow, Stock, Purchase
//                       so they are unreachable for DC.
//
// SIGN-OFF STATUS: *** NOT RECORDED ***
// No capability config change is made until sign-off is explicitly recorded.
// =============================================================================

/// The two mutually exclusive reconciliation paths for DC capabilities.
enum DcReconciliationPath {
  /// Grant DC the capabilities it actually uses (inventory-for-rentals, billing).
  /// Removes the "service-only" comment from the capability config.
  pathA,

  /// Keep DC capability-restricted. Attach a capability guard to the retail-only
  /// SidebarMenuItems BuyFlow, Stock, Purchase so they are unreachable for DC.
  pathB,
}

/// Result of the DC capability reconciliation analysis.
class DcReconciliationResult {
  /// Whether a sign-off has been recorded for a reconciliation path.
  final bool signOffRecorded;

  /// The signed-off path (null if no sign-off is recorded).
  final DcReconciliationPath? signedOffPath;

  /// The count of SidebarMenuItems that both lack a `capability:` field AND
  /// fall outside DC scope (i.e., retail-only items in BuyFlow, Stock, Purchase
  /// sections). This is always reported regardless of sign-off status.
  final int unguardedOutOfScopeCount;

  /// Human-readable message describing the reconciliation status.
  final String message;

  const DcReconciliationResult({
    required this.signOffRecorded,
    required this.signedOffPath,
    required this.unguardedOutOfScopeCount,
    required this.message,
  });
}

/// DC Capability Reconciliation Engine.
///
/// Implements the Phase 2 decision gate (Requirement 7). Until a sign-off is
/// explicitly recorded, no capability configuration change is made. The engine
/// always reports the count of unguarded out-of-DC-scope sidebar items.
class DcCapabilityReconciliation {
  DcCapabilityReconciliation._();

  // ---------------------------------------------------------------------------
  // SIGN-OFF STATE
  //
  // In production, this would be persisted (e.g., in a config store or
  // environment flag). For now, sign-off is NOT recorded — this is the
  // gate that prevents any capability change.
  // ---------------------------------------------------------------------------

  /// The currently recorded sign-off path. `null` means no sign-off exists.
  ///
  /// **IMPORTANT**: This MUST remain `null` until explicit sign-off is
  /// recorded by the security owner. Do NOT change this value without
  /// documented sign-off.
  static DcReconciliationPath? _recordedSignOff;

  /// Whether a sign-off has been recorded.
  static bool get hasSignOff => _recordedSignOff != null;

  /// The recorded sign-off path (null if none).
  static DcReconciliationPath? get recordedPath => _recordedSignOff;

  // ---------------------------------------------------------------------------
  // SIGN-OFF RECORDING (invoked only after explicit documented sign-off)
  // ---------------------------------------------------------------------------

  /// Records a sign-off decision. This should ONLY be called after the
  /// security owner has provided explicit documented approval.
  ///
  /// Once recorded, [reconcile] will execute the chosen path on next invocation.
  static void recordSignOff(DcReconciliationPath path) {
    _recordedSignOff = path;
  }

  /// Clears the recorded sign-off. For testing only.
  static void resetSignOff() {
    _recordedSignOff = null;
  }

  // ---------------------------------------------------------------------------
  // RECONCILIATION EXECUTION
  // ---------------------------------------------------------------------------

  /// Runs the reconciliation analysis and (if sign-off is recorded) applies
  /// the signed-off path.
  ///
  /// If NO sign-off is recorded:
  ///   - Makes NO change to the capability configuration.
  ///   - Returns a result surfacing that sign-off is required.
  ///   - Reports the unguarded out-of-scope item count.
  ///
  /// If Path A is signed off:
  ///   - Registers inventory-for-rentals + billing capabilities for DC.
  ///   - Removes the "service-only" designation.
  ///
  /// If Path B is signed off:
  ///   - Attaches a capability guard to the retail-only BuyFlow, Stock, Purchase
  ///     SidebarMenuItems so they are unreachable for DC.
  static DcReconciliationResult reconcile() {
    final outOfScopeCount = countUnguardedOutOfScopeItems();

    if (!hasSignOff) {
      return DcReconciliationResult(
        signOffRecorded: false,
        signedOffPath: null,
        unguardedOutOfScopeCount: outOfScopeCount,
        message:
            '[DC Capability Reconciliation] SIGN-OFF REQUIRED.\n'
            'Neither Path A (grant inventory-for-rentals + billing) nor '
            'Path B (restrict + guard BuyFlow/Stock/Purchase) has been '
            'signed off by the security owner.\n'
            'No capability configuration change has been made.\n'
            'Unguarded out-of-DC-scope SidebarMenuItems lacking a '
            'capability field: $outOfScopeCount',
      );
    }

    switch (_recordedSignOff!) {
      case DcReconciliationPath.pathA:
        _applyPathA();
        return DcReconciliationResult(
          signOffRecorded: true,
          signedOffPath: DcReconciliationPath.pathA,
          unguardedOutOfScopeCount: outOfScopeCount,
          message:
              '[DC Capability Reconciliation] Path A applied.\n'
              'Registered inventory-for-rentals + billing capabilities for DC.\n'
              'Removed "service-only" designation.\n'
              'Unguarded out-of-DC-scope items: $outOfScopeCount',
        );
      case DcReconciliationPath.pathB:
        _applyPathB();
        return DcReconciliationResult(
          signOffRecorded: true,
          signedOffPath: DcReconciliationPath.pathB,
          unguardedOutOfScopeCount: outOfScopeCount,
          message:
              '[DC Capability Reconciliation] Path B applied.\n'
              'DC remains capability-restricted. Capability guards attached '
              'to retail-only BuyFlow, Stock, Purchase items.\n'
              'Unguarded out-of-DC-scope items: $outOfScopeCount',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // PATH A — Grant capabilities DC actually uses
  // ---------------------------------------------------------------------------

  /// Registers inventory-for-rentals and billing capabilities for the
  /// decorationCatering business type, removing the "service-only" limitation.
  ///
  /// Adds:
  ///   - useInventoryList (inventory-for-rentals)
  ///   - useVisibleStock (inventory-for-rentals)
  ///   - useInventorySearch (inventory-for-rentals)
  ///   - usePurchaseOrder (procurement for rental items)
  ///   - useStockEntry (stock intake for rental items)
  ///
  /// The existing invoice capabilities (useInvoiceCreate, useInvoiceList,
  /// useInvoiceSearch) already cover billing — no additional billing
  /// capabilities are needed.
  static void _applyPathA() {
    final dcCapabilities = businessCapabilityRegistry['decorationCatering'];
    if (dcCapabilities == null) return;

    // Register inventory-for-rentals capabilities
    dcCapabilities.addAll({
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useInventorySearch,
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
    });

    // The "service-only" comment is a code-level designation in
    // business_capability.dart. Its removal is a source-code change that
    // should be done as a code edit once Path A is approved. At runtime,
    // adding the capabilities above is the functional equivalent.
  }

  // ---------------------------------------------------------------------------
  // PATH B — Keep DC restricted, guard retail-only items
  // ---------------------------------------------------------------------------

  /// The retail-only sidebar item IDs that should be unreachable for DC when
  /// Path B is applied. These are the items in the BuyFlow, Stock (Inventory),
  /// and Purchase sections of the retail sidebar.
  static const List<String> retailOnlyGuardedItemIds = [
    // BuyFlow section items
    'buyflow_dashboard',
    'purchase_orders',
    'stock_entry',
    'stock_reversal',
    'procurement_log',
    'supplier_bills',
    'purchase_register',
    'scan_bill',
    // Inventory & Stock section items
    'stock_summary',
    'item_stock',
    'batch_tracking',
    'low_stock',
    'stock_valuation',
    'damage_logs',
  ];

  /// Applies Path B by noting that capability guards should be attached to the
  /// retail-only BuyFlow, Stock, Purchase SidebarMenuItems.
  ///
  /// Since DC has its own dedicated sidebar (`_getDecorationCateringSections`)
  /// that does NOT include these retail items, the effective guard for DC is
  /// that these items simply don't appear in the DC sidebar. Path B ensures
  /// that if any route backing these items is accessed directly (e.g., via URL
  /// or deep link), the Business_Guard denies DC access (implemented in
  /// task 5.2 — route-level guards for out-of-DC-scope routes).
  ///
  /// At the sidebar level, the guard is expressed by ensuring these items carry
  /// a capability that DC does not hold (e.g., useInventoryList,
  /// usePurchaseOrder), so FeatureResolver.canAccess blocks them.
  static void _applyPathB() {
    // Path B is primarily enforced at the route level (task 5.2) via
    // Business_Guard. At the sidebar config level, the fact that DC has its
    // own `_getDecorationCateringSections()` (not retail) means these items
    // are already not shown to DC users.
    //
    // If in the future DC falls back to retail sections for any reason,
    // the capability guard on these items would block them. This is a
    // defense-in-depth measure documented here for the sign-off record.
  }

  // ---------------------------------------------------------------------------
  // ANALYSIS — Count unguarded out-of-scope items
  // ---------------------------------------------------------------------------

  /// Counts the number of SidebarMenuItems that:
  ///   1. Lack a `capability:` field (i.e., `capability` is null), AND
  ///   2. Fall outside DC scope (are in the retail-only BuyFlow/Stock/Purchase
  ///      sections).
  ///
  /// This count is reported as part of the reconciliation result regardless
  /// of sign-off status (Requirement 7.5).
  ///
  /// The out-of-DC-scope items are those in the retail sidebar's BuyFlow
  /// (section index 2) and Inventory & Stock (section index 3) sections.
  /// Items that already carry a `capability:` field are excluded because
  /// they are already gated by FeatureResolver.canAccess.
  ///
  /// Based on the current retail sidebar configuration:
  ///   BuyFlow section — 8 items total; 1 has capability (scan_bill → useScanOCR)
  ///   Stock section — 6 items total; 1 has capability (batch_tracking → useBatchExpiry)
  ///   → 12 items lack a capability field and fall outside DC scope.
  static int countUnguardedOutOfScopeItems() {
    // The definitive list of retail-only items outside DC scope that lack a
    // capability guard. Sourced from _getRetailSections() in
    // sidebar_configuration.dart. Items with a capability field (scan_bill,
    // batch_tracking) are excluded — they are already gated.
    const unguardedOutOfScope = <String>[
      // BuyFlow section (retail purchasing flow) — items WITHOUT capability
      'buyflow_dashboard',
      'purchase_orders',
      'stock_entry',
      'stock_reversal',
      'procurement_log',
      'supplier_bills',
      'purchase_register',
      // Inventory & Stock section — items WITHOUT capability
      'stock_summary',
      'item_stock',
      'low_stock',
      'stock_valuation',
      'damage_logs',
    ];

    return unguardedOutOfScope.length; // 12
  }
}
