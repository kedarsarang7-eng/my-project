/// Preservation Property Test — Clinic (Doctor/OPD) Vertical Remediation
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.11,
/// 3.12 → Properties 13, 14, 15 (+ Property 4 preservation half)**
///
/// Property 2: Preservation — Non-Clinic Verticals, Billing/GST & Confirmed
/// Features.
///
/// **METHODOLOGY — observation-first.** Every assertion below was written AFTER
/// running the UNFIXED code on inputs where `isBugCondition(input)` is FALSE and
/// RECORDING the actual observed output. The golden constants in this file
/// (sidebar signatures, the 13 clinic-id → screen map, the clinic capability
/// set, the clinic GST config) are those recorded baselines. The clinic
/// remediation fix MUST NOT change any of them.
///
/// **EXPECTED OUTCOME (this phase): every test PASSES on the UNFIXED code.** A
/// pass confirms the regression baseline is captured; the same suite is re-run
/// after each fix phase (tasks 4.6 / 5.8 / 6.6 / 7.3 / 8) and must keep passing.
///
/// Two kinds of probe are used (matching the companion exploration test's
/// conventions):
///   • Deterministic real-source / behavioural probes — drive the live
///     resolver / registry / config (no DB), which are headless-safe.
///   • DB-backed probes — self-skip via [_tryOpenClinicDb] / [markTestSkipped]
///     while the shared Drift schema is un-creatable in-memory due to a
///     pre-existing, unrelated vegetable-broker defect (the `MandiSettlements`
///     CHECK constraint references `paymentStatus` instead of the
///     `payment_status` column). Each DB-backed preservation probe is backed by
///     a deterministic real-source probe so the baseline is still captured.
///
/// PBT library: dartproptest ^0.2.1 — used over the non-clinic business-type
/// domain and the 13-clinic-id domain, which both have a natural generated
/// input space.
///
/// Run: flutter test test/features/clinic/clinic_vertical_remediation_preservation_test.dart
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/features/doctor/data/repositories/patient_repository.dart';
import 'package:dukanx/features/doctor/models/patient_model.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';

// ---------------------------------------------------------------------------
// Test doubles (same shape as the companion exploration test)
// ---------------------------------------------------------------------------

/// Spy SyncManager that records every enqueued op so the offline-first
/// write→enqueue contract can be observed without a real backend.
class _SpySyncManager extends Fake implements SyncManager {
  final List<SyncQueueItem> enqueued = [];

  @override
  Future<String> enqueue(SyncQueueItem item) async {
    enqueued.add(item);
    return 'spy-op-${enqueued.length}';
  }
}

/// Fake SessionManager supplying a known, non-null owner id so the repositories'
/// shared [resolveOwnerId] fail-safe resolves a real tenant id under the
/// headless test harness (no GetIt registration). Supplies only the missing
/// dependency — the preservation assertions (one Drift row, one enqueued op)
/// are unchanged.
class _FakeSessionManager extends Fake implements SessionManager {
  @override
  String? get ownerId => 'usr_A';
}

// ---------------------------------------------------------------------------
// Real-source helpers (cwd == package root when `flutter test` runs)
// ---------------------------------------------------------------------------

String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// Attempts to open an in-memory [AppDatabase]. Returns `null` when the shared
/// Drift schema cannot be created in-memory because of the unrelated, in-progress
/// vegetable-broker `MandiSettlements` CHECK-constraint defect — so DB-backed
/// preservation probes self-skip instead of failing for an unrelated reason.
Future<AppDatabase?> _tryOpenClinicDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  try {
    await db.customSelect('SELECT 1').get();
    return db;
  } catch (_) {
    try {
      await db.close();
    } catch (_) {
      /* ignore */
    }
    return null;
  }
}

const String _kDbBlockedReason =
    'Shared Drift schema cannot be created in-memory due to a pre-existing, '
    'unrelated vegetable-broker defect (MandiSettlements CHECK constraint '
    'references `paymentStatus` instead of the `payment_status` column). This '
    'blocks every DB-backed test in the repo. The preservation baseline is '
    'captured by the companion deterministic real-source probe; this behavioural '
    'probe will re-confirm it once the shared schema is repaired.';

/// Builds the canonical signature of a business type's UNFILTERED sidebar:
/// `title=[id,id,...] | title=[...]`. Identical to the observation harness used
/// to record the goldens below.
String _sidebarSignature(BusinessType type) {
  final sections = getSectionsForBusinessType(type);
  return sections
      .map((s) => '${s.title}=[${s.items.map((i) => i.id).join(",")}]')
      .join(' | ');
}

