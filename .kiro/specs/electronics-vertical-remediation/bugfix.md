# Bugfix Requirements Document

## Introduction

The **Electronics ("Mobile / Electronics", `BusinessType.electronics`)** vertical in the DukanX
Flutter app is the headline electronics business type yet ships the least dedicated, correct
behavior of the electronics family. Device-defining features (IMEI/serial tracking, warranty
register, serial history, multi-unit, service/repair jobs) are either denied to electronics by
route guards, fully orphaned (built but unreachable), faked with hardcoded data, or unsafe
(serial uniqueness is a stub). This remediation fixes those defects across a phased plan while
preserving the behavior of every other business type and every screen shared with `mobileShop`
and `computerShop`.

This document captures **only** the bug conditions, expected corrections, and behavior that must
be preserved. Technical/design decisions (which screen to build vs. which guard to broaden, table
shapes, migrations, route wiring) belong in `design.md`, not here.

### Authoritative source and live-code re-verification

The authoritative audit is `audit-reports/business-types/audit-electronics.md`. Per the operating
rules, claims were re-verified against the current code. The following **discrepancies between the
audit text and the current code** were found and are reflected in the requirements below — they
must NOT be acted on as written in the stale audit:

- **D1 — Serial field validator (audit §14 "no validator"):** `manual_item_entry_sheet.dart`
  (line ~354) DOES attach a `validator`, but it is `null` for electronics and computerShop and
  only non-empty-required for `mobileShop`. So the real defect for electronics is "blank serial
  silently accepted," not "no validator at all." Duplicate serials are unchecked **everywhere**
  (no async uniqueness anywhere in the billing path).
