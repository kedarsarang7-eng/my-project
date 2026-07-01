// ============================================================================
// PHASE — Task 18.2: PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 24: Expiry validation
//          evaluates required-field before past-date
// **Validates: Requirements 23.1, 23.2, 23.3, 23.4**
// ============================================================================
//
// Property 24 (design.md — Correctness Properties):
//   *For any* item, a null or empty expiry date yields a failed validation
//   identifying expiry as a missing required field with the past-expiry check
//   skipped; a non-null expiry earlier than the current date yields a failed
//   past-dated validation; a non-null expiry equal to or later than the current
//   date passes; in all cases the item's unsaved data is unchanged.
//
// WHAT IS PROVEN HERE:
//   Task 18.1 reordered `PharmacyValidationService.validateBillItem` so the
//   required-field check for expiry runs BEFORE the past-expiry check. We drive
//   the service under `BusinessType.pharmacy` (the vertical whose config
//   requires both batchNo and expiryDate) with a NON-EMPTY batch number and a
//   non-scheduled drug, so the only failing surface left is the expiry logic.
//   For every generated item the service outcome must match an independent
//   oracle keyed on the expiry category:
//     * null expiry        -> throws MISSING_EXPIRY_DATE (required-field),
//                             and NEVER EXPIRED_PRODUCT (past-date is skipped).
//     * non-null past       -> throws EXPIRED_PRODUCT (past-dated).
//     * non-null future     -> passes (no exception).
//   In all three cases the item's data (productName, batchNo, expiryDate, qty,
//   price, productId) is unchanged, since validation never mutates the item.
//
// TIMING NOTE:
//   The service captures `DateTime.now()` internally, so the exact-equal
//   instant boundary is not deterministically observable (clock advances
//   between item construction and the captured `now`). To keep the property
//   robust and faithful we generate only CLEARLY-past expiries (>= 1 day ago)
//   and CLEARLY-future expiries (>= 60s ahead); the ambiguous sub-second region
//   around "now" is intentionally not sampled. Requirement 23.4's
//   "equal-or-later passes" obligation is exercised by the future category and
//   the deterministic anchors below.
//
// PBT library: dartproptest ^0.2.1 (repo-standard; see pubspec.yaml note on why
//   `glados` is not used). Idiomatic usage: `forAll((arg) => <bool>, [gen],
//   numRuns: N)` returns true iff the property held for every run, else throws
//   a shrinking Exception with a counterexample.
//
// Run: flutter test test/features/pharmacy/expiry_validation_order_property24_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/error/pharmacy_compliance_exception.dart';
import 'package:dukanx/core/services/pharmacy_validation_service.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec; 200 is the
/// dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// The three mutually-exclusive expiry categories the property exercises.
enum _ExpiryKind { nullExpiry, past, future }

/// A single generated validation scenario plus its expected oracle outcome.
class _ExpiryCase {
  final _ExpiryKind kind;
  final DateTime? expiry;
  final String productId;
  final String productName;
  final String batchNo;
  final double qty;
  final double price;

  const _ExpiryCase({
    required this.kind,
    required this.expiry,
    required this.productId,
    required this.productName,
    required this.batchNo,
    required this.qty,
    required this.price,
  });
}

/// Build a fresh [BillItem] for the case. batchNo is ALWAYS non-empty and the
/// drug is non-scheduled, so the batch-number and prescription rules never
/// fire — isolating the expiry order-of-checks under test.
BillItem _buildItem(_ExpiryCase c) => BillItem(
  productId: c.productId,
  productName: c.productName,
  qty: c.qty,
  price: c.price,
  batchNo: c.batchNo,
  expiryDate: c.expiry,
  // drugSchedule left null => not a scheduled drug => no prescription needed.
);

/// Independent oracle: the error code the service SHOULD raise, or null when
/// validation SHOULD pass. Mirrors Requirements 23.1–23.4 directly.
String? _oracleOutcome(_ExpiryKind kind) {
  switch (kind) {
    case _ExpiryKind.nullExpiry:
      return 'MISSING_EXPIRY_DATE'; // required-field, past-check skipped
    case _ExpiryKind.past:
      return 'EXPIRED_PRODUCT'; // past-dated
    case _ExpiryKind.future:
      return null; // passes
  }
}

/// Run the service and reduce its behaviour to a comparable token: the thrown
/// compliance code, or null when no exception was raised (validation passed).
String? _actualOutcome(BillItem item) {
  try {
    PharmacyValidationService().validateBillItem(item, BusinessType.pharmacy);
    return null;
  } on PharmacyComplianceException catch (e) {
    return e.code;
  }
}

/// A compact, comparable snapshot of the fields the property promises to leave
/// unchanged across a validation call.
String _snapshot(BillItem i) => [
  i.productId,
  i.productName,
  i.batchNo,
  i.expiryDate?.toIso8601String() ?? '<null>',
  i.qty.toString(),
  i.price.toString(),
].join('|');

