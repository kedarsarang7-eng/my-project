# Implementation Plan — Clothing / Fashion Vertical Full Remediation

## Overview

Phased, evidence-based implementation plan that makes the DukanX `clothing` vertical
(`BusinessType.clothing`, "Clothing / Fashion") shippable end-to-end. Work proceeds
strictly in phase order (Phase 0 → Phase 10). Each phase ends with a STOP GATE: list every
file created/modified/deleted, run `flutter analyze` on touched files, emit the literal text
`PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for the literal reply `APPROVED`.
Do NOT auto-continue to the next phase. Any DynamoDB model-shape, Hive box, or Drift table
change requires a Mini_Gate (proposed change + migration plan) before applying; any deletion
of a record/file/route/screen uses a soft-delete status flag or a two-confirmation flow — no
hard deletes.

The language is Dart/Flutter for the app and Node.js for any backend endpoint, consistent
with the existing codebase (the design specifies concrete Dart signatures, so no language
choice is required).

All new code follows the non-negotiable cross-cutting constraints (Requirement 1) and the
scope boundary (Requirement 2): integer-Paise money (never `double`/`float`/decimal for
currency or quantity-price), RID id pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`,
tenant scoping on every query/write/sync (unresolved tenant aborts the operation), idempotent
migrations, and surgical/additive edits to Shared_Components (`sidebar_configuration.dart`,
`business_alerts_widget.dart`, `business_quick_actions.dart`, `business_capability.dart`,
`feature_resolver.dart`) — no other business type's sidebar, capability, quick-action, or
alert resolution changes, with a documented blast radius on every shared-file edit. Changes
are restricted to the four allowed locations: `features/clothing/*`, `modules/clothing/*`,
the `clothing` case within Shared_Components, and the navigation entries needed for
reachability. Route wiring uses **Option B** (scoped legacy `MaterialApp.routes` registration
in `buildAppRoutes()`); no app-wide GoRouter migration; no new backend endpoint beyond
satisfying an existing clothing-screen contract; e-Way bill deferred pending explicit sign-off.

## Tasks

