// ============================================================================
// Task 18.3 — UNIT TESTS for expiry validation cases
// Feature: pharmacy-vertical-remediation
// _Requirements: 23.5_
// ============================================================================
//
// These example-based unit tests pin the three mandated expiry outcomes of
// `PharmacyValidationService.validateBillItem` after Task 18.1 reordered the
// required-field check to run BEFORE the past-date check:
//
//   * Null expiry    -> fails as MISSING_EXPIRY_DATE (a missing required
//                        field), and NOT EXPIRED_PRODUCT (the past-date check
//                        is skipped).
//   * Past expiry    -> fails as EXPIRED_PRODUCT (past-dated).
//   * Current/future -> passes (no exception).
//
// Each item uses a NON-EMPTY batchNo and a non-scheduled drug so the batch and
// prescription rules never fire — isolating the expiry dimension. We drive the
// service under `BusinessType.pharmacy`, the vertical whose config requires
// both batchNo and expiryDate.
//
// Run: flutter test test/features/pharmacy/expiry_validation_cases_test.dart
// ============================================================================

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/error/pharmacy_compliance_exception.dart';
import 'package:dukanx/core/services/pharmacy_validation_service.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a pharmacy bill item with a fixed non-empty batch number and a
/// non-scheduled drug, varying only the expiry date so the tests isolate the
/// expiry dimension.
BillItem _item({DateTime? expiryDate, required String productName}) => BillItem(
  productId: 'P-$productName',
  productName: productName,
  qty: 1,
  price: 10,
  batchNo: 'BATCH-1', // non-empty => batch rule never fires
  expiryDate: expiryDate,
  // drugSchedule left null => not scheduled => no prescription needed.
);

void main() {
  final service = PharmacyValidationService();

  group('Task 18.3 — expiry validation cases (Requirements 23.5)', () {
    test(
      'null expiry fails as MISSING_EXPIRY_DATE (missing required field)',
      () {
        final item = _item(productName: 'NullExpiryDrug');

        expect(
          () => service.validateBillItem(item, BusinessType.pharmacy),
          throwsA(
            isA<PharmacyComplianceException>().having(
              (e) => e.code,
              'code',
              'MISSING_EXPIRY_DATE',
            ),
          ),
        );
      },
    );

    test(
      'null expiry does NOT fail as EXPIRED_PRODUCT (past-check skipped)',
      () {
        final item = _item(productName: 'NullExpiryDrug');

        try {
          service.validateBillItem(item, BusinessType.pharmacy);
          fail('Expected a PharmacyComplianceException for null expiry');
        } on PharmacyComplianceException catch (e) {
          expect(
            e.code,
            isNot('EXPIRED_PRODUCT'),
            reason: 'Required-field check must run before the past-date check.',
          );
          expect(e.code, 'MISSING_EXPIRY_DATE');
        }
      },
    );

    test('past expiry fails as EXPIRED_PRODUCT (past-dated)', () {
      final item = _item(
        productName: 'PastExpiryDrug',
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(
        () => service.validateBillItem(item, BusinessType.pharmacy),
        throwsA(
          isA<PharmacyComplianceException>().having(
            (e) => e.code,
            'code',
            'EXPIRED_PRODUCT',
          ),
        ),
      );
    });

    test('future expiry passes (no exception)', () {
      final item = _item(
        productName: 'FutureExpiryDrug',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );

      expect(
        () => service.validateBillItem(item, BusinessType.pharmacy),
        returnsNormally,
      );
    });

    test('current (near-now future) expiry passes', () {
      // A clearly-future expiry a minute ahead represents "current/future"
      // without sampling the ambiguous sub-second boundary around now().
      final item = _item(
        productName: 'CurrentExpiryDrug',
        expiryDate: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(
        () => service.validateBillItem(item, BusinessType.pharmacy),
        returnsNormally,
      );
    });
  });
}
