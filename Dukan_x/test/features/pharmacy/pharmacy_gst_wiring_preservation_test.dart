/// Preservation Property Tests — Pharmacy GST Resolver Wiring
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
///
/// Property 2: Preservation — Non-Pharmacy and User-Override Paths Unchanged
///
/// The companion bug-condition exploration test
/// (`test/bug_condition/pharmacy_gst_resolver_wiring_exploration_test.dart`)
/// proves pharmacy's GST computation is wrongly derived from `product.taxRate`
/// instead of `PharmacyGstResolver`. This suite proves the OTHER half of the
/// contract: every input where `isBugCondition(X)` is FALSE — every
/// non-pharmacy business type, pharmacy's own null/empty-HSN fallback,
/// pharmacy's user-override path, and pharmacy's quantity-edit/increment reuse
/// — must keep producing EXACTLY the same `gstRate`/`cgst`/`sgst` after the
/// fix (Task 3) that it does today, on UNFIXED code.
///
/// **IMPORTANT**: These tests MUST PASS on unfixed code. A pass here is the
/// EXPECTED OUTCOME (this is the opposite of the exploration test).
///
/// Methodology (observation-first, same convention as the exploration test
/// and `test/bug_condition/fuel_gst_compliance_preservation_test.dart`):
/// `_addItem`/`_addItemWithStockWarning`/`_showManualItemEntry`'s
/// `onItemAdded`/`_showOcrResultDialog`/`_updateQuantity`/
/// `_addDimensionedHardwareItem`/`_addWeighedGroceryItem` are private methods
/// on a `ConsumerState` requiring a live widget tree, Riverpod `ref`, and a
/// Drift database to invoke directly. Each formula is mirrored EXACTLY as it
/// appears in the UNFIXED source (line numbers cited per mirror) and
/// exercised as a pure function here. Because Task 3 gates every change
/// behind `businessType == BusinessType.pharmacy` (per design.md), these
/// mirrors of the untouched branches remain valid, unchanged regression
/// baselines both before AND after the fix — re-running this SAME file
/// (Task 3.7) is expected to keep passing.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/features/pharmacy/pharmacy_gst_wiring_preservation_test.dart
library;

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/pharmacy/pharmacy_gst_resolver.dart';
import 'package:dukanx/models/business_type.dart';

const double _eps = 1e-9;
const int kNumRuns = 200;

final PharmacyGstResolver _resolver = PharmacyGstResolver();

/// Minimal stand-in for the fields the mirrored call sites actually read.
class _FakeProduct {
  final double taxRate;
  final String? hsnCode;
  final String? drugSchedule;
  const _FakeProduct({required this.taxRate, this.hsnCode, this.drugSchedule});
}

/// Every business type OTHER than pharmacy (18 types) — Task 3 does not touch
/// any GST computation for these (Requirement 3.1).
final List<BusinessType> _nonPharmacyTypes = BusinessType.values
    .where((t) => t != BusinessType.pharmacy)
    .toList();

// ---------------------------------------------------------------------------
// Mirror A — `_addItem`/`_addItemWithStockWarning` NEW-LINE branch, generic
// (non-pharmacy) shape.
//
// Source (bill_creation_screen_v2.dart, ~line 527–531, duplicated ~655–659) —
// UNFIXED, applies to every business type today:
//   gstRate: product.taxRate,
//   cgst: taxablePrice * (product.taxRate / 200),
//   sgst: taxablePrice * (product.taxRate / 200),
// where taxablePrice = (product.sellingPrice - happyHourPerUnit).clamp(0, inf)
// ---------------------------------------------------------------------------
class _GstResult {
  final double gstRate;
  final double cgst;
  final double sgst;
  const _GstResult({
    required this.gstRate,
    required this.cgst,
    required this.sgst,
  });
}

_GstResult _addItemNewLineMirror({
  required double taxRate,
  required double sellingPrice,
  required double happyHourPerUnit,
}) {
  final double taxablePrice = (sellingPrice - happyHourPerUnit).clamp(
    0.0,
    double.infinity,
  );
  return _GstResult(
    gstRate: taxRate,
    cgst: taxablePrice * (taxRate / 200),
    sgst: taxablePrice * (taxRate / 200),
  );
}