> **Phased STOP-GATE protocol.** After every phase: (a) list files created/modified/deleted,
> (b) run `flutter analyze` on touched files and report results, (c) output exactly
> `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Sub-tasks marked
> with `*` are optional tests and are not auto-implemented. Property tests reference the
> design's Correctness Properties by number, run a minimum of 100 iterations, and are tagged
> `Feature: clothing-vertical-remediation, Property {n}: {text}`.

- [x] 1. Phase 0 — Read-only verification (Requirement 3)

  - [x] 1.1 Produce the read-only Verification_Report
    - Create `.kiro/specs/clothing-vertical-remediation/phase0-verification-report.md` and create/modify/delete zero other files; touch no application source, configuration, or build file
    - State what the cited source lines of `variant_cell.dart`, `size_curve_chip.dart`, and `clothing_variant_scanner_widget.dart` do, each with file path + start/end line numbers
    - Classify each of `clothing_sync_handler.dart` and `clothing_ws_handler.dart` as exactly active or not-active in the live app, with path + start/end lines
    - Record the exact `AppScreen` targets that `AppScreen.itemStock` and `AppScreen.categories` resolve to in `core/navigation/app_screens.dart`, with path + lines
    - Classify whether the `session_manager.dart` RBAC matrix gates the retail sidebar items shown to clothing as exactly gated or not-gated, with path + lines
    - Classify whether the billing line-item UI renders `size`/`color` per line as exactly renders or does-not-render, with path + lines
    - Classify the backend response shape for each of `/clothing/variants/{id}`, `/clothing/tailoring-notes`, and `/clothing/variants/bulk` as deployed-non-stub / deployed-stub / no-handler, recording the observed response-key contract and any handler path + lines
    - Mark every previously unverified audit item CONFIRMED or FALSIFIED with supporting file path + lines; flag any unresolved item still-unverified with the specific missing evidence; resolve every item to exactly one of those three states
    - If any audit/Ground Truth claim contradicts the code → STOP and report the discrepancy; do not route around it
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

- [x] 2. Checkpoint — Phase 0
  - List files created/modified/deleted (Verification_Report only), confirm zero non-report files changed, output `PHASE 0 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 3. Phase 1 — Navigation reachability architecture decision (Requirement 4)

  - [x] 3.1 Record the route-surface architecture decision (Option B)
    - Record an ADR (in the phase gate write-up) enumerating Option A (mount the full GoRouter module system) and Option B (register scoped clothing routes on the legacy `MaterialApp.routes` surface), selecting exactly one
    - Record Option B as the recommended and chosen option, with a complete rationale and the trade-offs of rejecting Option A, containing no "to be decided" placeholders
    - Identify exactly one documented route surface — `buildAppRoutes()` in `lib/app/routes.dart` "CUSTOM BUSINESS MODULES" section — on which all subsequent clothing routes register
    - Begin no sidebar or route wiring until the decision is approved; if rejected/returned, retain the record, apply requested changes, and re-emit the Phase 1 gate without beginning wiring
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 4. Checkpoint — Phase 1
  - Confirm the architecture decision record is complete with no placeholders, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 5. Phase 2 — Sidebar, capability/RBAC, route guard, quick action (Requirements 5, 6, 7)

  - [x] 5.1 Add `_getClothingSections()` and the explicit `case BusinessType.clothing` branch
    - In `lib/widgets/desktop/sidebar_configuration.dart`, add `case BusinessType.clothing:` returning a new `_getClothingSections()`; do not fall through to `default: _getRetailSections()`
    - Return exactly one dedicated clothing section with the four items Variant Matrix (`clothing_variant_matrix` → `Variant_Management_Screen`), Tailoring / Alterations (`clothing_tailoring` → `Tailoring_Measurements_Screen`), Size & Color Stock Overview (`clothing_stock_overview` → `Clothing_Inventory_Screen`), Price-Tag / Barcode Printing (`clothing_tag_printing` → print flow), plus the same shared common sections returned for every other type
    - Each item has a non-empty label and a target that resolves via `SidebarNavigationHandler.getScreenForItem` to an existing screen, with no placeholder routes; document the blast radius in-file
    - _Requirements: 5.1, 5.2, 5.3, 1.8, 1.9_

  - [x] 5.2 Tag clothing items with their capability and apply the capability gate
    - Tag each clothing item whose granted `BusinessCapability` (`useVariants`, `useTailoringNotes`, `useBarcodeScanner`, `useScanOCR`) is present; render the variant-tracking surface in the dedicated section and do NOT condition it on `useBatchExpiry`
    - Omit an item whose capability is not granted while still returning non-gated clothing items and the shared common sections
    - _Requirements: 5.4, 5.5, 6.1_

  - [x] 5.3 Attach `permission` tags to the surfaced financial/compliance/admin items
    - Attach a `permission` tag to each of `audit_trail`, `bank_accounts`, `accounting_reports`, `gstr1`, `gstr2`, `gstr3b`, `gst_summary`, `expenses`, `credit_notes`, `backup` so `RolePermissions.hasPermission` evaluates each by role; include iff the user holds the permission, exclude otherwise
    - Make the edit additive only — no rendered item for any other business type is added/removed/reordered/altered; if any listed item remains untagged, emit a verification error naming each untagged item key
    - _Requirements: 6.2, 6.3, 6.4, 6.5, 6.6_

  - [x] 5.4 Correct the variant route guard and the "Variants" quick action
    - In `lib/app/routes.dart`, change the `Variant_Management_Screen` route guard from `Permissions.manageStaff` to a single inventory/product permission governing variant management; a holder resolves to the screen with no redirect, a non-holder is blocked, redirected to the default authorized landing screen, shown an access-denied indication, and no screen state is instantiated/retained
    - In `business_quick_actions.dart`, point the clothing "Variants" quick action to `Variant_Management_Screen`, not `AppScreen.categories`; leave every other business type's quick-action destinations identical
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [ ]* 5.5 Write property test for other-business-type preservation
    - **Property 7: Other business types are unchanged**
    - **Validates: Requirements 1.8, 1.9, 5.6, 6.5, 7.6, 15.1, 16.7**

  - [ ]* 5.6 Write property test for clothing sidebar id resolution
    - **Property 8: Every clothing sidebar id resolves to a real screen**
    - **Validates: Requirements 5.3, 15.2**

  - [ ]* 5.7 Write property test for the capability gate
    - **Property 9: Capability gate includes granted and excludes ungranted items**
    - **Validates: Requirements 5.4, 5.5**

  - [ ]* 5.8 Write property test for the financial-item permission tags
    - **Property 10: Enumerated financial/compliance/admin items carry a permission tag**
    - **Validates: Requirements 6.2, 6.6**

  - [ ]* 5.9 Write property test for RBAC inclusion by permission
    - **Property 11: RBAC inclusion is exactly by permission**
    - **Validates: Requirements 6.3, 6.4**

  - [ ]* 5.10 Write property test for variant route authorization
    - **Property 12: Variant route access is granted iff authorized**
    - **Validates: Requirements 7.2, 7.3, 7.4**

  - [ ]* 5.11 Write example tests for sidebar/scope/route/quick-action
    - Assert `_getSectionsForBusiness(clothing)` returns the dedicated clothing section (not retail) with the four named items plus shared common sections and the variant surface present without `useBatchExpiry`; the variant route guard uses the inventory/product permission (not `manageStaff`); the "Variants" quick action targets `Variant_Management_Screen`
    - _Requirements: 5.1, 5.2, 6.1, 7.1, 7.5_

