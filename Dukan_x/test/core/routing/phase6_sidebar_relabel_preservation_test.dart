// ============================================================================
// PHASE 6 — Task 7.4: PRESERVATION test for sidebar relabels (Audit Trail /
// Sync Status) (go_router navigation migration — sidebar cleanup)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 7.4 — Preservation test for sidebar labels/links.
// Validates: Requirements 2.2, 2.3
//
// PURPOSE (preservation half of the exploration -> fix -> preservation triple):
//   Phase 6 / Task 7.2 made LABEL-ONLY changes in
//   `lib/widgets/desktop/sidebar_configuration.dart`:
//     * `audit_trail` : label "Audit Trail" -> "All Transactions";
//                       icon -> Icons.list_alt_outlined. itemId/route UNCHANGED
//                       (still opens AllTransactionsScreen).
//     * `sync_status` : label "Sync Status" -> "Backup & Sync" (clinic "System"
//                       section AND retail "Utilities & System" section).
//                       itemId/route UNCHANGED (still opens BackupScreen).
//   No route_paths.dart / app_router.dart / capability changes; all itemIds
//   preserved.
//
//   This suite OWNS the post-relabel assertions and proves the multi-business-
//   type NON-REGRESSION rule (Req 2.3): the relabel did not drop/add any
//   sidebar itemId for any in-scope business type, and the relabeled items
//   STILL resolve to the same screens.
//
//   THREE THINGS PROVEN:
//
//   (1) LINK PRESERVED (Req 2.2 — label-only change):
//       The relabeled itemIds STILL resolve to the same screens via BOTH the
//       legacy `SidebarNavigationHandler.getScreenForItem` (flag OFF) and the
//       go_router resolver `AppRouter.screenForItemId` (flag ON) — the same
//       seam the Phase 2/4 parity tests use:
//          audit_trail -> AllTransactionsScreen
//          sync_status -> BackupScreen
//       The itemId -> screen mapping is flag-independent (the relabel touched
//       neither routing nor capability), so both seams must agree and be
//       unchanged.
//
//   (2) NON-REGRESSION (Req 2.3 — no itemId dropped/added):
//       The flattened set of itemIds surfaced by `sidebarSectionsProvider` for
//       each in-scope business type is UNCHANGED by the relabel — pinned to a
//       golden per-type inventory snapshot. Reuses the Property-4 / phase1
//       preservation seam (ProviderContainer overrides: FakeBusinessTypeNotifier,
//       FakeAuthStateNotifier authenticated, currentUserRoleProvider -> owner;
//       FeatureResolver REAL). Because the relabel is label-only, the itemId set
//       must equal the recorded golden; the old labels must appear NOWHERE.
//
//   (3) RELABEL IN EFFECT (Req 9.2, 9.3 — truthful labels):
//       Every surfaced `audit_trail` item label == "All Transactions"; every
//       surfaced `sync_status` item label == "Backup & Sync"; and the OLD
//       labels "Audit Trail" / "Sync Status" are surfaced for NO in-scope type.
//
// SEAMS:
//   * Resolution: `getScreenForItem` (legacy, flag OFF) and
//     `AppRouter.screenForItemId` (flag ON) both synchronously CONSTRUCT screen
//     widgets — no build()/GetIt/IO. A real BuildContext captured from a
//     minimal pumped host drives both; only `runtimeType` is inspected. (Same
//     seam as the Phase 2 parity preservation test.)
//   * Visibility: `sidebarSectionsProvider` resolved per (type, owner) with
//     FeatureResolver REAL and fakes only for the session/business-type seams
//     (Property-4 conventions).
//
// TEST-ONLY: this task changes NO production code.
//
// Run: flutter test test/core/routing/phase6_sidebar_relabel_preservation_test.dart
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

// ============================================================================
// CONSTANTS — the relabeled items, their truthful (new) labels, their OLD
// labels, and the screens they must still resolve to.
// ============================================================================

const String _auditTrailId = 'audit_trail';
const String _syncStatusId = 'sync_status';

const String _auditTrailNewLabel = 'All Transactions';
const String _syncStatusNewLabel = 'Backup & Sync';

const String _auditTrailOldLabel = 'Audit Trail';
const String _syncStatusOldLabel = 'Sync Status';

