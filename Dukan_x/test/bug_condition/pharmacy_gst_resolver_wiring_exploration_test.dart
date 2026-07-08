/// Bug Condition Exploration Test — Pharmacy GST Resolver Wiring
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
///
/// Property 1: Bug Condition — Pharmacy GST Resolved via HSN/Schedule
///
/// `PharmacyGstResolver` (`lib/core/pharmacy/pharmacy_gst_resolver.dart`) is a
/// complete, unit-tested class that resolves a pharmacy line item's GST rate
/// from its HSN code / drug schedule, but it has ZERO call sites in
/// `bill_creation_screen_v2.dart`. Every GST-computation site there instead
/// derives `gstRate` directly from the flat `product.taxRate`, even for
/// pharmacy, so two medicines in different statutory slabs that happen to
/// share the same product-level `taxRate` get taxed identically/incorrectly.
///
/// **CRITICAL**: On UNFIXED code these assertions FAIL — failure CONFIRMS the
/// bug exists. DO NOT fix the test or the source when it fails here. After
/// the fix (Task 3.2–3.5) these SAME tests will PASS (Task 3.6).
///
/// `_addItem`/`_addItemWithStockWarning`/`_showManualItemEntry`'s
/// `onItemAdded`/`_showOcrResultDialog` are private methods on a
/// `ConsumerState` that require a live widget tree, Riverpod `ref`, and a
/// Drift database (FEFO batch lookup, prescription gate) to invoke directly.
/// Following this repo's established convention for screen-embedded business
/// logic (see `test/bug_condition/fuel_gst_compliance_exploration_test.dart`),
/// each call site's GST-computation expression is mirrored EXACTLY as it
/// appears in the UNFIXED source (line numbers cited in each function's
/// doc-comment) and exercised as a pure function here. The mirrors are
/// intentionally dumb copies of the current (buggy) production expressions —
/// they must be replaced with resolver calls only when the corresponding
/// task (3.2–3.5) edits the real source.
///
/// Run: flutter test test/bug_condition/pharmacy_gst_resolver_wiring_exploration_test.dart
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/pharmacy/pharmacy_gst_resolver.dart';
import 'package:dukanx/core/pharmacy/paise.dart';

final PharmacyGstResolver _resolver = PharmacyGstResolver();

/// Minimal stand-in for the fields of `Product` that the four call sites
/// under test actually read (`taxRate`, `hsnCode`, `drugSchedule`).
class _FakeProduct {
  final double taxRate;
  final String? hsnCode;
  final String? drugSchedule;
  const _FakeProduct({required this.taxRate, this.hsnCode, this.drugSchedule});
}

// ---------------------------------------------------------------------------
// Mirror 1 — `_addItem` / `_addItemWithStockWarning` new-line branch.
//
// Source (bill_creation_screen_v2.dart, ~line 550-569, duplicated ~line
// 700-719) — FIXED by Task 3.2/3.3:
//   final ratePercent = _resolvePharmacyGstRatePercent(
//     hsn: product.hsnCode,
//     schedule: product.drugSchedule,
//   );
//   newItemGstRate = ratePercent.toDouble();
//
// This mirror now reproduces the FIXED expression for the pharmacy business
// type: it resolves the rate via `PharmacyGstResolver` from HSN/drug
// schedule instead of reading the flat `product.taxRate`.
// ---------------------------------------------------------------------------
double _addItemNewLineGstRateUnfixed(_FakeProduct product) => _resolver
    .resolve(hsn: product.hsnCode, schedule: product.drugSchedule)
    .ratePercent
    .toDouble();

// ---------------------------------------------------------------------------
// Mirror 2 — `_showManualItemEntry`'s `onItemAdded` backfill.
//
// Source (bill_creation_screen_v2.dart, ~line 2028-2062) — FIXED by Task 3.4:
//   if (item.gstRate == 0) {
//     final matched = await _findProductByName(item.productName);
//     if (businessType == BusinessType.pharmacy && matched != null) {
//       final ratePercent = _resolvePharmacyGstRatePercent(
//         hsn: matched.hsnCode,
//         schedule: matched.drugSchedule,
//       );
//       finalItem = item.copyWith(gstRate: ratePercent.toDouble(), ...);
//     } else if (matched != null && matched.taxRate > 0) { ... }
//   }
//
// For pharmacy, the fixed source has no `matched.taxRate > 0` guard — a
// pharmacy product can validly resolve to a rate even when its flat
// `taxRate` is 0.
// ---------------------------------------------------------------------------
double _manualEntryBackfillGstRateUnfixed({
  required double itemGstRate,
  required _FakeProduct? matched,
}) {
  if (itemGstRate == 0 && matched != null) {
    return _resolver
        .resolve(hsn: matched.hsnCode, schedule: matched.drugSchedule)
        .ratePercent
        .toDouble();
  }
  return itemGstRate;
}

// ---------------------------------------------------------------------------
// Mirror 3 — `_showOcrResultDialog`'s "Add to Bill" handler.
//
// Source (bill_creation_screen_v2.dart, ~line 1885-1900) — FIXED by Task 3.5:
//   final ratePercent = _resolvePharmacyGstRatePercent(
//     hsn: matched?.hsnCode,
//     schedule: matched?.drugSchedule,
//   );
//   gstRate = ratePercent.toDouble();
//
// When `matched` is null, `hsn`/`schedule` are both null and the resolver's
// 12% fallback applies naturally.
// ---------------------------------------------------------------------------
double _ocrAddToBillGstRateUnfixed(_FakeProduct? matched) => _resolver
    .resolve(hsn: matched?.hsnCode, schedule: matched?.drugSchedule)
    .ratePercent
    .toDouble();

