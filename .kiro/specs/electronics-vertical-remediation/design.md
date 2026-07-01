# Electronics Vertical Remediation — Bugfix Design

## Overview

This design formalizes the phased remediation of the **Electronics**
(`BusinessType.electronics`, display name "Mobile / Electronics") vertical in the DukanX
Flutter app. The requirements (`bugfix.md`) frame each defect as a bug condition `C(X)`,
a correct-behavior property `P(result)`, and a preservation goal `F(X) = F'(X)` for all
non-triggering inputs, grouped into nine STOP-GATE phases (Phase 0 read-only investigation
through Phase 8 final regression verification).

The remediation strategy is **reachability + integrity, not rebuild**. Live-code
verification (Phase 0 prework, see "Phase 0 findings" below) confirms that the data layer
needed to fix Electronics largely already exists — the `IMEISerials` Drift table (with a
`{userId, imeiOrSerial}` unique key and warranty columns), a real
`getImeiTrackingStatement` query, built `WarrantyScreen` / `SerialHistoryScreen`, allowed
`/job/*` routes, and `IMEISerialRepository`. The gaps are: (1) serial uniqueness/required
enforcement is a stub, (2) device screens are guarded against Electronics, (3) warranty
expiry and serial inventory are not written at point of sale, (4) the sidebar shows a
generic retail menu, (5) dashboard counts are hardcoded, (6) sensitive sidebar items carry
no RBAC permission, and (7) returns/serial-stock/accessibility/HSN gaps remain.

Every change is **additive and tenant-isolated**. No code path belonging to another
business type is altered. Files shared with `mobileShop` / `computerShop`
(`manual_item_entry_sheet.dart`, `billing_service.dart`, `sidebar_configuration.dart`,
`business_alerts_widget.dart`, `business_quick_actions.dart`, `legacy_routes.dart`) are
flagged in each phase and their existing behavior is preserved byte-for-byte except for
the explicit, electronics-gated additions described here.

### Authoritative source and live-code re-verification

The authoritative audit is `audit-reports/business-types/audit-electronics.md`; the
requirements are `bugfix.md`. Per the operating rules, every claim below was re-verified
against the current codebase before being encoded. `bugfix.md` already records
discrepancies **D1–D4**. This design records three further discrepancies (**D5–D7**) found
during verification — the live code has moved past the stale audit text in these places,
and executors MUST NOT act on the stale descriptions.

### Phase 0 findings (read-only verification performed for this design)

These are the verified facts the later-phase design decisions rest on. Phase 0 of
execution must re-confirm them at task time (the codebase may move), but they are recorded
here as the current ground truth:

- **D1 (serial validator) — CONFIRMED.** `manual_item_entry_sheet.dart` attaches a serial
  `validator` only for `BusinessType.mobileShop` (`'IMEI / Serial No is required for mobile
  shop'`); it is `null` for `electronics` and `computerShop`. A blank serial is silently
  accepted for Electronics. The async duplicate check in the same file is gated by
  `widget.businessType.name.contains('mobile')` — so it never runs for Electronics.
- **D2 (warranty range) — STALE/PRESERVE.** `manual_item_entry_sheet.dart` already
  validates `warrantyMonths` as a whole number in `0..120`. This is preserved, not
  reintroduced (Regression clause 3.3).
- **D3 (route file) — CONFIRMED, location corrected.** The live router for the device and
  job routes is `Dukan_x/lib/core/routing/legacy_routes.dart` (GoRouter `GoRoute`
  entries), NOT `app/routes.dart`. All later route edits target this file.
- **D4 (IMEI query tenant scope) — CONFIRMED as a concern.**
  `statements_repository.getImeiTrackingStatement` filters `i.userId.equals(userId)` only;
  there is no `vendorId`/tenant filter beyond `userId`. The `IMEISerials` table is itself
  keyed/scoped by `userId` (unique key `{userId, imeiOrSerial}`). Whether `userId` is the
  correct tenant boundary here (vs. a separate `vendorId`) is the Phase 0 gate before the
  screen is wired in Phase 2.
- **D5 (sidebar grouping) — NEW.** `bugfix.md` 1.14 says Electronics is grouped with
  `mobileShop` AND `computerShop`. The live `_getSectionsForBusiness()` already split
  `mobileShop` into its own `_getMobileShopSections()` (5 device entries). Electronics is
  now grouped with **`computerShop` only**:
  `case BusinessType.electronics: case BusinessType.computerShop: return
  _getRetailSections();`. The Phase 4 fix splits **Electronics** out into a dedicated
  `_getElectronicsSections()`, leaving the `computerShop` case on `_getRetailSections()`
  unchanged. `_getMobileShopSections()` is the structural template to mirror.
