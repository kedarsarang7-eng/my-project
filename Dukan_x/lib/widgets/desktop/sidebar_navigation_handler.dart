import 'package:flutter/material.dart';

// Dashboard & Control
import '../../features/dashboard/presentation/screens/dashboard_controller.dart';
import '../../features/dashboard/presentation/screens/live_business_health_screen.dart';
import '../../features/dashboard/presentation/screens/daily_snapshot_screen.dart';
import '../../features/alerts/presentation/screens/alerts_notifications_screen.dart';

// Doctor/Clinic
import '../../features/doctor/presentation/screens/doctor_dashboard_screen.dart';
import '../../features/doctor/presentation/screens/appointment_screen.dart';
import '../../features/doctor/presentation/screens/patient_list_screen.dart';
import '../../features/doctor/presentation/screens/add_patient_screen.dart';
import '../../features/doctor/presentation/screens/prescriptions_list_screen.dart';
import '../../features/doctor/presentation/screens/medicine_master_screen.dart';
import '../../features/doctor/presentation/screens/lab_reports_screen.dart';
import '../../features/doctor/presentation/screens/patient_history_picker_screen.dart';

// Clinic — Orphaned OPD screens (Phase 3, Task 6.2 / Req 2.16)
// These exist only under features/clinic (Decision 2.1: features/doctor is
// primary but these screens have no doctor-stack equivalent).
import '../../features/clinic/presentation/screens/patient_queue_screen.dart';
import '../../features/clinic/presentation/screens/clinic_calendar_screen.dart';

// Billing
import '../../features/billing/presentation/screens/bill_creation_screen_v2.dart';

// Revenue
import '../../features/revenue/screens/revenue_overview_screen.dart';
import '../../features/revenue/screens/receipt_entry_screen.dart';
import '../../features/revenue/screens/return_inwards_screen.dart';
import '../../features/revenue/screens/proforma_screen.dart';
import '../../features/revenue/screens/booking_order_screen.dart';
import '../../features/revenue/screens/dispatch_note_screen.dart';
import '../../features/revenue/screens/sales_register_screen.dart';

// BuyFlow
import '../../features/buy_flow/screens/buy_flow_dashboard.dart';
import '../../features/buy_flow/screens/buy_orders_screen.dart';
import '../../features/buy_flow/screens/stock_entry_screen.dart';
import '../../features/buy_flow/screens/stock_reversal_screen.dart';
import '../../features/buy_flow/screens/vendor_payouts_screen.dart';
import '../../features/buy_flow/screens/procurement_log_screen.dart';
import '../../features/buy_flow/screens/supplier_bills_screen.dart';

// Inventory
import '../../features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../features/inventory/presentation/screens/stock_summary_screen.dart';
import '../../features/inventory/presentation/screens/low_stock_alerts_screen.dart';
import '../../features/inventory/presentation/screens/stock_valuation_screen.dart';
import '../../features/inventory/presentation/screens/batch_tracking_screen.dart';
import '../../features/inventory/presentation/screens/damage_logs_screen.dart';

// Petrol Pump
import '../../features/petrol_pump/presentation/screens/petrol_pump_management_screen.dart';
import '../../features/petrol_pump/presentation/screens/shift_history_screen.dart';
import '../../features/petrol_pump/presentation/screens/tank_list_screen.dart';
import '../../features/petrol_pump/presentation/screens/dispenser_list_screen.dart';

// Restaurant
import '../../features/restaurant/presentation/screens/table_management_screen.dart';
import '../../features/restaurant/presentation/screens/kitchen_display_screen.dart';
import '../../features/restaurant/presentation/screens/food_menu_management_screen.dart';
import '../../features/restaurant/presentation/screens/floor_management_screen.dart';
import '../../features/restaurant/presentation/screens/kot_report_screen.dart';
import '../../features/restaurant/presentation/screens/recipe_management_screen.dart';
import '../../features/restaurant/presentation/screens/restaurant_delivery_ops_screen.dart';
import '../../features/restaurant/presentation/screens/restaurant_owner_command_screen.dart';

// Customers & Ledger
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/party_ledger/screens/party_ledger_list_screen.dart';

// Reports & GST
import '../../features/reports/presentation/screens/reports_hub_screen.dart';
import '../../features/reports/presentation/screens/all_transactions_screen.dart';
import '../../features/reports/presentation/screens/pnl_screen.dart';
import '../../features/reports/presentation/screens/cashflow_screen.dart';
import '../../features/reports/presentation/screens/balance_screen.dart';
import '../../features/gst/screens/gst_reports_screen.dart';
import '../../features/reports/presentation/screens/trial_balance_screen.dart';
import '../../features/reports/presentation/screens/purchase_report_screen.dart';
import '../../features/reports/presentation/screens/bill_wise_profit_screen.dart';
import '../../features/reports/presentation/screens/print_menu_screen.dart';
import '../../features/reports/presentation/screens/product_performance_screen.dart'; // Added
import '../../features/backup/screens/backup_screen.dart';
import '../../features/settings/presentation/screens/error_logs_screen.dart'; // Added
import '../../features/settings/presentation/screens/device_settings_screen.dart'; // Added

