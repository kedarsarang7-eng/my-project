# Bugfix Requirements Document

## Introduction

The pharmacy business-type audit (`audit-reports/business-types/audit-pharmacy.md`) flagged that pharmacy's per-item GST is not schedule/HSN-aware: `BusinessTypeConfig` for `BusinessType.pharmacy` fixes `defaultGstRate: 12.0` with `gstEditable: false`, and every GST computation site in `BillCreationScreenV2` (quick-add, manual entry, weighed-item entry, quantity edits, discount recompute) derives `gstRate` directly from `product.taxRate` — a single per-product rate with no schedule/HSN resolution. Medicines legitimately span the {0, 5, 12, 18, 28}% statutory slabs by HSN code and drug schedule, so a per-product flat rate cannot represent this correctly.

A remediation effort already built `PharmacyGstResolver` (`lib/core/pharmacy/pharmacy_gst_resolver.dart`) — a fully-implemented, unit-tested class that resolves the correct GST rate from an item's HSN code and/or drug schedule (HSN match → schedule match → 12% fallback with a `usedFallback` flag), and computes the GST amount in integer paise with round-half-up via the shared `Paise` helper. Investigation of the current codebase confirms this resolver has **zero call sites** anywhere in production code (`bill_creation_screen_v2.dart`, `bills_repository.dart`) — it is fully built but never wired in. Every other audit-flagged pharmacy defect (Rx-capture gating, MRP enforcement, H1 Register dead link, hardcoded alert counts, FEFO ordering, duplicate `NarcoticRegisterScreen`, drug-schedule string/enum mismatch, orphaned pharmacy screens, `pharmacist` role, batch-tracking error surfacing, supplier expiry-return flow, accessibility labels) was independently verified as already fixed in the current codebase and is out of scope for this spec.

This bugfix wires `PharmacyGstResolver` into every pharmacy GST-computation site in `BillCreationScreenV2`, so pharmacy line items are taxed by their resolved HSN/schedule rate instead of the flat per-product `taxRate`, while leaving GST computation for all 18 other business types byte-for-byte unchanged.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a pharmacy item is added to a bill (quick-add, manual entry, weighed-item entry, or barcode/product-search paths) THEN the system computes `gstRate`/`cgst`/`sgst` directly from `product.taxRate`, ignoring the item's HSN code and drug schedule
1.2 WHEN a pharmacy item's quantity is increased on an existing bill line THEN the system recomputes `cgst`/`sgst` from the existing line's already-flat `gstRate`, perpetuating the un-resolved rate
1.3 WHEN a pharmacy bill item has `gstRate == 0` and a matched product is found during discount/price recompute THEN the system backfills `gstRate` from `matched.taxRate` instead of resolving it via HSN/schedule
1.4 WHEN two pharmacy items share the same `taxRate` but have different HSN codes or drug schedules that legitimately warrant different statutory slabs (e.g. a 5%-slab life-saving drug vs. a 12%-slab standard formulation, both entered with the same flat product `taxRate`) THEN the system taxes them identically instead of applying the correct per-item slab

### Expected Behavior (Correct)

2.1 WHEN a pharmacy item is added to a bill (quick-add, manual entry, weighed-item entry, or barcode/product-search paths) THEN the system SHALL resolve the GST rate via `PharmacyGstResolver.resolve(hsn: product.hsnCode, schedule: product.drugSchedule)` and compute `cgst`/`sgst` from the resolved rate
2.2 WHEN a pharmacy item's quantity is increased on an existing bill line THEN the system SHALL recompute `cgst`/`sgst` using the line's already-resolved GST rate (the rate resolved at add-time), without re-flattening it to `product.taxRate`
2.3 WHEN a pharmacy bill item has `gstRate == 0` and a matched product is found during discount/price recompute THEN the system SHALL resolve the GST rate via `PharmacyGstResolver.resolve(hsn: matched.hsnCode, schedule: matched.drugSchedule)` instead of assigning `matched.taxRate` directly
2.4 WHEN a pharmacy item's HSN code and/or drug schedule match an entry in `PharmacyGstResolver`'s statutory slab mapping THEN the system SHALL apply that resolved rate, and WHEN neither matches THEN the system SHALL apply the resolver's 12% fallback rate
2.5 WHEN GST is computed for a resolved pharmacy line item THEN the system SHALL derive the amount using integer-paise, round-half-up arithmetic consistent with `PharmacyGstResolver.gstAmountPaise`/`Paise`, so displayed CGST+SGST match the resolver's rate to the paisa

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a bill item is added, edited, or recomputed for any business type OTHER than `BusinessType.pharmacy` THEN the system SHALL CONTINUE TO compute `gstRate`/`cgst`/`sgst` from `product.taxRate` exactly as before, with no reference to `PharmacyGstResolver`
3.2 WHEN a pharmacy product's HSN code and drug schedule are both null/empty THEN the system SHALL CONTINUE TO apply a 12% GST rate (the resolver's fallback), matching today's effective default for such items
3.3 WHEN a pharmacy bill item has a non-zero, user-entered `gstRate` (an explicit user override) THEN the system SHALL CONTINUE TO respect that user-entered rate without being overwritten by the resolver
3.4 WHEN `business_type_config.dart`'s pharmacy `defaultGstRate`/`gstEditable` values or any other business type's `BusinessTypeConfig` are read THEN the system SHALL CONTINUE TO return the same values as before this fix (this fix changes computation call sites in the billing screen, not the shared config)
3.5 WHEN MRP enforcement, Rx-capture gating, FEFO batch selection, or any other already-fixed pharmacy behavior runs during the same bill-item-add flow THEN the system SHALL CONTINUE TO behave exactly as it does today, unaffected by the GST resolution change

### Bug Condition

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type BillItemGstComputation
  OUTPUT: boolean

  // True when a pharmacy line item's GST rate is derived from the flat
  // product taxRate instead of the schedule/HSN-aware PharmacyGstResolver
  RETURN X.businessType = BusinessType.pharmacy
     AND X.gstRateSource = 'product.taxRate'
END FUNCTION
```

### Property Specification

```pascal
// Property: Fix Checking - Pharmacy GST resolved via HSN/schedule
FOR ALL X WHERE isBugCondition(X) DO
  result ← computeGst'(X)
  ASSERT result.rate = PharmacyGstResolver.resolve(hsn: X.hsn, schedule: X.schedule).ratePercent
  ASSERT result.gstAmountPaise = PharmacyGstResolver.gstAmountPaise(
           taxableAmountPaise: X.taxableAmountPaise, ratePercent: result.rate)
END FOR

// Property: Preservation - non-pharmacy and user-override paths unchanged
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT computeGst(X) = computeGst'(X)
END FOR
```