/// The screens the relabeled itemIds must STILL resolve to (label-only change).
/// Mirrors the Phase 2 golden baseline (`_goldenScreenTypeByItemId`).
const String _auditTrailScreen = 'AllTransactionsScreen';
const String _syncStatusScreen = 'BackupScreen';

/// The 18 in-scope business types (design.md -> Data Model 4). `other` is the
/// default/retail fallback, exercised indirectly by every retail vertical.
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

// ============================================================================
// FAKES (same conventions as the Property-4 / phase1 preservation seam)
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

/// Builds a container that resolves the shell sidebar for [type] as it would be
/// right after a successful login as owner. FeatureResolver stays REAL.
ProviderContainer _containerFor(BusinessType type) {
  return ProviderContainer(
    overrides: [
      businessTypeProvider.overrideWith(() => _FakeBusinessTypeNotifier(type)),
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier()),
      currentUserRoleProvider.overrideWithValue(UserRole.owner),
    ],
  );
}

/// Reads the resolved sidebar sections for [type] and returns the flattened
/// (itemId, label) pairs in deterministic provider order.
List<MapEntry<String, String>> _itemsFor(BusinessType type) {
  final container = _containerFor(type);
  try {
    final sections = container.read(sidebarSectionsProvider);
    final out = <MapEntry<String, String>>[];
    for (final section in sections) {
      for (final item in section.items) {
        out.add(MapEntry(item.id, item.label));
      }
    }
    return out;
  } finally {
    container.dispose();
  }
}

/// The sorted set of surfaced itemIds for [type].
List<String> _itemIdsFor(BusinessType type) {
  final ids = _itemsFor(type).map((e) => e.key).toSet().toList()..sort();
  return ids;
}