// ============================================================
// HIDDEN FEATURE SCREENS (Made visible per audit)
// ============================================================

// Doctor/Clinic - Hidden screens
import '../../features/doctor/presentation/screens/doctor_revenue_screen.dart';

// Petrol Pump - Hidden report screens
import '../../features/petrol_pump/presentation/screens/fuel_rates_screen.dart';
import '../../features/petrol_pump/presentation/screens/reports/fuel_profit_report_screen.dart';
import '../../features/petrol_pump/presentation/screens/reports/nozzle_sales_report_screen.dart';
import '../../features/petrol_pump/presentation/screens/reports/shift_report_screen.dart';
import '../../features/petrol_pump/presentation/screens/reports/tank_stock_report_screen.dart';

// Restaurant - Hidden screens
import '../../features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart';

// Service Business - Hidden screens
import '../../features/service/presentation/screens/service_job_list_screen.dart';
import '../../features/service/presentation/screens/exchange_list_screen.dart';
import '../../features/service/presentation/screens/create_service_job_screen.dart';
import '../../features/service/presentation/screens/second_hand_intake_screen.dart';

// QR Scanner (for scan_qr sidebar item)
import '../../features/shop_linking/presentation/screens/qr_scanner_screen.dart';

// ============================================================
// PHASE 2 - ADDITIONAL HIDDEN SCREENS DISCOVERED
// ============================================================

// Accounting Module - Hidden from sidebar
import '../../features/accounting/screens/accounting_reports_screen.dart';

// Bank Module - Hidden from sidebar
import '../../features/bank/presentation/screens/bank_screen.dart';

// Credit Notes - Hidden from sidebar
import '../../features/credit_notes/presentation/screens/credit_note_screen.dart';

// DayBook - Hidden from sidebar (exists in main.dart routes but not sidebar)
import '../../features/daybook/presentation/screens/day_book_screen.dart';

// Catalogue - Hidden from sidebar
import '../../features/catalogue/presentation/screens/catalogue_screen.dart';

// Insights - Hidden from sidebar
import '../../features/insights/presentation/screens/insights_screen.dart';

// Expenses - Hidden from sidebar
import '../../features/expenses/presentation/screens/expenses_screen.dart';

// Pharmacy - H1 Register (Schedule H1 statutory compliance screen)
import '../../features/prescriptions/presentation/screens/h1_register_screen.dart';

// Pharmacy - Orphaned compliance/lookup screens surfaced in sidebar (Req 13)
import '../../features/pharmacy/screens/salt_search_screen.dart';
import '../../features/pharmacy/screens/patient_registry_screen.dart';
import '../../features/pharmacy/screens/narcotic_register_screen.dart';

// Pharmacy - Executive dashboard reconciliation (Req 12)
import '../../features/dashboard/v2/screens/pharmacy_dashboard_screen.dart';
import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';
// RBAC parity on the in-shell path (Task 3.5 — bugfix.md 2.9). The same
// VendorRoleGuard + permission constants the named-route layer
// (lib/core/routing/legacy_routes.dart) applies to hardware routes are reused
// here so staff-role permission checks are enforced on both navigation systems.
import '../../core/auth/role_guard.dart';
import '../../config/permissions.dart';
// BusinessGuard — used for book_store school-orders/consignments (Task 5.4;
// Req 5.9). Matches the BusinessGuard([bookStore]) wrapper in legacy_routes.dart
// so the in-shell path enforces the same business-type restriction.
import '../../features/core/auth/business_type_guard.dart';

// ============================================================
// HARDWARE VERTICAL - In-shell navigation wiring (Task 3.1)
// Previously orphaned / dead-linked screens surfaced through the live shell
// so their HardwareOpsRepository endpoints are reachable from the UI
// (bugfix.md 2.1, 2.2, 2.3). All entries below are additive.
// ============================================================
import '../../features/delivery_challan/presentation/screens/delivery_challan_list_screen.dart';
import '../../features/hardware/presentation/screens/hardware_operations_screen.dart';
import '../../features/hardware/presentation/screens/hardware_command_center_screen.dart';
import '../../features/hardware/presentation/screens/hardware_supplier_management_screen.dart';
import '../../features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart';
import '../../features/hardware/presentation/screens/hardware_credit_control_screen.dart';
import '../../features/hardware/presentation/screens/hardware_invoice_profile_screen.dart';
import '../../features/hardware/presentation/screens/eway_bill_screen.dart';

// ============================================================
// MANDI (vegetablesBroker) — Phase 4, Task 18.2
// Real Mandi screens replacing former LegacyRouteRedirect stubs.
// Requirements: 12.2, 12.5
// ============================================================
import '../../features/vegetable_broker/presentation/screens/lot_register_screen.dart';
import '../../features/vegetable_broker/presentation/screens/farmer_ledger_entry_screen.dart';
import '../../features/vegetable_broker/presentation/screens/mandi_commission_report_screen.dart';
import '../../features/vegetable_broker/presentation/screens/settlement_screen.dart';
import '../../features/vegetable_broker/presentation/screens/rate_board_screen.dart';

