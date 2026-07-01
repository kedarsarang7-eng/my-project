// =============================================================================
// RoutePaths — go_router path/name constants (DukanX navigation migration)
// =============================================================================
//
// Single source of truth for go_router path/name string constants and the
// `itemId -> path` resolver. Filled phase-by-phase:
//   * Phase 1 — foundation route constants ONLY: splash, login, business-type
//               resolution, and the main shell base.
//   * Phase 2 (CURRENT, Task 3.1) — one constant per migrated sidebar
//               `itemId` (90 total), the `pathForItemId(itemId)` resolver, and
//               documented duplicate mappings. NO GoRoutes are registered here
//               (that is Task 3.3) and the shell dispatch is untouched
//               (Task 3.4). This file is pure string/data ONLY — no widgets,
//               no screen imports, no navigation side effects.
//
// PATH NAMING CONVENTION (documented, consistent):
//   snake_case `itemId`  ->  '/app/' + kebab-case(itemId)
//   e.g.  'new_sale'         -> '/app/new-sale'
//         'gstr1'            -> '/app/gstr1'
//         'b2b_b2c'          -> '/app/b2b-b2c'
//   Each itemId yields a UNIQUE path (itemIds are unique), so duplicate-SCREEN
//   mappings (e.g. purchase_register & procurement_log both render
//   ProcurementLogScreen) still have DISTINCT paths — de-dup is a Phase 6
//   decision, NOT done here.
//
// UNKNOWN itemId HANDLING:
//   `pathForItemId` is TOTAL over the known itemId set (Property 2). For any
//   itemId NOT in the legacy switch it returns the documented sentinel
//   `RoutePaths.notFound` ('/app/not-found') rather than throwing — Task 3.3
//   binds this sentinel to the theme-aware "Feature Not Found" placeholder via
//   the go_router `errorBuilder`.
// =============================================================================

/// Holder for go_router route path and name constants plus the legacy
/// `itemId -> path` resolver.
///
/// Phase 1 carries the four foundation routes; Phase 2 (Task 3.1) adds one
/// constant per legacy sidebar `itemId` and [pathForItemId]. See file header.
abstract final class RoutePaths {
  const RoutePaths._();

  // ---------------------------------------------------------------------------
  // Foundation routes (Phase 1) — kept intact.
  // ---------------------------------------------------------------------------

  /// Animated splash / bootstrap screen. The router's initial location.
  static const String splash = '/splash';

  /// Name for the splash route.
  static const String splashName = 'splash';

  /// Login screen.
  static const String login = '/login';

  /// Name for the login route.
  static const String loginName = 'login';

  /// Business-type resolution step (auth + business-type gate). Reuses the
  /// existing `AuthGate` single entry point, which resolves authentication,
  /// onboarding, and the active business type before the shell is shown.
  static const String authGate = '/auth-gate';

  /// Name for the business-type resolution route.
  static const String authGateName = 'authGate';

  /// Base path for the main application shell (the `ShellRoute`). Per-item
  /// child routes are registered under this base in Phase 2 (Task 3.3).
  static const String shell = '/app';

  /// Name for the main shell route.
  static const String shellName = 'appShell';

  // ---------------------------------------------------------------------------
  // Unknown / not-found sentinel (Phase 2)
  // ---------------------------------------------------------------------------

  /// Sentinel path returned by [pathForItemId] for an unknown `itemId`.
  /// Bound to the theme-aware "Feature Not Found" placeholder in Task 3.3 via
  /// the go_router `errorBuilder` (mirrors the legacy switch `default:` case).
  static const String notFound = '/app/not-found';

  /// Name for the not-found sentinel route (Task 3.3).
  static const String notFoundName = 'appNotFound';

  // ---------------------------------------------------------------------------
  // Capability-denied screen (Phase 3, Task 4.3)
  // ---------------------------------------------------------------------------

  /// Path of the capability "deny" screen. The Phase 3 router guard
  /// ([AppRouter.capabilityRedirect]) redirects here when the active business
  /// type lacks the [BusinessCapability] bound to the requested route, so a
  /// deep link can never leak a screen the type is isolated from (security
  /// fix S3, Req 6.1/6.3). The deny screen is theme-aware and offers a way back
  /// to a permitted area — it is NOT a crash and NOT blank.
  ///
  /// Registered under the main `ShellRoute`, so it renders inside the shell
  /// (the sidebar stays available). It carries NO capability binding itself, so
  /// the guard always allows it (no redirect loop).
  static const String denied = '/app/denied';

