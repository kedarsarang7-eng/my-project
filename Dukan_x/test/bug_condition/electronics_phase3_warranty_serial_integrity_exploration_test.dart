/// Phase 3 Bug-Condition Exploration Test — Warranty/Serial Data Integrity at POS
///
/// **Validates: Requirements 2.11, 2.12, 2.13**
///
/// **Property 5: Bug Condition** — Warranty/serial data integrity at point of sale.
///
/// This test encodes the EXPECTED behavior (what SHOULD happen after the fix).
/// It is run on UNFIXED code and is EXPECTED TO FAIL — failure confirms the bug
/// exists.
///
/// Bug condition (from design):
///   `BillLineSave` where `businessType == electronics AND isDeviceLine AND
///    NOT (warrantyExpiryComputed(input) AND serialInventoryLinked(input))`
///
/// Expected behavior asserted:
///   - warranty expiry persisted as single source of truth
///     (`warrantyEndDate == saleDate + warrantyMonths`)
///   - RID-patterned tenant-scoped `IMEISerials` record created/linked
///   - serial-level stock decremented (status == SOLD)
///
/// EXPECTED OUTCOME on UNFIXED code: Test FAILS because:
///   - `billing_service.dart` does not compute warranty expiry at POS
///   - `billing_service.dart` does not create an `IMEISerials` record from the
///     sale — the serial is written to `BillItems.imei` only
///   - Stock is decremented by SKU quantity only, not by serial status
///
/// Test approach: We simulate what `BillingService.createBill` does at the DB
/// level (insert bill header + bill items with serial/IMEI) and then verify
/// that the expected post-sale invariants hold. On UNFIXED code, no code in the
/// billing path creates the IMEISerials record or computes warranty — so the
/// assertions will FAIL.
///
/// PBT library: dartproptest ^0.2.1
///
/// Run: flutter test test/bug_condition/electronics_phase3_warranty_serial_integrity_exploration_test.dart
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/billing/services/billing_service.dart';
import 'package:dukanx/features/inventory/services/inventory_service.dart';
import 'package:dukanx/features/inventory/data/product_batch_repository.dart';
import 'package:dukanx/features/accounting/services/accounting_service.dart';
import 'package:dukanx/features/accounting/services/locking_service.dart';
import 'package:dukanx/features/accounting/models/journal_entry_model.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/service/data/repositories/imei_serial_repository.dart';
import 'package:dukanx/features/service/models/imei_serial.dart';
import 'package:dukanx/features/service/services/warranty_date_utils.dart';

// ---------------------------------------------------------------------------
// Fakes — let the test exercise the REAL BillingService.createBill code path
// (the fix lives there) without pulling in sync/accounting/period-lock infra.
// Mirrors test/integration/bill_flow_test.dart.
// ---------------------------------------------------------------------------

class _FakeSyncManager extends Fake implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem item) async => 'fake-op-id';
}

