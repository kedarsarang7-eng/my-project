# Design Document — Book Store (`bookStore`) Vertical Full Remediation

## Overview

The DukanX `bookStore` vertical (`BusinessType.bookStore`, display name "Book Store") already ships a substantial dedicated feature surface under `lib/features/book_store/` — five `Book*Screen` widgets (`BookPosScreen`, `BookInventoryScreen`, `BookSupplierReturnsScreen`, `ConsignmentSettlementScreen`, `SchoolOrderScreen`), an ISBN scanner and a customer-loyalty widget, `book_repository.dart`, a `BookStoreBusinessRules` utility holding the authoritative ISBN-10/13 checksum validator, a `BookStoreStrategy` billing strategy, and a GoRouter module under `lib/modules/book_store/` — plus a backend handler `my-backend/src/handlers/book_store.ts`. The audit (`audit-reports/business-types/audit-bookStore.md`) confirms the problem is **not absence of features — it is reachability, data-truthfulness, and logical consistency**. The book screens are *orphaned* from the live shell, the dashboard shows fabricated counts and dead links, the catalogue and POS grids render mock/empty data, GST handling is self-contradictory, three ISBN validators disagree, publisher returns is a placeholder, loyalty is a spend proxy, and the repository is online-only.

This design specifies how the phased remediation defined in `requirements.md` (Requirement 1 through Requirement 14, delivered across Phase 0 through Phase 10) is realized in code. The strategic directive — echoed from the requirements and the audit — is **restore reachability and integrity, do not rebuild**. The existing `Book*Screen` widgets, `book_repository`, `BookStoreBusinessRules`, and `BookStoreStrategy` are assets to wire, correct, and harden, not liabilities to replace (Requirement 2.5, 2.6). This design mirrors the requirements structure: the cross-cutting invariants of Requirement 1 and the scope boundary of Requirement 2 become design-wide invariants; each subsequent phase maps to a design section with concrete components, interfaces, and data models; and the money, ISBN, settlement, loyalty, sync, and RBAC surfaces are specified precisely enough to support property-based testing. It follows the same shape and conventions as the completed `electronics-vertical-remediation` and `schoolerp-vertical-remediation` designs for consistency.

### Live-reality findings that anchor this design (audit + a code re-read)

Every claim below was re-verified against the current codebase before being encoded. Phase 0 (Requirement 3) re-confirms each at task time and records evidence; the codebase may move.

- **Sidebar fall-through (CONFIRMED).** `_getSectionsForBusiness(BusinessType type)` in `lib/widgets/desktop/sidebar_configuration.dart` has explicit cases for clinic, electronics, computerShop, mobileShop, restaurant/service, hardware, vegetablesBroker, decorationCatering, jewellery, clothing, and schoolErp — but **no `case BusinessType.bookStore`** → it falls through to `default: return _getRetailSections();`. A book-store operator sees the generic 10-section retail sidebar with zero book-specific entries (F1).
- **Capability/permission filter exists.** `sidebarSectionsProvider` already filters every `SidebarMenuItem` by `item.capability` (via `FeatureResolver.canAccess`) and `item.permission` (via role permissions). A bookStore section plugs into this existing pipeline; no filter rewrite is needed. The `bookStore` capability set already grants `useISBN`, `usePublisherReturns`, `useLoyaltyPoints`, `useScanOCR`, `useBarcodeScanner`, and the inventory/invoice/alert keys.
- **Quick actions branch exists but two of three are dead (CONFIRMED).** `business_quick_actions.dart` has `case BusinessType.bookStore:` wiring **Book Search → `AppScreen.bookCatalogue`**, **Returns → `AppScreen.bookReturns`**, and an **ISBN Scan** action whose `onTap` is an empty no-op. `bookCatalogue` resolves to `book_catalogue`/`bookReturns` → not present in `content_host._screenBuilders` nor `getScreenForItem` → the `default:` "Feature Not Found" placeholder (F3).
- **Alerts branch fabricates counts (CONFIRMED).** `business_alerts_widget.dart` has `case BusinessType.bookStore:` in `_getTitle` returning **"Inventory Alerts"** and an alerts case rendering two hardcoded rows (counts `'11'` and `'6'`); it never reads the live `counts` map that the grocery branch reads from `alertCountsProvider` (F11).
- **Config GST is contradictory (CONFIRMED).** `business_type_config.dart` `bookStore` block sets `defaultGstRate: 12.0`, `gstEditable: true`, `itemLabel: 'Book'`. `BookStoreStrategy`'s doc comment claims books are GST-exempt (0%), while `BookPosScreen` computes `grandTotal = subtotal − discount` with **no tax line at all** — three sources disagree (F6, F7).
- **Money is float today; new money must be Paise.** The touched money surfaces (POS totals, consignment settlement, publisher-return amounts, loyalty) are `double`/rupee based. Per Requirement 1, all money in touched/created code becomes integer Paise; any existing float currency field is migrated only through the Schema_Gate (1.3, 6.9).
- **Three ISBN validators coexist (CONFIRMED).** The authoritative checksum lives in `BookStoreBusinessRules.isValidIsbn` (unused by UI); `isbn_scanner_widget.dart` has a duplicate checksum; `BookInventoryScreen` uses a length-only check; the Add Book dialog validates nothing (F13, F14). POS adds an unknown ISBN as a ₹0 placeholder line (F15).
- **Publisher returns is a placeholder; loyalty is a proxy (CONFIRMED).** `BookSupplierReturnsScreen`'s publisher-returns tab shows a "future update" placeholder despite `usePublisherReturns` and deployed `POST/GET /book-store/returns`; the loyalty widget passes `customer.totalPaid` as "points" with no accrual/redemption (F16, F17).
- **Repository is online-only (CONFIRMED).** `book_repository.dart` calls `apiClient.get/post` directly (school orders, consignments) with no Sync_Queue/offline path; POS bills and product adds go through offline-capable repositories (F25).
- **Route surface is `app/routes.dart` (per requirements Glossary).** The live named-route table is `lib/app/routes.dart`, where `/book_store/school_orders` and `/book_store/consignments` are wrapped in `VendorRoleGuard(viewReports)` + `BusinessGuard([bookStore])` but nothing navigates to them. The GoRouter module (`lib/modules/book_store/`) is **not mounted** — report-only (F4). This differs from the schoolErp vertical, whose routes live in `legacy_routes.dart`; Phase 0 records the verified live file before any wiring.

