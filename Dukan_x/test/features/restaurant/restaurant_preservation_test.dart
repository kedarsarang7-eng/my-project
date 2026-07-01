// ============================================================================
// TASK 2 — PRESERVATION PROPERTY TESTS (bugfix workflow)
// Feature: restaurant-vertical-remediation
// Property 2: Preservation — Non-Restaurant Sidebar Resolution & Existing
//             Behavior Unchanged
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.10, 3.11**
// ============================================================================
//
// METHODOLOGY: Observation-first.
//   1. Observe the current (unfixed) behavior of each function under test.
//   2. Encode those observations as assertions.
//   3. All tests MUST PASS on unfixed code — that confirms baseline.
//   4. After the fix, re-run to verify no regressions (Property 2).
//
// OBSERVATIONS (recorded on UNFIXED code):
//   - Non-restaurant sidebar items resolve to their expected widget types.
//   - RestaurantBusinessRules.splitBill(1000, 2) → [500.0, 500.0]
//   - RestaurantBusinessRules.serviceCharge(1000) → 50.0
//   - OrderType.fromString('DINE_IN') → OrderType.dineIn
//   - OrderType.fromString('TAKEAWAY') → OrderType.takeaway
//   - BusinessTypeRegistry restaurant config: defaultGstRate == 5.0,
//     gstEditable == false
//
// PBT library: dartproptest ^0.2.1.
// Run: flutter test test/features/restaurant/restaurant_preservation_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/restaurant/data/models/food_order_model.dart';
import 'package:dukanx/features/restaurant/utils/restaurant_business_rules.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

// Screen imports for type assertion on non-restaurant sidebar items.
import 'package:dukanx/features/billing/presentation/screens/bill_creation_screen_v2.dart';
import 'package:dukanx/features/revenue/screens/revenue_overview_screen.dart';
import 'package:dukanx/features/revenue/screens/sales_register_screen.dart';
import 'package:dukanx/features/inventory/presentation/screens/stock_summary_screen.dart';
import 'package:dukanx/features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import 'package:dukanx/features/inventory/presentation/screens/low_stock_alerts_screen.dart';
import 'package:dukanx/features/inventory/presentation/screens/stock_valuation_screen.dart';
import 'package:dukanx/features/inventory/presentation/screens/batch_tracking_screen.dart';
import 'package:dukanx/features/inventory/presentation/screens/damage_logs_screen.dart';
import 'package:dukanx/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:dukanx/features/party_ledger/screens/party_ledger_list_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/reports_hub_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/all_transactions_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/pnl_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/cashflow_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/balance_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/trial_balance_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/purchase_report_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/bill_wise_profit_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/print_menu_screen.dart';
import 'package:dukanx/features/reports/presentation/screens/product_performance_screen.dart';
import 'package:dukanx/features/backup/screens/backup_screen.dart';
import 'package:dukanx/features/buy_flow/screens/buy_flow_dashboard.dart';
import 'package:dukanx/features/buy_flow/screens/buy_orders_screen.dart';
import 'package:dukanx/features/buy_flow/screens/stock_entry_screen.dart';
import 'package:dukanx/features/buy_flow/screens/stock_reversal_screen.dart';
import 'package:dukanx/features/buy_flow/screens/vendor_payouts_screen.dart';
import 'package:dukanx/features/buy_flow/screens/procurement_log_screen.dart';
import 'package:dukanx/features/buy_flow/screens/supplier_bills_screen.dart';
import 'package:dukanx/features/revenue/screens/receipt_entry_screen.dart';
import 'package:dukanx/features/revenue/screens/return_inwards_screen.dart';
import 'package:dukanx/features/revenue/screens/proforma_screen.dart';
import 'package:dukanx/features/revenue/screens/booking_order_screen.dart';
import 'package:dukanx/features/revenue/screens/dispatch_note_screen.dart';
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';
import 'package:dukanx/features/settings/presentation/screens/error_logs_screen.dart';
import 'package:dukanx/features/settings/presentation/screens/device_settings_screen.dart';

/// Number of PBT runs — enough for confidence across the domain.
const int kNumRuns = 50;

/// A real, non-'SYSTEM' tenant id for GetIt registration (needed after P0 fix).
const String kBusinessId = 'usr_pizza_palace_123';

/// Lightweight fake [SessionManager] — the P0-fixed sidebar handler resolves
/// vendorId via `sl<SessionManager>().currentBusinessId`. We register this so
/// the restaurant items resolve without crashing.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager(this._businessId);
  final String? _businessId;

  @override
  String? get currentBusinessId => _businessId;

  @override
  String? get userId => _businessId;
}

