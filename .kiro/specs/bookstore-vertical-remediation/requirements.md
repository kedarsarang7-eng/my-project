# Requirements Document

## Introduction

The DukanX `bookStore` business vertical (`BusinessType.bookStore`, display name "Book Store") ships a substantial dedicated feature set under `lib/features/book_store/` — a POS screen, an inventory/catalogue screen, a publisher/supplier returns screen, a consignment settlement screen, a school/institution order screen, ISBN scanner and loyalty widgets, a `book_repository`, a `BookStoreBusinessRules` utility, a `BookStoreStrategy`, and a GoRouter module under `lib/modules/book_store/` — plus backend handlers in `my-backend/src/handlers/book_store.ts`. However, this feature set is largely **unreachable, mock-backed, or logically inconsistent**. The sidebar dispatcher `_getSectionsForBusiness` in `sidebar_configuration.dart` has no `case BusinessType.bookStore` (verified: no `BusinessType.bookStore` reference exists in that file), so a book-store operator falls through to `default: _getRetailSections()` and sees a generic retail sidebar with zero book-specific entries. Five book screens are orphaned, three dashboard quick actions are dead, dashboard alert counts are hardcoded, the catalogue and POS grids are mock/empty, GST handling is self-contradictory (a `defaultGstRate: 12.0` config — verified — versus a strategy comment claiming 0% versus a POS that adds no tax at all), three inconsistent ISBN validators coexist, the Add Book dialog performs no ISBN validation, loyalty is a `totalPaid` proxy, publisher returns is a placeholder, `book_repository` has no offline-first path, and money/create actions have no in-widget RBAC.

The strategic directive for this remediation is **restore reachability and integrity, not rebuild**. The existing `Book*Screen` widgets, `book_repository`, `BookStoreBusinessRules`, and `BookStoreStrategy` are treated as assets to wire, correct, and harden — not liabilities to replace. Work proceeds strictly in phase order (Phase 0 through Phase 10). Phase 0 is read-only pre-flight verification that resolves each audit assumption to CONFIRMED, NOT-REPRODUCED, or UNVERIFIABLE. Each subsequent phase ends with an explicit STOP GATE requiring human sign-off before the next begins. All work is bound by a set of non-negotiable cross-cutting constraints (integer-paise money, the RID id pattern, tenant scoping on every query, schema-change and hard-delete confirmation gates, idempotent migrations, and a "do not fabricate completion" honesty rule). Two decision areas — the GST/tax policy for books versus stationery (Phase 3) and the build-versus-defer decision for backlog features (Phase 9) — are gated behind explicit human confirmation because they are business decisions, not engineering choices.

The vertical is referred to throughout as the **Book_Store_System**. Requirements are grouped by the phase that delivers them and map back to the traceability-matrix finding IDs (F1–F35) they remediate. Findings that do not reproduce against the live codebase are recorded as "not reproduced" rather than silently skipped. The authoritative source for detail is `audit-reports/business-types/audit-bookStore.md`.

## Glossary