### Guiding principles

- **Evidence before change.** Phase 0 produces a read-only `Verification_Report` resolving every audit assumption to CONFIRMED, Not_Reproduced, or UNVERIFIABLE, including GoRouter mount status, settle/fulfill route pairing, tenant/vendorId isolation, existing-test results, and the Product/Customer persisted shape. No later phase acts on an assumption.
- **Restore, never rebuild.** Every wired screen references an existing `Book*Screen` widget. No screen is copied or replaced (Requirement 2.5, 2.6).
- **Surgical, additive shared edits.** Shared files (`sidebar_configuration.dart`, `sidebar_navigation_handler.dart`, `content_host.dart`, `business_quick_actions.dart`, `business_alerts_widget.dart`, `business_capability.dart`, `app_screens.dart`, `navigation_controller.dart`, `app/routes.dart`, `business_type_config.dart`) are touched only inside the `bookStore` branch/case or by adding a new gated item; no other business type's resolution path changes, and a regression pass records per-vertical results.
- **One canonical money path.** All touched book-store money is integer Paise end-to-end; rupee display is a presentation-time conversion only.
- **Dev-flag-gated rollout.** The new bookStore sidebar and wiring ship behind a `Dev_Flag`, hidden in production, until Phase 8 sign-off removes the flag and the navigation goes live (Requirement 5.1, 11.6, 13.6).
- **Offline-first repository.** `book_repository` migrates onto the established Sync_Queue offline-first pattern; publisher returns joins school orders and consignments in the offline path.
- **Gate-driven progression.** Each phase ends with the literal `PHASE N COMPLETE — AWAITING APPROVAL` and resumes only on the literal `APPROVED`. Schema changes (Schema_Gate) and hard deletions (Delete_Gate: reference search + sign-off) require their own explicit approval.
- **Business decisions are hard stops.** The GST/tax policy for books versus stationery (Phase 3) and the build-versus-defer decision for backlog features (Phase 9) write no code until confirmed, because they are business decisions, not engineering choices (Requirement 6.1, 12.7, 14.6).

### Design-wide invariants (Requirement 1 & 2)

1. **Integer-Paise money (1.1, 1.2, 1.3).** Every money value in created/modified book-store code is an `int` of Paise. No `double`/`float`/decimal currency is introduced. Any touched existing float currency field migrates to integer Paise only via the Schema_Gate — never silently.
2. **RID ids (1.4).** New entities use `{tenantId}-{timestamp_ms}-{uuid_v4_short}` via the shared RID generator, where `tenantId` is the active `Tenant_Id`, `timestamp_ms` is Unix epoch milliseconds, and `uuid_v4_short` is a non-empty shortened UUID v4. Any bare `Uuid().v4()` on a touched write path is replaced.
3. **Tenant scoping (1.5, 1.6, 1.7).** Every query/write/sync resolves `Tenant_Id` from the authenticated session (no hardcoded `'SYSTEM'` or other literal). An unresolved tenant aborts the operation with an unresolved-tenant error, performs no read or write, and leaves persisted data unchanged.
4. **Schema_Gate for stored shapes (1.8).** Any DynamoDB item-shape change, persisted Product/Customer field addition, or Drift table change halts and requests a Schema_Gate stating the proposed change, every consumer of the changed shape, and a migration plan before applying.
5. **No hard deletes without sign-off (1.9).** Removal of a file/route/screen/symbol first runs a repository-wide reference search, records the result and an explicit deletion request in the Phase_Report, and proceeds only on the literal `APPROVED` (Delete_Gate).
6. **Idempotent migrations (1.10).** Any data migration/backfill is guarded so repeated runs produce the same persisted result and modify zero records after the first execution.
7. **Additive shared edits + regression (1.11, 1.12).** Shared components gain only a `bookStore` branch or a new gated item; no other business type's sidebar/quick-action/alert/capability/strategy/config resolution changes. A regression pass records pass/fail per non-bookStore vertical.
8. **Honesty rule (1.13, 1.14).** A claim that cannot be statically verified is flagged unverifiable in the Phase_Report; no Finding_Id is reported resolved without cited evidence (a change, test result, or search result).
9. **Scope boundary (2.1–2.7).** Freely-editable changes are restricted to `lib/features/book_store/**`, `lib/modules/book_store/**`, `lib/core/billing/strategies/book_store_strategy.dart`, `my-backend/src/handlers/book_store.ts`, and `test/features/book_store/**`; Shared_Component edits are confined to the `bookStore` branch. No app-wide GoRouter migration; no other vertical's code is touched.

## Architecture

### Current-state component map

```mermaid
graph TD
    subgraph Live shell
        SHELL[Desktop shell / mobile drawer] --> SBPROV[sidebarSectionsProvider]
        SBPROV --> SBCFG[sidebar_configuration.dart _getSectionsForBusiness]
        SBCFG -->|bookStore: NO case| RETAIL[default: _getRetailSections]
        SHELL --> DASH[Dashboard V2]
        DASH --> QA0[business_quick_actions bookStore: Book Search->placeholder, Returns->placeholder, ISBN Scan->no-op]
        DASH --> AW0[business_alerts_widget bookStore: hardcoded '11' / '6']
    end
    subgraph Orphaned book_store code lib/features/book_store
        SCR[5 Book*Screen widgets - mock/empty grids]
        REPO[book_repository ApiClient-direct, online-only]
        RULES[BookStoreBusinessRules.isValidIsbn - unused]
        ISBNW[isbn_scanner_widget duplicate validator]
        LOY[customer_loyalty_widget totalPaid proxy]
        STRAT[BookStoreStrategy 0% comment]
    end
    subgraph Route + module surface
        AR[app/routes.dart /book_store/* guarded viewReports, unused]
        MOD[modules/book_store GoRouter NOT mounted]
        CFG[business_type_config defaultGstRate 12.0]
    end
    RETAIL -.->|no link| SCR
    AR -->|BusinessGuard bookStore| SCR
    REPO -->|REST| EP[/books/* + /book-store/* Lambda]
    STRAT -.-> SCR
```