  /// Name for the capability-denied route (Task 4.3).
  static const String deniedName = 'appDenied';

  // ---------------------------------------------------------------------------
  // NEW post-legacy routes (Phase 5+) — NOT part of the frozen legacy
  // dispatch inventory.
  // ---------------------------------------------------------------------------
  //
  // Routes added AFTER the Phase 2 migration that were NEVER `case`s in
  // `SidebarNavigationHandler.getScreenForItem` (the legacy switch has no
  // scan-bill case). They are kept in a SEPARATE map (`_newRouteItemIdToPath`)
  // so the legacy-inventory contracts stay honest: `knownItemIds`,
  // `knownPaths`, `isKnownItemId`, `pathForItemId`, and `itemIdForPath` remain
  // EXACTLY the 90 legacy ids (Property 2 totality). Navigable resolution that
  // must also cover these new routes uses the `nav*`/`isNavItemId` helpers
  // (consumed by the sidebar dispatch and the router capability guard).

  /// `scan_bill` -> OCR "Scan Bill / Purchase Entry" (Phase 5, Task 6.2).
  ///
  /// REUSES the existing AWS Textract "Smart Inventory Import" pipeline by
  /// rendering its entry screen (`ScanBillImagePickerScreen` from
  /// `features/purchase/scan_bill.dart`). This is NOT a new OCR implementation.
  /// Capability-gated by `useScanOCR` at the router guard
  /// (`AppRouter.requiredCapabilityFor('scan_bill')`), so grocery (granted
  /// `useScanOCR`) is allowed and types without it are denied.
  static const String scanBill = '/app/scan-bill';

  /// Name for the scan-bill route. Equals [scanBillItemId] so the router
  /// capability guard resolves it via the route `name` exactly as it does for
  /// the per-item legacy routes.
  static const String scanBillName = 'scan_bill';

  /// Stable sidebar/route id for the scan-bill route.
  static const String scanBillItemId = 'scan_bill';

  // ---------------------------------------------------------------------------
  // Mandi (vegetablesBroker) routes — Phase 4 (Task 18.2)
  //
  // Real routes replacing former LegacyRouteRedirect stubs. Each opens its
  // corresponding Phase 3 screen with no legacy redirect (Req 12.2, 12.5).
  // ---------------------------------------------------------------------------

  /// `mandi_lot_register` -> Lot Register screen (Req 11.1).
  static const String mandiLotRegister = '/app/mandi-lot-register';

  /// `mandi_farmer_ledger` -> Farmer Ledger entry point (Req 11.2).
  static const String mandiFarmerLedger = '/app/mandi-farmer-ledger';

  /// `mandi_commission_report` -> Commission Report screen.
  static const String mandiCommissionReport = '/app/mandi-commission-report';

  /// `mandi_settlement` -> Settlement / Patti screen (Req 11.3).
  static const String mandiSettlement = '/app/mandi-settlement';

  /// `mandi_rate_board` -> Rate Board screen (Req 11.4).
  static const String mandiRateBoard = '/app/mandi-rate-board';

  /// Stable sidebar item IDs for Mandi routes.
  static const String mandiLotRegisterItemId = 'mandi_lot_register';
  static const String mandiFarmerLedgerItemId = 'mandi_farmer_ledger';
  static const String mandiCommissionReportItemId = 'mandi_commission_report';
  static const String mandiSettlementItemId = 'mandi_settlement';
  static const String mandiRateBoardItemId = 'mandi_rate_board';

  /// The five Mandi sidebar item IDs (Task 18.2). Used by the router to
  /// register explicit GoRoutes for the Mandi screens.
  static const List<String> mandiItemIds = <String>[
    mandiLotRegisterItemId,
    mandiFarmerLedgerItemId,
    mandiCommissionReportItemId,
    mandiSettlementItemId,
    mandiRateBoardItemId,
  ];

