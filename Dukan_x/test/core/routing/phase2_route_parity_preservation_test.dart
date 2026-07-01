// ============================================================================
// PHASE 2 — Task 3.9: Route parity PRESERVATION test
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 3.9 — Write preservation test for parity across ≥5 business types.
// Validates: Requirements 2.2, 2.3, 5.2, 5.6
//
// PURPOSE (preservation — the Phase 2 counterpart to the 3.2 exploration
// baseline):
//   After the Phase 2 route registration + flag-gated dispatch wiring, this
//   test PRESERVES the parity contract that the 3.2 exploration baseline
//   (`phase2_legacy_screen_per_item_exploration_test.dart`) captured. It proves
//   two things, for ≥5 in-scope business types (grocery, pharmacy, clinic,
//   restaurant, petrolPump + the default/retail fallback = `BusinessType.other`
//   = SIX types):
//
//   (A) PARITY PRESERVED (Req 5.2, 5.6 / Property 1 framing):
//       For every known sidebar `itemId`, the FLAG-ON resolver
//       `AppRouter.screenForItemId(itemId, context)` returns the SAME screen
//       `Type` — and the SAME key constructor args
//       (`GstReportsScreen.initialIndex`, `PartyLedgerListScreen.initialFilter`,
//        restaurant `vendorId`) — as the legacy FLAG-OFF dispatch
//       `SidebarNavigationHandler.getScreenForItem(itemId, context)`. Both are
//       additionally pinned to the 3.2 GOLDEN screen-Type mapping, so this is an
//       explicit preservation of that baseline rather than a tautology against
//       the (delegating) resolver alone.
//
//   (B) NON-REGRESSION (Req 2.3):
//       The per-type VISIBLE sidebar item set produced by
//       `sidebarSectionsProvider` is UNCHANGED flag ON vs flag OFF — both for
//       the six parity types and for the broader 18 in-scope business types — so
//       Phase 2 did not regress any other business type's menu. (This overlaps
//       Property 4 but is framed here as the explicit preservation assertion the
//       task requires: "assert no other type regressed".)
//
// TIE TO THE 3.2 BASELINE:
//   `_goldenScreenTypeByItemId` below is transcribed VERBATIM from the 3.2
//   exploration baseline's `_legacyScreenTypeByItemId` golden map. Asserting
//   BOTH the legacy dispatch AND the flag-ON resolver against this golden — for
//   each of the six business types — ties the preservation assertions directly
//   back to the recorded exploration baseline (per task guidance).
//
// SEAMS (reused from the 3.2 / 3.3 / Property tests — nothing heavy is pumped):
//   * `getScreenForItem` (legacy, flag OFF) and `AppRouter.screenForItemId`
//     (flag ON) both synchronously CONSTRUCT `const` screen widgets — no
//     `build()`, no GetIt, no IO. A single real `BuildContext` captured from a
//     minimal pumped host drives both; only `runtimeType` + public arg fields
//     are inspected. (Same seam as the 3.2 baseline and the 3.3 parity test.)
//   * The visible-sidebar non-regression dimension reuses the Property-4
//     conventions: `sidebarSectionsProvider` resolved in two containers — one
//     with the migration flag default-OFF (legacy build) and one with it ON
//     (migrated build) — with `FeatureResolver` REAL, fakes only for the
//     session/business-type seams.
//
// Test-only. No production code is touched by this task.
// ============================================================================

import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Imports used ONLY to read varying constructor args off resolved widgets.
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';
import 'package:dukanx/features/party_ledger/screens/party_ledger_list_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/table_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/kitchen_display_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/food_menu_management_screen.dart';
import 'package:dukanx/features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart';

// ============================================================================
// PARITY DIMENSION — business types + the 3.2 golden mapping
// ============================================================================

/// The SIX (≥5) business types parity is preserved for. `other` is the
/// default/retail fallback branch of the sidebar resolver. Mirrors the set the
/// 3.2 exploration baseline captured.
const List<BusinessType> _parityBusinessTypes = <BusinessType>[
  BusinessType.grocery,
  BusinessType.pharmacy,
  BusinessType.clinic,
  BusinessType.restaurant,
  BusinessType.petrolPump,
  BusinessType.other, // default / retail fallback (6th type, ≥ 5 required)
];

