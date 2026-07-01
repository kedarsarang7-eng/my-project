# Implementation Plan — Mobile Phone Shop Vertical Remediation

## Overview

Phased, evidence-based implementation plan that makes the DukanX `mobileShop` vertical
(`BusinessType.mobileShop`, "Mobile Phone Shop") shippable end-to-end. Work proceeds strictly
in phase order (Phase 0 → Phase 10). Each phase ends with a STOP GATE: list every file
created/modified/deleted, run `flutter analyze` on touched files, emit the literal text
`PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for the literal reply `APPROVED`.
Do NOT auto-continue to the next phase. Any DynamoDB model-shape, Drift table, or enum-shape
change requires a Mini_Gate (proposed change + idempotent migration plan) before applying; any
deletion of a record/file/route/screen uses a soft-delete status flag or a two-confirmation
flow — no hard deletes.

The language is Dart/Flutter for the app and Node.js for any backend endpoint, consistent with
the existing codebase (the design specifies concrete Dart signatures — `warrantyEndDate`,
`isValidLuhn15`, the RID generator — so no language choice is required).

All new code follows the non-negotiable cross-cutting constraints (Requirement 1) and the scope
boundary (Requirement 2): integer-Paise money (never `double`/`float`/decimal for currency), RID
id pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, tenant scoping on every query/write/sync
(unresolved tenant aborts the operation), idempotent migrations, and surgical/additive edits to
Shared_Components (`service_locator.dart`, `bills_repository.dart`, `billing_service.dart`,
`sidebar_configuration.dart`, `business_quick_actions.dart`, `business_alerts_widget.dart`,
`business_capability.dart`, `feature_resolver.dart`, the `/computer-shop/*` route registrations)
— no other business type's sidebar, capability, quick-action, or alert resolution changes, except
the explicitly authorized device-service guard widenings, with a documented blast radius and a
per-vertical regression result on every shared-file edit. Changes are restricted to the allowed
locations: `features/service/*`, `modules/mobile_shop/*`, the `mobileShop` case/key within
Shared_Components, the `Bills_Repository` DI registration, the navigation entries needed for
reachability, and the Shared_Device_Verticals repositories/screens only for regression prevention
or the minimum access-widening edit. No app-wide GoRouter migration; no new backend endpoint
beyond an existing contract; EMI/finance is a deferred decision left unmodified pending explicit
confirmation.

## Tasks

> **Phased STOP-GATE protocol.** After every phase: (a) list files created/modified/deleted,
> (b) run `flutter analyze` on touched files and report results, (c) output exactly
> `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Sub-tasks marked with
> `*` are optional tests and are not auto-implemented. Property tests reference the design's
> Correctness Properties by number, run a minimum of 100 iterations against an in-memory/mocked
> Drift store, and are tagged `Feature: mobileshop-vertical-remediation, Property {n}: {text}`.

- [x] 1. Phase 0 — Read-only verification (Requirement 3)

  - [x] 1.1 Produce the read-only Verification_Report
    - Create `.kiro/specs/mobileshop-vertical-remediation/phase0-verification-report.md` and create/modify/delete zero other files; touch no application source, configuration, or build file
    - For each of `IMEISerial`, `ServiceJob`, `Exchange`, `WarrantyClaim`, record whether every read and write is scoped by the session Tenant_Id, citing the file + function checked
    - Record whether `MobileShopSyncHandler` and `MobileShopWsHandler` are active in the live app or inactive due to the unmounted Mobile_Shop_Module, citing the registration path
    - Record whether `BillCreationScreenV2` enforces IMEI as required at submit time, distinct from the manual-entry-sheet path
    - Record whether the `backup` flow encrypts its output, resolving the audit's "encryption unverified" item to CONFIRMED or FALSIFIED
    - Record whether any SIM-activation or recharge screen exists, resolving the SIM/recharge item to CONFIRMED-absent or FALSIFIED
    - Record the full RolePermissions matrix as applied to mobileShop sidebar items, identifying which sensitive items carry no `permission` tag
    - Resolve every previously unverified audit item to exactly one of CONFIRMED / FALSIFIED / CONFIRMED-absent / still-unverified with a one-sentence rationale; a missing source forces still-unverified naming the missing path
    - If a falsified finding is depended on by a later phase, record the discrepancy and halt before that phase until acknowledged; mark Phase 0 complete only when every item is resolved
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11_

- [x] 2. Checkpoint — Phase 0
  - List files created/modified/deleted (Verification_Report only), confirm zero non-report files changed, output `PHASE 0 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 3. Phase 1 — IMEI pipeline DI and data integrity (Requirement 4)

  - [x] 3.1 Inject IMEI_Validation_Service into Bills_Repository
    - In `lib/core/di/service_locator.dart`, construct `BillsRepository(... imeiValidationService: IMEIValidationService(sl<AppDatabase>()) ...)` so `imeiValidationService` is non-null at runtime — the single change that activates the pipeline
    - Make the edit additive only; document the Shared_Component blast radius (`service_locator.dart`, `bills_repository.dart`) and the business types exercised (mobileShop, electronics, computerShop)
    - _Requirements: 4.1, 1.9, 1.12_

  - [x] 3.2 Verify validate → persist → mark ordering and tenant-scoped IMEISerial upsert
    - With the field non-null, confirm the pre-save `validateBillItems` block (bills_repository ~line 229) runs before persistence and proceeds only on zero errors, and the post-save `markIMEIsAsSold` block (~line 476) runs after persistence
    - On a persisted mobileShop bill containing an IMEI, create/update the matching `IMEISerial` row scoped by session Tenant_Id with status `sold`; an unresolved Tenant_Id aborts before any read/write and returns a tenant-missing error
    - On a `markIMEIsAsSold` failure after persistence, keep the bill persisted and return an error naming the IMEIs not marked sold
    - _Requirements: 4.2, 4.3, 4.9, 1.4, 1.5, 1.13_

  - [x] 3.3 Implement the clamping warranty-end-date helper
    - Replace the naive `DateTime(now.year, now.month + warrantyMonths, now.day)` in `markIMEIsAsSold` with the pure `warrantyEndDate(saleDate, warrantyMonths)` helper that, for a warranty-months count in the inclusive range 0–120, computes the target year/month and clamps the day to `min(saleDay, lastDayOfTargetMonth)` rather than rolling into the following month
    - _Requirements: 4.4_

  - [x] 3.4 Preserve shared-vertical bill persistence
    - Confirm `electronics` and `computerShop` bills persist the same field values as before the injection and that no `IMEISerial` row is created/modified for a vertical that does not require IMEI (the required-IMEI check is keyed on the mobile business type)
    - _Requirements: 4.6_

  - [ ]* 3.5 Write property test for sale recording and IMEISerial marking
    - **Property 5: Sale records and marks the IMEISerial**
    - **Validates: Requirements 4.2, 4.3**

  - [ ]* 3.6 Write property test for the warranty-date clamp
    - **Property 6: Warranty end date is months-after with last-day clamp**
    - **Validates: Requirements 4.4, 4.5**

  - [ ]* 3.7 Write property test for unresolved-tenant abort
    - **Property 3: Unresolved tenant aborts with no side effects**
    - **Validates: Requirements 1.13**

  - [ ]* 3.8 Write property test for shared-vertical preservation
    - **Property 11: Shared device verticals persist unchanged**
    - **Validates: Requirements 4.6**

  - [ ]* 3.9 Write example/regression tests for DI, ordering, the 31st-into-30-day case, and shared bills
    - Assert `imeiValidationService` resolves non-null; assert the validate-then-persist-then-mark order and the post-persist mark-failure path; assert a sale on the 31st with a term landing in a 30-day month yields the target month's last day, not the 1st of the following month; assert an electronics bill and a computerShop bill persist successfully after the injection
    - _Requirements: 4.1, 4.5, 4.7, 4.8, 4.9_

- [x] 4. Checkpoint — Phase 1
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 1 tests pass, document the Shared_Component blast radius and per-vertical regression result, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 5. Phase 2 — IMEI enforcement and validation (Requirement 5)

  - [x] 5.1 Enforce IMEI as a required field at the UI layer
    - In `manual_item_entry_sheet.dart` add a non-empty guard on the serial/IMEI field; in `bill_line_item_row.dart` evaluate `config.isRequired(ItemField.serialNo)` rather than `hasField`
    - On an empty submission, reject it, identify the offending line, retain entered values, and present a required-field message
    - _Requirements: 5.1, 5.2_

  - [x] 5.2 Reject duplicate IMEIs at the UI layer before persistence
    - Before the bill is added/persisted, reject an IMEI whose existing `IMEISerial` status is `sold`/`inService`/`damaged` with a message naming the IMEI and its conflicting status, preventing it from being added to the bill
    - _Requirements: 5.3, 5.9_

  - [x] 5.3 Implement the Luhn_Check and 15-digit classification
    - Add the pure `isValidLuhn15(imei)` helper; accept a non-empty value that is exactly 15 numeric digits only if it passes Luhn, rejecting a 15-digit value failing Luhn with a format error; treat a non-empty value that is not exactly 15 numeric digits as a generic serial and do NOT apply the Luhn check (extend, do not replace, the existing `_guessIMEIType` length-15 heuristic)
    - _Requirements: 5.4, 5.5, 5.6_

  - [x] 5.4 Fix the Billing_Service enum match
    - In `billing/services/billing_service.dart`, match the mobileShop type using `BusinessType.mobileShop.name` instead of the literal `'mobile_shop'`, reviving the dead branch
    - _Requirements: 5.7_

  - [x] 5.5 Enforce the warranty-months range
    - Accept a warranty-months value only when it is an integer in the inclusive range 0–120; reject a non-integer, negative, or >120 value with an error indication
    - _Requirements: 5.8_

  - [ ]* 5.6 Write property test for invalid/duplicate IMEI rejection
    - **Property 7: Invalid or duplicate IMEIs are rejected before persistence**
    - **Validates: Requirements 4.8, 5.1, 5.3, 5.9**

  - [ ]* 5.7 Write property test for Luhn validation
    - **Property 8: Luhn validation of 15-digit IMEIs**
    - **Validates: Requirements 5.4, 5.6**

  - [ ]* 5.8 Write property test for non-15-digit generic serials
    - **Property 9: Non-15-digit values are generic serials**
    - **Validates: Requirements 5.5**

  - [ ]* 5.9 Write property test for warranty-months range validation
    - **Property 10: Warranty-months range validation**
    - **Validates: Requirements 5.8**

  - [ ]* 5.10 Write example tests for the Luhn examples and the enum-match fix
    - Assert a Luhn-valid 15-digit IMEI is accepted and a Luhn-invalid one rejected; assert `billing_service.dart` matches `BusinessType.mobileShop.name`
    - _Requirements: 5.6, 5.7_

- [x] 6. Checkpoint — Phase 2
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 2 tests pass, output `PHASE 2 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 7. Phase 3 — Unblock guarded device-service screens (Requirement 6)

  - [x] 7.1 Record the widen-vs-relocate decision
    - Record a durable decision artifact choosing to widen the existing `BusinessGuard` allow-lists (over relocating the screens), with a rationale of at least one complete sentence (minimum, reversible, additive edit satisfying the scope boundary)
    - _Requirements: 6.5_

  - [x] 7.2 Widen the device-service route guards to include mobileShop
    - In the `/computer-shop/warranty`, `/computer-shop/serial-history`, and `/computer-shop/job-card/*` route registrations, add `BusinessType.mobileShop` to each `BusinessGuard` allow-list as an additive edit; leave `/computer-shop/multi-unit` restricted to `computerShop` and do not grant `useMultiUnit` to mobileShop
    - _Requirements: 6.7_

  - [x] 7.3 Gate each widened screen through Feature_Resolver by its matching capability
    - Gate access through `Feature_Resolver.canAccess` evaluated before render — `useWarranty` for Warranty_Screen, `useIMEI` for Serial_History_Screen, `useJobSheets` for Job_Card_Detail_Screen; a mobileShop session holding the capability renders the screen, one lacking it is denied, the screen is not rendered, and the required capability is named
    - A business type holding none of the three and not in the widened allow-list is denied with a message naming the required capability or allowed business types; the denial must not name only "Computer Shop" for a screen mobileShop may now use
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6, 6.8, 6.9_

  - [ ]* 7.4 Write property test for capability gating of device-service screens
    - **Property 12: Capability gating of device-service screens**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.6, 6.9**

  - [ ]* 7.5 Write example tests for the widened guards and denial messaging
    - Assert a mobileShop session reaches Warranty/Serial-History/Job-Card screens; assert Multi_Unit_Screen stays computerShop-only; assert a denial names the required capability or allowed business types, never only "Computer Shop"
    - _Requirements: 6.7, 6.8_

- [x] 8. Checkpoint — Phase 3
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 3 tests pass, confirm the widen-vs-relocate decision artifact is recorded, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 9. Phase 4 — Sidebar, navigation, and RBAC wiring (Requirement 7)

  - [x] 9.1 Add `_getMobileShopSections()` and the explicit `case BusinessType.mobileShop` branch
    - In `lib/widgets/desktop/sidebar_configuration.dart`, remove mobileShop from the shared `electronics/mobileShop/computerShop → _getRetailSections()` group and add `case BusinessType.mobileShop: return _getMobileShopSections();`; do not fall through to retail (electronics and computerShop keep their own grouped case)
    - Return exactly the five mobile entries — Service Jobs (`service_jobs` → `ServiceJobListScreen`), Exchanges (`exchanges` → `ExchangeListScreen`), IMEI Tracking (`imei_tracking` → `SerialHistoryScreen`), Warranty (`warranty` → `WarrantyScreen`), Second-Hand Intake (`second_hand_intake` → `SecondHandIntakeScreen`) — plus the same shared common sections every type receives; exclude unsupported retail items (`proforma_bids`, `dispatch_notes`, `return_inwards`) by omission; document the in-file blast radius
    - _Requirements: 7.1, 7.8, 7.10, 1.9, 1.12_

  - [x] 9.2 Tag each mobile item with its capability and apply the capability gate
    - Tag each item with its matching capability (`useJobSheets`, `useExchange`, `useIMEI`, `useWarranty`, `useBuyback`) and exclude from the returned set any item whose capability the session does not hold
    - _Requirements: 7.2, 7.8_

  - [x] 9.3 Attach `permission` tags to surfaced financial/compliance/admin items
    - Attach a `permission` tag (e.g. `viewReports`, `manageSettings`) to each sensitive retail item that remains visible to mobileShop so `RolePermissions` gates it; a role lacking the tagged permission is blocked, shown an access-denied indication, and the current screen state preserved
    - _Requirements: 7.4, 7.5_

  - [x] 9.4 Enforce Content_Host guard parity and service-job navigation
    - When a repair/exchange screen renders through the Content_Host in-shell path, enforce the same permission required by the equivalent named route (`/service_jobs`, `/exchanges`) before rendering, denying render when absent; ensure job-create/job-status/job-deliver navigation reaches the corresponding service-job destination and renders without a navigation error
    - _Requirements: 7.3, 7.6_

  - [x] 9.5 Record the manageStaff-permission and Mobile_Shop_Module disposition decisions
    - Record a durable decision artifact stating (a) whether `manageStaff` remains the gating permission for repair/exchange operations or is replaced by an operations/invoice permission, and (b) whether the orphaned Mobile_Shop_Module / Mobile_Shop_Routes are deleted (under soft-delete/sign-off) or retained — each with a one-sentence rationale
    - _Requirements: 7.7, 7.9_

  - [ ]* 9.6 Write property test for capability-filtered sidebar items
    - **Property 13: Sidebar items are filtered by held capability**
    - **Validates: Requirements 7.2, 7.8**

  - [ ]* 9.7 Write property test for RBAC gating of permission-tagged items
    - **Property 14: RBAC gating of permission-tagged items**
    - **Validates: Requirements 7.5, 13.6**

  - [ ]* 9.8 Write example/regression tests for the five-item section and byte-for-byte preservation
    - Assert `_getSectionsForBusiness(mobileShop)` returns the dedicated five-item section (not retail) plus shared common sections; assert every other `BusinessType` returns sections byte-for-byte identical to the pre-change baseline
    - _Requirements: 7.1, 7.10_

- [x] 10. Checkpoint — Phase 4
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 4 tests pass, confirm the decision artifacts recorded, document the Shared_Component blast radius and per-vertical regression result, output `PHASE 4 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 11. Phase 5 — Dashboard and KPI real-data wiring (Requirement 8)

  - [x] 11.1 Point the "IMEI Lookup" quick action at Serial_History_Screen
    - In `business_quick_actions.dart`, replace the empty `onTap: () {}` on the mobileShop "IMEI Lookup" action with navigation to Serial_History_Screen; leave every other business type's quick-action destinations identical
    - _Requirements: 8.1, 8.7_

  - [x] 11.2 Wire live alert counts and the four KPI cards
    - In `business_alerts_widget.dart`, replace the hardcoded literals `'5'`, `'8'`, `'3'` in the mobileShop branch with reads from `Service_Job_Service.getJobCounts`, `Exchange_Service.getExchangeStats`, and `Alert_Counts_Provider`
    - Display exactly four KPI cards — active repairs by job status (`getJobCounts`), exchange pipeline value (`getExchangeStats.totalExchangeValue`), IMEI in-stock vs sold count, open warranty claim count — each from its live source; leave non-mobileShop branches resolving identical content
    - _Requirements: 8.2, 8.3, 8.7_

  - [x] 11.3 Implement loading / empty / error states for each KPI card
    - Show a loading state while a source loads and resolve to a value/empty/error within 10 seconds; show a zero value with an empty-state label for a zero-record source (not a hardcoded count); show an error state with a retry affordance on failure/timeout, never a stale or hardcoded count
    - _Requirements: 8.4, 8.5, 8.6_

  - [ ]* 11.4 Write example tests for KPI wiring, states, and cross-vertical preservation
    - Assert "IMEI Lookup" navigates to Serial_History_Screen; assert the four KPI cards read their live sources; assert loading/empty/error states; assert non-mobileShop alert/quick-action content and destinations are unchanged
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

- [x] 12. Checkpoint — Phase 5
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 5 tests pass, document the Shared_Component blast radius and per-vertical regression result, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 13. Phase 6 — Second-hand intake, demo status, EMI decision (Requirement 9)

  - [x] 13.1 Request the Mini_Gate for the IMEISerial / IMEISerialStatus shape changes
    - Before applying any schema/enum change, halt and request a Mini_Gate presenting the proposed `IMEISerial` extension (`condition`, `grade`, `valuationPaise`) and the `IMEISerialStatus` `demo` addition together with an idempotent migration plan that, re-run on already-migrated rows, produces no additional changes; if the gate is not granted, apply no schema/enum change and leave existing definitions unchanged
    - _Requirements: 9.4, 9.5, 9.6, 1.6_

  - [x] 13.2 Implement the SecondHandIntakeScreen with validation, integer-Paise valuation, and RID
    - Capture device identity, a `condition` from a predefined finite set, and a `grade` from a predefined finite set, scoped by Tenant_Id; reject a missing required field or out-of-set condition/grade, creating no record and naming the offending field
    - Store the valuation as integer Paise in the inclusive range `1 .. 99,999,999,999` and generate the identifier with the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
    - _Requirements: 9.1, 9.2, 9.3, 1.1, 1.2, 1.3, 1.4_

  - [x] 13.3 Exclude demo units from sellable stock while keeping them visible in IMEI tracking
    - Exclude an `IMEISerial` with `demo` status from sellable stock counts while keeping it visible in IMEI tracking; re-include it in sellable counts when it transitions out of `demo` to a sellable status
    - _Requirements: 9.7, 9.8_

  - [x] 13.4 Record the EMI/finance scope decision
    - Record an explicit decision marking EMI/finance as in-scope or deferred-backlog with a rationale of at least one sentence; implement no EMI code without the Requirement 2.5 confirmation
    - _Requirements: 9.9, 2.5_

  - [ ]* 13.5 Write property test for the RID identifier format
    - **Property 1: RID identifier format**
    - **Validates: Requirements 1.3, 9.3**

  - [ ]* 13.6 Write property test for migration idempotency
    - **Property 4: Migrations are idempotent**
    - **Validates: Requirements 1.8, 9.5**

  - [ ]* 13.7 Write property test for second-hand intake validation
    - **Property 15: Second-hand intake validation**
    - **Validates: Requirements 9.1, 9.2**

  - [ ]* 13.8 Write property test for the second-hand valuation range
    - **Property 16: Second-hand valuation range**
    - **Validates: Requirements 9.3**

  - [ ]* 13.9 Write property test for demo-unit stock exclusion
    - **Property 17: Demo units are excluded from sellable stock**
    - **Validates: Requirements 9.7, 9.8**

- [x] 14. Checkpoint — Phase 6
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 6 tests pass, confirm the Mini_Gate sign-off for the schema/enum change and the EMI decision artifact, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 15. Phase 7 — Security hardening (Requirement 10)

  - [x] 15.1 Unify the identity source across the two service screens
    - Resolve the authenticated user identity in Service_Job_List_Screen and Exchange_List_Screen from one shared identity source (reconciling `AuthService().currentUser` vs `FirebaseAuth.instance`) so both return the same User_Id and Tenant_Id for the same session
    - _Requirements: 10.1_

  - [x] 15.2 Implement null-session and timeout error states
    - On a null session/identity at load, show an error state messaging an invalid/expired session and stop the loading indicator; if identity does not resolve within 10 seconds, replace the loading indicator with an error state indicating the session could not be resolved
    - _Requirements: 10.2, 10.3_

  - [x] 15.3 Scope every Phase 0 tenant-leak read/write by the session Tenant_Id
    - For each tenant-isolation leak identified in Phase 0 affecting an `IMEISerial`/`ServiceJob`/`Exchange`/`WarrantyClaim` read/write, scope the operation by the session Tenant_Id so it accesses only same-tenant records
    - _Requirements: 10.4, 1.4_

  - [ ]* 15.4 Write property test for tenant isolation across all device entities
    - **Property 2: Tenant isolation across all device entities**
    - **Validates: Requirements 1.4, 10.4, 10.5, 13.3**

  - [ ]* 15.5 Write property test for consistent identity source
    - **Property 18: Identity source is consistent across service screens**
    - **Validates: Requirements 10.1**

  - [ ]* 15.6 Write per-entity isolation tests and null/timeout state tests
    - Provide a passing test per `IMEISerial`/`ServiceJob`/`Exchange`/`WarrantyClaim` asserting a query under one Tenant_Id returns zero other-tenant records; assert the null-session and 10-second-timeout error states replace the loading indicator
    - _Requirements: 10.2, 10.3, 10.5_

- [x] 16. Checkpoint — Phase 7
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 7 tests pass, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 17. Phase 8 — Capability alignment (Requirement 11)

  - [x] 17.1 Record and apply the OCR decision
    - Record a documented decision resolving `useScanOCR` for mobileShop to exactly one of — grant the capability (aligning with electronics) or remove the `ocrFocus` value — with a rationale of at least one complete sentence (minimum 10 words); where OCR is denied, expose no `ocrFocus` value or any UI/label/config entry implying OCR exists for mobileShop
    - _Requirements: 11.1, 11.2_

  - [x] 17.2 Record the sales-return decision
    - Record a documented decision resolving `useSalesReturn` for mobileShop to — grant an IMEI-aware return flow or remain without sales-return — with a rationale of at least one complete sentence
    - _Requirements: 11.3_

  - [x] 17.3 Implement the IMEI-aware return flow (only if granted by 17.2)
    - If the decision grants the flow: confirming a return for a `sold` `IMEISerial` within the requesting tenant reverts its status to a returnable state scoped to that tenant only; a return for a non-existent (within tenant) or non-`sold` serial is rejected with the status unchanged and an error naming the reason; no `IMEISerial` belonging to a different tenant is modified
    - _Requirements: 11.4, 11.5, 11.6_

  - [ ]* 17.4 Write property test for IMEI-aware return status revert (only if return flow granted)
    - **Property 19: IMEI-aware return reverts status, tenant-scoped**
    - **Validates: Requirements 11.4, 11.6**

  - [ ]* 17.5 Write property test for IMEI-aware return error condition (only if return flow granted)
    - **Property 20: IMEI-aware return error condition**
    - **Validates: Requirements 11.5**

- [x] 18. Checkpoint — Phase 8
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 8 tests pass, confirm the OCR and sales-return decision artifacts (and mark Properties 19/20 not-applicable in the Traceability_Matrix if the return flow is deferred), output `PHASE 8 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 19. Phase 9 — UX, performance, and accessibility (Requirement 12)

  - [x] 19.1 Debounce search on both service screens
    - Apply the search filter in Service_Job_List_Screen / Exchange_List_Screen only after 300 ms of keystroke inactivity (replacing per-keystroke `.where(...)`); clearing the field shows the full unfiltered list within 300 ms
    - _Requirements: 12.1, 12.2_

  - [x] 19.2 Unify the header structure and replace hardcoded colors with theme tokens
    - Render both screens with an identical header structure — same header component, title placement, and primary-action positioning (reconciling AppBar vs custom-gradient header); replace all hardcoded color literals in the touched service screens with theme tokens so none remain
    - _Requirements: 12.3, 12.4_

  - [x] 19.3 Add Semantics labels and tooltips, and record the contrast verification
    - Give every custom tap target in the touched screens — including the previously action-less status cards — a non-empty `Semantics` label and a tooltip; record a color-contrast verification against WCAG 2.1 AA (≥4.5:1 normal text, ≥3:1 large text), noting full WCAG validation requires manual testing with assistive technology
    - _Requirements: 12.5, 12.6_

  - [ ]* 19.4 Write example tests for debounce, theming, and accessibility
    - Assert search recomputes only after 300 ms idle and a cleared field restores the full list within 300 ms; assert zero color literals remain and both screens use the identical header structure; assert non-empty `Semantics` labels and tooltips on custom tap targets including status cards
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [x] 20. Checkpoint — Phase 9
  - List files created/modified/deleted, run `flutter analyze` on touched files, ensure all Phase 9 tests pass, output `PHASE 9 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 21. Phase 10 — Regression, isolation, RBAC, offline, traceability (Requirement 13)

  - [x] 21.1 Run the cross-vertical regression pass against the pre-Phase-10 baseline
    - Compare each Shared_Device_Vertical and every other business type against a baseline recorded before Phase 10 across sidebar/capability/quick-action/alert behavior, recording PASS/FAIL per business type; list any differing element and withhold final sign-off until resolved
    - _Requirements: 13.1, 13.2_

  - [x] 21.2 Run the multi-tenant isolation and offline tests
    - With ≥2 distinct Tenant_Id values, confirm `IMEISerial`/`ServiceJob`/`Exchange`/`WarrantyClaim` reads/writes return no other-tenant records (record any leak and withhold sign-off); with connectivity disabled, confirm repair/exchange reads/writes operate against the local database and IMEI rows persist locally
    - _Requirements: 13.3, 13.4, 13.5_

  - [x] 21.3 Run the RBAC visibility test per permission-tagged item
    - Confirm each permission-tagged sidebar item is hidden for roles lacking the permission and shown for roles holding it, recording PASS/FAIL per item
    - _Requirements: 13.6_

  - [x] 21.4 Produce the Traceability_Matrix
    - Map every audit finding (§1–§20) to exactly one of FIXED / VERIFIED-OK / DEFERRED-SIGNOFF; list any unmapped, multiply-dispositioned, or unresolved finding and withhold final sign-off until each has exactly one recorded disposition
    - _Requirements: 13.7, 13.8_

  - [ ]* 21.5 Write integration/offline tests for the local-DB repair/exchange/IMEI path
    - 1–3 examples asserting offline reads/writes hit the local database and IMEI rows persist locally, plus the end-to-end sync-handler disposition from the Phase 0 finding
    - _Requirements: 13.5_

- [x] 22. Checkpoint — Phase 10 (final verification)
  - Confirm all property tests (Properties 1–20, with 19/20 conditional on the Phase 8 return-flow decision) and example/integration tests pass; run `flutter analyze` across all touched files with no new warnings/errors; confirm the Traceability_Matrix is complete with exactly one disposition per finding; output `PHASE 10 COMPLETE — AWAITING APPROVAL`, then stop. Ask the user if questions arise.

## Notes

- Sub-tasks marked with `*` are optional tests (property, unit, integration) and are not auto-implemented; core implementation sub-tasks are always implemented.
- Each property test references a specific design Correctness Property by number and the requirements clause it validates, runs a minimum of 100 iterations against an in-memory/mocked Drift store (no live backend calls), and is tagged `Feature: mobileshop-vertical-remediation, Property {n}: {text}`.
- The highest-value properties land close to the implementation they protect: Property 5 (sale marks IMEISerial) and 6 (warranty clamp) in Phase 1; Property 7 (invalid/duplicate rejection), 8 (Luhn), 9 (generic serial), 10 (warranty range) in Phase 2; Property 12 (device-screen gating) in Phase 3; Property 13 (capability filter) and 14 (RBAC) in Phase 4; Property 1 (RID), 4 (idempotent migration), 15–17 (second-hand/demo) in Phase 6; Property 2 (tenant isolation), 3 (unresolved tenant), 18 (identity) in Phase 7; Property 19/20 (return flow, conditional) in Phase 8.
- Properties 19 and 20 are exercised only if the Phase 8 sales-return decision (11.3) grants the IMEI-aware return flow; if deferred, they are marked not-applicable in the Traceability_Matrix with the decision as rationale.
- Dashboard wiring, KPI loading/empty/error states, navigation reachability, denial messaging, header/theming/accessibility, timing budgets, and the Phase 0/3/4/6/8/10 decision and verification artifacts are validated by example, integration, smoke, or governance checks per the design Testing Strategy — not by properties.
- Every phase ends with a STOP GATE; schema/enum/Drift changes require a Mini_Gate (proposed change + idempotent migration plan) and any removal uses soft-delete or a two-confirmation flow. No other business type's sidebar, capability, quick-action, or alert resolution is modified except the explicitly authorized device-service guard widenings, and every Shared_Component edit records its blast radius and a per-vertical regression result.
- All new money is integer Paise, all new ids use the RID pattern, and every query/write/sync is tenant-scoped (an unresolved tenant aborts the operation leaving data unchanged).

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["3.1"] },
    { "id": 2, "tasks": ["3.2", "3.3", "3.4"] },
    { "id": 3, "tasks": ["3.5", "3.6", "3.7", "3.8", "3.9"] },
    { "id": 4, "tasks": ["5.1", "5.3", "5.4", "5.5"] },
    { "id": 5, "tasks": ["5.2"] },
    { "id": 6, "tasks": ["5.6", "5.7", "5.8", "5.9", "5.10"] },
    { "id": 7, "tasks": ["7.1", "7.2"] },
    { "id": 8, "tasks": ["7.3"] },
    { "id": 9, "tasks": ["7.4", "7.5"] },
    { "id": 10, "tasks": ["9.1"] },
    { "id": 11, "tasks": ["9.2", "9.3", "9.4", "9.5"] },
    { "id": 12, "tasks": ["9.6", "9.7", "9.8"] },
    { "id": 13, "tasks": ["11.1", "11.2"] },
    { "id": 14, "tasks": ["11.3"] },
    { "id": 15, "tasks": ["11.4"] },
    { "id": 16, "tasks": ["13.1"] },
    { "id": 17, "tasks": ["13.2", "13.3", "13.4"] },
    { "id": 18, "tasks": ["13.5", "13.6", "13.7", "13.8", "13.9"] },
    { "id": 19, "tasks": ["15.1", "15.2", "15.3"] },
    { "id": 20, "tasks": ["15.4", "15.5", "15.6"] },
    { "id": 21, "tasks": ["17.1", "17.2"] },
    { "id": 22, "tasks": ["17.3"] },
    { "id": 23, "tasks": ["17.4", "17.5"] },
    { "id": 24, "tasks": ["19.1", "19.2", "19.3"] },
    { "id": 25, "tasks": ["19.4"] },
    { "id": 26, "tasks": ["21.1", "21.2", "21.3", "21.4"] },
    { "id": 27, "tasks": ["21.5"] }
  ]
}
```