- **D6 (device-route guards already widened) — NEW.** `bugfix.md` 1.8 says
  `/computer-shop/warranty` and `/computer-shop/serial-history` are guarded to
  `[computerShop]` only. The live guards are already widened to
  `[computerShop, mobileShop]` AND now wrap an inner `CapabilityGate`
  (`useWarranty` / `useIMEI`). Enabling Electronics therefore requires adding
  `BusinessType.electronics` to **both** the `BusinessGuard.allowedTypes` and the inner
  `CapabilityGate.allowedTypes` at each route. Electronics already holds `useWarranty` and
  `useIMEI`, so the capability predicate passes once it is in the allow-lists.
  `/computer-shop/multi-unit` remains `[computerShop]` only and Electronics lacks
  `useMultiUnit` — multi-unit is the one device screen that needs an explicit grant vs.
  park decision.
- **D7 (/job/* already allow Electronics) — NEW.** `/job/create`, `/job/status`,
  `/job/deliver` already include `BusinessType.electronics` in `allowedTypes` and require
  `Permissions.manageStaff`. The in-shell `sidebar_navigation_handler.dart` already wraps
  `job_create` / `job_status` / `job_deliver` / `service_jobs` in
  `VendorRoleGuard(manageStaff)`. So Phase 2's "surface `/job/*`" is a purely additive
  sidebar entry, and Phase 6's quick-action/route-agreement fix (2.21) is about routing the
  dashboard "New Repair" action through the same `manageStaff`-guarded path rather than a
  raw `AppScreen` navigation.

## Glossary

- **Bug_Condition (C)**: The set of inputs/states that trigger an Electronics defect — a
  device sale with a missing/duplicate serial, an Electronics user reaching a guarded
  device screen, a dashboard rendering a hardcoded count, etc.
- **Property (P)**: The correct behavior for inputs in `C` — reject the duplicate/blank
  serial, render the screen, compute warranty expiry, show a real count, etc.
- **Preservation**: Existing behavior for all inputs NOT in `C`, especially every
  `mobileShop` / `computerShop` path and every shared-file branch, which must be identical
  after the fix (`F(X) = F'(X)`).
- **F / F'**: The original (unfixed) and fixed code paths.
- **RID**: The required ID pattern for all new entity IDs:
  `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
- **paise (integer money)**: All new currency values are integer paise; no float/double for
  money in new code.
- **tenant-scoped query**: Every new read/write is filtered by the active tenant
  (`userId`/`vendorId` as confirmed in Phase 0); no `vendorId:'SYSTEM'` and no unscoped read.
- **`IMEISerials`**: Drift table (`core/database/tables.dart`) tracking each device unit
  (`id`, `userId`, `imeiOrSerial`, `type`, `status`, `warrantyMonths`, `warrantyStartDate`,
  `warrantyEndDate`, `productId`, `billId`, `purchaseDate`, `purchasePrice`); unique key
  `{userId, imeiOrSerial}`.
- **`IMEISerialRepository`**: `features/service/data/repositories/imei_serial_repository.dart`
  — read/write access to `IMEISerials` (`getByNumber(userId, serial)` etc.).
- **CapabilityGate / BusinessGuard / VendorRoleGuard**: The three layered route guards in
  `legacy_routes.dart` — business-type allow-list, capability predicate, and RBAC
  permission respectively.
- **`_getRetailSections()` / `_getMobileShopSections()` / `_getElectronicsSections()`**:
  Sidebar section builders in `sidebar_configuration.dart`. The last is NEW (Phase 4).

## Bug Details

### Bug Condition

The Electronics vertical exhibits a family of defects spanning data integrity, reachability,
navigation, dashboard truthfulness, RBAC, and validation. Each is triggered when an
Electronics-context input meets the condition for its clause group. The unifying formal
predicate:

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input — one of {BillLineSave, ScreenNavigation, SidebarRender,
                          DashboardRender, RbacView, ReturnSave, HsnEntry}
                 carrying businessType, and context-specific fields
  OUTPUT: boolean

  IF input.businessType != BusinessType.electronics THEN
    RETURN false            // only Electronics is in scope (preservation domain)
  END IF

  RETURN
    // Phase 1 — serial integrity at billing
    (input IS BillLineSave AND input.isDeviceLine AND
       (input.serial IS blank OR duplicateOrSold(input.serial, input.tenantId)))
    // Phase 2 — device-screen reachability
    OR (input IS ScreenNavigation AND
        input.target IN {Warranty, SerialHistory, ImeiTracking, ServiceJob} AND
        NOT reachableForElectronics(input.target))
    // Phase 3 — warranty/serial persistence at POS
    OR (input IS BillLineSave AND input.isDeviceLine AND
        NOT (warrantyExpiryComputed(input) AND serialInventoryLinked(input)))
    // Phase 4 — sidebar relevance
    OR (input IS SidebarRender AND sidebarIs(_getRetailSections) AND
        missingDeviceEntries(input))
    // Phase 5 — dashboard data truthfulness
    OR (input IS DashboardRender AND countIsHardcodedLiteral(input))
    // Phase 6 — RBAC gating
    OR (input IS RbacView AND sensitiveItem(input) AND input.permission IS null)
    // Phase 7 — returns / serial-stock / a11y / HSN
    OR (input IS ReturnSave AND input.isDeviceLine AND NOT serialValidated(input))
    OR (input IS HsnEntry AND NOT hsnFormatValidated(input))
END FUNCTION
```

A fix is correct when, for every `input` with `isBugCondition(input) = true`, the fixed
code produces the matching `2.x` property, AND for every `input` with
`isBugCondition(input) = false` (all non-Electronics paths and all Electronics happy-path
inputs), the fixed code is byte-for-byte behaviorally identical to the original.

### Examples

- **Blank serial accepted (1.6):** Electronics user adds a phone with the Serial field empty
  → expected: rejected with "Serial required for electronics"; actual: line saved silently.
- **Duplicate IMEI accepted (1.5):** Same IMEI billed twice in one tenant → expected:
  rejected against `IMEISerials` `{userId, imeiOrSerial}`; actual: `billing_service.dart`
  stub `// Strict 1:1 validation could go here` accepts it.
- **Warranty screen denied (1.8 / D6):** Electronics user opens `/computer-shop/warranty` →
  expected: WarrantyScreen renders; actual: `BusinessGuard(allowedTypes:[computerShop,
  mobileShop])` denies "Warranty is available for: Computer Shop, Mobile Phone Shop."
- **Orphaned IMEI tracking (1.9):** Electronics user looks for serial tracking →
  `ImeiTrackingStatementScreen` has no route/sidebar entry; unreachable.
- **Hardcoded alerts (1.17):** Electronics dashboard shows "Warranty Expiring 5" /
  "Pending Repairs 8" — string literals in `business_alerts_widget.dart`, never queried.
- **Dead button (1.18):** "IMEI Lookup" quick action `onTap: () {}` — no feedback.
- **Edge — valid unique serial (NOT in C):** A device billed with a unique, non-blank
  serial must still complete exactly as today (Preservation 3.5).

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors (must remain identical after every phase):**
- All `mobileShop` and `computerShop` behavior: their sidebars (`_getMobileShopSections()`
  and the `computerShop` `_getRetailSections()` case), route guards (now
  `[computerShop, mobileShop]` on warranty/serial-history), capability sets, and shared
  billing/entry-sheet branches.
- The `mobileShop`-only non-empty serial validator and the
  `businessType.name.contains('mobile')` async duplicate check (Regression 3.2).
- The existing `warrantyMonths` `0..120` whole-number validation (D2 / Regression 3.3).
- The Electronics config: priceLabel "MRP", `defaultGstRate 18.0`, `gstEditable false`,
  required `itemName/quantity/price/brand/hsnCode` (Regression 3.4).
- The Electronics happy path: a unique, valid serial completes the sale and writes the bill
  line exactly as today (Regression 3.5).
- Every other business type's dashboard, alerts, quick actions, RBAC, and the generic
  inventory/returns/reports/backup screens (Regression 3.6, 3.7).

**Scope:** All inputs where `isBugCondition` is false — every non-Electronics business type,
and every Electronics input outside the specific clause conditions — must be completely
unaffected. The correct behaviors per clause are enumerated in the matching `2.x`
requirements and realized by the phase-by-phase decisions in "Fix Implementation".

## Hypothesized Root Cause

1. **Shared-component grouping.** Electronics was bundled into `_getRetailSections()` (with
   `computerShop`) and the shared `business_alerts_widget` / `business_quick_actions`
   electronics+computerShop case, so it inherited a generic retail experience and never got
   device-specific navigation, alerts, or actions.
2. **Guard allow-lists exclude Electronics.** Device screens were built and wired for
   `computerShop` (later widened to `mobileShop`) but the `allowedTypes` and inner
   `CapabilityGate` allow-lists were never extended to `electronics`, despite Electronics
   holding `useIMEI` + `useWarranty`.
3. **Deferred integrity work.** Serial uniqueness (`billing_service.dart` stub), serial
   inventory linkage, and warranty-expiry computation at POS were left as TODOs; the real
   `IMEISerials` table and `getImeiTrackingStatement` query exist but are not written/read
   by the Electronics sale path.
4. **Placeholder dashboard data.** Electronics alert counts were stubbed as literals
   (`'5'`, `'8'`) and the IMEI Lookup action was stubbed (`onTap: () {}`) pending a real
   data source.
5. **Missing RBAC metadata.** `_getRetailSections()` items set only optional `capability`,
   never `permission`, so the RBAC filter cannot hide sensitive items.

## Correctness Properties

> Single source of truth for PBT traceability. Each phase contributes one Bug-Condition
> property (the `2.x` correction) and relies on the global Preservation property (Property
> 1) for `F(X)=F'(X)` on non-triggering inputs. All new persistence in every property must
> honor the non-negotiable constraints (integer-paise money, RID ids, tenant-scoped
> queries, idempotent migrations, no schema change/hard delete without sign-off).

Property 1: Preservation — Non-Electronics and Electronics-happy-path behavior unchanged

_For any_ input where `isBugCondition(input)` is false (any non-Electronics business type,
or an Electronics input outside a clause condition — including a unique, valid, non-blank
device serial), the fixed code SHALL produce exactly the same result as the original code,
preserving all `mobileShop`/`computerShop` sidebars, guards, capabilities, shared
billing/entry-sheet branches, the `0..120` warranty validation, and the Electronics MRP/18%
config.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

Property 2: Phase 0 — Investigation gates resolved before action

_For any_ later-phase assumption (route mounting, capability-vs-guard access decision,
`getImeiTrackingStatement` tenant scope, live route-file location), the system SHALL produce
a documented, evidence-based finding and SHALL block the dependent phase until the finding
confirms the assumption.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

Property 3: Phase 1 — Serial/IMEI uniqueness and required-at-billing

_For any_ Electronics device bill line where the serial is blank OR duplicates an existing
tenant-scoped `IMEISerials` record in a sold/active state, the fixed code SHALL reject the
line with a clear validation error; for a unique non-blank serial it SHALL accept it
unchanged.

**Validates: Requirements 2.5, 2.6, 2.7**

Property 4: Phase 2 — Device screens reachable for Electronics

_For any_ Electronics navigation to Warranty, Serial-History, IMEI/Serial Tracking, or
Service/Repair Jobs, the fixed code SHALL render the screen (via the Phase 0 access
decision: widen `BusinessGuard` + inner `CapabilityGate` allow-lists, and add a route +
sidebar entry for the previously orphaned `ImeiTrackingStatementScreen`), backed by a
tenant-scoped query.

**Validates: Requirements 2.8, 2.9, 2.10**

Property 5: Phase 3 — Warranty/serial data integrity at point of sale

_For any_ Electronics device sale with a valid `warrantyMonths`, the fixed code SHALL compute
warranty expiry as `sale_date + warrantyMonths`, persist it as the single source of truth,
create/link the corresponding tenant-scoped RID-patterned `IMEISerials` record, and decrement
serial-level stock for the unit sold.

**Validates: Requirements 2.11, 2.12, 2.13**

Property 6: Phase 4 — Dedicated Electronics sidebar and correct id resolution

_For any_ Electronics sidebar render, the fixed code SHALL show a dedicated Electronics
section containing the device-relevant entries (Serial/IMEI Tracking, Warranty Register,
Service/Repair Jobs, Returns-with-serial) without surfacing clearly-irrelevant retail-only
items, without altering the `mobileShop`/`computerShop` sidebars, and SHALL ensure ids map
to their intended screens (`audit_trail` not presented as a real audit log unless backed by
one).

**Validates: Requirements 2.14, 2.15, 2.16**

Property 7: Phase 5 — Dashboard data truthfulness

_For any_ Electronics dashboard render, the fixed code SHALL compute alert counts from real
tenant-scoped queries (warranty-expiring from `IMEISerials.warrantyEndDate`; pending repairs
from the service-job source) instead of hardcoded literals, navigate the "IMEI Lookup"
action to a functional destination, and only run alert queries whose results are displayed.

**Validates: Requirements 2.17, 2.18, 2.19**

Property 8: Phase 6 — RBAC permission gating

_For any_ non-privileged role viewing the Electronics sidebar, the fixed code SHALL hide
sensitive items (`audit_trail`, `bank_accounts`, `backup`, `expenses`,
`accounting_reports`) by assigning each a `permission`, and the "New Repair" quick action
SHALL apply the same `manageStaff` authority as the `/job/*` route guard.

**Validates: Requirements 2.20, 2.21**

Property 9: Phase 7 — Returns, serial-stock view, accessibility, HSN

_For any_ Electronics sales return of a device line, the fixed code SHALL validate the
returned serial (exists, tenant-scoped, was sold) before accepting it; SHALL provide a
serial-wise stock view; SHALL expose `Semantics`/tooltips and accessible state on
quick-action buttons; and SHALL validate HSN length/format, rejecting malformed values.

**Validates: Requirements 2.22, 2.23, 2.24, 2.25**

Property 10: Phase 8 — Cleanup and end-to-end regression

_For any_ completed remediation state, the fixed code SHALL have removed the mislabeled id
aliases and dead code/queries addressed above and SHALL confirm via end-to-end verification
that all earlier fixes hold and shared `mobileShop`/`computerShop` behavior is unchanged.

**Validates: Requirements 2.26, 3.1**

## Fix Implementation

Each phase below maps its correction clauses (`2.x`) and the relevant regression clauses
(`3.x`) to concrete technical decisions: the exact screen / route / guard / capability /
table / migration / sidebar / dashboard change that implements it, the shared files touched
(flagged), and the blast radius. Phases execute in order as STOP GATES per the steering
operating rules: after each phase, list touched files, run `flutter analyze`, report
results, then halt for `APPROVED`.

### Shared-file ledger (flagged; preserve non-Electronics branches)

| File | Shared with | Electronics-only change | Preservation guarantee |
|---|---|---|---|
| `features/billing/services/billing_service.dart` | mobileShop, computerShop | Replace electronics IMEI stub with tenant-scoped uniqueness + serial-record write | mobileShop/computerShop branches and the SKU path untouched |
| `features/billing/presentation/widgets/manual_item_entry_sheet.dart` | mobileShop, computerShop, clothing | Add electronics serial `validator` + HSN format validator | mobileShop validator, `0..120` warranty validator, clothing branch untouched |
| `widgets/desktop/sidebar_configuration.dart` | all verticals | New `_getElectronicsSections()` + split electronics out of the computerShop-grouped case | `_getRetailSections()`, `_getMobileShopSections()`, computerShop case, `default` untouched |
| `features/dashboard/v2/widgets/business_alerts_widget.dart` | electronics+computerShop case | New electronics snapshot provider + electronics branch | computerShop branch and all other vertical providers untouched |
| `features/dashboard/v2/widgets/business_quick_actions.dart` | electronics+others | Wire IMEI Lookup; guard New Repair | other branches untouched |
| `core/routing/legacy_routes.dart` | all verticals | Add `electronics` to warranty/serial-history allow-lists; new ImeiTracking route | mobileShop/computerShop allow-lists preserved (only extended) |

### Phase 0 — Investigation & reachability (read-only STOP GATE) — clauses 1.1–1.4 / 2.1–2.4

No behavior changes. Produce a written findings record (the "Phase 0 findings" above is the
design-time draft; execution re-confirms each at task time and records evidence):

- **2.1 (route mounting):** Confirm each of `/computer-shop/warranty`,
  `/computer-shop/serial-history`, `/computer-shop/multi-unit`, `/job/create`,
  `/job/status`, `/job/deliver` is a live `GoRoute` in `legacy_routes.dart` and is mounted
  on the active router (grep + confirm the router that `MaterialApp.router`/`GoRouter` uses;
  reconcile with the sibling-audit "GoRouter not mounted" note). Block Phase 2 route edits
  until confirmed.
- **2.2 (access decision per screen):** Decide, per screen, grant-by-allow-list vs.
  grant-by-capability. Verified inputs: Electronics holds `useIMEI` + `useWarranty` (so
  Warranty/Serial-History/ImeiTracking need only allow-list widening — D6); Electronics
  lacks `useMultiUnit` (so Multi-Unit needs an explicit capability grant or is parked);
  `useBuyback`/`useExchange` remain parked (out of scope).
- **2.3 (`getImeiTrackingStatement` tenant scope):** Confirm whether `userId` is the correct
  tenant boundary or a `vendorId` filter must be added (D4). Require a tenant-scoped,
  non-`SYSTEM` filter before wiring the screen in Phase 2.
- **2.4 (route-file location):** Record the corrected live file
  (`core/routing/legacy_routes.dart`) and ignore the stale `app/routes.dart` line citations
  (D3).

**Deliverable:** `phase-0-findings` notes appended to the spec; STOP for `APPROVED`.

### Phase 1 — Serial/IMEI uniqueness & required-at-billing (CRITICAL) — 1.5–1.7 / 2.5–2.7

- **2.5 (uniqueness):** In `billing_service.dart`, replace the electronics stub
  (`// Strict 1:1 validation could go here`) with a tenant-scoped uniqueness check via
  `IMEISerialRepository.getByNumber(tenantId, serial)` (leveraging the existing
  `{userId, imeiOrSerial}` unique key as the DB backstop). Reject when an existing record is
  in a sold/active conflict status; surface a clear validation error. Mirror the proven
  `mobileShop` pattern already present in `manual_item_entry_sheet.dart` so behavior is
  consistent across the family. No schema change.
- **2.6 (blank rejected):** In `manual_item_entry_sheet.dart`, set the serial-field
  `validator` to non-empty-required for `BusinessType.electronics` device lines (currently
  `null`; D1). Reuse the mobileShop message style.
- **2.7 (conditionally required):** Treat `serialNo` as conditionally required for
  Electronics device lines at billing (validation-layer enforcement; config field stays
  optional to avoid a schema/config change without sign-off).
- **Preservation:** mobileShop validator + `contains('mobile')` async check untouched
  (3.2); `0..120` warranty validator untouched (3.3); unique-valid happy path completes
  unchanged (3.5). Money stays integer paise; any new id RID-patterned; check is
  tenant-scoped (3.8).

### Phase 2 — Reachability of device screens (CRITICAL) — 1.8–1.10 / 2.8–2.10

- **2.8 (Warranty/Serial-History/Multi-Unit):** In `legacy_routes.dart`, add
  `BusinessType.electronics` to BOTH the `BusinessGuard.allowedTypes` AND the inner
  `CapabilityGate.allowedTypes` for `/computer-shop/warranty` and
  `/computer-shop/serial-history` (D6; Electronics already holds `useWarranty`/`useIMEI`).
  Update the `denialMessage` strings to include Electronics. For `/computer-shop/multi-unit`
  (currently `[computerShop]` only, and Electronics lacks `useMultiUnit`), apply the Phase 0
  decision — either grant `useMultiUnit` to electronics in `business_capability.dart` and
  widen both allow-lists, or park Multi-Unit and document the deferral.
- **2.9 (ImeiTracking):** Add a new `GoRoute` (e.g. `/electronics/imei-tracking`) in
  `legacy_routes.dart` wrapping `ImeiTrackingStatementScreen` in
  `VendorRoleGuard(viewInvoices) → BusinessGuard([electronics, ...]) →
  CapabilityGate(useIMEI)`, backed by the tenant-scoped `getImeiTrackingStatement` confirmed
  in Phase 0 (2.3). Add the matching sidebar id in Phase 4.
- **2.10 (Service/Repair jobs):** No route change needed — `/job/*` already allow
  Electronics + `manageStaff` (D7). Surface them via a Phase 4 sidebar entry.
- **Preservation:** Only allow-lists are extended (never narrowed); computerShop/mobileShop
  access preserved (3.1, 3.6).

### Phase 3 — Warranty & serial data integrity at POS (HIGH) — 1.11–1.13 / 2.11–2.13

- **2.11 (warranty expiry at POS):** In the Electronics sale path (`billing_service.dart`),
  compute `warrantyEndDate = sale_date + warrantyMonths` and persist to `IMEISerials`
  (`warrantyStartDate`, `warrantyEndDate`, `isUnderWarranty`) as the single source of truth
  that feeds `getImeiTrackingStatement`. The columns already exist — no schema change.
- **2.12 (serial inventory record):** On sale, create/link the `IMEISerials` record for the
  unit (RID-patterned `id`, tenant-scoped `userId`, `billId`, `productId`, `status=SOLD`,
  `purchasePrice` in integer paise for new writes) via `IMEISerialRepository`.
- **2.13 (serial-level stock):** Decrement serial-level stock for the specific unit sold (set
  the unit's `status` to `SOLD`) in addition to the existing SKU quantity decrement; the SKU
  decrement path is preserved.
- **Preservation:** SKU stock decrement and bill-line write unchanged for non-device lines
  and for mobileShop/computerShop (3.1, 3.7). Constraints: integer paise, RID ids,
  tenant-scoped, idempotent — if any new column/table is genuinely required it is a
  sign-off-gated migration, not a silent change (3.8).

### Phase 4 — Electronics sidebar & navigation (HIGH; aliasing MED-LOW) — 1.14–1.16 / 2.14–2.16

- **2.14 (dedicated section):** In `sidebar_configuration.dart`, split `electronics` out of
  the `electronics + computerShop` case (D5) into a new `_getElectronicsSections()`,
  mirroring the structure of `_getMobileShopSections()`. The `computerShop` case stays on
  `_getRetailSections()` unchanged; the `default` branch is untouched.
- **2.15 (device entries; trim irrelevant):** `_getElectronicsSections()` includes
  Serial/IMEI Tracking (→ new ImeiTracking route, 2.9), Warranty Register (→
  `/computer-shop/warranty`, now reachable, 2.8), Service/Repair Jobs (→ `/job/*`, 2.10),
  Returns-with-serial (→ Phase 7), plus the shared common sections; it omits clearly
  irrelevant retail-only ids (`funds_flow`, `filing_status`, `ledger_abstract`, `b2b_b2c`).
- **2.16 (id resolution):** Ensure each new Electronics id maps to its intended screen; do
  NOT carry the `audit_trail`→`AllTransactionsScreen` alias into the Electronics section as a
  "real audit log" (either omit it or label it accurately; a real audit log is Phase 8/parked
  unless backed by one).
- **Preservation:** `_getRetailSections()`, `_getMobileShopSections()`, computerShop case,
  and every other vertical's case unchanged (3.1, 3.6). BLAST RADIUS: one new case + one new
  builder function.

### Phase 5 — Dashboard data integrity (HIGH; wasted query LOW) — 1.17–1.19 / 2.17–2.19

- **2.17 (real counts):** Add an `electronicsAlertCountsProvider` (mirroring
  `mandiAlertCountsProvider` / `schoolAlertCountsProvider` per-vertical snapshot pattern
  already in `business_alerts_widget.dart`, and reusing the existing
  `imeiInStockCount`/`openWarrantyClaims` snapshot scaffolding where present). Compute
  warranty-expiring from tenant-scoped `IMEISerials.warrantyEndDate` and pending repairs from
  the service-job source. Replace the hardcoded `'5'`/`'8'` literals in the
  electronics+computerShop branch with the snapshot values, with an unavailable/`...`
  indicator on query failure (matching the established pattern).
- **2.18 (IMEI Lookup):** In `business_quick_actions.dart`, replace `onTap: () {}` with
  navigation to the functional serial/IMEI lookup destination (the ImeiTracking route from
  2.9, or Serial-History).
- **2.19 (no wasted queries):** Ensure Electronics only runs the alert queries whose results
  are displayed (drive the dashboard from `electronicsAlertCountsProvider`; don't run the
  generic `alertCountsProvider` lowStock/expiringSoon queries for Electronics if unused).
- **Preservation:** The shared electronics+computerShop case must keep computerShop's
  existing behavior — gate the new provider on `businessType == electronics` so computerShop
  is unaffected (3.6). All counts from tenant-scoped queries (3.8).

### Phase 6 — RBAC permission gating (HIGH; layering MED) — 1.20–1.21 / 2.20–2.21

- **2.20 (sensitive-item permissions):** Assign a `permission` to the sensitive items in the
  Electronics section (`audit_trail`, `bank_accounts`, `backup`, `expenses`,
  `accounting_reports`) so the existing RBAC filter in `sidebarSectionsProvider` hides them
  from unauthorized roles. Applied within `_getElectronicsSections()` so no other vertical's
  items are touched.
- **2.21 (quick-action/route agreement):** Route the dashboard "New Repair" quick action
  through the same `manageStaff`-guarded path as `/job/*` (D7) — navigate via the guarded
  `/job/create` route / the `VendorRoleGuard(manageStaff)`-wrapped in-shell `job_create`
  case rather than a raw `AppScreen.serviceJobs` navigation that bypasses the check.
- **Preservation:** RBAC behavior for all other verticals unchanged (3.6).

### Phase 7 — Returns, serial-stock view & accessibility (HIGH; semantics/HSN MED-LOW) — 1.22–1.25 / 2.22–2.25

- **2.22 (return serial validation):** In the Electronics return flow, validate the returned
  device serial against `IMEISerials` (exists, tenant-scoped, was sold) before accepting the
  return line; on accept, transition the unit's `status` to `RETURNED`.
- **2.23 (serial-wise stock view):** Provide a serial-wise stock view for Electronics
  (a `status`-filtered `IMEISerials` list, reachable from the Electronics sidebar). Broader
  multi-warehouse/FIFO/BOM remains parked.
- **2.24 (accessibility):** Add `Semantics`/tooltips and accessible state to the Electronics
  quick-action buttons in `business_quick_actions.dart` (including a meaningful state for the
  now-wired IMEI Lookup button).
- **2.25 (HSN validation):** In `manual_item_entry_sheet.dart`, add a length/format
  `validator` to the HSN field (currently labeled "Optional" with no validator) and reject
  malformed values.
- **Preservation:** Generic return/inventory screens for other verticals unchanged (3.7);
  HSN validator added without changing the required-field config (3.4).

### Phase 8 — Cleanup & final regression verification — 1.26 / 2.26

- **2.26 (cleanup + e2e):** Remove the mislabeled id aliases and dead code/queries addressed
  above; run the full property/regression suite end-to-end; confirm all earlier fixes hold
  and that `mobileShop`/`computerShop` behavior (sidebars, guards, capabilities, shared
  billing/entry-sheet branches) is byte-for-byte unchanged (Preservation 3.1).

## Testing Strategy

### Validation Approach

Two-phase per defect: first surface counterexamples that demonstrate the bug on the UNFIXED
code (exploratory bug-condition checking), then verify the fix produces the correct property
AND preserves all non-triggering behavior. Because the change set spans many shared files,
**preservation checking is the dominant safety net** and is property-based wherever the input
domain is large (all business types × all inputs).

### Exploratory Bug Condition Checking

**Goal:** Surface counterexamples BEFORE fixing, to confirm/refute each root cause. If
refuted, re-hypothesize before coding.

**Test Cases (run on UNFIXED code; expected to fail/expose the defect):**
1. **Blank serial (1.6):** Save an Electronics device line with empty serial → today: accepted.
2. **Duplicate IMEI (1.5):** Bill the same IMEI twice in one tenant → today: accepted (stub).
3. **Warranty denied (1.8):** Navigate Electronics to `/computer-shop/warranty` → today:
   denied by `BusinessGuard([computerShop, mobileShop])`.
4. **Orphan IMEI tracking (1.9):** Resolve a route/sidebar id for `ImeiTrackingStatementScreen`
   → today: none exists.
5. **Warranty expiry at POS (1.11):** Sell with `warrantyMonths` → today: no
   `warrantyEndDate` written / no reachable tracker.
6. **Hardcoded alerts (1.17):** Render Electronics dashboard with empty DB → today: still
   shows "5"/"8".
7. **Dead button (1.18):** Tap IMEI Lookup → today: nothing.
8. **RBAC (1.20):** View Electronics sidebar as cashier → today: sees `audit_trail`/`backup`.
9. **HSN (1.25):** Enter malformed HSN → today: accepted.

**Expected Counterexamples:** acceptance of blank/duplicate serials; access-denied for
Electronics on built device screens; literal dashboard counts; unreachable IMEI tracking.
Probable causes: guard allow-lists excluding electronics; billing stub; literal UI strings.

### Fix Checking

**Goal:** For all inputs where the bug condition holds, the fixed code produces the property.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := fixed(input)
  ASSERT expectedBehavior(result)   // the matching 2.x property (P2..P8)
END FOR
```

### Preservation Checking

**Goal:** For all inputs where the bug condition does NOT hold, the fixed code equals the
original.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT original(input) = fixed(input)
END FOR
```

**Approach:** Property-based testing is preferred for preservation because the
non-triggering domain is huge (every non-Electronics `BusinessType` × every input kind) and
edge-prone. Generate random `(businessType, input)` pairs with
`businessType != electronics` (plus Electronics happy-path serials) and assert sidebar
sections, route-guard decisions, capability sets, dashboard counts, and billing results are
identical to a pre-change snapshot. Observe behavior on UNFIXED code first, then lock it in.

**Preservation Test Cases:**
1. **mobileShop/computerShop sidebars:** `getSectionsForBusinessType(mobileShop|computerShop)`
   unchanged vs. snapshot (3.1).
2. **mobileShop serial validator + duplicate check:** still enforced (3.2).
3. **Warranty `0..120` validation:** still present and unchanged (3.3, D2).
4. **Electronics config:** MRP / 18% / `gstEditable false` / required fields unchanged (3.4).
5. **Unique-valid Electronics serial:** sale completes and writes bill line as before (3.5).
6. **Other verticals' dashboards/guards/RBAC:** unchanged across random generation (3.6, 3.7).

### Unit Tests

- Serial validator: blank rejected for electronics; mobileShop message preserved; null path
  for clothing unchanged.
- `billing_service` uniqueness: duplicate/sold serial rejected; unique accepted; non-device
  line unaffected.
- Warranty expiry: `warrantyEndDate == saleDate + warrantyMonths`; `0` and `120` boundaries.
- Route guards: electronics allowed on warranty/serial-history/imei-tracking/job-*;
  computerShop/mobileShop still allowed; unrelated types still denied.
- Sidebar: `_getElectronicsSections()` contains device entries and the RBAC `permission` on
  sensitive items; `_getRetailSections()` unchanged.
- HSN validator: malformed rejected, valid accepted.

### Property-Based Tests

- **P0 Preservation:** random `(businessType ≠ electronics, input)` → fixed == original for
  sidebar/guard/capability/dashboard/billing.
- **P2 Uniqueness:** random serial multiset within a tenant → no two active records share a
  serial after billing; blanks always rejected.
- **P3 Reachability:** for every device target, electronics resolves to render (never deny).
- **P4 Warranty/serial:** random `warrantyMonths ∈ 0..120` and sale dates → expiry exact;
  exactly one `IMEISerials` record per unit; serial stock decremented once.
- **P7 Returns:** random serials → only sold, tenant-scoped serials accepted on return.

### Integration Tests

- Full Electronics sale → serial recorded → appears in IMEI Tracking → warranty expiry shows
  in the tracker and dashboard "Warranty Expiring" count.
- Electronics navigates sidebar → Warranty / Serial-History / Service Jobs / IMEI Tracking
  all render; cashier role does not see gated sensitive items.
- New Repair quick action enforces `manageStaff` consistently with `/job/create`.
- Cross-vertical smoke: mobileShop and computerShop full flows unchanged end-to-end (3.1).