class _FakeAccountingService extends Fake implements AccountingService {
  @override
  Future<JournalEntryModel> createStockEntry({
    required String userId,
    required String referenceId,
    required String type,
    required String reason,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    return JournalEntryModel(
      id: 'dummy-entry',
      userId: userId,
      voucherNumber: 'JV-001',
      voucherType: VoucherType.journal,
      entryDate: date,
      entries: const [],
      totalDebit: amount,
      totalCredit: amount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _FakeLockingService extends Fake implements LockingService {
  @override
  Future<void> validateAction(
    String userId,
    DateTime date, {
    LockOverrideContext? overrideContext,
  }) async {
    // Always valid in tests.
  }
}

class _FakeProductBatchRepository extends Fake
    implements ProductBatchRepository {
  @override
  Future<double> updateBatchStock(String batchId, double delta) async => 0.0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Tenant ID used across all tests (simulates a single Electronics shop owner).
const _tenantId = 'test-electronics-tenant-phase3';

/// Creates an in-memory AppDatabase for isolated testing.
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Builds a real [BillingService] backed by the in-memory [db] and fakes for
/// the sync/accounting/period-lock collaborators, so the test drives the actual
/// production billing code path that contains the Phase 3 fix.
BillingService _createBillingService(AppDatabase db) {
  final inventoryService = InventoryService(
    db,
    _FakeLockingService(),
    _FakeAccountingService(),
    _FakeSyncManager(),
    _FakeProductBatchRepository(),
  );
  return BillingService(db, inventoryService);
}

/// Seeds a shop + product so the SKU-level stock deduction inside
/// [BillingService.createBill] succeeds for the given [productId].
Future<void> _seedShopAndProduct(
  AppDatabase db, {
  required String productId,
  required DateTime saleDate,
}) async {
  final existingShop = await (db.select(
    db.shops,
  )..where((t) => t.ownerId.equals(_tenantId))).getSingleOrNull();
  if (existingShop == null) {
    await db
        .into(db.shops)
        .insert(
          ShopsCompanion(
            id: const Value('$_tenantId-shop'),
            ownerId: const Value(_tenantId),
            businessType: const Value('electronics'),
            name: const Value('Test Electronics Shop'),
            allowNegativeStock: const Value(false),
            createdAt: Value(saleDate),
            updatedAt: Value(saleDate),
          ),
        );
  }

  await db
      .into(db.products)
      .insert(
        ProductsCompanion(
          id: Value(productId),
          userId: const Value(_tenantId),
          name: const Value('Samsung Galaxy S24 Ultra'),
          sellingPrice: const Value(15999.0),
          costPrice: const Value(12000.0),
          stockQuantity: const Value(10.0),
          createdAt: Value(saleDate),
          updatedAt: Value(saleDate),
        ),
        mode: InsertMode.insertOrReplace,
      );
}

/// Generates a unique serial number for a given seed.
String _serialForSeed(int seed) =>
    'SN-PH3-${seed.abs().toString().padLeft(6, '0')}';

/// Simulates the electronics billing path by calling the REAL
/// [BillingService.createBill] — the production code path where the Phase 3
/// fix lives — with a bill carrying the given serial and warranty months.
/// Then checks the post-sale invariants (IMEISerials record created, warranty
/// expiry computed, serial-level stock decremented to SOLD).
///
/// Before the fix: createBill wrote the serial to BillItems.imei only — no
/// IMEISerials record, no warranty computation. After the fix: createBill
/// creates the IMEISerials record with correct warranty data and SOLD status.
Future<void> _simulateElectronicsSaleAndVerify({
  required AppDatabase db,
  required String serial,
  required int warrantyMonths,
  required DateTime saleDate,
  required String billId,
  required String productId,
}) async {
  final billingService = _createBillingService(db);
  await _seedShopAndProduct(db, productId: productId, saleDate: saleDate);

  // warrantyMonths is carried per-line in the bill's itemsJson blob, keyed by
  // serialNo — exactly how BillingService parses it at POS.
  final itemsJson = jsonEncode([
    {
      'serialNo': serial,
      'warrantyMonths': warrantyMonths,
      'productId': productId,
      'productName': 'Samsung Galaxy S24 Ultra',
    },
  ]);

  // Step 1: Build the bill header (mirrors what the billing UI passes in).
  final bill = BillEntity(
    id: billId,
    userId: _tenantId,
    invoiceNumber: 'INV-PH3-${billId.hashCode.abs()}',
    billDate: saleDate,
    subtotal: 15999.0,
    taxAmount: 2879.82,
    discountAmount: 0,
    grandTotal: 18878.82,
    paidAmount: 18878.82,
    status: 'Paid',
    paymentMode: 'CASH',
    itemsJson: itemsJson,
    source: 'MANUAL',
    cashPaid: 18878.82,
    onlinePaid: 0,
    businessType: 'electronics',
    serviceCharge: 0,
    costOfGoodsSold: 0,
    grossProfit: 0,
    printCount: 0,
    isSynced: false,
    marketCess: 0,
    commissionAmount: 0,
    version: 1,
    customerId: null,
    customerName: 'Guest',
    createdAt: saleDate,
    updatedAt: saleDate,
  );

  // Step 2: Build the device bill line carrying the serial/IMEI.
  final item = BillItemEntity(
    id: '$billId-item-1',
    billId: billId,
    productId: productId,
    productName: 'Samsung Galaxy S24 Ultra',
    quantity: 1,
    unit: 'pcs',
    unitPrice: 15999.0,
    taxRate: 18.0,
    taxAmount: 2879.82,
    discountAmount: 0,
    totalAmount: 18878.82,
    sortOrder: 0,
    createdAt: saleDate,
    hsnCode: '85171290',
    cgstRate: 9.0,
    cgstAmount: 1439.91,
    sgstRate: 9.0,
    sgstAmount: 1439.91,
    igstRate: 0,
    igstAmount: 0,
    imei: serial,
  );

  // Route through the REAL production billing path (the fix lives here).
  final result = await billingService.createBill(bill: bill, items: [item]);
  expect(
    result.isSuccess,
    isTrue,
    reason:
        'BillingService.createBill must succeed for a valid electronics device '
        'sale. Error: ${result.error?.message}',
  );

  // Step 3: Verify the expected post-sale invariants
  final imeiRepo = IMEISerialRepository(db);
  final record = await imeiRepo.getByNumber(_tenantId, serial);

  // ASSERTION: IMEISerials record MUST exist after sale (2.12)
  expect(
    record,
    isNotNull,
    reason:
        'After an electronics device sale, an IMEISerials record MUST be '
        'created for serial "$serial" with warrantyMonths=$warrantyMonths. '
        'Bug: billing_service.dart writes the serial to BillItems.imei '
        'but does NOT create/link an IMEISerials record at point of sale.',
  );

  if (record != null) {
    // 2.11: Warranty expiry computed at POS
    final expectedEnd = warrantyEndDate(saleDate, warrantyMonths);
    expect(
      record.warrantyStartDate,
      equals(saleDate),
      reason:
          'warrantyStartDate must equal the sale date ($saleDate). '
          'Bug: warranty expiry is never computed at POS.',
    );
    expect(
      record.warrantyEndDate,
      equals(expectedEnd),
      reason:
          'warrantyEndDate must equal saleDate + $warrantyMonths months '
          '(expected: $expectedEnd). Bug: no warranty computation at POS.',
    );
    expect(
      record.isUnderWarranty,
      equals(warrantyMonths > 0),
      reason:
          'isUnderWarranty must be ${warrantyMonths > 0} for '
          'warrantyMonths=$warrantyMonths.',
    );

    // 2.12: Tenant-scoped, RID-patterned, linked to bill
    expect(record.userId, equals(_tenantId));
    expect(record.billId, equals(billId));

    // 2.13: Serial-level stock decremented (status == SOLD)
    expect(
      record.status,
      equals(IMEISerialStatus.sold),
      reason:
          'Serial-level stock must be decremented to SOLD status after sale. '
          'Bug: only SKU-level stock is decremented, serial status untouched.',
    );
  }
}

void main() {
  // =========================================================================
  // Concrete boundary test: warrantyMonths = 0 (no warranty)
  //
  // Even with 0 warranty months, the sale should still create an IMEISerials
  // record (tracking the unit) with status SOLD and warrantyEndDate = saleDate.
  // =========================================================================
  group(
    'Phase 3 Bug Condition — boundary: warrantyMonths=0 creates IMEISerials record',
    () {
      late AppDatabase db;

      setUp(() {
        db = _createTestDb();
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'warrantyMonths=0: IMEISerials record created with status SOLD (2.12, 2.13)',
        () async {
          await _simulateElectronicsSaleAndVerify(
            db: db,
            serial: 'SN-PH3-BOUNDARY-ZERO',
            warrantyMonths: 0,
            saleDate: DateTime(2025, 6, 15),
            billId: '$_tenantId-1718409600000-boundary-zero',
            productId: 'prod-boundary-0',
          );
        },
      );
    },
  );

  // =========================================================================
  // Concrete boundary test: warrantyMonths = 120 (max warranty, 10 years)
  //
  // The sale should create an IMEISerials record with warrantyEndDate =
  // saleDate + 120 months.
  // =========================================================================
  group(
    'Phase 3 Bug Condition — boundary: warrantyMonths=120 warranty expiry computed',
    () {
      late AppDatabase db;

      setUp(() {
        db = _createTestDb();
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'warrantyMonths=120: warrantyEndDate == saleDate + 120 months (2.11)',
        () async {
          await _simulateElectronicsSaleAndVerify(
            db: db,
            serial: 'SN-PH3-BOUNDARY-MAX',
            warrantyMonths: 120,
            saleDate: DateTime(2025, 1, 15),
            billId: '$_tenantId-1736899200000-boundary-max',
            productId: 'prod-boundary-120',
          );
        },
      );
    },
  );

  // =========================================================================
  // Concrete test: warrantyMonths=12 standard case
  //
  // Standard 1-year warranty — the most common scenario.
  // =========================================================================
  group('Phase 3 Bug Condition — warrantyMonths=12 standard case', () {
    late AppDatabase db;

    setUp(() {
      db = _createTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'warrantyMonths=12: full warranty/serial integrity at POS (2.11, 2.12, 2.13)',
      () async {
        await _simulateElectronicsSaleAndVerify(
          db: db,
          serial: 'SN-PH3-STANDARD-12M',
          warrantyMonths: 12,
          saleDate: DateTime(2025, 3, 20),
          billId: '$_tenantId-1742428800000-standard-12',
          productId: 'prod-standard-12',
        );
      },
    );
  });

  // =========================================================================
  // PBT: Property over random warrantyMonths ∈ 0..120 and sale dates
  //
  // For any random warrantyMonths in 0..120 and a random sale date, after
  // billing an electronics device:
  //   - warrantyEndDate == saleDate + warrantyMonths (exact per design)
  //   - exactly one IMEISerials record exists per unit sold
  //   - serial stock is decremented once (status == SOLD)
  //
  // Bug: billing_service.dart creates no IMEISerials record and computes no
  // warranty expiry — this property will fail on every input.
  // =========================================================================
  group('Phase 3 Bug Condition — PBT warranty/serial integrity property', () {
    test(
      'PBT: for random warrantyMonths ∈ 0..120 and sale dates, '
      'warranty expiry is computed and IMEISerials record created (2.11, 2.12, 2.13)',
      () async {
        await forAll(
          (int warrantyMonths) async {
            // Create a fresh DB for each property check to avoid cross-contamination
            final localDb = _createTestDb();

            try {
              // Generate a unique serial from the warrantyMonths seed
              final serial = _serialForSeed(warrantyMonths * 7 + 42);
              // Derive a sale date from the seed for diversity
              final saleDate = DateTime(
                2024 + (warrantyMonths % 3), // 2024, 2025, or 2026
                1 + (warrantyMonths % 12), // Month 1-12
                1 + (warrantyMonths % 28), // Day 1-28
              );
              final billId =
                  '$_tenantId-${saleDate.millisecondsSinceEpoch}-pbt-$warrantyMonths';
              final productId =
                  'prod-electronics-ph3-${warrantyMonths.abs() % 100}';

              await _simulateElectronicsSaleAndVerify(
                db: localDb,
                serial: serial,
                warrantyMonths: warrantyMonths,
                saleDate: saleDate,
                billId: billId,
                productId: productId,
              );
            } finally {
              await localDb.close();
            }

            return true;
          },
          // Generate warrantyMonths values across the full 0..120 range
          // (includes boundary values 0 and 120 within the interval)
          [Gen.interval(0, 120)],
          numRuns: 20,
        );
      },
    );
  });

  // =========================================================================
  // Control test: billing DOES insert the bill and bill items (existing behavior)
  //
  // This confirms the billing path itself functions — the bill and items are
  // written to the DB. The bug is specifically that NO IMEISerials record is
  // created and NO warranty expiry is computed. This control should PASS even
  // on unfixed code.
  // =========================================================================
  group(
    'Control — billing inserts bill and items (existing behavior works)',
    () {
      late AppDatabase db;

      setUp(() {
        db = _createTestDb();
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'bill and bill items with serial are written to DB (control)',
        () async {
          const serial = 'SN-PH3-CONTROL';
          final saleDate = DateTime(2025, 5, 10);
          final billId =
              '$_tenantId-${saleDate.millisecondsSinceEpoch}-control';

          // Insert bill
          await db.insertBill(
            BillsCompanion(
              id: Value(billId),
              userId: Value(_tenantId),
              invoiceNumber: const Value('INV-PH3-CONTROL'),
              billDate: Value(saleDate),
              subtotal: const Value(15999.0),
              taxAmount: const Value(2879.82),
              discountAmount: const Value(0),
              grandTotal: const Value(18878.82),
              paidAmount: const Value(18878.82),
              status: const Value('Paid'),
              paymentMode: const Value('CASH'),
              itemsJson: const Value('[]'),
              source: const Value('MANUAL'),
              cashPaid: const Value(18878.82),
              onlinePaid: const Value(0),
              businessType: const Value('electronics'),
              serviceCharge: const Value(0),
              costOfGoodsSold: const Value(0),
              grossProfit: const Value(0),
              printCount: const Value(0),
              isSynced: const Value(false),
              marketCess: const Value(0),
              commissionAmount: const Value(0),
              createdAt: Value(saleDate),
              updatedAt: Value(saleDate),
            ),
          );

          // Insert bill item with serial
          await db
              .into(db.billItems)
              .insert(
                BillItemsCompanion(
                  id: Value('$billId-item-1'),
                  billId: Value(billId),
                  productId: const Value('prod-control'),
                  productName: const Value('Samsung Galaxy S24 Ultra'),
                  quantity: const Value(1),
                  unit: const Value('pcs'),
                  unitPrice: const Value(15999.0),
                  taxRate: const Value(18.0),
                  taxAmount: const Value(2879.82),
                  discountAmount: const Value(0),
                  totalAmount: const Value(18878.82),
                  sortOrder: const Value(0),
                  createdAt: Value(saleDate),
                  hsnCode: const Value('85171290'),
                  cgstRate: const Value(9.0),
                  cgstAmount: const Value(1439.91),
                  sgstRate: const Value(9.0),
                  sgstAmount: const Value(1439.91),
                  igstRate: const Value(0),
                  igstAmount: const Value(0),
                  imei: const Value(serial),
                ),
              );

          // Verify the bill was written
          final bill = await (db.select(
            db.bills,
          )..where((t) => t.id.equals(billId))).getSingleOrNull();
          expect(bill, isNotNull, reason: 'Bill should be written to DB');
          expect(bill!.businessType, equals('electronics'));

          // Verify the bill item was written with the serial
          final items = await (db.select(
            db.billItems,
          )..where((t) => t.billId.equals(billId))).get();
          expect(items.length, equals(1));
          expect(items.first.imei, equals(serial));

          // This PASSES on unfixed code — the bug is the ABSENCE of IMEISerials
          // record creation, not a failure to write bill/items.
        },
      );
    },
  );
}
