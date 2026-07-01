# Requirements Document

## Introduction

The DukanX `clothing` business vertical (`BusinessType.clothing`, "Clothing / Fashion") ships a meaningful amount of clothing-specific UI and logic — a size × color `VariantGridWidget` with "Smart Fill" size curves, a `ClothingInventoryScreen` (size/color/SKU/barcode), a `VariantManagementScreen`, a `TailoringMeasurementsScreen`, a `VariantRepository`, a `ClothingBusinessRules` utility, a `ClothingVariantScannerWidget`, and a registered `ClothingModule` with GoRouter routes and nav items — but almost none of it is reachable in the running desktop app. An evidence-based audit (`audit-reports/business-types/audit-clothing.md`) found that clothing has no dedicated case in `_getSectionsForBusiness` and falls through to the generic retail sidebar (`_getRetailSections`), so a clothing merchant sees zero clothing-specific entries. The clothing-specific screens live in the parallel `ClothingModule` GoRouter system, which the live app does not mount because `app/app.dart` builds `MaterialApp(routes: buildAppRoutes())` (the legacy `MaterialApp.routes` map), leaving `ClothingInventoryScreen`, `VariantManagementScreen`, `TailoringMeasurementsScreen`, `VariantGridWidget`, and `ClothingBusinessRules` orphaned or dead.

