# Implementation Plan — School ERP (`schoolErp`) Vertical Full Remediation

## Overview

Phased, evidence-based implementation plan that integrates the existing DukanX `schoolErp`
vertical (`BusinessType.schoolErp`, "School ERP") into the live shell. The strategic
directive is **integrate the existing code, do not rebuild or delete working screens** — the
~34 `Ac*Screen` widgets and `AcRepository` under `lib/features/academic_coaching/` are assets
to wire up. Work proceeds strictly in phase order (Phase 0 → Phase 10). Each phase ends with a
STOP GATE: produce the Phase_Report (every file created/modified/deleted with the change and
the audit finding it addresses), run `flutter analyze` plus the test suite on touched code,
emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for the
literal reply `APPROVED`. Do NOT auto-continue to the next phase.

The language is Dart/Flutter for the app and Node.js for any backend logic, consistent with
the existing codebase (the design specifies concrete Dart signatures, so no language choice is
required).

All new code follows the non-negotiable cross-cutting constraints (Requirement 1) and the
scope boundary (Requirement 2): integer-Paise money (never `double`/`float`/decimal for
currency), RID id pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, tenant scoping on every
query/write/sync (unresolved tenant aborts the operation), idempotent migrations, and
surgical/additive edits to Shared_Components (`sidebar_configuration.dart`,
`sidebar_navigation_handler.dart`, `business_quick_actions.dart`, `business_alerts_widget.dart`,
`business_capability.dart`, `bill_template_system.dart`, the route table) — no other business
type's sidebar, capability, quick-action, alert, or template resolution changes. Changes are
restricted to the four allowed locations: `lib/features/academic_coaching/*`, the `schoolErp`
case within Shared_Components, the schoolErp offline sync handler, and the navigation entries
needed for reachability. No app-wide GoRouter migration; the standalone `school_admin_app/`,
`school_teacher_app/`, `school_student_app/`, `school_common/` projects are out of scope. Any
schema/`UserRole` enum/Drift-table change requires a Mini_Gate (proposed change + every
consumer + migration plan) before applying; any hard deletion requires a repository-wide
reference search + recorded sign-off — no hard deletes otherwise. Phase 4 (minors' PII) is a
hard policy stop: no PII handling code until retention, consent, authorized-role, and
audit-logging policies are confirmed and recorded with owner + timestamp.

## Tasks

> **Phased STOP-GATE protocol.** After every phase: (a) produce the Phase_Report listing files
> created/modified/deleted with the specific change and the audit finding each addresses, (b)
> run `flutter analyze` + the test suite on touched code and record counts, (c) record the
> per-non-school-vertical regression result, (d) output exactly `PHASE N COMPLETE — AWAITING
> APPROVAL`, then stop and wait for `APPROVED`. Sub-tasks marked with `*` are optional tests
> and are not auto-implemented. Property tests reference the design's Correctness Properties by
> number, run a minimum of 100 iterations, and are tagged
> `Feature: schoolerp-vertical-remediation, Property {n}: {text}`.

- [x] 1. Phase 0 — Read-only re-verification and gap discovery (Requirement 3)

  - [x] 1.1 Produce the read-only Verification_Report
    - Create `.kiro/specs/schoolerp-vertical-remediation/phase0-verification-report.md` and create/modify/delete zero other files; touch no application source, configuration, or build file
    - Record a repository-wide search for hardcoded `vendorId`, `tenantId`, or `'SYSTEM'` literals within `lib/features/academic_coaching/*`, citing file path + line for each occurrence, with explicit "none found" when zero
    - Classify every `AcRepository` write method (`createStudent`, `updateStudent`, `transferStudent`, `createBatch`, `createCourse`, `createInvoice`, `recordPayment`, `markAttendance`, `createExam`, `uploadResults`, `createMaterial`, `createFaculty`, `markFacultyAttendance`, `createTimetableSlot`, `generateCertificate`, `bulkImportStudents`, `bulkGenerateInvoices`, …) as `fully-threaded` or `has-gaps` for active `Tenant_Id`, noting whether tenant is threaded explicitly or only via the `ApiClient` auth header, with path + line; "no write methods found" when zero
    - Classify every new-entity id-generation site as `compliant` or `non-compliant` against the RID pattern, with path + line; "no non-compliant sites found" when all comply
    - Classify money representation as `paise-consistent` or `has-ambiguity`, listing the `ac_models.dart` `double` fields (`AcStudent.totalFees/totalPaid/balance`, `AcCourse.totalFee/materialFee/admissionFee`, `AcInvoice.totalAmount/paidAmount/balance/discountAmount/adjustmentAmount`) and the `*Paisa`/100 conversions as ambiguities, with path + line; "no ambiguous fields found" when all integer Paise
    - Record that `ac_validators.dart` exists and enumerate each function (`validateStudentId`, `validateName`, `validatePhone`, `validateEmail`, `validateDateOfBirth`, `validateFeeAmount`, `validateCapacity`, `validateDateRange`, `validateExamDuration`, `validateMarks`, `validatePincode`, `required`, `validateUniqueId`) with path + line; record its absence explicitly if missing
    - Classify each `/ac/*` endpoint required by an `Ac_Screen` as `deployed`, `not-deployed`, or `unverified`, recording observed vs expected request paths
    - Rate every Orphaned_Screen `Production-Ready`, `Needs-Work`, or `Stale` with a one-line justification and file path
    - Reconcile the route surface: verify the live route-registration file (`lib/core/routing/legacy_routes.dart` observed vs the audit's `app/routes.dart` claim) and resolve the `/ac/students` vs `AcStudentRegistrationScreen` collision question; mark every previously unverified assumption CONFIRMED, FALSIFIED, or still-unverified with path + line; ensure every check is classified with nothing left unclassified
    - If any Ground Truth assumption is contradicted by the live codebase → STOP, report the discrepancy in the report, and do not route around it
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11_

- [ ] 2. Checkpoint — Phase 0
  - List files created/modified/deleted (Verification_Report only), confirm zero non-report files changed, output `PHASE 0 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ensure all checks pass; ask the user if questions arise.

- [x] 3. Phase 1 — Routing and navigation wiring (Requirement 4)

  - [x] 3.1 Add `_getSchoolSections()` and the explicit `case BusinessType.schoolErp` branch
    - In `lib/widgets/desktop/sidebar_configuration.dart`, add `case BusinessType.schoolErp:` returning a new `_getSchoolSections()`; do not fall through to `default: _getRetailSections()`
    - Return the Production-Ready section/item set (Dashboard, Students & Admissions, Fees, Attendance, Exams & Report Cards, Timetable, Faculty, Transport, Library, Communication, Reports, Certificates), each item carrying a non-empty label and a capability gate via the existing `sidebarSectionsProvider` filter; orphaned screens are added later in Phase 6
    - Edit additively — for any `BusinessType` other than `schoolErp`, `_getSectionsForBusiness` returns sections identical to pre-change; document the blast radius in-file
    - _Requirements: 4.1, 4.2, 4.3, 4.10, 1.11, 1.12_

  - [x] 3.2 Map each `school_*` sidebar id to an existing `Ac_Screen` in the navigation handler
    - In `lib/widgets/desktop/sidebar_navigation_handler.dart`, add `case 'school_*':` branches in `tryGetScreenForItem` mapping each id to exactly one existing `Ac_Screen` widget (the same widgets the live route table references), never `_buildPlaceholderScreen`
    - An id that cannot resolve returns null from `tryGetScreenForItem` (placeholder via `getScreenForItem`), retains the current screen, surfaces an "unavailable" indication, performs no navigation, and raises no unhandled exception
    - _Requirements: 4.4, 4.5_

  - [x] 3.3 Resolve the `/ac/students` collision and align dormant GoRouter entries
    - Bind `/ac/students` to the screen recorded more feature-complete in the Phase 0 report (`AcStudentsScreen`) and assign `AcStudentRegistrationScreen` a distinct non-colliding path (e.g. `/ac/students/register`) in the live route table
    - Align each dormant `school_erp` GoRouter `/ac/*` entry to reference the same target as its live binding without activating GoRouter
    - Source school navigation only from `sidebarSectionsProvider`; flag the unused `SchoolErpModule.navItems` redundancy in the Phase_Report without deleting it (deletion is Phase 9)
    - _Requirements: 4.6, 4.7, 4.8, 4.9_

  - [ ]* 3.4 Write property test for other-business-type preservation
    - **Property 6: Other business types are unchanged**
    - **Validates: Requirements 1.11, 1.12, 1.15, 2.6, 4.10, 5.10, 6.7, 11.4, 13.7**

  - [ ]* 3.5 Write property test for school sidebar item well-formedness and resolution
    - **Property 7: Every school sidebar item is well-formed and resolves to a real screen**
    - **Validates: Requirements 4.2, 4.3, 4.4**

  - [ ]* 3.6 Write property test for safe handling of unknown navigation ids
    - **Property 8: Unknown navigation ids are handled safely**
    - **Validates: Requirements 4.5**

  - [ ]* 3.7 Write example tests for sidebar dispatch and route collision
    - Assert `_getSectionsForBusiness(schoolErp)` returns `_getSchoolSections()` (not retail); `/ac/students` binds to the more-complete screen and `AcStudentRegistrationScreen` gets a distinct non-colliding path
    - _Requirements: 4.1, 4.6_

- [x] 4. Checkpoint — Phase 1
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, document the Shared_Component blast radius and per-vertical regression result, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 5. Phase 2 — Dashboard, quick actions, and alerts with real data (Requirement 5)

  - [x] 5.1 Add the schoolErp quick-action case
    - In `lib/features/dashboard/v2/widgets/business_quick_actions.dart`, add `case BusinessType.schoolErp:` in `_buildActionsForBusiness` presenting exactly four actions — Collect Fee (→ `AcFeeCollectionScreen`), New Admission (→ `AcStudentRegistrationScreen`), Mark Attendance (→ `AcAttendanceScreen`), Enter Marks (→ `AcExamsScreen`), each navigating to the existing screen
    - Make the change additive within the `schoolErp` case; no other business type's action set changes
    - _Requirements: 5.1, 5.10_

  - [x] 5.2 Add the schoolErp alerts case backed by real tenant-scoped queries
    - In `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`, add `case BusinessType.schoolErp:` in `_getTitle` ("School Alerts") and `_buildAlertsForBusiness` presenting exactly three alerts — Fees Due, Absentees Today, Upcoming Exams — each backed by a real tenant-scoped query through `AcRepository`/the offline cache (fee dues, today's absentees, upcoming exams)
    - Display no hardcoded count for any schoolErp alert; derive every count from a live query result; keep the change additive within the `schoolErp` case
    - _Requirements: 5.2, 5.3, 5.10_

  - [x] 5.3 Surface tenant-scoped KPI cards with loading/empty/error states
    - Populate `Ac_Dashboard_Stats` KPI cards from `AcRepository.getDashboard()`, each a non-negative integer derived from a tenant-scoped query for the active `Tenant_Id`
    - Show a loading indicator while a query is in progress, a zero/empty-state indicator when a query returns no data, and an error indication on query failure — never a fabricated count
    - _Requirements: 5.4, 5.7, 5.8, 5.9_

  - [x] 5.4 Wire the `school.*` WebSocket consumer mirroring the `inventory.*` pattern
    - On a `school.fee.due`, `school.attendance.marked`, or `school.exam.result` event for the active `Tenant_Id`, update the corresponding dashboard alert/KPI by mirroring the existing `inventory.*` consumption pattern
    - Ignore any event whose tenant differs from the active `Tenant_Id`, updating nothing displayed
    - _Requirements: 5.5, 5.6_

  - [ ]* 5.5 Write property test for KPI/alert non-negative counts and honest empty state
    - **Property 9: KPI and alert counts are non-negative integers with honest empty state**
    - **Validates: Requirements 5.4, 5.7**

  - [ ]* 5.6 Write property test for tenant-filtered real-time updates
    - **Property 10: Real-time updates are tenant-filtered**
    - **Validates: Requirements 5.5, 5.6**

  - [ ]* 5.7 Write example tests for quick-action set, alert set, and UI states
    - Assert the schoolErp case presents exactly the four quick actions and three alerts, each wired to its screen/query with no hardcoded count literal in the school branch; assert a loading indicator while a query runs and an error indication on failure
    - _Requirements: 5.1, 5.2, 5.3, 5.8, 5.9_

- [x] 6. Checkpoint — Phase 2
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, document blast radius and per-vertical regression result, output `PHASE 2 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 7. Phase 3 — RBAC and scoped School_Permissions (Requirement 6)

  - [x] 7.1 Implement the `School_Permissions` mapping layer
    - Add a scoped layer mapping one or more existing `UserRole` values (`owner`, `manager`, `staff`, `accountant`) to each school-specific permission (`viewStudents`, `viewFees`, `collectFees`, `markAttendance`, `enterMarks`, `viewStudentPII`, `exportStudentPII`) without adding, removing, renaming, or reordering any `UserRole` value
    - Express the mapping as a total pure function `hasSchoolPermission(UserRole role, SchoolPermission p) -> bool` returning `false` (deny-by-default) for any unmapped pair, reusable by both the sidebar filter and the route guards
    - If a `UserRole` enum change is ever proposed, leave the enum unchanged and emit a Mini_Gate first
    - _Requirements: 6.1, 6.2_

  - [x] 7.2 Replace generic `/ac/*` route guards with School_Permission guards
    - Change every `/ac/*` route guard from a generic retail permission (`viewInvoices`, `viewClients`) to a school-specific permission so no `/ac/*` route retains a `viewInvoices`/`viewClients` guard
    - A holder of the required `School_Permission` resolves the route to its `Ac_Screen` with no redirect; a non-holder (or a route with no mapping defined) is blocked, renders no part of the screen, is redirected to the default authorized landing screen, and is shown an access-denied indication
    - Scope the change to schoolErp routes; no other business type's route guard changes
    - _Requirements: 6.3, 6.4, 6.5, 6.6, 6.7_

  - [ ]* 7.3 Write property test for `/ac/*` route access control
    - **Property 11: `/ac/*` route access is granted exactly by school permission**
    - **Validates: Requirements 6.3, 6.4, 6.5, 6.6**

  - [ ]* 7.4 Write property test for the permission mapping totality and UserRole stability
    - **Property 12: School permission mapping is total and leaves UserRole unchanged**
    - **Validates: Requirements 6.2**

- [x] 8. Checkpoint — Phase 3
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, confirm no `UserRole` enum change was applied without a Mini_Gate, document per-vertical regression result, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 9. Phase 4 — Minors' PII and compliance (policy stop) (Requirement 7)

  - [x] 9.1 Surface the four policy decisions for sign-off and halt PII implementation
    - While any of the data retention period, parent/guardian consent mechanism, authorized-role list, or audit-logging policy is unconfirmed, treat Phase 4 as a hard stop and implement no minors'-PII handling code
    - Surface each unconfirmed decision by name; treat a decision as confirmed only when a record captures the decision, the agreed value, the confirming compliance owner, and the confirmation timestamp
    - Verify and record per DynamoDB table storing minors' PII whether encryption-at-rest is enabled (boolean per table) in the Phase_Report
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.8, 7.9_

  - [x] 9.2 Implement the per-record PII access audit log (only after policies are confirmed)
    - When a user views or exports a minor's PII, write exactly one audit entry capturing acting user, record accessed, action (`view`/`export`), and timestamp, scoped by `Tenant_Id`, with outcome `allowed` and data returned when the user's role is in the confirmed authorized-role list
    - When the user's role is not in the confirmed authorized-role list, deny the operation, return and export no data, and write an audit entry recording the denied attempt (outcome `denied`)
    - Use the RID pattern for the audit entry id
    - _Requirements: 7.6, 7.7_

  - [ ]* 9.3 Write property test for audited PII access with correct outcome
    - **Property 13: Minors' PII access is always audited with the correct outcome**
    - **Validates: Requirements 7.6, 7.7**

- [x] 10. Checkpoint — Phase 4
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, confirm each policy decision is recorded with owner + timestamp (or that PII code was withheld pending sign-off), record per-PII-table encryption-at-rest status, output `PHASE 4 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 11. Phase 5 — Offline sync and real-time consistency (Requirement 8)

  - [x] 11.1 Add the tenant-scoped Drift cache for students, fees, and attendance
    - Add `school_students_cache`, `school_fees_cache`, and `school_attendance_cache` Drift tables mirroring the offline caching pattern used by other verticals; every row carries `tenantId`, currency columns are integer Paise, and identifiers follow the RID pattern
    - A cache read never returns a row whose `tenantId` differs from the active `Tenant_Id`; any new table/column is additive with safe defaults and applied only after a Mini_Gate
    - _Requirements: 8.1, 8.6, 1.8_

  - [x] 11.2 Extend `SchoolErpSyncHandler` beyond students with the sync queue
    - Extend the handler beyond `school_students` to also synchronize fees, attendance, and exams (additional collection → `/ac/*` base-path mappings); add the `school_sync_queue` (`entityType`, `operation`, `entityRid`, `retryCount`, `lastError`, `failed` flag)
    - _Requirements: 8.2_

  - [x] 11.3 Implement idempotent, order-independent reconciliation keyed by RID
    - On connectivity restore, reconcile local and remote state so each RID has exactly one stored version with no duplicate; an upsert whose RID exists at the same-or-newer `version` is a no-op (applying the same change more than once equals a single application)
    - When a WebSocket event and a sync operation target the same RID, serialize the operations, apply the change at most once, and reach a single resulting version independent of arrival order
    - _Requirements: 8.3, 8.4, 8.5_

  - [x] 11.4 Retain and retry failed sync entries without discarding
    - A failed sync entry retains its pending local change, leaves successfully synced records unaffected, and is retried on the next connectivity-restored event; it is never discarded
    - _Requirements: 8.7_

  - [ ]* 11.5 Write property test for tenant isolation across reads, writes, and the cache
    - **Property 3: Tenant isolation across reads, writes, and the cache**
    - **Validates: Requirements 1.5, 8.1**

  - [ ]* 11.6 Write property test for idempotent, order-independent sync reconciliation
    - **Property 14: Sync reconciliation is idempotent and order-independent**
    - **Validates: Requirements 8.3, 8.4, 8.5**

  - [ ]* 11.7 Write property test for retained-and-retried failed sync entries
    - **Property 15: Failed sync entries are retained and retried, never discarded**
    - **Validates: Requirements 8.7**

  - [ ]* 11.8 Write integration test for the offline-first students/fees/attendance path
    - 1–3 examples for the offline load + sync path; assert the screens read through the offline cache and the sync handler covers fees/attendance/exams
    - _Requirements: 8.2_

- [x] 12. Checkpoint — Phase 5
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, confirm any Mini_Gate sign-off obtained for the new Drift tables, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 13. Phase 6 — Orphaned screen disposition (Requirement 9)

  - [x] 13.1 Wire each Production-Ready orphaned screen into navigation
    - For each screen rated Production-Ready in Phase 0, add exactly one route, one `School_Permission` guard, and one sidebar entry, referencing the existing screen widget without copying or rebuilding it
    - Record in the Phase_Report the screen identifier, its route, its guard permission name, and its sidebar label
    - _Requirements: 9.1, 9.2, 9.6_

  - [x] 13.2 Record Needs-Work and Stale dispositions without wiring or deleting
    - For each Needs-Work screen, record its specific gaps as discrete Phase_Report items and add no route, guard, or sidebar entry
    - For each Stale screen, run a reference search across the schoolErp source tree, record the reference count and file paths, and flag it for deletion without deleting it (deletion deferred to explicit sign-off per Requirement 1.9)
    - _Requirements: 9.3, 9.4, 9.5_

- [x] 14. Checkpoint — Phase 6
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, confirm no Stale screen was deleted without sign-off, document per-vertical regression result, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 15. Phase 7 — Data validation and money/ID compliance (Requirement 10)

  - [x] 15.1 Migrate touched money fields to integer Paise via the Mini_Gate process
    - Resolve each rupee/paise ambiguity recorded in Phase 0 by migrating the affected `ac_models.dart` `double` money fields to integer-Paise fields (`totalFeesPaise`, `totalPaidPaise`, `balancePaise`, `*Paise` invoice/course/component/payment equivalents); compute `balancePaise = totalPaise - paidPaise` in integer Paise; rupee display converts only at the presentation edge via a single shared helper
    - Apply the migration via the Mini_Gate process and make it idempotent so repeated runs produce the same persisted result and modify zero records after the first execution
    - _Requirements: 10.2, 1.1, 1.2, 1.3, 1.10_

  - [x] 15.2 Close RID compliance gaps and harden tenant resolution on write paths
    - Bring each id-generation site recorded non-compliant in Phase 0 into compliance with the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}` via the shared RID generator, replacing any bare `Uuid().v4()` on a touched write path
    - Resolve `Tenant_Id` from the authenticated session on every write (no hardcoded literal); if the tenant is unresolved, reject the operation, perform no read/write, leave persisted data unchanged, and return an unresolved-tenant error
    - _Requirements: 10.1, 1.4, 1.6, 1.7_

  - [x] 15.3 Route every write path through `AcValidators` with strict fee validation
    - Route every School_System write path through `AcValidators` before persistence; validate that a saved fee entry links to an existing student record and an existing class record scoped to the active `Tenant_Id` before any data is persisted
    - Extend/replace `validateFeeAmount` with an integer-Paise validator whose lower bound is strictly positive; a null, non-numeric, zero, or negative amount rejects the save, persists nothing, retains entered values, and shows an error on the amount field; any validation failure (including invalid student/class linkage) rejects the write, leaves any prior record unchanged, retains entered values, and identifies the invalid field or linkage
    - _Requirements: 10.3, 10.4, 10.5, 10.6_

  - [ ]* 15.4 Write property test for the integer-Paise money path
    - **Property 1: Money is integer Paise**
    - **Validates: Requirements 1.1, 1.2, 8.6, 10.2**

  - [ ]* 15.5 Write property test for well-formed RID identifiers
    - **Property 2: RID identifiers are well-formed**
    - **Validates: Requirements 1.4, 8.6, 10.1**

  - [ ]* 15.6 Write property test for unresolved-tenant abort
    - **Property 4: Unresolved tenant aborts the operation**
    - **Validates: Requirements 1.7**

  - [ ]* 15.7 Write property test for migration idempotency
    - **Property 5: Migrations are idempotent**
    - **Validates: Requirements 1.10**

  - [ ]* 15.8 Write property test for write-path validation rejection
    - **Property 16: Write-path validation rejects invalid input without side effects**
    - **Validates: Requirements 10.3, 10.5, 10.6**

- [x] 16. Checkpoint — Phase 7
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, confirm Mini_Gate sign-off for the paise migration, ensure all validation/money/ID tests pass, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 17. Phase 8 — Fee receipt template (Requirement 11)

  - [x] 17.1 Return a dedicated `Fee_Receipt_Template` for schoolErp
    - In `lib/features/onboarding/bill_template_system.dart`, make `getTemplate` return a new dedicated `Fee_Receipt_Template` for `BusinessType.schoolErp` instead of `_serviceTemplate`; update the sample-items switch for schoolErp in lockstep
    - For every other business type, `getTemplate` returns the identical template it returned before (only the `schoolErp` case changes)
    - _Requirements: 11.1, 11.4_

  - [x] 17.2 Render student, class, per-fee-head breakdown, and paise-formatted amounts with placeholders
    - Render the student name, the class, and a per-fee-head breakdown where each fee head is a separate line item with its own label and amount; convert each integer-Paise value (paid amount, due amount, every per-fee-head amount) to its rupee value with exactly two decimal places via the shared helper
    - When the student name, class, or breakdown is missing/empty, render a fixed placeholder string in its place while the remaining fields still render without error; a breakdown with zero fee-head line items renders the breakdown section containing the placeholder and still renders the paid and due amounts
    - _Requirements: 11.2, 11.3, 11.5, 11.6_

  - [ ]* 17.3 Write property test for fee-receipt rendering with placeholders
    - **Property 17: Fee receipt renders student, class, and per-head breakdown with placeholders**
    - **Validates: Requirements 11.2, 11.5, 11.6**

  - [ ]* 17.4 Write property test for paise two-decimal formatting
    - **Property 18: Paise values format to exactly two decimal places**
    - **Validates: Requirements 11.3**

  - [ ]* 17.5 Write example test for template dispatch
    - Assert `getTemplate(schoolErp)` returns the `Fee_Receipt_Template`, not `_serviceTemplate`
    - _Requirements: 11.1_

- [x] 18. Checkpoint — Phase 8
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, document per-vertical regression result for `bill_template_system.dart`, output `PHASE 8 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 19. Phase 9 — Dead code and duplicate cleanup (Requirement 12)

  - [x] 19.1 Reference-search each deletion candidate and record results before any removal
    - For the `/ac/students` collision residue, the flagged `SchoolErpModule.navItems` redundancy, and the redundant `/ac/fees` `LegacyRouteRedirect`, run a repository-wide reference search and record in the Phase_Report the search scope, the exact path/symbol, and the live-reference count (a live reference is any reference outside the candidate's own definition file and outside generated `.freezed.dart`/`.g.dart` files)
    - If one or more live references exist, do not delete the candidate, retain it unchanged, and record each live reference (file path + line)
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [x] 19.2 Delete only zero-reference candidates after recorded sign-off
    - When a search confirms zero live references, perform the deletion only after explicit sign-off per Requirement 1.9 and record the sign-off identity and timestamp in the Phase_Report
    - If a deletion is attempted without a recorded zero-reference result and recorded sign-off, block the deletion and record the missing prerequisite in the Phase_Report
    - _Requirements: 12.5, 12.6_

- [x] 20. Checkpoint — Phase 9
  - List files created/modified/deleted, run `flutter analyze` + tests on touched files, confirm every deletion has a recorded zero-reference result and sign-off, output `PHASE 9 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

- [x] 21. Phase 10 — End-to-end verification and final report (Requirement 13)

  - [x] 21.1 Run the full lint/analyze step and full test suite and record counts
    - Run the full `flutter analyze` step and the full test suite; record total, passed, and failed counts for both in the final Phase_Report
    - If the lint/analyze error count or test fail count is greater than zero, record a Fail status and enumerate each failure
    - _Requirements: 13.1, 13.2_

  - [x] 21.2 Produce the Verification_Matrix and capability-wiring confirmation
    - Map every audit finding to exactly one of Resolved, Partially-Resolved, Deferred, or Out-of-Scope, with none unmapped and none multiply-assigned; cite evidence (test output, search output, or changed location) for each Resolved/Partially-Resolved entry
    - Confirm that `businessCapabilityRegistry['schoolErp']` grants are read by the live schoolErp UI and record a pass/fail; list every pending human decision (deferred Phase 4 policy, pending Mini_Gate, deletion sign-off) with its status
    - _Requirements: 13.3, 13.4, 13.5, 13.6_

  - [x] 21.3 Record the per-non-school-vertical regression result
    - Record a pass/fail per business type other than `schoolErp`, where pass means the sidebar, dashboard, quick actions, and alerts widget resolve unchanged behavior; record a fail identifying the affected surface and business type for any changed behavior
    - _Requirements: 13.7, 13.8_

- [x] 22. Final checkpoint — Phase 10
  - Confirm the Verification_Matrix is complete with every finding mapped, all tests pass, and every non-school vertical passes the regression check; output `PHASE 10 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and are not auto-implemented; they may be skipped for a faster MVP but are recommended for the universal correctness properties.
- Each task references specific granular requirements for traceability.
- Property tests validate the universal Correctness Properties from the design (Properties 1–18), run a minimum of 100 iterations, and are tagged `Feature: schoolerp-vertical-remediation, Property {n}: {text}`.
- Example, widget, integration, and governance checks cover the non-property criteria (Phase 0/4/9/10 artifacts, UI states, template dispatch, capability wiring, regression suite).
- Checkpoints enforce the phased STOP-GATE protocol: each phase ends with `PHASE N COMPLETE — AWAITING APPROVAL` and resumes only on the literal `APPROVED`. Schema/`UserRole`/Drift-table changes (Mini_Gate) and hard deletions (reference search + sign-off) require their own explicit approval.
- The strategic directive is integrate, never rebuild: every wired screen references an existing `Ac*Screen` widget.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["3.1", "3.2"] },
    { "id": 2, "tasks": ["3.3"] },
    { "id": 3, "tasks": ["3.4", "3.5", "3.6", "3.7"] },
    { "id": 4, "tasks": ["5.1", "5.2", "5.3", "5.4"] },
    { "id": 5, "tasks": ["5.5", "5.6", "5.7"] },
    { "id": 6, "tasks": ["7.1"] },
    { "id": 7, "tasks": ["7.2"] },
    { "id": 8, "tasks": ["7.3", "7.4"] },
    { "id": 9, "tasks": ["9.1"] },
    { "id": 10, "tasks": ["9.2"] },
    { "id": 11, "tasks": ["9.3"] },
    { "id": 12, "tasks": ["11.1", "11.2"] },
    { "id": 13, "tasks": ["11.3", "11.4"] },
    { "id": 14, "tasks": ["11.5", "11.6", "11.7", "11.8"] },
    { "id": 15, "tasks": ["13.1", "13.2"] },
    { "id": 16, "tasks": ["15.1", "15.2"] },
    { "id": 17, "tasks": ["15.3"] },
    { "id": 18, "tasks": ["15.4", "15.5", "15.6", "15.7", "15.8"] },
    { "id": 19, "tasks": ["17.1", "17.2"] },
    { "id": 20, "tasks": ["17.3", "17.4", "17.5"] },
    { "id": 21, "tasks": ["19.1", "19.2"] },
    { "id": 22, "tasks": ["21.1", "21.2", "21.3"] }
  ]
}
```
