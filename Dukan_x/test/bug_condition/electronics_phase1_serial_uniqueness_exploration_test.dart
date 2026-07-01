/// Phase 1 Bug-Condition Exploration Test — Electronics Serial/IMEI Uniqueness
///
/// **Validates: Requirements 2.5, 2.6, 2.7**
///
/// **Property 3: Bug Condition** — Serial/IMEI uniqueness and required-at-billing.
///
/// This test encodes the EXPECTED behavior (what SHOULD happen after the fix).
/// It is run on UNFIXED code and is EXPECTED TO FAIL — failure confirms the bug
/// exists.
///
/// Bug condition (from design):
///   `BillLineSave` where `businessType == electronics AND isDeviceLine AND
///    (serial blank OR duplicateOrSold(serial, tenantId))`
///
/// Expected behavior asserted:
///   - blank serial rejected with "serial required for electronics"
///   - duplicate/already-sold serial rejected against tenant-scoped `IMEISerials`
///     `{userId, imeiOrSerial}`
///   - unique non-blank serial accepted unchanged
///
/// EXPECTED OUTCOME on UNFIXED code: Test FAILS because:
///   - `billing_service.dart` stub (`// Strict 1:1 validation could go here`)
///     accepts duplicates
///   - `manual_item_entry_sheet.dart` `null` validator accepts blanks for
///     electronics
///   - `imei_validation_service.dart` `validateBillItems` only adds blank-serial
///     error when `businessType.contains('mobile')`, not for 'electronics'
///
/// PBT library: dartproptest ^0.2.1
///
/// Run: flutter test test/bug_condition/electronics_phase1_serial_uniqueness_exploration_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:drift/native.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/service/services/imei_validation_service.dart';
import 'package:dukanx/features/service/data/repositories/imei_serial_repository.dart';
import 'package:dukanx/features/service/models/imei_serial.dart';
import 'package:dukanx/models/bill.dart';
import 'package:dukanx/models/business_type.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory AppDatabase for isolated testing.
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Creates a BillItem with a given serial and product name.
BillItem _makeBillItem({
  required String productId,
  required String productName,
  String? serialNo,
  int? warrantyMonths,
  double price = 15999.0,
}) {
  return BillItem(
    productId: productId,
    productName: productName,
    qty: 1,
    price: price,
    unit: 'pcs',
    hsn: '85171290',
    gstRate: 18.0,
    serialNo: serialNo,
    warrantyMonths: warrantyMonths ?? 12,
  );
}

/// Tenant ID used across all tests (simulates a single Electronics shop owner).
const _tenantId = 'test-electronics-tenant-001';

