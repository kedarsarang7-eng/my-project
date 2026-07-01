# Requirements Document

## Introduction

The DukanX `jewellery` business vertical (`BusinessType.jewellery`) is a substantial, well-structured feature module — 8 screens, 5 model groups, 6 repositories, a making-charges calculator, a business-rules utility, and a registered go_router module — but almost none of it is reachable in the running desktop app. A jewellery vendor is served the generic retail sidebar (no `case BusinessType.jewellery` in `_getSectionsForBusiness`), the live `MaterialApp routes:` table registers zero jewellery routes, `SidebarNavigationHandler.getScreenForItem` has no jewellery cases, and `jewellery_integration.dart` is dead code that even shadows `go_router` types. Beyond reachability, an evidence-based audit (`audit-reports/business-types/audit-jewellery.md`) identified money-correctness defects (per-10g vs per-gram rate mismatch, two divergent pricing engines, qty-vs-weight bill totals, GST simplification, wastage double-counting, placeholder stone charge), missing jewellery-domain capabilities and route guards, dead dashboard quick actions, hardcoded alert counts, an online-only custom-orders repository, validation and crash gaps, PMLA KYC PII handling gaps, mojibake in user-facing strings, and accessibility gaps.

This document specifies a phased, evidence-based remediation that makes the vertical shippable end-to-end. Work proceeds strictly in phase order (Phase 0 through Phase 8). Phase 0 is read-only verification that resolves every unverified audit item to CONFIRMED or FALSIFIED. Each subsequent phase ends with an explicit STOP GATE that requires human sign-off before the next begins. All work is bound by a set of non-negotiable cross-cutting constraints (multi-tenant scoping, integer-paise money, RID id pattern, idempotent migrations, no deletions or schema changes without sign-off, no changes to other business types).

The vertical is referred to throughout as the **Jewellery_System**, with sub-systems named for clarity. Requirements are grouped by the phase that delivers them and map back to the audit findings they remediate.

## Glossary

