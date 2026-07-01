# Implementation Plan — Book Store (`bookStore`) Vertical Full Remediation

## Overview

Phased, evidence-based implementation plan that restores reachability and integrity to the
existing DukanX `bookStore` vertical (`BusinessType.bookStore`, "Book Store"). The strategic
directive is **restore reachability and integrity, do not rebuild** — the five `Book*Screen`
widgets, `book_repository.dart`, `BookStoreBusinessRules`, and `BookStoreStrategy` under
`lib/features/book_store/` (plus `lib/modules/book_store/` and `my-backend/src/handlers/book_store.ts`)
are assets to wire, correct, and harden, not liabilities to replace (Requirement 2.5, 2.6).
Work proceeds strictly in phase order (Phase 0 → Phase 10). Each phase ends with a STOP GATE:
produce the Phase_Report (every file created/modified/deleted with the specific change and the
Finding_Id each addresses), run `flutter analyze` plus the touched test suite, record the
per-non-bookStore-vertical regression result, emit the literal text
`PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for the literal reply `APPROVED`.
Do NOT auto-continue to the next phase.

The language is Dart/Flutter for the app and TypeScript (Node.js) for the backend handler,
consistent with the existing codebase. The design specifies concrete Dart/TS shapes, so no
language choice is required.

All new code follows the non-negotiable cross-cutting constraints (Requirement 1) and the
scope boundary (Requirement 2): integer-Paise money (never `double`/`float`/decimal for
currency), the RID id pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, tenant scoping on
every query/write/sync (an unresolved tenant aborts the operation with no I/O), idempotent
migrations, and surgical/additive edits to Shared_Components (`sidebar_configuration.dart`,
`sidebar_navigation_handler.dart`, `content_host.dart`, `business_quick_actions.dart`,
`business_alerts_widget.dart`, `business_capability.dart`, `app_screens.dart`,
`navigation_controller.dart`, `app/routes.dart`, `business_type_config.dart`) confined to the
`bookStore` branch/case only — no other business type's sidebar, capability, quick-action,
alert, strategy, or config resolution changes. Freely-editable changes are restricted to
`lib/features/book_store/**`, `lib/modules/book_store/**`,
`lib/core/billing/strategies/book_store_strategy.dart`, `my-backend/src/handlers/book_store.ts`,
and `test/features/book_store/**`. No app-wide GoRouter migration (F4 is report-only). Any
stored-shape change (DynamoDB item shape, persisted Product/Customer field, Drift table) requires
a Schema_Gate (proposed change + every consumer + migration plan) before applying; any hard
deletion requires a repository-wide reference search + recorded sign-off (Delete_Gate). Two
business decisions are hard stops that write no code until confirmed: the GST/tax policy for
books versus stationery (Phase 3) and the build-versus-defer backlog decision (Phase 9).

## Tasks

> **Phased STOP-GATE protocol.** After every phase: (a) produce the Phase_Report listing files
> created/modified/deleted with the specific change and the Finding_Id each addresses, (b) run
> `flutter analyze` + the touched test suite and record total/passed/failed counts, (c) record
> the per-non-bookStore-vertical regression result, (d) output exactly
> `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Sub-tasks marked
> with `*` are optional test sub-tasks and are not auto-implemented. Property tests reference
> the design's Correctness Properties by number, run a minimum of 100 iterations, and are tagged
> `Feature: bookstore-vertical-remediation, Property {n}: {text}`. New bookStore navigation and
> wiring ships behind the `Dev_Flag` until Phase 8 sign-off removes it.

---

### Phase 0 — Read-only pre-flight verification (Requirement 3)

- [x] 1. Phase 0 — Produce the read-only Verification_Report

  - [x] 1.1 Create the Verification_Report and record every pre-flight check with evidence
    - Create `.kiro/specs/bookstore-vertical-remediation/phase0-verification-report.md` and create/modify/delete zero other files; touch no application source, configuration, or build file (3.1)
    - Record the GoRouter mount status of `lib/modules/book_store/` as exactly `mounted` or `not-mounted`, citing file path + evidence (in-repo comments, `module_loader`/`module_registry` registration), and classify F4 as report-only (3.2)
    - Record whether `POST /books/consignments/{id}/settle` and `POST /books/school-orders/{id}/fulfill` are paired with a deployed `Book_Store_Handler` route as `paired`/`unpaired`/`unverified`, recording observed vs expected request paths (3.3, F24)
    - Record a repository-wide search for hardcoded `tenantId`/`vendorId`/`'SYSTEM'` literals and unscoped reads/writes within `lib/features/book_store/**` and the `bookStore` path of `book_store.ts`, citing file path + line for each hit, with explicit "none found" when zero (3.4, F29)
    - Run the existing `test/features/book_store/**` suite and capture total/passed/failed counts (3.5)
    - Record the confirmed persisted shape of the Product and Customer records, listing fields relevant to author, publisher, edition, and loyalty so later phases know which additions require a Schema_Gate (3.6)
    - Mark every evaluated Finding_Id exactly one of CONFIRMED, Not_Reproduced, or UNVERIFIABLE with file path + line; record a non-reproducing finding as Not_Reproduced with evidence rather than silently omitting it (3.7, 3.8)
    - Ensure every check in 3.2–3.8 has a recorded result with nothing left unclassified; record any Phase 0 finding that contradicts a later-phase assumption and mark the dependent phase blocked until resolved (3.9, 3.10)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

- [x] 2. Checkpoint — Phase 0
  - Confirm only the Verification_Report was created and zero application/config/build files changed; ensure every check is classified; output `PHASE 0 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 1 — Tenant isolation and security baseline (Requirement 4)

- [ ] 3. Phase 1 — Enforce tenant/vendor isolation on every book-store read and write

  - [-] 3.1 Thread the active Tenant_Id through Book_Repository reads and writes
    - In `lib/features/book_store/data/book_repository.dart`, resolve the active `Tenant_Id` from the authenticated session (no hardcoded `'SYSTEM'`) and include it in every school-order, consignment, and (later-added) publisher-return read/write so responses contain only that tenant's records; close each tenant-scoping gap recorded in the Phase 0 report
    - _Requirements: 4.1, 4.2, 1.5, 1.6_

  - [-] 3.2 Scope the Book_Store_Handler by the authenticated tenant boundary
    - In `my-backend/src/handlers/book_store.ts`, derive the tenant boundary from the authenticated request context and scope every DynamoDB query and write by it; preserve the request/response contract for all fields other than the added tenant scoping
    - _Requirements: 4.3, 4.6_

  - [ ] 3.3 Reject unresolved-tenant and cross-tenant operations
    - When no `Tenant_Id` resolves, reject the read/write with an unresolved-tenant error and perform no I/O (leave persisted data unchanged); when a request references a record whose `Tenant_Id` differs from the requester's, deny it and return neither the record nor any field, in both `book_repository.dart` and `book_store.ts`
    - _Requirements: 4.4, 4.5, 1.7_

  - [ ]* 3.4 Write property test for tenant isolation across repo, handler, and cache
    - **Property 3: Tenant isolation across reads, writes, handler, and cache**
    - **Validates: Requirements 1.5, 4.1, 4.2, 4.3, 4.5**

  - [ ]* 3.5 Write property test for unresolved-tenant abort
    - **Property 4: Unresolved tenant aborts the operation**
    - **Validates: Requirements 1.7, 4.4**

  - [ ]* 3.6 Write handler contract test for preserved non-tenant fields
    - Assert `book_store.ts` request/response fields other than tenant scoping are unchanged after the isolation edit
    - _Requirements: 4.6_

- [ ] 4. Checkpoint — Phase 1
  - List touched files, run `flutter analyze` + touched tests, record the per-non-bookStore-vertical regression result, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 2 — Navigation and wiring behind a Dev_Flag (Requirement 5)

- [ ] 5. Phase 2 — Wire the bookStore sidebar, screens, and quick actions (Dev_Flag-gated)

  - [ ] 5.1 Add `_getBookStoreSections()` behind an explicit `case BusinessType.bookStore`
    - In `lib/widgets/desktop/sidebar_configuration.dart`, add `case BusinessType.bookStore:` returning a new `_getBookStoreSections()` (mirroring `_getSchoolSections()`/`_getElectronicsSections()`); do not fall through to `default: _getRetailSections()` (F1)
    - Gate the new section behind the `Dev_Flag` so pre-remediation behavior is unchanged in production while the flag is disabled; return items covering Book Catalogue, Book POS, Consignments, School/Institution Orders, and Publisher Returns, each with a non-whitespace label, a stable id, and its matching already-granted `BusinessCapability` gate via the existing `sidebarSectionsProvider` filter
    - Edit additively — for any `BusinessType` other than `bookStore`, `_getSectionsForBusiness` returns sections identical to pre-change
    - _Requirements: 5.1, 5.2, 5.3, 1.11, 1.12_

  - [ ] 5.2 Map each `book_*` sidebar id to an existing Book_Screen
    - In `lib/widgets/desktop/sidebar_navigation_handler.dart` (and/or `content_host.dart` `_screenBuilders`), add `case 'book_*':` branches mapping `book_catalogue`→`BookInventoryScreen`, `book_pos`→`BookPosScreen`, `book_consignments`→`ConsignmentSettlementScreen`, `book_school_orders`→`SchoolOrderScreen`, `book_publisher_returns`→`BookSupplierReturnsScreen`, each to exactly one existing widget, never the "Feature Not Found" placeholder (F2)
    - An id that cannot resolve retains the current screen, performs no navigation, surfaces an "unavailable" indication, and raises no unhandled exception
    - _Requirements: 5.4, 5.5_

  - [ ] 5.3 Repair the bookStore dashboard quick actions
    - In `lib/features/dashboard/v2/widgets/business_quick_actions.dart` (bookStore case only), map `AppScreen.bookCatalogue`/`AppScreen.bookReturns` ids into `content_host._screenBuilders`/`getScreenForItem` so **Book Search** resolves to `BookInventoryScreen`, **Returns** resolves to `BookSupplierReturnsScreen` (neither to a placeholder), and replace the empty **ISBN Scan** `onTap` with a defined action that opens the ISBN scan flow (F3); add any needed `AppScreen` ids in `lib/core/navigation/app_screens.dart`
    - _Requirements: 5.6, 5.7, 5.8_

  - [ ] 5.4 Route school-orders/consignments through the existing guarded paths; keep GoRouter report-only
    - Route bookStore navigation to school orders and consignments through the existing guarded `/book_store/school_orders` and `/book_store/consignments` entries in `lib/app/routes.dart` rather than bypassing their guards; do not mount or migrate the `lib/modules/book_store/` GoRouter module (F4 report-only)
    - _Requirements: 5.9, 5.10_

  - [ ]* 5.5 Write property test for other business types unchanged
    - **Property 6: Other business types are unchanged**
    - **Validates: Requirements 1.11, 1.12, 5.11**

  - [ ]* 5.6 Write property test for sidebar item well-formedness and resolution
    - **Property 7: Every book sidebar item is well-formed and resolves to a real screen**
    - **Validates: Requirements 5.3, 5.4**

  - [ ]* 5.7 Write property test for safe handling of unknown navigation ids
    - **Property 8: Unknown navigation ids are handled safely**
    - **Validates: Requirements 5.5**

  - [ ]* 5.8 Write example tests for Dev_Flag gating and quick-action resolution
    - With `Dev_Flag` off, `_getSectionsForBusiness(bookStore)` returns pre-remediation behavior; with it on, it returns `_getBookStoreSections()`; Book Search→`BookInventoryScreen`, Returns→`BookSupplierReturnsScreen`, ISBN Scan opens the scan flow (no empty `onTap`, none to placeholder)
    - _Requirements: 5.1, 5.2, 5.6, 5.7, 5.8_

- [ ] 6. Checkpoint — Phase 2
  - List touched files, run `flutter analyze` + touched tests, record the per-non-bookStore-vertical regression result (Shared_Component edits confined to the `bookStore` branch), output `PHASE 2 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 3 — Money logic: per-item GST and consignment settlement cap (Requirement 6)

- [ ] 7. Phase 3 — Per-item GST and capped consignment settlement (integer Paise)

  - [ ] 7.1 Halt on the tax policy and request explicit confirmation (business decision)
    - Treat the GST rate model as a hard stop: implement no rate table while the tax policy is unconfirmed; request explicit confirmation presenting the option that printed books (HSN 4901) are exempt at 0%, notebooks at 5%, and other stationery at 5%–18% by HSN, before writing any per-item GST code (F6, F7)
    - _Requirements: 6.1, 6.2, 14.6_

  - [ ] 7.2 Resolve per-item GST from tax class/HSN and reconcile the contradiction
    - Once the policy is confirmed, resolve the GST rate for a line item from the item's tax class or HSN code rather than the single flat `defaultGstRate`, and reconcile the `BookStoreStrategy` 0% comment, the `business_type_config.dart` bookStore `defaultGstRate: 12.0`, and the POS computing no tax into one confirmed policy governing all three; request a Schema_Gate before persisting any tax class / HSN / unit-settlement-price shape change (F6, F7)
    - _Requirements: 6.3, 6.4, 6.9, 1.8_

  - [ ] 7.3 Compute the POS tax line and express all money in integer Paise
    - In `BookPosScreen`, compute tax per line item using the resolved rate, render a tax line in the totals, and express `subtotalPaise`/`discountPaise`/`taxPaise`/`grandTotalPaise` as `int` Paise end-to-end (rupee display is a presentation-time conversion only)
    - _Requirements: 6.5, 1.1, 1.2_

  - [ ] 7.4 Compute and enforce the consignment Settlement_Cap
    - In `ConsignmentSettlementScreen`, compute `settlementCapPaise = booksSold × unitSettlementPricePaise` in integer Paise and display the expected settlement; reject a proposed amount exceeding the cap (persist nothing, over-settlement error identifying the cap) and reject a zero-or-negative amount (persist nothing, validation error)
    - _Requirements: 6.6, 6.7, 6.8_

  - [ ]* 7.5 Write property test for integer-Paise money on touched paths
    - **Property 1: Money is integer Paise**
    - **Validates: Requirements 1.1, 1.2, 6.5, 10.6**

  - [ ]* 7.6 Write property test for GST rate resolution from tax class/HSN
    - **Property 9: GST rate resolves from tax class or HSN, not a flat rate**
    - **Validates: Requirements 6.3**

  - [ ]* 7.7 Write property test for consignment settlement cap and validation
    - **Property 10: Consignment settlement is capped and validated**
    - **Validates: Requirements 6.6, 6.7, 6.8**

  - [ ]* 7.8 Write property test for POS invoice total as integer-Paise per-line tax sum
    - **Property 11: POS invoice total is the integer-Paise sum of per-line tax**
    - **Validates: Requirements 6.5**

- [ ] 8. Checkpoint — Phase 3
  - Confirm the tax policy was explicitly confirmed before any rate table was written; list touched files, run `flutter analyze` + touched tests, record the regression result, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 4 — Data reality (Requirement 7)

- [ ] 9. Phase 4 — Back catalogue, POS, alerts, and metadata with real tenant-scoped data

  - [ ] 9.1 Populate the catalogue from a tenant-scoped Product query
    - In `BookInventoryScreen`, populate the catalogue list from a tenant-scoped Product query and remove the hardcoded sample rows (F9)
    - _Requirements: 7.1_

  - [ ] 9.2 Populate the POS grid and wire search to tenant-scoped products
    - In `BookPosScreen`, populate the product grid from a tenant-scoped Product query (not `itemCount: 0`) and filter the grid by the search term against tenant-scoped products (F10)
    - _Requirements: 7.2, 7.3_

  - [ ] 9.3 Persist author, publisher, and edition on the Product record
    - When a book is added/edited, persist author, publisher, and edition to the Product record scoped to the active `Tenant_Id`; request a Schema_Gate before persisting if the Product shape must change (F12)
    - _Requirements: 7.4, 7.5, 1.8_

  - [ ] 9.4 Derive bookStore dashboard alert counts from real queries
    - In `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` (bookStore branch only), derive each displayed count from a real tenant-scoped query and remove the hardcoded `'11'`/`'6'` literals (F11)
    - _Requirements: 7.6_

  - [ ] 9.5 Route ISBN lookup and low-stock through deployed endpoints
    - Resolve ISBN metadata via `GET /book-store/isbn/{isbn}` and compute low-stock alerts via `GET /book-store/low-stock`, both through `book_repository`, rather than a hardcoded count (F18, F19)
    - _Requirements: 7.7, 7.8_

  - [ ] 9.6 Render empty and error states instead of fabricated values
    - For catalogue/search/alert/ISBN-lookup/low-stock queries, show a zero/empty-state indicator when no data returns and an error indication when a query fails — never a fabricated value
    - _Requirements: 7.9, 7.10_

  - [ ]* 9.7 Write property test for tenant-scoped POS search filtering
    - **Property 19: POS search returns only matching tenant-scoped products**
    - **Validates: Requirements 7.3**

  - [ ]* 9.8 Write property test for book metadata round-trip
    - **Property 20: Book metadata round-trips through the Product record**
    - **Validates: Requirements 7.4**

  - [ ]* 9.9 Write example tests for data-source wiring and UI states
    - Catalogue/POS grid populate from tenant-scoped queries; the bookStore alert branch reads counts from a provider/query (not `'11'`/`'6'`); empty result renders an empty-state; failed query renders an error indication
    - _Requirements: 7.1, 7.2, 7.6, 7.9, 7.10_

- [ ] 10. Checkpoint — Phase 4
  - List touched files, run `flutter analyze` + touched tests, record the regression result, output `PHASE 4 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 5 — ISBN validation consolidation (Requirement 8)

- [ ] 11. Phase 5 — Consolidate ISBN validation onto the authoritative checksum validator

  - [ ] 11.1 Route all ISBN validation through `BookStoreBusinessRules.isValidIsbn`
    - Consolidate ISBN validation onto the single authoritative `BookStoreBusinessRules.isValidIsbn`; replace the duplicate checksum in `isbn_scanner_widget.dart` and the length-only check in `BookInventoryScreen` with calls to it (F13)
    - _Requirements: 8.1, 8.2_

  - [ ] 11.2 Enforce ISBN validation in the Add Book dialog
    - Validate the entered ISBN with `isValidIsbn` before persisting; a failing checksum rejects the save, persists nothing, retains entered values, and shows an error on the ISBN field (F14)
    - _Requirements: 8.3, 8.4_

  - [ ] 11.3 Enforce ISBN validation at POS and eliminate the ₹0 placeholder line
    - An ISBN scanned/entered at POS that fails validation is rejected with a validation error and adds no cart line; a valid ISBN matching no tenant-scoped product prompts the operator to create the book first and does not add a ₹0 placeholder cart line (F15)
    - _Requirements: 8.5, 8.6_

  - [ ]* 11.4 Write property test for the ISBN checksum predicate
    - **Property 12: ISBN validation is a correct checksum predicate**
    - **Validates: Requirements 8.1**

  - [ ]* 11.5 Write property test for invalid-ISBN rejection with no side effects
    - **Property 13: Invalid ISBNs are rejected on add and at POS with no side effects**
    - **Validates: Requirements 8.3, 8.4, 8.5, 8.6**

- [ ] 12. Checkpoint — Phase 5
  - List touched files, run `flutter analyze` + touched tests, record the regression result, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 6 — Publisher returns and real loyalty (Requirement 9)

- [ ] 13. Phase 6 — Functional publisher returns and a real loyalty balance

  - [ ] 13.1 Make Publisher Returns functional, backed by Book_Repository
    - Replace the "future update" placeholder in `BookSupplierReturnsScreen` with a functional returns UI; submitting a return persists it via `POST /book-store/returns` with a tenant-scoped RID identifier and money in integer Paise; opening the list loads existing returns via `GET /book-store/returns` scoped to the active `Tenant_Id` (F16)
    - _Requirements: 9.1, 9.2, 9.3, 1.4_

  - [ ] 13.2 Derive a real loyalty balance with accrual and bounded redemption
    - In `customer_loyalty_widget.dart`, derive the balance from an actual points balance (not `customer.totalPaid`); a sale accrues points per the confirmed accrual rule; redemption decreases the balance and applies it to the bill total in integer Paise; a redemption exceeding the available balance is rejected with nothing applied and a validation error; request a Schema_Gate before persisting if the Customer shape must change (F17)
    - _Requirements: 9.4, 9.5, 9.6, 9.7, 9.8, 1.8_

  - [ ]* 13.3 Write property test for RID identifier well-formedness
    - **Property 2: RID identifiers are well-formed**
    - **Validates: Requirements 1.4, 9.2**

  - [ ]* 13.4 Write property test for loyalty accrual
    - **Property 15: Loyalty accrual increases the balance by the confirmed rule**
    - **Validates: Requirements 9.5**

  - [ ]* 13.5 Write property test for bounded loyalty redemption in Paise
    - **Property 16: Loyalty redemption is bounded and applied in Paise**
    - **Validates: Requirements 9.6, 9.7**

  - [ ]* 13.6 Write integration tests for the returns endpoints
    - Confirm the client calls `POST /book-store/returns` and `GET /book-store/returns` scoped to the active tenant, and reads the loyalty balance from the real balance field (not `customer.totalPaid`)
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 14. Checkpoint — Phase 6
  - List touched files, run `flutter analyze` + touched tests, record the regression result, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 7 — Offline-first migration (Requirement 10)

- [ ] 15. Phase 7 — Migrate Book_Repository onto the Sync_Queue offline-first pattern

  - [ ] 15.1 Migrate Book_Repository off direct apiClient calls onto the Sync_Queue
    - Migrate `book_repository.dart` off direct `apiClient.get/post` onto the established Sync_Queue offline-first pattern used by bills/products; store locally-persisted currency as integer Paise and identifiers in the RID pattern, scoping every cached record by the active `Tenant_Id`; request a Schema_Gate for any new Drift table/column (F25)
    - _Requirements: 10.1, 10.6, 1.8_

  - [ ] 15.2 Queue offline writes with a pending state and define the publisher-return offline path
    - While offline, queue school-order, consignment, and publisher-return writes locally and surface a pending state (not "Failed to load"); define the publisher-return offline behavior explicitly (queueing, conflict handling, reconciliation) consistent with school orders and consignments (F25, F26)
    - _Requirements: 10.2, 10.5_

  - [ ] 15.3 Flush queued writes idempotently on connectivity restore
    - On connectivity restore, flush queued writes so each RID-identified record has exactly one stored version with no duplicate, and applying the same RID-identified change more than once yields the same persisted result as a single application (F25, F26)
    - _Requirements: 10.3, 10.4_

  - [ ] 15.4 Retain and retry failed sync entries without discarding them
    - A failed sync retains that record's pending local change, leaves successfully synced records unaffected, and retries the failed record on the next connectivity-restored event without discarding it
    - _Requirements: 10.7_

  - [ ]* 15.5 Write property test for idempotent migrations
    - **Property 5: Migrations are idempotent**
    - **Validates: Requirements 1.10**

  - [ ]* 15.6 Write property test for idempotent, duplicate-free sync reconciliation
    - **Property 17: Sync reconciliation is idempotent and duplicate-free**
    - **Validates: Requirements 10.3, 10.4**

  - [ ]* 15.7 Write property test for retained-and-retried failed sync entries
    - **Property 18: Failed sync entries are retained and retried, never discarded**
    - **Validates: Requirements 10.7**

  - [ ]* 15.8 Write integration tests for offline-first behavior
    - Confirm `book_repository` routes through the Sync_Queue, queues writes with a pending state while offline, and applies the publisher-return offline path consistently with orders/consignments
    - _Requirements: 10.1, 10.2, 10.5_

- [ ] 16. Checkpoint — Phase 7
  - List touched files, run `flutter analyze` + touched tests, record the regression result, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 8 — In-widget RBAC guards; remove the Dev_Flag (Requirement 11)

- [ ] 17. Phase 8 — Gate money/create writes in-widget and take navigation live

  - [ ] 17.1 Add in-widget permission checks on guarded book-store writes
    - Verify the acting user holds the required permission before persisting in `BookPosScreen` invoice generation, `BookInventoryScreen` add/create, and consignment-settlement / school-order-fulfillment writes; a user lacking the permission is blocked (persist nothing, access-denied indication), enforced independent of the entry path since `Content_Host` applies no route guard (F27, F28)
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

  - [ ] 17.2 Remove the Dev_Flag gating on Phase 8 sign-off
    - On Phase 8 sign-off, remove the `Dev_Flag` gating so the bookStore sidebar and wiring become live
    - _Requirements: 11.6, 5.1_

  - [ ]* 17.3 Write property test for in-widget RBAC gating
    - **Property 14: Money and create writes are gated by an in-widget permission check**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

- [ ] 18. Checkpoint — Phase 8
  - Confirm the Dev_Flag is removed and navigation is live; list touched files, run `flutter analyze` + touched tests, record the regression result, output `PHASE 8 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 9 — Capability gating and medium/low polish (Requirement 12)

- [ ] 19. Phase 9 — Capability entries, layout/pagination/lifecycle polish, and backlog gating

  - [ ] 19.1 Add gateable capability entries for school orders and consignment
    - In `lib/core/isolation/business_capability.dart` (bookStore set only), add `BusinessCapability` entries for school/institution orders (and consignment where none exists) so the features are gateable through `FeatureResolver`; wire the corresponding sidebar item gates from Phase 2 (F20)
    - _Requirements: 12.1_

  - [ ] 19.2 Make the POS three-pane layout robust on narrow windows
    - Lay out `BookPosScreen` without horizontal overflow on narrow windows by adjusting the max width or providing a responsive/stacked layout (F30)
    - _Requirements: 12.2_

  - [ ] 19.3 Paginate consignment and school-order loads
    - In `book_repository.dart`, request consignments/school-orders in pages rather than one unpaginated call (F32)
    - _Requirements: 12.3_

  - [ ] 19.4 Guard BuildContext after await in async failure branches
    - In `SchoolOrderScreen`/`ConsignmentSettlementScreen`, guard `BuildContext` usage after `await` in failure branches with `mounted` checks (F33)
    - _Requirements: 12.4_

  - [ ] 19.5 Omit clearly retail-only sidebar sections
    - In `_getBookStoreSections()`, omit clearly retail-only sections irrelevant to a book store (F34)
    - _Requirements: 12.5_

  - [ ] 19.6 Improve accessibility on touched surfaces
    - Address low-contrast text and add tooltips/`Semantics` labels to icon-only buttons on touched book-store surfaces (noting full WCAG validation needs manual assistive-technology testing) (F35)
    - _Requirements: 12.6_

  - [ ] 19.7 Flag backlog features as hard stops (business decision)
    - Flag Used Books (F21), set/bundle class-set composition (F22), Stationery category with mixed GST (F23), and book detail/edit + publisher/school master UI (F31) as backlog and build none of them without explicit confirmation
    - _Requirements: 12.7, 14.6_

  - [ ]* 19.8 Write example test for capability wiring
    - Assert the new school-orders/consignment capabilities resolve through `FeatureResolver` for `bookStore`
    - _Requirements: 12.1_

  - [ ]* 19.9 Write example tests for layout, pagination, lifecycle, and a11y
    - POS lays out without overflow at narrow width; repo requests pages; failure branches carry `mounted` guards; icon-only buttons carry `Semantics`/tooltips; sidebar omits named retail-only ids
    - _Requirements: 12.2, 12.3, 12.4, 12.5, 12.6_

- [ ] 20. Checkpoint — Phase 9
  - Confirm no backlog feature was built without confirmation; list touched files, run `flutter analyze` + touched tests, record the regression result, output `PHASE 9 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

---

### Phase 10 — Final regression and traceability (Requirement 13)

- [ ] 21. Phase 10 — Final verification pass and Traceability_Matrix

  - [ ] 21.1 Run marker search, analyze, and the book-store test suite
    - Run a repository-wide `TODO`/`FIXME`/`mock`/`stub` search within `lib/features/book_store/**` and `lib/modules/book_store/**`, recording each remaining occurrence with path + line; run the full analyze step and the book-store test suite, recording total/passed/failed for each; if the analyze error count or test fail count is greater than zero, record a Fail status enumerating each failure
    - _Requirements: 13.1, 13.2, 13.3_

  - [ ] 21.2 Produce the Traceability_Matrix and confirm the Dev_Flag is removed
    - Map every Finding_Id F1–F35 to exactly one of Resolved, Partially-Resolved, Not-Reproduced, Deferred, or Out-of-Scope (none unmapped or multiply-assigned), citing evidence for Resolved/Partially-Resolved; confirm the `Dev_Flag` is removed and navigation is live (pass/fail); list every pending human decision (deferred tax detail, backlog build decisions, pending Schema_Gate/Delete_Gate) with its status
    - _Requirements: 13.4, 13.5, 13.6, 13.9_

  - [ ] 21.3 Record the per-non-bookStore-vertical regression result
    - Record a pass/fail for at least three other business verticals, where pass means the sidebar, dashboard, quick actions, and alerts widget resolve unchanged behavior; record a fail identifying the affected surface and business type for any changed behavior
    - _Requirements: 13.7, 13.8_

- [ ] 22. Final checkpoint — Phase 10
  - Confirm the Traceability_Matrix is complete with every finding mapped, all tests pass, the Dev_Flag is removed, and at least three non-bookStore verticals pass the regression check; output `PHASE 10 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and are not auto-implemented; they may be skipped for a faster MVP but are recommended for the universal correctness properties.
- Each task references specific granular requirements for traceability.
- Property tests validate the universal Correctness Properties from the design (Properties 1–20), run a minimum of 100 iterations, and are tagged `Feature: bookstore-vertical-remediation, Property {n}: {text}`. Dart logic uses `package:test` with a property-based helper (e.g. `glados`); `book_store.ts` backend logic uses `fast-check`.
- Example, widget, integration, and governance checks cover the non-property criteria (Phase 0/9/10 artifacts, UI states, quick-action/data-source wiring, capability wiring, endpoint integration, regression suite).
- Checkpoints enforce the phased STOP-GATE protocol: each phase ends with `PHASE N COMPLETE — AWAITING APPROVAL` and resumes only on the literal `APPROVED`. Schema changes (Schema_Gate) and hard deletions (Delete_Gate: reference search + sign-off) require their own explicit approval.
- Two business decisions are hard stops that write no code until confirmed: the GST/tax policy (Phase 3) and the build-versus-defer backlog decision (Phase 9).
- The strategic directive is restore, never rebuild: every wired screen references an existing `Book*Screen` widget, and Shared_Component edits are confined to the `bookStore` branch/case.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["3.1", "3.2"] },
    { "id": 2, "tasks": ["3.3"] },
    { "id": 3, "tasks": ["3.4", "3.5", "3.6"] },
    { "id": 4, "tasks": ["5.1", "5.2"] },
    { "id": 5, "tasks": ["5.3", "5.4"] },
    { "id": 6, "tasks": ["5.5", "5.6", "5.7", "5.8"] },
    { "id": 7, "tasks": ["7.1"] },
    { "id": 8, "tasks": ["7.2"] },
    { "id": 9, "tasks": ["7.3", "7.4"] },
    { "id": 10, "tasks": ["7.5", "7.6", "7.7", "7.8"] },
    { "id": 11, "tasks": ["9.1", "9.4", "9.5"] },
    { "id": 12, "tasks": ["9.2", "9.3", "9.6"] },
    { "id": 13, "tasks": ["9.7", "9.8", "9.9"] },
    { "id": 14, "tasks": ["11.1"] },
    { "id": 15, "tasks": ["11.2", "11.3"] },
    { "id": 16, "tasks": ["11.4", "11.5"] },
    { "id": 17, "tasks": ["13.1", "13.2"] },
    { "id": 18, "tasks": ["13.3", "13.4", "13.5", "13.6"] },
    { "id": 19, "tasks": ["15.1"] },
    { "id": 20, "tasks": ["15.2", "15.3", "15.4"] },
    { "id": 21, "tasks": ["15.5", "15.6", "15.7", "15.8"] },
    { "id": 22, "tasks": ["17.1", "17.2"] },
    { "id": 23, "tasks": ["17.3"] },
    { "id": 24, "tasks": ["19.1", "19.2", "19.4", "19.6", "19.7"] },
    { "id": 25, "tasks": ["19.3", "19.5"] },
    { "id": 26, "tasks": ["19.8", "19.9"] },
    { "id": 27, "tasks": ["21.1", "21.2", "21.3"] }
  ]
}
```