### Target-state component map (post-remediation, Dev_Flag enabled)

```mermaid
graph TD
    SHELL[Desktop shell / mobile drawer] --> SBPROV[sidebarSectionsProvider]
    SBPROV --> SBCFG[sidebar_configuration.dart]
    SBCFG -->|case bookStore + Dev_Flag| BSECT[_getBookStoreSections]
    BSECT -->|items: capability + permission tags| NAV[SidebarNavigationHandler / ContentHost]
    NAV --> SCR[existing Book*Screen widgets]
    QA[business_quick_actions case bookStore] --> A1[Book Search / ISBN Scan / Returns]
    AW[business_alerts_widget case bookStore] --> LOWSTOCK[/book-store/low-stock live count]
    SCR --> REPOFF[book_repository + Sync_Queue offline-first]
    REPOFF -->|tenant-scoped, paise| EP[/books/* + /book-store/* Lambda]
    SCR --> RULES[BookStoreBusinessRules.isValidIsbn - single validator]
    SCR --> RBAC[in-widget permission checks on money/create writes]
    STRAT[BookStoreStrategy + per-item GST by tax class/HSN] --> POS[BookPosScreen tax line]
    LOY[loyalty: real balance + accrual/redemption] --> POS
    BE[book_store.ts tenant-scoped handler] --> EP
```

### Phase-to-requirement map

| Phase | Requirements | Theme | Primary artifacts |
|-------|--------------|-------|-------------------|
| 0 | 3 | Read-only pre-flight verification | `Verification_Report` (Markdown only) |
| 1 | 4 | Tenant isolation & security baseline | `book_repository.dart`, `my-backend/src/handlers/book_store.ts` |
| 2 | 5 | Navigation & wiring (behind Dev_Flag) | `sidebar_configuration.dart` (`_getBookStoreSections`), `sidebar_navigation_handler.dart`/`content_host.dart`, `business_quick_actions.dart`, `app_screens.dart` |
| 3 | 6 | Money logic — per-item GST + settlement cap | `book_store_strategy.dart`, `BookPosScreen`, `ConsignmentSettlementScreen`, `business_type_config.dart` (bookStore) |
| 4 | 7 | Data reality — real catalogue/search/alerts/metadata | `BookInventoryScreen`, `BookPosScreen`, `business_alerts_widget.dart`, `book_repository.dart` |
| 5 | 8 | ISBN validation consolidation | `BookStoreBusinessRules`, `isbn_scanner_widget.dart`, `BookInventoryScreen`, `BookPosScreen` |
| 6 | 9 | Publisher returns + real loyalty | `BookSupplierReturnsScreen`, `customer_loyalty_widget.dart`, `book_repository.dart` |
| 7 | 10 | Offline-first migration | `book_repository.dart`, Sync_Queue integration |
| 8 | 11 | In-widget RBAC guards; remove Dev_Flag | `Book*Screen` write paths, `content_host.dart` |
| 9 | 12 | Capability gating & medium/low polish | `business_capability.dart`, `BookPosScreen` layout, `book_repository.dart` pagination, mounted guards, a11y |
| 10 | 13 | Final regression & traceability | `Traceability_Matrix`, test suites, per-vertical regression |

The cross-cutting constraints of Requirement 1 (integer Paise, RID ids, tenant scoping, Schema_Gate, Delete_Gate, idempotent migrations, additive shared edits, honesty rule) and the scope boundary of Requirement 2 are not phases — they are invariants enforced in every section below. Requirement 14 (strict ordering + stop gates + Phase_Report) governs progression.

## Components and Interfaces

### Phase 0 — Verification_Report (Requirement 3)

A single read-only Markdown artifact at `.kiro/specs/bookstore-vertical-remediation/phase0-verification-report.md`. Phase 0 creates, modifies, and deletes zero files other than this report and touches no application source/config/build file (3.1). It records, each with file path + line numbers:

- **GoRouter mount status (3.2).** The mount status of the `lib/modules/book_store/` GoRouter module classified as exactly `mounted` or `not-mounted`, with evidence (the in-repo comments and `module_loader` registration), and F4 classified report-only.
- **Settle/fulfill route pairing (3.3).** Whether `POST /books/consignments/{id}/settle` and `POST /books/school-orders/{id}/fulfill` are paired with a deployed `Book_Store_Handler` route, each classified `paired`, `unpaired`, or `unverified`, recording observed vs expected request paths (F24).
- **Tenant-scoping search (3.4).** Result of a repository-wide search for hardcoded `tenantId`/`vendorId`/`'SYSTEM'` literals and unscoped reads/writes within `lib/features/book_store/**` and the `bookStore` path of `book_store.ts` (F29), with file path + line for each hit and an explicit "none found" when zero.
- **Existing tests (3.5).** Result of running `test/features/book_store/**`, capturing total/passed/failed counts.
- **Product/Customer shape (3.6).** The confirmed persisted shape of the Product and Customer records, listing fields relevant to author, publisher, edition, and loyalty, so later phases know which additions require a Schema_Gate.
- **Finding classification (3.7, 3.8).** Every evaluated Finding_Id marked exactly one of CONFIRMED, Not_Reproduced, or UNVERIFIABLE with file path + line; a finding that cannot be reproduced is recorded as Not_Reproduced with evidence, never silently omitted.
- **Completeness & contradiction (3.9, 3.10).** Every check in 3.2–3.8 has a recorded result with nothing unclassified; a Phase 0 finding that contradicts a later-phase assumption is recorded and blocks the dependent phase until resolved by sign-off.

### Phase 1 — Tenant isolation and security baseline (Requirement 4)

**`book_repository.dart` tenant threading (4.1, 4.2).** Each read/write for school orders, consignments, and (added later) publisher returns includes the active `Tenant_Id` so responses contain only that tenant's records. Any tenant-scoping gap recorded in Phase 0 is closed by adding the active `Tenant_Id` filter.

**`book_store.ts` handler (4.3, 4.6).** The handler derives the tenant boundary from the authenticated request context and scopes every DynamoDB query and write by it; the request/response contract is preserved for all fields other than the added tenant scoping.

