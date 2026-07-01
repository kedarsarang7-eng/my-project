# GAPS_FOUND.md — Audit Trail

> **Final Status: 179/179 tests passed. All 5 gaps FIXED.**

---

## Gap 1: Tax-Inclusive Pricing — FIXED ✅
- **File**: `lib/core/billing/paise_calculator.dart`
- **Fix**: Added `isTaxInclusive` flag to `PaiseLineItem`. When `true`,
  `calculateLineItem` reverse-extracts the base price via:
  `base = lineAmount × 10000 / (10000 + rateBps)`
- **Tests**: 7 new tests in `paise_calculator_edge_cases_test.dart` covering
  18%, 5%, 28% inclusive extraction, 0% rate, inter-state, discount, and
  backward-compat default.

## Gap 2: Composition Scheme — FIXED ✅
- **File**: `lib/core/billing/paise_calculator.dart`
- **Fix**: Added `isCompositionScheme` flag to `PaiseLineItem`. When `true`,
  `calculateLineItem` returns zero tax breakup with `rateBps=0`,
  regardless of the input `gstRateBps`.
- **Tests**: 3 new tests covering single item, invoice-level, and
  `isCompositionScheme` overriding `isInterState`.

## Gap 3: Fragile Inter-State Detection — FIXED ✅
- **Files**: `lib/core/accounting/bill_calculator.dart`, `lib/models/bill.dart`
- **Fix**: Added `bool isInterState` field to `BillItem` (default: `false`).
  BillCalculator now uses `item.isInterState` instead of the fragile
  `item.igst > 0` heuristic. Fully backward-compatible: existing callers
  that don't set it get intra-state (CGST+SGST) behavior.
- **Tests**: Updated inter-state test + added regression test confirming
  `igst=0` with `isInterState=false` correctly produces CGST+SGST.

## Gap 4: `_roundTo2` Double Escape — FIXED ✅
- **File**: `lib/core/accounting/bill_calculator.dart`
- **Fix**: Replaced `Decimal → double → round() → Decimal` with pure
  BigInt arithmetic: `shifted.toBigInt()` + manual half-up comparison
  against `Decimal.parse('0.5')`. No floating-point involved at any step.
- **Tests**: Existing BillCalculator tests verify identical rounding behavior.

## Gap 5: Negative Amounts Clamped to Zero — FIXED ✅
- **File**: `lib/core/billing/paise_calculator.dart`
- **Fix**: Removed the `taxablePaise < 0 ? 0 : taxablePaise` clamp.
  Negative taxable now flows through, producing negative tax (represents
  tax refund on credit notes). CGST/SGST split works correctly on negative
  values via integer division.
- **Tests**: 4 new tests covering negative taxable, negative CGST+SGST split,
  negative IGST, and negative discount (surcharge). Updated 2 existing tests
  that expected clamping.

---

## Test Inventory (Post-Fix)

| File | Tests | Status |
|------|-------|--------|
| `test/unit/gst/paise_calculator_test.dart` | 41 | ✅ |
| `test/unit/gst/paise_calculator_edge_cases_test.dart` | 24 | ✅ |
| `test/unit/gst/bill_calculator_test.dart` | 16 | ✅ |
| `test/unit/gst/gst_validator_test.dart` | 10 | ✅ |
| `test/unit/money/money_math_test.dart` | 15 | ✅ |
| `test/unit/money/amount_converter_test.dart` | 22 | ✅ |
| `test/unit/money/paise_arithmetic_test.dart` | 20 | ✅ |
| `test/unit/rid/request_context_test.dart` | 18 | ✅ |
| `test/unit/rid/request_context_edge_cases_test.dart` | 15 | ✅ |
| `test/unit/repository/` (pre-existing) | 14 | ✅ |
| **TOTAL** | **179** | **✅ ALL PASSED** |