  /// New (post-legacy) navigable `itemId -> path` routes. Kept SEPARATE from
  /// the legacy [_itemIdToPath] so the frozen 90-id inventory contracts hold.
  static const Map<String, String> _newRouteItemIdToPath = <String, String>{
    scanBillItemId: scanBill,
    // Mandi (vegetablesBroker) routes — Phase 4, Task 18.2.
    mandiLotRegisterItemId: mandiLotRegister,
    mandiFarmerLedgerItemId: mandiFarmerLedger,
    mandiCommissionReportItemId: mandiCommissionReport,
    mandiSettlementItemId: mandiSettlement,
    mandiRateBoardItemId: mandiRateBoard,
  };

  // ===========================================================================
  // Phase 2 — Per-itemId path constants.
  //
  // The accompanying doc comment on each constant records the EXACT legacy
  // screen + constructor args returned by
  // `SidebarNavigationHandler.getScreenForItem`, so Task 3.3 can build each
  // GoRoute faithfully WITHOUT re-reading the switch. (No screen classes are
  // imported here by design.)
  // ===========================================================================

  // --------------------------- Dashboard & Control ---------------------------

  /// `executive_dashboard` -> `DashboardController()`
  static const String executiveDashboard = '/app/executive-dashboard';

  /// `clinic_dashboard` -> `DoctorDashboardScreen()`
  static const String clinicDashboard = '/app/clinic-dashboard';

  /// `live_health` -> `LiveBusinessHealthScreen()`
  static const String liveHealth = '/app/live-health';

  /// `alerts` -> `AlertsNotificationsScreen()`
  static const String alerts = '/app/alerts';

  /// `daily_snapshot` -> `DailySnapshotScreen()`
  static const String dailySnapshot = '/app/daily-snapshot';

  // ------------------------------ Clinic Specific ----------------------------

  /// `daily_appointments` -> `AppointmentScreen()`
  /// (shares the AppointmentScreen target with `appointments` — both are
  /// distinct itemIds/paths; not a documented Model-2 duplicate group).
  static const String dailyAppointments = '/app/daily-appointments';

  /// `appointments` -> `AppointmentScreen()`
  static const String appointments = '/app/appointments';

  /// `patients_list` -> `PatientListScreen()`
  static const String patientsList = '/app/patients-list';

  /// `add_patient` -> `AddPatientScreen()`
  static const String addPatient = '/app/add-patient';

  /// `prescriptions` -> `SafePrescriptionListScreen()`
  static const String prescriptions = '/app/prescriptions';

  /// `medicine_master` -> `MedicineMasterScreen()`
  static const String medicineMaster = '/app/medicine-master';

  /// `lab_reports` -> `LabReportsScreen()`
  static const String labReports = '/app/lab-reports';

  /// `patient_history` -> `PatientListScreen()`
  /// NOTE (no clean 1:1 — flag for Phase 5/6): there is no dedicated
  /// patient-history screen; the legacy switch returns `PatientListScreen()`
  /// "for selection". Preserve as-is in Phase 2; revisit later.
  static const String patientHistory = '/app/patient-history';

  // ------------------------------- Revenue Desk ------------------------------

  /// `revenue_overview` -> `RevenueOverviewScreen()`
  static const String revenueOverview = '/app/revenue-overview';

  /// `new_sale` -> `BillCreationScreenV2()`
  static const String newSale = '/app/new-sale';

  /// `receipt_entry` -> `ReceiptEntryScreen()`
  static const String receiptEntry = '/app/receipt-entry';

  /// `return_inwards` -> `ReturnInwardsScreen()`
  /// (Phase 3 capability binding target: useSalesReturn.)
  static const String returnInwards = '/app/return-inwards';

  /// `proforma_bids` -> `ProformaScreen()`
  /// (Phase 3 capability binding target: useProformaInvoice.)
  static const String proformaBids = '/app/proforma-bids';

  /// `booking_orders` -> `BookingOrderScreen()`
  /// (Phase 3: capability mapping is a BUSINESS DECISION — Req 6.5.)
  static const String bookingOrders = '/app/booking-orders';

  /// `dispatch_notes` -> `DispatchNoteScreen()`
  /// (Phase 3 capability binding target: useDispatchNote.)
  static const String dispatchNotes = '/app/dispatch-notes';