- [x] 6. Checkpoint — Phase 2
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 2 tests pass, document the Shared_Component blast radius and the per-vertical regression result, output `PHASE 2 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 7. Phase 3 — Critical data-loss and API contract fixes (Requirement 8)

  - [x] 7.1 Add an explicit Save control and a real `onQuantitiesChanged` handler
    - In `variant_grid_widget.dart` add an explicit Save control; in `variant_management_screen.dart` replace the empty `onQuantitiesChanged` callback with a handler that routes edits to `Variant_Repository.bulkUpdateVariants` scoped by Tenant_Id
    - On a confirmed persist, present a visible success indicator within 2 seconds; on failure, present an error indication and retain the merchant's edited quantities without discarding them
    - _Requirements: 8.1, 8.2, 8.8, 8.9_

  - [x] 7.2 Resolve the `/clothing/variants/{id}` response-key contract
    - Adopt a single response-key contract per the Phase 0 finding (3.7) so `Clothing_Inventory_Screen` and `Variant_Repository` read the same key (`items` vs `variants` mismatch resolved)
    - _Requirements: 8.3_

  - [x] 7.3 Make `VariantItem.fromJson` null/type-guarded
    - Cast each field through a null/type guard so a null/mistyped optional field resolves to its defined default and a null/mistyped required field raises a descriptive parse error rather than an uncaught exception
    - _Requirements: 8.4_

  - [x] 7.4 Replace `firstWhere` with a `Map`-indexed product lookup in `_getFilteredVariants`
    - Look products up via a `Map<String, Product>` keyed by product id so an unmatched id never throws `StateError`
    - _Requirements: 8.5_

  - [x] 7.5 Debounce the variant-search recompute
    - Debounce so the filtered list rebuilds at most once per 300 ms of input inactivity rather than on every keystroke
    - _Requirements: 8.6_

  - [x] 7.6 Replace the N+1 fetch in `Clothing_Inventory_Screen._loadInventory` with a single batch call
    - Replace the per-product fetch with one batch endpoint call
    - _Requirements: 8.7_

  - [ ]* 7.7 Write property test for the variant-grid save path
    - **Property 14: Variant grid Save persists exactly the edited quantities**
    - **Validates: Requirements 8.1, 8.2**

  - [ ]* 7.8 Write property test for failed-save retention
    - **Property 15: Failed save retains edited quantities**
    - **Validates: Requirements 8.9**

  - [ ]* 7.9 Write property test for total JSON parsing
    - **Property 16: Variant JSON parsing is total**
    - **Validates: Requirements 8.4**

  - [ ]* 7.10 Write property test for crash-free filtering
    - **Property 17: Filtering never throws on an unmatched product id**
    - **Validates: Requirements 8.5**

  - [ ]* 7.11 Write property test for fetch-count independence
    - **Property 18: Variant fetch request count is independent of product count**
    - **Validates: Requirements 8.7, 13.1**

  - [ ]* 7.12 Write example tests for contract, feedback, and debounce
    - Assert both consumers read the same `/clothing/variants/{id}` key; a confirmed save shows a success indicator within 2 s; rapid keystrokes recompute once after 300 ms idle
    - _Requirements: 8.3, 8.6, 8.8_

- [x] 8. Checkpoint — Phase 3
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all data-loss/contract tests pass, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 9. Phase 4 — Tailoring module wiring (Requirement 9)

  - [x] 9.1 Add the tailoring measurement record with RID, typed date, and soft-delete status
    - Define the tailoring record carrying an RID `id` via `RidGenerator.next(tenantId)`, `tenantId`, `customerId`, `invoiceId`, validated `measurements`, `priority`, a typed `DateTime deliveryDate` (not a split string), and a `status` flag (`active`/`deleted`)
    - _Requirements: 9.6, 1.3, 1.4_

  - [x] 9.2 Wire the "Take Measurements" action and register the route (Option B)
    - Open `Tailoring_Measurements_Screen` constructed with the originating `customerId`/`invoiceId` from a bill/customer context; register the navigation path on the Option B route surface, reachable in a single activation
    - Activation without a resolvable `customerId`/`invoiceId` does not open the screen and shows an error naming the missing context
    - _Requirements: 9.1, 9.2, 9.7_

  - [x] 9.3 Validate measurement fields against `ClothingBusinessRules.isValidMeasurement`
    - Validate each field against the bounds (not an inline `> 0` check); on save parse each with `double.tryParse` and persist only values that parse and fall within bounds, associated with `customerId`/`invoiceId`; an unparseable/out-of-bounds field rejects the save, retains all entered values, and names the invalid field
    - _Requirements: 9.3, 9.4, 9.8_

  - [x] 9.4 Make `_deleteMeasurements` a soft delete
    - Set a status flag rather than performing a silent no-op
    - _Requirements: 9.5_

  - [ ]* 9.5 Write property test for RID identifiers
    - **Property 2: RID identifiers are well-formed**
    - **Validates: Requirements 1.3**

  - [ ]* 9.6 Write property test for soft deletes
    - **Property 5: Deletions are soft**
    - **Validates: Requirements 1.6, 9.5**

  - [ ]* 9.7 Write property test for tailoring validation and save
    - **Property 19: Tailoring validation and save honor measurement bounds**
    - **Validates: Requirements 9.3, 9.4, 9.8**

  - [ ]* 9.8 Write property test for the typed delivery date
    - **Property 20: Delivery date round-trips as a typed DateTime**
    - **Validates: Requirements 9.6**

  - [ ]* 9.9 Write example test for tailoring navigation
    - Assert the "Take Measurements" action constructs `Tailoring_Measurements_Screen` with originating ids and is reachable in one activation; missing context shows an error and does not open the screen
    - _Requirements: 9.1, 9.2, 9.7_

- [x] 10. Checkpoint — Phase 4
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all tailoring tests pass, output `PHASE 4 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 11. Phase 5 — GST value-slab rule, variant model unification, exchange (Requirements 10, 11)

  - [x] 11.1 Implement the GST_Slab_Rule in integer Paise
    - Add the pure `gstRatePercentForTaxableValue(int taxableValuePaise)` / `gstAmountPaise(...)` functions: 5% when `0 < value < 100000` Paise, 12% when `value >= 100000` Paise; honor a manual override when `gstEditable` is true, reject it (retain slab rate + error) when false; reject a `<= 0` value (skip computation + error); compute all intermediate/final money in integer Paise with half-up rounding to whole Paise
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 11.2 Unify the divergent shapes into a single `Variant_Item` and migrate doubles → Paise
    - Converge on `Variant_Item { id (RID), productId, color, size, sku(<=64), barcode(<=64), priceCents(int Paise >=0), stock(int >=0) }`; remove the ad-hoc `Map<String,dynamic>` and the `quantity`/`priceAdjustment` doubles; migrate touched `double` price/quantity fields to integer Paise with an idempotent migration
    - If unification requires a DynamoDB model-shape / Hive box / Drift table change, halt for a Mini_Gate with a proposed change + migration plan before applying
    - _Requirements: 11.1, 11.2, 1.1, 1.2, 1.5, 1.7_

  - [x] 11.3 Fix the variant cell-key scheme to be injective
    - Replace `'${color}_$size'` with a collision-free encoding (length-prefixed or separator-escaped) so any two distinct `(color, size)` pairs yield distinct keys, including values containing `_` (e.g., "Off_White")
    - _Requirements: 11.3_

  - [x] 11.4 Grant `useSalesReturn` to clothing only
    - In `business_capability.dart`, grant `useSalesReturn` to `BusinessType.clothing` and to no other business type (additive edit)
    - _Requirements: 11.4_

  - [x] 11.5 Implement the atomic size-swap exchange
    - In a single atomic operation increment the returned variant's stock and decrement the issued variant's stock; insufficient issued stock rejects the exchange leaving both unchanged with an error; any post-adjustment failure rolls back all adjustments so no partial state persists
    - _Requirements: 11.5, 11.6, 11.7_

  - [x] 11.6 Record season/brand/loyalty scope decisions
    - Record explicit in-scope or deferred-backlog decisions for season/collection tracking, brand-wise stock reporting, and loyalty/bundle support, each with a written rationale of at least one sentence
    - _Requirements: 11.8_

  - [ ]* 11.7 Write property test for the integer-Paise money path
    - **Property 1: Money is integer Paise with half-up rounding**
    - **Validates: Requirements 1.1, 1.2, 10.5, 14.8**

  - [ ]* 11.8 Write property test for migration idempotency
    - **Property 6: Migrations are idempotent**
    - **Validates: Requirements 1.7**

  - [ ]* 11.9 Write property test for clothing-only capability grants
    - **Property 13: Capabilities are granted to clothing only**
    - **Validates: Requirements 11.4**

  - [ ]* 11.10 Write property test for the GST slab threshold
    - **Property 21: GST slab selects the rate by value threshold**
    - **Validates: Requirements 10.1, 10.2**

  - [ ]* 11.11 Write property test for the GST override rule
    - **Property 22: GST override honored iff editable**
    - **Validates: Requirements 10.3, 10.4**

  - [ ]* 11.12 Write property test for non-positive taxable-value rejection
    - **Property 23: Non-positive taxable value is rejected**
    - **Validates: Requirements 10.6**

  - [ ]* 11.13 Write property test for the variant model round-trip
    - **Property 24: Variant model round-trips**
    - **Validates: Requirements 11.1**

  - [ ]* 11.14 Write property test for cell-key injectivity
    - **Property 25: Variant cell keys are injective**
    - **Validates: Requirements 11.3**

  - [ ]* 11.15 Write property test for exchange atomicity
    - **Property 26: Size-swap exchange is atomic and stock-correct**
    - **Validates: Requirements 11.5, 11.6, 11.7**

  - [ ]* 11.16 Write the GST boundary unit test
    - Assert a taxable value of exactly 100,000 Paise selects 12% and 99,999 Paise selects 5%
    - _Requirements: 10.7_

