import 'package:flutter/material.dart';

/// Defines all possible screens in the application for type-safe navigation.
/// Used by [NavigationController] and [DesktopRootShell].
enum AppScreen {
  // --- DASHBOARD ---
  executiveDashboard,
  dailySnapshot,
  liveHealth,
  alerts,

  // --- BILLING & REVENUE ---
  newSale,
  revenueOverview,
  receiptEntry,
  salesRegister,
  proformaBids,
  bookingOrders,
  dispatchNotes,
  returnInwards,

  // --- INVENTORY & STOCK ---
  stockSummary,
  itemStock,
  batchTracking,
  lowStock,
  stockValuation,
  damageLogs,
  categories,

  // --- BUY FLOW ---
  buyflowDashboard,
  purchaseOrders,
  stockEntry,
  stockReversal,
  procurementLog,
  supplierBills,
  purchaseRegister,

  // --- PARTIES & LEDGER ---
  customers,
  suppliers,
  partyLedger,
  ledgerHistory,
  ledgerAbstract,
  outstanding,

  // --- BUSINESS INTELLIGENCE ---
  analyticsHub,
  turnoverAnalysis,
  productPerformance,
  dailyActivity,
  procurementInsights,
  marginAnalysis,
  insights,
  catalogue,

  // --- FINANCIAL REPORTS ---
  invoiceMargin,
  incomeStatement,
  fundsFlow,
  financialPosition,
  cashBank,
  accountingReports,
  bankAccounts,
  daybook,
  creditNotes,
  expenses,
  paymentHistory,

  // --- TAX & COMPLIANCE ---
  gstr1,
  b2bB2c,
  hsnReports,
  taxLiability,
  filingStatus,

  // --- OPERATIONS & LOGS ---
  transactionReports,
  activityLogs,
  auditTrail,
  errorLogs,

  // --- UTILITIES & SYSTEM ---
  printSettings,
  docTemplates,
  backup,
  syncStatus,
  deviceSettings,
  settings,
  appManagement,

  // --- CLINIC SPECIFIC ---
  clinicDashboard,
  patientsList,
  addPatient,
  patientHistory,
  scanQr,
  appointments,
  prescriptions,
  medicineMaster,
  labReports,
  doctorRevenue,

  // --- PHARMACY SPECIFIC ---
  h1Register,

  // --- SERVICE SPECIFIC ---
  serviceJobs,
  exchanges,

  // --- RESTAURANT SPECIFIC ---
  restaurantTables,
  kitchenDisplay,
  menuManagement,
  dailySummary,

  // --- PETROL PUMP SPECIFIC ---
  petrolDashboard,
  dispenserManagement,
  fuelRates,
  tankManagement,
  shiftManagement,
  fuelProfitReport,
  nozzleSalesReport,
  shiftReport,
  tankStockReport,

  // --- HARDWARE SPECIFIC ---
  hardwareOperations,

  // --- DECORATION & CATERING SPECIFIC ---
  dcBookings,
  dcQuotes,
  dcStaff,
  dcCateringMenu,

  // --- JEWELLERY SPECIFIC ---
  jewelleryCustomOrders,
  jewelleryGoldRate,

  // --- VEGETABLE BROKER / MANDI SPECIFIC ---
  mandiLotEntry,
  mandiFarmerLedger,

  // --- BOOK STORE SPECIFIC ---
  bookCatalogue,
  bookReturns,

  // --- DELIVERY ---
  deliveryChallans,

  // --- CUSTOMER ---
  addCustomer,

  // --- REPORTS ---
  reportsHub,

  // --- BUY FLOW SPECIFIC ADDITIONS ---
  vendorPayouts,

  // --- FALLBACK ---
  unknown;

  /// Whether this screen requires data preloading
  bool get requiresPreload => switch (this) {
    AppScreen.newSale => true,
    AppScreen.salesRegister => true,
    AppScreen.stockSummary => true,
    AppScreen.partyLedger => true,
    AppScreen.gstr1 => true,
    AppScreen.transactionReports => true,
    AppScreen.analyticsHub => true,
    _ => false,
  };

  /// Whether this screen should be kept alive (cached)
  bool get keepAlive => switch (this) {
    AppScreen.executiveDashboard => true,
    AppScreen.newSale => true,
    AppScreen.stockSummary => true,
    AppScreen.customers => true,
    _ => false,
  };

  /// Icon for this screen
  IconData get icon => switch (this) {
    AppScreen.executiveDashboard => Icons.dashboard_rounded,
    AppScreen.newSale => Icons.point_of_sale_rounded,
    AppScreen.stockSummary => Icons.inventory_2_rounded,
    AppScreen.customers => Icons.people_rounded,
    AppScreen.settings => Icons.settings_rounded,
    AppScreen.gstr1 => Icons.receipt_long_rounded,
    AppScreen.partyLedger => Icons.account_balance_rounded,
    _ => Icons.article_rounded,
  };

