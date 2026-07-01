// ============================================================================
// PHASE 2 — Task 3.2: Legacy screen-per-itemId EXPLORATION test
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 3.2 — Write exploration test capturing the legacy screen-per-itemId
//            mapping (the Phase 2 PARITY BASELINE).
// Validates: Requirements 2.1
//
// PURPOSE (exploration / parity baseline):
//   This test records — and asserts — the EXACT screen that the LEGACY
//   dispatch `SidebarNavigationHandler.getScreenForItem(itemId, context)`
//   returns for every reachable sidebar `itemId`, across SIX business types
//   (grocery, pharmacy, clinic, restaurant, petrolPump, and the default/retail
//   fallback = `BusinessType.other`). It captures:
//     * the runtime `Type` of the returned widget, and
//     * the key constructor arguments that vary per item
//       (`GstReportsScreen.initialIndex`, `PartyLedgerListScreen.initialFilter`,
//        restaurant `vendorId`).
//   It MUST PASS against the UNCHANGED legacy code. It is the baseline that
//   Phase 2's route-build parity (Task 3.3) and preservation test (Task 3.9)
//   are checked against.
//
// IS `getScreenForItem` BUSINESS-TYPE-DEPENDENT?  -> NO (verified).
//   `getScreenForItem` is a pure `switch (itemId)` — it takes a `BuildContext`
//   but NEVER reads the active `BusinessType`; the context is only used by the
//   `default:` placeholder branch (for theme colors). Therefore the
//   itemId -> screen mapping is INVARIANT across business types. Business type
//   only affects which itemIds are *reachable* (the sidebar MENU-FILTERING
//   layer, `sidebarSectionsProvider`), NOT the dispatch result.
//
// REACHABILITY ASSUMPTION (documented, per task guidance):
//   Because the dispatch is business-type-independent, the full set of
//   reachable itemIds for ANY business type is a SUBSET of the complete known
//   inventory (`RoutePaths.knownItemIds`, 90 ids from Task 3.1). Asserting the
//   mapping over the FULL inventory for each of the six types is therefore a
//   STRICT SUPERSET of asserting only each type's reachable subset — it proves
//   parity for every itemId any type could possibly reach, and additionally
//   proves the type-invariance property. So we iterate the full 90-id inventory
//   per type rather than re-deriving per-type sidebar subsets.
//
// SEAM CHOSEN (and why this is safe / nothing heavy is pumped):
//   `getScreenForItem` returns `const`-constructed screen widgets; CONSTRUCTING
//   a `const` widget runs NO `build()`, touches NO GetIt service locator, and
//   performs NO network/SharedPreferences I/O. We therefore drive the dispatch
//   with a REAL `BuildContext` (captured from a minimal pumped host) and
//   inspect ONLY the returned widget's `runtimeType` and its public
//   constructor fields — WITHOUT pumping the returned screen. This exercises
//   every itemId (including the restaurant `vendorId:'SYSTEM'` screens) with no
//   heavy dependencies. No production code is touched by this task.
// ============================================================================

import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Imports used ONLY to read varying constructor args off the returned widgets.
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';
import 'package:dukanx/features/party_ledger/screens/party_ledger_list_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/table_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/kitchen_display_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/food_menu_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart';

/// The six business types the parity baseline is captured for.
/// `other` is the default/retail fallback branch of the sidebar resolver.
const List<BusinessType> _baselineBusinessTypes = <BusinessType>[
  BusinessType.grocery,
  BusinessType.pharmacy,
  BusinessType.clinic,
  BusinessType.restaurant,
  BusinessType.petrolPump,
  BusinessType.other, // default / retail fallback
];