- [x] 12. Checkpoint — Phase 5
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all GST/variant/exchange tests pass, confirm any Mini_Gate sign-off obtained for a schema/box/table change, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 13. Phase 6 — Offline-first, sync, printing, backend confirmation (Requirement 12)

  - [x] 13.1 Implement `ClothingRepositoryOffline` (local store + sync queue)
    - Following `jewellery_repository_offline.dart`: a local store plus a `clothing_sync_queue` (`entityType`, `operation`, `entityId`, `retryCount`, `lastError`, failed flag; records carry `synced`, `pendingOperation`, `pendingSince`, `version`), tenant-scoped, RID ids, optimistic local write; any new field/box/table is additive with safe defaults and applied only after a Mini_Gate; an unresolved tenant aborts the operation
    - Every create/update/delete persists locally within 1 s and enqueues exactly one sync-queue entry
    - _Requirements: 12.2, 1.4, 1.5, 1.12_

  - [x] 13.2 Route the three clothing screens through the repository (no direct `ApiClient`)
    - Route all CRUD in `Clothing_Inventory_Screen`, `Variant_Management_Screen`, and `Tailoring_Measurements_Screen` through `ClothingRepositoryOffline`, never `ApiClient` directly
    - _Requirements: 12.1_

  - [x] 13.3 Implement FIFO drain with retry cap and unsynced indication
    - On reconnect drain the queue FIFO; retry a failing entry up to 5 times, retain it (record preserved) until success or limit, mark it failed after the limit, and show a visible "unsynced changes exist" indication — never silent discard
    - _Requirements: 12.3, 12.4_

  - [x] 13.4 Resolve `Clothing_Sync_Handler` / `Clothing_Ws_Handler` disposition
    - Activate them, or remove them under the soft-delete + sign-off rules, based on the Phase 0 finding (3.3)
    - _Requirements: 12.5_

  - [x] 13.5 Implement per-variant price-tag/barcode printing
    - Print one tag per selected variant via `Print_Infrastructure`; a print failure names the affected variant and leaves its record unchanged
    - _Requirements: 12.6, 12.7_

  - [x] 13.6 Surface the OCR scan-bill entry point
    - Surface an OCR scan-bill entry reachable in a single interaction from `Clothing_Inventory_Screen`, using the granted `useScanOCR` capability
    - _Requirements: 12.8_

  - [x] 13.7 Confirm or feature-flag absent `/clothing/*` sync endpoints
    - Confirm any `/clothing/*` endpoint required by the sync path with the backend, or place the dependent feature behind a feature flag rather than failing silently; create no new endpoint beyond satisfying an existing clothing-screen contract
    - _Requirements: 12.9, 2.3_

  - [ ]* 13.8 Write property test for tenant isolation
    - **Property 3: Tenant isolation**
    - **Validates: Requirements 1.4**

  - [ ]* 13.9 Write property test for unresolved-tenant abort
    - **Property 4: Unresolved tenant aborts the operation**
    - **Validates: Requirements 1.12**

  - [ ]* 13.10 Write property test for optimistic enqueue
    - **Property 27: Offline writes are optimistic and enqueue exactly one entry**
    - **Validates: Requirements 12.2**

  - [ ]* 13.11 Write property test for FIFO drain
    - **Property 28: Sync queue drains FIFO**
    - **Validates: Requirements 12.3**

  - [ ]* 13.12 Write property test for retry-then-mark behavior
    - **Property 29: Failed sync entries are retried then marked, never discarded**
    - **Validates: Requirements 12.4**

  - [ ]* 13.13 Write property test for one-tag-per-variant printing
    - **Property 30: One tag is rendered per selected variant**
    - **Validates: Requirements 12.6**

  - [ ]* 13.14 Write integration test for the offline-first variant path
    - 1–3 examples for the offline variant load + sync path; assert the three screens depend on `ClothingRepositoryOffline` and never call `ApiClient` directly for CRUD; confirm `/clothing/*` endpoints or feature-flag absent ones
    - _Requirements: 12.1, 12.9_