// ---------------------------------------------------------------------------
// NON-RESTAURANT SIDEBAR ITEMS — the full catalog of items that MUST NOT be
// affected by the restaurant vendorId fix (Preservation 3.1, 3.6, 3.11).
//
// Each entry maps an itemId to its OBSERVED runtime type on UNFIXED code.
// ---------------------------------------------------------------------------
const Map<String, Type> kNonRestaurantItems = <String, Type>{
  'new_sale': BillCreationScreenV2,
  'revenue_overview': RevenueOverviewScreen,
  'receipt_entry': ReceiptEntryScreen,
  'return_inwards': ReturnInwardsScreen,
  'proforma_bids': ProformaScreen,
  'booking_orders': BookingOrderScreen,
  'dispatch_notes': DispatchNoteScreen,
  'sales_register': SalesRegisterScreen,
  'buyflow_dashboard': BuyFlowDashboard,
  'purchase_orders': BuyOrdersScreen,
  'stock_entry': StockEntryScreen,
  'stock_reversal': StockReversalScreen,
  'vendor_payouts': VendorPayoutsScreen,
  'procurement_log': ProcurementLogScreen,
  'supplier_bills': SupplierBillsScreen,
  'stock_summary': StockSummaryScreen,
  'item_stock': InventoryDashboardScreen,
  'batch_tracking': BatchTrackingScreen,
  'low_stock': LowStockAlertsScreen,
  'stock_valuation': StockValuationScreen,
  'damage_logs': DamageLogsScreen,
  'customers': CustomersListScreen,
  'party_ledger': PartyLedgerListScreen,
  'analytics_hub': ReportsHubScreen,
  'product_performance': ProductPerformanceScreen,
  'invoice_margin': PnlScreen,
  'income_statement': PnlScreen,
  'funds_flow': CashflowScreen,
  'financial_position': BalanceScreen,
  'print_settings': PrintMenuScreen,
  'backup': BackupScreen,
  'error_logs': ErrorLogsScreen,
  'device_settings': DeviceSettingsScreen,
  'ledger_history': AllTransactionsScreen,
  'ledger_abstract': TrialBalanceScreen,
  'procurement_insights': PurchaseReportScreen,
  'margin_analysis': BillWiseProfitScreen,
};

/// Ordered list of item IDs for index-based PBT generation.
final List<String> kNonRestaurantItemIds = kNonRestaurantItems.keys.toList(
  growable: false,
);