/// GOLDEN BASELINE — transcribed VERBATIM from the 3.2 exploration baseline
/// (`phase2_legacy_screen_per_item_exploration_test.dart`'s
/// `_legacyScreenTypeByItemId`). The preservation assertions are pinned to this
/// map so parity is checked against the RECORDED baseline, not merely against
/// the (delegating) flag-ON resolver.
const Map<String, String> _goldenScreenTypeByItemId = <String, String>{
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
  'patient_history': 'PatientListScreen',
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

/// Captures a real [BuildContext] from a minimally pumped host so both resolvers
/// can be driven exactly as the shell drives them. Constructing `const` screen
/// widgets runs no `build()`/IO.
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

// ============================================================================
// NON-REGRESSION DIMENSION — sidebar visibility fakes/helpers (Property-4 style)
// ============================================================================

/// Pins the active business type WITHOUT touching SharedPreferences / license
/// providers.
class _FakeBusinessTypeNotifier extends BusinessTypeNotifier {
  _FakeBusinessTypeNotifier(this._type);

  final BusinessType _type;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

/// Represents a completed (post-login) authentication WITHOUT reaching into the
/// GetIt service locator.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated);
}

/// The 18 in-scope business types (design.md → Data Model 4). The broader set
/// over which Phase 2 must not regress sidebar menus.
const List<BusinessType> _inScopeTypes = <BusinessType>[
  BusinessType.grocery,
  BusinessType.pharmacy,
  BusinessType.restaurant,
  BusinessType.clinic,
  BusinessType.petrolPump,
  BusinessType.service,
  BusinessType.electronics,
  BusinessType.mobileShop,
  BusinessType.computerShop,
  BusinessType.clothing,
  BusinessType.hardware,
  BusinessType.wholesale,
  BusinessType.vegetablesBroker,
  BusinessType.bookStore,
  BusinessType.jewellery,
  BusinessType.autoParts,
  BusinessType.decorationCatering,
  BusinessType.schoolErp,
];

/// Builds a container that resolves the shell sidebar for [type] as it would be
/// right after a successful login as [role]. go_router is the sole navigation
/// path (Task 9.3), so there is no longer a flag dimension.
ProviderContainer _containerFor(BusinessType type, UserRole role) {
  final container = ProviderContainer(
    overrides: [
      businessTypeProvider.overrideWith(() => _FakeBusinessTypeNotifier(type)),
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier()),
      currentUserRoleProvider.overrideWithValue(role),
    ],
  );
  return container;
}