Beyond reachability, the audit identified a critical data-loss defect (the variant grid's `onQuantitiesChanged` is an empty callback, so grid edits are silently discarded with no Save button), an API contract mismatch (`/clothing/variants/{id}` read as `items` by one consumer and `variants` by another), crash risks (`VariantItem.fromJson` unguarded casts, a `firstWhere` with no `orElse` in `_getFilteredVariants`, `double.parse` at tailoring save), a missing GST value-slab rule (5% under ₹1000 / 12% at-or-above ₹1000 is only a code comment), an N+1 variant fetch and a per-keystroke recompute with no debounce, a capability mismatch hiding the only variant-related sidebar item (`batch_tracking` gated by `useBatchExpiry`, which clothing is not granted), an RBAC bypass where financial/compliance/admin retail items carry no `permission` tag, a mis-permissioned variant route (`Permissions.manageStaff` guarding a product screen), a mis-routed "Variants" quick action (to `AppScreen.categories` instead of the variant matrix), hardcoded dashboard alert counts (`'6'` and `'9'`), inconsistent money representation (mixed `priceCents` integers and `priceAdjustment`/`quantity` doubles), a fragile string-stored delivery date, hardcoded non-theme-aware colors, and accessibility gaps.

This document specifies a phased, evidence-based remediation that makes the clothing vertical shippable end-to-end. Work proceeds strictly in phase order (Phase 0 through Phase 10). Phase 0 is read-only verification that resolves every unverified audit item to CONFIRMED or FALSIFIED. Each subsequent phase ends with an explicit STOP GATE that requires human sign-off before the next begins. All work is bound by a set of non-negotiable cross-cutting constraints (multi-tenant scoping, integer-paise money, RID id pattern, idempotent migrations, no hard deletes, no schema changes without a mini-gate, additive-only edits to shared components with a regression pass).

The vertical is referred to throughout as the **Clothing_System**, with sub-systems named for clarity. Requirements are grouped by the phase that delivers them and map back to the audit findings they remediate.

## Glossary

- **Clothing_System**: The clothing business vertical of the DukanX Flutter app, encompassing its screens, repositories, models, services, providers, routes, capabilities, dashboard widgets, and sidebar configuration. Identified by `BusinessType.clothing`.
- **Sidebar_Configuration**: `lib/widgets/desktop/sidebar_configuration.dart` — defines `SidebarSection`/`SidebarMenuItem` lists per business type via `_getSectionsForBusiness`. A shared component spanning 9+ verticals.
- **Sidebar_Navigation_Handler**: `lib/widgets/desktop/sidebar_navigation_handler.dart` — resolves a sidebar item id to a screen widget via `getScreenForItem`.
- **App_Router**: `lib/app/routes.dart` `buildAppRoutes()` — the legacy `MaterialApp routes:` registration table that is the single source of truth for live named routes, including the "CUSTOM BUSINESS MODULES" section and the existing `/clothing/variants` entry.
- **Clothing_Module**: `lib/modules/clothing/clothing_module.dart` — the parallel GoRouter module (`routes => clothingRoutes`, 5 `navItems`) that is registered in `ModuleRegistry` but not mounted by the live app.
- **Clothing_Routes**: `lib/modules/clothing/routes/clothing_routes.dart` — the GoRouter route list for the Clothing_Module, currently containing `LegacyRouteRedirect` stubs and one real `/clothing/inventory` route.
- **Clothing_Inventory_Screen**: `lib/features/clothing/presentation/screens/clothing_inventory_screen.dart` — the size/color/SKU/barcode inventory screen, currently orphaned and online-only.
- **Variant_Management_Screen**: `lib/features/clothing/presentation/screens/variant_management_screen.dart` — hosts the `VariantGridWidget`; reachable only via a guarded legacy route that no UI navigates to.
- **Tailoring_Measurements_Screen**: `lib/features/clothing/presentation/screens/tailoring_measurements_screen.dart` — captures chest/waist/hips/length/sleeve/shoulder/neck/inseam, priority, and a delivery date; fully orphaned (no route, no navigation).
- **Variant_Grid_Widget**: `lib/features/clothing/widgets/variant_grid/variant_grid_widget.dart` — the editable size-column × color-row matrix with "Smart Fill" size curves.
- **Variant_Cell**: `lib/features/clothing/widgets/variant_grid/variant_cell.dart` — a single editable matrix cell (internals unverified in the audit).
- **Size_Curve_Chip**: `lib/features/clothing/widgets/variant_grid/size_curve_chip.dart` — the "Smart Fill" size-curve chip (internals unverified in the audit).
- **Variant_Scanner_Widget**: `lib/features/barcode/widgets/clothing_variant_scanner_widget.dart` — the read-only variant barcode scanner (internals unverified in the audit).
- **Variant_Repository**: `lib/features/clothing/data/variant_repository.dart` — holds `getVariants`, `bulkUpdateVariants`, `exportToCsv`, and the `VariantItem` model (`color/size/quantity/priceAdjustment`).
- **Variant_Item**: `VariantItem` — the typed variant model in Variant_Repository, to be unified to include `sku`, `barcode`, `priceCents`, and `stock`.
- **Clothing_Business_Rules**: `lib/features/clothing/utils/clothing_business_rules.dart` — the `isValidMeasurement` (bounds per `MeasurementKey`), `sizeForChest`, and related domain rules; currently imported by nothing (dead code).
- **Clothing_Sync_Handler**: `lib/modules/clothing/sync/clothing_sync_handler.dart` — the offline sync handler for clothing entities (live effect unverified in the audit).
- **Clothing_Ws_Handler**: `lib/modules/clothing/websocket/clothing_ws_handler.dart` — the websocket handler for clothing entities (live effect unverified in the audit).
- **Business_Capability**: `BusinessCapability` enum and the capability registry (`lib/core/isolation/business_capability.dart`); resolved by **Feature_Resolver**.
- **Feature_Resolver**: `lib/core/isolation/feature_resolver.dart` `canAccess()` — the strict-deny capability gate applied to `SidebarMenuItem`s before RBAC.
- **Quick_Actions**: `lib/features/dashboard/v2/widgets/business_quick_actions.dart` — dashboard quick-action buttons resolved per `BusinessType`. A shared component.
- **Alerts_Widget**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` — dashboard alert-count widget resolved per `BusinessType`. A shared component.
- **Business_Capability_File**: `lib/core/isolation/business_capability.dart` — the capability registry; a shared component spanning 9+ verticals.
- **Alert_Counts_Provider**: `alertCountsProvider` / `fetchCounts()` — the live Drift-backed stream that supplies real `lowStock`/`expiringSoon` counts (used by the grocery dashboard case).
- **Vendor_Role_Guard**: `VendorRoleGuard` — the existing route wrapper enforcing vendor role and an optional required permission.
- **Business_Guard**: `BusinessGuard` — the existing route wrapper restricting a route to specified `allowedTypes`.
- **GST_Slab_Rule**: The Indian apparel GST value-slab rule — 5% when the taxable item value is under ₹1000 and 12% when the value is at or above ₹1000 — applied in integer Paise.
- **Print_Infrastructure**: The existing print/label infrastructure (`PrintMenuScreen` and related services) used to render and print documents.
- **Verification_Report**: A read-only Markdown artifact produced in Phase 0 documenting endpoint reality, widget/handler behavior, dead-code confirmation, RBAC matrix reality, and bill-rendering reality, containing zero code changes.
- **Verification_Matrix**: The Phase 10 Markdown artifact mapping every audit finding to exactly one of FIXED, VERIFIED-OK, or DEFERRED-SIGNOFF.
- **Tenant_Id**: The authenticated business identity (`session.currentBusinessId`) used to scope all queries, writes, and sync calls.
- **Paise**: Integer representation of currency (1 rupee = 100 paise). All money values in touched clothing code are integer paise.
- **RID**: The new-entity identifier pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
- **Shared_Components**: The cross-vertical files `sidebar_configuration.dart`, `business_alerts_widget.dart`, `business_quick_actions.dart`, `business_capability.dart`, and `feature_resolver.dart`, each spanning 9+ verticals.
- **Stop_Gate**: A point at which Clothing_System work for a phase stops and waits for explicit human approval before continuing. Emitted as the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and resumed only on the literal reply `APPROVED`.
- **Mini_Gate**: A separate, explicit sign-off required specifically before any Hive box or DynamoDB schema/model shape change, accompanied by a proposed change and a migration plan.

## Requirements

### Requirement 1: Cross-Cutting Non-Negotiable Constraints

**User Story:** As the platform owner, I want every change in this remediation to honor the platform's multi-tenant, money, identity, and safety invariants, so that the Clothing_System ships without introducing data leakage, currency errors, or destructive side effects.

#### Acceptance Criteria

1. WHERE money values are represented in code created or modified by this remediation, THE Clothing_System SHALL store and compute currency as integer Paise.
2. THE Clothing_System SHALL NOT introduce `double`, `float`, or decimal floating-point types for currency or quantity-price values in code created or modified by this remediation, and SHALL migrate any touched `double` price or quantity field to integer Paise.
3. WHEN the Clothing_System creates a new entity identifier, THE Clothing_System SHALL generate it using the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, where `tenantId` is the active Tenant_Id, `timestamp_ms` is the Unix epoch time in milliseconds, and `uuid_v4_short` is a non-empty shortened form of a UUID version 4.
4. WHERE the Clothing_System reads, writes, or synchronizes clothing data, THE Clothing_System SHALL scope every query, repository call, and sync call by Tenant_Id.
5. IF a change requires a DynamoDB schema or model shape change or a Hive box change, THEN THE Clothing_System SHALL halt and request a Mini_Gate, presenting the proposed change and a migration plan, before applying the change.
6. IF a change requires removing a record, file, route, or screen, THEN THE Clothing_System SHALL use a soft-delete status flag or a flow requiring two distinct explicit user confirmations rather than a hard delete, and SHALL NOT perform a hard delete of data.
7. WHERE the Clothing_System applies a data migration, THE Clothing_System SHALL make the migration idempotent and re-runnable such that repeated executions produce the same persisted result and modify zero records after the first execution.
8. WHEN the Clothing_System modifies a Shared_Component, THE Clothing_System SHALL make additive edits only and SHALL preserve the behavior of every business type other than `clothing`.
9. THE Clothing_System SHALL NOT modify the sidebar section function, capability set, quick actions, or alerts of any business type other than `clothing`.
10. WHEN the Clothing_System completes an additive edit to a Shared_Component, THE Clothing_System SHALL execute a regression pass that verifies every business type other than `clothing` resolves unchanged behavior and records a pass or fail result per business type.
11. WHEN the Clothing_System completes an additive edit to a Shared_Component, THE Clothing_System SHALL document the blast radius identifying the Shared_Components changed and the business types exercised.
12. IF the Tenant_Id is missing or cannot be resolved, THEN THE Clothing_System SHALL reject the operation, perform no read or write, and return an error.
13. WHEN a phase of this remediation is completed, THE Clothing_System SHALL emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and SHALL perform no further phase work until the literal reply `APPROVED` is received.

### Requirement 2: Scope Boundary

**User Story:** As a maintainer, I want the remediation boundary fixed in advance, so that the work stays surgical and does not expand into out-of-scope rewrites.

#### Acceptance Criteria

1. THE Clothing_System SHALL restrict all code changes to exactly these four locations: files under `features/clothing/*`, files under `modules/clothing/*`, the `clothing` case within Shared_Components, and the navigation entries (route registration and sidebar/menu wiring) required to make clothing screens reachable; THE Clothing_System SHALL NOT modify any file outside these four locations.
2. THE Clothing_System SHALL NOT perform an app-wide GoRouter migration as part of this remediation, and SHALL limit any router change to the navigation entries needed for clothing screen reachability as defined in criterion 1.
3. THE Clothing_System SHALL NOT create any new backend endpoint, and SHALL only add or adjust an endpoint where it is required to satisfy an API contract already referenced by an existing clothing screen.
4. WHERE the e-Way bill feature is requested, THE Clothing_System SHALL treat it as deferred and excluded from scope, and SHALL request explicit confirmation before performing any e-Way bill code change.
5. IF a proposed change falls outside the boundary defined in criterion 1, THEN THE Clothing_System SHALL not apply the change, SHALL leave existing files unmodified, and SHALL surface a request for explicit sign-off identifying the out-of-scope change before proceeding.
6. WHILE awaiting confirmation for a deferred or out-of-scope change (criteria 4 and 5), THE Clothing_System SHALL continue only with in-scope work defined in criterion 1 and SHALL NOT apply the pending change until explicit sign-off is received.

### Requirement 3: Phase 0 — Read-Only Verification

**User Story:** As a maintainer, I want every unverified audit finding resolved to CONFIRMED or FALSIFIED before any code changes, so that subsequent phases act on confirmed facts rather than assumptions.

#### Acceptance Criteria

1. WHILE executing Phase 0, THE Clothing_System SHALL create, modify, and delete zero files other than the single Verification_Report artifact, and SHALL NOT modify any application source, configuration, or build file.
2. THE Verification_Report SHALL state what the cited source lines of `variant_cell.dart`, `size_curve_chip.dart`, and `clothing_variant_scanner_widget.dart` do, with file path and start and end line numbers for each.
3. THE Verification_Report SHALL classify each of `clothing_sync_handler.dart` and `clothing_ws_handler.dart` as exactly one of active or not-active in the live app, with file path and start and end line numbers.
4. THE Verification_Report SHALL record the exact `AppScreen` targets that `AppScreen.itemStock` and `AppScreen.categories` resolve to in `core/navigation/app_screens.dart`, with file path and line numbers.
5. THE Verification_Report SHALL classify whether the `session_manager.dart` RBAC matrix gates the retail sidebar items shown to clothing as exactly one of gated or not-gated, with file path and line numbers.
6. THE Verification_Report SHALL classify whether the billing line-item UI renders `size` and `color` per line as exactly one of renders or does-not-render, with file path and line numbers.
7. THE Verification_Report SHALL classify the backend response shape for each of `/clothing/variants/{id}`, `/clothing/tailoring-notes`, and `/clothing/variants/bulk` as exactly one of: deployed non-stub handler, deployed stub handler, or no handler deployed, recording the response key contract observed and the file path with start and end line numbers where a handler exists.
8. WHERE the Verification_Report records a previously unverified audit item, THE Verification_Report SHALL mark that item as exactly one of CONFIRMED or FALSIFIED with the supporting file path and line numbers.
9. IF an item cannot be resolved to CONFIRMED or FALSIFIED from available evidence, THEN THE Verification_Report SHALL flag the item as still-unverified and SHALL state the specific evidence that is missing.
10. THE Verification_Report SHALL resolve every previously unverified audit item to exactly one of CONFIRMED, FALSIFIED, or still-unverified.

### Requirement 4: Phase 1 — Navigation Reachability Architecture Decision

**User Story:** As a maintainer, I want a single recorded decision on how clothing screens become reachable in the live app, so that subsequent wiring follows one documented route surface.

#### Acceptance Criteria

1. THE Clothing_System SHALL produce a recorded architecture decision that enumerates both Option A (mount the full GoRouter module system) and Option B (register scoped clothing routes on the legacy `MaterialApp.routes` surface) and selects exactly one of them as the chosen option.
2. THE Clothing_System SHALL record Option B as the recommended option.
3. THE Clothing_System SHALL document, for the selected option, a rationale that states the reason for selection and the trade-offs of the rejected option, such that the record contains no unresolved or "to be decided" placeholders.
4. WHEN the architecture decision is recorded, THE Clothing_System SHALL identify exactly one documented route surface on which all subsequent clothing routes are registered.
5. WHEN the architecture decision record is completed, THE Clothing_System SHALL emit the Stop_Gate for Phase 1.
6. WHILE the recorded architecture decision has not been approved, THE Clothing_System SHALL NOT begin sidebar wiring or route wiring.
7. IF the recorded architecture decision is rejected or returned with requested changes, THEN THE Clothing_System SHALL retain the existing decision record, apply the requested changes, and re-emit the Stop_Gate for Phase 1 without beginning sidebar or route wiring.

### Requirement 5: Phase 2 — Dedicated Clothing Sidebar Section

**User Story:** As a clothing merchant, I want a dedicated sidebar for my business, so that I can reach every clothing feature from normal navigation instead of a generic retail sidebar.

#### Acceptance Criteria

1. WHEN `_getSectionsForBusiness` is called with `BusinessType.clothing`, THE Sidebar_Configuration SHALL return the section list produced by a new `_getClothingSections()` function via an explicit `case BusinessType.clothing`, and SHALL NOT fall through to `default: _getRetailSections()`.
2. WHEN `_getSectionsForBusiness` is called with `BusinessType.clothing`, THE Sidebar_Configuration SHALL return exactly one dedicated clothing section containing the four items Variant Matrix, Tailoring / Alterations, Size & Color Stock Overview, and Price-Tag / Barcode Printing, in addition to the same shared common sections returned for every other `BusinessType`.
3. WHEN `_getSectionsForBusiness` is called with `BusinessType.clothing`, THE Sidebar_Configuration SHALL return each of the four clothing-specific items with a label containing at least one non-whitespace character and a navigation target that resolves via Sidebar_Navigation_Handler to an existing screen, with no item pointing to an unimplemented or placeholder route.
4. WHERE a clothing-specific sidebar item surfaces a gated domain feature and its corresponding Business_Capability (`useVariants`, `useTailoringNotes`, `useBarcodeScanner`, or `useScanOCR`) is granted, THE Sidebar_Configuration SHALL tag that `SidebarMenuItem` with that granted Business_Capability.
5. IF a clothing-specific sidebar item surfaces a gated domain feature whose corresponding Business_Capability (`useVariants`, `useTailoringNotes`, `useBarcodeScanner`, or `useScanOCR`) is not granted, THEN THE Sidebar_Configuration SHALL omit that item from the returned clothing section while still returning all non-gated clothing items and the shared common sections.
6. WHEN `_getSectionsForBusiness` is called with any `BusinessType` other than `clothing`, THE Sidebar_Configuration SHALL return sections identical to those returned prior to the `case BusinessType.clothing` addition.

### Requirement 6: Phase 2 — Capability Mismatch and RBAC Bypass Closure

**User Story:** As a security owner, I want the variant-tracking capability mismatch resolved and the un-gated financial items gated, so that clothing features are reachable and sensitive items are not shown to every role.

#### Acceptance Criteria

1. THE Clothing_System SHALL render the variant-tracking surface within the dedicated clothing section of the Sidebar_Configuration, and SHALL NOT condition the visibility of that surface on the `useBatchExpiry` capability, such that the variant-tracking surface is visible to a clothing merchant even though clothing is not granted `useBatchExpiry`.
2. WHERE the retail sidebar surfaces the financial, compliance, and admin items `audit_trail`, `bank_accounts`, `accounting_reports`, the tax items (`gstr1`, `gstr2`, `gstr3b`, `gst_summary`), `expenses`, `credit_notes`, and `backup` to a clothing merchant, THE Clothing_System SHALL attach a `permission` tag to each such item so that `RolePermissions.hasPermission` evaluates it by role.
3. WHEN a permission-tagged item is resolved for a user that `RolePermissions.hasPermission` reports as lacking the item's required permission, THE Clothing_System SHALL exclude that item from the rendered clothing sidebar.
4. WHEN a permission-tagged item is resolved for a user that `RolePermissions.hasPermission` reports as holding the item's required permission, THE Clothing_System SHALL include that item in the rendered clothing sidebar.
5. WHEN the RBAC bypass closure is applied within the shared Sidebar_Configuration, THE Clothing_System SHALL make the change additively and SHALL NOT add, remove, reorder, or otherwise alter any rendered sidebar item for any business type other than `clothing`.
6. IF any of the financial, compliance, or admin items shown to clothing in criterion 2 remains without a `permission` tag, THEN THE Clothing_System SHALL treat the bypass closure as incomplete and SHALL emit a verification error that identifies each untagged item by its item key.

### Requirement 7: Phase 2 — Route Guard and Quick-Action Corrections

**User Story:** As a clothing merchant, I want the variant route guarded by the correct permission and the "Variants" quick action routed to the real variant matrix, so that access control is correct and the action lands on the right screen.

#### Acceptance Criteria

1. THE Clothing_System SHALL guard the `Variant_Management_Screen` route with a single inventory or product permission that governs variant management, and SHALL NOT use `Permissions.manageStaff` as the guard for that route.
2. WHEN a clothing vendor holding the corrected inventory permission navigates to the variant route, THE Clothing_System SHALL resolve the route to `Variant_Management_Screen` and display the variant matrix without redirecting to any other screen.
3. IF a user lacking the corrected inventory permission navigates to the variant route, THEN THE Clothing_System SHALL block access to `Variant_Management_Screen`, redirect the user to the application's default authorized landing screen, and present an indication that access was denied.
4. IF access to the variant route is blocked due to a missing permission, THEN THE Clothing_System SHALL retain no `Variant_Management_Screen` state and SHALL NOT instantiate or render the variant matrix.
5. WHEN a clothing merchant activates the "Variants" quick action, THE Quick_Actions SHALL navigate to the variant matrix screen (`Variant_Management_Screen`) and SHALL NOT navigate to `AppScreen.categories`.
6. WHILE Quick_Actions resolves actions for any business type other than `clothing`, THE Quick_Actions SHALL resolve each action to the identical destination it resolved to before this change.

### Requirement 8: Phase 3 — Critical Data-Loss and API Contract Fixes

**User Story:** As a clothing merchant, I want variant grid edits to save reliably and variant data to load without crashes, so that I never silently lose stock entries.

#### Acceptance Criteria

1. WHEN a clothing merchant edits the Variant_Grid_Widget and activates an explicit Save control, THE Clothing_System SHALL persist all edited quantities via `Variant_Repository.bulkUpdateVariants` scoped by Tenant_Id.
2. THE Clothing_System SHALL replace the empty `onQuantitiesChanged` callback in Variant_Management_Screen with a handler that routes edits to the save path defined in criterion 1.
3. THE Clothing_System SHALL resolve the `/clothing/variants/{id}` response-key mismatch by adopting a single contract so that `Clothing_Inventory_Screen` and `Variant_Repository` read the same key.
4. WHEN `VariantItem.fromJson` parses an API payload, THE Clothing_System SHALL cast each field through a null and type guard so that a null or mistyped optional field resolves to its defined default value, and a null or mistyped required field produces a descriptive parse error rather than an uncaught exception.
5. WHEN `_getFilteredVariants` resolves a product for a variant entry, THE Clothing_System SHALL look up the product via a `Map` index keyed by product id rather than via `firstWhere` without `orElse`, so that an unmatched product id does not throw a `StateError`.
6. WHEN a clothing merchant types in the variant search field, THE Clothing_System SHALL debounce the recompute so that the filtered list is rebuilt at most once per 300 milliseconds of input inactivity rather than on every keystroke.
7. THE Clothing_System SHALL replace the N+1 per-product variant fetch in `Clothing_Inventory_Screen._loadInventory` with a single batch endpoint call.
8. WHEN `Variant_Repository.bulkUpdateVariants` confirms that the edited quantities were persisted, THE Clothing_System SHALL present a visible success indicator within 2 seconds of the Save activation.
9. IF `Variant_Repository.bulkUpdateVariants` fails to persist the edited quantities, THEN THE Clothing_System SHALL present an error indication stating that the save did not complete and SHALL retain the merchant's edited quantities in the Variant_Grid_Widget without discarding them.

### Requirement 9: Phase 4 — Tailoring Module Wiring

**User Story:** As a clothing merchant, I want the tailoring measurements screen reachable and its inputs validated, so that I can capture alteration measurements tied to a customer and bill without losing data.

#### Acceptance Criteria

1. WHEN a clothing merchant activates the "Take Measurements" action from a bill or customer context, THE Clothing_System SHALL open `Tailoring_Measurements_Screen` constructed with the originating `customerId` and `invoiceId`.
2. THE Clothing_System SHALL register a navigation path to `Tailoring_Measurements_Screen` on the documented route surface selected in Requirement 4 that is reachable from the bill or customer context in a single activation of the "Take Measurements" action.
3. WHEN a measurement field value is entered or changed, THE Clothing_System SHALL validate the value against the `ClothingBusinessRules.isValidMeasurement` bounds rather than an inline `> 0` check.
4. WHEN `Tailoring_Measurements_Screen` saves a measurement, THE Clothing_System SHALL parse each field with `double.tryParse` and persist only the values that parse successfully and fall within the `ClothingBusinessRules.isValidMeasurement` bounds, associated with the originating `customerId` and `invoiceId`.
5. WHEN a clothing merchant deletes a measurement record, THE Clothing_System SHALL implement `_deleteMeasurements` as a soft-delete that sets a status flag rather than performing a silent no-op.
6. THE Clothing_System SHALL store the tailoring delivery date as a typed `DateTime` rather than as a split string.
7. IF the "Take Measurements" action is activated without a resolvable `customerId` or `invoiceId`, THEN THE Clothing_System SHALL not open `Tailoring_Measurements_Screen` and SHALL display an error indication identifying the missing originating context.
8. IF a measurement field fails `double.tryParse` or falls outside the `ClothingBusinessRules.isValidMeasurement` bounds when a save is attempted, THEN THE Clothing_System SHALL reject the save, retain all entered field values without clearing them, and display an error indication identifying the invalid field.

### Requirement 10: Phase 5 — GST Value-Slab Rule

**User Story:** As a clothing merchant, I want the apparel GST value slab applied automatically, so that bills are tax-accurate without manual rate edits.

#### Acceptance Criteria

1. WHEN a clothing line item's taxable value is greater than 0 Paise and strictly less than ₹1000 (100,000 Paise), THE Clothing_System SHALL apply a 5% GST rate.
2. WHEN a clothing line item's taxable value is greater than or equal to ₹1000 (100,000 Paise), THE Clothing_System SHALL apply a 12% GST rate.
3. WHERE a clothing merchant overrides the computed GST rate AND `gstEditable` is true, THE Clothing_System SHALL honor the manual override rather than re-applying the slab.
4. IF a clothing merchant attempts to override the computed GST rate WHILE `gstEditable` is false, THEN THE Clothing_System SHALL reject the override, retain the slab-computed rate, and surface an error indication that manual GST edits are disabled.
5. WHERE GST is computed under the slab rule, THE Clothing_System SHALL perform every intermediate and final money computation in integer Paise, rounding any fractional Paise result to the nearest whole Paise with halves rounded up.
6. IF a clothing line item's taxable value is 0 Paise or negative, THEN THE Clothing_System SHALL reject the line item, skip slab GST computation, and surface an error indication that taxable value must be greater than 0 Paise.
7. THE Clothing_System SHALL provide a calculation test asserting that a taxable value of exactly ₹1000 (100,000 Paise) selects the 12% rate and a taxable value of 99,999 Paise (one Paise below ₹1000) selects the 5% rate.

### Requirement 11: Phase 5 — Variant Model Unification and Exchange Flow

**User Story:** As a clothing merchant, I want a single variant model and a working size-swap exchange flow, so that variant data is consistent and customers can exchange sizes.

#### Acceptance Criteria

1. THE Clothing_System SHALL unify the divergent variant shapes into a single `Variant_Item` model carrying `sku` (a string of at most 64 characters), `barcode` (a string of at most 64 characters), `priceCents` as a non-negative integer in Paise, and `stock` as a non-negative integer, replacing the ad-hoc `Map<String,dynamic>` and the `quantity`/`priceAdjustment` double fields.
2. IF the unified `Variant_Item` model requires a DynamoDB model shape change, THEN THE Clothing_System SHALL halt and request a Mini_Gate, and SHALL NOT modify the model shape until the Mini_Gate is approved.
3. WHEN the Variant_Grid_Widget computes a cell key from color and size, THE Clothing_System SHALL produce a key such that any two distinct (color, size) pairs yield distinct keys, including pairs whose color or size value contains the `_` character (for example "Off_White").
4. THE Clothing_System SHALL grant the `useSalesReturn` Business_Capability to `BusinessType.clothing` and SHALL NOT grant it to any other business type.
5. WHEN a clothing merchant completes a size-swap exchange, THE Clothing_System SHALL, in a single atomic operation, increment the stock of the returned variant and decrement the stock of the issued variant.
6. IF the issued variant has insufficient stock for a size-swap exchange, THEN THE Clothing_System SHALL reject the exchange, leave the stock of both variants unchanged, and surface an error indication.
7. IF any step of the size-swap exchange fails after stock adjustment begins, THEN THE Clothing_System SHALL roll back all stock adjustments for that exchange so that no partial adjustment persists.
8. THE Clothing_System SHALL record explicit decisions on season/collection tracking, brand-wise stock reporting, and loyalty/bundle support as either in-scope items or deferred backlog items, each with a written rationale of at least one sentence.

### Requirement 12: Phase 6 — Offline-First, Sync, Printing, and Backend Confirmation

**User Story:** As a clothing merchant, I want clothing screens to work offline and to print variant tags, so that I can operate without continuous connectivity and label my stock.

#### Acceptance Criteria

1. THE Clothing_System SHALL route the three clothing screens (`Clothing_Inventory_Screen`, `Variant_Management_Screen`, `Tailoring_Measurements_Screen`) through an offline-first repository backed by a local store plus a sync queue, and SHALL NOT call `ApiClient` directly for create, read, update, or delete of clothing records.
2. WHEN a clothing merchant creates, updates, or deletes a clothing record while offline or online, THE Clothing_System SHALL persist the change to the local store within 1 second and enqueue exactly one corresponding sync-queue entry.
3. WHEN connectivity is restored, THE Clothing_System SHALL drain the sync queue in first-in-first-out order.
4. IF a sync-queue entry fails to sync, THEN THE Clothing_System SHALL retry it up to 5 times, retain the entry in the queue until it succeeds or the retry limit is reached, mark the entry as failed after the retry limit, and present a visible indication that unsynced changes exist.
5. THE Clothing_System SHALL verify and activate `Clothing_Sync_Handler` and `Clothing_Ws_Handler`, or remove them under the soft-delete and sign-off rules, based on the Phase 0 finding for their live behavior.
6. WHEN a clothing merchant prints a price tag or barcode for selected variants, THE Clothing_System SHALL render one tag per selected variant via the existing Print_Infrastructure.
7. IF a price-tag or barcode print fails, THEN THE Clothing_System SHALL present an error indication identifying the affected variant and SHALL leave the variant record unchanged.
8. THE Clothing_System SHALL surface an OCR scan-bill entry point for clothing, reachable within a single user interaction from `Clothing_Inventory_Screen`, using the granted `useScanOCR` capability.
9. IF a `/clothing/*` endpoint required by the offline-first sync path is absent, THEN THE Clothing_System SHALL confirm the endpoint with the backend or place the dependent feature behind a feature flag rather than failing sync silently.

### Requirement 13: Phase 7 — Performance Hardening Verification

**User Story:** As a clothing merchant, I want variant screens to stay responsive under load, so that large catalogs and wide size sets do not degrade the UI.

#### Acceptance Criteria

1. WHEN the variant inventory loads a dataset of at least 1,000 products with up to 20 variants each, THE Clothing_System SHALL retrieve all variant data using a fixed number of batch requests that does not increase with the product count, rather than one request per product, confirming the Requirement 8 batch-fetch fix under load.
2. WHEN a clothing merchant enters consecutive characters in the variant search field, THE Clothing_System SHALL apply the debounce from Requirement 8 so that the filtered-list recompute executes only after 300 milliseconds elapse with no further keystroke, rather than on every keystroke.
3. WHEN the variant grid is rendered at any desktop viewport width from 800 to 1280 pixels, THE Clothing_System SHALL reflow variant grid columns to the available width with a minimum column width of 120 pixels, such that no horizontal scrollbar appears for widths at or above 800 pixels.
4. WHEN the variant inventory described in criterion 1 completes loading, THE Clothing_System SHALL complete initial rendering of the variant grid within 3000 milliseconds measured from batch-request dispatch to first interactive render.
5. IF the batch fetch in criterion 1 fails or does not return within 10000 milliseconds, THEN THE Clothing_System SHALL present an error indication, SHALL NOT fall back to per-product requests, and SHALL leave any previously loaded variant data unchanged.

### Requirement 14: Phase 8 — UI Polish, Theming, and Accessibility

**User Story:** As a clothing merchant, I want theme-aware, accessible clothing screens with import/export and input bounds, so that the vertical is usable, consistent, and accessible.

#### Acceptance Criteria

1. THE Clothing_System SHALL replace the hardcoded colors (`#1A1A2E`, `#B8860B`, `grey[50]`) in the touched clothing screens with `Theme.of(context)` values such that zero hardcoded color literals remain in those screens and the screens render correctly in both light and dark themes.
2. WHERE a variant cell, scanner control, or measurement field conveys state, THE Clothing_System SHALL wrap the control in a `Semantics` widget exposing a label containing at least one non-whitespace character.
3. WHERE a clothing control is icon-only, THE Clothing_System SHALL provide a tooltip containing at least one non-whitespace character.
4. THE Clothing_System SHALL apply theme-derived color pairs intended to meet WCAG 2.1 Level AA contrast (at least 4.5:1 for normal text and at least 3:1 for large text), and SHALL document that full WCAG contrast conformance requires manual assistive-technology testing and expert review.
5. WHEN a clothing merchant triggers a variant export, THE Clothing_System SHALL produce a CSV export via `Variant_Repository.exportToCsv`.
6. WHEN a clothing merchant imports a CSV of variants, THE Clothing_System SHALL import the valid rows and present the count of imported rows.
7. IF an imported CSV is malformed or contains invalid rows, THEN THE Clothing_System SHALL reject the invalid rows, indicate which rows failed, and preserve the existing variant data.
8. WHEN money is displayed or stored by a touched clothing screen, THE Clothing_System SHALL represent the value as a non-negative integer in Paise within the range 0 to 9,999,999,999.
9. THE Clothing_System SHALL apply a per-product reorder level rather than a hardcoded low-stock threshold.
10. IF a variant quantity entry is negative or exceeds 999,999, THEN THE Clothing_System SHALL reject the entry, present an error indication, and preserve the prior value.

### Requirement 15: Phase 9 — Mandatory Regression Pass

**User Story:** As a maintainer, I want a mandatory regression pass on shared components and a navigation walk for clothing, so that no other vertical regresses and every clothing screen is reachable.

#### Acceptance Criteria

1. WHEN Phase 9 runs, THE Clothing_System SHALL compare the electronics, mobile, computer, hardware, grocery, and pharmacy verticals against a recorded pre-change baseline across four categories — sidebar sections, capability flags, quick-action set, and alert set — and SHALL pass only when zero items are added, removed, or reordered in any category for any of those verticals.
2. WHEN Phase 9 runs, THE Clothing_System SHALL perform a navigation graph walk for clothing that passes only when 100% of clothing sidebar items resolve to a registered screen with zero "Unknown Screen" placeholders.
3. IF the regression pass detects a behavioral change in any business type other than `clothing`, THEN THE Clothing_System SHALL halt for remediation before proceeding and SHALL present an indication identifying the affected vertical and the differing category.
4. IF the navigation graph walk finds a clothing sidebar item that does not resolve to a registered screen or resolves to an "Unknown Screen" placeholder, THEN THE Clothing_System SHALL halt for remediation before proceeding and SHALL present an indication identifying the unresolved item.
5. WHEN both the regression pass and the navigation walk complete, THE Clothing_System SHALL record as evidence the per-vertical outcome for each of the six verticals covered, the navigation-walk outcome, and the routes visited.

### Requirement 16: Phase 10 — Final Verification Matrix and Test Coverage

**User Story:** As a maintainer, I want a final verification matrix and required test coverage, so that every audit finding has a recorded disposition and the vertical ships verified.

#### Acceptance Criteria

1. THE Clothing_System SHALL produce a Verification_Matrix mapping every finding in `audit-clothing.md` to exactly one of FIXED, VERIFIED-OK, or DEFERRED-SIGNOFF, such that zero findings are unmapped and no finding carries more than one disposition.
2. WHERE a finding is marked DEFERRED-SIGNOFF, THE Verification_Matrix SHALL record the rationale and the named sign-off authority required to action it.
3. THE Clothing_System SHALL provide passing unit tests covering the GST slab rule (including the ₹1000 boundary), the variant model unification, and the cell-key collision fix (including the "Off_White" case).
4. THE Clothing_System SHALL provide passing widget tests covering the variant grid save path and the tailoring measurement validation against `ClothingBusinessRules.isValidMeasurement` bounds.
5. THE Clothing_System SHALL provide passing integration tests covering the offline-first variant load and sync path with one to three representative examples.
6. THE Clothing_System SHALL provide a manual smoke-test checklist covering the navigation path from the clothing sidebar to each clothing screen with no "Unknown Screen" placeholder.
7. WHEN all tests are run, THE Clothing_System SHALL confirm that the electronics, mobile, computer, hardware, grocery, and pharmacy verticals resolve unchanged sidebar, capability, quick-action, and alert behavior as a result of this remediation.
8. IF any required test fails, THEN THE Clothing_System SHALL halt and surface the failing tests before declaring the vertical shippable.