**Unresolved / cross-tenant (4.4, 4.5).** A read/write with no resolvable `Tenant_Id` is rejected with an unresolved-tenant error and performs no I/O. A request referencing a record whose `Tenant_Id` differs from the requester's is denied, returning neither the record nor any field.

### Phase 2 — Navigation and wiring behind a Dev_Flag (Requirement 5)

**`Dev_Flag` gating (5.1).** While the `Dev_Flag` is disabled, `bookStore` navigation is the pre-remediation behavior and the new sidebar is not surfaced in production. All Phase 2–7 wiring stays behind this flag until Phase 8 removes it.

**`_getBookStoreSections()` in `sidebar_configuration.dart` (5.2, 5.3).** A new private builder returning the bookStore section list, reached via an explicit `case BusinessType.bookStore:` — no fall-through to `default: _getRetailSections()`. Mirrors the structure of `_getSchoolSections()`/`_getElectronicsSections()`. Items cover **Book Catalogue, Book POS, Consignments, School/Institution Orders, Publisher Returns**, each with a non-empty label and a stable id, gated by the matching already-granted `BusinessCapability` (and a permission tag from Phase 8).

| Section | Item id | Screen | Capability gate |
|---------|---------|--------|-----------------|
| Catalogue | `book_catalogue` | `BookInventoryScreen` | `useStockManagement` |
| Point of Sale | `book_pos` | `BookPosScreen` | `useBarcodeScanner`/`useISBN` |
| Consignments | `book_consignments` | `ConsignmentSettlementScreen` | (new consignment capability, Phase 9) |
| School Orders | `book_school_orders` | `SchoolOrderScreen` | (new school-orders capability, Phase 9) |
| Publisher Returns | `book_publisher_returns` | `BookSupplierReturnsScreen` | `usePublisherReturns` |

**Id resolution (5.4, 5.5).** New `case 'book_*':` branches in `SidebarNavigationHandler.getScreenForItem` (and/or `Content_Host._screenBuilders`) map each id to exactly one existing `Book_Screen`. An id that cannot resolve retains the current screen, performs no navigation, surfaces an "unavailable" indication, and raises no unhandled exception (never the "Feature Not Found" placeholder for a wired id).

**Quick-action repair (5.6, 5.7, 5.8).** In `business_quick_actions.dart` the `bookStore` case is corrected so **Book Search** navigates via an `App_Screens` id that resolves to `BookInventoryScreen` (not the placeholder), **Returns** resolves to `BookSupplierReturnsScreen` (not the placeholder), and **ISBN Scan** invokes a defined action opening the ISBN scan flow (not the empty `onTap`). This requires mapping `AppScreen.bookCatalogue`/`AppScreen.bookReturns` ids into `content_host._screenBuilders`/`getScreenForItem`.

**Guarded routing & GoRouter (5.9, 5.10).** bookStore navigation to school orders and consignments routes through the existing guarded `/book_store/school_orders` and `/book_store/consignments` paths in `app/routes.dart` rather than bypassing them. The GoRouter module is reported report-only and not mounted or migrated (F4).

**Preservation (5.11).** For any `BusinessType` other than `bookStore`, `_getSectionsForBusiness`, `getScreenForItem`, and the quick-actions/alerts resolvers return behavior identical to pre-change.

### Phase 3 — Money logic: per-item GST and settlement cap (Requirement 6)

**Tax-policy hard stop (6.1, 6.2).** While the applicable tax policy is unconfirmed, no rate table is implemented. The system requests explicit confirmation, presenting the option that printed books (HSN 4901) are exempt at 0%, notebooks at 5%, and other stationery at 5%–18% by HSN, before implementing per-item GST.

**Per-item GST (6.3, 6.4, 6.5).** Once confirmed, the GST rate for a line item resolves from the item's tax class or HSN code rather than the single flat `defaultGstRate`. The contradiction between the `BookStoreStrategy` 0% comment, the `defaultGstRate: 12.0` config, and the POS computing no tax is reconciled to one confirmed policy governing all three. `BookPosScreen` computes tax per line item using the resolved rate, renders a tax line in the totals, and expresses every monetary value in integer Paise.

**Consignment settlement cap (6.6, 6.7, 6.8).** A settlement dialog computes the `Settlement_Cap` as `books_sold × unit_settlement_price` in integer Paise and displays the computed expected settlement. A proposed amount exceeding the cap is rejected (persist nothing, over-settlement error identifying the cap). A zero-or-negative proposed amount is rejected (persist nothing, validation error).

**Schema_Gate (6.9).** Where a stored shape must change to carry a tax class, HSN code, or unit settlement price, a Schema_Gate is requested before persisting.

### Phase 4 — Data reality (Requirement 7)

**Real catalogue & grid (7.1, 7.2, 7.3).** `BookInventoryScreen` populates its list from a tenant-scoped Product query (no hardcoded sample rows). `BookPosScreen` populates its grid from a tenant-scoped Product query (not `itemCount: 0`), and its search box filters the grid by term against tenant-scoped products.

**Book metadata (7.4, 7.5).** Adding/editing a book persists author, publisher, and edition to the Product record scoped to the active `Tenant_Id`; if this needs a Product-shape change, a Schema_Gate is requested first.

**Live alerts & endpoints (7.6, 7.7, 7.8).** The `bookStore` branch of `business_alerts_widget.dart` derives each count from a real tenant-scoped query (no `'11'`/`'6'` literals). ISBN metadata resolves through the deployed `GET /book-store/isbn/{isbn}` via `book_repository`; low-stock alerts call `GET /book-store/low-stock` via `book_repository` rather than a hardcoded count.

**Empty & error states (7.9, 7.10).** A tenant-scoped catalogue/search/alert/ISBN-lookup/low-stock query returning no data shows a zero/empty-state indicator; a failing query shows an error indication for the affected surface — never a fabricated value.

### Phase 5 — ISBN validation consolidation (Requirement 8)

**Single validator (8.1, 8.2).** All ISBN validation routes through `BookStoreBusinessRules.isValidIsbn`. The duplicate in `isbn_scanner_widget.dart` and the length-only check in `BookInventoryScreen` are replaced with calls to it.