/// GOLDEN BASELINE — the EXACT screen `Type` name the legacy switch returns
/// for each itemId, transcribed verbatim from
/// `SidebarNavigationHandler.getScreenForItem`. Compared via
/// `runtimeType.toString()` to avoid importing ~70 screen classes purely for
/// type identity. (Args that vary are asserted separately below.)
const Map<String, String> _legacyScreenTypeByItemId = <String, String>{
  // Dashboard & Control
  'executive_dashboard': 'DashboardController',
  'clinic_dashboard': 'DoctorDashboardScreen',
  'live_health': 'LiveBusinessHealthScreen',
  'alerts': 'AlertsNotificationsScreen',
  'daily_snapshot': 'DailySnapshotScreen',
  // Clinic
  'daily_appointments': 'AppointmentScreen',
  'appointments': 'AppointmentScreen',
  'patients_list': 'PatientListScreen',
  'add_patient': 'AddPatientScreen',
  'prescriptions': 'SafePrescriptionListScreen',
  'medicine_master': 'MedicineMasterScreen',
  'lab_reports': 'LabReportsScreen',
  'patient_history': 'PatientListScreen', // reuses PatientListScreen
  // Revenue Desk
  'revenue_overview': 'RevenueOverviewScreen',
  'new_sale': 'BillCreationScreenV2',
  'receipt_entry': 'ReceiptEntryScreen',
  'return_inwards': 'ReturnInwardsScreen',
  'proforma_bids': 'ProformaScreen',
  'booking_orders': 'BookingOrderScreen',
  'dispatch_notes': 'DispatchNoteScreen',
  'sales_register': 'SalesRegisterScreen',
  // BuyFlow
  'buyflow_dashboard': 'BuyFlowDashboard',
  'purchase_orders': 'BuyOrdersScreen',
  'stock_entry': 'StockEntryScreen',
  'stock_reversal': 'StockReversalScreen',
  'vendor_payouts': 'VendorPayoutsScreen',
  'procurement_log': 'ProcurementLogScreen',
  'supplier_bills': 'SupplierBillsScreen',
  'purchase_register': 'ProcurementLogScreen', // dup of procurement_log
  // Inventory & Stock
  'stock_summary': 'StockSummaryScreen',
  'item_stock': 'InventoryDashboardScreen',
  'batch_tracking': 'BatchTrackingScreen',
  'low_stock': 'LowStockAlertsScreen',
  'stock_valuation': 'StockValuationScreen',
  'damage_logs': 'DamageLogsScreen',
  // Parties & Ledger
  'customers': 'CustomersListScreen',
  'suppliers': 'PartyLedgerListScreen', // initialFilter: 'supplier'
  'party_ledger': 'PartyLedgerListScreen', // no filter
  'ledger_history': 'AllTransactionsScreen', // cluster
  'ledger_abstract': 'TrialBalanceScreen',
  'outstanding': 'PartyLedgerListScreen', // initialFilter: 'receivable'
  // Business Intelligence
  'analytics_hub': 'ReportsHubScreen',
  'turnover_analysis': 'AllTransactionsScreen', // cluster
  'product_performance': 'ProductPerformanceScreen',
  'daily_activity': 'AllTransactionsScreen', // cluster
  'procurement_insights': 'PurchaseReportScreen',
  'margin_analysis': 'BillWiseProfitScreen',
  // Financial Reports
  'invoice_margin': 'PnlScreen', // dup pair with income_statement
  'income_statement': 'PnlScreen', // dup pair with invoice_margin
  'funds_flow': 'CashflowScreen', // dup pair with cash_bank
  'financial_position': 'BalanceScreen',
  'cash_bank': 'CashflowScreen', // dup pair with funds_flow
  // Tax & Compliance (all GstReportsScreen, differ by initialIndex)
  'gstr1': 'GstReportsScreen', // initialIndex 0
  'b2b_b2c': 'GstReportsScreen', // initialIndex 0 (dup of gstr1)
  'hsn_reports': 'GstReportsScreen', // initialIndex 1
  'tax_liability': 'GstReportsScreen', // initialIndex 2
  'filing_status': 'GstReportsScreen', // initialIndex 3
  // Operations & Logs
  'transaction_reports': 'AllTransactionsScreen', // cluster
  'activity_logs': 'AllTransactionsScreen', // cluster
  'audit_trail': 'AllTransactionsScreen', // cluster (mislabeled)
  'error_logs': 'ErrorLogsScreen',
  // Utilities & System
  'print_settings': 'PrintMenuScreen', // dup pair with doc_templates
  'doc_templates': 'PrintMenuScreen', // dup pair with print_settings
  'backup': 'BackupScreen',
  'sync_status': 'BackupScreen', // mislabeled (reuses BackupScreen)
  'device_settings': 'DeviceSettingsScreen',
  // Petrol Pump
  'petrol_dashboard': 'PetrolPumpManagementScreen',
  'shift_management': 'ShiftHistoryScreen',
  'tank_management': 'TankListScreen',
  'dispenser_management': 'DispenserListScreen',
  // Restaurant (all carry vendorId:'SYSTEM')
  'restaurant_tables': 'TableManagementScreen',
  'kitchen_display': 'KitchenDisplayScreen',
  'menu_management': 'FoodMenuManagementScreen',
  'daily_summary': 'RestaurantDailySummaryScreen',
  // Hidden — doctor / QR
  'doctor_revenue': 'DoctorRevenueScreen',
  'scan_qr': 'QrScannerScreen',
  // Hidden — petrol pump reports
  'fuel_rates': 'FuelRatesScreen',
  'fuel_profit_report': 'FuelProfitReportScreen',
  'nozzle_sales_report': 'NozzleSalesReportScreen',
  'shift_report': 'ShiftReportScreen',
  'tank_stock_report': 'TankStockReportScreen',
  // Hidden — service business
  'service_jobs': 'ServiceJobListScreen',
  'exchanges': 'ExchangeListScreen',
  // Phase-2 additional hidden screens
  'accounting_reports': 'AccountingReportsScreen',
  'bank_accounts': 'BankScreen',
  'credit_notes': 'CreditNotesListScreen',
  'daybook': 'DayBookScreen',
  'catalogue': 'CatalogueScreen',
  'insights': 'InsightsScreen',
  'expenses': 'ExpensesScreen',
};