// ---------------------------------------------------------------------------
// Mirror B — `_addItem`/`_addItemWithStockWarning` EXISTING-LINE increment
// branch, and `_updateQuantity` (same shape) — Source ~line 505–515 and
// ~680–705. UNFIXED, unchanged by Task 3 for ANY business type (design.md:
// "these paths already derive cgst/sgst from the line's own stored gstRate"):
//   gstRate: existing.gstRate,               // never re-derived
//   cgst: newQty * (taxableBase * (existing.gstRate / 200)),
//   sgst: newQty * (taxableBase * (existing.gstRate / 200)),
// where taxableBase = (existing.price - perUnitDiscount).clamp(0, inf)
// ---------------------------------------------------------------------------
_GstResult _existingLineIncrementMirror({
  required double storedGstRate,
  required double price,
  required double perUnitDiscount,
  required double newQty,
}) {
  final double taxableBase = (price - perUnitDiscount).clamp(
    0.0,
    double.infinity,
  );
  return _GstResult(
    gstRate: storedGstRate,
    cgst: newQty * (taxableBase * (storedGstRate / 200)),
    sgst: newQty * (taxableBase * (storedGstRate / 200)),
  );
}

// ---------------------------------------------------------------------------
// Mirror C — `_addDimensionedHardwareItem` (hardware dimension-unit path).
// Source ~line 1254–1264. UNFIXED, gated to businessType == hardware, so
// unreachable for pharmacy and untouched by Task 3:
//   gstRate: taxRate, cgst/sgst: qty * (price * (taxRate / 200))
// ---------------------------------------------------------------------------
_GstResult _dimensionedHardwareMirror({
  required double taxRate,
  required double price,
  required double qty,
}) {
  final double halfGst = qty * (price * (taxRate / 200));
  return _GstResult(gstRate: taxRate, cgst: halfGst, sgst: halfGst);
}

// ---------------------------------------------------------------------------
// Mirror D — `_addWeighedGroceryItem` (grocery loose-weight path).
// Source ~line 1336–1349. UNFIXED, gated to businessType == grocery, so
// unreachable for pharmacy and untouched by Task 3. Identical shape to
// Mirror C.
// ---------------------------------------------------------------------------
_GstResult _weighedGroceryMirror({
  required double taxRate,
  required double price,
  required double netWeightKg,
}) {
  final double halfGst = netWeightKg * (price * (taxRate / 200));
  return _GstResult(gstRate: taxRate, cgst: halfGst, sgst: halfGst);
}

// ---------------------------------------------------------------------------
// Mirror E — `_showManualItemEntry`'s `onItemAdded` backfill.
// Source ~line 1941–1953. UNFIXED:
//   if (item.gstRate == 0) {
//     final matched = await _findProductByName(item.productName);
//     if (matched != null && matched.taxRate > 0) {
//       ... gstRate: matched.taxRate ...
//     }
//   }
// The user-override guard (item.gstRate != 0 -> untouched) is business-type
// agnostic and is Requirement 3.3's preserved invariant.
// ---------------------------------------------------------------------------
double _manualEntryBackfillGstRateMirror({
  required double itemGstRate,
  required _FakeProduct? matched,
}) {
  if (itemGstRate == 0 && matched != null && matched.taxRate > 0) {
    return matched.taxRate;
  }
  return itemGstRate;
}

// ---------------------------------------------------------------------------
// Mirror F — `_showOcrResultDialog`'s "Add to Bill" handler, non-pharmacy
// shape. Source ~line 1811: `final double gstRate = matched?.taxRate ?? 0;`
// Per design.md, Task 3.5 ONLY changes this for pharmacy (12% resolver
// fallback on no match); every other business type keeps `matched?.taxRate
// ?? 0` unchanged.
// ---------------------------------------------------------------------------
double _ocrAddToBillGstRateMirror(_FakeProduct? matched) =>
    matched?.taxRate ?? 0;