void main() {
  // =========================================================================
  // (a) Blank serial on an Electronics device line — assert rejected
  //
  // Bug: `imei_validation_service.validateBillItems` only adds the error
  //   "IMEI/Serial required for: ..." when `businessType.contains('mobile')`.
  //   For 'electronics', blank serials silently pass.
  // Expected: blank serial rejected with a message containing
  //   "required" for electronics device lines.
  // =========================================================================
  group('Phase 1 Bug Condition — blank serial rejected for electronics', () {
    late AppDatabase db;
    late IMEIValidationService validationService;

    setUp(() {
      db = _createTestDb();
      validationService = IMEIValidationService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('blank serial on electronics device line is rejected (2.6)', () async {
      final items = [
        _makeBillItem(
          productId: 'prod-phone-001',
          productName: 'Samsung Galaxy S24',
          serialNo: '', // BLANK — should be rejected for electronics
        ),
      ];

      final result = await validationService.validateBillItems(
        userId: _tenantId,
        items: items,
        businessType: BusinessType.electronics.name, // 'electronics'
      );

      // EXPECTED (post-fix): validation fails for blank serial on electronics
      expect(
        result.isValid,
        isFalse,
        reason:
            'Blank serial on an electronics device line must be rejected. '
            'Bug: imei_validation_service only requires serial when '
            'businessType.contains("mobile"), silently accepting blanks for '
            'electronics.',
      );
      expect(
        result.errors.any(
          (e) =>
              e.toLowerCase().contains('required') ||
              e.toLowerCase().contains('serial'),
        ),
        isTrue,
        reason:
            'Error message should mention serial being required for electronics',
      );
    });

    test('null serial on electronics device line is rejected (2.6)', () async {
      final items = [
        _makeBillItem(
          productId: 'prod-phone-002',
          productName: 'iPhone 15 Pro',
          serialNo: null, // NULL — should be rejected for electronics
        ),
      ];

      final result = await validationService.validateBillItems(
        userId: _tenantId,
        items: items,
        businessType: BusinessType.electronics.name,
      );

      // EXPECTED (post-fix): validation fails for null serial on electronics
      expect(
        result.isValid,
        isFalse,
        reason:
            'Null serial on an electronics device line must be rejected. '
            'Bug: validation only triggers blank-serial error for mobileShop.',
      );
    });
  });

  // =========================================================================
  // (b) Same IMEI billed twice in one tenant — assert rejected
  //
  // Bug: `billing_service.dart` stub (`// Strict 1:1 validation could go here`)
  //   performs no uniqueness enforcement. The `validateBillItems` in
  //   `imei_validation_service` DOES check for sold status — but the billing
  //   flow via `billing_service._validateBillRules` never calls it for the
  //   uniqueness concern. Even within `validateBillItems`, if a serial doesn't
  //   exist in IMEISerials yet (first sale not recorded), the second attempt
  //   also won't find it as sold.
  //
  // Expected: duplicate/already-sold serial rejected against tenant-scoped
  //   `IMEISerials` `{userId, imeiOrSerial}`.
  // =========================================================================
  group('Phase 1 Bug Condition — duplicate IMEI rejected for electronics', () {
    late AppDatabase db;
    late IMEIValidationService validationService;
    late IMEISerialRepository imeiRepository;

    setUp(() {
      db = _createTestDb();
      validationService = IMEIValidationService(db);
      imeiRepository = IMEISerialRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('same IMEI billed twice in one tenant is rejected (2.5)', () async {
      // Use a non-15-digit serial to avoid Luhn check interference
      const duplicateSerial = 'SN-ELEC-SOLD-12345';

      // First: insert the serial as already-sold in the tenant's IMEISerials
      final now = DateTime.now();
      final existingRecord = IMEISerial(
        id: 'imei-record-001',
        userId: _tenantId,
        productId: 'prod-phone-003',
        imeiOrSerial: duplicateSerial,
        type: IMEISerialType.imei,
        status: IMEISerialStatus.sold, // Already sold
        billId: 'bill-prev-001',
        customerId: 'cust-001',
        soldPrice: 59999.0,
        soldDate: now.subtract(const Duration(days: 30)),
        warrantyMonths: 12,
        warrantyStartDate: now.subtract(const Duration(days: 30)),
        warrantyEndDate: now.add(const Duration(days: 335)),
        isUnderWarranty: true,
        productName: 'Samsung Galaxy S24',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );
      await imeiRepository.createIMEISerial(existingRecord);

      // Now attempt to bill the SAME serial again for electronics
      final items = [
        _makeBillItem(
          productId: 'prod-phone-003',
          productName: 'Samsung Galaxy S24',
          serialNo: duplicateSerial, // DUPLICATE — already sold
        ),
      ];

      final result = await validationService.validateBillItems(
        userId: _tenantId,
        items: items,
        businessType: BusinessType.electronics.name,
      );

      // EXPECTED (post-fix): validation fails for duplicate/already-sold serial
      expect(
        result.isValid,
        isFalse,
        reason:
            'A duplicate/already-sold IMEI must be rejected for electronics. '
            'Bug: billing_service.dart stub does nothing; even '
            'imei_validation_service does check sold status but the '
            'electronics billing flow in billing_service._validateBillRules '
            'never enforces uniqueness (the stub is empty).',
      );
      expect(
        result.errors.any(
          (e) =>
              e.toLowerCase().contains('sold') ||
              e.toLowerCase().contains('duplicate'),
        ),
        isTrue,
        reason: 'Error message should mention serial already sold or duplicate',
      );
    });

    test(
      'same serial used in a single bill with two items is rejected (2.5)',
      () async {
        const sharedSerial = 'SN-ELECTRONICS-DUP-001';

        // Two items in the same bill attempt to use the same serial
        final items = [
          _makeBillItem(
            productId: 'prod-earbuds-001',
            productName: 'Sony WF-1000XM5 (Unit 1)',
            serialNo: sharedSerial,
          ),
          _makeBillItem(
            productId: 'prod-earbuds-001',
            productName: 'Sony WF-1000XM5 (Unit 2)',
            serialNo: sharedSerial, // SAME serial on different line
          ),
        ];

        final result = await validationService.validateBillItems(
          userId: _tenantId,
          items: items,
          businessType: BusinessType.electronics.name,
        );

        // EXPECTED (post-fix): within-bill duplicate rejected
        expect(
          result.isValid,
          isFalse,
          reason:
              'Two items in the same bill sharing a serial must be rejected. '
              'Bug: no within-bill duplicate detection exists.',
        );
      },
    );
  });

  // =========================================================================
  // (c) PBT: property over random serial multiset within a tenant asserting
  //     no two active IMEISerials records share a serial after billing.
  //
  // Bug: The billing path does not enforce uniqueness — duplicates accumulate.
  //
  // This property generates random serial sets (some with duplicates) and
  // asserts that validation correctly rejects duplicates and accepts uniques.
  // =========================================================================
  group('Phase 1 Bug Condition — PBT serial uniqueness property', () {
    late AppDatabase db;
    late IMEIValidationService validationService;
    late IMEISerialRepository imeiRepository;

    setUp(() {
      db = _createTestDb();
      validationService = IMEIValidationService(db);
      imeiRepository = IMEISerialRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('PBT: for random serial multisets, validation rejects duplicates and '
        'accepts uniques for electronics (2.5, 2.6, 2.7)', () async {
      // We test a scoped property: given a set of serials where some are
      // already "sold" in the tenant, attempting to bill those same serials
      // again must be rejected.
      //
      // The property: after billing, no two active IMEISerials records
      // in the same tenant share a serial number.

      // Generate multiple test scenarios with different serial sets
      await forAll(
        (int seed) async {
          // Create a fresh DB for each property check to avoid cross-contamination
          final localDb = _createTestDb();
          final localValidation = IMEIValidationService(localDb);
          final localRepo = IMEISerialRepository(localDb);

          try {
            // Generate a serial from the seed
            final baseSerial =
                'SN-${(seed.abs() % 99999).toString().padLeft(5, '0')}';
            final now = DateTime.now();

            // Pre-seed this serial as "sold" in the tenant
            await localRepo.createIMEISerial(
              IMEISerial(
                id: 'pre-${seed.abs()}',
                userId: _tenantId,
                productId: 'prod-${seed.abs() % 10}',
                imeiOrSerial: baseSerial,
                type: IMEISerialType.serial,
                status: IMEISerialStatus.sold,
                billId: 'bill-prev-${seed.abs()}',
                soldDate: now.subtract(const Duration(days: 10)),
                warrantyMonths: 12,
                warrantyStartDate: now.subtract(const Duration(days: 10)),
                warrantyEndDate: now.add(const Duration(days: 355)),
                isUnderWarranty: true,
                productName: 'Test Product $seed',
                createdAt: now,
                updatedAt: now,
              ),
            );

            // Now attempt to bill the same serial again
            final items = [
              _makeBillItem(
                productId: 'prod-new-${seed.abs() % 10}',
                productName: 'Attempted Duplicate Sale $seed',
                serialNo: baseSerial, // Already sold above
              ),
            ];

            final result = await localValidation.validateBillItems(
              userId: _tenantId,
              items: items,
              businessType: BusinessType.electronics.name,
            );

            // PROPERTY: duplicate serial must be rejected
            expect(
              result.isValid,
              isFalse,
              reason:
                  'Property violated: serial "$baseSerial" is already sold in '
                  'tenant $_tenantId but was accepted again. No two active '
                  'IMEISerials records should share a serial after billing.',
            );
          } finally {
            await localDb.close();
          }

          return true;
        },
        [Gen.interval(1, 50)],
        numRuns: 10,
      );
    });

    test('PBT: unique non-blank serials are always accepted for electronics '
        '(happy path preserved) (2.7, 3.5)', () async {
      // Counter-property: a unique, non-blank serial must always be accepted.
      // This should PASS even on unfixed code (the happy path works today).
      await forAll(
        (int seed) async {
          final localDb = _createTestDb();
          final localValidation = IMEIValidationService(localDb);

          try {
            // Generate a unique serial (no pre-existing record)
            final uniqueSerial = 'UNIQUE-${seed.abs()}-${(seed * 7).abs()}';

            final items = [
              _makeBillItem(
                productId: 'prod-unique-${seed.abs() % 10}',
                productName: 'Valid Electronics Item $seed',
                serialNo: uniqueSerial,
              ),
            ];

            final result = await localValidation.validateBillItems(
              userId: _tenantId,
              items: items,
              businessType: BusinessType.electronics.name,
            );

            // PROPERTY: unique non-blank serial must be accepted
            expect(
              result.isValid,
              isTrue,
              reason:
                  'Property violated: unique serial "$uniqueSerial" should be '
                  'accepted for electronics but was rejected. The uniqueness '
                  'fix must not break the happy path.',
            );
          } finally {
            await localDb.close();
          }

          return true;
        },
        [Gen.interval(100, 200)],
        numRuns: 10,
      );
    });
  });

  // =========================================================================
  // Concrete counterexample: mobileShop blank-serial rejection (control test)
  //
  // This test SHOULD PASS on unfixed code — it confirms mobileShop correctly
  // rejects blanks (the existing, working validator). This is the
  // preservation-side control that proves the bug is electronics-specific.
  // =========================================================================
  group('Control — mobileShop blank serial IS rejected (Preservation 3.2)', () {
    late AppDatabase db;
    late IMEIValidationService validationService;

    setUp(() {
      db = _createTestDb();
      validationService = IMEIValidationService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('mobileShop blank serial is rejected (control)', () async {
      final items = [
        _makeBillItem(
          productId: 'prod-mobile-001',
          productName: 'iPhone 15',
          serialNo: '', // BLANK
        ),
      ];

      final result = await validationService.validateBillItems(
        userId: _tenantId,
        items: items,
        businessType: BusinessType.mobileShop.name, // 'mobileShop'
      );

      // This SHOULD pass on unfixed code — mobileShop already rejects blanks
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('required')),
        isTrue,
        reason: 'mobileShop correctly rejects blank serials',
      );
    });
  });
}