  /// `sales_register` -> `SalesRegisterScreen()`
  static const String salesRegister = '/app/sales-register';

  // ---------------------------------- BuyFlow --------------------------------

  /// `buyflow_dashboard` -> `BuyFlowDashboard()`
  static const String buyflowDashboard = '/app/buyflow-dashboard';

  /// `purchase_orders` -> `BuyOrdersScreen()`
  static const String purchaseOrders = '/app/purchase-orders';

  /// `stock_entry` -> `StockEntryScreen()`
  static const String stockEntry = '/app/stock-entry';

  /// `stock_reversal` -> `StockReversalScreen()`
  /// (Phase 3 capability binding target: useStockReversal.)
  static const String stockReversal = '/app/stock-reversal';

  /// `vendor_payouts` -> `VendorPayoutsScreen()`
  static const String vendorPayouts = '/app/vendor-payouts';

  /// `procurement_log` -> `ProcurementLogScreen()`
  static const String procurementLog = '/app/procurement-log';

  /// `supplier_bills` -> `SupplierBillsScreen()`
  static const String supplierBills = '/app/supplier-bills';

  /// `purchase_register` -> `ProcurementLogScreen()`
  /// DUPLICATE of `procurement_log` (same screen, comment: "Reuse procurement
  /// log"). Preserved, NOT deduped (Phase 6 decision). Distinct path.
  /// (Phase 3 capability binding target: usePurchaseRegister.)
  static const String purchaseRegister = '/app/purchase-register';

  // ----------------------------- Inventory & Stock ---------------------------

  /// `stock_summary` -> `StockSummaryScreen()`
  static const String stockSummary = '/app/stock-summary';

  /// `item_stock` -> `InventoryDashboardScreen()`
  static const String itemStock = '/app/item-stock';

  /// `batch_tracking` -> `BatchTrackingScreen()`
  /// (Phase 3 existing capability binding: useBatchExpiry.)
  static const String batchTracking = '/app/batch-tracking';

  /// `low_stock` -> `LowStockAlertsScreen()`
  static const String lowStock = '/app/low-stock';

  /// `stock_valuation` -> `StockValuationScreen()`
  static const String stockValuation = '/app/stock-valuation';

  /// `damage_logs` -> `DamageLogsScreen()`
  static const String damageLogs = '/app/damage-logs';

  // ----------------------------- Parties & Ledger ----------------------------

  /// `customers` -> `CustomersListScreen()`
  static const String customers = '/app/customers';

  /// `suppliers` -> `PartyLedgerListScreen(initialFilter: 'supplier')`
  static const String suppliers = '/app/suppliers';

  /// `party_ledger` -> `PartyLedgerListScreen()`
  static const String partyLedger = '/app/party-ledger';

  /// `ledger_history` -> `AllTransactionsScreen()`
  /// Member of the AllTransactionsScreen CLUSTER (see Model 2). Relabel/flag in
  /// Phase 6. Distinct path; preserved as-is in Phase 2.
  static const String ledgerHistory = '/app/ledger-history';

  /// `ledger_abstract` -> `TrialBalanceScreen()`
  static const String ledgerAbstract = '/app/ledger-abstract';

  /// `outstanding` -> `PartyLedgerListScreen(initialFilter: 'receivable')`
  static const String outstanding = '/app/outstanding';

  // -------------------------- Business Intelligence --------------------------

  /// `analytics_hub` -> `ReportsHubScreen()`
  static const String analyticsHub = '/app/analytics-hub';

  /// `turnover_analysis` -> `AllTransactionsScreen()`
  /// AllTransactionsScreen CLUSTER; legacy comment "Placeholder mapping" — no
  /// clean 1:1 (flag for Phase 5/6). Preserved as-is.
  static const String turnoverAnalysis = '/app/turnover-analysis';

  /// `product_performance` -> `ProductPerformanceScreen()`
  static const String productPerformance = '/app/product-performance';

  /// `daily_activity` -> `AllTransactionsScreen()`
  /// AllTransactionsScreen CLUSTER (no clean 1:1 — flag for Phase 5/6).
  static const String dailyActivity = '/app/daily-activity';