**Add-book & POS enforcement (8.3, 8.4, 8.5, 8.6).** The Add Book dialog validates the entered ISBN with the checksum validator before persisting; a failing checksum rejects the save, persists nothing, retains entered values, and shows an error on the ISBN field. An ISBN scanned/entered at POS that fails validation is rejected with a validation error rather than adding a cart line. A valid ISBN matching no tenant-scoped product prompts the operator to create the book first and does **not** add a ₹0 placeholder cart line.

### Phase 6 — Publisher returns and real loyalty (Requirement 9)

**Publisher returns (9.1, 9.2, 9.3).** The Publisher Returns tab presents a functional UI backed by `book_repository` (no "future update" placeholder). Submitting a return persists it via `POST /book-store/returns` with a tenant-scoped RID identifier and money in integer Paise. Opening the list loads existing returns via `GET /book-store/returns` scoped to the active `Tenant_Id`.

**Real loyalty (9.4, 9.5, 9.6, 9.7, 9.8).** A customer's loyalty balance derives from an actual points balance, not `customer.totalPaid`. A sale accrues points per the confirmed accrual rule; redemption decreases the balance by the redeemed amount and applies it to the bill total in integer Paise. A redemption exceeding the available balance is rejected (apply nothing, validation error). If persisting a loyalty balance needs a Customer-shape change, a Schema_Gate is requested first.

### Phase 7 — Offline-first migration (Requirement 10)

**Sync_Queue migration (10.1, 10.2, 10.5, 10.6).** `book_repository` migrates off direct `apiClient.get/post` onto the Sync_Queue offline-first pattern used by bills/products. While offline, school-order, consignment, and publisher-return writes queue locally and surface a pending state (not "Failed to load"). Publisher-returns offline behavior is defined explicitly (queueing, conflict handling, reconciliation) consistent with school orders and consignments. Locally persisted data stores currency as integer Paise and identifiers in the RID pattern, and every cached record is scoped by the active `Tenant_Id`.

**Reconciliation & idempotency (10.3, 10.4, 10.7).** On connectivity restore, queued writes flush so each RID-identified record has exactly one stored version with no duplicate; applying the same RID-identified change more than once yields the same persisted result as a single application. A failed sync retains that record's pending local change, leaves successfully synced records unaffected, and retries the failed record on the next connectivity-restored event without discarding it.

### Phase 8 — In-widget RBAC guards; remove Dev_Flag (Requirement 11)

**In-widget checks (11.1–11.5).** `BookPosScreen` invoice generation, `BookInventoryScreen` add/create, and consignment-settlement / school-order-fulfillment writes each verify the acting user holds the required permission before persisting. A user lacking the required permission is blocked (persist nothing, access-denied indication). Because `Content_Host` applies no route guard, the in-widget check is enforced independent of the entry path.

**Go-live (11.6).** On Phase 8 sign-off, the `Dev_Flag` gating is removed so the bookStore sidebar and wiring become live.

### Phase 9 — Capability gating and medium/low polish (Requirement 12)

**Capability entries (12.1).** New `BusinessCapability` entries are added for school/institution orders (and consignment where none exists) so the features are gateable through `FeatureResolver`.

**Polish (12.2–12.6).** `BookPosScreen` lays out its three panes without horizontal overflow on narrow windows (adjust max width or provide a responsive/stacked layout). `book_repository` requests consignments/school-orders in pages rather than one unpaginated call. Async handlers in `SchoolOrderScreen`/`ConsignmentSettlementScreen` guard `BuildContext` after `await` in failure branches with `mounted` checks. The sidebar omits clearly retail-only sections irrelevant to a book store. Accessibility is improved on touched surfaces (low-contrast text, tooltips/`Semantics` on icon-only buttons), noting full WCAG validation needs manual assistive-technology testing.

**Backlog hard stop (12.7).** Used Books (F21), set/bundle class-set composition (F22), Stationery category with mixed GST (F23), and book detail/edit + publisher/school master UI (F31) are flagged backlog and not built without explicit confirmation.

### Phase 10 — Final regression and traceability (Requirement 13)

A final pass runs a repository-wide `TODO`/`FIXME`/`mock`/`stub` search within the book-store trees (recording each remaining occurrence with path + line), the full analyze step, and the book-store test suite (recording total/passed/failed for each); a non-zero error/fail count records a Fail status enumerating each failure. The `Traceability_Matrix` maps every Finding_Id F1–F35 to exactly one of Resolved, Partially-Resolved, Not-Reproduced, Deferred, or Out-of-Scope, none unmapped or multiply-assigned, with cited evidence for Resolved/Partially-Resolved. The report confirms the `Dev_Flag` is removed and navigation is live, records a pass/fail for at least three other verticals (unchanged sidebar/dashboard/quick-actions/alerts), and lists every pending human decision (deferred tax detail, backlog build decisions, pending Schema_Gate/Delete_Gate) with its status.

## Data Models

### Money representation (Requirement 1.1, 6.5, 10.6)

The canonical in-app representation for all touched book-store money is **integer Paise**. Rupee values are derived only at the presentation edge via a single conversion helper (Paise → rupees with exactly two decimals). No arithmetic is performed on rupee doubles.

| Surface | Current (double, rupees) | Target (int, Paise) | Notes |
|---------|--------------------------|---------------------|-------|
| `BookPosScreen` totals | `subtotal`, `discount`, `grandTotal`, (no tax) | `subtotalPaise`, `discountPaise`, `taxPaise`, `grandTotalPaise` | new tax line; per-item GST |
| Consignment settlement | server `settlementAmount` (editable double) | `unitSettlementPricePaise`, `settlementCapPaise`, `proposedSettlementPaise` | cap = `booksSold × unitSettlementPricePaise` |
| Publisher return | amount (double) | `amountPaise` (int) | RID id, tenant-scoped |
| Loyalty | `customer.totalPaid` proxy | `loyaltyPointsBalance` (int), `accruedPoints`, `redeemedPaise` | real balance, accrual/redemption |

Any migration of an existing float currency field to integer Paise is performed only through the Schema_Gate (1.3, 6.9, 9.8).

### RID identifier (Requirement 1.4)

```
{tenantId}-{timestamp_ms}-{uuid_v4_short}
```

`tenantId` is the active `Tenant_Id`, `timestamp_ms` is Unix epoch milliseconds, and `uuid_v4_short` is a non-empty shortened UUID v4. A shared RID generator produces ids for all new book-store entities (publisher returns, queued writes) on touched write paths, replacing any bare UUID generation.