void main() {
  setUp(() async {
    await GetIt.I.reset();
    // Register SessionManager so the P0-fixed sidebar handler can resolve
    // vendorId for restaurant items without throwing.
    GetIt.I.registerSingleton<SessionManager>(FakeSessionManager(kBusinessId));
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  // =========================================================================
  // OBSERVATION TESTS — verify current behavior on UNFIXED code
  // =========================================================================

  group('Observation: RestaurantBusinessRules (Req 3.10)', () {
    test('splitBill(1000, 2) returns [500.0, 500.0]', () {
      final parts = RestaurantBusinessRules.splitBill(1000, 2);
      expect(parts, equals([500.0, 500.0]));
    });

    test('serviceCharge(1000) returns 50.0', () {
      expect(RestaurantBusinessRules.serviceCharge(1000), equals(50.0));
    });
  });

  group('Observation: OrderType.fromString (Req 3.4)', () {
    test('fromString("DINE_IN") returns OrderType.dineIn', () {
      expect(OrderType.fromString('DINE_IN'), equals(OrderType.dineIn));
    });

    test('fromString("TAKEAWAY") returns OrderType.takeaway', () {
      expect(OrderType.fromString('TAKEAWAY'), equals(OrderType.takeaway));
    });
  });

  group('Observation: GST rate for restaurant (Req 3.3)', () {
    test('restaurant defaultGstRate is 5.0', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(config.defaultGstRate, 5.0);
    });

    test('restaurant gstEditable is false', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(config.gstEditable, false);
    });
  });

  // =========================================================================
  // PROPERTY-BASED TESTS — preservation properties
  // =========================================================================

  group(
    'Property 2: Preservation — Non-Restaurant Sidebar Resolution (Req 3.1, 3.6, 3.11)',
    () {
      testWidgets('PBT: for all non-restaurant sidebar item IDs, the widget type '
          'returned is identical to the observed baseline', (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final bool held = forAll(
          (int idx) {
            final itemId = kNonRestaurantItemIds[idx];
            final expectedType = kNonRestaurantItems[itemId]!;
            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              itemId,
              context,
            );
            // The resolved widget's runtime type must match the observed type.
            return screen != null && screen.runtimeType == expectedType;
          },
          <Generator<dynamic>>[
            Gen.interval(0, kNonRestaurantItemIds.length - 1),
          ],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'Preservation violation: a non-restaurant sidebar item resolved '
              'to a different widget type than the observed baseline. The '
              'restaurant fix must not alter any other sidebar resolution.',
        );
      });

      // Deterministic per-item verification for clear failure output.
      testWidgets(
        'each non-restaurant sidebar item resolves to its observed widget type',
        (tester) async {
          late BuildContext context;
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (ctx) {
                  context = ctx;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          for (final entry in kNonRestaurantItems.entries) {
            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              entry.key,
              context,
            );
            expect(
              screen,
              isNotNull,
              reason: '"${entry.key}" should resolve to a screen (not null).',
            );
            expect(
              screen.runtimeType,
              entry.value,
              reason:
                  '"${entry.key}" should resolve to ${entry.value} but got '
                  '${screen.runtimeType}.',
            );
          }
        },
      );
    },
  );

  group('Property 2: Preservation — OrderType fromString (Req 3.4)', () {
    test('PBT: for all existing OrderType values, fromString continues to '
        'return the correct enum value', () {
      // Domain: all current OrderType enum values and their string representations.
      final existingOrderTypes = <String, OrderType>{
        'DINE_IN': OrderType.dineIn,
        'TAKEAWAY': OrderType.takeaway,
      };
      final keys = existingOrderTypes.keys.toList();

      final bool held = forAll(
        (int idx) {
          final key = keys[idx % keys.length];
          final expected = existingOrderTypes[key]!;
          return OrderType.fromString(key) == expected;
        },
        <Generator<dynamic>>[Gen.interval(0, keys.length - 1)],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'Preservation violation: an existing OrderType string no longer '
            'resolves to the expected enum value.',
      );
    });

    test('OrderType.fromString fallback for unknown strings is dineIn', () {
      // Preservation: unknown strings must continue to fall back to dineIn.
      expect(OrderType.fromString('UNKNOWN'), OrderType.dineIn);
      expect(OrderType.fromString(''), OrderType.dineIn);
      expect(OrderType.fromString('INVALID'), OrderType.dineIn);
    });
  });

  group('Property 2: Preservation — serviceCharge formula (Req 3.10)', () {
    test(
      'PBT: for any subtotal > 0, serviceCharge(subtotal) == subtotal * 0.05 '
      '(within rounding precision)',
      () {
        final bool held = forAll(
          (int subtotalCents) {
            // Generate subtotals from 1 paise (0.01) to 100000.00.
            final subtotal = subtotalCents / 100.0;
            if (subtotal <= 0) return true; // skip zero/negative edge
            final charge = RestaurantBusinessRules.serviceCharge(subtotal);
            final expected = subtotal * 0.05;
            // Allow rounding tolerance of 1 paise (0.01).
            return (charge - expected).abs() <= 0.01;
          },
          <Generator<dynamic>>[Gen.interval(1, 10000000)],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'Preservation violation: serviceCharge formula deviated from '
              'subtotal * 0.05 (within rounding).',
        );
      },
    );
  });

  // =========================================================================
  // UNIT TESTS — specific preservation checks
  // =========================================================================

  group('Unit: BusinessQuickActions restaurant navigation targets (Req 3.7)', () {
    // NOTE: BusinessQuickActions navigates via AppScreen enum → the
    // NavigationController resolves the enum to a sidebar item ID. We verify
    // the SIDEBAR item IDs that the restaurant quick actions ultimately target.
    // The widget code calls:
    //   nav.navigateTo(AppScreen.restaurantTables)  → 'restaurant_tables'
    //   nav.navigateTo(AppScreen.kitchenDisplay)    → 'kitchen_display'
    //   nav.navigateTo(AppScreen.menuManagement)    → 'menu_management'
    //
    // We verify the sidebar handler resolves these item IDs to non-null screens.
    testWidgets('restaurant quick action sidebar item IDs resolve to screens', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      const quickActionItemIds = [
        'restaurant_tables',
        'kitchen_display',
        'menu_management',
      ];

      for (final itemId in quickActionItemIds) {
        final screen = SidebarNavigationHandler.tryGetScreenForItem(
          itemId,
          context,
        );
        expect(
          screen,
          isNotNull,
          reason:
              'Quick action target "$itemId" must resolve to a screen widget.',
        );
      }
    });
  });

  group('Unit: GST rate for restaurant remains 5%% non-editable (Req 3.3)', () {
    test('restaurant config: defaultGstRate == 5.0, gstEditable == false', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(
        config.defaultGstRate,
        5.0,
        reason:
            'Restaurant must retain 5%% fixed GST (no ITC). '
            'Changing this is out of scope for the remediation.',
      );
      expect(
        config.gstEditable,
        false,
        reason:
            'Restaurant GST must remain non-editable. '
            'Restaurants use a fixed 5%% rate without input tax credit.',
      );
    });
  });
}