// ============================================================
// DECORATION & CATERING — Phase 1, Task 3.9
// Wire all 14 DC sidebar item ids to their respective screens.
// Requirements: 4.2, 4.3, 4.4, 5.4
// ============================================================
import '../../features/decoration_catering/presentation/screens/dc_dashboard_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_bookings_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_calendar_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_quotes_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_catering_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_decoration_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_staff_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_staff_attendance_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_vendor_payments_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_inventory_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_shopping_list_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_billing_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_profitability_screen.dart';
import '../../features/decoration_catering/presentation/screens/dc_reports_screen.dart';

// ============================================================
// JEWELLERY VERTICAL — Phase 1, Task 2.3
// Wire all 8 jewellery sidebar item ids to their respective screens.
// Requirements: 5.1, 5.2, 5.3
// ============================================================
import '../../features/jewellery/presentation/screens/gold_rate_management_screen.dart';
import '../../features/jewellery/presentation/screens/gold_rate_alert_screen.dart';
import '../../features/jewellery/presentation/screens/jewellery_weight_stock_screen.dart';
import '../../features/jewellery/presentation/screens/hallmark_inventory_screen.dart';
import '../../features/jewellery/presentation/screens/old_gold_exchange_screen.dart';
import '../../features/jewellery/presentation/screens/custom_order_management_screen.dart';
import '../../features/jewellery/presentation/screens/jewellery_repair_screen.dart';
import '../../features/jewellery/presentation/screens/gold_scheme_screen.dart';
import '../../features/jewellery/presentation/screens/making_charges_calculator_screen.dart';

// Scan Bill — resolves `/purchase/scan-bill` (Requirement 5.3, Phase 0 finding 2.7)
import '../../features/purchase/presentation/screens/scan_bill_image_picker_screen.dart';

// ============================================================
// ELECTRONICS VERTICAL — Phase 7, Task 23.2
// Wire serial_stock sidebar id to ImeiTrackingStatementScreen.
// Requirement: 2.23
// ============================================================
import '../../features/statements/presentation/screens/imei_tracking_statement_screen.dart';

// ============================================================
// BOOK STORE VERTICAL — Phase 2, Task 5.2
// Wire all 5 book sidebar item ids to their respective Book_Screen widgets.
// Requirements: 5.4, 5.5
// ============================================================
import '../../features/book_store/presentation/screens/book_inventory_screen.dart';
import '../../features/book_store/presentation/screens/book_pos_screen.dart';
import '../../features/book_store/presentation/screens/consignment_settlement_screen.dart';
import '../../features/book_store/presentation/screens/school_order_screen.dart';
import '../../features/book_store/presentation/screens/book_supplier_returns_screen.dart';

// ============================================================
// CLOTHING VERTICAL — Phase 2, Task 5.1
// Wire all 4 clothing sidebar item ids to their respective screens.
// Requirements: 5.1, 5.2, 5.3, 1.8, 1.9
// ============================================================
import '../../features/clothing/presentation/screens/variant_management_screen.dart';
import '../../features/clothing/presentation/screens/tailoring_measurements_screen.dart';
import '../../features/clothing/presentation/screens/clothing_inventory_screen.dart';

// ============================================================
// SCHOOL ERP — Phase 1, Task 3.2
// Wire all 15 school sidebar item ids to their respective Ac_Screen widgets.
// Requirements: 4.4, 4.5
// ============================================================
import '../../features/academic_coaching/presentation/screens/ac_dashboard_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_students_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_class_sections_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_fee_collection_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_classwise_fee_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_attendance_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_exams_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_report_cards_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_timetable_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_faculty_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_transport_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_library_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_notifications_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_reports_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_certificate_generator_screen.dart';
// Phase 6, Task 13.1 — Production-Ready orphaned screens (Req 9.1, 9.2, 9.6)
import '../../features/academic_coaching/presentation/screens/ac_admissions_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_lesson_plans_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_homework_screen.dart';
import '../../features/academic_coaching/presentation/screens/ac_id_cards_screen.dart';

/// Shared `itemId -> screen` resolver for the application shell.
///
/// This is the SINGLE source of truth mapping a sidebar `itemId` to its screen
/// widget (including constructor args such as `GstReportsScreen.initialIndex`
/// and `PartyLedgerListScreen.initialFilter`). The go_router route builders
/// delegate to it via [AppRouter.screenForItemId], and [DesktopContentHost]
/// uses it to render the active screen, so the mapping stays in one place.
///
/// NOTE (Task 9.3): this was historically the "legacy switch-case dispatch".
/// After the go_router cutover it is retained as the shared resolver the
/// router delegates to — it is no longer a parallel/legacy navigation path.
class SidebarNavigationHandler {
  /// Resolves the screen widget for a given sidebar [itemId].
  ///
  /// Returns the placeholder screen when [itemId] does not map to a known
  /// screen, preserving the historical behaviour for every existing caller
  /// (go_router builders, etc.). Callers that need to distinguish a genuine
  /// resolution miss (e.g. [DesktopContentHost] for the pharmacy H1 Register
  /// safety branch, Req 9.3) should use [tryGetScreenForItem] instead.
  static Widget getScreenForItem(String itemId, BuildContext context) {
    return tryGetScreenForItem(itemId, context) ??
        _buildPlaceholderScreen('Unknown Screen', Icons.help_outline);
  }