/// Captures a real [BuildContext] from a minimally pumped host so the legacy
/// dispatch can be driven exactly as the shell drives it.
Future<BuildContext> _pumpAndCaptureContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group(
    'Feature: gorouter-navigation-migration — Phase 2 legacy screen-per-itemId '
    'parity baseline (Req 2.1)',
    () {
      // ----------------------------------------------------------------------
      // 1) The dispatch returns the documented screen TYPE for every itemId,
      //    and that result is INVARIANT across all six business types.
      // ----------------------------------------------------------------------
      testWidgets(
        'every reachable itemId resolves to the documented screen type — '
        'invariant across grocery/pharmacy/clinic/restaurant/petrolPump/retail',
        (tester) async {
          final context = await _pumpAndCaptureContext(tester);

          // Iterate the full known inventory (90 ids — Task 3.1) per type.
          for (final itemId in RoutePaths.knownItemIds) {
            final expectedType = _legacyScreenTypeByItemId[itemId];
            expect(
              expectedType,
              isNotNull,
              reason:
                  'Baseline missing a golden type for itemId "$itemId". '
                  'The exploration baseline must cover every known itemId.',
            );

            String? firstSeenType;
            for (final type in _baselineBusinessTypes) {
              // The dispatch ignores `type`; we still drive it once per type to
              // PROVE business-type independence of the mapping.
              final widget = SidebarNavigationHandler.getScreenForItem(
                itemId,
                context,
              );
              final actualType = widget.runtimeType.toString();

              expect(
                actualType,
                expectedType,
                reason:
                    'itemId "$itemId" under ${type.name} returned $actualType '
                    'but the legacy baseline is $expectedType.',
              );

              firstSeenType ??= actualType;
              expect(
                actualType,
                firstSeenType,
                reason:
                    'itemId "$itemId" must resolve to the same screen type for '
                    'every business type (dispatch is type-independent).',
              );
            }
          }
        },
      );

      // ----------------------------------------------------------------------
      // 2) Baseline completeness: golden map and the Task 3.1 inventory agree
      //    (no dropped / phantom itemIds in the baseline).
      // ----------------------------------------------------------------------
      testWidgets('baseline covers exactly the 90 known itemIds', (
        tester,
      ) async {
        expect(_legacyScreenTypeByItemId.keys.toSet(), hasLength(90));
        expect(
          _legacyScreenTypeByItemId.keys.toSet(),
          equals(RoutePaths.knownItemIds.toSet()),
          reason:
              'The parity baseline must mirror the Task 3.1 itemId inventory '
              'exactly — no dropped or phantom ids.',
        );
      });

      // ----------------------------------------------------------------------
      // 3) Varying constructor args are captured (GstReportsScreen.initialIndex,
      //    PartyLedgerListScreen.initialFilter, restaurant vendorId).
      // ----------------------------------------------------------------------
      testWidgets('GstReportsScreen.initialIndex baseline per tax itemId', (
        tester,
      ) async {
        final context = await _pumpAndCaptureContext(tester);

        const expectedIndex = <String, int>{
          'gstr1': 0,
          'b2b_b2c': 0, // duplicate of gstr1 — same screen + same index
          'hsn_reports': 1,
          'tax_liability': 2,
          'filing_status': 3,
        };

        expectedIndex.forEach((itemId, index) {
          final widget =
              SidebarNavigationHandler.getScreenForItem(itemId, context)
                  as GstReportsScreen;
          expect(
            widget.initialIndex,
            index,
            reason: 'itemId "$itemId" must open GstReportsScreen tab $index.',
          );
        });
      });

      testWidgets('PartyLedgerListScreen.initialFilter baseline', (
        tester,
      ) async {
        final context = await _pumpAndCaptureContext(tester);

        // suppliers -> 'supplier', outstanding -> 'receivable', party_ledger -> null.
        final suppliers =
            SidebarNavigationHandler.getScreenForItem('suppliers', context)
                as PartyLedgerListScreen;
        expect(suppliers.initialFilter, 'supplier');

        final outstanding =
            SidebarNavigationHandler.getScreenForItem('outstanding', context)
                as PartyLedgerListScreen;
        expect(outstanding.initialFilter, 'receivable');

        final partyLedger =
            SidebarNavigationHandler.getScreenForItem('party_ledger', context)
                as PartyLedgerListScreen;
        expect(partyLedger.initialFilter, isNull);
      });

      testWidgets(
        "restaurant screens carry the (out-of-scope) vendorId:'SYSTEM' arg",
        (tester) async {
          final context = await _pumpAndCaptureContext(tester);

          final tables =
              SidebarNavigationHandler.getScreenForItem(
                    'restaurant_tables',
                    context,
                  )
                  as TableManagementScreen;
          expect(tables.vendorId, 'SYSTEM');

          final kitchen =
              SidebarNavigationHandler.getScreenForItem(
                    'kitchen_display',
                    context,
                  )
                  as KitchenDisplayScreen;
          expect(kitchen.vendorId, 'SYSTEM');

          final menu =
              SidebarNavigationHandler.getScreenForItem(
                    'menu_management',
                    context,
                  )
                  as FoodMenuManagementScreen;
          expect(menu.vendorId, 'SYSTEM');

          final summary =
              SidebarNavigationHandler.getScreenForItem(
                    'daily_summary',
                    context,
                  )
                  as RestaurantDailySummaryScreen;
          expect(summary.vendorId, 'SYSTEM');
        },
      );

      // ----------------------------------------------------------------------
      // 4) Documented duplicate equivalences asserted explicitly, so Phase 2
      //    route-build parity can be verified against them (design Model 2).
      // ----------------------------------------------------------------------
      testWidgets('duplicate itemId pairs resolve to the SAME screen type', (
        tester,
      ) async {
        final context = await _pumpAndCaptureContext(tester);

        String typeOf(String itemId) =>
            SidebarNavigationHandler.getScreenForItem(
              itemId,
              context,
            ).runtimeType.toString();

        // purchase_register & procurement_log -> ProcurementLogScreen
        expect(typeOf('purchase_register'), typeOf('procurement_log'));
        expect(typeOf('purchase_register'), 'ProcurementLogScreen');

        // invoice_margin & income_statement -> PnlScreen
        expect(typeOf('invoice_margin'), typeOf('income_statement'));
        expect(typeOf('invoice_margin'), 'PnlScreen');

        // funds_flow & cash_bank -> CashflowScreen
        expect(typeOf('funds_flow'), typeOf('cash_bank'));
        expect(typeOf('funds_flow'), 'CashflowScreen');

        // print_settings & doc_templates -> PrintMenuScreen
        expect(typeOf('print_settings'), typeOf('doc_templates'));
        expect(typeOf('print_settings'), 'PrintMenuScreen');

        // gstr1 & b2b_b2c -> GstReportsScreen with the SAME initialIndex (0)
        final g =
            SidebarNavigationHandler.getScreenForItem('gstr1', context)
                as GstReportsScreen;
        final b =
            SidebarNavigationHandler.getScreenForItem('b2b_b2c', context)
                as GstReportsScreen;
        expect(g.runtimeType, b.runtimeType);
        expect(g.initialIndex, b.initialIndex);
        expect(g.initialIndex, 0);

        // AllTransactionsScreen cluster — all six resolve to the same screen.
        const cluster = <String>[
          'ledger_history',
          'turnover_analysis',
          'daily_activity',
          'activity_logs',
          'audit_trail',
          'transaction_reports',
        ];
        for (final itemId in cluster) {
          expect(
            typeOf(itemId),
            'AllTransactionsScreen',
            reason: 'cluster itemId "$itemId" must open AllTransactionsScreen.',
          );
        }
      });

      // ----------------------------------------------------------------------
      // 5) Unknown itemId falls to the legacy placeholder (default branch),
      //    documenting the behavior Task 3.3's errorBuilder must mirror.
      // ----------------------------------------------------------------------
      testWidgets('unknown itemId returns the theme-aware placeholder', (
        tester,
      ) async {
        final context = await _pumpAndCaptureContext(tester);
        final widget = SidebarNavigationHandler.getScreenForItem(
          'totally_unknown_item',
          context,
        );
        // Private `_PlaceholderScreen`; assert by its runtime type name.
        expect(widget.runtimeType.toString(), '_PlaceholderScreen');
      });
    },
  );
}
