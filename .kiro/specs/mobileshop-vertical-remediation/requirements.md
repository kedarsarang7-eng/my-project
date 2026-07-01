# Requirements Document

## Introduction

The DukanX `mobileShop` business vertical (`BusinessType.mobileShop`, "Mobile Phone Shop") is configured and capability-granted as a specialized device-retail vertical — IMEI required at sale, repairs/service jobs, exchange/buyback, warranty registration, and second-hand inventory — and a substantial real backend already exists under `features/service/*` (service jobs, exchanges, warranty claims, an `IMEISerial` model, an `IMEISerialRepository`, and an `IMEIValidationService`). An evidence-based audit (`audit-reports/business-types/audit-mobileShop.md`, sections 1–20) found that the **live wiring is broken or generic** despite this. The audit is the single source of truth for what is broken; this document translates its findings into testable requirements.

The most severe defects are data-integrity failures. The IMEI pipeline is a runtime no-op: `core/di/service_locator.dart` registers `BillsRepository` **without** injecting `imeiValidationService`, the field is nullable, so both guarded blocks (`validateBillItems` pre-save and `markIMEIsAsSold` post-save) are skipped — IMEI duplicate-prevention, auto-registration, and mark-as-sold never run, and the `IMEISerials` table can silently go unpopulated. A second, parallel IMEI check in `billing/services/billing_service.dart` gates on the string `'mobile_shop'`, which never matches the enum name `mobileShop`, so that branch is dead (and is only a comment anyway). The warranty end-date math in `markIMEIsAsSold` has a day-of-month overflow edge case. IMEI is never enforced as required at the UI layer (`manual_item_entry_sheet.dart` captures `serialNo` with no non-empty guard; `bill_line_item_row.dart` uses `hasField`, not `isRequired`), there is no Luhn checksum validation, and the duplicate-rejection logic — though present in `IMEISerialRepository.getByNumber` — is unreachable because the service is un-injected.

Beyond data integrity, the vertical renders the **generic retail sidebar** (`_getRetailSections`) with zero mobile-specific entries: the genuinely relevant `service_jobs`/`exchanges` (present in `_getServiceSections`) are withheld, while irrelevant retail clutter is shown. The built `WarrantyScreen`, `SerialHistoryScreen`, and `JobCardDetailScreen` live under `features/computer_shop/` and are `BusinessGuard`-restricted to `computerShop` only, so mobileShop is **blocked** from features it holds capabilities for (`useWarranty`, `useIMEI`, `useJobSheets`). The dashboard "IMEI Lookup" quick action is a dead `onTap: () {}`, and the alert cards show hardcoded literals (`'5'`, `'8'`, `'3'`) instead of the real counts that `ServiceJobService.getJobCounts` and `ExchangeService.getExchangeStats` already compute. Financial/compliance/admin sidebar items carry no `permission` tag (RBAC bypass), the `content_host` in-shell path bypasses the `VendorRoleGuard(manageStaff)` that wraps the equivalent named routes, second-hand intake does not exist despite the config declaring a `'second_hand'` module, the `IMEISerialStatus` enum lacks a `demo` state, and the two service screens read user identity from two divergent sources (`AuthService().currentUser` vs `FirebaseAuth.instance`).

This document specifies a phased, evidence-based remediation that makes the mobileShop vertical shippable end-to-end. Work proceeds strictly in phase order (Phase 0 through Phase 10). Phase 0 is read-only pre-flight verification that resolves every unverified audit item to CONFIRMED or FALSIFIED. Each subsequent phase ends with an explicit STOP GATE that requires human sign-off before the next begins. All work is bound by a set of non-negotiable cross-cutting constraints (multi-tenant scoping, integer-paise money, the RID id pattern, idempotent migrations, no hard deletes without sign-off, no schema changes without a mini-gate, and additive-only edits to shared components and the repositories/screens that electronics and computerShop share, with a regression pass).

The vertical is referred to throughout as the **MobileShop_System**, with sub-systems named for clarity. Requirements are grouped by the phase that delivers them and map back to the audit findings (cited by section, e.g., §7) and to the traceability matrix closed in Phase 10.

## Glossary