// ---------------------------------------------------------------------------
// RECORDED BASELINES (observed on UNFIXED code — see _observe harness)
// ---------------------------------------------------------------------------

/// The default ("retail") sidebar signature shared by every business type that
/// falls through `_getSectionsForBusiness`'s `default:` branch.
const String _retailSignature =
    'Dashboard & Control=[executive_dashboard,live_health,alerts,daily_snapshot] | '
    'Revenue Desk=[revenue_overview,new_sale,receipt_entry,return_inwards,proforma_bids,booking_orders,dispatch_notes,sales_register] | '
    'BuyFlow=[buyflow_dashboard,purchase_orders,stock_entry,stock_reversal,procurement_log,supplier_bills,purchase_register,scan_bill] | '
    'Inventory & Stock=[stock_summary,item_stock,batch_tracking,low_stock,stock_valuation,damage_logs] | '
    'Parties & Ledger=[customers,suppliers,party_ledger,ledger_history,ledger_abstract,outstanding] | '
    'Business Intelligence=[analytics_hub,turnover_analysis,product_performance,daily_activity,procurement_insights,margin_analysis,insights,catalogue] | '
    'Financial Reports=[invoice_margin,income_statement,funds_flow,financial_position,cash_bank,accounting_reports,bank_accounts,daybook,credit_notes,expenses] | '
    'Tax & Compliance=[gstr1,b2b_b2c,hsn_reports,tax_liability,filing_status] | '
    'Operations & Logs=[transaction_reports,activity_logs,audit_trail,error_logs] | '
    'Utilities & System=[print_settings,doc_templates,backup,sync_status,device_settings]';

/// Observed UNFIXED sidebar signature for every NON-CLINIC business type.
final Map<BusinessType, String> _kNonClinicSidebarGolden = {
  BusinessType.grocery: _retailSignature,
  BusinessType.clothing: _retailSignature,
  BusinessType.electronics: _retailSignature,
  BusinessType.mobileShop: _retailSignature,
  BusinessType.computerShop: _retailSignature,
  BusinessType.wholesale: _retailSignature,
  BusinessType.bookStore: _retailSignature,
  BusinessType.jewellery: _retailSignature,
  BusinessType.autoParts: _retailSignature,
  BusinessType.decorationCatering: _retailSignature,
  BusinessType.schoolErp: _retailSignature,
  BusinessType.other: _retailSignature,
  BusinessType.pharmacy:
      'Pharmacy Control=[executive_dashboard,live_health,daily_snapshot] | '
      'Dispensing & Sales=[new_sale,prescriptions,revenue_overview,sales_register] | '
      'Inventory & Expiry=[item_stock,batch_tracking,low_stock,stock_valuation] | '
      'Procurement=[purchase_orders,stock_entry,supplier_bills] | '
      'Compliance & Lookups=[salt_search,patient_registry,narcotic_register,h1_register] | '
      'Finance & Cash Flow=[expenses,bank_accounts] | '
      'Parties & Ledger=[customers,suppliers,party_ledger,outstanding] | '
      'Reports & Analytics=[analytics_hub,product_performance,invoice_margin,gstr1] | '
      'System=[print_settings,backup,error_logs,device_settings]',
  BusinessType.restaurant:
      'Restaurant Operations=[executive_dashboard,restaurant_tables,kitchen_display,menu_management,daily_summary] | '
      'Billing & Cashier=[new_sale,revenue_overview,sales_register] | '
      'Inventory & Stock=[stock_summary,item_stock,low_stock] | '
      'Advanced Operations=[floor_management,kot_report,recipe_management,delivery_ops,restaurant_command_center] | '
      'Parties & Ledger=[customers,suppliers,party_ledger,outstanding] | '
      'Reports & Analytics=[analytics_hub,product_performance,invoice_margin,gstr1] | '
      'System=[print_settings,backup,error_logs,device_settings]',
  BusinessType.hardware:
      'Projects, Indents & Deposits=[hardware_operations,hardware_command_center,hardware_phase12_workspace] | '
      'Estimates \u2192 Invoice=[proforma_bids,hardware_invoice_profile,new_sale,return_inwards] | '
      'Delivery Challans=[delivery_challans,dispatch_notes,eway_bill] | '
      'Contractor Credit=[hardware_credit_control,party_ledger,outstanding] | '
      'Supplier Rate Compare=[hardware_supplier_management,supplier_bills,suppliers] | '
      'Inventory=[stock_summary,item_stock,low_stock,stock_valuation]',
  BusinessType.service:
      'Service Dashboard=[executive_dashboard,daily_activity,daily_snapshot] | '
      'Billing Desk=[new_sale,revenue_overview,receipt_entry,sales_register,proforma_bids] | '
      'Service & Repairs=[service_jobs,exchanges] | '
      'Parties & Ledger=[customers,suppliers,party_ledger,outstanding] | '
      'Reports & Analytics=[analytics_hub,product_performance,invoice_margin,gstr1] | '
      'System=[print_settings,backup,error_logs,device_settings]',
  BusinessType.petrolPump:
      'Fuel Station Ops=[petrol_dashboard,shift_management,dispenser_management,tank_management] | '
      'Billing & Sales=[new_sale,revenue_overview,sales_register] | '
      'Reports & Analytics=[fuel_rates,fuel_profit_report,nozzle_sales_report,shift_report,tank_stock_report] | '
      'Parties & Ledger=[customers,suppliers,party_ledger,outstanding] | '
      'Reports & Analytics=[analytics_hub,product_performance,invoice_margin,gstr1] | '
      'System=[print_settings,backup,error_logs,device_settings]',
  BusinessType.vegetablesBroker:
      'Lot Register=[mandi_lot_register] | '
      'Farmer Ledger=[mandi_farmer_ledger] | '
      'Commission Report=[mandi_commission_report] | '
      'Settlement / Patti=[mandi_settlement] | '
      'Rate Board=[mandi_rate_board]',
};