  /// `procurement_insights` -> `PurchaseReportScreen()`
  static const String procurementInsights = '/app/procurement-insights';

  /// `margin_analysis` -> `BillWiseProfitScreen()`
  static const String marginAnalysis = '/app/margin-analysis';

  // ----------------------------- Financial Reports ---------------------------

  /// `invoice_margin` -> `PnlScreen()`
  /// DUPLICATE pair with `income_statement` (both -> PnlScreen). Preserved.
  static const String invoiceMargin = '/app/invoice-margin';

  /// `income_statement` -> `PnlScreen()`
  /// DUPLICATE of `invoice_margin`. Preserved, NOT deduped. Distinct path.
  static const String incomeStatement = '/app/income-statement';

  /// `funds_flow` -> `CashflowScreen()`
  /// DUPLICATE pair with `cash_bank` (both -> CashflowScreen). Preserved.
  static const String fundsFlow = '/app/funds-flow';

  /// `financial_position` -> `BalanceScreen()`
  static const String financialPosition = '/app/financial-position';

  /// `cash_bank` -> `CashflowScreen()`
  /// DUPLICATE of `funds_flow`. Preserved, NOT deduped. Distinct path.
  static const String cashBank = '/app/cash-bank';

  // ----------------------------- Tax & Compliance ----------------------------

  /// `gstr1` -> `GstReportsScreen(initialIndex: 0)`  (GSTR-1 tab)
  /// DUPLICATE pair with `b2b_b2c` (both -> GstReportsScreen(initialIndex: 0)).
  static const String gstr1 = '/app/gstr1';

  /// `b2b_b2c` -> `GstReportsScreen(initialIndex: 0)`  (B2B/B2C tab)
  /// DUPLICATE of `gstr1` (same screen + same initialIndex). Preserved. Distinct
  /// path.
  static const String b2bB2c = '/app/b2b-b2c';

  /// `hsn_reports` -> `GstReportsScreen(initialIndex: 1)`  (HSN tab)
  static const String hsnReports = '/app/hsn-reports';

  /// `tax_liability` -> `GstReportsScreen(initialIndex: 2)`  (Liability tab)
  static const String taxLiability = '/app/tax-liability';

  /// `filing_status` -> `GstReportsScreen(initialIndex: 3)`  (Status tab)
  static const String filingStatus = '/app/filing-status';

  // ----------------------------- Operations & Logs ---------------------------

  /// `transaction_reports` -> `AllTransactionsScreen()`
  /// AllTransactionsScreen CLUSTER (no clean 1:1 — flag for Phase 5/6).
  static const String transactionReports = '/app/transaction-reports';

  /// `activity_logs` -> `AllTransactionsScreen()`
  /// AllTransactionsScreen CLUSTER (no clean 1:1 — flag for Phase 5/6).
  static const String activityLogs = '/app/activity-logs';

  /// `audit_trail` -> `AllTransactionsScreen()`
  /// AllTransactionsScreen CLUSTER; MISLABELED — opens all-transactions, not a
  /// real immutable audit log. Relabel in Phase 6 (Req 9.2). Preserved as-is.
  static const String auditTrail = '/app/audit-trail';

  /// `error_logs` -> `ErrorLogsScreen()`
  static const String errorLogs = '/app/error-logs';

  // ---------------------------- Utilities & System ---------------------------

  /// `print_settings` -> `PrintMenuScreen()`
  /// DUPLICATE pair with `doc_templates` (both -> PrintMenuScreen). Preserved.
  static const String printSettings = '/app/print-settings';

  /// `doc_templates` -> `PrintMenuScreen()`
  /// DUPLICATE of `print_settings`. Preserved, NOT deduped. Distinct path.
  static const String docTemplates = '/app/doc-templates';

  /// `backup` -> `BackupScreen()`
  static const String backup = '/app/backup';

  /// `sync_status` -> `BackupScreen()`
  /// MISLABELED — opens BackupScreen ("Reuse Backup for sync status"), not a
  /// real sync-status dashboard. Relabel in Phase 6 (Req 9.3). Distinct path.
  static const String syncStatus = '/app/sync-status';

  /// `device_settings` -> `DeviceSettingsScreen()`
  static const String deviceSettings = '/app/device-settings';