- **MobileShop_System**: The mobile-phone-shop business vertical of the DukanX Flutter app, encompassing its screens, repositories, models, services, providers, routes, capabilities, dashboard widgets, and sidebar configuration. Identified by `BusinessType.mobileShop`.
- **Sidebar_Configuration**: `lib/widgets/desktop/sidebar_configuration.dart` — defines `SidebarSection`/`SidebarMenuItem` lists per business type via `_getSectionsForBusiness`, and filters items through `sidebarSectionsProvider` by capability and permission. A shared component spanning 9+ verticals.
- **Sidebar_Navigation_Handler**: `lib/widgets/desktop/sidebar_navigation_handler.dart` — resolves a sidebar item id to a screen widget via `getScreenForItem`.
- **Content_Host**: `lib/widgets/desktop/content_host.dart` — the in-shell screen host whose `_buildScreen` calls `getScreenForItem(screen.id)` and renders the resulting widget directly, caching built screens in `_screenCache`.
- **App_Router**: `lib/app/routes.dart` `buildAppRoutes()` — the legacy `MaterialApp routes:` table that is the single source of truth for live named routes, including `/service_jobs`, `/exchanges`, `/job/create`, `/job/status`, `/job/deliver`, and the `/computer-shop/*` routes.
- **Mobile_Shop_Module**: `lib/modules/mobile_shop/mobile_shop_module.dart` — the parallel GoRouter module exposing `routes => mobileShopRoutes` and 6 `navItems` (Billing, Scan Bill, IMEI Track, Repair, Exchange, EMI), registered in `ModuleRegistry` but not mounted by the live app (which builds `MaterialApp(routes: buildAppRoutes())`).
- **Mobile_Shop_Routes**: `lib/modules/mobile_shop/routes/mobile_shop_routes.dart` — the GoRouter route list for the Mobile_Shop_Module, currently `LegacyRouteRedirect` stubs (`/mobile/billing`, `/mobile/imei`, `/mobile/repair`, `/mobile/exchange`, `/mobile/emi`).
- **Bills_Repository**: `lib/core/repository/bills_repository.dart` — the shared bill-persistence repository whose nullable `imeiValidationService` field gates the `validateBillItems` (pre-save) and `markIMEIsAsSold` (post-save) blocks. Shared by electronics, mobileShop, and computerShop.
- **Service_Locator**: `lib/core/di/service_locator.dart` — the dependency-injection registration site (lines ~435–448) where `BillsRepository` is constructed without `imeiValidationService:`.
- **IMEI_Validation_Service**: `lib/features/service/services/imei_validation_service.dart` — holds `validateBillItems`, `markIMEIsAsSold`, the required-IMEI check (`businessType.contains('mobile')`), and the `_guessIMEIType` length-15 heuristic. Currently never injected.
- **IMEI_Serial_Repository**: `IMEISerialRepository` — the repository providing `getByNumber` and status checks (sold/inService/damaged) that implement duplicate-sale prevention.
- **IMEI_Serial**: `IMEISerial` — the per-unit serial/IMEI model and its `IMEISerialStatus` enum (currently `inStock`, `sold`, `inService`, `returned`, `damaged`; no `demo` state).
- **Service_Job_Service**: `ServiceJobService` — the Drift-backed repair-job service providing `getJobCounts` (real status counts).
- **Exchange_Service**: `ExchangeService` — the Drift-backed exchange service providing `getExchangeStats` (real counts including `totalExchangeValue`).
- **Warranty_Claim_Service**: `WarrantyClaimService` — the full warranty-claim lifecycle service that already exists.
- **Service_Job_List_Screen**: `lib/features/service/presentation/screens/service_job_list_screen.dart` — the repair-job list; reads user id via `AuthService().currentUser?.uid`; status cards have empty `onTap`; search re-filters on every keystroke with no debounce.
- **Exchange_List_Screen**: `lib/features/service/presentation/screens/exchange_list_screen.dart` — the exchange list; reads user id via `FirebaseAuth.instance.currentUser?.uid`; shows a perpetual spinner with no error state when the user id is null.
- **Warranty_Screen**: `WarrantyScreen` (`features/computer_shop/...`) — warranty registration/claims UI; route `/computer-shop/warranty` is `BusinessGuard(allowedTypes:[computerShop])`.
- **Serial_History_Screen**: `SerialHistoryScreen` (`features/computer_shop/...`) — IMEI/serial history viewer; route `/computer-shop/serial-history` is `BusinessGuard(allowedTypes:[computerShop])`.
- **Job_Card_Detail_Screen**: `JobCardDetailScreen` (`features/computer_shop/...`) — job-card detail UI; route `/computer-shop/job-card/...` is `BusinessGuard(allowedTypes:[computerShop])`.
- **Multi_Unit_Screen**: `MultiUnitScreen` (`features/computer_shop/...`) — multi-unit UI; route `/computer-shop/multi-unit` is `BusinessGuard(allowedTypes:[computerShop])`; gated by `useMultiUnit`, which mobileShop does not hold.
- **Quick_Actions**: `lib/features/dashboard/v2/widgets/business_quick_actions.dart` — dashboard quick-action buttons resolved per `BusinessType`; the mobileShop branch includes a dead "IMEI Lookup" `onTap: () {}`. A shared component.
- **Alerts_Widget**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` — dashboard alert-count widget; the mobileShop branch emits hardcoded literals `'5'`, `'8'`, `'3'`. A shared component.
- **Alert_Counts_Provider**: `alertCountsProvider` / `fetchCounts()` — the live Drift-backed stream supplying real counts (used by the grocery dashboard case).
- **Business_Capability_File**: `lib/core/isolation/business_capability.dart` — the capability registry (key `'mobileShop'`); a shared component spanning 9+ verticals.
- **Feature_Resolver**: `lib/core/isolation/feature_resolver.dart` `canAccess()` — the strict-deny capability gate (default `false`) applied to `SidebarMenuItem`s before RBAC; `_normalizeType` maps `'mobileshop' → 'mobileShop'`.
- **Billing_Service**: `lib/features/billing/services/billing_service.dart` — contains an IMEI branch gated on `businessType == 'electronics' || businessType == 'mobile_shop'`; the `'mobile_shop'` literal never matches the enum name `mobileShop`.
- **Business_Type_Config**: `lib/core/billing/business_type_config.dart` — the mobileShop config block (requiredFields including `serialNo` (IMEI); `modules: ['inventory','sales','repairs','second_hand','reports']`; `ocrFocus = 'Name, Model, Serial/IMEI'`).
- **Vendor_Role_Guard**: `VendorRoleGuard` — the existing route wrapper enforcing vendor role and an optional required permission (e.g., `Permissions.manageStaff`).
- **Business_Guard**: `BusinessGuard` — the existing route wrapper restricting a route to specified `allowedTypes`.
- **RolePermissions**: The RBAC matrix (`RolePermissions.hasPermission(role, permission)`) evaluated by `sidebarSectionsProvider` for any item carrying a `permission` tag.
- **Device_Service_Capabilities**: The mobileShop capabilities `useIMEI`, `useWarranty`, `useBuyback`, `useExchange`, `useJobSheets`, `useRepairStatus` — granted but with no corresponding sidebar item.
- **Verification_Report**: A read-only Markdown artifact produced in Phase 0 documenting tenant-isolation reality, sync-handler liveness, submit-time IMEI enforcement, backup encryption, SIM/recharge absence, and the full RBAC matrix, containing zero code changes.
- **Traceability_Matrix**: The Phase 10 Markdown artifact mapping every audit finding (§1–§20) to exactly one of FIXED, VERIFIED-OK, or DEFERRED-SIGNOFF.
- **Tenant_Id**: The authenticated business/tenant identity resolved from the active session, used to scope all queries, writes, and sync calls; never hardcoded.
- **Paise**: Integer representation of currency (1 rupee = 100 paise). All money values in touched mobileShop code are integer paise.
- **RID**: The new-entity identifier pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
- **Shared_Components**: The cross-vertical files `sidebar_configuration.dart`, `business_alerts_widget.dart`, `business_quick_actions.dart`, `business_capability.dart`, `feature_resolver.dart`, `bills_repository.dart`, `service_locator.dart`, and the `/computer-shop/*` route registrations — each affecting business types other than mobileShop.
- **Shared_Device_Verticals**: The `electronics` and `computerShop` business types that share `Bills_Repository` and the `features/computer_shop/*` device-service screens with mobileShop.
- **Luhn_Check**: The Luhn checksum algorithm used to validate a 15-digit IMEI.
- **Stop_Gate**: A point at which MobileShop_System work for a phase stops and waits for explicit human approval before continuing. Emitted as the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and resumed only on the literal reply `APPROVED`.
- **Mini_Gate**: A separate, explicit sign-off required specifically before any DynamoDB schema/model shape change, Drift table change, or enum-shape change, accompanied by a proposed change and an idempotent migration plan.

## Requirements

### Requirement 1: Cross-Cutting Non-Negotiable Constraints

**User Story:** As the platform owner, I want every change in this remediation to honor the platform's multi-tenant, money, identity, and safety invariants, so that the MobileShop_System ships without introducing data leakage, currency errors, or destructive side effects.

#### Acceptance Criteria

1. WHERE money values are represented in code created or modified by this remediation, THE MobileShop_System SHALL store and compute currency as integer Paise.
2. THE MobileShop_System SHALL NOT introduce `double`, `float`, or decimal floating-point types for currency values in code created or modified by this remediation, and SHALL migrate any touched currency field to integer Paise.
3. WHEN the MobileShop_System creates a new entity identifier, THE MobileShop_System SHALL generate it using the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, where `tenantId` is the active Tenant_Id, `timestamp_ms` is the Unix epoch time in milliseconds, and `uuid_v4_short` is a shortened form of a UUID version 4 of at least 8 characters.
4. WHERE the MobileShop_System reads, writes, or synchronizes an `IMEISerial`, `ServiceJob`, `Exchange`, or `WarrantyClaim` record, THE MobileShop_System SHALL scope every query, repository call, and sync call by the Tenant_Id resolved from the authenticated session.
5. THE MobileShop_System SHALL NOT derive the Tenant_Id from a hardcoded value, a constant, or a value supplied by the client request body.
6. IF a change requires a DynamoDB schema or model shape change, a Drift table change, or an enum-shape change, THEN THE MobileShop_System SHALL halt and request a Mini_Gate, presenting the proposed change and an idempotent migration plan, before applying the change.
7. IF a change requires removing a record, file, route, or screen, THEN THE MobileShop_System SHALL use a soft-delete status flag or a flow requiring two distinct explicit user confirmations, and SHALL NOT perform a hard delete of data without explicit sign-off.
8. WHERE the MobileShop_System applies a data migration, THE MobileShop_System SHALL make the migration idempotent and re-runnable such that two or more consecutive executions over the same data produce the same persisted result and modify zero records after the first execution.
9. WHEN the MobileShop_System modifies a Shared_Component, THE MobileShop_System SHALL make additive edits only and SHALL preserve the behavior of every business type other than `mobileShop`, except where a shared repository or screen is intentionally widened to include `mobileShop` under Requirement 8.
10. THE MobileShop_System SHALL NOT modify the sidebar section function, capability set, quick actions, or alerts of any business type other than `mobileShop`.
11. WHEN the MobileShop_System completes an additive edit to a Shared_Component, THE MobileShop_System SHALL execute a regression pass that verifies each Shared_Device_Vertical and every other business type resolves behavior identical to the baseline behavior captured before the edit, and SHALL record a pass or fail result per business type.
12. WHEN the MobileShop_System completes an additive edit to a Shared_Component, THE MobileShop_System SHALL document the blast radius identifying the Shared_Components changed and the business types exercised.
13. IF the Tenant_Id is missing or cannot be resolved, THEN THE MobileShop_System SHALL reject the operation, perform no read or write, leave all persisted data unchanged, and return an error indicating the Tenant_Id is missing or unresolved.
14. WHEN a phase of this remediation is completed, THE MobileShop_System SHALL emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and SHALL perform no further phase work until the literal reply `APPROVED` is received.

### Requirement 2: Scope Boundary

**User Story:** As a maintainer, I want the remediation boundary fixed in advance, so that the work stays surgical and does not expand into out-of-scope rewrites or collateral damage to other verticals.

#### Acceptance Criteria

1. THE MobileShop_System SHALL restrict code changes to exactly these locations: files under `features/service/*`, files under `modules/mobile_shop/*`, the `mobileShop` case or key within Shared_Components, the dependency-injection registration of `Bills_Repository` in Service_Locator, the navigation entries (route registration and sidebar wiring) required to make mobileShop screens reachable, and the `Shared_Device_Verticals` repositories/screens only where omitting the change would cause an existing passing mobileShop or device-service test or screen to fail (regression prevention) or where the change is the minimum edit needed to extend an existing capability to include `mobileShop` (access widening).
2. THE MobileShop_System SHALL NOT modify the code, capability set, sidebar section, quick actions, or alerts of any business type other than `mobileShop`, except for the shared-repository and shared-screen widenings explicitly authorized in criterion 1.
3. THE MobileShop_System SHALL NOT perform an app-wide GoRouter migration as part of this remediation, and SHALL limit any router change to the navigation entries needed for mobileShop screen reachability as defined in criterion 1, where a screen is reachable when it has both a registered route and a sidebar entry that resolves to that route.
4. THE MobileShop_System SHALL NOT create any new backend endpoint, and SHALL only add or adjust an endpoint where it is required to satisfy an API contract already referenced by an existing mobileShop or device-service screen.
5. WHERE the EMI/finance feature is requested, THE MobileShop_System SHALL treat it as a deferred decision item, SHALL request explicit confirmation before performing any EMI code change, and SHALL leave all EMI-related files unmodified until that confirmation is received.
6. IF a proposed change falls outside the boundary defined in criterion 1, THEN THE MobileShop_System SHALL not apply the change, SHALL leave all existing files unmodified with no partial edits persisted, and SHALL surface a request for explicit sign-off that identifies the specific file path and the boundary clause the change violates before proceeding.
7. IF a single proposed change touches both an in-scope location and an out-of-scope location, THEN THE MobileShop_System SHALL apply only the in-scope portion, SHALL leave the out-of-scope location unmodified, and SHALL surface a request for explicit sign-off identifying the out-of-scope portion before applying it.

### Requirement 3: Phase 0 — Pre-Flight Read-Only Verification

**User Story:** As a maintainer, I want every unverified audit finding resolved to CONFIRMED or FALSIFIED before any code changes, so that subsequent phases act on confirmed facts rather than assumptions.

#### Acceptance Criteria

1. WHILE Phase 0 is in progress, THE MobileShop_System SHALL make zero code, configuration, or schema changes and SHALL produce only the Verification_Report.
2. THE Verification_Report SHALL record, for each mobileShop table and repository (`IMEISerial`, `ServiceJob`, `Exchange`, `WarrantyClaim`), whether every read and write is scoped by the Tenant_Id resolved from the authenticated session, citing the file and function checked.
3. THE Verification_Report SHALL record whether `MobileShopSyncHandler` and `MobileShopWsHandler` are active in the live app or inactive due to the unmounted Mobile_Shop_Module, citing the registration path checked.
4. THE Verification_Report SHALL record whether the bill submit path (`BillCreationScreenV2`) enforces IMEI as required at submit time for mobileShop, distinct from the manual-entry-sheet path.
5. THE Verification_Report SHALL record whether the `backup` flow encrypts its output, resolving the audit's "encryption unverified" item to CONFIRMED or FALSIFIED.
6. THE Verification_Report SHALL record whether any SIM-activation or recharge screen exists, resolving the audit's SIM/recharge item to CONFIRMED-absent or FALSIFIED.
7. THE Verification_Report SHALL record the full RolePermissions matrix as it applies to mobileShop sidebar items, identifying which sensitive items currently carry no `permission` tag.
8. THE Verification_Report SHALL resolve every previously unverified audit item to exactly one of CONFIRMED, FALSIFIED, or still-unverified, and SHALL state a one-sentence rationale for each still-unverified item.
9. IF Phase 0 verification falsifies a finding that a later phase depends on, THEN THE MobileShop_System SHALL record the discrepancy in the Verification_Report and SHALL halt before that dependent phase until the maintainer acknowledges the discrepancy.
10. IF a file, function, or registration path required to resolve an audit item cannot be located during verification, THEN THE MobileShop_System SHALL mark that item as still-unverified in the Verification_Report and SHALL state the missing source as its one-sentence rationale.
11. WHEN every previously unverified audit item has been resolved to CONFIRMED, FALSIFIED, CONFIRMED-absent, or still-unverified with a recorded rationale, THE MobileShop_System SHALL mark Phase 0 complete in the Verification_Report.

### Requirement 4: Phase 1 — IMEI Pipeline Dependency Injection and Data Integrity

**User Story:** As a mobile-shop merchant, I want every mobile sale to record its IMEI and mark it sold, so that I never lose per-unit tracking or warranty linkage and never bill a duplicate IMEI.

#### Acceptance Criteria

1. WHEN Service_Locator constructs Bills_Repository, THE MobileShop_System SHALL inject a non-null IMEI_Validation_Service instance so that `imeiValidationService` is non-null at runtime.
2. WHEN a mobileShop bill is saved through Bills_Repository, THE MobileShop_System SHALL invoke `validateBillItems` before persistence, SHALL proceed to persistence only when `validateBillItems` reports zero errors, and SHALL invoke `markIMEIsAsSold` after persistence.
3. WHEN a mobileShop bill containing an IMEI is persisted, THE MobileShop_System SHALL create or update the `IMEISerial` row whose IMEI value matches the billed IMEI scoped by Tenant_Id and SHALL set its status to `sold`.
4. WHEN `markIMEIsAsSold` computes a warranty end date from a sale date and a warranty-months count in the inclusive range 0 to 120, THE MobileShop_System SHALL compute a date exactly the specified number of months after the sale date, and IF the sale day-of-month exceeds the target month's last day THEN THE MobileShop_System SHALL clamp the warranty end date to the target month's last day rather than rolling into the following month.
5. THE MobileShop_System SHALL provide a calculation test asserting that a sale on the 31st with a warranty term landing in a 30-day month yields a warranty end date on the target month's last day, not the first day of the following month.
6. WHEN Bills_Repository persists a bill for `electronics` or `computerShop`, THE MobileShop_System SHALL persist the same field values it persisted before the IMEI_Validation_Service injection and SHALL NOT create or modify an `IMEISerial` row for a vertical that does not require IMEI.
7. THE MobileShop_System SHALL provide a regression test confirming that an `electronics` bill and a `computerShop` bill persist successfully after the IMEI_Validation_Service injection.
8. IF a mobileShop bill is submitted with an IMEI that is empty, malformed, or already recorded as `sold`, `inService`, or `damaged`, THEN THE MobileShop_System SHALL reject the submission before persistence, leave persisted data unchanged, and return an error identifying the offending IMEI.
9. IF `markIMEIsAsSold` fails after the bill is persisted, THEN THE MobileShop_System SHALL keep the bill persisted and SHALL return an error naming the IMEIs that were not marked sold.

### Requirement 5: Phase 2 — IMEI Enforcement and Validation

**User Story:** As a mobile-shop merchant, I want IMEI required, unique, and format-valid at the point of sale, so that bad or duplicate IMEIs cannot be saved.

#### Acceptance Criteria

1. IF a mobileShop bill or add-item entry is submitted with an empty serial/IMEI value, THEN THE MobileShop_System SHALL reject the submission, identify the offending line, retain the entered values, and present a required-field message.
2. THE MobileShop_System SHALL evaluate the IMEI requirement using `config.isRequired(ItemField.serialNo)` rather than `hasField`.
3. IF a mobileShop bill is submitted with an IMEI whose existing `IMEISerial` status is `sold`, `inService`, or `damaged`, THEN THE MobileShop_System SHALL reject the submission as a duplicate and present a message identifying the duplicate IMEI value and its conflicting status.
4. WHEN a 15-digit IMEI value is submitted, THE MobileShop_System SHALL accept it only if it passes the Luhn_Check, and IF it fails the Luhn_Check THEN THE MobileShop_System SHALL reject it with a format error.
5. IF a non-empty serial/IMEI value is submitted that is not exactly 15 numeric digits, THEN THE MobileShop_System SHALL treat it as a generic serial rather than a validated IMEI and SHALL NOT apply the Luhn_Check to it.
6. THE MobileShop_System SHALL provide a validation test asserting that a Luhn-valid 15-digit IMEI is accepted and a Luhn-invalid 15-digit IMEI is rejected.
7. WHEN Billing_Service evaluates its IMEI branch, THE MobileShop_System SHALL match the mobileShop business type using `BusinessType.mobileShop.name` rather than the literal string `'mobile_shop'`.
8. WHERE a warranty-months value is entered, THE MobileShop_System SHALL accept it only when it is an integer in the inclusive range 0 to 120, and IF the value is non-integer, negative, or greater than 120 THEN THE MobileShop_System SHALL reject it with an error indication.
9. WHEN duplicate-IMEI rejection occurs at the UI layer, THE MobileShop_System SHALL prevent the duplicate from being added to the bill before persistence is attempted.

### Requirement 6: Phase 3 — Unblock Guarded Device-Service Screens for mobileShop

**User Story:** As a mobile-shop merchant, I want the warranty, serial-history, and job-card screens reachable, so that I can use the features my vertical already holds capabilities for.

#### Acceptance Criteria

1. WHEN a `mobileShop` session holding `useWarranty` navigates to Warranty_Screen, THE MobileShop_System SHALL render the screen rather than a Business_Guard denial.
2. WHEN a `mobileShop` session holding `useIMEI` navigates to Serial_History_Screen, THE MobileShop_System SHALL render the screen rather than a Business_Guard denial.
3. WHEN a `mobileShop` session holding `useJobSheets` navigates to Job_Card_Detail_Screen, THE MobileShop_System SHALL render the screen rather than a Business_Guard denial.
4. WHERE access to Warranty_Screen, Serial_History_Screen, and Job_Card_Detail_Screen is granted, THE MobileShop_System SHALL gate that access via Feature_Resolver by the matching capability (`useWarranty`, `useIMEI`, `useJobSheets` respectively) evaluated before the screen renders.
5. THE MobileShop_System SHALL record a decision on whether the three screens are moved to a shared device-service location or the existing guards are widened, with a written rationale of at least one complete sentence.
6. IF a business type that holds neither `useWarranty`, `useIMEI`, nor `useJobSheets` and is not in the widened allow-list navigates to these screens, THEN THE MobileShop_System SHALL deny access, SHALL NOT render the screen, and SHALL present a message naming the required capability or allowed business types.
7. THE MobileShop_System SHALL keep Multi_Unit_Screen restricted to `computerShop` and SHALL NOT grant `useMultiUnit` to mobileShop.
8. IF access to a device-service screen is denied, THEN THE MobileShop_System SHALL NOT display a message that names only "Computer Shop" for a screen that mobileShop is now permitted to use.
9. IF a `mobileShop` session that lacks the specific capability required for a requested device-service screen navigates to that screen, THEN THE MobileShop_System SHALL deny access, SHALL NOT render the screen, and SHALL name the required capability.

### Requirement 7: Phase 4 — Sidebar, Navigation, and RBAC Wiring

**User Story:** As a mobile-shop merchant, I want a dedicated sidebar with my repair, exchange, IMEI, warranty, and second-hand tools, so that I can reach every mobile feature from normal navigation with correct access control.

#### Acceptance Criteria

1. WHEN `_getSectionsForBusiness` is called with `BusinessType.mobileShop`, THE Sidebar_Configuration SHALL return a dedicated mobileShop section set containing exactly the following five entries — Service Jobs, Exchanges, IMEI Tracking, Warranty, and Second-Hand Intake — and SHALL NOT fall through to the generic retail sections.
2. WHERE each mobileShop sidebar item is defined, THE Sidebar_Configuration SHALL tag it with its matching capability (`useJobSheets`, `useExchange`, `useIMEI`, `useWarranty`, `useBuyback` as applicable), and SHALL exclude from the returned set any item whose capability the session does not hold.
3. WHEN a mobileShop merchant selects the job-create, job-status, or job-deliver navigation entry, THE MobileShop_System SHALL navigate to the corresponding service-job destination and render it without a navigation error.
4. WHERE financial, compliance, or admin retail items remain visible to mobileShop, THE Sidebar_Configuration SHALL attach a `permission` tag to each such sensitive item so that RolePermissions gates it.
5. IF a merchant whose role lacks the permission tagged on a sidebar item attempts to open that item, THEN THE MobileShop_System SHALL block access, present an access-denied indication, and preserve the current screen state.
6. WHEN a repair or exchange screen is rendered through the Content_Host in-shell path, THE MobileShop_System SHALL enforce the same permission required by the equivalent named route, and IF the required permission is absent THEN THE MobileShop_System SHALL deny rendering, closing the Content_Host guard bypass.
7. THE MobileShop_System SHALL record, in a durable decision artifact, a decision on whether `manageStaff` remains the gating permission for repair/exchange operations or is replaced by an operations/invoice permission, with a rationale of at least one complete sentence.
8. THE MobileShop_System SHALL exclude from the mobileShop sidebar the unsupported retail items whose capabilities mobileShop does not hold (for example `proforma_bids`, `dispatch_notes`, `return_inwards`), enforced either by capability tag or by omission from the dedicated section.
9. THE MobileShop_System SHALL record, in a durable decision artifact, a decision on whether the orphaned GoRouter Mobile_Shop_Module and Mobile_Shop_Routes are deleted (under the soft-delete/sign-off rule) or retained, with a rationale of at least one complete sentence.
10. WHEN `_getSectionsForBusiness` is called with any `BusinessType` other than `mobileShop`, THE Sidebar_Configuration SHALL return sections byte-for-byte identical to those returned prior to the mobileShop changes.

### Requirement 8: Phase 5 — Dashboard and KPI Real-Data Wiring

**User Story:** As a mobile-shop merchant, I want the dashboard to show live repair, exchange, IMEI, and warranty numbers, so that the KPIs I see match the real data inside the screens.

#### Acceptance Criteria

1. WHEN the mobileShop dashboard "IMEI Lookup" quick action is activated, THE MobileShop_System SHALL navigate to the Serial_History_Screen rather than executing an empty handler.
2. WHEN the mobileShop dashboard is opened or refreshed, THE Alerts_Widget SHALL render mobileShop alert counts from live data sources (`Service_Job_Service.getJobCounts`, `Exchange_Service.getExchangeStats`, and Alert_Counts_Provider) rather than the hardcoded literals `'5'`, `'8'`, and `'3'`.
3. WHEN the mobileShop dashboard is opened or refreshed, THE MobileShop_System SHALL display exactly four KPI cards — active repairs by job status (from `Service_Job_Service.getJobCounts`), exchange pipeline value (from `Exchange_Service.getExchangeStats`), IMEI in-stock versus sold count, and open warranty claim count — each sourced from its live data source.
4. WHILE a KPI data source is loading, THE MobileShop_System SHALL display a loading state for the affected card and SHALL resolve that card to a value, an empty state, or an error state within 10 seconds.
5. IF a KPI data source returns zero records, THEN THE MobileShop_System SHALL display a zero value with an empty-state label for the affected card rather than a hardcoded count.
6. IF a KPI data source fails to load or does not resolve within 10 seconds, THEN THE MobileShop_System SHALL display an error state with a retry affordance for the affected card and SHALL NOT display a stale or hardcoded count.
7. WHEN the Alerts_Widget or Quick_Actions resolves for any business type other than `mobileShop`, THE MobileShop_System SHALL resolve the identical content and destinations it resolved before this change.

### Requirement 9: Phase 6 — Second-Hand Intake, Demo Status, and EMI Decision

**User Story:** As a mobile-shop merchant, I want to intake and value used phones and track demo units, so that my second-hand inventory is a real, tracked part of the system.

#### Acceptance Criteria

1. WHEN a second-hand/used-phone intake is submitted, THE MobileShop_System SHALL capture device identity, a condition from a predefined finite set, and a grade from a predefined finite set, scoped by Tenant_Id.
2. IF a second-hand intake is submitted with a missing required field or a condition or grade outside its predefined set, THEN THE MobileShop_System SHALL reject the submission, create no record, and return an error identifying the offending field.
3. WHEN a used phone is intaken, THE MobileShop_System SHALL record its valuation as an integer number of Paise greater than 0 and no greater than 99,999,999,999, and SHALL generate its identifier using the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
4. WHERE the `IMEISerial` model is extended for second-hand intake, THE MobileShop_System SHALL add condition and grade fields and SHALL request a Mini_Gate before applying the model-shape change.
5. WHERE a `demo` state is added to `IMEISerialStatus`, THE MobileShop_System SHALL request a Mini_Gate before applying the enum-shape change and SHALL provide a migration plan that, when re-run on already-migrated rows, produces no additional changes.
6. IF a Mini_Gate for a model-shape or enum-shape change is not granted, THEN THE MobileShop_System SHALL apply no schema change and SHALL leave the existing model and enum definitions unchanged.
7. WHEN an `IMEISerial` carries the `demo` status, THE MobileShop_System SHALL exclude that unit from sellable stock counts while keeping it visible in IMEI tracking.
8. WHEN an `IMEISerial` transitions out of the `demo` status to a sellable status, THE MobileShop_System SHALL re-include that unit in sellable stock counts.
9. THE MobileShop_System SHALL record an explicit decision on EMI/finance scope as either an in-scope item or a deferred backlog item, with a written rationale of at least one sentence, and SHALL NOT implement EMI code without the confirmation required by Requirement 2 criterion 5.

### Requirement 10: Phase 7 — Security Hardening

**User Story:** As a security owner, I want consistent identity, a defined null-session state, and confirmed tenant isolation, so that the service screens are safe and predictable.

#### Acceptance Criteria

1. WHEN Service_Job_List_Screen or Exchange_List_Screen loads, THE MobileShop_System SHALL resolve the authenticated user identity from a single identity source shared by both screens, such that both screens return the same User_Id and Tenant_Id for the same active session.
2. IF the authenticated session or user identity is null when Service_Job_List_Screen or Exchange_List_Screen loads, THEN THE MobileShop_System SHALL display an error state that includes a message indicating the session is invalid or expired and SHALL stop showing the loading indicator.
3. IF the authenticated session or user identity has not resolved within 10 seconds of Service_Job_List_Screen or Exchange_List_Screen beginning to load, THEN THE MobileShop_System SHALL replace the loading indicator with an error state that includes a message indicating the session could not be resolved.
4. WHEN any tenant-isolation leak identified in Phase 0 affects an `IMEISerial`, `ServiceJob`, `Exchange`, or `WarrantyClaim` read or write, THE MobileShop_System SHALL scope that operation by the session Tenant_Id so that the operation accesses only records whose Tenant_Id equals the session Tenant_Id.
5. THE MobileShop_System SHALL provide, for each of `IMEISerial`, `ServiceJob`, `Exchange`, and `WarrantyClaim`, a passing automated test asserting that a query issued under one Tenant_Id returns zero records belonging to any other Tenant_Id.

### Requirement 11: Phase 8 — Capability Alignment

**User Story:** As a maintainer, I want the OCR and sales-return capability decisions resolved, so that the mobileShop capability set matches the vertical's real behavior.

#### Acceptance Criteria

1. THE MobileShop_System SHALL record a documented decision on `useScanOCR` for mobileShop that resolves to exactly one of two outcomes — granting the capability (aligning with electronics) or removing the `ocrFocus` value — accompanied by a written rationale of at least one complete sentence (minimum 1 sentence, minimum 10 words).
2. WHERE `useScanOCR` is denied for mobileShop, THE MobileShop_System SHALL NOT expose any `ocrFocus` value or any UI element, label, or configuration entry that implies an OCR feature exists for mobileShop.
3. THE MobileShop_System SHALL record a documented decision on `useSalesReturn` for mobileShop that resolves to exactly one of two outcomes — granting an IMEI-aware return flow or remaining without sales-return — accompanied by a written rationale of at least one complete sentence (minimum 1 sentence, minimum 10 words).
4. WHERE an IMEI-aware return flow is provided, WHEN a return is confirmed for an `IMEISerial` whose status is `sold` within the requesting Tenant_Id, THE MobileShop_System SHALL revert that `IMEISerial` status from `sold` to a returnable state, scoped to the requesting Tenant_Id only.
5. WHERE an IMEI-aware return flow is provided, IF a return is requested for an `IMEISerial` that does not exist within the requesting Tenant_Id or whose status is not `sold`, THEN THE MobileShop_System SHALL reject the return, leave the `IMEISerial` status unchanged, and return an error indication identifying the reason for rejection.
6. WHERE an IMEI-aware return flow is provided, THE MobileShop_System SHALL NOT modify the status of any `IMEISerial` belonging to a different Tenant_Id than the requesting tenant.

### Requirement 12: Phase 9 — UX, Performance, and Accessibility

**User Story:** As a mobile-shop merchant, I want responsive, consistent, accessible service screens, so that the vertical is usable and meets accessibility expectations.

#### Acceptance Criteria

1. WHEN a merchant types in the Service_Job_List_Screen or Exchange_List_Screen search field, THE MobileShop_System SHALL apply the search filter only after 300 milliseconds elapse with no further keystroke, so that filtering is not recomputed on every individual keystroke.
2. WHEN the search field in the Service_Job_List_Screen or Exchange_List_Screen is cleared, THE MobileShop_System SHALL display the full unfiltered list within 300 milliseconds.
3. THE MobileShop_System SHALL render the Service_Job_List_Screen and Exchange_List_Screen using an identical header structure and layout pattern, defined as the same header component, the same title placement, and the same primary-action positioning on both screens.
4. THE MobileShop_System SHALL replace all hardcoded color literals in the touched service screens with theme tokens, such that no hardcoded color literal remains in those screens.
5. THE MobileShop_System SHALL provide a non-empty `Semantics` label and a tooltip for every custom tap target in the touched service screens, including any previously action-less status cards.
6. THE MobileShop_System SHALL record the result of a color-contrast verification for text and interactive elements in the touched service screens, evaluated against the WCAG 2.1 AA contrast ratios (at least 4.5:1 for normal text and at least 3:1 for large text), noting that full WCAG validation requires manual testing with assistive technology.

### Requirement 13: Phase 10 — Regression, Multi-Tenant Isolation, and Traceability Closure

**User Story:** As a maintainer, I want a final regression, isolation, RBAC, and offline pass with full audit traceability, so that the vertical ships verified and no other vertical regresses.

#### Acceptance Criteria

1. WHEN Phase 10 runs the regression pass, THE MobileShop_System SHALL verify that each Shared_Device_Vertical and every other business type resolves sidebar, capability, quick-action, and alert behavior that exactly matches a baseline recorded before Phase 10, and SHALL record a PASS or FAIL result per business type.
2. IF the regression pass detects any element differing from the recorded baseline for a business type other than `mobileShop`, THEN THE MobileShop_System SHALL list each differing element and SHALL withhold final sign-off until the difference is resolved.
3. WHEN Phase 10 runs the multi-tenant isolation test using at least two distinct Tenant_Id values, THE MobileShop_System SHALL confirm that `IMEISerial`, `ServiceJob`, `Exchange`, and `WarrantyClaim` reads and writes return no records belonging to another Tenant_Id.
4. IF the isolation test detects any cross-Tenant_Id access for `IMEISerial`, `ServiceJob`, `Exchange`, or `WarrantyClaim`, THEN THE MobileShop_System SHALL record the leak and SHALL withhold final sign-off until it is resolved.
5. WHEN Phase 10 runs the offline-mode test with connectivity disabled, THE MobileShop_System SHALL confirm that repair and exchange reads and writes operate against the local database and SHALL confirm that IMEI rows are persisted locally.
6. WHEN Phase 10 runs the RBAC test, THE MobileShop_System SHALL confirm that each permission-tagged sidebar item is hidden for roles lacking the permission and shown for roles holding it, and SHALL record a PASS or FAIL result per item.
7. WHEN Phase 10 completes, THE Traceability_Matrix SHALL map every audit finding from sections 1 through 20 to exactly one of FIXED, VERIFIED-OK, or DEFERRED-SIGNOFF.
8. IF any audit finding remains unmapped, carries more than one disposition, or remains unresolved at Phase 10 completion, THEN THE MobileShop_System SHALL list each such finding and SHALL withhold final sign-off until every finding has exactly one recorded disposition.