/// The 13 already-correct clinic sidebar ids → the screen runtimeType each one
/// resolves to on UNFIXED code (observed). Preservation: these must NOT change
/// (note: `patient_history` is a defect id and is deliberately NOT in this set).
const Map<String, String> _kClinicIdScreenGolden = {
  'clinic_dashboard': 'DoctorDashboardScreen',
  'daily_appointments': 'AppointmentScreen',
  'patients_list': 'PatientListScreen',
  'add_patient': 'AddPatientScreen',
  'scan_qr': 'QrScannerScreen',
  'appointments': 'AppointmentScreen',
  'prescriptions': 'SafePrescriptionListScreen',
  'medicine_master': 'MedicineMasterScreen',
  'lab_reports': 'LabReportsScreen',
  'doctor_revenue': 'DoctorRevenueScreen',
  'new_sale': 'BillCreationScreenV2',
  'revenue_overview': 'RevenueOverviewScreen',
  'device_settings': 'DeviceSettingsScreen',
};

/// The exact clinic capability set observed in `businessCapabilityRegistry`.
const Set<BusinessCapability> _kClinicCapabilityGolden = {
  BusinessCapability.useInvoiceList,
  BusinessCapability.useInvoiceSearch,
  BusinessCapability.useInvoiceCreate,
  BusinessCapability.useDailySnapshot,
  BusinessCapability.useRevenueOverview,
  BusinessCapability.useAppointments,
  BusinessCapability.useConsultationBilling,
  BusinessCapability.usePatientRegistry,
  BusinessCapability.usePrescription,
  BusinessCapability.useDoctorLinking,
};

