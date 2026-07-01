// ============================================================================
// PHARMACY VERTICAL REMEDIATION — Task 18.3: EXAMPLE-BASED UNIT TESTS
// Feature: pharmacy-vertical-remediation
// Under test: PharmacyValidationService.validateBillItem(...)
//             (lib/core/services/pharmacy_validation_service.dart)
// **Validates: Requirements 23.5**
// ============================================================================
//
// Requirement 23 — "Fix Null-Expiry Bypass Order-of-Checks":
//   23.1 Required-field expiry check runs BEFORE the past-expiry check.
//   23.2 Null/empty expiry -> FAILED with a missing-expiry result, and the
//        past-expiry check is NOT evaluated (so it must surface
//        MISSING_EXPIRY_DATE, never EXPIRED_PRODUCT).
//   23.3 Non-null expiry earlier than now -> FAILED as past-dated
//        (EXPIRED_PRODUCT).
//   23.4 Non-null expiry equal-or-later than now -> PASSED (no throw).
//   23.5 Tests SHALL cover at minimum: null expiry (missing-expiry),
//        past expiry (past-dated), and current-or-future expiry (passed).
//
// These are the three mandated cases. We exercise the PHARMACY path
// (BusinessType.pharmacy requires batchNo + expiryDate), supplying a non-empty
// batchNo so the batch check passes and the expiry path is the one under test.
//
// Run: flutter test test/features/pharmacy/pharmacy_expiry_validation_test.dart
// ============================================================================

import 'package:dukanx/core/billing/business_type_config.dart'
    show BusinessType;
import 'package:dukanx/core/error/pharmacy_compliance_exception.dart';
import 'package:dukanx/core/services/pharmacy_validation_service.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal pharmacy [BillItem] with a present batch number so the
/// mandatory-batch check passes and validation reaches the expiry logic.
BillItem _pharmacyItem({DateTime? expiryDate}) {
  return BillItem(
    productId: 'p-1',
    productName: 'Paracetamol 500mg',
    qty: 1,
    price: 1000, // paise — value irrelevant to the expiry path
    batchNo: 'BATCH-001', // non-empty -> batch check passes
    expiryDate: expiryDate,
  );
}

/// Matches a [PharmacyComplianceException] carrying the given [code].
Matcher _throwsComplianceCode(String code) {
  return throwsA(
    isA<PharmacyComplianceException>().having((e) => e.code, 'code', code),
  );
}

void main() {
  final service = PharmacyValidationService();
  const businessType = BusinessType.pharmacy;

  group(
    'PharmacyValidationService.validateBillItem — expiry cases (R23.5)',
    () {
      test('null expiry (batch present) fails as MISSING_EXPIRY_DATE, not '
          'EXPIRED_PRODUCT (R23.1, R23.2)', () {
        final item = _pharmacyItem(expiryDate: null);

        // Required-field check runs first: missing expiry, NOT past-dated.
        expect(
          () => service.validateBillItem(item, businessType),
          _throwsComplianceCode('MISSING_EXPIRY_DATE'),
        );

        // Defensively confirm it is NOT reported as an expired product.
        expect(
          () => service.validateBillItem(item, businessType),
          isNot(_throwsComplianceCode('EXPIRED_PRODUCT')),
        );
      });

      test('past expiry fails as EXPIRED_PRODUCT (R23.3)', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final item = _pharmacyItem(expiryDate: pastDate);

        expect(
          () => service.validateBillItem(item, businessType),
          _throwsComplianceCode('EXPIRED_PRODUCT'),
        );
      });

      test('current/today expiry passes (no throw) (R23.4)', () {
        // "Today" represented at end-of-day so it is equal-or-later than the
        // instant `validateBillItem` reads via DateTime.now() — a current-dated
        // item must pass.
        final now = DateTime.now();
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        final item = _pharmacyItem(expiryDate: endOfToday);

        expect(
          () => service.validateBillItem(item, businessType),
          returnsNormally,
        );
      });

      test('future expiry passes (no throw) (R23.4)', () {
        final futureDate = DateTime.now().add(const Duration(days: 365));
        final item = _pharmacyItem(expiryDate: futureDate);

        expect(
          () => service.validateBillItem(item, businessType),
          returnsNormally,
        );
      });
    },
  );
}