  /// Resolves the screen widget for [itemId], or `null` when no screen is
  /// registered for it. Unlike [getScreenForItem] this never substitutes a
  /// [_PlaceholderScreen], so callers can implement their own resolution-miss
  /// handling.
  static Widget? tryGetScreenForItem(String itemId, BuildContext context) {
    switch (itemId) {
      // ========== Dashboard & Control ==========
      case 'executive_dashboard':
        // Req 12.1 / 12.5 (Dashboard reconciliation): pharmacy users get the
        // dedicated PharmacyDashboardScreen as the SINGLE executive-dashboard
        // destination — never the generic dashboard. Every other vertical keeps
        // the existing DashboardController unchanged, so only the pharmacy-gated
        // branch changes (Req 5.3).
        //
        // Req 6.1 / 6.3 (DC post-login landing): decorationCatering tenants
        // get the dedicated DcDashboardScreen as their post-login landing,
        // never the generic dashboard. Falls back to DcDashboardScreen if the
        // resolved route is anything else.
        if (_activeBusinessTypeIsPharmacy()) {
          return const PharmacyDashboardScreen();
        }
        if (_activeBusinessTypeIsDecorationCatering()) {
          return const DcDashboardScreen();
        }
        return const DashboardController();
      case 'clinic_dashboard':
        return const DoctorDashboardScreen();
      case 'live_health':
        return const LiveBusinessHealthScreen();
      case 'alerts':
        return const AlertsNotificationsScreen();
      case 'daily_snapshot':
        return const DailySnapshotScreen();

      // ========== Clinic Specific ==========
      case 'daily_appointments':
      case 'appointments':
        return const AppointmentScreen();
      case 'patients_list':
        return const PatientListScreen();
      case 'add_patient':
        return const AddPatientScreen();
      case 'prescriptions':
        return const SafePrescriptionListScreen();
      case 'medicine_master':
        return const MedicineMasterScreen();
      case 'lab_reports':
        return const LabReportsScreen();
      case 'patient_history':
        // Req 2.15: route to a patient picker that opens PatientHistoryScreen
        return const PatientHistoryPickerScreen();

      // ========== Clinic — Orphaned OPD Screens (Phase 3, Req 2.16) ==========
      // Token/queue management and appointment calendar from features/clinic.
      // Conditional on Decision 2.1: sourced from features/clinic since no
      // doctor-stack equivalent exists. Capability-gated by usePatientRegistry.
      case 'patient_queue':
        return const PatientQueueScreen();
      case 'clinic_calendar':
        return const ClinicCalendarScreen();

      // ========== Revenue Desk ==========
      case 'revenue_overview':
        return const RevenueOverviewScreen();
      case 'new_sale':
        return const BillCreationScreenV2();
      case 'receipt_entry':
        return const ReceiptEntryScreen();
      case 'return_inwards':
        return const ReturnInwardsScreen();
      case 'proforma_bids':
        return const ProformaScreen();
      case 'booking_orders':
        return const BookingOrderScreen();
      case 'dispatch_notes':
        return const DispatchNoteScreen();
      case 'sales_register':
        return const SalesRegisterScreen();

      // ========== BuyFlow ==========
      case 'buyflow_dashboard':
        return const BuyFlowDashboard();
      case 'purchase_orders':
        return const BuyOrdersScreen();
      case 'stock_entry':
        return const StockEntryScreen();
      case 'stock_reversal':
        return const StockReversalScreen();
      case 'vendor_payouts':
        return const VendorPayoutsScreen();
      case 'procurement_log':
        return const ProcurementLogScreen();
      case 'supplier_bills':
        return const SupplierBillsScreen();
      case 'purchase_register':
        return const ProcurementLogScreen(); // Reuse procurement log

      // ========== Inventory & Stock ==========
      case 'stock_summary':
        // Requirement 13.5: jewellery presents stock by metal weight, not qty.
        if (_activeBusinessTypeIsJewellery()) {
          return const JewelleryWeightStockScreen();
        }
        return const StockSummaryScreen();
      case 'item_stock':
        return const InventoryDashboardScreen();
      case 'batch_tracking':
        return const BatchTrackingScreen();
      case 'low_stock':
        return const LowStockAlertsScreen();
      case 'stock_valuation':
        return const StockValuationScreen();
      case 'damage_logs':
        return const DamageLogsScreen();

      // ========== Parties & Ledger ==========
      case 'customers':
        return const CustomersListScreen();
      case 'suppliers':
        // Reuse Party Ledger strictly for suppliers
        return const PartyLedgerListScreen(initialFilter: 'supplier');
      case 'party_ledger':
        return const PartyLedgerListScreen();
      case 'ledger_history':
        return const AllTransactionsScreen();
      case 'ledger_abstract':
        return const TrialBalanceScreen();
      case 'outstanding':
        return const PartyLedgerListScreen(initialFilter: 'receivable');

      // ========== Business Intelligence ==========
      case 'analytics_hub':
        return const ReportsHubScreen();
      case 'turnover_analysis':
        return const AllTransactionsScreen(); // Placeholder mapping
      case 'product_performance':
        return const ProductPerformanceScreen();
      case 'daily_activity':
        return const AllTransactionsScreen();
      case 'procurement_insights':
        return const PurchaseReportScreen();
      case 'margin_analysis':
        return const BillWiseProfitScreen();

      // ========== Financial Reports ==========
      case 'invoice_margin':
        return const PnlScreen();
      case 'income_statement':
        return const PnlScreen();
      case 'funds_flow':
        return const CashflowScreen();
      case 'financial_position':
        return const BalanceScreen();
      case 'cash_bank':
        return const CashflowScreen();

      // ========== Tax & Compliance ==========
      case 'gstr1':
        return const GstReportsScreen(initialIndex: 0); // GSTR-1
      case 'b2b_b2c':
        return const GstReportsScreen(initialIndex: 0); // B2B/B2C
      case 'hsn_reports':
        return const GstReportsScreen(initialIndex: 1); // HSN
      case 'tax_liability':
        return const GstReportsScreen(initialIndex: 2); // Liability
      case 'filing_status':
        return const GstReportsScreen(initialIndex: 3); // Status

      // ========== Operations & Logs ==========
      case 'transaction_reports':
        return const AllTransactionsScreen();
      case 'activity_logs':
        return const AllTransactionsScreen();
      case 'audit_trail':
        return const AllTransactionsScreen();
      case 'error_logs':
        return const ErrorLogsScreen();

      // ========== Utilities & System ==========
      case 'print_settings':
        return const PrintMenuScreen();
      case 'doc_templates':
        return const PrintMenuScreen();
      case 'backup':
        return const BackupScreen();
      case 'sync_status':
        return const BackupScreen(); // Reuse Backup for sync status
      case 'device_settings':
        return const DeviceSettingsScreen();

      // ========== Petrol Pump ==========
      case 'petrol_dashboard':
        return const PetrolPumpManagementScreen();
      case 'shift_management':
        return const ShiftHistoryScreen();
      case 'tank_management':
        return const TankListScreen();
      case 'dispenser_management':
        return const DispenserListScreen();

      // ========== Restaurant ==========
      case 'restaurant_tables':
        final vendorId =
            sl<SessionManager>().currentBusinessId ??
            sl<SessionManager>().userId ??
            'SYSTEM';
        return TableManagementScreen(vendorId: vendorId);
      case 'kitchen_display':
        final vendorId =
            sl<SessionManager>().currentBusinessId ??
            sl<SessionManager>().userId ??
            'SYSTEM';
        return KitchenDisplayScreen(vendorId: vendorId);
      case 'menu_management':
        final vendorId =
            sl<SessionManager>().currentBusinessId ??
            sl<SessionManager>().userId ??
            'SYSTEM';
        return FoodMenuManagementScreen(vendorId: vendorId);
      case 'daily_summary':
        final vendorId =
            sl<SessionManager>().currentBusinessId ??
            sl<SessionManager>().userId ??
            'SYSTEM';
        return RestaurantDailySummaryScreen(vendorId: vendorId);

      // ========== Restaurant — Advanced Operations (Task 5.2) ==========
      case 'floor_management':
        final vendorId =
            sl<SessionManager>().currentBusinessId ??
            sl<SessionManager>().userId ??
            'SYSTEM';
        return FloorManagementScreen(vendorId: vendorId);
      case 'kot_report':
        final vendorId =
            sl<SessionManager>().currentBusinessId ??
            sl<SessionManager>().userId ??
            'SYSTEM';
        return KotReportScreen(vendorId: vendorId);
      case 'recipe_management':
        final vendorId =
            sl<SessionManager>().currentBusinessId ??
            sl<SessionManager>().userId ??
            'SYSTEM';
        return RecipeManagementScreen(vendorId: vendorId);
      case 'delivery_ops':
        return const RestaurantDeliveryOpsScreen();
      case 'restaurant_command_center':
        return const RestaurantOwnerCommandScreen();

      // ============================================================
      // HIDDEN FEATURES MADE VISIBLE (per audit)
      // ============================================================

      // ========== Doctor/Clinic Hidden ==========
      case 'doctor_revenue':
        return const DoctorRevenueScreen();
      case 'scan_qr':
        return const QrScannerScreen();

      // ========== Petrol Pump Reports (Hidden) ==========
      case 'fuel_rates':
        return const FuelRatesScreen();
      case 'fuel_profit_report':
        return const FuelProfitReportScreen();
      case 'nozzle_sales_report':
        return const NozzleSalesReportScreen();
      case 'shift_report':
        return const ShiftReportScreen();
      case 'tank_stock_report':
        return const TankStockReportScreen();

      // ========== Service Business (Hidden) ==========
      // RBAC parity (Task 9.4 — Requirement 7.6): wrap with the SAME
      // VendorRoleGuard + permission the named-route layer
      // (legacy_routes.dart `/service_jobs`, `/exchanges`) enforces, so the
      // Content_Host in-shell path no longer bypasses the manageStaff guard.
      case 'service_jobs':
        return const VendorRoleGuard(
          requiredPermission: Permissions.manageStaff,
          child: ServiceJobListScreen(),
        );
      case 'exchanges':
        return const VendorRoleGuard(
          requiredPermission: Permissions.manageStaff,
          child: ExchangeListScreen(),
        );
      // Service-job sub-navigation targets (Task 9.4 — Requirement 7.3):
      // job-create/job-status/job-deliver reach the corresponding service-job
      // destination through the in-shell resolver without a navigation error.
      // Guarded identically to the GoRouter paths in legacy_routes.dart.
      case 'job_create':
        return const VendorRoleGuard(
          requiredPermission: Permissions.manageStaff,
          child: CreateServiceJobScreen(),
        );
      case 'job_status':
        return const VendorRoleGuard(
          requiredPermission: Permissions.manageStaff,
          child: ServiceJobListScreen(),
        );
      case 'job_deliver':
        return const VendorRoleGuard(
          requiredPermission: Permissions.manageStaff,
          child: ServiceJobListScreen(),
        );

      // ============================================================
      // MOBILE SHOP — Phase 6, Task 13.2
      // Second-Hand Intake screen for used-device buyback.
      // Requirements: 9.1, 9.2, 9.3, 1.1, 1.2, 1.3, 1.4
      // ============================================================
      case 'second_hand_intake':
        return const SecondHandIntakeScreen();

      // ============================================================
      // PHASE 2 - ADDITIONAL HIDDEN SCREENS
      // ============================================================

      // Accounting & Financial
      case 'accounting_reports':
        return const AccountingReportsScreen();
      case 'bank_accounts':
        return const BankScreen();
      case 'credit_notes':
        return const CreditNotesListScreen();

      // Daily Operations
      case 'daybook':
        return const DayBookScreen();
      case 'catalogue':
        return const CatalogueScreen();
      case 'insights':
        return const InsightsScreen();
      case 'expenses':
        return const ExpensesScreen();

      // ============================================================
      // PHARMACY - Compliance / Statutory Registers
      // ============================================================
      case 'h1_register':
        // Schedule H1 statutory register (Req 9.1, 9.2). Always resolves to the
        // real screen so the navigation action never dead-ends on a placeholder.
        return const H1RegisterScreen();

      // Salt / generic substitute lookup (Req 13.1, 13.2). Browse mode — the
      // optional onProductSelected callback is only supplied from the billing
      // flow (Req 25), so the sidebar opens it as a standalone lookup screen.
      case 'salt_search':
        return const SaltSearchScreen();

      // Pharmacy Patient Registry (Req 13.1, 13.2).
      case 'patient_registry':
        return const PatientRegistryScreen();

      // Narcotic / Schedule X statutory register (Req 13.1, 13.2).
      case 'narcotic_register':
        return const NarcoticRegisterScreen();

      // ============================================================
      // HARDWARE VERTICAL (Task 3.1 — bugfix.md 2.1, 2.2, 2.3)
      // ============================================================

      // P0: previously dead dashboard CTAs (1.1 / 1.2). These resolve through
      // the in-shell path so "Delivery Challan" and "Projects" no longer land
      // on the "Feature Not Found" placeholder.
      case 'delivery_challans':
        return const DeliveryChallanListScreen();
      case 'hardware_operations':
        return const HardwareOperationsScreen();

      // P0: previously orphaned hardware screens (1.3). Surfacing them here
      // makes their backing HardwareOpsRepository endpoints reachable from the
      // live UI.
      //
      // RBAC parity (Task 3.5 — bugfix.md 2.9): these orphaned screens are
      // wrapped in the SAME VendorRoleGuard + permission constants the
      // named-route layer (legacy_routes.dart) applies to the equivalent
      // hardware routes, so the in-shell path enforces staff-role permissions
      // consistently rather than returning a raw, unguarded widget.
      // (The two dashboard CTAs above — delivery_challans / hardware_operations
      // — intentionally resolve to their concrete screen types, matching the
      // shell's primary-navigation contract.)
      case 'hardware_command_center':
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: HardwareCommandCenterScreen(),
        );
      case 'hardware_supplier_management':
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: HardwareSupplierManagementScreen(),
        );
      case 'hardware_phase12_workspace':
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: HardwarePhase12WorkspaceScreen(),
        );
      case 'hardware_credit_control':
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: HardwareCreditControlScreen(),
        );
      case 'hardware_invoice_profile':
        return const VendorRoleGuard(
          requiredPermission: Permissions.systemSettings,
          child: HardwareInvoiceProfileScreen(),
        );
      // e-Way bill for bulk dispatches > ₹50,000 (bugfix.md 2.14). Hardware
      // path only; additive new id.
      case 'eway_bill':
        return const VendorRoleGuard(
          requiredPermission: Permissions.createInvoices,
          child: EWayBillScreen(),
        );

      // ============================================================
      // MANDI (vegetablesBroker) — Phase 4, Task 18.2
      // Real Mandi screens replacing former LegacyRouteRedirect stubs.
      // Requirements: 12.2, 12.5
      // ============================================================
      case 'mandi_lot_register':
        return const LotRegisterScreen();
      case 'mandi_farmer_ledger':
        return const FarmerLedgerEntryScreen();
      case 'mandi_commission_report':
        return const MandiCommissionReportScreen();
      case 'mandi_settlement':
        return const SettlementScreen();
      case 'mandi_rate_board':
        return const RateBoardScreen();

      // ============================================================
      // JEWELLERY VERTICAL — Phase 1, Task 2.3
      // Maps each jewellery sidebar item id to its single screen widget.
      // None may fall through to _buildPlaceholderScreen('Unknown Screen').
      // Requirements: 5.1, 5.2, 5.3
      // ============================================================
      case 'jewellery_gold_rate':
        return const GoldRateManagementScreen();
      case 'jewellery_gold_rate_alert':
        return const GoldRateAlertScreen();
      case 'jewellery_hallmark':
        return const HallmarkInventoryScreen();
      case 'jewellery_old_gold_exchange':
        return const OldGoldExchangeScreen();
      case 'jewellery_custom_orders':
        return const CustomOrderManagementScreen();
      case 'jewellery_repair':
        return const JewelleryRepairScreen();
      case 'jewellery_gold_scheme':
        return const GoldSchemeScreen();
      case 'jewellery_making_charges':
        return const MakingChargesCalculatorScreen();

      // Scan Bill — resolves `/purchase/scan-bill` navigation target so it is
      // not a dead end (Requirement 5.3, Phase 0 finding 2.7). The backing
      // screen already exists at `/app/scan-bill` via app_router.dart; this
      // entry ensures in-shell sidebar resolution also works.
      case 'scan_bill':
        return const ScanBillImagePickerScreen(verticalType: 'jewellery');

      // ============================================================
      // DECORATION & CATERING — Phase 1, Task 3.9
      // Maps 14 DC sidebar item ids to their respective screens.
      // Note: dc_vendor_payments → DcVendorPaymentsScreen, NOT DcStaffScreen.
      // Requirements: 4.2, 4.3, 4.4, 5.4
      // ============================================================
      case 'dc_dashboard':
        return const DcDashboardScreen();
      case 'dc_bookings':
        return const DcBookingsScreen();
      case 'dc_calendar':
        return const DcCalendarScreen();
      case 'dc_quotes':
        return const DcQuotesScreen();
      case 'dc_catering_menu':
        return const DcCateringScreen();
      case 'dc_decoration_themes':
        return const DcDecorationScreen();
      case 'dc_staff':
        return const DcStaffScreen();
      case 'dc_attendance':
        return const DcStaffAttendanceScreen();
      case 'dc_vendor_payments':
        return const DcVendorPaymentsScreen();
      case 'dc_inventory_rentals':
        return const DcInventoryScreen();
      case 'dc_shopping_list':
        return const DcShoppingListScreen();
      case 'dc_billing':
        return const DcBillingScreen();
      case 'dc_profitability':
        return const DcProfitabilityScreen();
      case 'dc_reports':
        return const DcReportsScreen();

      // ============================================================
      // SCHOOL ERP — Phase 1, Task 3.2
      // Maps 15 school sidebar item ids to their respective Ac_Screen
      // widgets (+ 4 Production-Ready orphaned screens added in Phase 6).
      // _buildPlaceholderScreen. An unknown school_* id falls through
      // to `default: return null`, which lets getScreenForItem surface
      // the placeholder while tryGetScreenForItem callers can implement
      // their own resolution-miss handling (Requirement 4.5).
      // Requirements: 4.4, 4.5
      // BLAST RADIUS: Additive only — no other case is modified.
      // ============================================================
      case 'school_dashboard':
        return const AcDashboardScreen();
      case 'school_students':
        return const AcStudentsScreen();
      case 'school_classes':
        return const AcClassSectionsScreen();
      case 'school_fees':
        return const AcFeeCollectionScreen();
      case 'school_fee_structure':
        return const AcClasswiseFeeScreen();
      case 'school_attendance':
        return const AcAttendanceScreen();
      case 'school_exams':
        return const AcExamsScreen();
      case 'school_report_cards':
        return const AcReportCardsScreen();
      case 'school_timetable':
        return const AcTimetableScreen();
      case 'school_faculty':
        return const AcFacultyScreen();
      case 'school_transport':
        return const AcTransportScreen();
      case 'school_library':
        return const AcLibraryScreen();
      case 'school_notifications':
        return const AcNotificationsScreen();
      case 'school_reports':
        return const AcReportsScreen();
      case 'school_certificates':
        return const AcCertificateGeneratorScreen();

      // ============================================================
      // SCHOOL ERP — Phase 6, Task 13.1 (Req 9.1, 9.2, 9.6)
      // Maps 4 Production-Ready orphaned screen ids to their
      // respective Ac_Screen widgets. Each case returns the real
      // screen widget — never _buildPlaceholderScreen.
      // BLAST RADIUS: Additive only — no other case is modified.
      // ============================================================
      case 'school_admissions':
        return const AcAdmissionsScreen();
      case 'school_lesson_plans':
        return const AcLessonPlansScreen();
      case 'school_homework':
        return const AcHomeworkScreen();
      case 'school_id_cards':
        return const AcIdCardsScreen();

      // ============================================================
      // CLOTHING VERTICAL — Phase 2, Task 5.1
      // Maps 4 clothing sidebar item ids to their respective screens.
      // Requirements: 5.1, 5.2, 5.3, 1.8, 1.9
      // BLAST RADIUS: Additive only — no other case is modified.
      // ============================================================
      case 'clothing_variant_matrix':
        // Opens VariantManagementScreen for the default/all-products view.
        // A productId is required by the screen constructor; when entered from
        // the sidebar (no specific product context), we pass an empty string
        // signaling "show all products" mode — the screen handles this by
        // displaying the full product-variant overview grid.
        return const VariantManagementScreen(productId: '');
      case 'clothing_tailoring':
        // Opens TailoringMeasurementsScreen in browse mode (no specific
        // invoice/customer context). The screen's optional parameters allow
        // standalone viewing of all tailoring records.
        return const TailoringMeasurementsScreen();
      case 'clothing_stock_overview':
        return const ClothingInventoryScreen();
      case 'clothing_tag_printing':
        // Routes to PrintMenuScreen (the existing Print_Infrastructure entry
        // point) for price-tag / barcode label printing.
        return const PrintMenuScreen();

      // ============================================================
      // ELECTRONICS VERTICAL — Phase 7, Task 23.2
      // Maps the serial_stock sidebar item to ImeiTrackingStatementScreen
      // which shows IMEISerials filtered by in-stock status.
      // Requirement: 2.23. BLAST RADIUS: Additive only.
      // ============================================================
      case 'serial_stock':
        return const ImeiTrackingStatementScreen();

      // ============================================================
      // BOOK STORE VERTICAL — Phase 2, Task 5.2
      // Maps each book_* sidebar item id to exactly one existing
      // Book_Screen widget. None falls through to the placeholder.
      // Requirements: 5.4, 5.5
      // BLAST RADIUS: Additive only — no other case is modified.
      // ============================================================
      case 'book_catalogue':
        return const BookInventoryScreen();
      case 'book_pos':
        return const BookPosScreen();
      // BOOK STORE — Guarded routes (Task 5.4; Requirements 5.9, 5.10).
      // Wraps ConsignmentSettlementScreen and SchoolOrderScreen with the SAME
      // VendorRoleGuard(viewReports) + BusinessGuard([bookStore]) that the
      // GoRouter paths `/book_store/consignments` and `/book_store/school_orders`
      // in legacy_routes.dart enforce, so the in-shell Content_Host path does
      // NOT bypass those guards. The GoRouter module (lib/modules/book_store/)
      // is NOT mounted or migrated — F4 remains report-only.
      case 'book_consignments':
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: BusinessGuard(
            allowedTypes: [BusinessType.bookStore],
            denialMessage: 'Only Book Stores can access Consignments',
            child: ConsignmentSettlementScreen(),
          ),
        );
      case 'book_school_orders':
        return const VendorRoleGuard(
          requiredPermission: Permissions.viewReports,
          child: BusinessGuard(
            allowedTypes: [BusinessType.bookStore],
            denialMessage: 'Only Book Stores can access School Orders',
            child: SchoolOrderScreen(),
          ),
        );
      case 'book_publisher_returns':
        return const BookSupplierReturnsScreen();

      default:
        return null;
    }
  }

  /// Get the route name for a given sidebar item ID
  static String getRouteForItem(String itemId) {
    return '/app/$itemId';
  }

  /// Resolves whether the active session business type is pharmacy.
  ///
  /// Used only by the `executive_dashboard` pharmacy-gated branch (Req 12.1,
  /// 12.5). Defensive by design: any resolution failure (e.g. the service
  /// locator is not configured in a unit test, or no session is active) falls
  /// back to `false`, so the non-pharmacy resolution path
  /// (`DashboardController`) is preserved byte-for-byte for the other 18
  /// verticals (Req 5.3).
  static bool _activeBusinessTypeIsPharmacy() {
    try {
      return sl<SessionManager>().activeBusinessType == BusinessType.pharmacy;
    } catch (_) {
      return false;
    }
  }

  /// Resolves whether the active session business type is decorationCatering.
  ///
  /// Used by the `executive_dashboard` DC-gated branch (Req 6.1, 6.3).
  /// Defensive by design: any resolution failure falls back to `false`, so the
  /// non-DC resolution path (`DashboardController`) is preserved for all other
  /// verticals. When true, the post-login landing renders `DcDashboardScreen`
  /// within 3s without blocking network calls.
  static bool _activeBusinessTypeIsDecorationCatering() {
    try {
      return sl<SessionManager>().activeBusinessType ==
          BusinessType.decorationCatering;
    } catch (_) {
      return false;
    }
  }

  /// Resolves whether the active session business type is jewellery.
  ///
  /// Used by the `stock_summary` jewellery-gated branch (Req 13.5).
  /// Defensive by design: any resolution failure falls back to `false`, so the
  /// non-jewellery resolution path (`StockSummaryScreen`) is preserved for all
  /// other verticals.
  static bool _activeBusinessTypeIsJewellery() {
    try {
      return sl<SessionManager>().activeBusinessType == BusinessType.jewellery;
    } catch (_) {
      return false;
    }
  }

  /// Build a placeholder screen for features not yet implemented
  static Widget _buildPlaceholderScreen(String title, IconData icon) {
    return _PlaceholderScreen(title: title, icon: icon);
  }
}

/// Placeholder screen widget - shown only for unknown routes
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FIXED: use theme-aware colors instead of hardcoded dark background
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Feature Not Found',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'This screen could not be located. Please select from the sidebar.',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