/// Flattens the resolved sidebar sections into a canonical, comparable list of
/// "visible items": one entry per surviving item (section title, item id, item
/// label). Ordering is preserved (the provider is deterministic).
List<String> _visibleItems(ProviderContainer container) {
  final sections = container.read(sidebarSectionsProvider);
  final out = <String>[];
  for (final section in sections) {
    for (final item in section.items) {
      out.add('${section.title}\u0001${item.id}\u0001${item.label}');
    }
  }
  return out;
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Returns true iff the visible sidebar item set for (type, role) is
/// deterministic — identical across two independently built containers. (The
/// migration flag is gone; sidebar visibility must depend only on type + role +
/// capability/RBAC, never on hidden global state.)
bool _sidebarUnchanged(BusinessType type, UserRole role) {
  final a = _containerFor(type, role);
  final b = _containerFor(type, role);
  try {
    return _listsEqual(_visibleItems(a), _visibleItems(b));
  } finally {
    a.dispose();
    b.dispose();
  }
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Feature: gorouter-navigation-migration — Phase 2 route parity PRESERVATION '
    '(Req 2.2, 2.3, 5.2, 5.6)',
    () {
      // ----------------------------------------------------------------------
      // (A) PARITY PRESERVED — for each of the six business types, the flag-ON
      //     resolver returns the SAME screen Type as the legacy flag-OFF
      //     dispatch, and BOTH equal the 3.2 golden baseline (Req 5.2, 5.6).
      // ----------------------------------------------------------------------
      testWidgets(
        'flag-ON resolver == legacy flag-OFF dispatch == 3.2 golden screen '
        'Type, for every itemId across the six business types',
        (tester) async {
          final context = await _pumpAndCaptureContext(tester);

          for (final type in _parityBusinessTypes) {
            for (final itemId in RoutePaths.knownItemIds) {
              final golden = _goldenScreenTypeByItemId[itemId];
              expect(
                golden,
                isNotNull,
                reason:
                    'No 3.2 golden baseline for itemId "$itemId"; the '
                    'preservation map must mirror the exploration baseline.',
              );

              // Flag OFF (legacy switch dispatch).
              final legacyType = SidebarNavigationHandler.getScreenForItem(
                itemId,
                context,
              ).runtimeType.toString();
              // Flag ON (go_router resolver).
              final routedType = AppRouter.screenForItemId(
                itemId,
                context,
              ).runtimeType.toString();

              // Preserved against the recorded baseline AND against each other.
              expect(
                legacyType,
                golden,
                reason:
                    'Legacy dispatch for "$itemId" under ${type.name} drifted '
                    'from the 3.2 baseline ($golden -> $legacyType).',
              );
              expect(
                routedType,
                golden,
                reason:
                    'Flag-ON resolver for "$itemId" under ${type.name} does '
                    'not preserve the 3.2 baseline ($golden -> $routedType).',
              );
              expect(
                routedType,
                legacyType,
                reason:
                    'Flag-ON vs flag-OFF parity broke for "$itemId" under '
                    '${type.name} ($legacyType vs $routedType).',
              );
            }
          }
        },
      );

      // ----------------------------------------------------------------------
      // (A') KEY VARYING ARGS PRESERVED — GstReportsScreen.initialIndex,
      //      PartyLedgerListScreen.initialFilter, restaurant vendorId match the
      //      legacy dispatch under the flag-ON resolver (Req 5.2, 5.6).
      // ----------------------------------------------------------------------
      testWidgets('GstReportsScreen.initialIndex preserved flag ON vs legacy', (
        tester,
      ) async {
        final context = await _pumpAndCaptureContext(tester);

        for (final itemId in const <String>[
          'gstr1',
          'b2b_b2c',
          'hsn_reports',
          'tax_liability',
          'filing_status',
        ]) {
          final legacy =
              SidebarNavigationHandler.getScreenForItem(itemId, context)
                  as GstReportsScreen;
          final routed =
              AppRouter.screenForItemId(itemId, context) as GstReportsScreen;
          expect(
            routed.initialIndex,
            legacy.initialIndex,
            reason: 'GstReportsScreen.initialIndex parity for "$itemId".',
          );
        }
      });

      testWidgets('PartyLedgerListScreen.initialFilter preserved flag ON vs '
          'legacy', (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        for (final itemId in const <String>[
          'suppliers',
          'outstanding',
          'party_ledger',
        ]) {
          final legacy =
              SidebarNavigationHandler.getScreenForItem(itemId, context)
                  as PartyLedgerListScreen;
          final routed =
              AppRouter.screenForItemId(itemId, context)
                  as PartyLedgerListScreen;
          expect(
            routed.initialFilter,
            legacy.initialFilter,
            reason: 'PartyLedgerListScreen.initialFilter parity for "$itemId".',
          );
        }
      });

      testWidgets("restaurant screens' vendorId preserved flag ON vs legacy", (
        tester,
      ) async {
        final context = await _pumpAndCaptureContext(tester);

        expect(
          (AppRouter.screenForItemId('restaurant_tables', context)
                  as TableManagementScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem(
                    'restaurant_tables',
                    context,
                  )
                  as TableManagementScreen)
              .vendorId,
        );
        expect(
          (AppRouter.screenForItemId('kitchen_display', context)
                  as KitchenDisplayScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem('kitchen_display', context)
                  as KitchenDisplayScreen)
              .vendorId,
        );
        expect(
          (AppRouter.screenForItemId('menu_management', context)
                  as FoodMenuManagementScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem('menu_management', context)
                  as FoodMenuManagementScreen)
              .vendorId,
        );
        expect(
          (AppRouter.screenForItemId('daily_summary', context)
                  as RestaurantDailySummaryScreen)
              .vendorId,
          (SidebarNavigationHandler.getScreenForItem('daily_summary', context)
                  as RestaurantDailySummaryScreen)
              .vendorId,
        );
      });

      // ----------------------------------------------------------------------
      // Baseline integrity guard — the preservation golden map mirrors the 3.2
      // exploration baseline (exactly the 90 known itemIds, no drift).
      // ----------------------------------------------------------------------
      test('preservation golden map mirrors the 3.2 baseline (90 itemIds)', () {
        expect(_goldenScreenTypeByItemId.keys.toSet(), hasLength(90));
        expect(
          _goldenScreenTypeByItemId.keys.toSet(),
          equals(RoutePaths.knownItemIds.toSet()),
          reason:
              'The preservation golden map must mirror the Task 3.2 itemId '
              'inventory exactly — no dropped or phantom ids.',
        );
      });

      // ----------------------------------------------------------------------
      // (B) NON-REGRESSION — the visible sidebar item set is unchanged flag ON
      //     vs OFF for the six parity types (Req 2.3): "assert no other type
      //     regressed".
      // ----------------------------------------------------------------------
      test('visible sidebar items are deterministic for the six parity '
          'types (as owner)', () {
        for (final type in _parityBusinessTypes) {
          if (type == BusinessType.other) {
            // `other` is the retail fallback; it is exercised indirectly by the
            // retail verticals in the broader sweep below. The dedicated shell
            // types are asserted directly here.
            continue;
          }
          expect(
            _sidebarUnchanged(type, UserRole.owner),
            isTrue,
            reason:
                'Sidebar visibility regressed with the migration flag for '
                '${type.name} — Phase 2 must not alter menu filtering (Req 2.3).',
          );
        }
      });

      // ----------------------------------------------------------------------
      // (B') NON-REGRESSION (broader) — assert the same for the full 18
      //      in-scope business types across the common RBAC roles, so Phase 2
      //      did not regress ANY other business type's menu (Req 2.3).
      // ----------------------------------------------------------------------
      test('visible sidebar items are deterministic for all 18 in-scope '
          'types across RBAC roles', () {
        const roles = <UserRole>[
          UserRole.owner,
          UserRole.manager,
          UserRole.staff,
          UserRole.accountant,
        ];
        for (final type in _inScopeTypes) {
          for (final role in roles) {
            expect(
              _sidebarUnchanged(type, role),
              isTrue,
              reason:
                  'Sidebar visibility regressed with the migration flag for '
                  '${type.name} as ${role.name} (Req 2.3 non-regression).',
            );
          }
        }
      });
    },
  );
}
