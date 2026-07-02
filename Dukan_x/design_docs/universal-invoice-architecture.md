# Universal Smart Invoice System — Architecture (Phase 1, APPROVED)

> Status: Phase 1 approved (schema approved at MINI_GATE 1.1; full doc approved at STOP_GATE 1).
> Scope: Config-driven invoice rendering for 9 universal business types + 3 dedicated templates.
> Backward compatibility with existing invoice data is non-negotiable and reversible.

## 1. Grounding in existing code (no conflicts)

This design reuses existing types rather than inventing new ones:

- `BusinessType` — `lib/models/business_type.dart` (19 values).
- `SubscriptionTier { basic, pro, premium, enterprise }` — `lib/core/subscription/subscription_tier.dart` (the real 4-tier enum).
- `EnhancedInvoiceConfig` / `EnhancedInvoiceCustomer` / `EnhancedInvoiceItem` — `lib/core/pdf/invoice_models.dart`. These already carry every business-specific field the sections need (batchNo, expiryDate, serialNo, warrantyMonths, hsn, upiId, signatureImage, size, color, tableNo, laborCharge, partsCharge, gross/net weight, commission, etc.).
- Primary active PDF generator: `lib/core/pdf/enhanced_invoice_pdf_service.dart` (must keep working).

## 2. Section Config Schema

### The 16 sections

```dart
enum InvoiceSection {
  businessInfo, customerInfo, shipping, productTable, tax, payment,
  discount, bankDetails, warranty, serialImei, notes, terms, qr,
  signature, logo, watermark,
}
```

### Section config — 7 required flags (verbatim from spec) + structural metadata

```dart
class InvoiceSectionConfig {
  // Identity / structural metadata (NOT part of the 7 behavioral flags)
  final InvoiceSection section;   // which section
  final int order;                // render order; drives Phase-6 reorder UI

  // The 7 required flags
  final bool enabled;             // master switch; false => engine skips it
  final bool required;            // fields mandatory; blocks save/print if empty
  final bool visible;             // render in OUTPUT (PDF/thermal/preview)
  final bool editable;            // admin may toggle in Settings Panel (Phase 6)
  final bool businessTypeSpecific;// appears only for specific business types
  final SubscriptionTier subscriptionTier; // MIN tier to use this section
  final bool offlineCompatible;   // fully renders with no network?

  final List<InvoiceFieldConfig> fields; // optional per-field control
}
```

Invariants:
- `required` is meaningful only when `enabled == true` (a disabled section cannot be required).
- `order` + `section` are structural identity, intentionally separate from the 7 behavioral flags.

### Field-level config

```dart
class InvoiceFieldConfig {
  final String key;    // maps to EnhancedInvoiceItem/Config property (e.g. 'batchNo')
  final String label;  // localizable
  final bool enabled;
  final bool required;
  final bool visible;
  final bool editable;
}
```

### Full config consumed by the engine

```dart
class InvoiceLayoutConfig {
  final BusinessType businessType;
  final int schemaVersion;                 // = 3 for the new engine
  final List<InvoiceSectionConfig> sections;
}
```

Tenant overrides from the Settings Panel merge on top of the per-business default.

## 3. Business-Type → Section Mapping (9 universal types)

Always-on (not shown): businessInfo, customerInfo, productTable, payment, logo.
Legend: ✅ enabled+visible · ⭐ enabled+required · ➖ disabled · ○ optional (default off).

| Business Type | shipping | tax | discount | bankDetails | warranty | serialImei | notes | terms | qr | signature | watermark | Product-table extras |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Grocery Store (pilot) | ➖ | ○ | ✅ | ○(pro) | ➖ | ➖ | ○ | ✅ | ✅UPI | ○ | ○ | HSN○, Unit |
| Mobile Shop (pilot) | ➖ | ✅ | ✅ | ○ | ⭐ | ⭐ IMEI | ○ | ✅ | ✅UPI | ✅ | ○ | IMEI⭐, Warranty⭐, HSN✅ |
| Wholesale Distributor (pilot) | ⭐ dispatch | ⭐ B2B | ✅ | ⭐ | ➖ | ➖ | ✅ | ⭐ | ✅ | ✅ | ○ | Bulk qty, HSN⭐, transport |
| Computer Store | ➖ | ✅ | ✅ | ○ | ⭐ | ✅ Serial | ○ | ✅ | ✅UPI | ✅ | ○ | Serial✅, Warranty⭐, HSN✅ |
| Electronics Store | ➖ | ✅ | ✅ | ○ | ✅ | ✅ Serial (IMEI○) | ○ | ✅ | ✅UPI | ✅ | ○ | Serial✅, Warranty✅, HSN✅ |
| Book Store | ➖ | ○ (many 0%) | ✅ | ➖ | ➖ | ➖ | ○ | ○ | ✅UPI | ○ | ➖ | ISBN○, HSN○ |
| Clothing Store | ➖ | ✅ | ⭐ | ➖ | ➖ | ➖ | ○ | ✅ exchange | ✅UPI | ○ | ○ | Size✅, Color✅ |
| Auto Parts Store | ○ | ✅ | ✅ | ○ | ✅ (IMEI➖) | ○ part-no | ○ | ✅ | ✅UPI | ✅ | ○ | Part-no, Warranty✅, HSN✅ |
| Hardware Store | ○ | ✅ | ✅ | ○ | ➖ | ➖ | ○ | ✅ "goods sold not returnable" | ✅UPI | ○ | ○ | HSN⭐, Unit (Pc/kg/box) |