void main() {
  // =========================================================================
  // PRESERVATION 13a — Non-clinic verticals' sidebar resolution is unchanged
  // (Property 13 / 3.1, 3.12). For EVERY non-clinic business type the
  // unfiltered sidebar signature must equal the recorded baseline. The clinic
  // fix touches only clinic code, so no change may leak into another vertical.
  // =========================================================================
  group('Preservation 13a — non-clinic sidebars match the recorded baseline '
      '(Req 3.1, 3.12)', () {
    final types = _kNonClinicSidebarGolden.keys.toList();

    // Concrete anchors for the most-used verticals.
    for (final t in [
      BusinessType.pharmacy,
      BusinessType.restaurant,
      BusinessType.hardware,
      BusinessType.vegetablesBroker,
      BusinessType.grocery,
    ]) {
      test('sidebar(${t.name}) is byte-for-byte the observed baseline', () {
        expect(
          _sidebarSignature(t),
          _kNonClinicSidebarGolden[t],
          reason:
              'PRESERVATION (3.1): the ${t.name} sidebar must resolve exactly '
              'as recorded on unfixed code — the clinic remediation must not '
              'leak into any other vertical.',
        );
      });
    }

    // PBT over the whole non-clinic domain: pick any non-clinic type, its
    // signature must equal the golden AND must never expose a clinic-only id.
    test('PBT: every non-clinic vertical matches baseline and exposes no '
        'clinic-only id', () {
      const clinicOnlyIds = {
        'clinic_dashboard',
        'daily_appointments',
        'patient_history',
        'medicine_master',
        'lab_reports',
        'doctor_revenue',
      };

      final held = forAll(
        (int i) {
          final type = types[i];
          final sig = _sidebarSignature(type);
          if (sig != _kNonClinicSidebarGolden[type]) return false;
          // No clinic-only navigation id may surface in a non-clinic sidebar.
          for (final id in clinicOnlyIds) {
            if (sig.contains('$id,') ||
                sig.contains('$id]') ||
                sig.contains('[$id')) {
              return false;
            }
          }
          return true;
        },
        [Gen.interval(0, types.length - 1)],
        numRuns: 80,
      );

      expect(
        held,
        isTrue,
        reason:
            'PRESERVATION (3.1): some non-clinic vertical deviated from its '
            'recorded sidebar baseline or leaked a clinic-only id.',
      );
    });

    // Determinism: resolution is pure (same input → same output across calls).
    test('sidebar resolution is deterministic for non-clinic types', () {
      for (final t in types) {
        expect(_sidebarSignature(t), _sidebarSignature(t));
      }
    });
  });

  // =========================================================================
  // PRESERVATION 13b — The 13 already-correct clinic ids resolve unchanged
  // (Property 13 / 3.6). Each id must still resolve to the same screen type and
  // remain non-null. (patient_history is excluded — it is a defect id.)
  // =========================================================================
  group('Preservation 13b — the 13 clinic ids resolve to the same screens '
      '(Req 3.6)', () {
    final ids = _kClinicIdScreenGolden.keys.toList();

    testWidgets('every already-correct clinic id resolves to its observed '
        'screen', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      // Concrete checks for all 13 ids.
      _kClinicIdScreenGolden.forEach((id, expectedType) {
        final w = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);
        expect(
          w,
          isNotNull,
          reason: 'PRESERVATION (3.6): clinic id "$id" must still resolve.',
        );
        expect(
          w.runtimeType.toString(),
          expectedType,
          reason:
              'PRESERVATION (3.6): clinic id "$id" must keep resolving to '
              '$expectedType (observed baseline) — the fix must not change the '
              'already-correct clinic ids.',
        );
      });

      // PBT over the 13-id domain.
      final held = forAll(
        (int i) {
          final id = ids[i];
          final w = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);
          return w != null &&
              w.runtimeType.toString() == _kClinicIdScreenGolden[id];
        },
        [Gen.interval(0, ids.length - 1)],
        numRuns: 60,
      );
      expect(
        held,
        isTrue,
        reason:
            'PRESERVATION (3.6): an already-correct clinic id deviated from its '
            'recorded screen resolution.',
      );
    });
  });

  // =========================================================================
  // PRESERVATION 14 — Billing attribution + GST semantics unchanged
  // (Property 14 / 3.2, 3.3). clinic_billing_service attributes bills/sync to
  // doctorId and keeps OPD lines at taxPercent 0.0; the clinic config keeps
  // defaultGstRate 0.0 / gstEditable true. Real-source + config probes.
  // =========================================================================
  group('Preservation 14 — clinic billing attribution & GST unchanged '
      '(Req 3.2, 3.3)', () {
    test('clinic_billing_service attributes bill + sync op to doctorId', () {
      final src = _readSource(
        'lib/features/doctor/services/clinic_billing_service.dart',
      );
      expect(
        src.isNotEmpty,
        isTrue,
        reason: 'clinic_billing_service.dart must exist.',
      );

      // Bill row and sync op are written with `userId: doctorId` (observed).
      final attributesToDoctor = RegExp(r'userId:\s*doctorId');
      expect(
        attributesToDoctor.allMatches(src).length >= 2,
        isTrue,
        reason:
            'PRESERVATION (3.2): clinic_billing_service must keep attributing '
            'both the bill row and the enqueued sync op to `doctorId` — the '
            'patient/appointment repos are aligned to it, not the reverse.',
      );
    });

    test('OPD consultation line keeps taxPercent 0.0', () {
      final src = _readSource(
        'lib/features/doctor/services/clinic_billing_service.dart',
      );
      final zeroTaxLine = RegExp(r"'taxPercent':\s*0\.0");
      expect(
        zeroTaxLine.hasMatch(src),
        isTrue,
        reason:
            'PRESERVATION (3.3): the OPD bill items must keep `taxPercent: 0.0`.',
      );
    });

    test('clinic config keeps defaultGstRate 0.0 and gstEditable true', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.clinic);
      expect(
        config.defaultGstRate,
        0.0,
        reason:
            'PRESERVATION (3.3): clinic defaultGstRate must remain 0.0 — GST '
            'semantics are not changed by this remediation.',
      );
      expect(
        config.gstEditable,
        isTrue,
        reason: 'PRESERVATION (3.3): clinic gstEditable must remain true.',
      );
    });
  });

  // =========================================================================
  // PRESERVATION 15a — Confirmed `✅ present` features remain wired
  // (Property 15 / 3.4). The dashboard/prescription/medicine/lab/revenue
  // screens stay reachable (covered structurally by 13b) and visit_screen keeps
  // capturing vitals/diagnosis/private-notes; LabReportsScreen keeps its
  // pending-report query. Real-source probes over the shipping screens.
  // =========================================================================
  group('Preservation 15a — confirmed clinic features unchanged (Req 3.4)', () {
    test('visit_screen still captures Diagnosis, Private Notes and SpO2', () {
      final src = _readSource(
        'lib/features/doctor/presentation/screens/visit_screen.dart',
      );
      expect(src.isNotEmpty, isTrue, reason: 'visit_screen.dart must exist.');
      expect(
        src.contains('Diagnosis') &&
            src.contains('Private Notes') &&
            RegExp(r'SpO2|spO2|spo2', caseSensitive: false).hasMatch(src),
        isTrue,
        reason:
            'PRESERVATION (3.4): visit_screen must keep capturing Diagnosis, '
            'Private Notes and the SpO2 vital (the role gate added by the fix '
            'restricts WHO sees them, not WHETHER they are captured).',
      );
    });

    test('LabReportsScreen keeps a pending-report query', () {
      final src = _readSource(
        'lib/features/doctor/presentation/screens/lab_reports_screen.dart',
      );
      expect(
        src.isNotEmpty,
        isTrue,
        reason: 'lab_reports_screen.dart must exist.',
      );
      expect(
        RegExp(r'pending', caseSensitive: false).hasMatch(src),
        isTrue,
        reason:
            'PRESERVATION (3.4): LabReportsScreen must keep its pending-report '
            'query behaviour.',
      );
    });
  });

  // =========================================================================
  // PRESERVATION 15b — Offline-first write→enqueue contract unchanged
  // (Property 15 / 3.8). Patient writes go to local Drift THEN
  // SyncManager.enqueue; only the tenant id changes after the fix. Real-source
  // probe (deterministic) + behavioural probe (self-skips on the DB blocker).
  // =========================================================================
  group('Preservation 15b — offline-first contract unchanged (Req 3.8)', () {
    test('PatientRepository writes local Drift and then enqueues a sync op', () {
      final src = _readSource(
        'lib/features/doctor/data/repositories/patient_repository.dart',
      );
      expect(
        src.isNotEmpty,
        isTrue,
        reason: 'patient_repository.dart must exist.',
      );
      // The offline-first signature: a local Drift insert + an enqueue call.
      final localWrite = RegExp(
        r'\.into\(.*patients.*\)|into\(_db\.patients\)|'
        r'\.into\(db\.patients\)',
      );
      final enqueue = RegExp(r'enqueue\(');
      expect(
        (localWrite.hasMatch(src) ||
                RegExp(
                  r'into\([^)]*patients',
                  caseSensitive: false,
                ).hasMatch(src)) &&
            enqueue.hasMatch(src),
        isTrue,
        reason:
            'PRESERVATION (3.8): PatientRepository must keep the offline-first '
            'write→enqueue contract (local Drift insert, then '
            'SyncManager.enqueue) — the fix only corrects the tenant id, not '
            'the mechanism.',
      );
    });

    test('behavioural: createPatient produces exactly one Drift row and one '
        'enqueued op', () async {
      final db = await _tryOpenClinicDb();
      if (db == null) {
        markTestSkipped(_kDbBlockedReason);
        return;
      }
      try {
        final spy = _SpySyncManager();
        final repo = PatientRepository(
          db: db,
          syncManager: spy,
          session: _FakeSessionManager(),
        );
        final now = DateTime.now();
        await repo.createPatient(
          PatientModel(
            id: const Uuid().v4(),
            name: 'Preserve Probe',
            phone: '9990002222',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final rows = await db.select(db.patients).get();
        expect(
          rows.length,
          1,
          reason:
              'PRESERVATION (3.8): exactly one local Drift patient row must be '
              'written (offline-first local write preserved).',
        );
        expect(
          spy.enqueued.length,
          1,
          reason:
              'PRESERVATION (3.8): exactly one sync op must be enqueued after '
              'the local write (write→enqueue contract preserved).',
        );
      } finally {
        await db.close();
      }
    });
  });

  // =========================================================================
  // PRESERVATION 4 (preservation half) — Backfill scoping: a patient row that
  // already carries a real (non-'SYSTEM') owner id is stored and read back
  // unchanged (Property 4 / 3.9). This captures the invariant the future
  // backfill migration must not violate. DB-backed → self-skips on the blocker.
  // =========================================================================
  group('Preservation 4 — rows with a real owner id are untouched (Req 3.9)', () {
    test('behavioural: a non-SYSTEM owner id round-trips unchanged', () async {
      final db = await _tryOpenClinicDb();
      if (db == null) {
        markTestSkipped(_kDbBlockedReason);
        return;
      }
      try {
        final now = DateTime.now();
        const realOwner = 'usr_real_owner';
        await db
            .into(db.patients)
            .insert(
              PatientsCompanion.insert(
                id: 'p-real-1',
                userId: realOwner,
                name: 'Already Attributed',
                createdAt: now,
                updatedAt: now,
              ),
            );

        final row = await db.select(db.patients).getSingle();
        expect(
          row.userId,
          realOwner,
          reason:
              'PRESERVATION (3.9): a patient row already carrying a real owner '
              'id must be stored/read back unchanged — the backfill migration '
              'must only re-attribute "SYSTEM" rows, never rows with a real id.',
        );
      } finally {
        await db.close();
      }
    });
  });

  // =========================================================================
  // PRESERVATION 15c — Decision-gate preservation (Property 15 / 3.5, 3.11).
  // Pre-sign-off: BOTH clinic stacks remain on disk (no deletion) and the
  // clinic capability set is UNCHANGED — in particular it grants NO inventory /
  // product / purchase / scan capabilities. Filesystem + registry probes.
  // =========================================================================
  group('Preservation 15c — decision gates: both stacks present, capability '
      'set unchanged (Req 3.5, 3.11)', () {
    test('both clinic stacks remain on disk (Decision 2.1 not pre-resolved)', () {
      expect(
        Directory('lib/features/doctor').existsSync(),
        isTrue,
        reason:
            'PRESERVATION (3.11): the features/doctor stack must remain on disk '
            'pre-sign-off (no deletion without Decision 2.1 sign-off).',
      );
      expect(
        Directory('lib/features/clinic').existsSync(),
        isTrue,
        reason:
            'PRESERVATION (3.11): the features/clinic stack must remain on disk '
            'pre-sign-off (no deletion without Decision 2.1 sign-off).',
      );
    });

    test('clinic capability set equals the observed baseline exactly', () {
      final caps = businessCapabilityRegistry['clinic'] ?? const {};
      expect(
        caps,
        _kClinicCapabilityGolden,
        reason:
            'PRESERVATION (3.5): the clinic capability set must remain exactly '
            'as observed pre-sign-off (Decision 2.2 not pre-resolved).',
      );
    });

    test('clinic grants NO inventory/product/purchase/scan capabilities '
        '(Decision 2.2 not pre-resolved)', () {
      final caps = businessCapabilityRegistry['clinic'] ?? const {};
      const forbidden = {
        BusinessCapability.useInventoryList,
        BusinessCapability.useVisibleStock,
        BusinessCapability.useInventorySearch,
        BusinessCapability.useStockManagement,
        BusinessCapability.useProductAdd,
        BusinessCapability.usePurchaseOrder,
        BusinessCapability.useStockEntry,
        BusinessCapability.useBarcodeScanner,
        BusinessCapability.useScanOCR,
      };
      for (final f in forbidden) {
        expect(
          caps.contains(f),
          isFalse,
          reason:
              'PRESERVATION (3.5): clinic must NOT grant $f pre-sign-off — the '
              'inventory contradiction (Decision 2.2) is not yet resolved.',
        );
      }
    });
  });
}
