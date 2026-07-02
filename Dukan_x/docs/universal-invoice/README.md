# Universal Smart Invoice System — Developer Guide

Config-driven invoice rendering for 9 universal business types + 3 dedicated
templates (Pharmacy, Restaurant, Jewellery), with shared sections, PDF/thermal
printing, a settings panel, an additive migration, and verified GST maths.

- Architecture: `design_docs/universal-invoice-architecture.md`
- Config guide: this file, "Configuration Guide"
- Migration guide: this file, "Migration Guide"

## Directory map

```
lib/features/invoice/
  universal/
    config/    invoice_section.dart, invoice_field_config.dart,
               invoice_section_config.dart, invoice_layout_config.dart,
               universal_invoice_presets.dart
    model/     universal_invoice_item.dart, universal_invoice_data.dart
    widgets/   invoice_shared_sections.dart, universal_invoice_template.dart
    print/     print_page_formats.dart, invoice_pdf_sections.dart,
               config_invoice_pdf_builder.dart, invoice_pdf_fonts.dart,
               invoice_print_adapter.dart
    settings/  invoice_sections_settings_panel.dart
    migration/ invoice_layout_migration.dart
    gst/       invoice_gst_calculator.dart
  dedicated/
    models/    pharmacy_invoice_item.dart, restaurant_invoice_item.dart,
               jewellery_invoice_item.dart
    widgets/   pharmacy_invoice_template.dart, restaurant_invoice_template.dart,
               jewellery_invoice_template.dart
```

## Core idea

The on-screen widget (`UniversalInvoiceTemplate`) and the PDF builder
(`ConfigInvoicePdfBuilder`) both iterate an `InvoiceLayoutConfig` and dispatch
sections through a registry keyed by `InvoiceSection`. There are **zero**
`if (businessType == ...)` conditionals in either render path — business
differences are pure config data. The dedicated templates reuse the shared
section components and only replace the product table.

## Architecture Overview

- `InvoiceLayoutConfig` = ordered `List<InvoiceSectionConfig>` + `businessType`
  + `schemaVersion` (3 = config engine; legacy PDF path = version 2).
- `InvoiceSectionConfig` carries the 7 flags: `enabled, required, visible,
  editable, businessTypeSpecific, subscriptionTier, offlineCompatible` plus
  `section` + `order` (structural).
- Product-table columns come from the productTable section's `visibleFields`.
- Shared sections live once in `InvoiceSharedSections` (widget) and
  `InvoicePdfSections` (PDF) and are reused by universal + dedicated templates.

## Configuration Guide

### Get a default layout for a business type
```dart
final config = UniversalInvoicePresets.forType(BusinessType.mobileShop);
```
Wired universal types: grocery, mobileShop, wholesale, computerShop,
electronics, bookStore, clothing, autoParts, hardware. Pharmacy/Restaurant/
Jewellery use dedicated templates, not this factory.

### Render on screen
```dart
UniversalInvoiceTemplate(config: config, data: universalInvoiceData);
```

### Toggle / reorder sections (admin)
```dart
InvoiceSectionsSettingsPanel(
  initialConfig: config,
  previewData: sampleData,
  onChanged: (updated) => persistTenantOverride(updated),
);
```
The panel edits the layout only. Subscription-tier gating is handled separately
by the existing DukanX 4-tier system; the `subscriptionTier` flag rides along in
the config for that system to enforce.

### Tenant overrides
```dart
final custom = config.withOverrides({
  InvoiceSection.terms: config.sectionFor(InvoiceSection.terms)!
      .copyWith(enabled: false, visible: false),
});
```

### Persist / restore
`InvoiceLayoutConfig`, `InvoiceSectionConfig`, `InvoiceFieldConfig` all provide
`toJson()` / `fromJson()`.

### Print (A4 / thermal 58mm / 80mm)
```dart
final bytes = await InvoicePrintAdapter.universalBytes(
  config: config, data: data, mode: InvoicePrintMode.a4);
await InvoicePrintAdapter.preview(bytes: bytes, filename: 'invoice.pdf');
```
PDF text uses the bundled NotoSansDevanagari theme (see `invoice_pdf_fonts.dart`)
so ₹ and Devanagari render correctly. Thermal modes use a compact receipt layout;
A4 uses the full table.

### GST calculation
```dart
final summary = InvoiceGstCalculator.forInvoice(lines, isInterState: false);
// summary.cgst / sgst / igst / cess / totalTax / grandTotal
```
Reuses the authoritative `GstService.calculateTaxBreakup` for the CGST/SGST/IGST
split and adds CESS. Intra-state → CGST+SGST (rate/2 each); inter-state → IGST.

## Dedicated templates

Pharmacy/Restaurant/Jewellery each reuse `InvoiceSharedSections` for business
info, customer info, payment/summary, terms (and tax/signature where relevant),
and implement only their bespoke product table:
- Pharmacy: mandatory Batch + Expiry, expiry-warning banner, `PharmacyInvoiceValidator`.
- Restaurant: portion (Full/Half), table binding, service-charge line.
- Jewellery: purity/HUID, weight×rate + making + wastage + stone − old-gold.

## Migration Guide

The migration is **additive and reversible**: it creates layout-config records
and never mutates existing invoice rows.

```dart
const migration = InvoiceLayoutMigration();
final report = migration.migrate(records, configStore, dryRun: true); // preview
if (report.isLossless) {
  migration.migrate(records, configStore); // commit
}
// rollback (drops created configs; invoices untouched)
migration.rollback(configStore, report);
```

- `report.recordCountParity` — before == after (no invoice added/dropped).
- `report.isLossless` — parity AND every line's item-count + grand-total preserved.
- `report.toText()` — human-readable report incl. an old-vs-new sample table.

### Rollback / feature flag
New engine = `schemaVersion 3`; the legacy renderer (`version 2`) stays intact.
Gate with a `useConfigDrivenInvoice` flag: ON → new engine, OFF → legacy. Rollback
= flip the flag off + drop the config table. No invoice data is mutated.

### Production run
Always run `dryRun: true` on a **copy/snapshot** first, verify parity, keep the
rollback ready, and only then commit. Never run against live data directly.

## Testing

```
flutter test test/features/invoice --coverage
```
78 tests; 100% line coverage of `lib/features/invoice/**` (see the coverage
report in Phase 8). Suites: unit (calc + serialization), widget (9 universal +
3 dedicated + settings), print (A4/thermal + fonts), integration
(create→render→print→save), migration (parity/loss/rollback), GST verification
(5 hand-calculated cases).