- **D2 — Warranty-months range validation (audit §14 "no range check, negative silently
  dropped"):** STALE. `manual_item_entry_sheet.dart` (line ~372) already validates that warranty
  months parse to a whole number and fall in `0..120`. UI range validation is therefore an
  **unchanged/preserved** behavior, not a defect. The real warranty defect is that expiry is not
  **computed at point of sale** and does not flow into any reachable tracker.
- **D3 — Route file location (audit §6 cites `app/routes.dart` lines 1110–1142):** Routing was
  refactored. The computer-shop guards now live in `core/routing/legacy_routes.dart` (a stale
  `route_results.csv` audit artifact confirms `/computer-shop/warranty` → `BusinessGuard`,
  `computerShop`, `viewInvoices`). Phase 0 must reconfirm the exact, live location before any
  guard edit.
- **D4 — IMEI tracking query tenant scope:** `statements_repository.getImeiTrackingStatement`
  scopes by `userId` only (`i.userId.equals(userId)`), with no `vendorId`/tenant filter visible
  in the query. Given DukanX's history of `vendorId:'SYSTEM'` tenant-isolation leaks, the tenant
  correctness of this query is **unverified** and is a Phase 0 investigation gate before the
  screen is wired.

### Bug condition methodology and phase / STOP-GATE structure

Each defect below is framed as a bug condition `C(X)` (inputs that trigger the bug), a property
`P(result)` (correct behavior on those inputs), and a preservation goal (`F(X) = F'(X)` for all
non-triggering inputs). Defects are grouped to map onto the phased remediation plan. **Each phase
is a STOP GATE:** the phase is executed in order, every touched file is listed, `flutter analyze`
is run and reported, and work halts for `APPROVED` before the next phase begins. Phase 0 is
read-only investigation whose "fix" is a verified, documented answer to each precondition — no
behavior changes until Phase 0 findings confirm the assumptions in later phases.

| Phase | Theme | Clause groups |
|---|---|---|
| 0 | Investigation & reachability (read-only, STOP GATE) | 1.1–1.4 / 2.1–2.4 |
| 1 | Serial/IMEI uniqueness & required-at-billing (CRITICAL) | 1.5–1.7 / 2.5–2.7 |
| 2 | Reachability of device screens (CRITICAL) | 1.8–1.10 / 2.8–2.10 |
| 3 | Warranty & serial data integrity at POS (HIGH) | 1.11–1.13 / 2.11–2.13 |
| 4 | Electronics sidebar & navigation (HIGH / MED-LOW) | 1.14–1.16 / 2.14–2.16 |
| 5 | Dashboard data integrity (HIGH / LOW) | 1.17–1.19 / 2.17–2.19 |
| 6 | RBAC permission gating (HIGH / MED) | 1.20–1.21 / 2.20–2.21 |
| 7 | Returns, serial-stock view & accessibility (HIGH / MED-LOW) | 1.22–1.25 / 2.22–2.25 |
| 8 | Cleanup & final regression verification | 1.26 / 2.26 |

### Non-negotiable constraints (apply to every fix)

- All money is **integer paise**; never float/double for currency in new code.
- New entity IDs use the **RID pattern** `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
- **Every query is tenant-scoped.** No new query may rely on `vendorId:'SYSTEM'` or an unscoped
  read.
- **No schema change without sign-off; no hard deletes without sign-off.** Migrations must be
  idempotent.
- Any file shared with `mobileShop`/`computerShop` must be flagged, and their existing behavior
  preserved identically.

### Out of scope (parked — do not build)

EMI/finance billing, e-Way bill, exchange/buyback, accessory bundling, extended-warranty upsell,
demo/display-unit tracking, loyalty points, multi-warehouse/FIFO/BOM. (Serial-wise stock view IS
in scope; broader warehouse logic is parked.)

## Bug Analysis

### Current Behavior (Defect)

> Clauses are grouped by remediation phase. Each `1.x` defect has a matching `2.x` correction.

**Phase 0 — Investigation & reachability (read-only STOP GATE)**

1.1 WHEN the electronics device routes (`/computer-shop/warranty`, `/computer-shop/serial-history`,
`/computer-shop/multi-unit`, `/job/create`, `/job/status`, `/job/deliver`) are inspected THEN the
system has no confirmed answer to whether they are mounted on the live router (`MaterialApp.routes`
vs `GoRouter` disconnect), so any later "wire/broaden a route" assumption is unverified.

1.2 WHEN electronics' access to device screens is considered THEN `BusinessGuard.allowedTypes`
excludes electronics for `/computer-shop/*`, AND the capability registry grants electronics
`useIMEI` + `useWarranty` but NOT `useMultiUnit`, `useJobSheets`, `useRepairStatus`, `useBuyback`,
or `useExchange`, so it is unconfirmed whether each target screen is safe to grant by capability.

1.3 WHEN `statements_repository.getImeiTrackingStatement` runs THEN it filters only by `userId`
with no visible tenant/`vendorId` scope, so its tenant-isolation correctness is unverified given
the known `vendorId:'SYSTEM'` leak history.

1.4 WHEN the audit's route citations are used THEN they point to `app/routes.dart` line numbers
that no longer match the refactored `core/routing/legacy_routes.dart`, so acting on the audit's
locations directly would edit the wrong/stale file.

**Phase 1 — Serial/IMEI uniqueness & required-at-billing (CRITICAL)**

1.5 WHEN an electronics bill line is saved with a serial/IMEI THEN `billing_service.dart`
(lines ~124–127) performs no uniqueness enforcement — it contains only the stub comment
`// Strict 1:1 validation could go here` — so duplicate or already-sold IMEIs are accepted.

1.6 WHEN an electronics item is entered via `manual_item_entry_sheet.dart` THEN the serial field's
`validator` is `null` for electronics (non-empty is required only for `mobileShop`), so a blank
serial is silently accepted for a device sale.

1.7 WHEN an electronics device is billed THEN `serialNo` is an optional config field and is not
conditionally required at billing, so a device can be sold with no serial recorded at all.

**Phase 2 — Reachability of device screens (CRITICAL)**

1.8 WHEN an electronics user attempts to reach Warranty, Serial-History, or Multi-Unit THEN the
`/computer-shop/*` routes are guarded by `BusinessGuard(allowedTypes: [computerShop])` and deny
electronics, so the built `WarrantyScreen`, `SerialHistoryScreen`, and `MultiUnitScreen` are
unreachable for electronics.

1.9 WHEN an electronics user looks for IMEI/serial tracking THEN `ImeiTrackingStatementScreen`
(backed by the real `getImeiTrackingStatement` query) has no route and no sidebar entry anywhere,
so the feature is fully orphaned and unreachable.

1.10 WHEN service/repair jobs are considered THEN `/job/create`, `/job/status`, `/job/deliver`
allow electronics at the route guard but no sidebar item points to them, so they are reachable
only by an inconsistent dashboard quick action.

**Phase 3 — Warranty & serial data integrity at point of sale (HIGH)**

1.11 WHEN a device is sold with `warrantyMonths` THEN warranty expiry is not computed at point of
sale (no `sale_date + warrantyMonths` calculation, no single source of truth); expiry is computed
only inside the orphaned `ImeiTrackingStatementScreen`, so warranty entered at billing never flows
into any reachable expiry tracker.

1.12 WHEN a serial is captured at billing THEN it is written to the bill line (`imei: Value(...)`)
but is not linked to an `IMEISerialRepository` / `iMEISerials` record, so there is no serial
inventory record created or updated from the sale.

1.13 WHEN an electronics sale is committed THEN stock is decremented by SKU quantity only, not by
the specific serial sold, so serial-level stock state is never maintained.

**Phase 4 — Electronics sidebar & navigation (HIGH; aliasing MED-LOW)**

1.14 WHEN the electronics sidebar renders THEN `_getSectionsForBusiness()` groups electronics with
`mobileShop`/`computerShop` and returns the shared `_getRetailSections()`, so electronics shows a
generic retail menu with no electronics-specific section.

1.15 WHEN that generic sidebar is shown THEN it surfaces items irrelevant to a small electronics
counter (`funds_flow`, `filing_status`, `ledger_abstract`, `b2b_b2c`) AND omits the device-relevant
entries (Serial/IMEI Tracking, Warranty Register, Service/Repair Jobs, Returns-with-serial).

1.16 WHEN multiple sidebar ids are resolved THEN `turnover_analysis`, `daily_activity`,
`ledger_history`, `activity_logs`, `audit_trail`, and `transaction_reports` all alias the same
`AllTransactionsScreen`, so labels promise distinct screens that do not exist and `audit_trail` is
not a real audit log.

**Phase 5 — Dashboard data integrity (HIGH; wasted query LOW)**

1.17 WHEN the electronics dashboard alerts render THEN `business_alerts_widget.dart` shows
hardcoded literals ("Warranty Expiring" `count: '5'`, "Pending Repairs" `count: '8'`) that never
reflect real data.

1.18 WHEN the "IMEI Lookup" dashboard quick action is tapped THEN it does nothing (`onTap: () {}`),
giving the user no feedback or navigation.

1.19 WHEN the electronics dashboard loads THEN `alertCountsProvider` runs `lowStock` and
`expiringSoon` DB queries whose results are not displayed for electronics, so the queries are
wasted work.

**Phase 6 — RBAC permission gating (HIGH; layering MED)**

1.20 WHEN any non-privileged role (cashier/staff) views the electronics sidebar THEN sensitive
items (`audit_trail`, `bank_accounts`, `backup`, `expenses`, `accounting_reports`) carry no
`permission`, so the RBAC filter cannot hide them and every role sees them.

1.21 WHEN the "New Repair" quick action navigates THEN it routes via `AppScreen.serviceJobs`
without a capability/permission check, while the route-level `BusinessGuard` requires a different
authority — so the quick action and the route guard disagree on who may create a repair job.

**Phase 7 — Returns, serial-stock view & accessibility (HIGH; semantics/HSN MED-LOW)**

1.22 WHEN an electronics sales return (`return_inwards`) is processed THEN the generic return flow
performs no serial validation on returned device lines, so a return can reference a wrong, blank,
or never-sold serial.

1.23 WHEN an electronics user looks for stock by unit THEN there is no serial-wise stock view; only
generic SKU-quantity inventory screens exist.

1.24 WHEN quick-action buttons are presented to assistive technology THEN they are `InkWell`+`Text`
with no `Semantics`/tooltip (and the dead IMEI Lookup button exposes no accessible state), so they
are not properly described.

1.25 WHEN an HSN code is entered in `manual_item_entry_sheet.dart` THEN it is a required field but
has no length/format validation, so malformed HSN values are accepted.

**Phase 8 — Cleanup & final regression verification**

1.26 WHEN the remediation is complete THEN, absent a final pass, mislabeled id aliases, the unused
`alertCountsProvider` queries on electronics, and any leftover dead code/labels remain, and there
is no end-to-end confirmation that shared `mobileShop`/`computerShop` behavior is unchanged.

### Expected Behavior (Correct)

> Each `2.x` clause is the correct behavior for the matching `1.x` defect.

**Phase 0 — Investigation & reachability (read-only STOP GATE)**

2.1 WHEN the device routes are inspected THEN the system SHALL produce a documented, evidence-based
finding of whether each route is mounted on the live router, and SHALL block later phases that
assume route wiring until reachability is confirmed.

2.2 WHEN electronics' access to device screens is considered THEN the system SHALL document, per
target screen, whether access should be granted by broadening `BusinessGuard.allowedTypes` and/or
granting the missing capability (`useMultiUnit`/`useJobSheets`/`useRepairStatus`), and SHALL flag
that `useBuyback`/`useExchange` remain out of scope (parked).

2.3 WHEN `getImeiTrackingStatement` is reviewed THEN the system SHALL verify and document its
tenant scoping, and SHALL require a tenant-scoped (non-`SYSTEM`) filter before the screen is wired
in Phase 2.

2.4 WHEN route locations are referenced THEN the system SHALL use the live, re-confirmed file
(`core/routing/legacy_routes.dart` or its successor) rather than the stale `app/routes.dart`
citations, and SHALL report the corrected location.

**Phase 1 — Serial/IMEI uniqueness & required-at-billing (CRITICAL)**

2.5 WHEN an electronics bill line is saved with a serial/IMEI THEN the system SHALL enforce
tenant-scoped 1:1 uniqueness against `iMEISerials` and SHALL reject a duplicate or already-sold
serial with a clear validation error instead of accepting it.

2.6 WHEN an electronics item is entered with a blank serial THEN the system SHALL reject it with a
validation message (serial required for electronics device lines) rather than silently accepting it.

2.7 WHEN an electronics device is billed THEN the system SHALL treat `serialNo` as conditionally
required for electronics device lines so a device cannot be sold without a recorded serial.

**Phase 2 — Reachability of device screens (CRITICAL)**

2.8 WHEN an electronics user opens Warranty, Serial-History, or Multi-Unit THEN the system SHALL
make these screens reachable for electronics (via the Phase 0 access decision) so the built screens
are usable.

2.9 WHEN an electronics user opens IMEI/serial tracking THEN the system SHALL expose
`ImeiTrackingStatementScreen` via a real route and a sidebar entry, backed by the tenant-scoped
query confirmed in Phase 0.

2.10 WHEN service/repair jobs are needed THEN the system SHALL surface the already-allowed `/job/*`
routes through a consistent sidebar entry so navigation and the route guard agree.

**Phase 3 — Warranty & serial data integrity at point of sale (HIGH)**

2.11 WHEN a device is sold with a valid `warrantyMonths` THEN the system SHALL compute warranty
expiry at point of sale as `sale_date + warrantyMonths` and persist it as the single source of
truth that feeds the reachable expiry tracker.

2.12 WHEN a serial is captured at billing THEN the system SHALL create/link the corresponding
`iMEISerials` record (RID-patterned id, tenant-scoped) so the sale produces a serial inventory
record.

2.13 WHEN an electronics sale is committed THEN the system SHALL decrement stock for the specific
serial sold (in addition to SKU quantity) so serial-level stock state stays correct.

**Phase 4 — Electronics sidebar & navigation (HIGH; aliasing MED-LOW)**

2.14 WHEN the electronics sidebar renders THEN the system SHALL provide a dedicated electronics
section (split out of the shared retail case) without altering the `mobileShop`/`computerShop`
sidebars.

2.15 WHEN the electronics sidebar is shown THEN it SHALL include the device-relevant entries
(Serial/IMEI Tracking, Warranty Register, Service/Repair Jobs, Returns-with-serial) and SHALL not
surface clearly-irrelevant retail-only items for electronics.

2.16 WHEN sidebar ids are resolved THEN the system SHALL ensure labels map to their intended
screens (or be corrected/removed), and `audit_trail` SHALL NOT be presented as a real audit log
unless backed by one.

**Phase 5 — Dashboard data integrity (HIGH; wasted query LOW)**

2.17 WHEN the electronics dashboard alerts render THEN the system SHALL compute counts from real
tenant-scoped queries (warranty-expiring from `iMEISerials` expiry; pending repairs from the
service-job source) instead of hardcoded literals.

2.18 WHEN the "IMEI Lookup" quick action is tapped THEN the system SHALL navigate to a functional
serial/IMEI lookup destination (no dead `onTap`).

2.19 WHEN the electronics dashboard loads THEN the system SHALL only run alert queries whose
results are displayed for electronics, avoiding wasted work.

**Phase 6 — RBAC permission gating (HIGH; layering MED)**

2.20 WHEN a non-privileged role views the electronics sidebar THEN the system SHALL gate sensitive
items (`audit_trail`, `bank_accounts`, `backup`, `expenses`, `accounting_reports`) with a
`permission` so the RBAC filter hides them from unauthorized roles.

2.21 WHEN the "New Repair" quick action navigates THEN the system SHALL apply the same authority
check as the `/job/*` route guard so the quick action and route guard agree on who may create a
repair job.

**Phase 7 — Returns, serial-stock view & accessibility (HIGH; semantics/HSN MED-LOW)**

2.22 WHEN an electronics sales return is processed THEN the system SHALL validate the returned
device serial (exists, tenant-scoped, was sold) before accepting the return line.

2.23 WHEN an electronics user looks for stock by unit THEN the system SHALL provide a serial-wise
stock view (broader multi-warehouse/FIFO/BOM remains parked).

2.24 WHEN quick-action buttons are presented THEN the system SHALL provide `Semantics`/tooltips and
accessible state so assistive technology can describe them.

2.25 WHEN an HSN code is entered THEN the system SHALL validate its length/format and reject
malformed values.

**Phase 8 — Cleanup & final regression verification**

2.26 WHEN the remediation completes THEN the system SHALL remove mislabeled aliases and dead
code/queries addressed above and SHALL confirm via end-to-end verification that all earlier fixes
hold and shared `mobileShop`/`computerShop` behavior is unchanged.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN any `mobileShop` or `computerShop` user uses the app THEN the system SHALL CONTINUE TO
render their existing sidebars, route guards, capabilities, and the shared `manual_item_entry_sheet`
/ `billing_service` / `_getRetailSections` behavior exactly as before (any file shared with them is
flagged and preserved).

3.2 WHEN a `mobileShop` item is entered THEN the system SHALL CONTINUE TO require a non-empty
serial/IMEI via the existing `mobileShop`-only validator.

3.3 WHEN any warranty-months value is entered in the manual entry sheet THEN the system SHALL
CONTINUE TO validate it as a whole number within `0..120` (this validation already exists — D2; it
must be preserved, not reintroduced or removed).

3.4 WHEN an electronics product is billed for a non-device or serial-less line within allowed rules
THEN the system SHALL CONTINUE TO apply the existing electronics config (priceLabel "MRP",
`defaultGstRate 18.0`, `gstEditable false`, required `itemName/quantity/price/brand/hsnCode`)
without change.

3.5 WHEN a serial that is unique and valid is sold THEN the system SHALL CONTINUE TO complete the
sale and write the bill line as it does today (the uniqueness fix only rejects duplicates/blanks;
it does not change the happy path).

3.6 WHEN any other business type's dashboard, alerts, quick actions, or RBAC are used THEN the
system SHALL CONTINUE TO behave identically (no cross-vertical capability, sidebar, or guard edits).

3.7 WHEN existing generic inventory, returns, reports, and backup screens are used by electronics
or any vertical THEN the system SHALL CONTINUE TO function as before, except where a clause above
explicitly adds serial-aware behavior for electronics.

3.8 WHEN any new id, query, or persistence is introduced THEN the system SHALL CONTINUE TO honor the
non-negotiable constraints (integer-paise money, RID-patterned ids, tenant-scoped queries, idempotent
migrations, no schema change or hard delete without sign-off).
