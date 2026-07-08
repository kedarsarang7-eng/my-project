# Implementation Plan

## Overview

Scope: wiring `PharmacyGstResolver` into the four GST-computation call sites in `BillCreationScreenV2` for `BusinessType.pharmacy` **only** — `_addItem`'s new-line branch, `_addItemWithStockWarning`'s new-line branch, `_showManualItemEntry`'s `onItemAdded` backfill, and `_showOcrResultDialog`'s "Add to Bill" handler. No task may alter GST computation for any of the other 17 business types, or any pharmacy path that does not derive `gstRate` from `product.taxRate` (quantity-edit/increment recompute, user-entered overrides, `business_type_config.dart`'s `defaultGstRate`/`gstEditable`).

Testing mandate: write the bug-condition exploration test and the preservation property tests FIRST, run both on UNFIXED code (exploration FAILS, preservation PASSES), then implement the fix, then re-run the same tests unchanged to confirm the fix resolves the bug and introduces no regressions.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "description": "Failing-first exploration test and observation-first preservation tests, written and run on UNFIXED code before any fix",
      "tasks": ["1", "2"]
    },
    {
      "wave": 2,
      "description": "Shared resolver instance and helper methods (foundational; the four call-site fixes build on this)",
      "tasks": ["3.1"]
    },
    {
      "wave": 3,
      "description": "Independent call-site fixes, each wiring the shared helpers from 3.1 into one GST-computation site",
      "tasks": ["3.2", "3.3", "3.4", "3.5"]
    },
    {
      "wave": 4,
      "description": "Re-run the same tests to confirm the bug is fixed and no regressions were introduced",
      "tasks": ["3.6", "3.7"]
    },
    {
      "wave": 5,
      "description": "Final checkpoint - full suite green",
      "tasks": ["4"]
    }
  ]
}
```

## Tasks

- [x] 1. Write bug condition exploration test (BEFORE implementing the fix)
  - **Property 1: Bug Condition** - Pharmacy GST Resolved via HSN/Schedule
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails at this stage**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples showing pharmacy `gstRate` is derived from `product.taxRate` instead of `PharmacyGstResolver.resolve(hsn, schedule)`
  - **Scoped PBT Approach**: These are deterministic defects at four call sites — scope the property to concrete failing cases (specific HSN/`taxRate` mismatches) for reproducibility, per design's Bug Condition: `isBugCondition(X)` is true when `X.businessType == BusinessType.pharmacy AND X.gstRateSource == 'product.taxRate'`
  - Write the following exploration assertions against `lib/features/billing/presentation/screens/bill_creation_screen_v2.dart` (run all on UNFIXED code):
    - **`_addItem`/`_addItemWithStockWarning` new-line branch**: quick-add a pharmacy product with `hsnCode: '3002'` (resolver: 5%) and `taxRate: 12.0`; assert the resulting `BillItem.gstRate` equals `5.0` — fails on unfixed code because it equals `12.0`
    - **Two same-`taxRate`, different-HSN products taxed identically** (Requirement 1.4): quick-add Product A (`hsnCode: '3002'`, `taxRate: 12.0`) and Product B (`hsnCode: '3004'`, `taxRate: 12.0`); assert A's `gstRate == 5.0` and B's `gstRate == 12.0` (different) — fails on unfixed code because both are `12.0` (identical)
    - **Manual-entry backfill** (`_showManualItemEntry`'s `onItemAdded`): an item with `gstRate == 0` whose name matches a product with `hsnCode: '3002'`, `taxRate: 18.0`; assert the backfilled `gstRate == 5.0` — fails on unfixed code because it backfills `18.0` (`matched.taxRate`)
    - **OCR add-to-bill with no product match** (`_showOcrResultDialog`): an OCR result with no name match for a pharmacy bill; assert `gstRate == 12.0` (resolver's fallback) — fails on unfixed code because it is `0` (`matched?.taxRate ?? 0`)
  - Run the tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g. `gstRate == 12.0` instead of `5.0` for HSN `'3002'`; both same-`taxRate` products taxed identically instead of 5%/12%; manual-entry backfill uses `18.0` instead of `5.0`; OCR no-match defaults to `0` instead of `12.0`)
  - Mark task complete when the test is written, run, and failures are documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Write preservation property tests (BEFORE implementing the fix)
  - **Property 2: Preservation** - Non-Pharmacy and User-Override Paths Unchanged
  - **IMPORTANT**: Follow observation-first methodology - run UNFIXED code for non-buggy inputs (`isBugCondition == false`), record actual outputs, then write property-based tests asserting those exact outputs
  - **Why property-based**: the non-pharmacy input space spans 17 other business types × arbitrary `taxRate`/qty/discount combinations, and pharmacy's own preserved sub-cases (null/empty HSN+schedule, user override, quantity-edit reuse) are easy to under-test by hand; generating many combinations catches edge cases manual examples would miss
  - Observe and capture on UNFIXED code, then write property-based tests asserting:
    - **Non-pharmacy business types unaffected**: for each of the 17 non-pharmacy types (and grocery/hardware's weighed/dimensioned paths), generate random `taxRate`/qty/discount and assert `gstRate`/`cgst`/`sgst` match the pre-fix `product.taxRate`-based formula exactly (Requirement 3.1)
    - **Pharmacy null/empty HSN and schedule → 12% fallback**: generate pharmacy products with `hsnCode: null`/`''` and `drugSchedule: null`/`''` and assert the rate is `12.0`, matching today's effective default (Requirement 3.2)
    - **Pharmacy user override respected**: generate a manually entered pharmacy `BillItem` with a non-zero `gstRate` and assert the manual-entry backfill never overwrites it, regardless of what a name-matched product's HSN/schedule would resolve to (Requirement 3.3)
    - **Pharmacy quantity-edit/increment reuse**: after a pharmacy line is added, generate random quantity increases via `_updateQuantity` and the existing-line increment branch, and assert `gstRate` never changes and `cgst`/`sgst` scale linearly from the same stored rate (Requirement 3.2/2.2 carry-forward)
    - **`business_type_config.dart` unchanged**: assert `BusinessTypeConfig.pharmacy.defaultGstRate == 12.0` and `gstEditable == false`, and every other business type's config, are unchanged (Requirement 3.4)
  - Run the tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms the baseline behavior to preserve)
  - Mark task complete when the tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 3. Fix - wire PharmacyGstResolver into the four GST-computation call sites

  - [x] 3.1 Add shared resolver instance and private helper methods
    - In `lib/features/billing/presentation/screens/bill_creation_screen_v2.dart`, add `import '../../../../core/pharmacy/pharmacy_gst_resolver.dart';` (`Paise` is already imported)
    - Add `static final PharmacyGstResolver _pharmacyGstResolver = PharmacyGstResolver();` on `_BillCreationScreenV2State`
    - Add `int _resolvePharmacyGstRatePercent({String? hsn, String? schedule}) => _pharmacyGstResolver.resolve(hsn: hsn, schedule: schedule).ratePercent;`
    - Add `double _pharmacyGstAmountRupees({required double taxableAmountRupees, required int ratePercent})` that converts to paise via `Paise.fromRupees`, calls `_pharmacyGstResolver.gstAmountPaise(...)`, and converts back to rupees (`/ 100.0`)
    - These two helpers centralize the resolver call and integer-paise amount math so all four call sites share one implementation instead of duplicating `PharmacyGstResolver()` construction and paise conversion
    - No behavior change yet — these are unused additions until 3.2–3.5 wire them in
    - _Bug_Condition: isBugCondition(X) where X.businessType = BusinessType.pharmacy AND X.gstRateSource = 'product.taxRate' (from Bug Details in design)_
    - _Requirements: 2.1, 2.4, 2.5_

  - [x] 3.2 Wire resolver into `_addItem`'s new-line branch
    - In the new-line `_items.add(BillItem(...))` block (~line 527–531), when `businessType == BusinessType.pharmacy`: resolve `ratePercent = _resolvePharmacyGstRatePercent(hsn: product.hsnCode, schedule: product.drugSchedule)`, use it for `gstRate`, and compute `cgst`/`sgst` by splitting `_pharmacyGstAmountRupees(taxableAmountRupees: taxablePrice, ratePercent: ratePercent)` evenly
    - For any other business type, keep the existing `product.taxRate`-based three lines (`gstRate: product.taxRate`, `cgst`/`sgst` from `product.taxRate / 200`) byte-for-byte unchanged
    - The existing-line increment branch (~line 505–515) is unchanged — it already derives `cgst`/`sgst` from `existing.gstRate`, so it automatically carries the resolved rate forward once this branch stores it correctly
    - _Bug_Condition: isBugCondition(X) where X.businessType = BusinessType.pharmacy AND X.gstRateSource = 'product.taxRate' at the _addItem new-line site_
    - _Expected_Behavior: gstRate = PharmacyGstResolver.resolve(hsn: product.hsnCode, schedule: product.drugSchedule).ratePercent; cgst+sgst = resolver's gstAmountPaise converted to rupees (Property 1 in design)_
    - _Preservation: non-pharmacy business types keep using product.taxRate unchanged (Property 2 in design)_
    - _Requirements: 2.1, 2.4, 2.5, 3.1, 3.2, 3.4_

  - [x] 3.3 Wire resolver into `_addItemWithStockWarning`'s new-line branch
    - Apply the identical change from 3.2 to `_addItemWithStockWarning`'s new-line `_items.add(BillItem(...))` block (~line 655–659), which duplicates `_addItem`'s add-line-item logic verbatim
    - The existing-line increment branch in this function is unchanged for the same reason as 3.2
    - _Bug_Condition: isBugCondition(X) where X.businessType = BusinessType.pharmacy AND X.gstRateSource = 'product.taxRate' at the _addItemWithStockWarning new-line site_
    - _Expected_Behavior: gstRate = PharmacyGstResolver.resolve(hsn: product.hsnCode, schedule: product.drugSchedule).ratePercent; cgst+sgst = resolver's gstAmountPaise converted to rupees (Property 1 in design)_
    - _Preservation: non-pharmacy business types keep using product.taxRate unchanged (Property 2 in design)_
    - _Requirements: 2.1, 2.4, 2.5, 3.1, 3.2, 3.4_

  - [x] 3.4 Wire resolver into `_showManualItemEntry`'s `onItemAdded` backfill
    - In the `onItemAdded` callback's `if (item.gstRate == 0) { final matched = await _findProductByName(item.productName); ... }` block (~line 1941–1953): keep the outer `item.gstRate == 0` guard exactly as-is (preserves the user-override requirement)
    - When `businessType == BusinessType.pharmacy` and `matched != null` (no `matched.taxRate > 0` guard — a pharmacy product can validly resolve to a rate even when `matched.taxRate` is 0): compute `ratePercent = _resolvePharmacyGstRatePercent(hsn: matched.hsnCode, schedule: matched.drugSchedule)`, set `gstRate: ratePercent`, and compute `cgst`/`sgst` via `_pharmacyGstAmountRupees` using the discount-adjusted `taxableBase`
    - For non-pharmacy, keep the existing `matched.taxRate > 0` guard and `matched.taxRate`-based backfill unchanged
    - _Bug_Condition: isBugCondition(X) where X.businessType = BusinessType.pharmacy AND X.gstRateSource = 'product.taxRate' at the manual-entry backfill site_
    - _Expected_Behavior: gstRate = PharmacyGstResolver.resolve(hsn: matched.hsnCode, schedule: matched.drugSchedule).ratePercent; cgst+sgst = resolver's gstAmountPaise converted to rupees (Property 1 in design)_
    - _Preservation: item.gstRate != 0 (user override) is never overwritten; non-pharmacy backfill unchanged (Property 2 in design)_
    - _Requirements: 2.1, 2.3, 2.4, 2.5, 3.1, 3.3, 3.4_

  - [x] 3.5 Wire resolver into `_showOcrResultDialog`'s "Add to Bill" handler
    - Replace `final double gstRate = matched?.taxRate ?? 0;` (~line 1811) with: when the active `businessType == BusinessType.pharmacy`, compute `ratePercent = _resolvePharmacyGstRatePercent(hsn: matched?.hsnCode, schedule: matched?.drugSchedule)` (naturally falls back to the resolver's 12% default when `matched` is null, since both `hsn` and `schedule` are then null); use `_pharmacyGstAmountRupees` for `halfGst`
    - For non-pharmacy, keep `matched?.taxRate ?? 0` unchanged
    - This intentionally changes the OCR no-match default from `0%` to the resolver's `12%` fallback for pharmacy only (per design: pharmacy's config-level fallback has always been 12%, never 0%)
    - _Bug_Condition: isBugCondition(X) where X.businessType = BusinessType.pharmacy AND X.gstRateSource = 'product.taxRate' at the OCR add-to-bill site_
    - _Expected_Behavior: gstRate = PharmacyGstResolver.resolve(hsn: matched?.hsnCode, schedule: matched?.drugSchedule).ratePercent (12% fallback when matched is null); cgst+sgst = resolver's gstAmountPaise converted to rupees (Property 1 in design)_
    - _Preservation: non-pharmacy OCR add-to-bill keeps matched?.taxRate ?? 0 unchanged (Property 2 in design)_
    - _Requirements: 2.1, 2.4, 2.5, 3.1, 3.2, 3.4_

  - [x] 3.6 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Pharmacy GST Resolved via HSN/Schedule
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior; passing confirms the bug is fixed at all four call sites
    - Run the bug condition exploration test from task 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms the bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 3.7 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Pharmacy and User-Override Paths Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run the preservation property tests from task 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions for non-pharmacy business types, user overrides, quantity-edit reuse, null-HSN fallback, and `business_type_config.dart`)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 4. Checkpoint - ensure all tests pass
  - Run the full test suite (exploration test from task 1, preservation tests from task 2, plus any existing `PharmacyGstResolver` unit tests) and confirm everything is green
  - Ask the user if questions arise

## Notes

- Follow the observation-first, exploration-first methodology strictly: tasks 1 and 2 MUST be written and run against UNFIXED code before any line in task 3 is touched.
- Task 1's exploration test is expected to FAIL on unfixed code — do not modify the test or the source to force a pass at that stage; a failure confirms the bug exists.
- Task 2's preservation tests are expected to PASS on unfixed code — they capture the baseline behavior (non-pharmacy business types, null/empty HSN fallback, user overrides, quantity-edit reuse, and `business_type_config.dart`) that must remain unchanged after the fix.
- The fix in task 3 is scoped exclusively to the four pharmacy GST call sites in `bill_creation_screen_v2.dart` listed in the Overview above. Do not modify GST logic for any other business type or any pharmacy path that doesn't derive `gstRate` from `product.taxRate`.
- Tasks 3.6 and 3.7 MUST re-run the exact same tests written in tasks 1 and 2 — do not author new tests for verification.
- If either the exploration test still fails after the fix, or a preservation test regresses, stop and re-examine the root cause in `design.md` before making further changes.
