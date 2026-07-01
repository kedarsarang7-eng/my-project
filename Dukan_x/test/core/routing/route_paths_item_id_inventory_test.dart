// ============================================================================
// PHASE 2 — Task 3.1: RoutePaths itemId inventory + resolver unit test
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 3.1 — Inventory all legacy itemIds and define `RoutePaths` constants.
//
// This test pins the Phase 2 DATA/CONSTANTS contract (no routes registered
// here yet — that is Task 3.3):
//   * every legacy `getScreenForItem` itemId has a NON-NULL, UNIQUE path;
//   * the full inventory is complete (90 itemIds — Property 2: no dropped ids);
//   * `pathForItemId` returns the right path for a representative sample,
//     including ALL documented duplicate pairs (Property 3: duplicates
//     preserved with DISTINCT paths, not deduped);
//   * an unknown itemId returns the documented `notFound` sentinel;
//   * paths follow the documented '/app/' + kebab-case convention.
//
// Validates: Requirements 5.1, 5.4, 5.5
// ============================================================================

import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The complete legacy itemId set, transcribed from every `case` in
  // SidebarNavigationHandler.getScreenForItem (90 unique itemIds, duplicates
  // of SHARED screens included — they are distinct itemIds).
  const legacyItemIds = <String>[
    // Dashboard & Control (5)
    'executive_dashboard', 'clinic_dashboard', 'live_health', 'alerts',
    'daily_snapshot',
    // Clinic (8)
    'daily_appointments', 'appointments', 'patients_list', 'add_patient',
    'prescriptions', 'medicine_master', 'lab_reports', 'patient_history',
    // Revenue Desk (8)
    'revenue_overview', 'new_sale', 'receipt_entry', 'return_inwards',
    'proforma_bids', 'booking_orders', 'dispatch_notes', 'sales_register',
    // BuyFlow (8)
    'buyflow_dashboard', 'purchase_orders', 'stock_entry', 'stock_reversal',
    'vendor_payouts', 'procurement_log', 'supplier_bills', 'purchase_register',
    // Inventory & Stock (6)
    'stock_summary', 'item_stock', 'batch_tracking', 'low_stock',
    'stock_valuation', 'damage_logs',
    // Parties & Ledger (6)
    'customers', 'suppliers', 'party_ledger', 'ledger_history',
    'ledger_abstract', 'outstanding',
    // Business Intelligence (6)
    'analytics_hub', 'turnover_analysis', 'product_performance',
    'daily_activity', 'procurement_insights', 'margin_analysis',
    // Financial Reports (5)
    'invoice_margin', 'income_statement', 'funds_flow', 'financial_position',
    'cash_bank',
    // Tax & Compliance (5)
    'gstr1', 'b2b_b2c', 'hsn_reports', 'tax_liability', 'filing_status',
    // Operations & Logs (4)
    'transaction_reports', 'activity_logs', 'audit_trail', 'error_logs',
    // Utilities & System (5)
    'print_settings', 'doc_templates', 'backup', 'sync_status',
    'device_settings',
    // Petrol Pump (4)
    'petrol_dashboard', 'shift_management', 'tank_management',
    'dispenser_management',
    // Restaurant (4)
    'restaurant_tables', 'kitchen_display', 'menu_management', 'daily_summary',
    // Hidden — doctor / QR (2)
    'doctor_revenue', 'scan_qr',
    // Hidden — petrol pump reports (5)
    'fuel_rates', 'fuel_profit_report', 'nozzle_sales_report', 'shift_report',
    'tank_stock_report',
    // Hidden — service business (2)
    'service_jobs', 'exchanges',
    // Phase-2 additional hidden screens (7)
    'accounting_reports', 'bank_accounts', 'credit_notes', 'daybook',
    'catalogue', 'insights', 'expenses',
  ];

  group(
    'RoutePaths inventory completeness (Req 5.1 — Property 2 totality)',
    () {
      test('exactly 90 legacy itemIds are inventoried', () {
        expect(
          legacyItemIds.toSet(),
          hasLength(90),
          reason: 'The test transcription itself must be 90 unique itemIds.',
        );
        expect(
          RoutePaths.knownItemIds.toSet(),
          hasLength(90),
          reason: 'RoutePaths must inventory exactly 90 itemIds.',
        );
      });

      test('RoutePaths covers every legacy itemId and nothing extra', () {
        expect(
          RoutePaths.knownItemIds.toSet(),
          equals(legacyItemIds.toSet()),
          reason:
              'No legacy itemId may be dropped and no phantom id may be added.',
        );
      });

      test('every legacy itemId resolves to a non-null, non-empty path', () {
        for (final id in legacyItemIds) {
          final path = RoutePaths.pathForItemId(id);
          expect(path, isNotEmpty, reason: 'itemId "$id" must have a path.');
          expect(
            path,
            isNot(RoutePaths.notFound),
            reason: 'Known itemId "$id" must not resolve to the sentinel.',
          );
          expect(RoutePaths.isKnownItemId(id), isTrue);
        }
      });

      test('all paths are unique', () {
        final paths = RoutePaths.knownPaths.toList();
        expect(
          paths.toSet(),
          hasLength(paths.length),
          reason: 'Each itemId must map to a distinct path (no collisions).',
        );
      });

      test('all paths follow the /app/ + kebab-case convention', () {
        final kebabSegment = RegExp(r'^/app/[a-z0-9]+(?:-[a-z0-9]+)*$');
        for (final id in legacyItemIds) {
          final path = RoutePaths.pathForItemId(id);
          expect(
            kebabSegment.hasMatch(path),
            isTrue,
            reason: 'Path "$path" for "$id" must be /app/<kebab-case>.',
          );
        }
      });
    },
  );

  group('Representative path resolution (Req 5.1)', () {
    test('non-duplicate itemIds resolve to the expected constant', () {
      expect(RoutePaths.pathForItemId('new_sale'), RoutePaths.newSale);
      expect(RoutePaths.pathForItemId('new_sale'), '/app/new-sale');
      expect(
        RoutePaths.pathForItemId('executive_dashboard'),
        RoutePaths.executiveDashboard,
      );
      expect(RoutePaths.pathForItemId('customers'), RoutePaths.customers);
      expect(RoutePaths.pathForItemId('scan_qr'), '/app/scan-qr');
      expect(RoutePaths.pathForItemId('hsn_reports'), RoutePaths.hsnReports);
    });
  });

  group('Documented duplicate pairs preserved with DISTINCT paths '
      '(Req 5.4, 5.5 — Property 3)', () {
    test(
      'purchase_register & procurement_log: distinct paths, same screen',
      () {
        expect(
          RoutePaths.pathForItemId('purchase_register'),
          RoutePaths.purchaseRegister,
        );
        expect(
          RoutePaths.pathForItemId('procurement_log'),
          RoutePaths.procurementLog,
        );
        expect(
          RoutePaths.purchaseRegister,
          isNot(equals(RoutePaths.procurementLog)),
        );
      },
    );

    test('invoice_margin & income_statement -> PnlScreen: distinct paths', () {
      expect(
        RoutePaths.pathForItemId('invoice_margin'),
        RoutePaths.invoiceMargin,
      );
      expect(
        RoutePaths.pathForItemId('income_statement'),
        RoutePaths.incomeStatement,
      );
      expect(
        RoutePaths.invoiceMargin,
        isNot(equals(RoutePaths.incomeStatement)),
      );
    });

    test('funds_flow & cash_bank -> CashflowScreen: distinct paths', () {
      expect(RoutePaths.pathForItemId('funds_flow'), RoutePaths.fundsFlow);
      expect(RoutePaths.pathForItemId('cash_bank'), RoutePaths.cashBank);
      expect(RoutePaths.fundsFlow, isNot(equals(RoutePaths.cashBank)));
    });

    test('gstr1 & b2b_b2c -> GstReportsScreen(0): distinct paths', () {
      expect(RoutePaths.pathForItemId('gstr1'), RoutePaths.gstr1);
      expect(RoutePaths.pathForItemId('b2b_b2c'), RoutePaths.b2bB2c);
      expect(RoutePaths.gstr1, isNot(equals(RoutePaths.b2bB2c)));
    });

    test(
      'print_settings & doc_templates -> PrintMenuScreen: distinct paths',
      () {
        expect(
          RoutePaths.pathForItemId('print_settings'),
          RoutePaths.printSettings,
        );
        expect(
          RoutePaths.pathForItemId('doc_templates'),
          RoutePaths.docTemplates,
        );
        expect(
          RoutePaths.printSettings,
          isNot(equals(RoutePaths.docTemplates)),
        );
      },
    );

    test('AllTransactionsScreen cluster: all distinct paths', () {
      const cluster = <String>[
        'ledger_history',
        'turnover_analysis',
        'daily_activity',
        'activity_logs',
        'audit_trail',
        'transaction_reports',
      ];
      final clusterPaths = cluster.map(RoutePaths.pathForItemId).toList();
      expect(
        clusterPaths.toSet(),
        hasLength(cluster.length),
        reason: 'Every cluster itemId keeps a distinct path (no de-dup).',
      );
      for (final p in clusterPaths) {
        expect(p, isNot(RoutePaths.notFound));
      }
    });
  });

  group('Unknown itemId handling (documented sentinel)', () {
    test('unknown itemId returns the notFound sentinel', () {
      expect(
        RoutePaths.pathForItemId('totally_unknown_item'),
        RoutePaths.notFound,
      );
      expect(RoutePaths.pathForItemId(''), RoutePaths.notFound);
      expect(
        RoutePaths.pathForItemId('NEW_SALE'),
        RoutePaths.notFound,
        reason: 'Resolver is case-sensitive over the legacy snake_case set.',
      );
      expect(RoutePaths.isKnownItemId('totally_unknown_item'), isFalse);
    });

    test('notFound sentinel has its documented value', () {
      expect(RoutePaths.notFound, '/app/not-found');
    });
  });

  group('Foundation constants remain intact (Phase 1 not regressed)', () {
    test('splash/login/auth-gate/shell unchanged', () {
      expect(RoutePaths.splash, '/splash');
      expect(RoutePaths.login, '/login');
      expect(RoutePaths.authGate, '/auth-gate');
      expect(RoutePaths.shell, '/app');
    });
  });
}