### Consignment settlement model (Requirement 6.6–6.8)

| Field | Type | Notes |
|-------|------|-------|
| `consignmentId` | `String` (RID for new) | tenant-scoped |
| `booksReceived` | `int` | informational |
| `booksSold` | `int` | drives the cap |
| `unitSettlementPricePaise` | `int` | per-book settlement price in Paise |
| `settlementCapPaise` | `int` (derived) | `booksSold × unitSettlementPricePaise` |
| `proposedSettlementPaise` | `int` | operator input; must be `0 < proposed ≤ cap` |

`unsoldReturn = booksReceived − booksSold` is displayed as informational.

### ISBN validation (Requirement 8)

The single authoritative validator is `BookStoreBusinessRules.isValidIsbn(String)` — a full ISBN-10/13 checksum. It is a total, pure predicate: any input (empty, non-digit, wrong length, bad checksum) returns `false`; a correct ISBN-10 or ISBN-13 returns `true`. All entry points (Add Book dialog, POS scan/entry, `isbn_scanner_widget`, `BookInventoryScreen` search) call it.

### Publisher return model (Requirement 9.1–9.3)

| Field | Type | Placeholder/rule |
|-------|------|------------------|
| `id` | `String` (RID) | tenant-scoped, `{tenantId}-{ms}-{uuid}` |
| `tenantId` | `String` | from session |
| `publisherId` / `publisherName` | `String` | |
| `lines` | `List<{productId, qty, amountPaise}>` | money in Paise |
| `totalAmountPaise` | `int` | sum of line amounts |
| `createdAt` | `DateTime` | |

Persisted via `POST /book-store/returns`; listed via `GET /book-store/returns`, tenant-scoped.

### Loyalty model (Requirement 9.4–9.8)

| Field | Type | Notes |
|-------|------|-------|
| `customerId` | `String` | tenant-scoped |
| `loyaltyPointsBalance` | `int` | real balance (not `totalPaid`) |
| `accrualRulePoints` | derived | per confirmed accrual rule |
| `redeemedPaise` | `int` | redemption applied to bill in Paise |

Redemption invariant: `redeemed ≤ loyaltyPointsBalance`; a redemption exceeding the balance is rejected with nothing applied. A Customer-shape change to persist the balance requires a Schema_Gate.

### Sync queue / offline cache (Requirement 10)

| Element | Key fields | Notes |
|---------|-----------|-------|
| Offline write record | `rid` (PK), `tenantId`, `entityType` (`schoolOrder`/`consignment`/`publisherReturn`), `operation`, payload, `pendingSince`, `retryCount`, `lastError`, `failed` | tenant-scoped; currency in Paise |
| Reconciliation | keyed by `rid` | idempotent upsert: re-applying an existing `rid` is a no-op; failed entries retained + retried, never discarded |

Any new Drift table/column is additive with safe defaults and applied only after a Schema_Gate (1.8).

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

These properties are derived from the acceptance-criteria prework and consolidated to remove redundancy. Process-governance, scope, artifact-content, business-decision, and UI-state criteria (all of Requirements 3 and 14; 1.3, 1.6, 1.8, 1.9, 1.13, 1.14; 2.1–2.7; 5.1, 5.2, 5.6–5.10; 6.1, 6.2, 6.4, 6.9; 7.1, 7.2, 7.5–7.10; 8.2; 9.1, 9.3, 9.4, 9.8; 10.1, 10.2, 10.5; 11.6; 12.1–12.7; 13.1–13.6, 13.8, 13.9) are validated by example-based, integration, smoke, or governance checks described in the Testing Strategy, not by properties. Redundant criteria are folded per the prework reflection (integer-Paise → Property 1; RID → Property 2; tenant isolation across repo/handler/cache → Property 3; unresolved-tenant → Property 4; other-types-unchanged → Property 6; sidebar well-formedness+reachability → Property 7; settlement cap+validation → Property 10; ISBN validator + rejection → Properties 12 and 13; sync reconciliation → Property 17; in-widget RBAC → Property 14).

### Property 1: Money is integer Paise

*For any* money value supplied to a touched Book_Store_System path (POS subtotal/discount/tax/total, consignment settlement, publisher-return amount, loyalty redemption), every stored and transmitted monetary result is an `int` number of Paise (never a `double`/`float`), equal to the integer reference computation.

**Validates: Requirements 1.1, 1.2, 6.5, 10.6**

### Property 2: RID identifiers are well-formed

*For any* active tenant id, an identifier produced for a new Book_Store_System entity (publisher return, queued write) matches the pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, embeds that exact tenant id as its prefix, contains a millisecond Unix timestamp segment, and ends with a non-empty shortened UUID v4 segment.

**Validates: Requirements 1.4, 9.2, 10.6**

### Property 3: Tenant isolation across reads, writes, handler, and cache

*For any* two distinct tenant ids and any Book_Store_System records (school orders, consignments, publisher returns, products, cached writes) written under the first, a repository read, backend handler query/write, offline-cache read, or list call performed under the second never returns those records or any of their fields.

**Validates: Requirements 1.5, 4.1, 4.2, 4.3, 4.5, 9.3, 10.6**

### Property 4: Unresolved tenant aborts the operation

*For any* Book_Store_System read or write attempted while the active `Tenant_Id` cannot be resolved, the operation is rejected, performs no read or write, leaves persisted data unchanged, and returns an unresolved-tenant error.

**Validates: Requirements 1.7, 4.4**

### Property 5: Migrations are idempotent

*For any* starting persisted state, applying a Book_Store_System remediation migration or backfill twice produces the same persisted result as applying it once, and the second application modifies zero records.

**Validates: Requirements 1.10**

### Property 6: Other business types are unchanged

*For any* `BusinessType` other than `bookStore`, the sidebar sections, granted capability set, quick-action set, alert set, billing strategy, and config after the remediation are identical (no item added, removed, or reordered) to those before the `case BusinessType.bookStore` additions and the shared-component edits.

**Validates: Requirements 1.11, 1.12, 5.11, 13.7**

### Property 7: Every book sidebar item is well-formed and resolves to a real screen

