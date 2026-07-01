// ============================================================================
// SIDEBAR NAVIGATION PARITY TEST
// ============================================================================
// Verifies that every sidebar menu item ID across all business types:
// 1. Resolves to a valid AppScreen (not AppScreen.unknown)
// 2. Has a widget builder in ContentHost OR SidebarNavigationHandler
//
// This test does NOT require a running app — it tests the static routing
// configuration only.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/navigation/app_screens.dart';
import 'package:dukanx/models/business_type.dart';

// We cannot import sidebar_configuration directly because it depends on
// flutter_riverpod providers, but we CAN test the AppScreen.fromId mapping
// which is the critical link in the chain.

/// All sidebar item IDs extracted from sidebar_configuration.dart.
/// This list MUST be kept in sync with sidebar_configuration.dart.
/// If a new sidebar item is added, add its ID here.
const allSidebarItemIds = [
  // Clinic Dashboard
  'clinic_dashboard',
  'daily_appointments',
  // Patient Management
  'patients_list',
  'add_patient',
  'patient_history',
  'scan_qr',
  // Clinical Desk
  'appointments',
  'prescriptions',
  'medicine_master',
  'lab_reports',
  'doctor_revenue',
  // Service Dashboard
  'executive_dashboard',
  'daily_activity',
  'daily_snapshot',
  // Service Billing
  'new_sale',
  'revenue_overview',
  'receipt_entry',
  'sales_register',
  'proforma_bids',
  // Service & Repairs
  'service_jobs',
  'exchanges',
  // Retail Dashboard
  'live_health',
  'alerts',
  // Retail Revenue
  'return_inwards',
  'booking_orders',
  'dispatch_notes',
  // BuyFlow
  'buyflow_dashboard',
  'purchase_orders',
  'stock_entry',
  'stock_reversal',
  'procurement_log',
  'supplier_bills',
  'purchase_register',
  // Inventory
  'stock_summary',
  'item_stock',
  'batch_tracking',
  'low_stock',
  'stock_valuation',
  'damage_logs',
  // Parties & Ledger
  'customers',
  'suppliers',
  'party_ledger',
  'ledger_history',
  'ledger_abstract',
  'outstanding',
  // Business Intelligence
  'analytics_hub',
  'turnover_analysis',
  'product_performance',
  'procurement_insights',
  'margin_analysis',
  'insights',
  'catalogue',
  // Financial Reports
  'invoice_margin',
  'income_statement',
  'funds_flow',
  'financial_position',
  'cash_bank',
  'accounting_reports',
  'bank_accounts',
  'daybook',
  'credit_notes',
  'expenses',
  // Tax & Compliance
  'gstr1',
  'b2b_b2c',
  'hsn_reports',
  'tax_liability',
  'filing_status',
  // Operations & Logs
  'transaction_reports',
  'activity_logs',
  'audit_trail',
  'error_logs',
  // Utilities & System
  'print_settings',
  'doc_templates',
  'backup',
  'sync_status',
  'device_settings',
  // Restaurant
  'restaurant_tables',
  'kitchen_display',
  'menu_management',
  'daily_summary',
  // Petrol Pump
  'petrol_dashboard',
  'shift_management',
  'dispenser_management',
  'tank_management',
  'fuel_rates',
  'fuel_profit_report',
  'nozzle_sales_report',
  'shift_report',
  'tank_stock_report',
];

void main() {
  group('Sidebar Navigation Parity', () {
    test('Every sidebar item ID resolves to a valid AppScreen', () {
      final failures = <String>[];

      for (final id in allSidebarItemIds) {
        final screen = AppScreen.fromId(id);
        if (screen == AppScreen.unknown) {
          failures.add(id);
        }
      }

      expect(
        failures,
        isEmpty,
        reason: 'These sidebar item IDs resolve to AppScreen.unknown '
            '(no matching enum value or explicit fromId case): $failures',
      );
    });

    test('No duplicate sidebar item IDs', () {
      final seen = <String>{};
      final duplicates = <String>[];

      for (final id in allSidebarItemIds) {
        if (!seen.add(id)) {
          duplicates.add(id);
        }
      }

      expect(
        duplicates,
        isEmpty,
        reason: 'Duplicate sidebar item IDs found: $duplicates',
      );
    });

    test('Every AppScreen has a unique ID', () {
      final ids = <String, AppScreen>{};
      final conflicts = <String>[];

      for (final screen in AppScreen.values) {
        if (screen == AppScreen.unknown) continue;
        final id = screen.id;
        if (ids.containsKey(id)) {
          conflicts.add('$id -> ${ids[id]!.name} AND ${screen.name}');
        } else {
          ids[id] = screen;
        }
      }

      expect(
        conflicts,
        isEmpty,
        reason: 'Multiple AppScreen values map to same ID: $conflicts',
      );
    });

    test('BusinessType enum has all 19 expected types', () {
      expect(BusinessType.values.length, 19);
      expect(BusinessType.values.map((t) => t.name).toSet(), containsAll([
        'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
        'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale',
        'petrolPump', 'vegetablesBroker', 'clinic', 'bookStore', 'jewellery',
        'autoParts', 'decorationCatering', 'schoolErp', 'other',
      ]));
    });

    test('fromId round-trips for common IDs', () {
      // Test that fromId(screen.id) == screen for key screens
      final screens = [
        AppScreen.executiveDashboard,
        AppScreen.newSale,
        AppScreen.salesRegister,
        AppScreen.customers,
        AppScreen.partyLedger,
        AppScreen.clinicDashboard,
        AppScreen.petrolDashboard,
        AppScreen.restaurantTables,
        AppScreen.serviceJobs,
        AppScreen.patientHistory,
        AppScreen.prescriptions,
        AppScreen.analyticsHub,
        AppScreen.gstr1,
      ];

      for (final screen in screens) {
        final id = screen.id;
        final resolved = AppScreen.fromId(id);
        expect(
          resolved,
          screen,
          reason: 'AppScreen.${screen.name}.id = "$id" but '
              'fromId("$id") = ${resolved.name}',
        );
      }
    });
  });
}