/// Captures a real [BuildContext] from a minimally pumped host so both
/// resolvers can be driven exactly as the shell drives them.
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
// GOLDEN — flattened itemId set per in-scope business type.
//
// Captured POST-relabel (== PRE-relabel, since Task 7.2 was label-only). This
// locks the per-type sidebar itemId inventory: any future change that DROPS or
// ADDS an itemId for any in-scope type fails this test (Req 2.3 non-regression).
// ============================================================================
const Map<BusinessType, List<String>> _goldenItemIdsByType =
    <BusinessType, List<String>>{
      BusinessType.grocery: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'batch_tracking',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'scan_bill',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.pharmacy: <String>[
        'analytics_hub',
        'backup',
        'batch_tracking',
        'customers',
        'daily_snapshot',
        'device_settings',
        'error_logs',
        'executive_dashboard',
        'gstr1',
        'invoice_margin',
        'item_stock',
        'live_health',
        'low_stock',
        'new_sale',
        'outstanding',
        'party_ledger',
        'prescriptions',
        'print_settings',
        'product_performance',
        'purchase_orders',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
      ],
      BusinessType.restaurant: <String>[
        'analytics_hub',
        'backup',
        'customers',
        'daily_summary',
        'device_settings',
        'error_logs',
        'executive_dashboard',
        'gstr1',
        'invoice_margin',
        'item_stock',
        'kitchen_display',
        'low_stock',
        'menu_management',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'product_performance',
        'restaurant_tables',
        'revenue_overview',
        'sales_register',
        'stock_summary',
        'suppliers',
      ],
      BusinessType.clinic: <String>[
        'add_patient',
        'appointments',
        'clinic_dashboard',
        'daily_appointments',
        'device_settings',
        'doctor_revenue',
        'lab_reports',
        'medicine_master',
        'new_sale',
        'patient_history',
        'patients_list',
        'prescriptions',
        'revenue_overview',
        'scan_qr',
        'sync_status',
      ],
      BusinessType.petrolPump: <String>[
        'analytics_hub',
        'backup',
        'customers',
        'device_settings',
        'dispenser_management',
        'error_logs',
        'fuel_profit_report',
        'fuel_rates',
        'gstr1',
        'invoice_margin',
        'new_sale',
        'nozzle_sales_report',
        'outstanding',
        'party_ledger',
        'petrol_dashboard',
        'print_settings',
        'product_performance',
        'revenue_overview',
        'sales_register',
        'shift_management',
        'shift_report',
        'suppliers',
        'tank_management',
        'tank_stock_report',
      ],
      BusinessType.service: <String>[
        'analytics_hub',
        'backup',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'device_settings',
        'error_logs',
        'exchanges',
        'executive_dashboard',
        'gstr1',
        'invoice_margin',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'product_performance',
        'proforma_bids',
        'receipt_entry',
        'revenue_overview',
        'sales_register',
        'service_jobs',
        'suppliers',
      ],
      BusinessType.electronics: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'scan_bill',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.mobileShop: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.computerShop: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.clothing: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'scan_bill',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.hardware: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.wholesale: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'batch_tracking',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.vegetablesBroker: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.bookStore: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'scan_bill',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.jewellery: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.autoParts: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.decorationCatering: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
      BusinessType.schoolErp: <String>[
        'accounting_reports',
        'activity_logs',
        'alerts',
        'analytics_hub',
        'audit_trail',
        'b2b_b2c',
        'backup',
        'bank_accounts',
        'booking_orders',
        'buyflow_dashboard',
        'cash_bank',
        'catalogue',
        'credit_notes',
        'customers',
        'daily_activity',
        'daily_snapshot',
        'damage_logs',
        'daybook',
        'device_settings',
        'dispatch_notes',
        'doc_templates',
        'error_logs',
        'executive_dashboard',
        'expenses',
        'filing_status',
        'financial_position',
        'funds_flow',
        'gstr1',
        'hsn_reports',
        'income_statement',
        'insights',
        'invoice_margin',
        'item_stock',
        'ledger_abstract',
        'ledger_history',
        'live_health',
        'low_stock',
        'margin_analysis',
        'new_sale',
        'outstanding',
        'party_ledger',
        'print_settings',
        'procurement_insights',
        'procurement_log',
        'product_performance',
        'proforma_bids',
        'purchase_orders',
        'purchase_register',
        'receipt_entry',
        'return_inwards',
        'revenue_overview',
        'sales_register',
        'stock_entry',
        'stock_reversal',
        'stock_summary',
        'stock_valuation',
        'supplier_bills',
        'suppliers',
        'sync_status',
        'tax_liability',
        'transaction_reports',
        'turnover_analysis',
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: gorouter-navigation-migration — Phase 6 sidebar relabel '
      'PRESERVATION (Req 2.2, 2.3)', () {
    // ----------------------------------------------------------------------
    // (1) LINK PRESERVED — relabeled itemIds still resolve to the same screen
    //     via BOTH seams (legacy flag-OFF dispatch AND flag-ON resolver).
    // ----------------------------------------------------------------------
    testWidgets(
      'relabeled itemIds still resolve to the same screens (audit_trail -> '
      'AllTransactionsScreen, sync_status -> BackupScreen) via both seams',
      (tester) async {
        final context = await _pumpAndCaptureContext(tester);

        // audit_trail
        expect(
          SidebarNavigationHandler.getScreenForItem(
            _auditTrailId,
            context,
          ).runtimeType.toString(),
          _auditTrailScreen,
          reason:
              'Legacy dispatch for audit_trail must still open '
              '$_auditTrailScreen (relabel is label-only).',
        );
        expect(
          AppRouter.screenForItemId(
            _auditTrailId,
            context,
          ).runtimeType.toString(),
          _auditTrailScreen,
          reason:
              'go_router resolver for audit_trail must still open '
              '$_auditTrailScreen (relabel is label-only).',
        );

        // sync_status
        expect(
          SidebarNavigationHandler.getScreenForItem(
            _syncStatusId,
            context,
          ).runtimeType.toString(),
          _syncStatusScreen,
          reason:
              'Legacy dispatch for sync_status must still open '
              '$_syncStatusScreen (relabel is label-only).',
        );
        expect(
          AppRouter.screenForItemId(
            _syncStatusId,
            context,
          ).runtimeType.toString(),
          _syncStatusScreen,
          reason:
              'go_router resolver for sync_status must still open '
              '$_syncStatusScreen (relabel is label-only).',
        );

        // Both seams must agree (flag-independent itemId -> screen mapping).
        expect(
          AppRouter.screenForItemId(_auditTrailId, context).runtimeType,
          SidebarNavigationHandler.getScreenForItem(
            _auditTrailId,
            context,
          ).runtimeType,
        );
        expect(
          AppRouter.screenForItemId(_syncStatusId, context).runtimeType,
          SidebarNavigationHandler.getScreenForItem(
            _syncStatusId,
            context,
          ).runtimeType,
        );
      },
    );

    test('relabeled itemIds remain in the route inventory (knownItemIds)', () {
      expect(
        RoutePaths.knownItemIds,
        containsAll(<String>[_auditTrailId, _syncStatusId]),
        reason:
            'The relabel must not have removed audit_trail/sync_status from '
            'the route inventory.',
      );
    });

    // ----------------------------------------------------------------------
    // (2) NON-REGRESSION — the flattened itemId set per in-scope type is
    //     unchanged by the relabel (pinned to the golden inventory).
    // ----------------------------------------------------------------------
    test('flattened sidebar itemId set per in-scope type is unchanged by the '
        'relabel (golden inventory)', () {
      // Guard: the golden must cover every in-scope type. If this fails the
      // golden was not populated — the failure message prints the captured
      // sets to paste in.
      final missing = _inScopeTypes
          .where((t) => !_goldenItemIdsByType.containsKey(t))
          .toList();
      if (missing.isNotEmpty) {
        final buf = StringBuffer(
          'GOLDEN NOT POPULATED for: '
          '${missing.map((t) => t.name).join(', ')}.\n'
          'Captured per-type itemId sets (paste into '
          '_goldenItemIdsByType):\n',
        );
        for (final type in _inScopeTypes) {
          final ids = _itemIdsFor(type);
          buf.writeln(
            "    BusinessType.${type.name}: <String>[${ids.map((s) => "'$s'").join(', ')}],",
          );
        }
        fail(buf.toString());
      }

      for (final type in _inScopeTypes) {
        expect(
          _itemIdsFor(type),
          equals(_goldenItemIdsByType[type]),
          reason:
              'Sidebar itemId inventory changed for ${type.name} — the '
              'Phase 6 relabel must be label-only (no itemId dropped or '
              'added) (Req 2.3).',
        );
      }
    });

    test('every surfaced itemId is a member of the route inventory (no '
        'phantom ids introduced by the relabel)', () {
      for (final type in _inScopeTypes) {
        for (final id in _itemIdsFor(type)) {
          expect(
            RoutePaths.isNavItemId(id),
            isTrue,
            reason:
                'Surfaced itemId "$id" for ${type.name} is not a navigable '
                'route id (RoutePaths.isNavItemId) — the relabel must not add '
                'ids. (Legacy ids live in knownItemIds; genuinely-new routes '
                'like scan_bill resolve via isNavItemId.)',
          );
        }
      }
    });

    // ----------------------------------------------------------------------
    // (3) RELABEL IN EFFECT — new truthful labels present; old labels gone.
    // ----------------------------------------------------------------------
    test('every surfaced audit_trail item is labeled "All Transactions" and '
        'every sync_status item is labeled "Backup & Sync"', () {
      var sawAuditTrail = false;
      var sawSyncStatus = false;

      for (final type in _inScopeTypes) {
        for (final entry in _itemsFor(type)) {
          if (entry.key == _auditTrailId) {
            sawAuditTrail = true;
            expect(
              entry.value,
              _auditTrailNewLabel,
              reason:
                  'audit_trail must show the truthful label '
                  '"$_auditTrailNewLabel" for ${type.name} (Req 9.2).',
            );
          }
          if (entry.key == _syncStatusId) {
            sawSyncStatus = true;
            expect(
              entry.value,
              _syncStatusNewLabel,
              reason:
                  'sync_status must show the truthful label '
                  '"$_syncStatusNewLabel" for ${type.name} (Req 9.3).',
            );
          }
        }
      }

      expect(
        sawAuditTrail,
        isTrue,
        reason:
            'At least one in-scope type must surface audit_trail so the '
            'relabel is observable.',
      );
      expect(
        sawSyncStatus,
        isTrue,
        reason:
            'At least one in-scope type must surface sync_status so the '
            'relabel is observable.',
      );
    });

    test('the OLD labels "Audit Trail" / "Sync Status" are surfaced for NO '
        'in-scope business type', () {
      for (final type in _inScopeTypes) {
        final labels = _itemsFor(type).map((e) => e.value).toList();
        expect(
          labels,
          isNot(contains(_auditTrailOldLabel)),
          reason:
              'The old "$_auditTrailOldLabel" label must be gone for '
              '${type.name} (Req 9.2 truthful relabel).',
        );
        expect(
          labels,
          isNot(contains(_syncStatusOldLabel)),
          reason:
              'The old "$_syncStatusOldLabel" label must be gone for '
              '${type.name} (Req 9.3 truthful relabel).',
        );
      }
    });
  });
}