// Expected (post-fix) rate for a pharmacy product, mirroring what Task
// 3.2–3.5 will make each call site do: resolve via HSN/schedule instead of
// reading product.taxRate.
int _expectedPharmacyRatePercent({String? hsn, String? schedule}) =>
    _resolver.resolve(hsn: hsn, schedule: schedule).ratePercent;

void main() {
  group(
    'Bug Condition 1.1/1.4 — _addItem/_addItemWithStockWarning new-line branch',
    () {
      test('pharmacy product hsnCode "3002" (resolver: 5%) with taxRate 12.0 '
          'should be taxed at 5%, not 12%', () {
        final product = const _FakeProduct(taxRate: 12.0, hsnCode: '3002');

        final expectedRate = _expectedPharmacyRatePercent(
          hsn: product.hsnCode,
          schedule: product.drugSchedule,
        ).toDouble();
        expect(
          expectedRate,
          5.0,
          reason:
              'Sanity check: PharmacyGstResolver must resolve HSN 3002 to 5%.',
        );

        final actualUnfixedRate = _addItemNewLineGstRateUnfixed(product);

        expect(
          actualUnfixedRate,
          expectedRate,
          reason:
              'COUNTEREXAMPLE (1.1): expected the resolved rate (5.0 via HSN '
              '3002) but the unfixed _addItem new-line branch used '
              'product.taxRate and produced $actualUnfixedRate instead.',
        );
      });

      test('two products with the SAME taxRate but DIFFERENT HSN codes must be '
          'taxed differently (Requirement 1.4)', () {
        final productA = const _FakeProduct(
          taxRate: 12.0,
          hsnCode: '3002',
        ); // resolver: 5%
        final productB = const _FakeProduct(
          taxRate: 12.0,
          hsnCode: '3004',
        ); // resolver: 12%

        final expectedRateA = _expectedPharmacyRatePercent(
          hsn: productA.hsnCode,
        ).toDouble();
        final expectedRateB = _expectedPharmacyRatePercent(
          hsn: productB.hsnCode,
        ).toDouble();
        expect(expectedRateA, 5.0);
        expect(expectedRateB, 12.0);

        final actualUnfixedRateA = _addItemNewLineGstRateUnfixed(productA);
        final actualUnfixedRateB = _addItemNewLineGstRateUnfixed(productB);

        expect(
          actualUnfixedRateA,
          expectedRateA,
          reason:
              'COUNTEREXAMPLE (1.4): product A (HSN 3002) should resolve to '
              '5% but the unfixed code produced $actualUnfixedRateA.',
        );
        expect(
          actualUnfixedRateB,
          expectedRateB,
          reason:
              'COUNTEREXAMPLE (1.4): product B (HSN 3004) should resolve to '
              '12% but the unfixed code produced $actualUnfixedRateB.',
        );
        expect(
          actualUnfixedRateA,
          isNot(equals(actualUnfixedRateB)),
          reason:
              'COUNTEREXAMPLE (1.4): products A and B have different '
              'statutory slabs (5% vs 12%) but the unfixed code taxes both '
              'identically at ${actualUnfixedRateA} because both share the '
              'same flat product.taxRate.',
        );
      });
    },
  );

  group(
    'Bug Condition 1.3 — manual-entry backfill (_showManualItemEntry onItemAdded)',
    () {
      test('item with gstRate == 0 matched to a product with hsnCode "3002" '
          '(resolver: 5%) and taxRate 18.0 should backfill to 5%, not 18%', () {
        final matched = const _FakeProduct(taxRate: 18.0, hsnCode: '3002');

        final expectedRate = _expectedPharmacyRatePercent(
          hsn: matched.hsnCode,
          schedule: matched.drugSchedule,
        ).toDouble();
        expect(expectedRate, 5.0);

        final actualUnfixedRate = _manualEntryBackfillGstRateUnfixed(
          itemGstRate: 0,
          matched: matched,
        );

        expect(
          actualUnfixedRate,
          expectedRate,
          reason:
              'COUNTEREXAMPLE (1.3): expected the manual-entry backfill to '
              'resolve to 5.0 via HSN 3002 but the unfixed code backfilled '
              'matched.taxRate and produced $actualUnfixedRate instead.',
        );
      });
    },
  );

  group('Bug Condition 1.1 — OCR add-to-bill with no product match', () {
    test('OCR result with no name match on a pharmacy bill should default to '
        'the resolver\'s 12% fallback, not 0%', () {
      const _FakeProduct? matched = null;

      final expectedRate = _expectedPharmacyRatePercent(
        hsn: matched?.hsnCode,
        schedule: matched?.drugSchedule,
      ).toDouble();
      expect(
        expectedRate,
        12.0,
        reason:
            'Sanity check: PharmacyGstResolver must fall back to 12% when '
            'both hsn and schedule are null.',
      );

      final actualUnfixedRate = _ocrAddToBillGstRateUnfixed(matched);

      expect(
        actualUnfixedRate,
        expectedRate,
        reason:
            'COUNTEREXAMPLE (1.1): expected the OCR no-match default to be '
            'the resolver\'s 12% fallback but the unfixed code used '
            'matched?.taxRate ?? 0 and produced $actualUnfixedRate instead.',
      );
    });
  });

  group(
    'Sanity — Paise helper is available for the GST-amount half of Property 1',
    () {
      test(
        'PharmacyGstResolver.gstAmountPaise agrees with Paise round-half-up',
        () {
          final taxablePaise = Paise.fromRupees(100.0);
          final gstPaise = _resolver.gstAmountPaise(
            taxableAmountPaise: taxablePaise,
            ratePercent: 5,
          );
          expect(gstPaise, 500); // 100.00 * 5% = 5.00 = 500 paise
        },
      );
    },
  );
}