/// Draws all three expiry categories with varied item data so null/past/future
/// branches co-occur across runs.
final Generator<_ExpiryCase> _caseGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 2), // 0: kind selector
      Gen.interval(1, 3650), // 1: days in the past (>= 1 day => clearly past)
      Gen.interval(
        60,
        315360000,
      ), // 2: seconds in future (>=60s => clearly future)
      Gen.interval(0, 100000), // 3: product name suffix
      Gen.interval(0, 100000), // 4: batch suffix
      Gen.interval(1, 100000), // 5: qty (scaled below)
      Gen.interval(0, 100000000), // 6: price in paise (scaled below)
    ]).map((parts) {
      final int kindSel = parts[0] as int;
      final int pastDays = parts[1] as int;
      final int futureSeconds = parts[2] as int;
      final int nameSuffix = parts[3] as int;
      final int batchSuffix = parts[4] as int;
      final double qty = (parts[5] as int) / 100.0; // 0.01 .. 1000.00
      final double price = (parts[6] as int) / 100.0; // ₹0.00 .. ₹1,000,000

      final _ExpiryKind kind = _ExpiryKind.values[kindSel];
      final DateTime now = DateTime.now();
      DateTime? expiry;
      switch (kind) {
        case _ExpiryKind.nullExpiry:
          expiry = null;
          break;
        case _ExpiryKind.past:
          expiry = now.subtract(Duration(days: pastDays));
          break;
        case _ExpiryKind.future:
          expiry = now.add(Duration(seconds: futureSeconds));
          break;
      }

      return _ExpiryCase(
        kind: kind,
        expiry: expiry,
        productId: 'P$nameSuffix',
        productName: 'Drug_$nameSuffix',
        batchNo: 'B$batchSuffix', // ALWAYS non-empty
        qty: qty,
        price: price,
      );
    });

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 24: Expiry validation '
      'evaluates required-field before past-date', () {
    test('Property 24: null expiry fails as missing-required-field (past-check '
        'skipped), past expiry fails as past-dated, future expiry passes, and '
        'item data is unchanged in every case', () {
      final bool held = forAll(
        (_ExpiryCase c) {
          final item = _buildItem(c);
          final String before = _snapshot(item);

          final String? expected = _oracleOutcome(c.kind);
          final String? actual = _actualOutcome(item);

          // (a) Outcome must match the oracle for this expiry category.
          //     For the null case this specifically asserts the code is
          //     MISSING_EXPIRY_DATE rather than EXPIRED_PRODUCT, proving the
          //     required-field check runs first and the past-check is
          //     skipped (R23.1, R23.2).
          if (actual != expected) return false;

          // (b) The item's unsaved data is never mutated by validation
          //     (R23.2, R23.3 retention obligations).
          if (_snapshot(item) != before) return false;

          return true;
        },
        [_caseGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'Every item must validate per its expiry category — null => '
            'MISSING_EXPIRY_DATE (past-check skipped), past => '
            'EXPIRED_PRODUCT, future => pass — with item data unchanged '
            '(Property 24 / Requirements 23.1–23.4).',
      );
    });

    // -- Deterministic anchors: pin the three mandated cases (R23.5) so the
    //    property is demonstrably non-vacuous. ----------------------------
    test('Property 24 anchors: null/past/future expiry produce the mandated '
        'outcomes and leave item data unchanged', () {
      final service = PharmacyValidationService();
      final now = DateTime.now();

      // Null expiry -> MISSING_EXPIRY_DATE, and NOT EXPIRED_PRODUCT.
      final nullItem = BillItem(
        productId: 'P1',
        productName: 'NullExpiryDrug',
        qty: 2,
        price: 50,
        batchNo: 'BATCH-1',
      );
      final nullBefore = _snapshot(nullItem);
      expect(
        () => service.validateBillItem(nullItem, BusinessType.pharmacy),
        throwsA(
          isA<PharmacyComplianceException>().having(
            (e) => e.code,
            'code',
            'MISSING_EXPIRY_DATE',
          ),
        ),
        reason: 'Null expiry must fail as a missing required field.',
      );
      expect(_snapshot(nullItem), nullBefore, reason: 'data unchanged');

      // Past expiry -> EXPIRED_PRODUCT.
      final pastItem = BillItem(
        productId: 'P2',
        productName: 'PastExpiryDrug',
        qty: 1,
        price: 10,
        batchNo: 'BATCH-2',
        expiryDate: now.subtract(const Duration(days: 1)),
      );
      final pastBefore = _snapshot(pastItem);
      expect(
        () => service.validateBillItem(pastItem, BusinessType.pharmacy),
        throwsA(
          isA<PharmacyComplianceException>().having(
            (e) => e.code,
            'code',
            'EXPIRED_PRODUCT',
          ),
        ),
        reason: 'Past expiry must fail as past-dated.',
      );
      expect(_snapshot(pastItem), pastBefore, reason: 'data unchanged');

      // Future expiry -> passes (no throw).
      final futureItem = BillItem(
        productId: 'P3',
        productName: 'FutureExpiryDrug',
        qty: 3,
        price: 99.5,
        batchNo: 'BATCH-3',
        expiryDate: now.add(const Duration(days: 365)),
      );
      final futureBefore = _snapshot(futureItem);
      expect(
        () => service.validateBillItem(futureItem, BusinessType.pharmacy),
        returnsNormally,
        reason: 'Current-or-future expiry must pass.',
      );
      expect(_snapshot(futureItem), futureBefore, reason: 'data unchanged');
    });
  });
}