*For any* bookStore sidebar item produced by `_getBookStoreSections()`, the item's label contains at least one non-whitespace character, the item's id is non-empty and stable, and `SidebarNavigationHandler.getScreenForItem` (or `Content_Host`) resolves the id to exactly one existing `Book_Screen` widget and never the "Feature Not Found" placeholder.

**Validates: Requirements 5.3, 5.4**

### Property 8: Unknown navigation ids are handled safely

*For any* item id not mapped for bookStore, id resolution returns no screen (the placeholder path), retains the current screen, performs no navigation, surfaces an "unavailable" indication, and raises no unhandled exception.

**Validates: Requirements 5.5**

### Property 9: GST rate resolves from tax class or HSN, not a flat rate

*For any* POS line item, once the tax policy is confirmed, the resolved GST rate equals the rate assigned to that item's tax class or HSN code in the confirmed rate table, rather than the single flat `defaultGstRate`.

**Validates: Requirements 6.3**

### Property 10: Consignment settlement is capped and validated

*For any* consignment with `booksSold` and `unitSettlementPricePaise`, the computed `Settlement_Cap` equals `booksSold × unitSettlementPricePaise` in integer Paise; a proposed settlement is accepted if and only if `0 < proposed ≤ cap`, and any proposed amount that exceeds the cap or is zero-or-negative is rejected with nothing persisted and an error identifying the cap or the invalid amount.

**Validates: Requirements 6.6, 6.7, 6.8**

### Property 11: POS invoice total is the integer-Paise sum of per-line tax

*For any* POS cart, the rendered grand total equals `sum(line subtotalPaise + resolved per-line taxPaise) − discountPaise` computed entirely in integer Paise, and a tax line reflecting the summed per-line tax is rendered in the totals.

**Validates: Requirements 6.5**

### Property 12: ISBN validation is a correct checksum predicate

*For any* string, `BookStoreBusinessRules.isValidIsbn` returns `true` if and only if the string is a valid ISBN-10 or ISBN-13 by checksum, and returns `false` for empty, non-digit, wrong-length, or bad-checksum input.

**Validates: Requirements 8.1**

### Property 13: Invalid ISBNs are rejected on add and at POS with no side effects

*For any* ISBN that fails `isValidIsbn`, submitting the Add Book dialog rejects the save (nothing persisted, entered values retained, error on the ISBN field) and scanning/entering it at POS is rejected with a validation error and no cart line added; and *for any* valid ISBN that matches no existing tenant-scoped product, the operator is prompted to create the book and no ₹0 placeholder cart line is added.

**Validates: Requirements 8.3, 8.4, 8.5, 8.6**

### Property 14: Money and create writes are gated by an in-widget permission check

*For any* acting user role and any guarded book-store write (POS invoice generation, inventory add/create, consignment settlement, school-order fulfillment), the write persists if and only if the role holds the required permission; a role lacking it is blocked with nothing persisted and an access-denied indication, independent of whether the screen was reached through a guarded route or through `Content_Host`.

**Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

### Property 15: Loyalty accrual increases the balance by the confirmed rule

*For any* completed sale that accrues loyalty, the customer's new loyalty balance equals the previous balance plus the points computed by the confirmed accrual rule applied to that sale.

**Validates: Requirements 9.5**

### Property 16: Loyalty redemption is bounded and applied in Paise

*For any* redemption request against a customer balance, the redemption is accepted if and only if the redeemed amount does not exceed the available balance; when accepted the new balance equals the old balance minus the redeemed amount and the bill total is reduced by the redeemed amount in integer Paise; when it exceeds the balance it is rejected with nothing applied and a validation error.

**Validates: Requirements 9.6, 9.7**

### Property 17: Sync reconciliation is idempotent and duplicate-free

*For any* set of queued offline writes and any number of flush attempts, after reconciliation each RID-identified record has exactly one stored version and applying the same RID-identified change more than once produces the same persisted result as a single application.

**Validates: Requirements 10.3, 10.4**

### Property 18: Failed sync entries are retained and retried, never discarded

*For any* sequence of sync entries containing a forced-failure entry, the failed entry retains its pending local change and is retried on the next connectivity-restored event, while successfully synced entries are unaffected and never re-applied or lost.

**Validates: Requirements 10.7**

### Property 19: POS search returns only matching tenant-scoped products

*For any* search term and any set of tenant-scoped products, every product returned by the `BookPosScreen` search matches the search term and belongs to the active `Tenant_Id`, and no non-matching or cross-tenant product is returned.

**Validates: Requirements 7.3**

### Property 20: Book metadata round-trips through the Product record

*For any* book with author, publisher, and edition values, saving it and then reading it back under the active `Tenant_Id` returns the same author, publisher, and edition values.

**Validates: Requirements 7.4**

## Error Handling

Error handling follows DukanX conventions (observable response or propagation; never a silent swallow) and the requirements' explicit error behaviors:

- **Tenant context unavailable (1.5, 1.7, 4.4).** If the active `Tenant_Id` cannot be resolved from the session, the operation aborts, accesses no data, leaves persisted data unchanged, and returns an unresolved-tenant error.
- **Cross-tenant reference (4.5).** A request referencing a record from another tenant is denied, returning neither the record nor any field.
- **Unknown navigation id (5.5).** An unmapped bookStore id resolves to no screen, the current screen is retained, an "unavailable" indication is shown, and no unhandled exception is raised — never the "Feature Not Found" placeholder for a wired id.
- **Dashboard/alert query states (7.9, 7.10).** An empty result shows a zero/empty-state indicator; a failed query shows an error indication for the affected surface — neither fabricates a count.
- **GST/settlement validation (6.7, 6.8).** A proposed settlement above the cap or zero/negative rejects the settlement, persists nothing, and shows an over-settlement or validation error identifying the cap.
- **ISBN validation (8.4, 8.5, 8.6).** A failing ISBN checksum on add rejects the save (nothing persisted, values retained, field error); at POS it is rejected with a validation error and no cart line; a valid-but-unknown ISBN prompts to create the book and adds no ₹0 line.
- **Loyalty redemption (9.7).** A redemption exceeding the available balance is rejected, applies nothing to the bill, and shows a validation error.
- **RBAC denial (11.4, 11.5).** A user lacking the required permission for an invoice, product, settlement, or fulfillment write is blocked, persists nothing, and sees an access-denied indication regardless of entry path.
- **Sync failures (10.7).** A failed sync entry retains its pending local change, leaves successfully synced records unaffected, and is retried on the next connectivity-restored event; it is never discarded.
- **Async lifecycle (12.4).** Async handlers in `SchoolOrderScreen`/`ConsignmentSettlementScreen` guard `BuildContext` after `await` in failure branches with a `mounted` check to avoid use-after-dispose exceptions.
- **Governance halts (1.3, 1.8, 1.9, 6.1, 6.2, 12.7, 14.x).** Schema changes (Schema_Gate), hard deletions (Delete_Gate: reference search + sign-off), unconfirmed tax policy, unconfirmed backlog build decisions, out-of-scope changes, and phase completion halt for explicit recorded sign-off rather than proceeding.

