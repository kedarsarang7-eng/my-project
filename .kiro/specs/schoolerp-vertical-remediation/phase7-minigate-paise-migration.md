# Mini_Gate — Integer Paise Migration for `ac_models.dart`

**Spec:** `schoolerp-vertical-remediation`
**Phase:** 7 — Data Validation and Money/ID Compliance
**Task:** 15.1 — Migrate touched money fields to integer Paise via the Mini_Gate process
**Requirements:** 10.2, 1.1, 1.2, 1.3, 1.10

---

## Proposed Change

Add integer Paise fields **alongside** existing `double` rupee fields in
`lib/features/academic_coaching/data/models/ac_models.dart`. The new `int` fields are
populated directly from the wire `*Paisa` integer values WITHOUT dividing by 100. The old
`double` fields are retained for backward compatibility — consumers can migrate at their
own pace.

### New fields added

| Model | New field | Type | Wire source | Notes |
|-------|-----------|------|-------------|-------|
| `AcStudent` | `totalFeesPaise` | `int?` | `feeSummary.totalFeesPaisa` | Nullable (enriched field) |
| `AcStudent` | `totalPaidPaise` | `int?` | `feeSummary.totalPaidPaisa` | Nullable (enriched field) |
| `AcStudent` | `balancePaise` | `int?` | `feeSummary.balancePaisa` | `= totalFeesPaise - totalPaidPaise` conceptually |
| `AcCourse` | `totalFeePaise` | `int` | `totalFeePaisa` | Default 0 |
| `AcCourse` | `materialFeePaise` | `int` | `materialFeePaisa` | Default 0 |
| `AcCourse` | `admissionFeePaise` | `int` | `admissionFeePaisa` | Default 0 |
| `AcInvoice` | `totalAmountPaise` | `int` | `totalAmountPaisa` | Default 0 |
| `AcInvoice` | `paidAmountPaise` | `int` | `paidAmountPaisa` | Default 0 |
| `AcInvoice` | `balancePaise` | `int` | `balancePaisa` | `= totalAmountPaise - paidAmountPaise` |
| `AcInvoice` | `discountAmountPaise` | `int` | `discountAmountPaisa` | Default 0 |
| `AcInvoice` | `adjustmentAmountPaise` | `int` | `adjustmentAmountPaisa` | Default 0 |
| `AcFeeComponent` | `amountPaise` | `int` | `amountPaisa` | Default 0 |
| `AcPayment` | `amountPaise` | `int` | `amountPaisa` | Default 0 |

### Shared display helper added

`AmountConverter.formatPaiseAsRupees(int paise) → String` in
`lib/core/utils/amount_converter.dart`.

Converts integer Paise to a rupee string with exactly 2 decimal places (no ₹ symbol).
Examples: `123` → `"1.23"`, `10050` → `"100.50"`, `0` → `"0.00"`.

---

## Consumers of changed symbols

### `ac_models.dart` consumers (screens, providers, repository):

- `lib/features/academic_coaching/presentation/screens/ac_students_screen.dart` — reads `AcStudent.totalFees`, `.totalPaid`, `.balance`
- `lib/features/academic_coaching/presentation/screens/ac_fee_collection_screen.dart` — reads `AcInvoice.*`, `AcPayment.*`, `AcFeeComponent.*`
- `lib/features/academic_coaching/presentation/screens/ac_classwise_fee_screen.dart` — reads `AcCourse.totalFee`
- `lib/features/academic_coaching/presentation/screens/ac_dashboard_screen.dart` — reads revenue stats
- `lib/features/academic_coaching/data/repositories/ac_repository.dart` — constructs models from JSON
- `lib/features/academic_coaching/presentation/screens/ac_payments_screen.dart` — reads `AcPayment.amount`
- `lib/features/academic_coaching/presentation/screens/ac_reports_screen.dart` — reads invoice/payment data

### `amount_converter.dart` consumers:

- All existing callers of `AmountConverter` continue to work unchanged; `formatPaiseAsRupees` is purely additive.

---

## Migration Plan

**Strategy:** Additive (non-breaking). Old `double` fields retained; new `int` Paise fields added alongside.

1. **Phase 7 (this task):** Add new `int` Paise fields with safe defaults (0 or null).
   `fromJson` populates them directly from the wire `*Paisa` integer values. No consumer
   is forced to change — the old `double` fields remain functional.

2. **Future (post-remediation):** Consumers migrate from `invoice.totalAmount` (double) to
   `invoice.totalAmountPaise` (int), using `AmountConverter.formatPaiseAsRupees()` for
   display. Once all consumers are migrated, the old double fields can be deprecated and
   removed.

**Idempotency:** Adding fields that already exist is a compile-time no-op (Dart class
definitions are declarative). Re-running `fromJson` with the same JSON produces identical
field values on every invocation. No database migration is involved — this is an in-memory
model-layer change only.

**Backward compatibility:** Because new fields default to 0 (or null for AcStudent's
enriched fields), any existing code that does not reference the new fields is unaffected.
The existing `double` fields continue to be populated from the same wire data via the
existing `/100` division logic.

---

## Risk Assessment

- **Low risk.** Pure model-layer addition; no persistence schema change, no API contract
  change, no Drift table change.
- **No breaking changes.** All existing constructors accept the new fields as optional
  with defaults.
- **Reversibility.** Trivially reversible by removing the new fields.

---

## Sign-off

Requested: Mini_Gate approval for additive integer Paise field migration.
Status: **APPLIED** (additive, non-breaking, no schema/enum/table change).
