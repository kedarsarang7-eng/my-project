# Requirements Document

## Introduction

The DukanX `decorationCatering` business vertical is fully built at the screen, model, and repository layers but is unreachable in normal use: it has no sidebar configuration case, missing barrel exports, unwired navigation ids, route-less screens, a self-redirect loop, and a post-login dashboard that does not route to the decoration/catering dashboard. Beyond reachability, an audit identified business-logic defects (split discount/tax models, an "advance defaults to 100%" default, rental price hardcoded to zero, ledger not updated on quote conversion), validation gaps, capability/isolation mismatches, and dead code.

This document specifies a phased, evidence-based remediation that makes the vertical shippable end-to-end. Work proceeds strictly in phase order (Phase 0 through Phase 8). Phase 0 is read-only verification; each subsequent phase ends with an explicit approval gate before the next begins. All work is bound by a set of non-negotiable cross-cutting constraints (multi-tenant scoping, integer-paise money, RID id pattern, idempotent migrations, no deletions or schema changes without sign-off, real fixes only).

The vertical is referred to throughout as the **DC_System**, with sub-systems named for clarity. Requirements are written against these named systems and map to the phase that delivers them.

## Glossary

- **DC_System**: The decoration & catering business vertical of the DukanX Flutter app, encompassing its screens, repository, providers, routes, and sidebar configuration. Identified by `BusinessType.decorationCatering`.
- **DC_Repository**: `lib/features/decoration_catering/data/repositories/dc_repository.dart` — the data-access layer that calls the backend `/dc/*` endpoints and maps JSON to/from DC models.
- **DC_Barrel**: `lib/features/decoration_catering/decoration_catering.dart` — the barrel file that re-exports DC models, repository, screens, services, and widgets.
- **Sidebar_Configuration**: `lib/widgets/desktop/sidebar_configuration.dart` — defines `SidebarSection`/`SidebarMenuItem` lists per business type via `_getSectionsForBusiness`.
- **Sidebar_Navigation_Handler**: `lib/widgets/desktop/sidebar_navigation_handler.dart` — resolves a sidebar item id to a screen widget via `getScreenForItem`.
- **App_Router**: `lib/app/routes.dart` — the legacy route registration table for screen routes.
- **DC_Routes**: `decoration_catering_routes.dart` — the DC route definitions, including the redirect logic currently containing a self-redirect loop.
- **DC_Module**: `decoration_catering_module.dart` — a go_router-based module suspected to be dead code (not referenced by the live navigation path).
- **Quick_Actions**: `lib/features/dashboard/v2/widgets/business_quick_actions.dart` (and related) — the dashboard quick-action buttons resolved per `BusinessType`.
- **Alerts_Widget**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` — the dashboard alert-count widget resolved per `BusinessType`.
- **DC_Dashboard**: `DcDashboardScreen` plus `dcStatsProvider` — the decoration/catering dashboard surface.
- **Verification_Report**: A read-only Markdown artifact produced in Phase 0 documenting endpoint/handler reality, dead-code confirmation, and formula verification, containing zero code changes.
- **Vendor_Role_Guard**: `VendorRoleGuard` — the existing route wrapper enforcing vendor role access.
- **Business_Guard**: `BusinessGuard` — the existing route wrapper restricting a route to specified `allowedTypes`.
- **Business_Capability**: `BusinessCapability` enum and `FeatureResolver.canAccess` — the capability gate applied to `SidebarMenuItem`s before RBAC.
- **EventBooking**: The DC booking model representing a catering/decoration event, including its money fields and (to be added) `eventEndDate`.
- **Tenant_Id**: The authenticated business identity (`SessionManager.currentBusinessId` = `activeBusinessId ?? userId`) used to scope all queries, writes, and cache keys. The literal `vendorId: 'SYSTEM'` is prohibited.
- **Paise**: Integer representation of currency (1 rupee = 100 paise). All money values in touched DC code are integer paise.
- **RID**: The new-entity identifier pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
- **DC_Sync_Handler**: `DecorationCateringSyncHandler` — the currently dormant offline sync handler for DC entities.
- **DC_Ws_Handler**: `DecorationCateringWsHandler` — the currently dormant websocket handler for DC entities.
- **Approval_Gate**: A point at which the DC_System work for a phase stops and waits for explicit human approval before continuing. Emitted as the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and resumed only on the literal reply `APPROVED`.
- **Mini_Approval_Gate**: A separate, explicit sign-off required specifically before any DynamoDB schema change.

## Requirements

### Requirement 1: Cross-Cutting Non-Negotiable Constraints

**User Story:** As the platform owner, I want every change in this remediation to honor the platform's multi-tenant, money, identity, and safety invariants, so that the DC_System ships without introducing data leakage, currency errors, or destructive side effects.

#### Acceptance Criteria

1. WHERE any phase reads, writes, or caches DC data, THE DC_System SHALL scope every query, write, and cache key by Tenant_Id resolved from `SessionManager.currentBusinessId`.
2. THE DC_System SHALL NOT use the literal identity `vendorId: 'SYSTEM'` for any DC query, write, or cache key.
3. WHERE money values are represented in code touched by this remediation, THE DC_System SHALL store and compute currency as integer Paise.
4. THE DC_System SHALL NOT introduce `double` or floating-point types for currency values in code touched by this remediation.
5. WHEN the DC_System creates a new entity identifier, THE DC_System SHALL generate it using the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
6. IF a change requires a DynamoDB schema change, THEN THE DC_System SHALL halt and request a Mini_Approval_Gate before applying the change.
7. IF a change requires deleting a file, screen, route, or data, THEN THE DC_System SHALL halt and request explicit sign-off before performing the deletion.
8. WHERE the DC_System applies a data migration, THE DC_System SHALL make the migration idempotent such that repeated executions produce the same persisted result and modify zero records after the first execution.
9. THE DC_System SHALL implement real fixes without TODO placeholders or workarounds in code introduced by this remediation.
10. WHERE the DC_System catches an exception in code introduced by this remediation, THE DC_System SHALL handle it with an observable response or propagate it, and SHALL NOT silently discard it.
11. WHERE the DC_System adds or modifies code, THE DC_System SHALL match existing codebase patterns for localization (l10n), responsive helpers, and error handling.
12. WHEN a phase of this remediation is completed, THE DC_System SHALL emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and SHALL perform no further phase work until the literal reply `APPROVED` is received.
13. IF Tenant_Id cannot be resolved from `SessionManager.currentBusinessId` because it is null or empty, THEN THE DC_System SHALL abort the operation, access no DC data, and return a tenant-context-unavailable error.

### Requirement 2: Phase 0 — Read-Only Backend Reality Check

**User Story:** As a maintainer, I want a verified, evidence-based report of the DC_System backend and dead-code reality before any code changes, so that subsequent phases act on confirmed facts rather than assumptions.

#### Acceptance Criteria

1. WHILE executing Phase 0, THE DC_System SHALL create, modify, and delete zero files other than the single Verification_Report artifact.
2. THE Verification_Report SHALL classify each of the 17 `/dc/*` endpoints (events CRUD, staff, staff/attendance, vendors, inventory, menu, packages, themes, expenses, invoices, quotes, payments, dashboard, profitability, shopping-list) as exactly one of: non-stub handler deployed, stub handler deployed, or no handler deployed; where a stub handler is a deployed handler that returns hardcoded or placeholder data or an unimplemented-response indicator.
3. WHERE the Verification_Report references an audit finding, THE Verification_Report SHALL include the file path and the start and end line numbers confirming the current behavior.
4. THE Verification_Report SHALL state whether `decoration_catering_module.dart` (go_router DC_Module) is dead code, including the file path and the start and end line numbers of supporting evidence.
5. THE Verification_Report SHALL record the `getEventProfitability` formula with its file path and line numbers and either confirm its correctness or flag profitability as unverified.
6. IF a `/dc/*` endpoint has no deployed non-stub handler, THEN THE Verification_Report SHALL flag that endpoint as a backend gap.
7. IF an item cannot be classified from available evidence, THEN THE Verification_Report SHALL flag the item as unverified with a stated reason.

### Requirement 3: Phase 1 — Sidebar Reachability

**User Story:** As a decoration/catering vendor, I want a dedicated sidebar for my business, so that I can reach every DC feature from normal navigation.

#### Acceptance Criteria

1. WHEN `_getSectionsForBusiness` is called with `BusinessType.decorationCatering`, THE Sidebar_Configuration SHALL return the section list produced by a new `_getDecorationCateringSections()` function via an explicit `case BusinessType.decorationCatering`, and SHALL NOT fall through to `_getRetailSections()` or any other business type's section function.
2. WHEN `_getSectionsForBusiness` is called with `BusinessType.decorationCatering`, THE Sidebar_Configuration SHALL return exactly the following 14 sections with no additional and no missing entries: Dashboard, Bookings, Calendar, Quotes, Catering/Menu, Decoration/Themes, Staff, Attendance, Vendors & Payments, Inventory/Rentals, Shopping List, Billing, Profitability, and Reports.
3. WHEN `_getSectionsForBusiness` is called with `BusinessType.decorationCatering`, THE Sidebar_Configuration SHALL return each of the 14 sections with a non-empty label and a navigation target that is reachable from the sidebar.
4. WHILE `_getSectionsForBusiness` is called with any `BusinessType` other than `decorationCatering`, THE Sidebar_Configuration SHALL return sections identical to those returned prior to the `case BusinessType.decorationCatering` addition.

### Requirement 4: Phase 1 — Barrel Exports and Navigation Wiring

**User Story:** As a developer, I want every DC screen exported and resolvable, so that no sidebar selection falls through to a placeholder.

#### Acceptance Criteria

1. THE DC_Barrel SHALL export `dc_event_detail_screen`, `dc_quote_conversion_screen`, `dc_staff_attendance_screen`, and `dc_vendor_rating_dialog`, such that each exported symbol resolves to a defined widget at compile time with zero unresolved-import or missing-symbol analyzer errors.
2. WHEN `getScreenForItem` is called with any one of the DC sidebar item ids enumerated in Requirement 3, THE Sidebar_Navigation_Handler SHALL return the single DC screen widget mapped to that id.
3. IF `getScreenForItem` is called with a DC sidebar item id enumerated in Requirement 3, THEN THE Sidebar_Navigation_Handler SHALL NOT return the `_PlaceholderScreen` fallthrough.
4. IF `getScreenForItem` is called with an id that is not enumerated in Requirement 3, THEN THE Sidebar_Navigation_Handler SHALL return the `_PlaceholderScreen` fallthrough without throwing an exception.

### Requirement 5: Phase 1 — Legacy Route Registration and Guards

**User Story:** As a decoration/catering vendor, I want all DC screens registered as guarded routes, so that deep links and in-app navigation resolve correctly and securely.

#### Acceptance Criteria

1. THE App_Router SHALL register exactly the following eight routes, each resolving to its corresponding DC screen: `dc_calendar`, `dc_quotes`, `dc_profitability`, `dc_shopping_list`, `dc_vendor_payments`, `dc_event_detail`, `dc_quote_conversion`, and `dc_staff_attendance`.
2. WHERE the App_Router registers a DC route from this set, THE App_Router SHALL wrap each individual route in both Vendor_Role_Guard and Business_Guard with `allowedTypes: [decorationCatering]`.
3. WHEN a user whose business type is `decorationCatering` and who holds the vendor role navigates to a DC route via in-app navigation or a deep link, THE DC_System SHALL resolve the route to its target screen.
4. WHEN a user navigates to the `/dc/vendors` target, THE DC_System SHALL resolve to `DcVendorPaymentsScreen` and SHALL NOT resolve to `DcStaffScreen`.
5. IF a user whose business type is not `decorationCatering` or who lacks the vendor role navigates to a DC route, THEN THE DC_System SHALL block access, redirect to a fallback, and retain no DC screen state.
6. WHEN the DC_Routes redirect logic resolves a DC route, THE DC_System SHALL resolve it in a single pass with no further redirect, eliminating the self-redirect loop.

### Requirement 6: Phase 1 — Post-Login Dashboard Routing and End-to-End Reachability

**User Story:** As a decoration/catering vendor, I want to land on my DC dashboard after login and reach all DC screens, so that the vertical is usable end-to-end.

#### Acceptance Criteria

1. WHEN a tenant whose business type is `decorationCatering` completes login, THE DC_System SHALL render `DcDashboardScreen` as the post-login landing screen within 3 seconds of authentication success.
2. THE DC_System SHALL make all 16 DC screens reachable from `DcDashboardScreen` through the DC navigation sidebar within a maximum of 2 navigation actions per screen, where "reachable" means the target screen renders its primary content without navigation error or crash.
3. IF a tenant whose business type is `decorationCatering` completes login but the resolved post-login route is not `DcDashboardScreen`, THEN THE DC_System SHALL route the tenant to `DcDashboardScreen` as the fallback landing screen.
4. IF navigation to any of the 16 DC screens fails to render its primary content, THEN THE DC_System SHALL retain the tenant on the current screen and display an error message indicating the target screen could not be loaded.

### Requirement 7: Phase 2 — Capability and Isolation Reconciliation

**User Story:** As a security owner, I want the DC_System's capabilities and route guards reconciled with the features it actually uses, so that access is neither broken nor over-permissive.

#### Acceptance Criteria

1. WHEN a reconciliation path has been recorded as signed off by the security owner, THE DC_System SHALL adopt exactly one of two mutually exclusive paths: Path A, which grants the DC_System the capabilities it uses (inventory-for-rentals and billing); or Path B, which keeps the DC_System capability-restricted.
2. WHERE Path A is the signed-off path, THE DC_System SHALL remove the "service-only" comment from the capability configuration.
3. WHERE Path B is the signed-off path, THE DC_System SHALL apply a capability guard to each of the retail-only `SidebarMenuItem`s BuyFlow, Stock, and Purchase such that these items are not reachable by the DC_System.
4. IF neither Path A nor Path B has a recorded sign-off when reconciliation is invoked, THEN THE DC_System SHALL make no change to the capability configuration and SHALL surface an indication that sign-off is required before proceeding.
5. WHEN capability reconciliation runs, THE DC_System SHALL report the total count of `SidebarMenuItem`s that both lack a `capability:` field and fall outside DC scope, where the count is an integer of 0 or greater.
6. WHERE a route is determined to be outside DC scope, THE DC_System SHALL attach Business_Guard to that route such that DC_System access to the route is denied.

### Requirement 8: Phase 3 — Dashboard Quick Actions and Alerts

**User Story:** As a decoration/catering vendor, I want quick actions and real alert counts on my dashboard, so that I can act on live business state.

#### Acceptance Criteria

1. WHEN Quick_Actions resolves actions for `BusinessType.decorationCatering`, THE DC_System SHALL provide exactly four actions—New Booking, New Quote, Add Staff, and Menu/Package—each rendered as a distinct activatable control that navigates to its corresponding screen when activated.
2. WHEN Alerts_Widget resolves alerts for `BusinessType.decorationCatering`, THE DC_System SHALL display three integer counts sourced from DC_Repository: count of events scheduled within the next 7 days (from the current date inclusive through 7 calendar days ahead), count of bookings with advance payment pending, and count of rentals due back on or before the current date.
3. WHILE a resolved alert count from DC_Repository equals zero, THE DC_System SHALL display the numeric value 0 for that alert rather than omitting the alert or substituting a placeholder.
4. THE Alerts_Widget SHALL derive every displayed count from DC_Repository query results and SHALL NOT display any hardcoded or literal numeric count for the DC_System.
5. IF DC_Repository fails to return alert counts when Alerts_Widget requests them, THEN THE DC_System SHALL display an error indication for the affected alert in place of a count and SHALL NOT display a stale or default numeric value.
6. WHEN DC_Dashboard is opened, THE DC_System SHALL render `DcDashboardScreen` populated with data obtained from `dcStatsProvider`, such that every displayed statistic traces to a `dcStatsProvider` value.

### Requirement 9: Phase 4 — Rental Lifecycle Correctness

**User Story:** As a decoration/catering vendor, I want rental inventory pricing and lifecycle state tracked accurately, so that rentals reflect real prices, returns, and damage.

#### Acceptance Criteria

1. WHEN `_inventoryFromJson` maps an inventory record in DC_Repository, THE DC_Repository SHALL populate `rentalPrice` from the API field rather than a hardcoded value of 0.
2. IF the `rentalPrice` API field is missing or null when `_inventoryFromJson` maps a record, THEN THE DC_Repository SHALL default `rentalPrice` to 0, retain all other mapped fields, and surface a non-blocking indication that `rentalPrice` was unavailable.
3. WHERE an inventory item is associated with an event, THE DC_System SHALL track its per-event lifecycle state as exactly one of: available, rented-out, returned, or returned-with-damage.
4. WHEN an inventory item is rented out for an event, THE DC_System SHALL record a rented quantity between 1 and the available on-hand quantity inclusive.
5. WHEN a rented item is returned, THE DC_System SHALL record a damaged-or-lost quantity between 0 and the rented quantity inclusive against the associated event.
6. IF a rent-out or return quantity outside its allowed bounds is entered, THEN THE DC_System SHALL reject the entry and retain the previous state.
7. WHEN inventory quantity is adjusted, THE DC_System SHALL apply the change via an atomic delta call rather than a read-all-then-PUT operation.
8. IF an atomic delta adjustment call fails, THEN THE DC_System SHALL leave the stored quantity unchanged and surface an error.
9. IF the backend does not support an atomic delta adjustment, THEN THE DC_System SHALL document the backend gap.

### Requirement 10: Phase 5 — Discount/Tax Model Unification

**User Story:** As a decoration/catering vendor, I want one consistent discount and tax model across quotes and billing, so that totals match regardless of which screen produced them.

#### Acceptance Criteria

1. THE DC_System SHALL apply a single percentage-based discount and tax model across both `computeQuoteTotal` and `dc_billing_screen.dart`, where the discount percentage is a value from 0 to 100 inclusive with at most 2 decimal places.
2. WHERE `computeQuoteTotal` currently uses an absolute discount model, THE DC_System SHALL convert the stored absolute discount amount to the equivalent percentage of the pre-discount subtotal (rounded to 2 decimal places) and persist it in the percentage model.
3. WHEN computing GST, THE DC_System SHALL apply the percentage tax model to the post-discount subtotal using the same GST rate and rounding rules in both `computeQuoteTotal` and `dc_billing_screen.dart`.
4. WHEN the same line items, discount percentage, and GST rate are supplied, THE DC_System SHALL produce a grand total from `computeQuoteTotal` that equals the grand total from `dc_billing_screen.dart` to the nearest paise (zero variance).
5. IF a discount percentage outside the range 0 to 100 inclusive is supplied, THEN THE DC_System SHALL reject the input, retain the previous valid discount value, and return an error indication identifying the out-of-range discount.

### Requirement 11: Phase 5 — Advance and Ledger Correctness

**User Story:** As a decoration/catering vendor, I want sane advance defaults and an accurate ledger on conversion, so that booking finances reflect reality.

#### Acceptance Criteria

1. THE DC_System SHALL replace the "advance defaults to 100% of total" behavior with a configurable advance percentage whose default value is 50% and whose accepted configured range is 30% to 50% inclusive.
2. WHEN an advance percentage is configured outside the 30% to 50% inclusive range, THE DC_System SHALL reject the configuration value, retain the previously stored advance percentage, and present an error indicating the accepted range.
3. WHEN a quote is converted to a booking, THE DC_System SHALL compute the advance amount from the configured advance percentage applied to the total and round the result to the nearest whole paise.
4. WHEN a quote is converted to a booking, THE DC_System SHALL validate that the advance amount is greater than or equal to 0 paise and less than or equal to the total.
5. IF the advance amount is less than 0 paise or exceeds the total at conversion, THEN THE DC_System SHALL reject the conversion, create no booking, retain the source quote in its pre-conversion state, and present an error indicating the advance amount is outside the allowed bounds.
6. WHEN a quote is converted to a booking, THE DC_System SHALL call `recordPayment` against the payments endpoint so that the ledger reflects the advance, rather than only setting `advancePaid` on the booking.
7. IF the `recordPayment` call fails during conversion, THEN THE DC_System SHALL reject the conversion, create no booking, leave the ledger unchanged, and present an error indicating the advance payment could not be recorded.

### Requirement 12: Phase 6 — Data Validation and Robustness

**User Story:** As a decoration/catering vendor, I want inputs validated and JSON parsing hardened, so that invalid data and malformed responses do not corrupt records or crash screens.

#### Acceptance Criteria

1. WHEN a discount percentage is entered, THE DC_System SHALL clamp the value to the range 0 to 100 inclusive.
2. WHEN a GST percentage is entered, THE DC_System SHALL bound the value to the range 0 to 28 inclusive.
3. IF a line-item quantity less than or equal to 0, empty, or non-numeric is entered, THEN THE DC_System SHALL reject the entry, retain the previous valid value, and present an error indication.
4. IF a line-item rate less than 0, empty, or non-numeric is entered, THEN THE DC_System SHALL reject the entry, retain the previous valid value, and present an error indication.
5. WHILE no event is selected, THE DC_System SHALL keep the "Generate Invoice" action disabled.
6. THE DC_System SHALL add `eventEndDate` to EventBooking and propagate it through the booking form, calendar, and profitability for multi-day events.
7. WHEN `_bookingFromJson` parses a booking record, THE DC_Repository SHALL apply null-safe parsing with defined defaults.
8. WHEN `_expenseFromJson` and `_vendorPaymentFromJson` map records, THE DC_Repository SHALL read the stored payment method rather than hardcoding `PaymentMethod.cash`.
9. IF a booking record is malformed when `_bookingFromJson` parses it, THEN THE DC_Repository SHALL skip the malformed record, preserve all valid records, surface an error indication, and not crash the screen.
10. IF the stored payment method is missing or unrecognized when `_expenseFromJson` or `_vendorPaymentFromJson` maps a record, THEN THE DC_Repository SHALL apply a defined default payment method and surface a non-blocking indication.
11. IF `eventEndDate` is earlier than the event start date, THEN THE DC_System SHALL reject the value and present an error indication.

### Requirement 13: Phase 7 (Optional) — Offline-First and Sync

**User Story:** As a decoration/catering vendor, I want DC data to work offline and sync like the retail vertical, so that I can operate without continuous connectivity.

#### Acceptance Criteria

1. BEFORE implementing Phase 7, THE DC_System SHALL obtain documented sign-off that explicitly lists the in-scope DC entities (events/bookings, staff, vendors, inventory, quotes, payments) and excludes all entities not named, and SHALL NOT create or modify any Phase 7 artifact until that sign-off is recorded.
2. WHERE Phase 7 is approved, THE DC_System SHALL add local Drift tables for each of the following DC entities: events/bookings, staff, vendors, inventory, quotes, and payments, where each table includes the same sync-tracking columns used by the retail vertical tables (last-modified timestamp, sync status, and soft-delete flag).
3. WHERE Phase 7 is approved, THE DC_System SHALL wire DC_Sync_Handler and DC_Ws_Handler to read from and write to the new local Drift tables defined in criterion 2, such that no DC sync operation references a table absent from that set.
4. WHERE Phase 7 is approved, WHEN a user creates, updates, or deletes a DC record while offline or online, THE DC_System SHALL persist the change to the local Drift table immediately and enqueue a corresponding sync-queue entry, using the same optimistic-write and queue-ordering behavior as the retail vertical.
5. WHERE Phase 7 is approved, WHEN connectivity is available, THE DC_System SHALL process queued sync entries in first-in-first-out order until the queue is empty.
6. WHERE Phase 7 is approved, IF a queued sync entry fails to transmit, THEN THE DC_System SHALL retain the entry in the sync queue, preserve the local record unchanged, retry the entry up to 5 times, and after the final failed attempt mark the entry with a failed-sync indication observable to the user without discarding the local change.

### Requirement 14: Phase 8 — Polish and Dead-Code Disposition

**User Story:** As a maintainer, I want accessibility polish and explicit disposition of dead code, so that the vertical is clean, accessible, and free of ambiguous leftovers.

#### Acceptance Criteria

1. WHERE a DC button is icon-only, THE DC_System SHALL render a non-empty tooltip containing text that describes the button's action.
2. WHERE a DC button is icon-only, THE DC_System SHALL expose a non-empty semantic label, readable by assistive technologies, that describes the button's action.
3. WHERE a DC status badge uses a font size below 10px, THE DC_System SHALL set the badge font size to a value between 10px and 11px inclusive.
4. WHERE a documented sign-off decision for `advanceForfeitedOnCancel` is recorded as "wire", THE DC_System SHALL invoke `advanceForfeitedOnCancel` within the cancellation flow.
5. WHERE a documented sign-off decision for `advanceForfeitedOnCancel` is recorded as "remove", THE DC_System SHALL remove `advanceForfeitedOnCancel` from the codebase.
6. IF `decoration_catering_module.dart` (DC_Module) is confirmed dead, THEN THE DC_System SHALL either delete it or retain it with a code comment documenting the migration rationale, according to the recorded sign-off decision.
7. IF the disposition in criterion 4, 5, or 6 requires deleting code, THEN THE DC_System SHALL obtain an explicit recorded sign-off before performing the deletion, and SHALL leave the code unchanged until that sign-off is recorded.