- [ ] 14. Checkpoint — Phase 6
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all offline/sync/print tests pass, confirm any Mini_Gate sign-off for a box/table change and any handler-removal sign-off, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 15. Phase 7 — Performance hardening verification (Requirement 13)

  - [x] 15.1 Make the variant grid reflow to available width
    - Replace `FixedColumnWidth(100)` so at any desktop width 800–1280 px the grid reflows columns to available width with a 120 px minimum column width and no horizontal scrollbar at ≥800 px
    - _Requirements: 13.3_

  - [x] 15.2 Handle batch-fetch failure/timeout without per-product fallback
    - If the batch fetch fails or exceeds 10,000 ms, show an error indication, perform no per-product fallback, and leave previously loaded variant data unchanged
    - _Requirements: 13.5_

  - [ ]* 15.3 Write integration test for batch load and render budget under load
    - Load ≥1,000 products (up to 20 variants each) using a fixed number of batch requests independent of product count; assert initial grid render completes within 3000 ms from batch-request dispatch
    - _Requirements: 13.1, 13.4_

  - [ ]* 15.4 Write example test for debounce under load
    - Assert consecutive keystrokes recompute only after 300 ms of inactivity
    - _Requirements: 13.2_

  - [ ]* 15.5 Write example test for grid reflow and batch-failure handling
    - Assert grid reflow + 120 px minimum column width + no horizontal scrollbar at widths 800–1280 px; assert a forced batch failure/timeout shows an error with no per-product fallback and unchanged prior data
    - _Requirements: 13.3, 13.5_