- **Jewellery_System**: The jewellery business vertical of the DukanX Flutter app, encompassing its screens, repositories, models, services, providers, routes, capabilities, dashboard widgets, and sidebar configuration. Identified by `BusinessType.jewellery`.
- **Sidebar_Configuration**: `lib/widgets/desktop/sidebar_configuration.dart` — defines `SidebarSection`/`SidebarMenuItem` lists per business type via `_getSectionsForBusiness`.
- **Sidebar_Navigation_Handler**: `lib/widgets/desktop/sidebar_navigation_handler.dart` — resolves a sidebar item id to a screen widget via `getScreenForItem`; unknown ids fall to `_buildPlaceholderScreen('Unknown Screen')`.
- **App_Router**: `lib/app/routes.dart` `buildAppRoutes()` — the legacy `MaterialApp routes:` registration table that is the single source of truth for live named routes, including the "CUSTOM BUSINESS MODULES" section.
- **Jewellery_Integration**: `lib/features/jewellery/jewellery_integration.dart` — dead-code integration object (`JewelleryIntegration`) that declares local fake `RouteBase`/`GoRoute` shadow classes and is referenced by nothing outside itself.
- **Jewellery_Business_Rules**: `lib/features/jewellery/utils/jewellery_business_rules.dart` — the purity-aware `billTotal`/`exchangeCredit` engine, the designated canonical pricing engine.
- **Making_Charges_Calculator**: `lib/features/jewellery/data/services/making_charges_calculator.dart` — the second pricing engine (`calculateTotalPrice`), to be refactored to call into Jewellery_Business_Rules.
- **Jewellery_Repository_Online**: `lib/features/jewellery/data/repositories/jewellery_repository.dart` — the online-only repository (calls `/jewellery/*` via `ApiClient`, throws when offline).
- **Jewellery_Repository_Offline**: `lib/features/jewellery/data/repositories/jewellery_repository_offline.dart` — the offline-first repository (Hive boxes + sync queue with retry cap 5).
- **Jewellery_Sync_Handler**: `jewellery_sync_handler.dart` — the offline sync handler for jewellery entities.
- **Jewellery_Ws_Handler**: `jewellery_ws_handler.dart` — the websocket handler for jewellery entities.
- **The_Eight_Screens**: The 8 jewellery screens — `GoldRateManagementScreen`, `GoldRateAlertScreen`, `MakingChargesCalculatorScreen`, `HallmarkInventoryScreen`, `OldGoldExchangeScreen`, `CustomOrderManagementScreen`, `JewelleryRepairScreen`, `GoldSchemeScreen`.
- **Quick_Actions**: `lib/features/dashboard/v2/widgets/business_quick_actions.dart` — dashboard quick-action buttons resolved per `BusinessType`.
- **Alerts_Widget**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` — dashboard alert-count widget resolved per `BusinessType`.
- **Bill_Line_Item_Row**: `lib/features/billing/presentation/widgets/bill_line_item_row.dart` — the live billing line-item widget where purity is a read-only text cell.
- **Vendor_Role_Guard**: `VendorRoleGuard` — the existing route wrapper enforcing vendor role access.
- **Business_Guard**: `BusinessGuard` — the existing route wrapper restricting a route to specified `allowedTypes`.
- **Business_Capability**: `BusinessCapability` enum and `FeatureResolver.canAccess` (`lib/core/isolation/business_capability.dart`) — the capability gate applied to `SidebarMenuItem`s before RBAC.
- **Gold_Rate_Card**: The stored gold-rate record holding per-10g paise values (`gold24KPer10gPaisa`, etc.) in Jewellery_Repository_Offline.
- **Purity_Enum**: The `GoldPurity` / `PurityStandard` enums defined in Jewellery_Business_Rules, the canonical typed representation of metal purity (24K/22K/18K/14K).
- **HUID**: The 6-character BIS Hallmark Unique Identification number used as the hallmark register key.
- **PMLA_KYC_PII**: Customer KYC data captured during old-gold exchange under the Prevention of Money Laundering Act — specifically `customerIdNumber` and `customerPhotoUrl`.
- **Verification_Report**: A read-only Markdown artifact produced in Phase 0 documenting endpoint reality, repository behavior, dead-code confirmation, and formula verification, containing zero code changes.
- **Tenant_Id**: The authenticated business identity used to scope all queries, writes, and sync calls. The literal `vendorId: 'SYSTEM'` fallback is prohibited.
- **Paise**: Integer representation of currency (1 rupee = 100 paise). All money values in touched jewellery code are integer paise.
- **RID**: The new-entity identifier pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
- **Stop_Gate**: A point at which Jewellery_System work for a phase stops and waits for explicit human approval before continuing. Emitted as the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and resumed only on the literal reply `APPROVED`.
- **Mini_Gate**: A separate, explicit sign-off required specifically before any Hive box or DynamoDB schema change, accompanied by a proposal and a migration plan.

## Requirements

### Requirement 1: Cross-Cutting Non-Negotiable Constraints

**User Story:** As the platform owner, I want every change in this remediation to honor the platform's multi-tenant, money, identity, and safety invariants, so that the Jewellery_System ships without introducing data leakage, currency errors, or destructive side effects.

#### Acceptance Criteria

1. WHERE money values are represented in code created or modified by this remediation, THE Jewellery_System SHALL store and compute currency as integer Paise.
2. THE Jewellery_System SHALL NOT introduce `double`, `float`, or decimal floating-point types for currency values in code created or modified by this remediation.
3. WHEN the Jewellery_System creates a new entity identifier, THE Jewellery_System SHALL generate it using the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
4. WHERE the Jewellery_System reads, writes, or synchronizes jewellery data, THE Jewellery_System SHALL scope every query, repository call, and sync call by Tenant_Id.
5. THE Jewellery_System SHALL NOT use the literal identity `vendorId: 'SYSTEM'` as a fallback for any jewellery query, write, or sync call.
6. IF a change requires a Hive box or DynamoDB schema change, THEN THE Jewellery_System SHALL halt and request a Mini_Gate, presenting the proposed change and a migration plan, before applying the change.
7. IF a change requires deleting a file, route, screen, or data, THEN THE Jewellery_System SHALL halt and request explicit sign-off before performing the deletion.
8. WHERE the Jewellery_System applies a data migration, THE Jewellery_System SHALL make the migration idempotent such that repeated executions produce the same persisted result and modify zero records after the first execution.
9. WHEN the Jewellery_System modifies a file shared across business types, THE Jewellery_System SHALL preserve the behavior of every business type other than `jewellery` such that their sidebar, capability, and routing resolution is identical to the pre-change behavior.
10. THE Jewellery_System SHALL NOT modify the sidebar section function, capability set, or routing logic of any business type other than `jewellery`.
11. WHEN a phase of this remediation is completed, THE Jewellery_System SHALL emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and SHALL perform no further phase work until the literal reply `APPROVED` is received.
12. WHERE the Jewellery_System modifies a shared file, THE Jewellery_System SHALL document the blast radius of the change in the file or accompanying notes.

### Requirement 2: Phase 0 — Read-Only Verification

**User Story:** As a maintainer, I want every unverified audit finding resolved to CONFIRMED or FALSIFIED before any code changes, so that subsequent phases act on confirmed facts rather than assumptions.

#### Acceptance Criteria

1. WHILE executing Phase 0, THE Jewellery_System SHALL create, modify, and delete zero files other than the single Verification_Report artifact.
2. THE Verification_Report SHALL classify the live bill-total computation as exactly one of: `Rate/Gm × metalWeight` (correct) or `Rate/Gm × quantity` (incorrect), with the file path and start and end line numbers of the evidence.
3. THE Verification_Report SHALL state whether an editable making-charges column exists in the billing line-item UI, with the file path and start and end line numbers of the evidence.
4. THE Verification_Report SHALL classify each of the `/jewellery/*` endpoints (`products`, `gold-rate`, `old-gold-exchange`, `custom-orders`, `hallmark-inventory`, `gold-rate-alert`, `gold-scheme`, `making-charges`, `jewellery-repair`) as exactly one of: deployed non-stub handler, deployed stub handler, or no handler deployed (404).
5. THE Verification_Report SHALL record the offline-versus-online behavior of each of the four un-audited repositories (`gold_scheme`, `jewellery_repair`, `gold_rate_alert`, `making_charges`) from a line read, with file path and line numbers.
6. THE Verification_Report SHALL record the observed behavior of `jewellery_sync_handler.dart` and `jewellery_ws_handler.dart` from a line read, with file path and line numbers.
7. THE Verification_Report SHALL state whether a backing screen exists for the `/purchase/scan-bill` navigation target, with the file path and line numbers of the evidence.
8. WHERE the Verification_Report records a previously unverified audit item, THE Verification_Report SHALL mark that item as exactly one of CONFIRMED or FALSIFIED with the supporting file path and line numbers.
9. IF an item cannot be resolved to CONFIRMED or FALSIFIED from available evidence, THEN THE Verification_Report SHALL flag the item as still-unverified with a stated reason.

### Requirement 3: Phase 1 — Sidebar Reachability (P0 Critical Wiring)

**User Story:** As a jewellery vendor, I want a dedicated sidebar for my business, so that I can reach every jewellery feature from normal navigation instead of a generic retail sidebar.

#### Acceptance Criteria

1. WHEN `_getSectionsForBusiness` is called with `BusinessType.jewellery`, THE Sidebar_Configuration SHALL return the section list produced by a new `_getJewellerySections()` function via an explicit `case BusinessType.jewellery`, and SHALL NOT fall through to `_getRetailSections()` or any other business type's section function.
2. WHEN `_getSectionsForBusiness` is called with `BusinessType.jewellery`, THE Sidebar_Configuration SHALL return sections covering exactly these surfaces with no missing entries: Daily Rates, Billing, Inventory by weight and hallmark, Old Gold Exchange, Custom Orders, Repairs, Gold Schemes, and Making-Charges Calculator.
3. WHEN `_getSectionsForBusiness` is called with `BusinessType.jewellery`, THE Sidebar_Configuration SHALL return each jewellery section with a non-empty label and a navigation target that is reachable from the sidebar.
4. WHILE `_getSectionsForBusiness` is called with any `BusinessType` other than `jewellery`, THE Sidebar_Configuration SHALL return sections identical to those returned prior to the `case BusinessType.jewellery` addition.

### Requirement 4: Phase 1 — Route Registration and Guards

**User Story:** As a jewellery vendor, I want all jewellery screens registered as guarded named routes on a single documented route surface, so that navigation resolves correctly and securely without route-surface drift.

#### Acceptance Criteria

1. THE App_Router SHALL register all of The_Eight_Screens as named routes within the "CUSTOM BUSINESS MODULES" section of the legacy `MaterialApp routes:` table, as the single documented route surface for the Jewellery_System.
2. WHERE the App_Router registers a jewellery route, THE App_Router SHALL wrap each individual route in both Vendor_Role_Guard and Business_Guard with `allowedTypes: [BusinessType.jewellery]`.
3. WHEN a user whose business type is `jewellery` and who holds the vendor role navigates to a jewellery route, THE Jewellery_System SHALL resolve the route to its target screen from The_Eight_Screens.
4. IF a user whose business type is not `jewellery` or who lacks the vendor role navigates to a jewellery route, THEN THE Jewellery_System SHALL block access and redirect to a fallback, retaining no jewellery screen state.
5. THE Jewellery_System SHALL reconcile the two divergent route surfaces (the 7-route module list and the integration list) into a single reachable set comprising all of The_Eight_Screens, such that the set of reachable jewellery screens equals exactly The_Eight_Screens.

### Requirement 5: Phase 1 — Navigation Handler, Dead-Code Removal, and Scan-Bill

**User Story:** As a jewellery vendor, I want every jewellery sidebar selection to resolve to a real screen with no dead navigation, so that I never reach an "Unknown Screen" placeholder.

#### Acceptance Criteria

1. WHEN `getScreenForItem` is called with any jewellery sidebar item id introduced by Requirement 3, THE Sidebar_Navigation_Handler SHALL return the single jewellery screen widget mapped to that id.
2. IF `getScreenForItem` is called with a jewellery sidebar item id introduced by Requirement 3, THEN THE Sidebar_Navigation_Handler SHALL NOT return the `_buildPlaceholderScreen('Unknown Screen')` fallthrough.
3. WHEN a jewellery vendor activates the `/purchase/scan-bill` navigation target, THE Jewellery_System SHALL resolve it to a backing screen and SHALL NOT leave the navigation as a dead end.
4. IF Jewellery_Integration is confirmed dead code in Phase 0, THEN THE Jewellery_System SHALL delete `jewellery_integration.dart` only after an explicit recorded sign-off, and SHALL leave the file unchanged until that sign-off is recorded.

### Requirement 6: Phase 2 — Rate Unit Correctness (P0 Money-Correctness)

**User Story:** As a jewellery vendor, I want gold rates converted between per-10g and per-gram exactly once at a single boundary, so that bills never carry a 10× pricing error.

#### Acceptance Criteria

1. THE Jewellery_System SHALL convert a Gold_Rate_Card per-10g paise value to a per-gram paise value at a single documented boundary using integer division `pricePerGramPaisa = pricePer10gPaisa ~/ 10`.
2. WHEN a per-10g paise value is converted to per-gram and consumed by Jewellery_Business_Rules, THE Jewellery_System SHALL apply the conversion exactly once with no second division or multiplication of the same value.
3. THE Jewellery_System SHALL provide bidirectional unit tests asserting that per-10g-to-per-gram conversion and its inverse produce consistent paise values for a representative set of rates.
4. IF a per-10g paise value is not evenly divisible by 10, THEN THE Jewellery_System SHALL apply a defined rounding rule for the integer-paise result and document that rule at the conversion boundary.

### Requirement 7: Phase 2 — Pricing Engine Unification and Bill Total

**User Story:** As a jewellery vendor, I want a single canonical pricing engine that bills by weight, so that the same sale produces the same total on every screen.

#### Acceptance Criteria

1. THE Jewellery_System SHALL designate `Jewellery_Business_Rules.billTotal` as the single canonical pricing engine for jewellery sale totals.
2. WHEN Making_Charges_Calculator computes a sale total, THE Jewellery_System SHALL delegate the metal-value, tax, and total computation to Jewellery_Business_Rules rather than computing a parallel total.
3. WHEN the same line items, weights, purity, rates, making charges, and tax rate are supplied to Making_Charges_Calculator and to Jewellery_Business_Rules, THE Jewellery_System SHALL produce grand totals that are equal to the nearest paise.
4. WHEN the live billing screen computes a jewellery bill total, THE Jewellery_System SHALL multiply Rate/Gm by `metalWeight` and SHALL NOT multiply Rate/Gm by `quantity`, in accordance with the Phase 0 finding for criterion 2 of Requirement 2.
5. THE Jewellery_System SHALL provide a calculation-engine test asserting that a jewellery bill total equals weight multiplied by rate plus making charges plus tax minus discount, computed in integer Paise.

### Requirement 8: Phase 2 — GST, Wastage, and Stone Charge Correctness

**User Story:** As a jewellery vendor, I want GST, wastage, and stone charges computed correctly, so that my bills are tax-accurate and free of double-counting.

#### Acceptance Criteria

1. THE Jewellery_System SHALL compute GST by applying the metal-value GST rate to the metal value and the making-charges GST treatment to making charges in accordance with documented Indian GST practice, with the cited treatment recorded in a code comment.
2. THE Jewellery_System SHALL apply wastage to the sale total exactly once such that wastage is not counted in both the metal-value path and the making-charges path for the same sale.
3. WHEN a stone charge is computed, THE Jewellery_System SHALL use a real stone-count field rather than the placeholder assumption of one stone per gram.
4. WHERE GST, wastage, and stone charges are computed, THE Jewellery_System SHALL perform every intermediate and final money computation in integer Paise.

### Requirement 9: Phase 3 — Jewellery-Domain Capabilities (P1 Capability & Security)

**User Story:** As a security owner, I want jewellery-domain capabilities defined and applied, so that jewellery features are gated by the capability layer rather than bypassing it.

#### Acceptance Criteria

1. THE Jewellery_System SHALL add the following Business_Capability flags to the capability registry: `useGoldRate`, `useGoldRateAlert`, `useMakingCharges`, `useHallmark`, `useOldGoldExchange`, `useCustomOrders`, `useGoldSchemes`, `useJewelleryRepair`, `useProductUnit`, and `useProductTax`.
2. THE Jewellery_System SHALL grant each capability listed in criterion 1 to `BusinessType.jewellery` in `businessCapabilityRegistry['jewellery']`.
3. WHERE a jewellery sidebar item introduced by Requirement 3 surfaces a gated domain feature, THE Jewellery_System SHALL attach the corresponding Business_Capability from criterion 1 to that `SidebarMenuItem`.
4. WHEN `FeatureResolver.canAccess` is evaluated for a jewellery domain capability that is granted, THE Jewellery_System SHALL permit access to the gated item.
5. THE Jewellery_System SHALL NOT grant any capability listed in criterion 1 to any business type other than `jewellery`.

### Requirement 10: Phase 3 — Capability Bypass Resolution and Guard Re-verification

**User Story:** As a security owner, I want the retail sidebar items shown to jewellery reconciled with granted capabilities, so that no off-workflow item appears without a capability gate.

#### Acceptance Criteria

1. WHERE the Jewellery_System surfaces the retail-origin items `return_inwards`, `proforma_bids`, `dispatch_notes`, `booking_orders`, and `low_stock` to a jewellery vendor, THE Jewellery_System SHALL gate each such item with a Business_Capability so that an item without a granted capability is not reachable.
2. WHEN capability reconciliation runs, THE Jewellery_System SHALL report, per item, whether each of the five retail-origin items is gated or removed for the Jewellery_System.
3. WHEN a jewellery route is registered or modified, THE Jewellery_System SHALL re-verify that the route carries both Vendor_Role_Guard and Business_Guard with `allowedTypes: [BusinessType.jewellery]`.
4. IF a retail-origin item is neither gated by a granted capability nor removed for the Jewellery_System, THEN THE Jewellery_System SHALL treat the reconciliation as incomplete and surface the unresolved item.

### Requirement 11: Phase 3 — PMLA KYC PII Protection

**User Story:** As a compliance owner, I want old-gold-exchange KYC PII encrypted or redacted and tenant-scoped, so that PMLA-sensitive customer data is protected at rest.

#### Acceptance Criteria

1. WHERE the Jewellery_System persists PMLA_KYC_PII fields `customerIdNumber` and `customerPhotoUrl`, THE Jewellery_System SHALL apply field-level encryption or redaction to those fields at rest.
2. WHERE the Jewellery_System stores or retrieves an old-gold-exchange record containing PMLA_KYC_PII, THE Jewellery_System SHALL scope the record by Tenant_Id.
3. WHEN the Jewellery_System displays a stored `customerIdNumber`, THE Jewellery_System SHALL render it in a redacted form rather than in full plaintext.
4. IF decryption or de-redaction of PMLA_KYC_PII fails, THEN THE Jewellery_System SHALL withhold the field value and surface an error indication rather than displaying corrupted or partial data.

### Requirement 12: Phase 4 — Dashboard Quick Actions and Live Alerts

**User Story:** As a jewellery vendor, I want working dashboard quick actions and real alert counts, so that I can act on live business state instead of dead buttons and fabricated numbers.

#### Acceptance Criteria

1. WHEN a jewellery vendor activates the "Custom Order" quick action, THE Quick_Actions SHALL navigate to `CustomOrderManagementScreen`.
2. WHEN a jewellery vendor activates the "Gold Rate" quick action, THE Quick_Actions SHALL navigate to `GoldRateManagementScreen`.
3. THE Quick_Actions SHALL NOT register an empty `onTap: () {}` handler for any jewellery quick action.
4. WHEN Alerts_Widget resolves alerts for `BusinessType.jewellery`, THE Alerts_Widget SHALL display counts sourced from Jewellery_Repository_Offline query results for pending custom orders and the current gold-rate state.
5. THE Alerts_Widget SHALL NOT display any hardcoded or literal numeric count (such as the values `3` or `!`) for the Jewellery_System.
6. WHILE a resolved jewellery alert count equals zero, THE Alerts_Widget SHALL display the numeric value 0 rather than omitting the alert or substituting a placeholder.
7. IF Jewellery_Repository_Offline fails to return an alert count when Alerts_Widget requests it, THEN THE Alerts_Widget SHALL display an error indication for the affected alert and SHALL NOT display a stale or default numeric value.

### Requirement 13: Phase 4 — Dedicated Dashboard, Ticker, and Live Data

**User Story:** As a jewellery vendor, I want a dedicated dashboard with live gold-rate data and weight-based stock, so that my dashboard reflects my actual jewellery workflow.

#### Acceptance Criteria

1. WHEN a jewellery vendor opens the dashboard, THE Jewellery_System SHALL render a dedicated jewellery dashboard with KPI cards for gold rate by purity (24K, 22K, 18K), metal stock by weight, pending custom orders, scheme collections due, and repair jobs in progress.
2. THE Jewellery_System SHALL render a gold-rate ticker widget on the jewellery dashboard sourced from live Gold_Rate_Card data.
3. WHEN a jewellery vendor edits purity on a billing line item, THE Bill_Line_Item_Row SHALL present an editable Purity_Enum dropdown rather than a read-only text cell.
4. WHEN a jewellery vendor edits making charges on a billing line item, THE Bill_Line_Item_Row SHALL present an editable making-charges column, in accordance with the Phase 0 finding for criterion 3 of Requirement 2.
5. WHEN a jewellery vendor opens `stock_summary` or `item_stock`, THE Jewellery_System SHALL present stock by metal weight rather than by quantity only.
6. THE Jewellery_System SHALL source every value displayed on the jewellery dashboard from repository or provider query results and SHALL NOT display any hardcoded value.

### Requirement 14: Phase 5 — Offline-First Parity and Sync Reconciliation (P1)

**User Story:** As a jewellery vendor, I want all jewellery features to work offline with correct conflict handling, so that I can operate without continuous connectivity and never silently lose data.

#### Acceptance Criteria

1. THE Jewellery_System SHALL migrate `custom_order_management_screen.dart` off the online-only Jewellery_Repository_Online onto an offline-first path backed by Hive plus the sync queue.
2. THE Jewellery_System SHALL bring the four repositories `gold_scheme`, `jewellery_repair`, `gold_rate_alert`, and `making_charges` to offline-first parity with Jewellery_Repository_Offline, each using Hive plus the sync queue.
3. WHEN a jewellery vendor creates, updates, or deletes a jewellery record while offline or online, THE Jewellery_System SHALL persist the change to the local Hive box immediately and enqueue a corresponding sync-queue entry.
4. WHEN the Jewellery_System reconciles a sync conflict, THE Jewellery_System SHALL compare record versions and apply version-based reconciliation rather than last-write-wins.
5. IF a queued jewellery sync entry fails to transmit, THEN THE Jewellery_System SHALL retain the entry, preserve the local record unchanged, retry up to 5 times, and after the final failed attempt mark the entry with a failed-sync indication observable to the vendor without discarding the local change.
6. WHERE Phase 5 changes a Hive schema, THE Jewellery_System SHALL make the change additive and idempotent and SHALL obtain a Mini_Gate before applying it.

### Requirement 15: Phase 6 — Validation and Crash Prevention (P2)

**User Story:** As a jewellery vendor, I want inputs validated and edge cases guarded, so that invalid data and malformed configurations do not produce wrong prices or crash screens.

#### Acceptance Criteria

1. WHEN Jewellery_Business_Rules computes `billTotal` or `exchangeCredit`, THE Jewellery_System SHALL apply an upper bound and a not-a-number guard so that out-of-range or non-numeric inputs do not produce an invalid total.
2. IF a negative weight, a negative rate, or a percentage greater than 100 is entered into Making_Charges_Calculator, THEN THE Jewellery_System SHALL reject the input, retain the previous valid value, and present an error indication.
3. IF the tiered making-charges configuration has empty `tieredRates` and a weight does not match any tier, THEN THE Jewellery_System SHALL return a graceful tiered-error result rather than throwing an uncaught exception.
4. WHEN `registerHallmark` is called with an HUID that already exists for the Tenant_Id, THE Jewellery_System SHALL detect the duplicate and reject the registration rather than silently overwriting the existing entry.
5. WHEN `setGoldRate` is called, THE Jewellery_System SHALL apply day-over-day spike and sanity bounds and reject a rate that exceeds those bounds.
6. THE Jewellery_System SHALL replace the free-text purity `String` representation with Purity_Enum end-to-end across billing and storage.

### Requirement 16: Phase 7 — Performance and Backend (P2/P3)

**User Story:** As a jewellery vendor, I want paginated lists and working backend endpoints, so that large datasets load efficiently and sync never fails silently.

#### Acceptance Criteria

1. WHEN `getProducts`, `getOrders`, `getExchanges`, or `getHallmarkEntries` is called with a limit and offset, THE Jewellery_System SHALL return at most the requested number of records starting at the requested offset.
2. THE Jewellery_System SHALL audit each jewellery list screen and pass an explicit limit and offset to the repository rather than loading an entire Hive box into memory.
3. THE Jewellery_System SHALL build or ticket each `/jewellery/*` endpoint identified as a backend gap in Phase 0, so that no jewellery sync operation fails silently against a missing endpoint.
4. IF a `/jewellery/*` endpoint is absent and a sync operation targets it, THEN THE Jewellery_System SHALL surface a visible sync-failure indication rather than leaving records marked unsynced without notice.
5. THE Jewellery_System SHALL build a certificate and certification tracking model and screen for jewellery items.
6. THE Jewellery_System SHALL record a live gold-rate market-feed integration as a non-blocking backlog item rather than implementing it within this remediation.

### Requirement 17: Phase 8 — Polish, Accessibility, and Sign-Off (P2/P3)

**User Story:** As a maintainer, I want encoding, accessibility, and regression polish with explicit dead-code disposition, so that the vertical ships clean, accessible, and without regressing any other vertical.

#### Acceptance Criteria

1. THE Jewellery_System SHALL replace the mojibake glyphs (such as `Ã—` for `×` and `â‚¹` for `₹`) in `making_charges_calculator.dart` and `jewellery_business_rules.dart` with the correct characters and re-save both files as UTF-8.
2. WHERE a jewellery dashboard widget in `business_quick_actions.dart` or `business_alerts_widget.dart` conveys state, THE Jewellery_System SHALL wrap the control in a `Semantics` widget exposing a non-empty label readable by assistive technologies.
3. THE Jewellery_System SHALL replace the glyph-only `'!'` gold-rate alert badge with an accessible text label that describes the alert state.
4. IF Jewellery_Integration deletion is approved, THEN THE Jewellery_System SHALL confirm and perform the deletion of `jewellery_integration.dart` under the sign-off recorded for Requirement 5 criterion 4.
5. WHEN a jewellery screen from The_Eight_Screens is rendered, THE Jewellery_System SHALL present a responsive layout that renders its primary content without overflow on phone, tablet, and desktop breakpoints.
6. THE Jewellery_System SHALL run the full test suite and confirm that no other business vertical regresses as a result of this remediation.
7. WHERE a Phase 8 disposition requires deleting code, THE Jewellery_System SHALL obtain an explicit recorded sign-off before performing the deletion and SHALL leave the code unchanged until that sign-off is recorded.