- **Book_Store_System**: The `bookStore` business vertical of the DukanX Flutter app, encompassing its screens, repository, business rules, strategy, providers, sync/websocket handlers, routes, capabilities, dashboard widgets, and sidebar configuration. Identified by `BusinessType.bookStore`.
- **Book_Store_Feature**: The existing code under `lib/features/book_store/` and `lib/modules/book_store/` — the `Book*Screen` widgets, `book_repository.dart`, `book_store_business_rules.dart`, ISBN/loyalty widgets, module, and routes that implement Book_Store_System functionality.
- **Book_Repository**: `lib/features/book_store/data/book_repository.dart` — the repository for school-order, consignment, and (to be added) publisher-return reads and writes. Currently calls `apiClient.get/post` directly with no offline queue.
- **Book_Store_Business_Rules**: `lib/features/book_store/utils/book_store_business_rules.dart` — the Book_Store_System rules utility that contains the authoritative `isValidIsbn` ISBN-10/13 checksum validator and `suggestedResalePrice`/`BookCondition` helpers.
- **Book_Store_Strategy**: `lib/core/billing/strategies/book_store_strategy.dart` — the billing strategy for the vertical whose doc comment currently claims books are GST-exempt (0%).
- **Book_Screen**: Any `Book*Screen`/order/consignment widget under `lib/features/book_store/presentation/screens/` — specifically `BookPosScreen`, `BookInventoryScreen`, `BookSupplierReturnsScreen`, `ConsignmentSettlementScreen`, and `SchoolOrderScreen`.
- **Sidebar_Configuration**: `lib/widgets/desktop/sidebar_configuration.dart` — defines per-business-type sidebar sections via `_getSectionsForBusiness`. A Shared_Component. bookStore currently falls through to `default: _getRetailSections()`.
- **Sidebar_Navigation_Handler**: `lib/widgets/desktop/sidebar_navigation_handler.dart` — resolves a sidebar item id to a screen widget via `getScreenForItem`.
- **Content_Host**: `lib/widgets/desktop/content_host.dart` — hosts and caches built screens via `_screenBuilders`/`_buildScreen` for the desktop shell.
- **Business_Capability**: `lib/core/isolation/business_capability.dart` — the capability registry whose `bookStore` set grants `useISBN`, `usePublisherReturns`, `useLoyaltyPoints`, and related keys, resolved through `FeatureResolver`.
- **Business_Quick_Actions**: `lib/features/dashboard/v2/widgets/business_quick_actions.dart` — dashboard quick-action buttons resolved per `BusinessType`. A Shared_Component.
- **Business_Alerts_Widget**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` — dashboard alert-count widget resolved per `BusinessType`. A Shared_Component. The bookStore branch currently returns hardcoded counts `'11'` and `'6'`.
- **App_Screens**: `lib/core/navigation/app_screens.dart` — the `AppScreen` enum and its `id`/`fromId` mapping, including `bookCatalogue` and `bookReturns`.
- **Navigation_Controller**: `lib/core/navigation/navigation_controller.dart` — the live navigation controller for the desktop shell.
- **App_Routes**: `lib/app/routes.dart` — the `MaterialApp.routes` named-route table (live source of truth for named routes), including the guarded `/book_store/school_orders` and `/book_store/consignments` entries.
- **Go_Router_Module**: `lib/modules/book_store/book_store_module.dart` and `routes/book_store_routes.dart` — GoRouter constructs (`/books/*` routes, `navItems`) that are NOT mounted by the live app; report-only in this remediation (F4).
- **Business_Type_Config**: `lib/core/billing/business_type_config.dart` — the per-business-type config; the bookStore block sets `defaultGstRate: 12.0`, `gstEditable: true` (verified).
- **Book_Store_Handler**: `my-backend/src/handlers/book_store.ts` — the AWS Lambda handler exposing ISBN lookup, low-stock, returns, consignments, school-orders, and customer-loyalty endpoints.
- **ISBN_Validator**: A function that validates an ISBN-10 or ISBN-13 value. Three currently coexist: the authoritative checksum validator in Book_Store_Business_Rules (`isValidIsbn`), a duplicate in `isbn_scanner_widget.dart`, and a length-only check in `BookInventoryScreen`.
- **Consignment_Settlement**: The sale-or-return settlement flow in `ConsignmentSettlementScreen`, in which a publisher is paid for books sold; settlement amount is currently server-provided and freely editable with no computed cap.
- **Settlement_Cap**: The computed maximum settlement amount for a consignment, equal to `books_sold × unit_settlement_price` in integer paise, above which a settlement is over-settled.
- **Loyalty_Points**: A customer's redeemable points balance. Currently faked as `customer.totalPaid` (lifetime spend) with no accrual or redemption.
- **Sync_Queue**: The app's offline-first queue used by bills/products repositories; Book_Repository is to be migrated onto it (F25).
- **Dev_Flag**: A development-only feature flag that keeps the new bookStore sidebar and wiring hidden in production until Phase 3 and Phase 8 are signed off, and is removed in Phase 10.
- **Tenant_Id**: The authenticated business identity (`tenantId`/`vendorId` as confirmed in Phase 0) used to scope every read, write, and sync call. No hardcoded `'SYSTEM'` or other tenant literal is permitted.
- **Paise**: Integer representation of currency (1 rupee = 100 Paise). All money values in touched Book_Store_System code are integer Paise.
- **RID**: The new-entity identifier pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, where `tenantId` is the active Tenant_Id, `timestamp_ms` is the Unix epoch time in milliseconds, and `uuid_v4_short` is a non-empty shortened form of a UUID version 4.
- **Shared_Component**: A cross-vertical file that spans more than one business type: `sidebar_configuration.dart`, `sidebar_navigation_handler.dart`, `content_host.dart`, `business_capability.dart`, `business_quick_actions.dart`, `business_alerts_widget.dart`, `app_screens.dart`, `navigation_controller.dart`, `app/routes.dart`, and `business_type_config.dart`.
- **Verification_Report**: The read-only Phase 0 Markdown artifact documenting GoRouter mount status, settle/fulfill route pairing, tenant/vendorId isolation, existing-test results, and Product/Customer schema, containing zero code changes.
- **Traceability_Matrix**: The Phase 10 Markdown artifact mapping every finding (F1–F35) to exactly one of Resolved, Partially-Resolved, Not-Reproduced, Deferred, or Out-of-Scope.
- **Finding_Id**: One of the audit finding identifiers F1 through F35 from the traceability matrix.
- **Not_Reproduced**: The status assigned to a finding whose described condition cannot be reproduced against the live codebase during verification.
- **Stop_Gate**: A point at which Book_Store_System work for a phase stops and waits for explicit human approval. Emitted as the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and resumed only on the literal reply `APPROVED`.
- **Schema_Gate**: A separate, explicit sign-off required before any change to a stored data shape (a DynamoDB item shape, a persisted Product/Customer field, or a Drift table), accompanied by the proposed change, every consumer it affects, and a migration plan.
- **Delete_Gate**: A separate, explicit sign-off required before any hard deletion of a file, route, screen, or code symbol, accompanied by a repository-wide reference-search result showing zero live references.
- **Phase_Report**: The written deliverable produced at the end of each phase listing files touched, exact changes, verification steps run and their results, Finding_Ids closed, unverifiable items, and decisions needed.

## Requirements

### Requirement 1: Cross-Cutting Non-Negotiable Constraints

**User Story:** As the platform owner, I want every change in this remediation to honor the platform's money, identity, tenant-isolation, and safety invariants, so that the Book_Store_System is remediated without introducing currency errors, data leakage, or destructive side effects.

#### Acceptance Criteria

1. WHERE money values are represented in code created or modified by this remediation, THE Book_Store_System SHALL store, compute, and transmit currency as integer Paise.
2. THE Book_Store_System SHALL NOT introduce `double`, `float`, or decimal floating-point types for currency values in code created or modified by this remediation.
3. IF this remediation touches an existing floating-point currency field, THEN THE Book_Store_System SHALL migrate it to integer Paise only via the Schema_Gate process and SHALL NOT alter it silently.
4. WHEN the Book_Store_System creates a new entity identifier, THE Book_Store_System SHALL generate it using the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, where `tenantId` is the active Tenant_Id, `timestamp_ms` is the Unix epoch time in milliseconds, and `uuid_v4_short` is a non-empty shortened form of a UUID version 4.
5. WHERE the Book_Store_System reads, writes, or synchronizes book-store data, THE Book_Store_System SHALL scope every query, repository call, and sync call by the active Tenant_Id.
6. THE Book_Store_System SHALL NOT use a hardcoded tenant literal such as `'SYSTEM'`, and SHALL resolve the Tenant_Id from the authenticated session for every read and write.
7. IF the Tenant_Id is missing or cannot be resolved, THEN THE Book_Store_System SHALL reject the operation, perform no read or write, leave persisted data unchanged, and return an error indicating an unresolved tenant.
8. IF a change requires altering a stored data shape, including a DynamoDB item shape, a persisted Product or Customer field, or a Drift table definition, THEN THE Book_Store_System SHALL halt and request a Schema_Gate that states the proposed change, lists every consumer of the changed shape, and presents a migration plan, before applying the change.
9. IF a change requires a hard deletion of a file, route, screen, or code symbol, THEN THE Book_Store_System SHALL first run a repository-wide reference search for that symbol, record the result and an explicit deletion request in the Phase_Report, and SHALL NOT perform the deletion until a Delete_Gate sign-off consisting of the literal reply `APPROVED` is received.
10. WHERE the Book_Store_System applies a data migration or backfill, THE Book_Store_System SHALL make it idempotent such that repeated executions produce the same persisted result and modify zero records after the first execution.
11. WHEN the Book_Store_System modifies a Shared_Component, THE Book_Store_System SHALL make additive edits scoped to the `bookStore` branch or case only and SHALL preserve the behavior of every business type other than `bookStore`.
12. THE Book_Store_System SHALL NOT modify the sidebar sections, quick actions, alerts, capability set, billing strategy, or config of any business type other than `bookStore`.
13. IF a claim about the code cannot be statically verified, THEN THE Book_Store_System SHALL flag the claim as unverifiable in the Phase_Report and SHALL NOT report it as complete.
14. THE Book_Store_System SHALL NOT report a Finding_Id as resolved unless the resolution is demonstrable by a cited change, test result, or search result recorded in the Phase_Report.

### Requirement 2: Scope Boundary

**User Story:** As a maintainer, I want the remediation boundary fixed in advance, so that the work stays surgical and restores existing code instead of expanding into rewrites or out-of-scope migrations.

#### Acceptance Criteria

1. THE Book_Store_System SHALL restrict freely-editable code changes to exactly these locations: files under `lib/features/book_store/**`, files under `lib/modules/book_store/**`, `lib/core/billing/strategies/book_store_strategy.dart`, `my-backend/src/handlers/book_store.ts`, and `test/features/book_store/**`.
2. WHERE the Book_Store_System edits a Shared_Component, THE Book_Store_System SHALL limit the edit to the `bookStore` branch or `case BusinessType.bookStore` only and SHALL leave every other branch identical to its pre-change state.
3. THE Book_Store_System SHALL NOT modify code belonging to any other business vertical.
4. THE Book_Store_System SHALL NOT perform the app-wide `MaterialApp.routes`-to-GoRouter migration and SHALL treat it as a separate out-of-scope initiative, reporting on it only (F4).
5. THE Book_Store_System SHALL restore, correct, and harden the existing Book_Store_Feature code rather than rebuilding or replacing working screens.
6. IF a `Book_Screen` widget or Book_Repository compiles without errors under the project's analyze step and passes the existing tests, THEN THE Book_Store_System SHALL treat it as an asset to wire and SHALL NOT rebuild or replace it.
7. IF a proposed change falls outside the boundary defined in criteria 1 and 2, THEN THE Book_Store_System SHALL not apply the change, SHALL leave existing files unmodified, and SHALL surface a request for explicit sign-off identifying the specific out-of-scope change before proceeding.

### Requirement 3: Phase 0 — Pre-Flight Verification (Read-Only)

**User Story:** As a maintainer, I want every audit assumption re-verified against the live codebase before any code change, so that subsequent phases act on confirmed facts rather than stale assumptions.

#### Acceptance Criteria

1. WHILE executing Phase 0, THE Book_Store_System SHALL create, modify, and delete zero files other than the single Verification_Report artifact, and SHALL NOT modify any application source, configuration, or build file.
2. THE Verification_Report SHALL record the GoRouter mount status for the Go_Router_Module (F4) as exactly one of mounted or not-mounted, citing the file path and evidence, and SHALL classify F4 as report-only.
3. THE Verification_Report SHALL record whether the client-called settle and fulfill routes (`POST /books/consignments/{id}/settle`, `POST /books/school-orders/{id}/fulfill`) are paired with a deployed Book_Store_Handler route (F24), classifying each as exactly one of paired, unpaired, or unverified, and recording the observed or expected request path.
4. THE Verification_Report SHALL record the result of a repository-wide search for hardcoded `tenantId`, `vendorId`, or `'SYSTEM'` literals and for unscoped reads/writes within `lib/features/book_store/**` and the `bookStore` path of `my-backend/src/handlers/book_store.ts` (F29), citing file path and line number for each occurrence found, and SHALL explicitly record "none found" when the search returns zero occurrences.
5. THE Verification_Report SHALL record the result of running the existing `test/features/book_store/**` test suite, capturing the total, passed, and failed counts.
6. THE Verification_Report SHALL record the confirmed persisted shape of the Product record and the Customer record, listing the fields relevant to author, publisher, edition, and loyalty, so that later phases can determine which additions require a Schema_Gate.
7. WHERE the Verification_Report evaluates a Finding_Id, THE Verification_Report SHALL mark that finding as exactly one of CONFIRMED, Not_Reproduced, or UNVERIFIABLE with supporting file path and line number.
8. IF a finding described in the traceability matrix cannot be reproduced against the live codebase, THEN THE Verification_Report SHALL record it as Not_Reproduced with the evidence examined and SHALL NOT silently omit it.
9. WHEN Phase 0 completes, THE Verification_Report SHALL contain a recorded result for every check defined in criteria 2 through 8 with no checked item left unclassified.
10. IF a Phase 0 finding contradicts an assumption that a later phase depends on, THEN THE Book_Store_System SHALL record the contradiction in the Verification_Report and SHALL block the dependent phase until the contradiction is resolved by sign-off.

### Requirement 4: Phase 1 — Tenant Isolation and Security Baseline

**User Story:** As a security owner, I want tenant and vendor isolation confirmed and enforced on every book-store read and write, so that no operator can read or mutate another tenant's book-store data.

#### Acceptance Criteria

1. WHERE the Phase 0 Verification_Report recorded a tenant-scoping gap in `lib/features/book_store/**` or the `bookStore` path of Book_Store_Handler (F29), THE Book_Store_System SHALL add the active Tenant_Id filter so that the affected read or write is tenant-scoped.
2. WHEN Book_Repository issues a read or write for school orders, consignments, or publisher returns, THE Book_Store_System SHALL include the active Tenant_Id in the request such that the response contains only records belonging to that Tenant_Id.
3. WHEN Book_Store_Handler processes a book-store request, THE Book_Store_System SHALL derive the tenant boundary from the authenticated request context and SHALL scope every DynamoDB query and write by that boundary.
4. IF a book-store read or write is attempted without a resolvable Tenant_Id, THEN THE Book_Store_System SHALL reject the operation, perform no read or write, and return an error indicating an unresolved tenant.
5. IF a book-store request references a record whose Tenant_Id differs from the requester's Tenant_Id, THEN THE Book_Store_System SHALL deny the operation and return neither the record nor any of its fields.
6. WHEN the Book_Store_System modifies Book_Store_Handler for tenant isolation, THE Book_Store_System SHALL preserve the request/response contract for all fields other than the added tenant scoping.

### Requirement 5: Phase 2 — Navigation and Wiring (Behind a Dev Flag)

**User Story:** As a book-store operator, I want a dedicated bookStore sidebar whose items open the existing `Book_Screen` widgets and whose dashboard quick actions work, so that I can reach every book feature from normal navigation instead of a generic retail sidebar.

#### Acceptance Criteria

1. WHILE the Dev_Flag is disabled, THE Book_Store_System SHALL present the pre-remediation navigation for `bookStore` unchanged and SHALL NOT surface the new bookStore sidebar in production.
2. WHILE the Dev_Flag is enabled AND `_getSectionsForBusiness` is called with `BusinessType.bookStore`, THE Sidebar_Configuration SHALL return a dedicated bookStore section list via an explicit `case BusinessType.bookStore` and SHALL NOT fall through to `default: _getRetailSections()` (F1).
3. WHILE the Dev_Flag is enabled, THE Sidebar_Configuration SHALL return bookStore items covering Book Catalogue, Book POS, Consignments, School/Institution Orders, and Publisher Returns, each with a label containing at least one non-whitespace character and a stable id (F1, F2).
4. THE Sidebar_Navigation_Handler or Content_Host SHALL map each bookStore sidebar item id to exactly one corresponding existing `Book_Screen` widget, resolving `BookInventoryScreen`, `BookPosScreen`, `ConsignmentSettlementScreen`, `SchoolOrderScreen`, and `BookSupplierReturnsScreen` (F2).
5. IF a bookStore sidebar item id cannot be resolved to a `Book_Screen`, THEN THE Sidebar_Navigation_Handler SHALL retain the current screen, perform no navigation, surface an indication that the destination is unavailable, and raise no unhandled exception.
6. WHEN the bookStore dashboard quick action "Book Search" is activated, THE Business_Quick_Actions SHALL navigate to the book catalogue screen via an `App_Screens` id that resolves to an existing `Book_Screen` and not to a "Feature Not Found" placeholder (F3).
7. WHEN the bookStore dashboard quick action "Returns" is activated, THE Business_Quick_Actions SHALL navigate to the publisher/supplier returns screen via an `App_Screens` id that resolves to an existing `Book_Screen` and not to a placeholder (F3).
8. WHEN the bookStore dashboard quick action "ISBN Scan" is activated, THE Business_Quick_Actions SHALL invoke a defined action that opens the ISBN scan flow and SHALL NOT execute an empty no-op handler (F3).
9. WHERE named-route guards already exist for `/book_store/school_orders` and `/book_store/consignments` (F5), THE Book_Store_System SHALL route bookStore navigation to those screens through the existing guarded paths rather than bypassing them.
10. THE Book_Store_System SHALL report the GoRouter mount status for the Go_Router_Module as report-only and SHALL NOT mount or migrate it in this phase (F4).
11. WHEN `_getSectionsForBusiness`, `getScreenForItem`, or the quick-actions/alerts resolver is called with any `BusinessType` other than `bookStore`, THE Shared_Component SHALL return behavior identical to its pre-change state.

### Requirement 6: Phase 3 — Money Logic (Per-Item GST and Consignment Settlement Cap)

**User Story:** As a book-store operator, I want GST computed per item by tax class and consignment settlements capped at the amount actually owed, so that invoices are tax-correct and I never over-pay a publisher.

#### Acceptance Criteria

1. WHILE the applicable tax policy (books-only versus books-plus-stationery, and the per-category rate table) is unconfirmed, THE Book_Store_System SHALL treat the GST rate model as a hard stop and SHALL NOT implement a rate table.
2. THE Book_Store_System SHALL request explicit confirmation of the tax policy, presenting the option that printed books (HSN 4901) are exempt at 0%, notebooks are taxed at 5%, and other stationery is taxed at 5% to 18% by HSN, before implementing per-item GST (F6, F7).
3. WHEN the tax policy is confirmed, THE Book_Store_System SHALL resolve the GST rate for a line item from the item's tax class or HSN code rather than from a single flat `defaultGstRate` field (F7).
4. THE Book_Store_System SHALL reconcile the contradiction between the Book_Store_Strategy 0% comment, the `defaultGstRate: 12.0` config, and the POS computing no tax, so that a single confirmed policy governs all three (F6).
5. WHEN `BookPosScreen` computes an invoice total, THE Book_Store_System SHALL compute tax per line item using the resolved per-item GST rate, SHALL render a tax line in the totals, and SHALL express every monetary value in integer Paise (F6).
6. WHEN a consignment settlement dialog is presented, THE Book_Store_System SHALL compute the Settlement_Cap as `books_sold × unit_settlement_price` in integer Paise and SHALL display the computed expected settlement (F8).
7. IF a proposed consignment settlement amount exceeds the Settlement_Cap, THEN THE Book_Store_System SHALL reject the settlement, persist nothing, and present an over-settlement error identifying the cap (F8).
8. IF a proposed consignment settlement amount is zero or negative, THEN THE Book_Store_System SHALL reject the settlement, persist nothing, and present a validation error.
9. WHERE a stored data shape must change to carry a tax class, HSN code, or unit settlement price, THE Book_Store_System SHALL request a Schema_Gate before persisting the new shape.

### Requirement 7: Phase 4 — Data Reality

**User Story:** As a book-store operator, I want the catalogue, POS search, dashboard alerts, and book metadata backed by real tenant-scoped data, so that the screens reflect my actual inventory instead of mock rows and fabricated counts.

#### Acceptance Criteria

1. WHEN `BookInventoryScreen` renders its catalogue list, THE Book_Store_System SHALL populate the list from a tenant-scoped Product query and SHALL NOT display the hardcoded sample rows (F9).
2. WHEN `BookPosScreen` renders its product grid, THE Book_Store_System SHALL populate the grid from a tenant-scoped Product query rather than an empty `itemCount: 0` list (F10).
3. WHEN a user enters text in the `BookPosScreen` search box, THE Book_Store_System SHALL filter the product grid by the search term and return matching tenant-scoped products (F10).
4. WHEN a book is added or edited, THE Book_Store_System SHALL persist the author, publisher, and edition values to the Product record scoped to the active Tenant_Id (F12).
5. IF persisting author, publisher, or edition requires a change to the Product data shape, THEN THE Book_Store_System SHALL request a Schema_Gate before persisting (F12).
6. WHEN the bookStore dashboard alerts render, THE Business_Alerts_Widget SHALL derive each displayed count from a real tenant-scoped query and SHALL NOT display the hardcoded literals `'11'` or `'6'` (F11).
7. WHEN the Book_Store_System resolves ISBN metadata during catalogue entry or POS scan, THE Book_Store_System SHALL call the deployed ISBN-lookup endpoint (`GET /book-store/isbn/{isbn}`) via Book_Repository (F18).
8. WHEN the Book_Store_System computes low-stock alerts, THE Book_Store_System SHALL call the deployed low-stock endpoint (`GET /book-store/low-stock`) via Book_Repository rather than using a hardcoded count (F19).
9. IF a tenant-scoped catalogue, search, alert, ISBN-lookup, or low-stock query returns no data, THEN THE Book_Store_System SHALL display a zero or empty-state indicator rather than a fabricated or placeholder value.
10. IF a tenant-scoped catalogue, search, alert, ISBN-lookup, or low-stock query fails, THEN THE Book_Store_System SHALL present an error indication for the affected surface and SHALL NOT display a fabricated value.

### Requirement 8: Phase 5 — ISBN Validation Consolidation

**User Story:** As a book-store operator, I want one correct ISBN validator enforced everywhere, so that invalid ISBNs are rejected on entry and scan and no zero-priced book is ever added to a sale.

#### Acceptance Criteria

1. THE Book_Store_System SHALL consolidate ISBN validation onto the single authoritative `BookStoreBusinessRules.isValidIsbn` checksum validator and SHALL route every ISBN validation call through it (F13).
2. WHERE the duplicate ISBN validator in `isbn_scanner_widget.dart` and the length-only check in `BookInventoryScreen` exist, THE Book_Store_System SHALL replace their use with `BookStoreBusinessRules.isValidIsbn` (F13).
3. WHEN the Add Book dialog is submitted, THE Book_Store_System SHALL validate the entered ISBN with `BookStoreBusinessRules.isValidIsbn` before persisting (F14).
4. IF the Add Book dialog ISBN fails the checksum validation, THEN THE Book_Store_System SHALL reject the save, persist nothing, retain the entered values, and present an error indication on the ISBN field (F14).
5. IF an ISBN scanned or entered at POS fails the checksum validation, THEN THE Book_Store_System SHALL reject the lookup and present a validation error rather than adding a cart line (F13, F15).
6. IF a scanned ISBN is valid but matches no existing tenant-scoped product, THEN THE Book_Store_System SHALL prompt the operator to create the book first and SHALL NOT add a placeholder cart line priced at ₹0 (F15).

### Requirement 9: Phase 6 — Publisher Returns and Real Loyalty

**User Story:** As a book-store operator, I want a working publisher-returns screen and a real loyalty points balance, so that I can record returns to publishers and reward customers with accurate, redeemable points.

#### Acceptance Criteria

1. WHEN the Publisher Returns tab is opened, THE Book_Store_System SHALL present a functional returns UI backed by Book_Repository and SHALL NOT present a "future update" placeholder (F16).
2. WHEN a publisher return is submitted, THE Book_Store_System SHALL persist it via the deployed `POST /book-store/returns` endpoint with a tenant-scoped, RID-patterned identifier and money in integer Paise (F16).
3. WHEN the Publisher Returns list is opened, THE Book_Store_System SHALL load existing returns via the deployed `GET /book-store/returns` endpoint scoped to the active Tenant_Id (F16).
4. WHEN a customer's loyalty balance is displayed, THE Book_Store_System SHALL derive it from an actual loyalty points balance and SHALL NOT use `customer.totalPaid` as a proxy (F17).
5. WHEN a sale that accrues loyalty points is completed, THE Book_Store_System SHALL increase the customer's loyalty balance according to the confirmed accrual rule (F17).
6. WHEN loyalty points are redeemed against a bill, THE Book_Store_System SHALL decrease the customer's loyalty balance by the redeemed amount and apply the redemption to the bill total in integer Paise (F17).
7. IF a loyalty redemption exceeds the customer's available balance, THEN THE Book_Store_System SHALL reject the redemption, apply nothing to the bill, and present a validation error.
8. IF persisting a loyalty balance requires a change to the Customer data shape, THEN THE Book_Store_System SHALL request a Schema_Gate before persisting (F17).

### Requirement 10: Phase 7 — Offline-First Migration

**User Story:** As a book-store operator working with intermittent connectivity, I want school orders, consignments, and publisher returns to work offline through the sync queue, so that the app stays usable without a connection and does not double-apply updates on reconnect.

#### Acceptance Criteria

1. THE Book_Store_System SHALL migrate Book_Repository off direct `apiClient.get/post` calls onto the Sync_Queue offline-first pattern used by the bills and products repositories (F25).
2. WHILE the device is offline, THE Book_Store_System SHALL queue school-order, consignment, and publisher-return writes locally and SHALL surface a pending state rather than a "Failed to load" error (F25, F26).
3. WHEN connectivity is restored after an offline period, THE Book_Store_System SHALL flush queued writes such that each record, identified by its RID, has exactly one stored version and no duplicate is produced (F25, F26).
4. WHEN the same queued change identified by its RID is applied more than once, THE Book_Store_System SHALL produce the same persisted result as a single application (F25, F26).
5. THE Book_Store_System SHALL define the offline behavior of publisher returns explicitly, specifying queueing, conflict handling, and reconciliation consistent with school orders and consignments (F26).
6. WHERE the Book_Store_System persists data locally, THE Book_Store_System SHALL store currency fields as integer Paise and identifiers in the RID pattern, and SHALL scope every cached record by the active Tenant_Id.
7. IF a queued sync operation fails for a record, THEN THE Book_Store_System SHALL retain that record's pending local change, leave successfully synced records unaffected, and retry the failed record on the next connectivity-restored event without discarding it.

### Requirement 11: Phase 8 — In-Widget RBAC Guards

**User Story:** As a security owner, I want money and create actions in book-store screens guarded by in-widget permission checks, so that writes are gated even when a screen is reached through a path that carries no route guard.

#### Acceptance Criteria

1. WHEN `BookPosScreen` invoice generation is invoked, THE Book_Store_System SHALL verify the acting user holds the required permission before persisting the invoice (F27).
2. WHEN `BookInventoryScreen` add or create is invoked, THE Book_Store_System SHALL verify the acting user holds the required permission before persisting the product (F27).
3. WHEN a consignment settlement or a school-order fulfillment write is invoked, THE Book_Store_System SHALL verify the acting user holds the required permission before persisting the money movement (F28).
4. IF the acting user lacks the required permission for an invoice, product, settlement, or fulfillment write, THEN THE Book_Store_System SHALL block the write, persist nothing, and present an access-denied indication (F27, F28).
5. WHERE a screen is reached through Content_Host, which applies no route guard, THE Book_Store_System SHALL still enforce the in-widget permission check so the write is gated independent of the entry path (F27, F28).
6. WHEN Phase 8 sign-off is recorded, THE Book_Store_System SHALL remove the Dev_Flag gating from the bookStore navigation so the sidebar and wiring become live.

### Requirement 12: Phase 9 — Capability Gating and Medium/Low Polish

**User Story:** As a book-store operator, I want school-order and consignment features gateable, the POS layout and lists robust, and irrelevant retail sections hidden, so that the vertical is complete, performant, and uncluttered — while backlog features are not built without confirmation.

#### Acceptance Criteria

1. THE Book_Store_System SHALL add a `BusinessCapability` entry for school/institution orders (and for consignment where none exists) so the features are gateable through `FeatureResolver` (F20).
2. WHEN `BookPosScreen` renders on a narrow window, THE Book_Store_System SHALL lay out its columns without horizontal overflow, adjusting the maximum width or providing a responsive/stacked layout for the three-pane POS (F30).
3. WHEN Book_Repository loads consignments or school orders, THE Book_Store_System SHALL request results in pages rather than loading the full list in a single unpaginated call (F32).
4. WHERE an async handler in `SchoolOrderScreen` or `ConsignmentSettlementScreen` uses `BuildContext` after an `await` in a failure branch, THE Book_Store_System SHALL guard the usage with a `mounted` check (F33).
5. WHEN the bookStore sidebar renders, THE Book_Store_System SHALL omit clearly retail-only sections that are irrelevant to a book store (F34).
6. THE Book_Store_System SHALL improve accessibility on touched book-store surfaces by addressing low-contrast text and adding tooltips or `Semantics` labels to icon-only buttons, noting that full WCAG validation requires manual assistive-technology testing (F35).
7. WHILE the backlog features Used Books (F21), Set/bundle class-set composition (F22), Stationery category with mixed GST (F23), and book detail/edit plus publisher/school master UI (F31) are unconfirmed, THE Book_Store_System SHALL flag each as backlog and SHALL NOT build it without explicit confirmation.

### Requirement 13: Phase 10 — Final Regression and Traceability

**User Story:** As a maintainer, I want a final verification pass and a traceability matrix, so that I can confirm every finding is resolved, deferred, or not reproduced, that the dev flag is removed, and that no other vertical regressed.

#### Acceptance Criteria

1. WHEN Phase 10 executes, THE Book_Store_System SHALL run a repository-wide search for `TODO`, `FIXME`, `mock`, and `stub` markers within `lib/features/book_store/**` and `lib/modules/book_store/**` and SHALL record each remaining occurrence with file path and line number in the final Phase_Report.
2. WHEN Phase 10 executes, THE Book_Store_System SHALL run the full analyze step and the book-store test suite and SHALL record the total, passed, and failed counts for each.
3. IF the recorded analyze error count or test fail count is greater than zero, THEN THE Book_Store_System SHALL record a Fail status in the final Phase_Report and SHALL enumerate each failure.
4. THE Book_Store_System SHALL produce a Traceability_Matrix that maps every Finding_Id F1 through F35 to exactly one of Resolved, Partially-Resolved, Not-Reproduced, Deferred, or Out-of-Scope, with no finding left unmapped and no finding assigned more than one status.
5. WHERE a Finding_Id is mapped to Resolved or Partially-Resolved, THE Traceability_Matrix SHALL cite the evidence (test output, search output, or changed location) supporting that status.
6. WHEN Phase 10 executes, THE Book_Store_System SHALL confirm the Dev_Flag has been removed and the bookStore navigation is live, recording a pass or fail result.
7. WHEN Phase 10 executes, THE Book_Store_System SHALL record a pass or fail result for at least three other business verticals, where pass means the sidebar, dashboard, quick actions, and alerts widget for that vertical resolve unchanged behavior.
8. IF any business type other than `bookStore` shows changed behavior in its sidebar, dashboard, quick actions, or alerts widget, THEN THE Book_Store_System SHALL record a fail result identifying the affected surface and business type.
9. THE Book_Store_System SHALL list every pending human decision, including any deferred tax-policy detail, backlog build decision, pending Schema_Gate, or pending Delete_Gate, in the final Phase_Report, recording for each the decision required and its current status.

### Requirement 14: Phase Ordering and Stop Gates

**User Story:** As a maintainer, I want the phases executed in strict order with human stop gates and written reports, so that I retain control over every step of the remediation.

#### Acceptance Criteria

1. THE Book_Store_System SHALL execute the phases in strict ascending order beginning with Phase 0 and ending with Phase 10, and SHALL NOT begin Phase N+1 until Phase N has received an approval reply consisting of exactly the case-sensitive literal `APPROVED`.
2. WHEN a phase completes, THE Book_Store_System SHALL produce a Phase_Report that contains all of the following, with no item left blank: (a) every file created, modified, or deleted, each identified by its full path; (b) the specific change made to each listed file; (c) each verification step executed together with its pass or fail result; (d) the Finding_Ids closed by the phase; (e) any items that could not be statically verified; and (f) any decisions needed before the next phase.
3. WHEN a phase completes and its Phase_Report has been produced, THE Book_Store_System SHALL emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL`, with `N` replaced by the completed phase number, and SHALL halt all further phase execution until an approval reply is received.
4. IF an approval reply requests changes, THEN THE Book_Store_System SHALL apply the requested changes, re-emit the Stop_Gate text for that same phase, and SHALL NOT advance to the next phase.
5. IF an approval reply is neither the exact literal `APPROVED` nor an actionable change request, THEN THE Book_Store_System SHALL NOT advance to the next phase, SHALL preserve the current phase state unchanged, and SHALL emit an indication that clarification is required.
6. IF a required business decision (tax policy or a build-versus-defer backlog decision) is unconfirmed, THEN THE Book_Store_System SHALL halt at the dependent phase and SHALL request confirmation rather than guessing.
7. WHERE a change can be applied as a line-level surgical diff to existing code, THE Book_Store_System SHALL apply the surgical diff rather than rewriting the surrounding code block.