  // -------------------------------- Petrol Pump ------------------------------

  /// `petrol_dashboard` -> `PetrolPumpManagementScreen()`
  static const String petrolDashboard = '/app/petrol-dashboard';

  /// `shift_management` -> `ShiftHistoryScreen()`
  static const String shiftManagement = '/app/shift-management';

  /// `tank_management` -> `TankListScreen()`
  static const String tankManagement = '/app/tank-management';

  /// `dispenser_management` -> `DispenserListScreen()`
  static const String dispenserManagement = '/app/dispenser-management';

  // --------------------------------- Restaurant ------------------------------

  /// `restaurant_tables` -> `TableManagementScreen(vendorId: <session-resolved>)`
  /// FIXED: vendorId now resolved from SessionManager.currentBusinessId.
  static const String restaurantTables = '/app/restaurant-tables';

  /// `kitchen_display` -> `KitchenDisplayScreen(vendorId: <session-resolved>)`
  /// FIXED: vendorId now resolved from SessionManager.currentBusinessId.
  static const String kitchenDisplay = '/app/kitchen-display';

  /// `menu_management` -> `FoodMenuManagementScreen(vendorId: <session-resolved>)`
  /// FIXED: vendorId now resolved from SessionManager.currentBusinessId.
  static const String menuManagement = '/app/menu-management';

  /// `daily_summary` -> `RestaurantDailySummaryScreen(vendorId: <session-resolved>)`
  /// FIXED: vendorId now resolved from SessionManager.currentBusinessId.
  static const String dailySummary = '/app/daily-summary';

  // ----------------------- Hidden features (made visible) --------------------

  /// `doctor_revenue` -> `DoctorRevenueScreen()`
  static const String doctorRevenue = '/app/doctor-revenue';

  /// `scan_qr` -> `QrScannerScreen()`
  static const String scanQr = '/app/scan-qr';

  // ------------------------- Petrol Pump reports (hidden) --------------------

  /// `fuel_rates` -> `FuelRatesScreen()`
  static const String fuelRates = '/app/fuel-rates';

  /// `fuel_profit_report` -> `FuelProfitReportScreen()`
  static const String fuelProfitReport = '/app/fuel-profit-report';

  /// `nozzle_sales_report` -> `NozzleSalesReportScreen()`
  static const String nozzleSalesReport = '/app/nozzle-sales-report';

  /// `shift_report` -> `ShiftReportScreen()`
  static const String shiftReport = '/app/shift-report';

  /// `tank_stock_report` -> `TankStockReportScreen()`
  static const String tankStockReport = '/app/tank-stock-report';

  // ---------------------------- Service business (hidden) --------------------

  /// `service_jobs` -> `ServiceJobListScreen()`
  static const String serviceJobs = '/app/service-jobs';

  /// `exchanges` -> `ExchangeListScreen()`
  static const String exchanges = '/app/exchanges';

  // ------------------- Phase-2 additional hidden screens ---------------------

  /// `accounting_reports` -> `AccountingReportsScreen()`
  static const String accountingReports = '/app/accounting-reports';

  /// `bank_accounts` -> `BankScreen()`
  static const String bankAccounts = '/app/bank-accounts';

  /// `credit_notes` -> `CreditNotesListScreen()`
  static const String creditNotes = '/app/credit-notes';

  /// `daybook` -> `DayBookScreen()`
  static const String daybook = '/app/daybook';

  /// `catalogue` -> `CatalogueScreen()`
  static const String catalogue = '/app/catalogue';

  /// `insights` -> `InsightsScreen()`
  static const String insights = '/app/insights';

  /// `expenses` -> `ExpensesScreen()`
  static const String expenses = '/app/expenses';

  // ===========================================================================
  // itemId -> path map + resolver
  // ===========================================================================