Matches spec examples: Auto Parts → IMEI=false, Warranty=true; Mobile Shop → IMEI=true.

## 4. Dedicated Templates (Pharmacy, Restaurant, Jewellery)

Must reuse shared section components (Customer Info, Payment, Summary, Signature); only the product-table logic is bespoke.

| Type | Breaking fields | Why universal fails |
|---|---|---|
| Pharmacy | batchNo + expiryDate mandatory & regulatory; Drug License in header; Schedule-H warnings; per-item expiry-block validation | Universal treats batch/expiry as optional columns; pharmacy needs required, validated, sale-blocking fields + expiryWarning section (regulatory). |
| Restaurant | Table/KOT, Half/Full portion, service charge, dine-in/parcel/aggregator split, running/held bills | Line item is not qty×unitPrice; portion + table + service-charge math change totals and row schema. |
| Jewellery | Purity/Hallmark (BIS/HUID), Making Charges, Gross/Net/Stone weight, wastage %, metal rate-of-day, old-gold exchange | Price = netWeight×rateOfDay + making + stoneValue − oldGoldExchange; replaces the universal qty×unitPrice formula. |

## 5. Migration Strategy + Rollback

| Existing file | Status | Migration action |
|---|---|---|
| core/pdf/invoice_template_factory.dart | Dead | Salvage 9 template classes → default productTable field configs, then delete. |
| core/pdf/adaptive_pdf_layouts.dart | Dead | Salvage show*Column booleans → InvoiceFieldConfig.visible (best source for mobileShop/computerShop/vegetablesBroker), then delete. |
| core/pdf/enhanced_invoice_pdf_service.dart | Active (primary) | Becomes config-driven renderer core; wrapped to consume InvoiceLayoutConfig. |
| core/pdf/invoice_pdf_theme.dart | Active | Keep as-is (theme keyed by businessType). |
| core/pdf/invoice_pdf_with_imei.dart | Active | Fold into serialImei section (enabled+required for mobileShop). |
| services/invoice_pdf_service.dart | Active | Keep InvoiceLanguage enum; convert to thin facade over engine. |
| services/pdf_invoice_service.dart, services/pdf_service.dart, services/bill_print_service.dart | Active | Retain legacy A4 path until Phase 5, then route through engine. |
| core/services/bill_print_service.dart | Dead (best 58/80mm thermal) | Salvage thermal logic into Phase-5 print adapter BEFORE deleting. |
| core/pdf/{invoice_pdf_service, pdf_invoice_service, pdf_service}.dart | Dead | Delete after salvage confirms no unique logic lost. |
| restaurant_pdf_bill_service.dart, dc_pdf_service.dart, purchase_receipt_pdf.dart, onboarding/bill_template_system.dart | Active | Out of universal scope; Restaurant handled by dedicated template (Phase 4). |

### Rollback plan (reversible)
- Additive storage: section configs live in a NEW store (`invoice_layout_config`). Existing Bill/invoice records are never mutated.
- Version gate: new engine = schemaVersion 3; existing `EnhancedInvoiceConfig.version == 2` path stays intact.
- Feature flag `useConfigDrivenInvoice` (per-tenant/remote-config). ON → new engine; OFF → legacy renderer unchanged.
- Reverse steps: (1) flip flag OFF → instant revert to legacy; (2) drop new config table → zero impact on invoice data.
- Phase 7 runs forward migration on a COPY of production first, demonstrating rollback before any forward run.

## 6. Phasing

- Phase 2: config models + universal engine widget + 3 pilots (Grocery, Mobile Shop, Wholesale). No PDF/print changes.
- Phase 3: wire remaining 6 universal types into the SAME engine (no new template files).
- Phase 4: 3 dedicated templates reusing shared sections.
- Phase 5: printing/PDF (thermal 58/80mm, A4) adapted to config-driven templates.
- Phase 6: Settings Panel (toggle/reorder). Tier gating out of scope (handled separately).
- Phase 7: migration on production copy with data-parity proof.
- Phase 8: tests (unit → widget → integration → migration) with pasted `flutter test` output.
- Phase 9: GST/CGST/SGST/IGST/CESS verification against 5 hand-calculated cases.
- Phase 10: developer docs + final sign-off checklist.
