# Implementation Plan — Jewellery Vertical Full Remediation

## Overview

Phased, evidence-based implementation plan that makes the DukanX `jewellery` vertical
(`BusinessType.jewellery`) shippable end-to-end. Work proceeds strictly in phase order
(Phase 0 → Phase 8). Each phase ends with a STOP GATE: list every file created/modified/
deleted, run `flutter analyze` on touched files, emit the literal text
`PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for the literal reply `APPROVED`.
Do NOT auto-continue. Schema changes (Hive/DynamoDB) require a Mini_Gate; any deletion of a
file/route/screen/data requires explicit recorded sign-off.

The language is Dart/Flutter for the app and Node.js for any backend endpoint, consistent
with the existing codebase (the design specifies concrete Dart signatures, so no language
choice is required).

All new code follows the non-negotiable conventions: integer-paise money (never
`double`/`float` for currency), RID id pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`,
tenant scoping on every query/write/sync (never `vendorId: 'SYSTEM'`), idempotent
migrations, surgical/additive edits to shared files (no other business type's sidebar,
capability, or routing resolution changes), and documented blast radius on every shared-file
edit.

## Tasks

> **Phased STOP-GATE protocol.** After every phase: (a) list files created/modified/deleted,
> (b) run `flutter analyze` on touched files and report results, (c) output exactly
> `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Sub-tasks marked
> with `*` are optional tests and are not auto-implemented. Property tests reference the design's
> Correctness Properties by number and run a minimum of 100 iterations, tagged
> `Feature: jewellery-vertical-remediation, Property {n}: {text}`.

- [x] 1. Phase 0 — Read-only verification (Requirement 2)

  - [x] 1.1 Produce the read-only Verification_Report
    - Create `.kiro/specs/jewellery-vertical-remediation/phase0-verification-report.md` and modify/delete zero other files
    - Classify the live bill-total computation as `Rate/Gm × metalWeight` or `Rate/Gm × quantity` with file path + start/end lines from `bill_creation_screen_v2.dart` / the calculation engine
    - State whether an editable making-charges column exists in `bill_line_item_row.dart`, with evidence lines
    - Classify each `/jewellery/*` endpoint (`products`, `gold-rate`, `old-gold-exchange`, `custom-orders`, `hallmark-inventory`, `gold-rate-alert`, `gold-scheme`, `making-charges`, `jewellery-repair`) as deployed-non-stub / deployed-stub / no-handler (404)
    - Record offline-vs-online behavior of the four un-audited repos (`gold_scheme`, `jewellery_repair`, `gold_rate_alert`, `making_charges`) and the observed behavior of `jewellery_sync_handler.dart` / `jewellery_ws_handler.dart`, with file paths + lines
    - State whether a backing screen exists for `/purchase/scan-bill`, with evidence lines
    - Mark every previously unverified audit item CONFIRMED or FALSIFIED with supporting file path + lines; flag any unresolved item still-unverified with a stated reason
    - If any Ground Truth/audit claim contradicts the code → STOP and report the discrepancy; do not route around it
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_

- [x] 2. Phase 1 — Reachability: sidebar, routes, navigation handler (Requirements 3, 4, 5)

  - [x] 2.1 Add `_getJewellerySections()` and the `case BusinessType.jewellery` branch
    - In `lib/widgets/desktop/sidebar_configuration.dart`, add an explicit `case BusinessType.jewellery:` returning a new `_getJewellerySections()`; do not fall through to `_getRetailSections()`
    - Cover exactly: Daily Rates (gold rate, gold-rate alert), Billing, Inventory (hallmark + weight stock), Old Gold Exchange, Custom Orders, Repairs, Gold Schemes, Making-Charges Calculator — each with a non-empty label and a reachable navigation target/item id
    - Leave the `default:` branch and every other business-type case byte-for-byte unchanged; document the blast radius in-file
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 1.9, 1.10, 1.12_

  - [x] 2.2 Register The_Eight_Screens as guard-wrapped GoRoutes
    - In `lib/core/routing/legacy_routes.dart`, register all 8 jewellery screens as named `GoRoute`s, each wrapping its screen in `VendorRoleGuard` → `BusinessGuard(allowedTypes: const [BusinessType.jewellery])` → screen, matching the existing clinic/bookStore pattern
    - Reconcile the two divergent legacy surfaces (the 7-route module list and the `jewellery_integration.dart` list) so the reachable set equals exactly The_Eight_Screens
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 2.3 Add jewellery cases to `getScreenForItem` and resolve scan-bill
    - In `lib/widgets/desktop/sidebar_navigation_handler.dart`, map each jewellery item id from task 2.1 to its single screen widget; none may fall through to `_buildPlaceholderScreen('Unknown Screen')`
    - Resolve `/purchase/scan-bill` to a backing screen (reuse an existing screen or add a thin backing screen per the Phase 0 finding 2.7) so it is not a dead end
    - _Requirements: 5.1, 5.2, 5.3_

  - [x]* 2.4 Write property test for jewellery sidebar id resolution
    - **Property 6: Every jewellery sidebar id resolves to its screen**
    - **Validates: Requirements 3.3, 5.1, 5.2**

  - [x]* 2.5 Write property test for jewellery route guards
    - **Property 7: Jewellery routes carry both guards for jewellery only**
    - **Validates: Requirements 4.2, 10.3**

  - [x]* 2.6 Write property test for route authorization
    - **Property 8: Route access is granted iff authorized**
    - **Validates: Requirements 4.3, 4.4**

  - [x]* 2.7 Write property test for other-business-type preservation
    - **Property 5: Other business types are unchanged**
    - **Validates: Requirements 1.9, 1.10, 3.4**

  - [x]* 2.8 Write example tests for reachability
    - Assert `_getSectionsForBusiness(jewellery)` returns jewellery sections (not retail), the section set equals the named surfaces, all 8 screens register as routes, the reachable set equals The_Eight_Screens, and `/purchase/scan-bill` resolves to a backing screen
    - _Requirements: 3.1, 3.2, 4.1, 4.5, 5.3_

- [x] 3. Checkpoint — Phase 1
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 1 tests pass, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 4. Phase 2 — Money correctness: rate unit, engine unification, GST/wastage/stone (Requirements 6, 7, 8)

  - [x] 4.1 Add the shared `RidGenerator` and apply it on touched new-entity paths
    - Add `RidGenerator.next(tenantId)` producing `{tenantId}-{timestamp_ms}-{uuid_v4_short}`; replace bare `Uuid().v4()` for new-entity id generation on touched jewellery paths
    - _Requirements: 1.3_

  - [x] 4.2 Implement the single rate-unit conversion boundary
    - Add `JewelleryRateUnit.perGramFromPer10g(int per10gPaisa)` performing `pricePerGramPaisa = per10gPaisa ~/ 10` exactly once; document the integer-truncation rounding rule at the boundary so callers never re-divide/multiply the value
    - _Requirements: 6.1, 6.2, 6.4_

  - [x] 4.3 Rework `JewelleryBusinessRules.billTotal` into the canonical integer-paise engine
    - Introduce `billTotalPaisa({grossWeightMilligrams, purity, ratePerGram24KPaisa, makingChargesPaisa, taxPaisa, discountPaisa})` computing metal value with integer arithmetic and documented half-up rounding to paise; designate it the single canonical pricing engine; ensure the live billing total multiplies Rate/Gm by `metalWeight`, never by `quantity`
    - _Requirements: 7.1, 7.4, 7.5, 1.1, 1.2, 8.4_

  - [x] 4.4 Refactor `MakingChargesCalculator` to delegate to the canonical engine
    - In `making_charges_calculator.dart`, delegate metal-value, tax, and total computation to `billTotalPaisa` rather than computing a parallel total; retain the making-charges breakdown (per-gram/percentage/tiered) as the engine input
    - _Requirements: 7.2, 7.3_

  - [x] 4.5 Implement split GST, single wastage application, and real stone charge
    - Compute GST as metal-value GST + making-charges GST (cite the Indian GST treatment in a code comment), not a single flat rate; apply wastage exactly once (remove the double-count path); use a real `stoneCount` field instead of "one stone per gram"; keep every intermediate value in integer paise
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x]* 4.6 Write property test for rate-unit conversion
    - **Property 9: Per-10g to per-gram conversion is a single floor division**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4**

  - [x]* 4.7 Write bidirectional rate-conversion unit tests
    - Example-based tests over 24K/22K/18K per-10g values (including non-multiples of 10) asserting `perGram = per10g ~/ 10` and reconstruction error below 10 paise
    - _Requirements: 6.3_

  - [x]* 4.8 Write property test for the integer-paise money path
    - **Property 1: Money path is integer paise**
    - **Validates: Requirements 1.1, 1.2, 8.4**

  - [x]* 4.9 Write property test for RID identifiers
    - **Property 2: RID identifiers are well-formed**
    - **Validates: Requirements 1.3**

  - [x]* 4.10 Write property test for two-engine equivalence
    - **Property 10: The two pricing engines agree**
    - **Validates: Requirements 7.2, 7.3**

  - [x]* 4.11 Write property test for the canonical reference formula
    - **Property 11: Canonical engine equals the reference bill formula**
    - **Validates: Requirements 7.1, 7.5**

  - [x]* 4.12 Write property test for weight-not-quantity scaling
    - **Property 12: Bill total scales with weight, not quantity**
    - **Validates: Requirements 7.4**

  - [x]* 4.13 Write property test for split GST
    - **Property 13: GST is split between metal value and making charges**
    - **Validates: Requirements 8.1**

  - [x]* 4.14 Write property test for single wastage application
    - **Property 14: Wastage is counted exactly once**
    - **Validates: Requirements 8.2**

  - [x]* 4.15 Write property test for stone-charge linearity
    - **Property 15: Stone charge is linear in stone count**
    - **Validates: Requirements 8.3**

  - [x]* 4.16 Write pricing-engine equivalence example test
    - Concrete worked examples (including the Phase 2 STOP GATE example) asserting calculator and canonical engine agree to the paise and equal `weight×rate + making + tax − discount`
    - _Requirements: 7.3, 7.5_

- [x] 5. Checkpoint — Phase 2
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all money-correctness tests pass, output `PHASE 2 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 6. Phase 3 — Capability, security, PMLA KYC (Requirements 9, 10, 11)

  - [x] 6.1 Add and grant the ten jewellery capabilities
    - In `lib/core/isolation/business_capability.dart`, append the eight new `BusinessCapability` values (`useGoldRate`, `useGoldRateAlert`, `useMakingCharges`, `useHallmark`, `useOldGoldExchange`, `useCustomOrders`, `useGoldSchemes`, `useJewelleryRepair`); grant all ten (including existing `useProductUnit`, `useProductTax`) in `businessCapabilityRegistry['jewellery']` and to no other business type
    - _Requirements: 9.1, 9.2, 9.5_

  - [x] 6.2 Attach capability gates to jewellery sidebar items
    - In `_getJewellerySections()`, attach the matching `BusinessCapability` to each gated jewellery `SidebarMenuItem` so `FeatureResolver.canAccess` permits granted items and filters ungranted ones
    - _Requirements: 9.3, 9.4_

  - [x] 6.3 Reconcile retail-origin items and re-verify route guards
    - Resolve each of `return_inwards`, `proforma_bids`, `dispatch_notes`, `booking_orders`, `low_stock` for the jewellery view (gated by a granted capability or absent) and produce a per-item gated/removed report; mark reconciliation incomplete and surface any item that is neither; re-verify each jewellery route carries `VendorRoleGuard` + `BusinessGuard(allowedTypes: [BusinessType.jewellery])`
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 6.4 Encrypt/redact and tenant-scope PMLA KYC fields
    - Add a `KycFieldCrypto` boundary in the offline repo persist/read path so `customerIdNumber` and `customerPhotoUrl` are encrypted/redacted at rest; keep records tenant-scoped; render `customerIdNumber` redacted (last-4); on decryption failure withhold the value and surface an error indication
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [x]* 6.5 Write property test for capability grants
    - **Property 16: Jewellery capabilities are granted to jewellery only**
    - **Validates: Requirements 9.4, 9.5**

  - [x]* 6.6 Write property test for gated-item capability attachment
    - **Property 17: Gated jewellery items carry their capability**
    - **Validates: Requirements 9.3**

  - [x]* 6.7 Write property test for retail-origin reconciliation
    - **Property 18: Retail-origin items are gated or removed**
    - **Validates: Requirements 10.1, 10.4**

  - [x]* 6.8 Write property test for KYC encryption round-trip
    - **Property 19: KYC fields round-trip under encryption and are not stored in plaintext**
    - **Validates: Requirements 11.1**

  - [x]* 6.9 Write property test for redacted KYC display
    - **Property 20: Displayed KYC id numbers are redacted**
    - **Validates: Requirements 11.3**

  - [x]* 6.10 Write property test for tenant isolation
    - **Property 3: Tenant isolation**
    - **Validates: Requirements 1.4, 1.5, 11.2**

  - [x]* 6.11 Write example test for capability presence
    - Assert the ten capabilities are present in the jewellery grant
    - _Requirements: 9.1, 9.2_

- [x] 7. Checkpoint — Phase 3
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all capability/security/KYC tests pass, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 8. Phase 4 — Dashboard: quick actions, alerts, dedicated dashboard, billing edits (Requirements 12, 13)

  - [x] 8.1 Wire jewellery dashboard quick actions
    - In `business_quick_actions.dart`, wire "Custom Order" → `CustomOrderManagementScreen` and "Gold Rate" → `GoldRateManagementScreen`; remove any `onTap: () {}` no-op for jewellery
    - _Requirements: 12.1, 12.2, 12.3_

  - [x] 8.2 Source jewellery alert counts from the offline repository
    - In `business_alerts_widget.dart`, replace the hardcoded `'3'`/`'!'` jewellery branch with counts from `JewelleryRepositoryOffline` (pending custom orders, gold-rate state); render a resolved zero as `0`; on repository failure show an error indication (never a stale/default number); leave no literal numeric count
    - _Requirements: 12.4, 12.5, 12.6, 12.7_

  - [x] 8.3 Build the dedicated jewellery dashboard and gold-rate ticker
    - Render KPI cards (gold rate by 24K/22K/18K, metal stock by weight, pending custom orders, scheme collections due, repair jobs in progress) and a gold-rate ticker sourced from live `GoldRateCard` data; every value traces to a repository/provider query (no hardcoded values)
    - _Requirements: 13.1, 13.2, 13.6_

  - [x] 8.4 Make purity and making-charges editable on the billing line item
    - In `bill_line_item_row.dart`, replace the read-only purity text cell with an editable `Purity_Enum` dropdown and present an editable making-charges column
    - _Requirements: 13.3, 13.4_

  - [x] 8.5 Present weight-based stock
    - Make `stock_summary` / `item_stock` present stock by metal weight rather than quantity only
    - _Requirements: 13.5_

  - [x]* 8.6 Write property test for repository-derived alert counts
    - **Property 22: Alert counts are repository-derived**
    - **Validates: Requirements 12.4, 12.6**

  - [x]* 8.7 Write property test for failure surfacing
    - **Property 21: Read/sync failures surface visibly and never fabricate data**
    - **Validates: Requirements 11.4, 12.7, 16.4**

  - [x]* 8.8 Write widget/example tests for the dashboard
    - Quick-action navigation, KPI card presence, editable purity dropdown, editable making-charges column, weight-based stock, and absence of hardcoded values
    - _Requirements: 12.1, 12.2, 12.3, 13.1, 13.3, 13.4, 13.5, 13.6_

- [x] 9. Checkpoint — Phase 4
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all dashboard tests pass, output `PHASE 4 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 10. Phase 5 — Offline-first parity and sync reconciliation (Requirement 14)

  - [x] 10.1 Migrate custom orders to the offline-first path
    - Move `custom_order_management_screen.dart` off the online-only `JewelleryRepository` onto `JewelleryRepositoryOffline` (Hive + sync queue)
    - _Requirements: 14.1_

  - [x] 10.2 Bring the four repositories to offline-first parity
    - Bring `gold_scheme`, `jewellery_repair`, `gold_rate_alert`, and `making_charges` repositories to offline-first parity (Hive box + sync queue), matching the offline repo pattern
    - _Requirements: 14.2_

  - [x] 10.3 Implement optimistic local write plus enqueue
    - Persist every create/update/delete to the local Hive box immediately and enqueue a corresponding sync-queue entry, online or offline
    - _Requirements: 14.3_

  - [x] 10.4 Implement version-based sync reconciliation
    - Compare local and server record `version` fields and apply version-based reconciliation rather than last-write-wins (add a server-version compare before overwrite)
    - _Requirements: 14.4_

  - [x] 10.5 Implement retry cap with failed-sync indication (additive Hive schema, Mini_Gate)
    - Retain a failing queued entry and preserve the local record across up to 5 retries; after the fifth failure mark it with a vendor-observable failed-sync indication and do not discard it; add additive fields (`serverVersion`, `syncFailed`, queue `failedPermanently`) with safe defaults; make the change idempotent and obtain a Mini_Gate before applying any Hive schema change
    - _Requirements: 14.5, 14.6, 1.6, 1.8_

  - [x]* 10.6 Write property test for optimistic enqueue
    - **Property 23: Offline writes are optimistic and enqueued**
    - **Validates: Requirements 14.3**

  - [x]* 10.7 Write property test for version-based reconciliation
    - **Property 24: Sync conflicts resolve by version**
    - **Validates: Requirements 14.4**

  - [x]* 10.8 Write property test for retry-then-mark behavior
    - **Property 25: Failed sync entries are retried then marked, never discarded**
    - **Validates: Requirements 14.5**

  - [x]* 10.9 Write property test for migration idempotency
    - **Property 4: Migrations are idempotent**
    - **Validates: Requirements 1.8, 14.6**

  - [x]* 10.10 Write example tests for offline parity
    - Custom orders create/list offline; each of the four repos exposes Hive + sync queue
    - _Requirements: 14.1, 14.2_

- [x] 11. Checkpoint — Phase 5
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all offline/sync tests pass, confirm the Mini_Gate sign-off was obtained for any Hive schema change, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 12. Phase 6 — Validation and crash prevention (Requirement 15)

  - [x] 12.1 Add NaN/upper-bound guards to the pricing engine
    - Guard `billTotalPaisa`/`exchangeCredit` so out-of-range or non-numeric inputs yield a guarded result within a defined upper bound rather than an invalid total
    - _Requirements: 15.1_

  - [x] 12.2 Add calculator input validation
    - In `MakingChargesCalculator`, reject negative weight, negative rate, and percentage > 100; retain the previous valid value and surface an error indication
    - _Requirements: 15.2_

  - [x] 12.3 Add graceful tiered-config handling
    - When `tieredRates` is empty and a weight matches no tier, return a graceful tiered-error result instead of throwing `Exception('No tier found…')`
    - _Requirements: 15.3_

  - [x] 12.4 Reject duplicate HUID on hallmark registration
    - In `registerHallmark`, detect an existing HUID for the tenant and reject rather than silently overwriting the Hive key; preserve the original entry
    - _Requirements: 15.4_

  - [x] 12.5 Enforce gold-rate spike and sanity bounds
    - In `setGoldRate`, apply day-over-day spike and sanity bounds and reject out-of-bounds rates with an error the caller surfaces
    - _Requirements: 15.5_

  - [x] 12.6 Replace free-text purity String with `Purity_Enum` end-to-end
    - Replace the free-text purity `String` with `Purity_Enum` across billing and storage paths
    - _Requirements: 15.6_

  - [x]* 12.7 Write property test for pricing guards
    - **Property 26: Pricing guards reject invalid inputs**
    - **Validates: Requirements 15.1, 15.2**

  - [x]* 12.8 Write property test for graceful tiered degradation
    - **Property 27: Tiered calculation degrades gracefully**
    - **Validates: Requirements 15.3**

  - [x]* 12.9 Write property test for duplicate HUID rejection
    - **Property 28: Duplicate HUID is rejected**
    - **Validates: Requirements 15.4**

  - [x]* 12.10 Write property test for gold-rate bounds
    - **Property 29: Gold rate bounds are enforced**
    - **Validates: Requirements 15.5**

  - [x]* 12.11 Write property test for purity enum round-trip
    - **Property 30: Purity round-trips as an enum**
    - **Validates: Requirements 15.6**

- [x] 13. Checkpoint — Phase 6
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all validation tests pass, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 14. Phase 7 — Performance and backend (Requirement 16)

  - [x] 14.1 Honor pagination across list repositories and screens
    - Make `getProducts`/`getOrders`/`getExchanges`/`getHallmarkEntries` honor `limit`/`offset`; audit each jewellery list screen to pass explicit `limit`/`offset` rather than loading the whole Hive box
    - _Requirements: 16.1, 16.2_

  - [x] 14.2 Build or ticket `/jewellery/*` endpoint gaps and surface sync failures
    - Build or ticket each `/jewellery/*` endpoint flagged as a backend gap in Phase 0; wrap new Lambdas in `withRequestContext` with tenant-scoped single-table items and integer-paise money; surface a visible sync-failure indication when an endpoint is absent instead of silently leaving records unsynced
    - _Requirements: 16.3, 16.4_

  - [x] 14.3 Add the certificate tracking model and screen
    - Add a `JewelleryCertificate` model (RID id, tenantId, product/HUID link, type, issuer, issue/expiry dates, document url, integer-paise valuation) in an additive Hive box `jewellery_certificates` and a tracking screen
    - _Requirements: 16.5_

  - [x] 14.4 Record the live gold-rate market-feed as a backlog item
    - Add a backlog marker (code comment / backlog entry) for live gold-rate market-feed integration; do not implement it in this remediation
    - _Requirements: 16.6_

  - [x]* 14.5 Write property test for pagination windows
    - **Property 31: Pagination returns a bounded window**
    - **Validates: Requirements 16.1**

  - [x]* 14.6 Write integration checks for built endpoints
    - 1–3 integration checks per built `/jewellery/*` endpoint (mocked at the Flutter layer, exercised end-to-end at the backend layer)
    - _Requirements: 16.3_

- [x] 15. Checkpoint — Phase 7
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure pagination/endpoint tests pass, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 16. Phase 8 — Polish, accessibility, sign-off (Requirement 17)

  - [x] 16.1 Fix mojibake in the money files
    - Correct `Ã—` → `×` and `â‚¹` → `₹` in `making_charges_calculator.dart` and `jewellery_business_rules.dart`; re-save both as UTF-8
    - _Requirements: 17.1_

  - [x] 16.2 Add Semantics and an accessible alert label
    - Wrap jewellery dashboard controls in `business_quick_actions.dart`/`business_alerts_widget.dart` in `Semantics` with non-empty labels; replace the glyph-only `'!'` badge with an accessible text label
    - _Requirements: 17.2, 17.3_

  - [x] 16.3 Delete `jewellery_integration.dart` under recorded sign-off
    - After the explicit Requirement 5.4 deletion sign-off is recorded, delete `jewellery_integration.dart`; perform no other deletion without its own recorded sign-off
    - _Requirements: 5.4, 17.4, 17.7, 1.7_

  - [x] 16.4 Make The_Eight_Screens responsive
    - Ensure each of The_Eight_Screens renders primary content without overflow at phone/tablet/desktop breakpoints
    - _Requirements: 17.5_

  - [x]* 16.5 Write property test for mojibake-free output
    - **Property 32: Calculator output is mojibake-free UTF-8**
    - **Validates: Requirements 17.1**

  - [x]* 16.6 Write accessibility and responsive example tests
    - Assert `Semantics` labels present on dashboard controls, the `'!'` badge replaced with an accessible text label, and each of The_Eight_Screens renders without overflow at phone/tablet/desktop breakpoints
    - _Requirements: 17.2, 17.3, 17.5_

  - [x]* 16.7 Run the full regression suite
    - Run the full existing test suite (including `test/core/routing/*` preservation tests and other-vertical sidebar/capability tests) to confirm no other business vertical regresses
    - _Requirements: 17.6_

- [x] 17. Checkpoint — Phase 8 (final verification)
  - Confirm all property tests (Properties 1–32) and example/integration tests pass; run `flutter analyze` across all touched files with no new warnings/errors; confirm the deletion sign-off for `jewellery_integration.dart` was recorded; output `PHASE 8 COMPLETE — AWAITING APPROVAL`, then stop. Ask the user if questions arise.

## Notes

- Sub-tasks marked with `*` are optional tests (property, unit, integration, widget) and are not auto-implemented; core implementation sub-tasks are always implemented.
- Each property test references a specific design Correctness Property by number and the requirements clause it validates, runs a minimum of 100 iterations, and is tagged `Feature: jewellery-vertical-remediation, Property {n}: {text}`.
- The highest-value money properties (9, 10, 11, 12, 13, 14, 15) land in Phase 2, close to the implementation they protect.
- Reachability, capability-presence, dashboard, offline-parity, accessibility, and endpoint criteria are validated by example/integration/widget tests rather than properties, per the design Testing Strategy.
- Every phase ends with a STOP GATE; schema changes require a Mini_Gate and deletions require explicit recorded sign-off. No other business type's sidebar, capability, or routing resolution is modified.
- All new money is integer paise, all new ids use the RID pattern, and every query/write/sync is tenant-scoped (never `vendorId: 'SYSTEM'`).

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3"] },
    { "id": 2, "tasks": ["2.4", "2.5", "2.6", "2.7", "2.8"] },
    { "id": 3, "tasks": ["4.1", "4.2", "4.3"] },
    { "id": 4, "tasks": ["4.4"] },
    { "id": 5, "tasks": ["4.5"] },
    { "id": 6, "tasks": ["4.6", "4.7", "4.8", "4.9", "4.10", "4.11", "4.12", "4.13", "4.14", "4.15", "4.16"] },
    { "id": 7, "tasks": ["6.1", "6.2", "6.4"] },
    { "id": 8, "tasks": ["6.3"] },
    { "id": 9, "tasks": ["6.5", "6.6", "6.7", "6.8", "6.9", "6.10", "6.11"] },
    { "id": 10, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5"] },
    { "id": 11, "tasks": ["8.6", "8.7", "8.8"] },
    { "id": 12, "tasks": ["10.1", "10.2"] },
    { "id": 13, "tasks": ["10.3"] },
    { "id": 14, "tasks": ["10.4"] },
    { "id": 15, "tasks": ["10.5"] },
    { "id": 16, "tasks": ["10.6", "10.7", "10.8", "10.9", "10.10"] },
    { "id": 17, "tasks": ["12.1", "12.2", "12.4", "12.5", "12.6"] },
    { "id": 18, "tasks": ["12.3"] },
    { "id": 19, "tasks": ["12.7", "12.8", "12.9", "12.10", "12.11"] },
    { "id": 20, "tasks": ["14.1", "14.2", "14.3", "14.4"] },
    { "id": 21, "tasks": ["14.5", "14.6"] },
    { "id": 22, "tasks": ["16.1", "16.2", "16.3", "16.4"] },
    { "id": 23, "tasks": ["16.5", "16.6", "16.7"] }
  ]
}
```