  /// Canonical mapping of every legacy `getScreenForItem` `itemId` to its
  /// go_router path. Exactly 90 entries (Property 2: totality / no dropped ids).
  ///
  /// Duplicate-SCREEN itemIds keep DISTINCT paths here (de-dup is Phase 6).
  static const Map<String, String> _itemIdToPath = <String, String>{
    // Dashboard & Control
    'executive_dashboard': executiveDashboard,
    'clinic_dashboard': clinicDashboard,
    'live_health': liveHealth,
    'alerts': alerts,
    'daily_snapshot': dailySnapshot,
    // Clinic
    'daily_appointments': dailyAppointments,
    'appointments': appointments,
    'patients_list': patientsList,
    'add_patient': addPatient,
    'prescriptions': prescriptions,
    'medicine_master': medicineMaster,
    'lab_reports': labReports,
    'patient_history': patientHistory,
    // Revenue Desk
    'revenue_overview': revenueOverview,
    'new_sale': newSale,
    'receipt_entry': receiptEntry,
    'return_inwards': returnInwards,
    'proforma_bids': proformaBids,
    'booking_orders': bookingOrders,
    'dispatch_notes': dispatchNotes,
    'sales_register': salesRegister,
    // BuyFlow
    'buyflow_dashboard': buyflowDashboard,
    'purchase_orders': purchaseOrders,
    'stock_entry': stockEntry,
    'stock_reversal': stockReversal,
    'vendor_payouts': vendorPayouts,
    'procurement_log': procurementLog,
    'supplier_bills': supplierBills,
    'purchase_register': purchaseRegister, // dup screen of procurement_log
    // Inventory & Stock
    'stock_summary': stockSummary,
    'item_stock': itemStock,
    'batch_tracking': batchTracking,
    'low_stock': lowStock,
    'stock_valuation': stockValuation,
    'damage_logs': damageLogs,
    // Parties & Ledger
    'customers': customers,
    'suppliers': suppliers,
    'party_ledger': partyLedger,
    'ledger_history': ledgerHistory, // AllTransactions cluster
    'ledger_abstract': ledgerAbstract,
    'outstanding': outstanding,
    // Business Intelligence
    'analytics_hub': analyticsHub,
    'turnover_analysis': turnoverAnalysis, // AllTransactions cluster
    'product_performance': productPerformance,
    'daily_activity': dailyActivity, // AllTransactions cluster
    'procurement_insights': procurementInsights,
    'margin_analysis': marginAnalysis,
    // Financial Reports
    'invoice_margin': invoiceMargin, // dup screen of income_statement
    'income_statement': incomeStatement, // dup screen of invoice_margin
    'funds_flow': fundsFlow, // dup screen of cash_bank
    'financial_position': financialPosition,
    'cash_bank': cashBank, // dup screen of funds_flow
    // Tax & Compliance
    'gstr1': gstr1, // dup screen of b2b_b2c (same initialIndex)
    'b2b_b2c': b2bB2c, // dup screen of gstr1 (same initialIndex)
    'hsn_reports': hsnReports,
    'tax_liability': taxLiability,
    'filing_status': filingStatus,
    // Operations & Logs
    'transaction_reports': transactionReports, // AllTransactions cluster
    'activity_logs': activityLogs, // AllTransactions cluster
    'audit_trail': auditTrail, // AllTransactions cluster (mislabeled)
    'error_logs': errorLogs,
    // Utilities & System
    'print_settings': printSettings, // dup screen of doc_templates
    'doc_templates': docTemplates, // dup screen of print_settings
    'backup': backup,
    'sync_status': syncStatus, // mislabeled (reuses BackupScreen)
    'device_settings': deviceSettings,
    // Petrol Pump
    'petrol_dashboard': petrolDashboard,
    'shift_management': shiftManagement,
    'tank_management': tankManagement,
    'dispenser_management': dispenserManagement,
    // Restaurant (vendorId resolved from session — tenant isolation fixed)
    'restaurant_tables': restaurantTables,
    'kitchen_display': kitchenDisplay,
    'menu_management': menuManagement,
    'daily_summary': dailySummary,
    // Hidden — doctor / QR
    'doctor_revenue': doctorRevenue,
    'scan_qr': scanQr,
    // Hidden — petrol pump reports
    'fuel_rates': fuelRates,
    'fuel_profit_report': fuelProfitReport,
    'nozzle_sales_report': nozzleSalesReport,
    'shift_report': shiftReport,
    'tank_stock_report': tankStockReport,
    // Hidden — service business
    'service_jobs': serviceJobs,
    'exchanges': exchanges,
    // Phase-2 additional hidden screens
    'accounting_reports': accountingReports,
    'bank_accounts': bankAccounts,
    'credit_notes': creditNotes,
    'daybook': daybook,
    'catalogue': catalogue,
    'insights': insights,
    'expenses': expenses,
  };