  /// Returns the corresponding sidebar item ID string
  String get id {
    switch (this) {
      case AppScreen.executiveDashboard:
        return 'executive_dashboard';
      case AppScreen.newSale:
        return 'new_sale';
      case AppScreen.salesRegister:
        return 'sales_register';
      case AppScreen.stockSummary:
        return 'stock_summary';
      case AppScreen.itemStock:
        return 'item_stock';
      case AppScreen.customers:
        return 'customers';
      case AppScreen.partyLedger:
        return 'party_ledger';
      case AppScreen.outstanding:
        return 'outstanding';
      case AppScreen.gstr1:
        return 'gstr1';
      case AppScreen.transactionReports:
        return 'transaction_reports';
      case AppScreen.deviceSettings:
        return 'device_settings';
      case AppScreen.settings:
        return 'settings';
      case AppScreen.patientsList:
        return 'patients_list';
      case AppScreen.prescriptions:
        return 'prescriptions';
      case AppScreen.appointments:
        return 'appointments';
      case AppScreen.addPatient:
        return 'add_patient';

      default:
        // Convert camelCase name to snake_case (e.g. liveHealth -> live_health)
        return name.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        );
    }
  }

  /// Helper to find screen from ID
  static AppScreen fromId(String id) {
    switch (id) {
      case 'executive_dashboard':
        return AppScreen.executiveDashboard;
      case 'new_sale':
        return AppScreen.newSale;
      case 'sales_register':
        return AppScreen.salesRegister;
      case 'stock_summary':
        return AppScreen.stockSummary;
      case 'item_stock':
        return AppScreen.itemStock;
      case 'customers':
        return AppScreen.customers;
      case 'party_ledger':
        return AppScreen.partyLedger;
      case 'outstanding':
        return AppScreen.outstanding;
      case 'gstr1':
        return AppScreen.gstr1;
      case 'transaction_reports':
        return AppScreen.transactionReports;
      case 'device_settings':
        return AppScreen.deviceSettings;
      case 'settings':
        return AppScreen.settings;
      case 'patients_list':
        return AppScreen.patientsList;
      case 'prescriptions':
        return AppScreen.prescriptions;
      case 'appointments':
        return AppScreen.appointments;
      case 'add_patient':
        return AppScreen.addPatient;

      // Explicit mappings
      case 'clinic_dashboard':
        return AppScreen.clinicDashboard;
      case 'daily_appointments':
        return AppScreen.appointments;
      case 'restaurant_tables':
        return AppScreen.restaurantTables;
      case 'service_jobs':
        return AppScreen.serviceJobs;
      case 'exchanges':
        return AppScreen.exchanges;
      case 'revenue_overview':
        return AppScreen.revenueOverview;
      case 'receipt_entry':
        return AppScreen.receiptEntry;
      case 'proforma_bids':
        return AppScreen.proformaBids;
      case 'booking_orders':
        return AppScreen.bookingOrders;
      case 'dispatch_notes':
        return AppScreen.dispatchNotes;
      case 'return_inwards':
        return AppScreen.returnInwards;
      case 'alert':
      case 'alerts':
        return AppScreen.alerts;
      case 'daily_snapshot':
        return AppScreen.dailySnapshot;

      // Mappings for newly wired screens
      case 'buyflow_dashboard':
        return AppScreen.buyflowDashboard;
      case 'purchase_orders':
        return AppScreen.purchaseOrders;
      case 'stock_entry':
        return AppScreen.stockEntry;
      case 'stock_reversal':
        return AppScreen.stockReversal;
      case 'procurement_log':
        return AppScreen.procurementLog;
      case 'supplier_bills':
        return AppScreen.supplierBills;
      case 'purchase_register':
        return AppScreen.purchaseRegister;
      case 'insights':
        return AppScreen.insights;
      case 'daybook':
        return AppScreen.daybook;
      case 'credit_notes':
        return AppScreen.creditNotes;
      case 'backup':
        return AppScreen.backup;
      case 'analytics_hub':
        return AppScreen.analyticsHub;
      case 'catalogue':
        return AppScreen.catalogue;

      default:
        // Try to match by normalized name (ignoring underscores and case)
        final normalizedId = id.toLowerCase().replaceAll('_', '');
        for (var screen in values) {
          if (screen.name.toLowerCase() == normalizedId) return screen;
        }
        return AppScreen.unknown;
    }
  }
}