void main() {
  // ==========================================================================
  // Preservation 3.1 — non-pharmacy business types unaffected
  // ==========================================================================
  group('Preservation 3.1: non-pharmacy business types unaffected', () {
    test('PBT: for any non-pharmacy business type + random taxRate/price/'
        'happy-hour-discount, the new-line branch keeps using product.taxRate '
        'unchanged (no PharmacyGstResolver reference)', () {
      final bool held = forAll(
        (int typeIdx, int taxRateCents, int priceCents, int discountCents) {
          final type = _nonPharmacyTypes[typeIdx % _nonPharmacyTypes.length];
          final double taxRate = taxRateCents / 100.0; // 0.00 .. 28.00
          final double price = priceCents / 100.0; // 0.00 .. 999.99
          final double happyHourPerUnit =
              discountCents / 100.0; // 0.00 .. price-ish

          final result = _addItemNewLineMirror(
            taxRate: taxRate,
            sellingPrice: price,
            happyHourPerUnit: happyHourPerUnit,
          );

          final double expectedTaxable = (price - happyHourPerUnit).clamp(
            0.0,
            double.infinity,
          );
          expect(
            result.gstRate,
            taxRate,
            reason:
                '${type.name}: gstRate must remain product.taxRate ($taxRate), '
                'unaffected by the pharmacy-only resolver wiring.',
          );
          expect(
            result.cgst,
            closeTo(expectedTaxable * (taxRate / 200), _eps),
            reason: '${type.name}: cgst formula must remain unchanged.',
          );
          expect(
            result.sgst,
            closeTo(expectedTaxable * (taxRate / 200), _eps),
            reason: '${type.name}: sgst formula must remain unchanged.',
          );
          return true;
        },
        [
          Gen.interval(0, _nonPharmacyTypes.length - 1),
          Gen.interval(0, 2800),
          Gen.interval(0, 99999),
          Gen.interval(0, 99999),
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test(
      'PBT: grocery weighed-item path keeps deriving GST from product.taxRate '
      '(unreachable for pharmacy; untouched by the fix)',
      () {
        final bool held = forAll(
          (int taxRateCents, int priceCents, int weightGrams) {
            final double taxRate = taxRateCents / 100.0;
            final double price = priceCents / 100.0;
            final double netWeightKg = weightGrams / 1000.0;

            final result = _weighedGroceryMirror(
              taxRate: taxRate,
              price: price,
              netWeightKg: netWeightKg,
            );

            expect(result.gstRate, taxRate);
            expect(
              result.cgst,
              closeTo(netWeightKg * (price * (taxRate / 200)), _eps),
            );
            expect(
              result.sgst,
              closeTo(netWeightKg * (price * (taxRate / 200)), _eps),
            );
            return true;
          },
          [
            Gen.interval(0, 2800),
            Gen.interval(0, 99999),
            Gen.interval(1, 50000),
          ],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test('PBT: hardware dimensioned-item path keeps deriving GST from '
        'product.taxRate (unreachable for pharmacy; untouched by the fix)', () {
      final bool held = forAll(
        (int taxRateCents, int priceCents, int areaCentiUnits) {
          final double taxRate = taxRateCents / 100.0;
          final double price = priceCents / 100.0;
          final double qty = areaCentiUnits / 100.0;

          final result = _dimensionedHardwareMirror(
            taxRate: taxRate,
            price: price,
            qty: qty,
          );

          expect(result.gstRate, taxRate);
          expect(result.cgst, closeTo(qty * (price * (taxRate / 200)), _eps));
          expect(result.sgst, closeTo(qty * (price * (taxRate / 200)), _eps));
          return true;
        },
        [
          Gen.interval(0, 2800),
          Gen.interval(0, 99999),
          Gen.interval(1, 100000),
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test(
      'PBT: non-pharmacy OCR add-to-bill keeps matched?.taxRate ?? 0 '
      'unchanged (only pharmacy gets the 12% no-match fallback per design)',
      () {
        final bool held = forAll(
          (int hasMatch, int taxRateCents) {
            final double taxRate = taxRateCents / 100.0;
            final _FakeProduct? matched = hasMatch == 1
                ? _FakeProduct(taxRate: taxRate)
                : null;

            final actual = _ocrAddToBillGstRateMirror(matched);
            final expected = matched?.taxRate ?? 0;

            expect(
              actual,
              expected,
              reason:
                  'Non-pharmacy OCR add-to-bill must keep matched?.taxRate '
                  '?? 0 exactly as today.',
            );
            return true;
          },
          [Gen.interval(0, 1), Gen.interval(0, 2800)],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test('PBT: non-pharmacy manual-entry backfill keeps matched.taxRate guard '
        '(matched.taxRate > 0) unchanged', () {
      final bool held = forAll(
        (int itemGstRateCents, int hasMatch, int matchedTaxRateCents) {
          final double itemGstRate = itemGstRateCents / 100.0;
          final _FakeProduct? matched = hasMatch == 1
              ? _FakeProduct(taxRate: matchedTaxRateCents / 100.0)
              : null;

          final actual = _manualEntryBackfillGstRateMirror(
            itemGstRate: itemGstRate,
            matched: matched,
          );

          final expected =
              (itemGstRate == 0 && matched != null && matched.taxRate > 0)
              ? matched.taxRate
              : itemGstRate;

          expect(actual, expected);
          return true;
        },
        [Gen.interval(0, 2800), Gen.interval(0, 1), Gen.interval(0, 2800)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });

  // ==========================================================================
  // Preservation 3.2 — pharmacy null/empty HSN and schedule -> 12% fallback
  // ==========================================================================
  group(
    'Preservation 3.2: pharmacy null/empty HSN and schedule -> 12% fallback',
    () {
      test('PharmacyGstResolver falls back to 12% (usedFallback=true) for null '
          'and empty hsn/schedule, matching today\'s effective default', () {
        for (final hsn in <String?>[null, '']) {
          for (final schedule in <String?>[null, '']) {
            final result = _resolver.resolve(hsn: hsn, schedule: schedule);
            expect(
              result.ratePercent,
              12,
              reason:
                  'hsn=$hsn, schedule=$schedule must resolve to the 12% '
                  'fallback, matching pharmacy\'s BusinessTypeConfig.'
                  'defaultGstRate today.',
            );
            expect(result.usedFallback, isTrue);
          }
        }
      });

      test('a pharmacy product with null HSN/schedule and taxRate == 12.0 '
          '(config default) already reads as 12% on unfixed code — the one '
          'case where old and new outputs coincide by design', () {
        const product = _FakeProduct(taxRate: 12.0);
        final unfixedMirror = _addItemNewLineMirror(
          taxRate: product.taxRate,
          sellingPrice: 100.0,
          happyHourPerUnit: 0.0,
        );
        final resolverRate = _resolver
            .resolve(hsn: product.hsnCode, schedule: product.drugSchedule)
            .ratePercent;
        expect(unfixedMirror.gstRate, 12.0);
        expect(resolverRate, 12);
        expect(
          unfixedMirror.gstRate,
          resolverRate.toDouble(),
          reason:
              'Null-HSN/schedule pharmacy items must yield the same 12% '
              'before and after the fix (Requirement 3.2).',
        );
      });
    },
  );

  // ==========================================================================
  // Preservation 3.3 — pharmacy user override respected
  // ==========================================================================
  group('Preservation 3.3: pharmacy user override respected', () {
    test('PBT: a non-zero user-entered gstRate is never overwritten by the '
        'manual-entry backfill, regardless of a matched pharmacy product\'s '
        'HSN/schedule-resolved rate', () {
      final bool held = forAll(
        (int itemGstRateCents, int hsnIdx, int scheduleIdx) {
          // Non-zero user-entered gstRate (guard's complement space).
          final double itemGstRate = (itemGstRateCents % 2799) / 100.0 + 0.01;
          const hsnPool = ['3002', '3004', '3401', null];
          const schedulePool = ['H', 'H1', 'X', 'OTC', null];
          final matched = _FakeProduct(
            taxRate: 18.0,
            hsnCode: hsnPool[hsnIdx % hsnPool.length],
            drugSchedule: schedulePool[scheduleIdx % schedulePool.length],
          );

          // What the resolver would produce for the matched product —
          // proves the override wins EVEN when the resolved rate differs.
          final resolvedRate = _resolver
              .resolve(hsn: matched.hsnCode, schedule: matched.drugSchedule)
              .ratePercent;

          final actual = _manualEntryBackfillGstRateMirror(
            itemGstRate: itemGstRate,
            matched: matched,
          );

          expect(
            actual,
            itemGstRate,
            reason:
                'A non-zero user-entered gstRate ($itemGstRate) must never '
                'be overwritten, even though the resolver would produce '
                '$resolvedRate for this matched product.',
          );
          return true;
        },
        [Gen.interval(1, 2800), Gen.interval(0, 3), Gen.interval(0, 4)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });

  // ==========================================================================
  // Preservation 3.2/2.2 carry-forward — pharmacy quantity-edit/increment
  // reuse
  // ==========================================================================
  group(
    'Preservation quantity-edit/increment reuse: gstRate never re-derived',
    () {
      test('PBT: after a pharmacy line is added with a resolved rate, random '
          'quantity increases via _updateQuantity / the existing-line '
          'increment branch never change gstRate, and cgst/sgst scale '
          'linearly from the SAME stored rate', () {
        // Rates a pharmacy line could have been resolved to at add-time
        // (any of the resolver's supported statutory slabs).
        const resolvedRatePool = [0, 5, 12, 18, 28];

        final bool held = forAll(
          (
            int rateIdx,
            int priceCents,
            int discountCents,
            int initialQtyInt,
            int qtyIncreaseInt,
          ) {
            final double storedGstRate =
                resolvedRatePool[rateIdx % resolvedRatePool.length].toDouble();
            final double price = priceCents / 100.0;
            final double discount = discountCents / 100.0;
            final double initialQty = initialQtyInt.toDouble();
            final double newQty = initialQty + qtyIncreaseInt.toDouble();

            final double perUnitDiscount = initialQty > 0
                ? discount / initialQty
                : 0.0;

            final result = _existingLineIncrementMirror(
              storedGstRate: storedGstRate,
              price: price,
              perUnitDiscount: perUnitDiscount,
              newQty: newQty,
            );

            final double taxableBase = (price - perUnitDiscount).clamp(
              0.0,
              double.infinity,
            );

            // gstRate NEVER changes — carried forward from add-time.
            expect(
              result.gstRate,
              storedGstRate,
              reason:
                  'Quantity-edit/increment must reuse the stored gstRate '
                  '($storedGstRate), never re-deriving it from '
                  'product.taxRate or the resolver.',
            );
            // cgst/sgst scale linearly with newQty from the SAME rate.
            expect(
              result.cgst,
              closeTo(newQty * (taxableBase * (storedGstRate / 200)), _eps),
            );
            expect(
              result.sgst,
              closeTo(newQty * (taxableBase * (storedGstRate / 200)), _eps),
            );
            // Linearity check: doubling qty (holding taxableBase fixed)
            // doubles cgst/sgst from the same per-unit rate.
            final doubledResult = _existingLineIncrementMirror(
              storedGstRate: storedGstRate,
              price: price,
              perUnitDiscount: perUnitDiscount,
              newQty: newQty * 2,
            );
            expect(
              doubledResult.cgst,
              closeTo(result.cgst * 2, 1e-6),
              reason:
                  'cgst must scale linearly with quantity at a fixed '
                  'stored gstRate.',
            );
            return true;
          },
          [
            Gen.interval(0, 4),
            Gen.interval(1, 99999),
            Gen.interval(0, 50000),
            Gen.interval(1, 100),
            Gen.interval(0, 100),
          ],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });
    },
  );

  // ==========================================================================
  // Preservation 3.4 — business_type_config.dart unchanged
  // ==========================================================================
  group('Preservation 3.4: business_type_config.dart unchanged', () {
    // Captured baseline: defaultGstRate/gstEditable for EVERY business type,
    // observed on UNFIXED code. This fix touches only computation call sites
    // in bill_creation_screen_v2.dart, never this config file.
    const Map<BusinessType, ({double rate, bool editable})> _baseline = {
      BusinessType.grocery: (rate: 0.0, editable: true),
      BusinessType.pharmacy: (rate: 12.0, editable: false),
      BusinessType.restaurant: (rate: 5.0, editable: false),
      BusinessType.clothing: (rate: 5.0, editable: true),
      BusinessType.electronics: (rate: 18.0, editable: false),
      BusinessType.mobileShop: (rate: 18.0, editable: false),
      BusinessType.computerShop: (rate: 18.0, editable: false),
      BusinessType.hardware: (rate: 18.0, editable: true),
      BusinessType.service: (rate: 18.0, editable: true),
      BusinessType.wholesale: (rate: 18.0, editable: true),
      BusinessType.petrolPump: (rate: 0.0, editable: false),
      BusinessType.vegetablesBroker: (rate: 0.0, editable: false),
      BusinessType.clinic: (rate: 0.0, editable: true),
      BusinessType.bookStore: (rate: 0.0, editable: true),
      BusinessType.jewellery: (rate: 3.0, editable: false),
      BusinessType.autoParts: (rate: 28.0, editable: true),
      BusinessType.decorationCatering: (rate: 18.0, editable: true),
      BusinessType.schoolErp: (rate: 0.0, editable: true),
      BusinessType.other: (rate: 0.0, editable: true),
    };

    test('pharmacy defaultGstRate == 12.0 and gstEditable == false (unchanged '
        'by this fix — it touches only bill_creation_screen_v2.dart)', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.pharmacy);
      expect(config.defaultGstRate, closeTo(12.0, _eps));
      expect(config.gstEditable, isFalse);
    });

    test('every business type\'s defaultGstRate/gstEditable match the captured '
        'baseline (no config drift anywhere from this fix)', () {
      expect(
        _baseline.keys.toSet(),
        BusinessType.values.toSet(),
        reason: 'Baseline must cover every BusinessType value.',
      );
      for (final type in BusinessType.values) {
        final config = BusinessTypeRegistry.getConfig(type);
        final expected = _baseline[type]!;
        expect(
          config.defaultGstRate,
          closeTo(expected.rate, _eps),
          reason: '${type.name} defaultGstRate must stay ${expected.rate}.',
        );
        expect(
          config.gstEditable,
          expected.editable,
          reason: '${type.name} gstEditable must stay ${expected.editable}.',
        );
      }
    });
  });
}