## Testing Strategy

Property-based testing **is appropriate** for this feature: integer-Paise money invariants, RID well-formedness, tenant isolation, idempotent migration and sync reconciliation, ISBN checksum validation, settlement-cap math and validation, POS per-line tax totals, loyalty accrual/redemption bounds, in-widget RBAC, search filtering, metadata round-trip, and the other-types-unchanged invariant are pure-logic surfaces with universal "for all inputs" statements. Navigation wiring, endpoint integration, dashboard/data-source wiring, UI loading/empty/error states, theming, accessibility, and the Phase 0/9/10 artifacts are validated by example, widget, integration, smoke, or governance checks.

A property-based testing library is used for the language under test (Dart: `package:test` with a property-based helper such as `glados`; the `book_store.ts` backend logic uses `fast-check`). Properties are **not** implemented from scratch.

### Property-based tests

- Each correctness property above is implemented by a **single** property-based test running a **minimum of 100 iterations**.
- Each test is tagged with a comment referencing its design property in the format: **Feature: bookstore-vertical-remediation, Property {number}: {property_text}**.
- Generators: money generators produce integer Paise so floating-point never enters assertions (Properties 1, 10, 11, 16); tenant generators produce distinct tenant pairs, including ids containing hyphens (Properties 2, 3); ISBN generators produce valid ISBN-10/13 alongside malformed/wrong-length/bad-checksum strings (Properties 12, 13); cart/line generators vary quantities, prices, discounts, and tax classes (Properties 9, 11); settlement generators vary `booksSold`/`unitSettlementPricePaise`/`proposed` including over-cap and non-positive values (Property 10); redemption generators include amounts above and below balance (Property 16); sync generators include forced-failure transports and repeated RID-identified changes (Properties 17, 18); role generators cover every acting role including ones lacking the permission (Property 14).
- **Highest-value properties to land first:** Property 1 (integer Paise), Property 3 (tenant isolation), Property 6 (other types preserved), Property 7 (sidebar reachability), Property 10 (settlement cap), Property 12/13 (ISBN validation), Property 14 (in-widget RBAC), Property 17 (sync reconciliation).

### Example-based unit & widget tests (non-property criteria)

- **Sidebar/scope (5.1, 5.2):** with the `Dev_Flag` off, `getSectionsForBusinessType(bookStore)` returns the pre-remediation behavior; with it on, it returns `_getBookStoreSections()` (not retail default).
- **Quick actions (5.6, 5.7, 5.8):** Book Search resolves to `BookInventoryScreen`, Returns to `BookSupplierReturnsScreen`, ISBN Scan opens the scan flow (no empty `onTap`) — none resolve to the placeholder.
- **Guarded routing (5.9):** school-orders/consignments navigation goes through the existing guarded `/book_store/*` routes.
- **GST reconciliation (6.4):** a single confirmed policy governs strategy, config, and POS.
- **Data reality (7.1, 7.2, 7.6):** catalogue and POS grid populate from tenant-scoped queries; the `bookStore` alert branch reads counts from a provider/query, not the `'11'`/`'6'` literals.
- **Data UI states (7.9, 7.10):** empty result renders an empty-state; failed query renders an error indication.
- **Publisher returns / loyalty source (9.1, 9.4):** the returns tab renders a functional UI (no placeholder); the loyalty display reads the real balance field, not `customer.totalPaid`.
- **Capability wiring (12.1):** the new school-orders/consignment capabilities resolve through `FeatureResolver`.
- **Layout/pagination/a11y/mounted (12.2–12.6):** POS lays out without overflow at narrow width; repo requests pages; failure branches carry `mounted` guards; icon-only buttons carry `Semantics`/tooltips; sidebar omits named retail-only ids.

### Integration & smoke tests (not PBT)

- **Endpoint wiring (7.7, 7.8, 9.2, 9.3):** 1–3 integration examples confirming the client calls `GET /book-store/isbn/{isbn}`, `GET /book-store/low-stock`, and `POST`/`GET /book-store/returns`.
- **Offline-first (10.1, 10.2, 10.5):** integration examples confirming `book_repository` routes through the Sync_Queue, queues writes while offline with a pending state, and defines the publisher-return offline path consistently with orders/consignments.
- **Handler contract (4.6):** a contract test confirming non-tenant request/response fields are unchanged after tenant scoping is added.

### Governance checks (process gates)

Schema_Gate (Product/Customer/Drift shape changes: 1.8, 6.9, 7.5, 9.8), Delete_Gate (reference search + `APPROVED`: 1.9), STOP GATE adherence and the literal gate text (14.1–14.5, 14.7), business-decision halts (tax policy 6.1/6.2, backlog build 12.7, 14.6), the honesty rule (1.13, 1.14), the Dev_Flag lifecycle (5.1, 11.6, 13.6), and the Phase 0/10 artifact completeness (Requirement 3; 13.1–13.6, 13.8, 13.9) are process checks recorded at each phase gate.

### Regression suite (Requirements 1.11, 1.12, 13.7)

Each phase compares every non-bookStore vertical against a recorded pre-change baseline across sidebar sections, capability flags, quick-action set, alert set, billing strategy, and config, passing only when zero items change in any category for any vertical. Property 6 provides automated, input-varying coverage of this no-regression invariant; the full existing test suite runs at the Phase 10 gate to confirm no other vertical regressed and that at least three verticals resolve unchanged behavior before the vertical is declared shippable.