  /// Reverse of [_itemIdToPath]: go_router path -> legacy sidebar `itemId`.
  ///
  /// Well-defined because every itemId maps to a UNIQUE path (see file header
  /// PATH NAMING CONVENTION), so the inverse is a function. Used by the shell
  /// (Task 3.4) under the go_router flag to translate the CURRENT routed
  /// location back to the sidebar `itemId` it should highlight — since under
  /// the flag the legacy `NavigationController` selection state is no longer
  /// the source of truth for the active screen.
  static final Map<String, String> _pathToItemId = <String, String>{
    for (final MapEntry<String, String> e in _itemIdToPath.entries)
      e.value: e.key,
  };

  /// All legacy sidebar `itemId`s handled by the migration (immutable view).
  /// Useful for parity/totality tests (Property 2).
  static Iterable<String> get knownItemIds => _itemIdToPath.keys;

  /// All known go_router paths (immutable view). Each is unique.
  static Iterable<String> get knownPaths => _itemIdToPath.values;

  /// Whether [itemId] is a known legacy sidebar item.
  static bool isKnownItemId(String itemId) => _itemIdToPath.containsKey(itemId);

  /// Total resolver: maps a legacy sidebar `itemId` to its go_router path.
  ///
  /// Returns the [notFound] sentinel for any unknown `itemId` (mirroring the
  /// legacy switch `default:` placeholder), so callers never receive `null`
  /// and never throw. See file header "UNKNOWN itemId HANDLING".
  static String pathForItemId(String itemId) =>
      _itemIdToPath[itemId] ?? notFound;

  /// Reverse resolver: maps a go_router [path] back to its legacy sidebar
  /// `itemId`, or `null` if [path] is not a known per-item path (e.g. the
  /// shell base `/app`, the [notFound] sentinel, or a foundation route).
  ///
  /// Used by the shell under the go_router flag to derive which sidebar item
  /// is active from the CURRENT routed location (Task 3.4). It is pure (no
  /// navigation side effects) — consistent with this file's data-only design.
  static String? itemIdForPath(String path) => _pathToItemId[path];

  // ---------------------------------------------------------------------------
  // Navigable resolution over BOTH legacy and NEW post-legacy routes.
  //
  // These intentionally do NOT widen the legacy-only [pathForItemId] /
  // [itemIdForPath] / [isKnownItemId] / [knownItemIds] contracts (which the
  // Property 2 totality + inventory tests pin to exactly the 90 legacy ids).
  // They are the seam the sidebar dispatch and the router capability guard use
  // so genuinely-new routes (e.g. `scan_bill`) resolve and gate correctly.
  // ---------------------------------------------------------------------------

  /// Reverse of [_newRouteItemIdToPath]: new-route path -> itemId.
  static final Map<String, String> _newPathToItemId = <String, String>{
    for (final MapEntry<String, String> e in _newRouteItemIdToPath.entries)
      e.value: e.key,
  };

  /// Whether [itemId] is a navigable route id — a legacy sidebar item OR a new
  /// post-legacy route (e.g. `scan_bill`).
  static bool isNavItemId(String itemId) =>
      _itemIdToPath.containsKey(itemId) ||
      _newRouteItemIdToPath.containsKey(itemId);

  /// Resolves a navigable [itemId] (legacy OR new post-legacy route) to its
  /// go_router path, falling back to [notFound]. Used by the sidebar dispatch
  /// so new routes navigate too, WITHOUT widening the legacy-only
  /// [pathForItemId] totality contract.
  static String navPathForItemId(String itemId) =>
      _itemIdToPath[itemId] ?? _newRouteItemIdToPath[itemId] ?? notFound;

  /// Reverse resolver over BOTH legacy and new routes, or `null` if [path] is
  /// not a known navigable path. Used by the router capability guard to resolve
  /// the itemId for a direct/deep-link navigation.
  static String? navItemIdForPath(String path) =>
      _pathToItemId[path] ?? _newPathToItemId[path];
}