- [x] 16. Checkpoint — Phase 7
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all performance tests pass, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 17. Phase 8 — UI polish, theming, accessibility, import/export, bounds (Requirement 14)

  - [x] 17.1 Replace hardcoded colors with `Theme.of(context)` values
    - Replace `#1A1A2E`, `#B8860B`, `grey[50]` in touched clothing screens so zero color literals remain; screens render correctly in light and dark; apply theme-derived color pairs targeting WCAG 2.1 AA contrast and document that full conformance requires manual AT testing + expert review
    - _Requirements: 14.1, 14.4_

  - [x] 17.2 Add Semantics labels and tooltips
    - Wrap variant cells, the scanner control, and measurement fields in `Semantics` with non-empty labels; give icon-only controls non-empty tooltips
    - _Requirements: 14.2, 14.3_

  - [x] 17.3 Implement CSV variant export and import
    - Export variants via `Variant_Repository.exportToCsv`; import valid rows and report the imported count; reject malformed/invalid rows, indicate which rows failed, and preserve existing variant data
    - _Requirements: 14.5, 14.6, 14.7_

  - [x] 17.4 Enforce money/quantity bounds and per-product reorder level
    - Represent displayed/stored money as a non-negative integer Paise in `0..9,999,999,999`; apply a per-product reorder level instead of a hardcoded low-stock threshold; reject a negative or >999,999 variant quantity with an error and preserve the prior value
    - _Requirements: 14.8, 14.9, 14.10_

  - [ ]* 17.5 Write property test for CSV export/import round-trip
    - **Property 31: CSV export/import round-trips and rejects invalid rows**
    - **Validates: Requirements 14.5, 14.6, 14.7**

  - [ ]* 17.6 Write property test for per-product low-stock computation
    - **Property 32: Low stock is computed from the per-product reorder level**
    - **Validates: Requirements 14.9**

  - [ ]* 17.7 Write property test for variant-quantity bounds
    - **Property 33: Variant quantity bounds are enforced**
    - **Validates: Requirements 14.10**

  - [ ]* 17.8 Write example tests for theming and accessibility
    - Assert zero color literals remain in touched screens and they render in light/dark; assert `Semantics` labels on variant cells/scanner/measurement fields and tooltips on icon-only controls
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [x] 18. Checkpoint — Phase 8
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all polish/accessibility/import-export tests pass, output `PHASE 8 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 19. Phase 9 — Mandatory regression pass and navigation walk (Requirement 15)

  - [x] 19.1 Run the cross-vertical regression pass
    - Compare electronics, mobile, computer, hardware, grocery, and pharmacy against a recorded pre-change baseline across sidebar sections, capability flags, quick-action set, and alert set; pass only when zero items are added/removed/reordered in any category for any of those verticals; on any detected change, halt for remediation naming the vertical + category
    - _Requirements: 15.1, 15.3, 15.5_

  - [x] 19.2 Run the clothing navigation graph walk
    - Walk the clothing navigation graph; pass only when 100% of clothing sidebar items resolve to a registered screen with zero "Unknown Screen" placeholders; on an unresolved item, halt for remediation naming the item; record the per-vertical outcome, the navigation-walk outcome, and the routes visited as evidence
    - _Requirements: 15.2, 15.4, 15.5_

- [x] 20. Checkpoint — Phase 9
  - Confirm the regression pass and navigation walk both pass with recorded evidence, output `PHASE 9 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 21. Phase 10 — Final verification matrix and test coverage (Requirement 16)

  - [x] 21.1 Produce the Verification_Matrix
    - Map every finding in `audit-clothing.md` to exactly one of FIXED, VERIFIED-OK, or DEFERRED-SIGNOFF — zero unmapped, none with more than one disposition; each DEFERRED-SIGNOFF records a rationale and the named sign-off authority
    - _Requirements: 16.1, 16.2_

  - [x] 21.2 Assemble and run the required unit tests
    - Provide passing unit tests for the GST slab (incl. the ₹1000 boundary), the variant model unification, and the cell-key collision fix (incl. "Off_White")
    - _Requirements: 16.3_

  - [x] 21.3 Assemble and run the required widget tests
    - Provide passing widget tests for the variant grid save path and tailoring validation against `ClothingBusinessRules.isValidMeasurement` bounds
    - _Requirements: 16.4_

  - [x] 21.4 Assemble and run the required integration tests
    - Provide passing integration tests for the offline-first variant load + sync path with 1–3 representative examples
    - _Requirements: 16.5_

  - [x] 21.5 Author the manual smoke-test checklist
    - Provide a checklist covering navigation from the clothing sidebar to each clothing screen with no "Unknown Screen" placeholder
    - _Requirements: 16.6_

  - [x] 21.6 Run the full regression suite and gate shippability
    - Confirm electronics, mobile, computer, hardware, grocery, and pharmacy resolve unchanged sidebar/capability/quick-action/alert behavior; if any required test fails, halt before declaring the vertical shippable
    - _Requirements: 16.7, 16.8_

