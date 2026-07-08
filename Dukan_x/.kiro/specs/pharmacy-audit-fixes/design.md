# Pharmacy GST Resolver Wiring — Bugfix Design

## Overview

`PharmacyGstResolver` (`lib/core/pharmacy/pharmacy_gst_resolver.dart`) is a complete, unit-tested class that resolves the correct statutory GST rate for a pharmacy line item from its HSN code and/or drug schedule (HSN match → schedule match → 12% fallback, `usedFallback` flag), and computes the GST amount in integer paise with round-half-up via the shared `Paise` helper. It has zero call sites in production code.

`BillCreationScreenV2` (`lib/features/billing/presentation/screens/bill_creation_screen_v2.dart`) instead derives `gstRate`/`cgst`/`sgst` directly from the flat `product.taxRate` at every GST-computation site, for every business type including pharmacy. Because pharmacy's `BusinessTypeConfig.defaultGstRate` is a single fixed 12% and `product.taxRate` is one number per product, two medicines that legitimately sit in different statutory slabs (e.g. a 5%-slab life-saving drug and a 12%-slab standard formulation) get taxed identically if their product-level `taxRate` happens to match.

The fix wires `PharmacyGstResolver` into the pharmacy-only branches of every GST-computation call site in `BillCreationScreenV2`:
- quick-add / barcode-and-search add (`_addItem`, `_addItemWithStockWarning`)
- manual-entry backfill (`_showManualItemEntry`'s `onItemAdded` callback)
- OCR ad-hoc add-to-bill (`_showOcrResultDialog`'s "Add to Bill" handler)

Two new private helper methods centralize the resolver call and the integer-paise GST amount calculation so the four call sites (which currently duplicate the same `product.taxRate` logic) share one implementation. All four call sites gate the new logic behind `businessType == BusinessType.pharmacy`; every other branch — and all 18 other business types — keeps executing the exact `product.taxRate` code path it uses today. Quantity-edit recompute (`_updateQuantity`) and the existing-line increment branches inside `_addItem`/`_addItemWithStockWarning` already reuse the line's stored `gstRate` rather than re-deriving it from `product.taxRate`, so once the add-time rate is correctly resolved, those paths automatically carry the resolved rate forward with no code change.

## Glossary

- **Bug_Condition (C)**: `businessType == BusinessType.pharmacy AND gstRateSource == 'product.taxRate'` — a pharmacy GST computation is about to be (or was) derived from the flat product tax rate instead of `PharmacyGstResolver`.
- **Property (P)**: The resolved GST rate/amount for a bug-condition input SHALL equal `PharmacyGstResolver.resolve(...)`'s rate and `PharmacyGstResolver.gstAmountPaise(...)`'s amount for the same taxable base.
- **Preservation**: The exact `gstRate`/`cgst`/`sgst` values every non-pharmacy business type, and every pharmacy user-override / already-resolved-rate path, produces today must be bit-for-bit identical after the fix.
- **`PharmacyGstResolver`**: `lib/core/pharmacy/pharmacy_gst_resolver.dart` — resolves `{hsn, schedule} → GstResolution(ratePercent, usedFallback)` and computes GST in integer paise.
- **`GstResolution`**: Value object returned by `resolve()`; `ratePercent` ∈ {0,5,12,18,28}, `usedFallback` is true when nothing matched and the 12% default applied.
- **`Paise`**: `lib/core/pharmacy/paise.dart` — integer-paise money helper (`fromRupees`, `roundHalfUp`, `toDisplay`); all pharmacy money math must route through it for round-half-up consistency.
- **`gstRateSource`**: Conceptual provenance tag (not a real field) distinguishing "derived from `product.taxRate`" vs. "resolved via `PharmacyGstResolver`" vs. "user-entered override" vs. "carried forward from an already-resolved `BillItem.gstRate`".
- **`BillItem.gstRate`**: `lib/models/bill.dart` — the existing double field that stores a line item's GST percentage. No new field is added; the resolved rate is threaded through the bill purely by writing the resolver's `ratePercent` into this existing field at add-time, exactly as `product.taxRate` is written into it today.
- **`Product.hsnCode` / `Product.drugSchedule`**: `lib/core/repository/products_repository.dart` — the two nullable `String?` fields `PharmacyGstResolver.resolve()` consumes as `hsn`/`schedule` inputs.
- **User override**: A pharmacy `BillItem` whose `gstRate` was set directly by the user (currently only possible via `ManualItemEntrySheet`'s free-text "GST %" field) rather than derived from a product or the resolver.

## Bug Details

### Bug Condition

The bug manifests at every point in `BillCreationScreenV2` where a pharmacy line item's `gstRate` (and the `cgst`/`sgst` computed from it) is assigned from `product.taxRate` (or a matched product's `taxRate`) instead of being resolved from that same product's `hsnCode`/`drugSchedule` via `PharmacyGstResolver`.

**Formal Specification:**
```
FUNCTION isBugCondition(X)
  INPUT: X of type BillItemGstComputation
  OUTPUT: boolean

  // True when a pharmacy line item's GST rate is derived from the flat
  // product taxRate instead of the schedule/HSN-aware PharmacyGstResolver
  RETURN X.businessType = BusinessType.pharmacy
     AND X.gstRateSource = 'product.taxRate'
END FUNCTION
```

### Examples

- **`_addItem` new-line branch** (line ~527, ~656 duplicate in `_addItemWithStockWarning`): a pharmacy product with `hsnCode: '3002'` (5% life-saving slab per the resolver's default overlay) and `taxRate: 12.0` is quick-added. Today: `gstRate: product.taxRate` → line taxed at 12%. Expected: `PharmacyGstResolver.resolve(hsn: '3002')` → 5% → line taxed at 5%.
- **Two products, same `taxRate`, different HSN**: Product A (`hsnCode: '3002'`, `taxRate: 12.0`) and Product B (`hsnCode: '3004'`, `taxRate: 12.0`) are both quick-added. Today: both taxed at 12% (identical, wrong for A). Expected: A taxed at 5%, B taxed at 12%.
- **Manual-entry backfill** (`_showManualItemEntry`'s `onItemAdded`, line ~1941): a manually entered pharmacy item with `gstRate == 0` matches an existing product with `taxRate: 18.0` and `hsnCode: '3401'` (18% non-medicine slab). Today: backfills `gstRate: matched.taxRate` (18%, coincidentally correct here but only because the resolver's default overlay also maps `3401 → 18`). If instead the matched product were `hsnCode: '3002'` with `taxRate: 18.0` (a data-entry mismatch), today's backfill would tax at 18% instead of the statutory 5%.
- **OCR add-to-bill** (`_showOcrResultDialog`, line ~1811): `final double gstRate = matched?.taxRate ?? 0;` — same defect as manual entry; also defaults to `0%` (not the resolver's `12%` fallback) when no product match is found, which additionally violates 3.2's "match today's effective default" expectation for the *matched-but-mistagged* case, though the no-match case for OCR already yields `0`, a pre-existing OCR-specific default this fix does not need to change (OCR add-to-bill has no product match requirement today; see Fix Implementation).
- **Edge case — null/empty HSN and schedule**: a pharmacy product with `hsnCode: null` and `drugSchedule: null` is quick-added. Today and after the fix: 12% is applied (today via `defaultGstRate`-influenced `taxRate`, after the fix via the resolver's `usedFallback` 12% default) — this is the one case where old and new outputs coincide by design (Requirement 3.2).

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Every GST computation for the 17 non-pharmacy, non-grocery/hardware-weighed business types (restaurant, clothing, electronics, mobileShop, computerShop, service, petrolPump, vegetablesBroker, wholesale, other, clinic, bookStore, jewellery, autoParts, decorationCatering, schoolErp, and grocery/hardware's own weighed/dimensioned paths) continues to derive `gstRate`/`cgst`/`sgst` from `product.taxRate` exactly as today, with zero references to `PharmacyGstResolver`.
- A pharmacy `BillItem` with a non-zero, user-entered `gstRate` (set via `ManualItemEntrySheet`'s free-text GST field) is never overwritten by the resolver — the existing `if (item.gstRate == 0)` guard in the manual-entry backfill continues to gate resolver invocation exactly as it gates today's `matched.taxRate` backfill.
- Quantity-edit recompute (`_updateQuantity`) and the existing-line increment branches in `_addItem`/`_addItemWithStockWarning` continue to derive `cgst`/`sgst` from the line's own stored `gstRate` — no lookup of `product.taxRate` or the resolver is introduced into these paths.
- `BusinessTypeConfig.pharmacy.defaultGstRate` (12.0) and `gstEditable` (false) in `business_type_config.dart` are read and returned unchanged; this fix touches only computation call sites in `bill_creation_screen_v2.dart`.
- MRP enforcement (`_buildItemCard`'s `onUpdate` guard), the Rx-capture prescription gate (`_ensurePrescriptionForProduct`), and FEFO batch auto-selection all continue to run exactly as they do today during the same add-item flow, unaffected by the GST resolution change (they read different fields and run at different points in the same functions).
- A pharmacy product with both `hsnCode` and `drugSchedule` null/empty continues to yield a 12% rate — the resolver's `usedFallback` default reproduces today's effective outcome for that case.

**Scope:**
All inputs that are NOT `(businessType == pharmacy AND gstRate derived from product.taxRate)` are unaffected by this fix. This includes:
- Mouse/keyboard edits to price, quantity, unit, discount for any business type.
- All GST computation for grocery's weighed-item path and hardware's dimension path (both are gated by `businessType == grocery`/`hardware` respectively and are unreachable when `businessType == pharmacy`).
- Non-pharmacy manual entry and OCR add-to-bill flows.
- Bill-level totals, invoice PDF rendering, and GSTR-1 HSN aggregation (these consume `BillItem.gstRate`/`cgst`/`sgst` downstream and are unaffected by *how* those fields were populated).

## Hypothesized Root Cause

1. **Resolver built in isolation from its call sites.** `PharmacyGstResolver` was implemented and unit-tested (`test/features/pharmacy/pharmacy_gst_resolver_example_test.dart`, `pharmacy_gst_property15_resolution_fallback_test.dart`) as a standalone class, but the corresponding edit to `BillCreationScreenV2`'s GST-computation sites was never made — a classic "built but not wired in" gap, consistent with every other GST computation site in the screen uniformly using `product.taxRate` regardless of business type.
2. **No business-type branch exists in the GST math.** Every `gstRate: product.taxRate` / `cgst: ... * (product.taxRate / 200)` expression in the file is business-type-agnostic by construction (the same three-line pattern is copy-pasted across grocery-weighed, hardware-dimensioned, and generic add-item code), so pharmacy never got a special case the way it did for FEFO batch selection, the prescription gate, and MRP enforcement (all of which *do* have `if (businessType == BusinessType.pharmacy)` branches in the same functions).
3. **Manual-entry / OCR backfill treats `taxRate` as the ground truth.** The `if (item.gstRate == 0) { ... matched.taxRate ... }` and `matched?.taxRate ?? 0` patterns assume the matched product's flat tax rate is always correct, with no awareness that pharmacy products need HSN/schedule resolution instead.
4. **Duplication multiplies the gap.** `_addItem` and `_addItemWithStockWarning` contain near-identical add-line-item logic (including the FEFO/MRP/prescription-gate pharmacy branches), so the same `product.taxRate` assignment is duplicated in two places, both needing the identical fix.

## Correctness Properties

Property 1: Bug Condition - Pharmacy GST Resolved via HSN/Schedule

_For any_ pharmacy line item being added or backfilled where the GST rate would otherwise be derived from `product.taxRate` (isBugCondition returns true), the fixed function SHALL resolve the rate via `PharmacyGstResolver.resolve(hsn: product.hsnCode, schedule: product.drugSchedule)` and SHALL compute the GST amount via `PharmacyGstResolver.gstAmountPaise` (integer paise, round-half-up), so the stored `gstRate` equals `resolution.ratePercent` and `cgst + sgst` equals the resolver's amount converted back to rupees.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

Property 2: Preservation - Non-Pharmacy and User-Override Paths Unchanged

_For any_ input where the bug condition does NOT hold — every non-pharmacy business type's GST computation, a pharmacy item with a non-zero user-entered `gstRate`, a pharmacy item's quantity-edit/increment recompute (which reuses the already-resolved `gstRate`), and a pharmacy item with null/empty HSN and schedule (which yields the same 12% as today) — the fixed code SHALL produce exactly the same `gstRate`/`cgst`/`sgst` as the original code.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

## Fix Implementation

### Changes Required

**File**: `lib/features/billing/presentation/screens/bill_creation_screen_v2.dart`

1. **Add a shared resolver instance and two private helpers** (new private members on `_BillCreationScreenV2State`):
   - `static final PharmacyGstResolver _pharmacyGstResolver = PharmacyGstResolver();`
   - `int _resolvePharmacyGstRatePercent({String? hsn, String? schedule}) => _pharmacyGstResolver.resolve(hsn: hsn, schedule: schedule).ratePercent;`
   - `double _pharmacyGstAmountRupees({required double taxableAmountRupees, required int ratePercent}) { final paise = Paise.fromRupees(taxableAmountRupees); final gstPaise = _pharmacyGstResolver.gstAmountPaise(taxableAmountPaise: paise, ratePercent: ratePercent); return gstPaise / 100.0; }`
   - Import: `import '../../../../core/pharmacy/pharmacy_gst_resolver.dart';` (`Paise` is already imported).
   - These two helpers centralize the resolver call and the integer-paise amount math so all four call sites below share one implementation instead of duplicating `PharmacyGstResolver()` construction and paise conversion.

2. **`_addItem` new-line branch** (currently `gstRate: product.taxRate`, `cgst`/`sgst` from `product.taxRate / 200`, ~line 527–531): when `businessType == BusinessType.pharmacy`, resolve `ratePercent = _resolvePharmacyGstRatePercent(hsn: product.hsnCode, schedule: product.drugSchedule)`, use it in place of `product.taxRate` for `gstRate`, and compute the GST amount for the taxable base (`taxablePrice`) via `_pharmacyGstAmountRupees`, splitting the result evenly into `cgst`/`sgst`. For any other business type, keep the existing `product.taxRate`-based three lines byte-for-byte.

3. **`_addItem` existing-line increment branch** (~line 505–515): no change. It already derives `cgst`/`sgst` from `existing.gstRate` (the rate stored at add-time), so once step 2 stores the resolved rate, this branch automatically carries it forward for pharmacy and continues deriving from `existing.gstRate` for everyone else.

4. **`_addItemWithStockWarning`**: apply the identical change from steps 2–3 (it duplicates `_addItem`'s add-line-item logic verbatim).

5. **`_showManualItemEntry`'s `onItemAdded` callback** (~line 1941–1953): the existing guard `if (item.gstRate == 0) { final matched = await _findProductByName(item.productName); if (matched != null && matched.taxRate > 0) { ... } }` stays structurally the same (preserving the user-override guard per Requirement 3.3), but when `businessType == BusinessType.pharmacy` and `matched != null`, replace `matched.taxRate` with `_resolvePharmacyGstRatePercent(hsn: matched.hsnCode, schedule: matched.drugSchedule)` and use `_pharmacyGstAmountRupees` (with the discount-adjusted `taxableBase`) for `cgst`/`sgst`. Non-pharmacy keeps using `matched.taxRate` exactly as today. Since a pharmacy product can resolve to a rate even when `matched.taxRate` is 0 (e.g. a 0%-slab exempt medicine mis-tagged with `taxRate: 0` on the product record), the pharmacy branch's condition is `matched != null` (no `> 0` guard); the non-pharmacy branch keeps its `matched.taxRate > 0` guard unchanged.

6. **`_showOcrResultDialog`'s "Add to Bill" handler** (~line 1811–1814): `final double gstRate = matched?.taxRate ?? 0;` — when the active `businessType == BusinessType.pharmacy`, compute `_resolvePharmacyGstRatePercent(hsn: matched?.hsnCode, schedule: matched?.drugSchedule)` instead (this naturally falls back to the resolver's 12% default when `matched` is null, since both `hsn` and `schedule` are then null — see Requirement 3.2). Use `_pharmacyGstAmountRupees` for `halfGst`. Non-pharmacy keeps `matched?.taxRate ?? 0` unchanged. (This changes the OCR no-match default from `0%` to the resolver's `12%` fallback for pharmacy only — this is the corrected behavior implied by Requirement 2.4/3.2, not a regression: pharmacy's config-level fallback has always been 12%, never 0%.)

7. **No change to `_updateQuantity`, `_toggleHalfPortion`, `_toggleHappyHour`, `_addDimensionedHardwareItem`, `_addWeighedGroceryItem`, or `_applyVoiceIntent`.** The first three derive tax from the line's own stored `gstRate` already; the latter two are gated to `businessType == hardware`/`grocery` and are unreachable when `businessType == pharmacy`; `_applyVoiceIntent` hardcodes `gstRate: 0` regardless of business type today and is not one of the GST-computation sites this bugfix addresses (it does not read `product.taxRate`, so it does not satisfy `isBugCondition`).

8. **No change to `lib/models/bill.dart` (`BillItem`)** or `lib/core/billing/business_type_config.dart`. The resolved rate is threaded through the bill purely via the existing `BillItem.gstRate` double field — no new field, no schema change (Requirement 3.4).

## Testing Strategy

### Validation Approach

Surface counterexamples on the unfixed code first (pharmacy items with mismatched HSN vs. flat `taxRate` taxed identically/incorrectly), then verify the fix resolves rates correctly for pharmacy while every other path — including pharmacy's own null-HSN/null-schedule case, user overrides, and quantity-edit recompute — remains byte-for-byte unchanged.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate pharmacy GST is derived from `product.taxRate` instead of `PharmacyGstResolver`, before implementing the fix.

**Test Plan**: Construct pharmacy `Product`s whose `hsnCode`/`drugSchedule` resolve (via `PharmacyGstResolver`) to a *different* rate than their `taxRate`, drive them through `_addItem`'s add-line-item logic (or an extracted equivalent) on the UNFIXED code, and assert the resulting `BillItem.gstRate` — expect it to equal `product.taxRate`, not the resolver's rate, confirming the bug.

**Test Cases**:
1. **HSN 5%-slab vs. flat 12% `taxRate`**: pharmacy product with `hsnCode: '3002'`, `taxRate: 12.0` — quick-add. Unfixed: `gstRate == 12.0`. (will fail the "expected 5.0" assertion on unfixed code)
2. **Manual-entry backfill with mismatched HSN**: `item.gstRate == 0`, matched product `hsnCode: '3002'`, `taxRate: 18.0` — unfixed backfill sets `gstRate == 18.0` instead of the resolver's 5.0.
3. **OCR add-to-bill with no product match**: OCR result with no name match — unfixed sets `gstRate == 0`, not the resolver's 12% fallback.
4. **Two same-`taxRate`, different-HSN products taxed identically** (deterministic reproduction of Requirement 1.4): confirms both lines get `gstRate == 12.0` on unfixed code despite one resolving to 5% via HSN.

**Expected Counterexamples**:
- `BillItem.gstRate` equals the flat `product.taxRate` (or `0` for the OCR no-match case) instead of `PharmacyGstResolver.resolve(...).ratePercent`.
- Root cause confirmed: no call site in `bill_creation_screen_v2.dart` references `PharmacyGstResolver`.

### Fix Checking

**Goal**: Verify that for all pharmacy inputs where the bug condition holds, the fixed function resolves the rate and amount via `PharmacyGstResolver`.

**Pseudocode:**
```
FOR ALL X WHERE isBugCondition(X) DO
  result := computeGst'(X)
  ASSERT result.gstRate = PharmacyGstResolver.resolve(hsn: X.hsn, schedule: X.schedule).ratePercent
  ASSERT result.cgst + result.sgst ≈ PharmacyGstResolver.gstAmountPaise(
           taxableAmountPaise: Paise.fromRupees(X.taxableAmountRupees),
           ratePercent: result.gstRate) / 100.0
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT computeGst(X) = computeGst'(X)
END FOR
```

**Testing Approach**: Property-based testing is recommended because:
- The non-pharmacy input space spans 17 other business types × arbitrary `taxRate`/quantity/discount combinations — enumerating them by hand risks missing one.
- Pharmacy's own preserved sub-cases (null/empty HSN+schedule, user override, quantity-edit reuse) are easy to under-test with a handful of manual examples but are naturally covered by generating many `hsn`/`schedule`/`gstRate` combinations and asserting equality against the pre-fix formula.

**Test Plan**: Observe the UNFIXED code's output for representative non-pharmacy business types and pharmacy edge cases (null HSN+schedule, non-zero user-entered `gstRate`, a second `_updateQuantity` call after add), record the exact `gstRate`/`cgst`/`sgst` values, then write property-based tests asserting the fixed code reproduces them.

**Test Cases**:
1. **Non-pharmacy business types unaffected**: for each of the 17 non-pharmacy types (and grocery/hardware's weighed/dimensioned paths), generate random `taxRate`/qty/discount and assert `gstRate`/`cgst`/`sgst` match the pre-fix `product.taxRate`-based formula exactly.
2. **Pharmacy null/empty HSN and schedule → 12% fallback**: generate pharmacy products with `hsnCode: null` and `drugSchedule: null` (and separately empty strings) and assert the resolved rate is 12%, matching today's effective default.
3. **Pharmacy user override respected**: generate a manually entered pharmacy `BillItem` with a non-zero `gstRate` and assert the manual-entry backfill never overwrites it, regardless of what a name-matched product's HSN/schedule would resolve to.
4. **Pharmacy quantity-edit/increment reuse**: after a pharmacy line is added with a resolved rate, generate random quantity increases via `_updateQuantity` and the existing-line increment branch, and assert `gstRate` never changes and `cgst`/`sgst` scale linearly from the *same* stored rate (no re-derivation from `product.taxRate` or the resolver).

### Unit Tests

- `_addItem`/`_addItemWithStockWarning` new-line branch: pharmacy product with a known HSN → asserts `gstRate` equals the resolver's rate, not `taxRate`.
- Manual-entry backfill: `item.gstRate == 0` + matched pharmacy product → asserts resolver-derived `gstRate`; `item.gstRate != 0` → asserts untouched.
- OCR add-to-bill: matched vs. unmatched product for pharmacy → asserts resolver rate (including the 12% no-match fallback) vs. `0` for non-pharmacy.
- Non-pharmacy business type passed through the same three call sites → asserts `product.taxRate`/`matched.taxRate` used unchanged.

### Property-Based Tests

- Generate arbitrary `(hsnCode, drugSchedule, taxRate)` triples for pharmacy products and assert `_addItem`'s resulting `gstRate` always equals `PharmacyGstResolver.resolve(hsn: hsnCode, schedule: drugSchedule).ratePercent`, never `taxRate`, for every generated combination.
- Generate arbitrary taxable amounts (rupees, including sub-paisa fractions) and resolved rates, and assert `cgst + sgst` (converted to paise) equals `PharmacyGstResolver.gstAmountPaise` applied to the round-half-up paise conversion of the same taxable amount.
- Generate arbitrary non-pharmacy business types with arbitrary `taxRate`/qty/discount and assert the resulting `gstRate`/`cgst`/`sgst` are identical to the pre-fix formula for every generated combination (preservation).

### Integration Tests

- Full add-to-bill flow for a pharmacy product with a 5%-slab HSN: quick-add → verify the line item, bill subtotal, and total tax reflect 5%, not 12%.
- Manual entry of a pharmacy medicine with no HSN typed but a name match to an existing HSN-tagged product: verify the backfilled rate matches the resolver's resolution for the matched product.
- Mixed-cart integration test: add one pharmacy item (HSN-resolved rate), one non-pharmacy item (flat `taxRate`), and one pharmacy item with a user-entered override GST in the same bill; verify all three lines' `gstRate`/`cgst`/`sgst` are independently correct and the bill's `_totalTax` sums them correctly.