- [x] 22. Checkpoint — Phase 10 (final verification)
  - Confirm all property tests (Properties 1–33) and example/integration/widget tests pass; run `flutter analyze` across all touched files with no new warnings/errors; confirm the Verification_Matrix is complete with zero unmapped findings; output `PHASE 10 COMPLETE — AWAITING APPROVAL`, then stop. Ask the user if questions arise.

## Notes

- Sub-tasks marked with `*` are optional tests (property, unit, integration, widget) and are not auto-implemented; core implementation sub-tasks are always implemented.
- Each property test references a specific design Correctness Property by number and the requirements clause it validates, runs a minimum of 100 iterations, and is tagged `Feature: clothing-vertical-remediation, Property {n}: {text}`.
- The highest-value properties land close to the implementation they protect: Property 21 (GST slab), 1 (integer Paise), 24 (variant round-trip), 25 (cell-key injectivity) in Phase 5; Property 14 (save path) in Phase 3; Property 26 (exchange atomicity) in Phase 5; Property 7 (other types preserved) in Phase 2.
- Reachability/route registration, theming, responsive layout, timing budgets, OCR entry, and the Phase 0/1/9/10 artifacts are validated by example, widget, integration, smoke, or governance checks per the design Testing Strategy — not by properties.
- Every phase ends with a STOP GATE; schema/box/table changes require a Mini_Gate (proposed change + migration plan) and any removal uses soft-delete or a two-confirmation flow. No other business type's sidebar, capability, quick-action, or alert resolution is modified, and every Shared_Component edit records its blast radius and a per-vertical regression result.
- All new money is integer Paise, all new ids use the RID pattern, every query/write/sync is tenant-scoped (unresolved tenant aborts), and route wiring stays on the single Option B surface (`buildAppRoutes()`).

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["3.1"] },
    { "id": 2, "tasks": ["5.1", "5.4"] },
    { "id": 3, "tasks": ["5.2"] },
    { "id": 4, "tasks": ["5.3"] },
    { "id": 5, "tasks": ["5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "5.11"] },
    { "id": 6, "tasks": ["7.1", "7.2", "7.3"] },
    { "id": 7, "tasks": ["7.4"] },
    { "id": 8, "tasks": ["7.5"] },
    { "id": 9, "tasks": ["7.6"] },
    { "id": 10, "tasks": ["7.7", "7.8", "7.9", "7.10", "7.11", "7.12"] },
    { "id": 11, "tasks": ["9.1"] },
    { "id": 12, "tasks": ["9.2", "9.3", "9.4"] },
    { "id": 13, "tasks": ["9.5", "9.6", "9.7", "9.8", "9.9"] },
    { "id": 14, "tasks": ["11.1", "11.2", "11.4", "11.6"] },
    { "id": 15, "tasks": ["11.3", "11.5"] },
    { "id": 16, "tasks": ["11.7", "11.8", "11.9", "11.10", "11.11", "11.12", "11.13", "11.14", "11.15", "11.16"] },
    { "id": 17, "tasks": ["13.1"] },
    { "id": 18, "tasks": ["13.2", "13.3", "13.4", "13.5", "13.6", "13.7"] },
    { "id": 19, "tasks": ["13.8", "13.9", "13.10", "13.11", "13.12", "13.13", "13.14"] },
    { "id": 20, "tasks": ["15.1", "15.2"] },
    { "id": 21, "tasks": ["15.3", "15.4", "15.5"] },
    { "id": 22, "tasks": ["17.1", "17.2", "17.3", "17.4"] },
    { "id": 23, "tasks": ["17.5", "17.6", "17.7", "17.8"] },
    { "id": 24, "tasks": ["19.1", "19.2"] },
    { "id": 25, "tasks": ["21.1", "21.2", "21.3", "21.4", "21.5", "21.6"] }
  ]
}
```
