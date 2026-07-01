# Requirements Document

## Introduction

The DukanX `schoolErp` business vertical (`BusinessType.schoolErp`, "School ERP") already ships a substantial, working feature set under `lib/features/academic_coaching/` — roughly 34 `Ac*Screen` widgets (dashboard, students, admissions, fee collection, attendance, exams, report cards, timetable, transport, hostel, library, certificates, ID cards, and more), a single repository `ac_repository.dart`, a validator utility `ac_validators.dart`, a thermal print service, and a set of `/ac/*` named routes guarded for `schoolErp`. However, this feature set is **disconnected** from the live schoolErp shell. The sidebar dispatcher `_getSectionsForBusiness` in `sidebar_configuration.dart` has no `case BusinessType.schoolErp` and therefore falls through to `default: _getRetailSections()`, so a school operator sees a generic retail sidebar and cannot reach any `Ac*Screen` from normal navigation. The dashboard quick actions and alerts widgets carry no school-specific, real-data wiring; the bill template system returns the generic `_serviceTemplate` for schoolErp instead of a fee receipt; and the `/ac/*` routes are guarded by generic permissions rather than school-specific ones.

The strategic directive for this remediation is **integrate the existing code, not rebuild or delete working screens**. The `Ac*Screen` widgets and `ac_repository.dart` are treated as assets to wire up, not liabilities to replace. Work proceeds strictly in phase order (Phase 0 through Phase 10). Phase 0 is read-only re-verification and gap discovery that resolves every audit assumption to CONFIRMED, FALSIFIED, or still-unverified. Each subsequent phase ends with an explicit STOP GATE requiring human sign-off before the next begins. All work is bound by a set of non-negotiable cross-cutting constraints (integer-paise money, RID id pattern, tenant scoping on every query, no schema changes without a mini-gate, no hard deletes without grep + sign-off, idempotent migrations, and a post-phase regression pass that protects every other business type).

The vertical is referred to throughout as the **School_System**. Requirements are grouped by the phase that delivers them and map back to the audit areas they remediate. Two product/legal decision areas — minors' PII and compliance (Phase 4) — and the RBAC enum question (Phase 3) are gated behind explicit human confirmation because they are not purely engineering choices.

## Glossary

- **School_System**: The schoolErp business vertical of the DukanX Flutter app, encompassing its screens, repository, validators, providers, services, routes, capabilities, dashboard widgets, sync handler, and sidebar configuration. Identified by `BusinessType.schoolErp`.
- **Academic_Coaching_Feature**: The existing code under `lib/features/academic_coaching/` — the ~34 `Ac*Screen` widgets, `ac_repository.dart`, `ac_validators.dart`, `ac_models.dart`, `ac_providers.dart`, and `ac_thermal_print_service.dart` that implement School_System functionality.
- **Ac_Repository**: `lib/features/academic_coaching/data/repositories/ac_repository.dart` — the single repository for student, fee, attendance, exam, and related school data reads and writes.
- **Ac_Validators**: `lib/features/academic_coaching/utils/ac_validators.dart` — the School_System input/validation utility extended in Phase 7.
- **Ac_Screen**: Any `Ac*Screen` widget under `lib/features/academic_coaching/presentation/screens/` (for example `AcDashboardScreen`, `AcStudentsScreen`, `AcStudentRegistrationScreen`, `AcFeeCollectionScreen`, `AcAttendanceScreen`, `AcExamsScreen`).
- **Sidebar_Configuration**: `lib/widgets/desktop/sidebar_configuration.dart` — defines per-business-type `SidebarSection`/`SidebarMenuItem` lists via `_getSectionsForBusiness`. A shared component spanning 14+ verticals. schoolErp currently falls through to `default: _getRetailSections()`.
- **Sidebar_Navigation_Handler**: `lib/widgets/desktop/sidebar_navigation_handler.dart` — resolves a sidebar item id to a screen widget.
- **Sidebar_Sections_Provider**: `sidebarSectionsProvider` — the live provider that supplies the filtered sidebar section list to the desktop shell; treated as the single source of truth for navigation.
- **App_Router**: the legacy `MaterialApp routes:` registration table (`buildAppRoutes()`) that is the live source of truth for named routes, including the `/ac/*` entries.
- **Go_Router_Table**: the dormant GoRouter route mappings for `/ac/*` that are not mounted by the live app; aligned but never activated by this remediation.
- **Nav_Items**: module-registry `navItems` for the academic/coaching module, which have no live UI consumer; flagged as redundant but not deleted within this remediation except via the Phase 9 cleanup process.
- **Quick_Actions**: `lib/features/dashboard/v2/widgets/business_quick_actions.dart` — dashboard quick-action buttons resolved per `BusinessType`. A shared component.
- **Alerts_Widget**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` — dashboard alert-count widget resolved per `BusinessType`. A shared component.
- **Ac_Dashboard_Stats**: the KPI statistics structure surfaced by `AcDashboardScreen` / Ac_Repository used to populate dashboard KPI cards.
- **Business_Capability_Registry**: `businessCapabilityRegistry` in `lib/core/isolation/business_capability.dart` — the capability registry whose `schoolErp` entry grants the school vertical capabilities (for example `useStudentRegistry`, `useFeeCollection`).
- **School_Permissions**: a new scoped permission layer (for example `viewFees`, `viewStudents`, `collectFees`, `markAttendance`, `enterMarks`, `viewStudentPII`, `exportStudentPII`) mapping onto existing user roles without modifying the global `UserRole` enum.
- **User_Role_Enum**: the global `UserRole` enum; an enum change is a schema change requiring a Mini_Gate.
- **School_Sync_Handler**: `SchoolErpSyncHandler` — the offline sync handler that currently syncs `school_students` and is extended to fees, attendance, and exams.
- **Drift_Cache**: the local Drift-backed cache for students, fees, and attendance, mirroring the offline caching pattern used by other verticals.
- **WebSocket_Events**: the realtime events `school.fee.due`, `school.attendance.marked`, and `school.exam.result`, consumed by mirroring the existing `inventory.*` consumption pattern.
- **Bill_Template_System**: `lib/features/onboarding/bill_template_system.dart` — the per-business-type bill/receipt template selector that currently returns `_serviceTemplate` for `schoolErp`.
- **Fee_Receipt_Template**: the dedicated schoolErp receipt template added in Phase 8 (student name, class, fee-head breakdown, paid/due amounts in Paise).
- **Tenant_Id**: the authenticated business identity used to scope every read, write, and sync call. No hardcoded `'SYSTEM'` or other tenant literal is permitted.
- **Paise**: integer representation of currency (1 rupee = 100 Paise). All money values in touched School_System code are integer Paise.
- **RID**: the new-entity identifier pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, where `tenantId` is the active Tenant_Id, `timestamp_ms` is the Unix epoch time in milliseconds, and `uuid_v4_short` is a non-empty shortened form of a UUID version 4.
- **Orphaned_Screen**: any `Ac_Screen` that exists in the codebase but is not reachable from the live schoolErp navigation; each is rated Production-Ready, Needs-Work, or Stale during verification.
- **Production_Ready / Needs_Work / Stale**: the three orphaned-screen ratings — Production-Ready (wire route + permission + sidebar), Needs-Work (report gaps, do not wire), Stale (grep for references, then flag for deletion pending sign-off).
- **Shared_Component**: a cross-vertical file (`sidebar_configuration.dart`, `business_quick_actions.dart`, `business_alerts_widget.dart`, `business_capability.dart`, `bill_template_system.dart`, route tables) that spans more than one business type.
- **Verification_Report**: the read-only Markdown artifact produced in Phase 0 documenting tenant-scoping reality, RID compliance, paise compliance, endpoint reality, and orphaned-screen ratings, containing zero code changes.
- **Verification_Matrix**: the Phase 10 Markdown artifact mapping every audit finding to exactly one of Resolved, Partially-Resolved, Deferred, or Out-of-Scope.
- **Stop_Gate**: a point at which School_System work for a phase stops and waits for explicit human approval before continuing. Emitted as the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and resumed only on the literal reply `APPROVED`.
- **Mini_Gate**: a separate, explicit sign-off required before any schema change (including a `UserRole` enum change or DynamoDB table-shape change) or any hard deletion, accompanied by the proposed change, every consumer it affects, and a migration or removal plan.
- **Phase_Report**: the written deliverable produced at the end of each phase listing files touched, exact changes, verification steps run, and the mapping from each change to the audit finding it addresses.

## Requirements

### Requirement 1: Cross-Cutting Non-Negotiable Constraints

**User Story:** As the platform owner, I want every change in this remediation to honor the platform's money, identity, tenant-isolation, and safety invariants, so that the School_System integrates without introducing currency errors, data leakage, or destructive side effects.

#### Acceptance Criteria

1. WHERE money values are represented in code created or modified by this remediation, THE School_System SHALL store and transmit currency as integer Paise.
2. THE School_System SHALL NOT introduce `double`, `float`, or decimal floating-point types for currency values in code created or modified by this remediation.
3. IF this remediation touches an existing floating-point currency field, THEN THE School_System SHALL migrate it to integer Paise only via the Mini_Gate process and SHALL NOT alter it silently.
4. WHEN the School_System creates a new entity identifier, THE School_System SHALL generate it using the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, where `tenantId` is the active Tenant_Id, `timestamp_ms` is the Unix epoch time in milliseconds, and `uuid_v4_short` is a non-empty shortened form of a UUID version 4.
5. WHERE the School_System reads, writes, or synchronizes school data, THE School_System SHALL scope every query, repository call, and sync call by the active Tenant_Id.
6. THE School_System SHALL NOT use a hardcoded tenant literal such as `'SYSTEM'`, and SHALL resolve the Tenant_Id from the authenticated session for every read and write.
7. IF the Tenant_Id is missing or cannot be resolved, THEN THE School_System SHALL reject the operation, perform no read or write, leave persisted data unchanged, and return an error indicating an unresolved tenant.
8. IF a change requires a schema change, including a `UserRole` enum change or a DynamoDB table-shape change, THEN THE School_System SHALL halt and request a Mini_Gate that states the proposed change, lists every consumer of the changed symbol, and presents a migration plan, before applying the change.
9. IF a change requires a hard deletion of a file, route, screen, or code symbol, THEN THE School_System SHALL first run a repository-wide reference search for that symbol, record the result and an explicit deletion request in the Phase_Report, and SHALL NOT perform the deletion until the literal reply `APPROVED` is received.
10. WHERE the School_System applies a data migration, THE School_System SHALL make the migration idempotent such that repeated executions produce the same persisted result and modify zero records after the first execution.
11. WHEN the School_System modifies a Shared_Component, THE School_System SHALL make additive edits scoped to the `schoolErp` case only and SHALL preserve the behavior of every business type other than `schoolErp`.
12. THE School_System SHALL NOT modify the sidebar sections, quick actions, alerts, capability set, or bill template of any business type other than `schoolErp`.
13. WHEN a phase of this remediation is completed, THE School_System SHALL run the existing lint/analyze step and the existing test suite on the touched code and SHALL record in the Phase_Report the lint/analyze error count and the test pass and fail counts.
14. IF the recorded lint/analyze error count or the recorded test fail count is greater than zero, THEN THE School_System SHALL NOT mark the phase complete and SHALL resolve the failures before emitting the Stop_Gate.
15. WHEN a phase of this remediation is completed, THE School_System SHALL confirm that the sidebar, dashboard, quick actions, and alerts widget of every business type other than `schoolErp` resolve unchanged behavior, and SHALL record a pass or fail result per affected business type.
16. WHEN a phase of this remediation is completed and criteria 13 through 15 are satisfied, THE School_System SHALL emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL` and SHALL perform no further phase work until the literal reply `APPROVED` is received.

### Requirement 2: Scope Boundary

**User Story:** As a maintainer, I want the remediation boundary fixed in advance, so that the work stays surgical and integrates existing code instead of expanding into rewrites or out-of-scope migrations.

#### Acceptance Criteria

1. THE School_System SHALL restrict code changes — create, modify, or delete — to exactly these locations: files under `lib/features/academic_coaching/*`, the `schoolErp` case within Shared_Components, the offline sync handler for schoolErp, and the navigation entries (route registration and sidebar/menu wiring) required to make `Ac_Screen` widgets reachable.
2. THE School_System SHALL integrate the existing Academic_Coaching_Feature code rather than rebuilding or replacing it.
3. IF an `Ac_Screen` widget or Ac_Repository compiles without errors under the project's analyze step and passes the existing tests, THEN THE School_System SHALL treat it as working and SHALL NOT rebuild or replace it.
4. THE School_System SHALL NOT migrate the application off `MaterialApp.routes` onto GoRouter, and SHALL treat any app-wide GoRouter migration as a separate out-of-scope initiative.
5. THE School_System SHALL exclude the standalone `school_admin_app/`, `school_teacher_app/`, `school_student_app/`, and `school_common/` projects from scope and SHALL NOT modify them.
6. WHEN the School_System fixes sidebar or navigation behavior, THE School_System SHALL scope the fix to the `schoolErp` case such that every other vertical's route registrations and sidebar/menu sections remain identical to their pre-change state.
7. IF a proposed change falls outside the boundary defined in criterion 1, THEN THE School_System SHALL not apply the change, SHALL leave existing files unmodified, and SHALL surface a request for explicit sign-off identifying the specific out-of-scope change before proceeding.

### Requirement 3: Phase 0 — Re-Verification and Gap Discovery (Read-Only)

**User Story:** As a maintainer, I want every audit assumption re-verified against the live codebase before any code change, so that subsequent phases act on confirmed facts rather than stale assumptions.

#### Acceptance Criteria

1. WHILE executing Phase 0, THE School_System SHALL create, modify, and delete zero files other than the single Verification_Report artifact, and SHALL NOT modify any application source, configuration, or build file.
2. THE Verification_Report SHALL record the result of a repository-wide search for hardcoded `vendorId`, `tenantId`, or `'SYSTEM'` literals within `lib/features/academic_coaching/*`, citing file path and line number for each occurrence found, and SHALL explicitly record "none found" when the search returns zero occurrences.
3. THE Verification_Report SHALL classify whether every write path in Ac_Repository threads the active Tenant_Id as exactly one of fully-threaded or has-gaps, listing each write method with its tenant-scoping status, file path, and line number, and SHALL explicitly record "no write methods found" when Ac_Repository exposes zero write paths.
4. THE Verification_Report SHALL classify whether every new-entity identifier created by the Academic_Coaching_Feature complies with the RID pattern as exactly one of compliant or non-compliant, listing each non-compliant id-generation site with file path and line number, and SHALL explicitly record "no non-compliant sites found" when every id-generation site complies.
5. THE Verification_Report SHALL classify whether money is represented as integer Paise end-to-end across the Academic_Coaching_Feature as exactly one of paise-consistent or has-ambiguity, listing each rupee/paise-ambiguous field with file path and line number, and SHALL explicitly record "no ambiguous fields found" when every money field is integer Paise.
6. IF `ac_validators.dart` exists, THEN THE Verification_Report SHALL record its presence and enumerate each validation function it currently provides with file path and line number; IF `ac_validators.dart` does not exist, THEN THE Verification_Report SHALL explicitly record its absence.
7. THE Verification_Report SHALL classify each `/ac/*` endpoint required by an `Ac_Screen` as exactly one of deployed, not-deployed, or unverified, recording the observed request path for endpoints classified deployed and recording the expected request path for endpoints classified not-deployed or unverified.
8. THE Verification_Report SHALL assign every Orphaned_Screen a rating of exactly one of Production-Ready, Needs-Work, or Stale, with a one-line justification and the file path for each screen.
9. WHERE the Verification_Report records a previously unverified audit assumption, THE Verification_Report SHALL mark that assumption as exactly one of CONFIRMED, FALSIFIED, or still-unverified with supporting file path and line number.
10. WHEN Phase 0 completes, THE Verification_Report SHALL contain a recorded result for every check defined in criteria 2 through 9 with no checked item left unclassified.
11. IF a Ground Truth assumption is contradicted by the live codebase, THEN THE School_System SHALL halt Phase 0, report the discrepancy in the Verification_Report, and SHALL NOT route around the contradiction.

### Requirement 4: Phase 1 — Routing and Navigation Wiring

**User Story:** As a school operator, I want a dedicated schoolErp sidebar whose items open the existing `Ac_Screen` widgets, so that I can reach every school feature from normal navigation instead of a generic retail sidebar.

#### Acceptance Criteria

1. WHEN `_getSectionsForBusiness` is called with `BusinessType.schoolErp`, THE Sidebar_Configuration SHALL return the section list produced by a new `_getSchoolSections()` function via an explicit `case BusinessType.schoolErp`, and SHALL NOT fall through to `default: _getRetailSections()`.
2. WHEN `_getSectionsForBusiness` is called with `BusinessType.schoolErp`, THE Sidebar_Configuration SHALL return school-specific sections in which every item carries a label containing at least one non-whitespace character.
3. WHEN `_getSectionsForBusiness` is called with `BusinessType.schoolErp`, THE Sidebar_Configuration SHALL return only items whose navigation target resolves via Sidebar_Navigation_Handler to an existing `Ac_Screen`, with no item pointing to a route that lacks a registered screen or resolves to a placeholder screen.
4. THE Sidebar_Navigation_Handler SHALL map each schoolErp sidebar item id to exactly one corresponding existing `Ac_Screen` widget.
5. IF a schoolErp sidebar item id cannot be resolved to an `Ac_Screen`, THEN THE Sidebar_Navigation_Handler SHALL retain the current screen, perform no navigation, surface an indication that the destination is unavailable, and raise no unhandled exception.
6. WHEN the `/ac/students` path collision between `AcStudentsScreen` and `AcStudentRegistrationScreen` is resolved, THE School_System SHALL bind `/ac/students` to the screen recorded as more feature-complete in the Phase 0 Verification_Report and SHALL assign the other screen a distinct path that does not collide with any other live `/ac/*` binding.
7. THE School_System SHALL align each dormant Go_Router_Table `/ac/*` entry to reference the same target as its live route binding without activating GoRouter.
8. THE School_System SHALL source schoolErp navigation items only from Sidebar_Sections_Provider, treating it as the single source of truth for schoolErp navigation.
9. WHERE the Nav_Items for the academic/coaching module duplicate navigation already provided by Sidebar_Sections_Provider, THE School_System SHALL flag the Nav_Items redundancy in the Phase_Report and SHALL NOT delete the Nav_Items in this phase.
10. WHEN `_getSectionsForBusiness` is called with any `BusinessType` other than `schoolErp`, THE Sidebar_Configuration SHALL return sections identical to those returned prior to the `case BusinessType.schoolErp` addition.

### Requirement 5: Phase 2 — Dashboard, Quick Actions, and Alerts with Real Data

**User Story:** As a school operator, I want the dashboard quick actions, alerts, and KPI cards to reflect real tenant-scoped data, so that I can act on accurate counts instead of hardcoded placeholders.

#### Acceptance Criteria

1. WHEN Quick_Actions resolves actions for `BusinessType.schoolErp`, THE Quick_Actions SHALL present exactly the four actions Collect Fee, New Admission, Mark Attendance, and Enter Marks, each navigating to the corresponding existing `Ac_Screen`.
2. WHEN Alerts_Widget resolves alerts for `BusinessType.schoolErp`, THE Alerts_Widget SHALL present exactly the three alerts Fees Due, Absentees Today, and Upcoming Exams, each backed by a real tenant-scoped query through Ac_Repository.
3. THE Alerts_Widget SHALL NOT display any hardcoded count for a schoolErp alert, and SHALL derive every displayed count from a live query result.
4. WHEN the schoolErp dashboard renders, THE School_System SHALL surface the Ac_Dashboard_Stats KPI cards, each populated with a non-negative integer derived from a tenant-scoped query for the active Tenant_Id.
5. WHEN a `school.fee.due`, `school.attendance.marked`, or `school.exam.result` WebSocket_Event is received for the active Tenant_Id, THE School_System SHALL update the corresponding dashboard alert or KPI by mirroring the existing `inventory.*` event consumption pattern.
6. IF a `school.fee.due`, `school.attendance.marked`, or `school.exam.result` WebSocket_Event is received for a tenant other than the active Tenant_Id, THEN THE School_System SHALL ignore the event and SHALL NOT update any displayed alert or KPI.
7. IF a tenant-scoped dashboard or alert query returns no data, THEN THE School_System SHALL display a zero or empty-state indicator rather than a fabricated or placeholder count.
8. WHILE a tenant-scoped dashboard or alert query is in progress, THE School_System SHALL display a loading indicator for the affected alert or KPI.
9. IF a tenant-scoped dashboard or alert query fails, THEN THE School_System SHALL present an error indication for the affected alert or KPI and SHALL NOT display a fabricated count.
10. WHEN the School_System modifies Quick_Actions or Alerts_Widget, THE School_System SHALL make the change additively within the `schoolErp` case and SHALL NOT alter the actions or alerts resolved for any other business type.

### Requirement 6: Phase 3 — RBAC and Scoped School Permissions

**User Story:** As a security owner, I want school screens guarded by school-specific permissions mapped onto existing roles, so that access control is meaningful without changing the global role enum.

#### Acceptance Criteria

1. IF a change to the global `UserRole` enum is proposed, THEN THE School_System SHALL leave the enum unchanged and SHALL emit a Mini_Gate request before any such change is applied.
2. THE School_System SHALL implement a scoped School_Permissions layer that maps one or more existing user roles to each school-specific permission without adding, removing, renaming, or reordering any value of the `UserRole` enum.
3. THE School_System SHALL guard every `/ac/*` route with a school-specific permission such that no `/ac/*` route retains a `viewInvoices` or `viewClients` guard.
4. WHEN an authenticated user holding the required School_Permission navigates to a guarded `/ac/*` route, THE School_System SHALL resolve the route to the corresponding `Ac_Screen` without redirecting.
5. IF an authenticated user lacking the required School_Permission navigates to a guarded `/ac/*` route, THEN THE School_System SHALL block access, render no part of the guarded `Ac_Screen`, redirect the user to the application's default authorized landing screen, and present an indication that access was denied.
6. IF a guarded `/ac/*` route has no School_Permission mapping defined, THEN THE School_System SHALL deny access and redirect the user to the application's default authorized landing screen.
7. WHEN the School_System applies School_Permissions, THE School_System SHALL scope the change to schoolErp routes and SHALL NOT change the guard of any route belonging to another business type.

### Requirement 7: Phase 4 — Minors' PII and Compliance (Policy Stop)

**User Story:** As a compliance owner, I want minors' personal data governed by confirmed retention, consent, access, and audit policies before any related code is written, so that the School_System meets legal obligations for children's data.

#### Acceptance Criteria

1. WHILE any of the data retention period, consent mechanism, authorized-role list, or audit-logging policy is unconfirmed, THE School_System SHALL treat Phase 4 as a hard stop and SHALL NOT implement minors' PII handling code.
2. THE School_System SHALL treat a policy decision as confirmed only when a sign-off is recorded that identifies the decision, the agreed value, the confirming compliance owner, and the confirmation timestamp.
3. THE School_System SHALL record a defined data retention period for minors' personally identifiable information and SHALL request explicit confirmation of that period before implementation.
4. THE School_System SHALL define a parent or guardian consent mechanism for collecting and processing minors' personally identifiable information and SHALL request explicit confirmation of that mechanism before implementation.
5. THE School_System SHALL define the list of roles authorized to view or export minors' personally identifiable information and SHALL request explicit confirmation of that list before implementation.
6. WHEN a user views or exports a minor's personally identifiable information, THE School_System SHALL write a per-record audit log entry capturing the acting user, the record accessed, the action type as one of view or export, and the timestamp, scoped by Tenant_Id.
7. IF a user whose role is not in the confirmed authorized-role list attempts to view or export a minor's personally identifiable information, THEN THE School_System SHALL deny the operation, return and export no data, and write an audit log entry recording the denied attempt.
8. THE School_System SHALL verify, per DynamoDB table storing minors' personally identifiable information, whether encryption-at-rest is enabled and SHALL record the boolean result for each table in the Phase_Report.
9. IF any Phase 4 policy decision remains unconfirmed, THEN THE School_System SHALL NOT proceed to implement minors' PII handling code and SHALL surface each unconfirmed decision by name for sign-off.

### Requirement 8: Phase 5 — Offline Sync and Real-Time Consistency

**User Story:** As a school operator working with intermittent connectivity, I want students, fees, and attendance cached locally and synced reliably, so that the app stays usable offline and does not double-apply updates on reconnect.

#### Acceptance Criteria

1. THE School_System SHALL add Drift_Cache local caching for students, fees, and attendance, mirroring the offline caching pattern used by other verticals, and SHALL NOT return a record belonging to a Tenant_Id other than the active Tenant_Id from the cache.
2. THE School_System SHALL extend School_Sync_Handler beyond `school_students` to also synchronize fees, attendance, and exams.
3. WHEN connectivity is restored after an offline period, THE School_System SHALL reconcile local and remote state such that each record, identified by its RID, has exactly one stored version and no duplicate is produced.
4. WHEN the same change identified by its RID is applied more than once, THE School_System SHALL produce the same persisted result as a single application.
5. WHEN a WebSocket_Event and an offline sync operation both target the same record, THE School_System SHALL serialize the operations, apply the change at most once, and reach a single resulting version independent of arrival order.
6. WHERE the School_System persists data locally, THE School_System SHALL store currency fields as integer Paise and identifiers in the RID pattern, consistent with Requirement 1.
7. IF a sync operation fails for a record, THEN THE School_System SHALL retain that record's pending local change, leave successfully synced records unaffected, and retry the failed record on the next connectivity-restored event without discarding it.

### Requirement 9: Phase 6 — Orphaned Screen Disposition

**User Story:** As a maintainer, I want each orphaned school screen handled according to its readiness rating, so that production-ready features become reachable while incomplete and stale screens are handled safely.

#### Acceptance Criteria

1. WHERE an Orphaned_Screen is rated Production-Ready in Phase 0, THE School_System SHALL make it reachable from schoolErp navigation by adding exactly one route, one School_Permission guard, and one sidebar entry for it.
2. WHEN an Orphaned_Screen is wired into navigation, THE School_System SHALL record in the Phase_Report the screen identifier, its route, its guard permission name, and its sidebar label.
3. WHERE an Orphaned_Screen is rated Needs-Work in Phase 0, THE School_System SHALL record its specific gaps as discrete items in the Phase_Report and SHALL NOT add any route, guard, or sidebar entry for it.
4. WHERE an Orphaned_Screen is rated Stale in Phase 0, THE School_System SHALL run a reference search across the schoolErp source tree, record the resulting reference count and file paths, and flag the screen for deletion in the Phase_Report without deleting it.
5. IF a Stale screen is flagged for deletion, THEN THE School_System SHALL NOT delete it until explicit sign-off is received per Requirement 1.
6. WHEN an Orphaned_Screen is wired into navigation, THE School_System SHALL reference the existing screen widget and SHALL NOT copy or rebuild it.

### Requirement 10: Phase 7 — Data Validation and Money/ID Compliance

**User Story:** As a school operator, I want fee entries validated and money and identifiers consistent across every write path, so that records are accurate and free of currency and linkage errors.

#### Acceptance Criteria

1. WHERE the Phase 0 Verification_Report recorded an RID compliance gap, THE School_System SHALL resolve the gap via the Mini_Gate process and SHALL bring the affected id-generation site into compliance with the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
2. WHERE the Phase 0 Verification_Report recorded a rupee/paise ambiguity on a screen, THE School_System SHALL resolve the ambiguity so that the screen represents currency as integer Paise.
3. WHEN a fee entry is saved, THE School_System SHALL validate that the entry links to an existing student record and an existing class record scoped to the active Tenant_Id before any data is persisted.
4. THE School_System SHALL route every School_System write path through Ac_Validators so that each write validates its input before persistence.
5. IF a fee entry's amount is null, non-numeric, zero, or negative in integer Paise, THEN THE School_System SHALL reject the save, persist nothing, retain the entered values, and present an error indication on the amount field.
6. IF a write-path input fails validation, including an invalid student or class linkage, THEN THE School_System SHALL reject the write, leave any previously stored record unchanged, retain the entered values without clearing them, and present an error indication identifying the invalid field or linkage.

### Requirement 11: Phase 8 — Fee Receipt Template

**User Story:** As a school operator, I want printed fee receipts to use a dedicated school template, so that receipts show the student, class, and fee breakdown instead of a generic service layout.

#### Acceptance Criteria

1. WHEN Bill_Template_System resolves a template for `BusinessType.schoolErp`, THE Bill_Template_System SHALL return the dedicated Fee_Receipt_Template and SHALL NOT return the generic `_serviceTemplate` fallback.
2. WHEN the Fee_Receipt_Template renders a fee receipt, THE Fee_Receipt_Template SHALL render the student name, the class, and a per-fee-head breakdown in which each fee head is listed as a separate line item with its own label and amount.
3. WHEN the Fee_Receipt_Template renders monetary values, THE Fee_Receipt_Template SHALL convert each integer-paise value (paid amount, due amount, and every per-fee-head amount) to its rupee value displayed with exactly two decimal places.
4. WHEN Bill_Template_System resolves a template for any business type other than `schoolErp`, THE Bill_Template_System SHALL return the identical template it returned prior to this change.
5. IF a required receipt field (student name, class, or per-fee-head breakdown) is missing or empty for a fee record, THEN THE Fee_Receipt_Template SHALL render a fixed placeholder string in place of that field and SHALL render the remaining receipt fields without raising an error.
6. IF the per-fee-head breakdown for a fee record contains zero fee-head line items, THEN THE Fee_Receipt_Template SHALL render the breakdown section containing the fixed placeholder string and SHALL still render the paid amount and the due amount.

### Requirement 12: Phase 9 — Dead Code and Duplicate Cleanup

**User Story:** As a maintainer, I want confirmed dead code and duplicates removed only after reference verification, so that the codebase is cleaner without risking accidental breakage.

#### Acceptance Criteria

1. WHEN the School_System finalizes the `/ac/students` collision resolution, THE School_System SHALL run a reference search across the entire repository for the removed path or symbol and SHALL record in the Phase_Report the search scope, the exact path or symbol searched, and the resulting reference count before any removal occurs.
2. WHEN the School_System addresses the Nav_Items redundancy flagged in Phase 1, THE School_System SHALL run a reference search across the entire repository and SHALL treat the candidate as removable only when the count of live references equals zero, where a live reference is any reference outside the candidate's own definition file and outside generated files (`.freezed.dart`, `.g.dart`).
3. WHERE a redundant `LegacyRouteRedirect` exists on `/ac/fees`, THE School_System SHALL run a reference search across the entire repository and SHALL remove it only after recording a live reference count of zero in the Phase_Report.
4. IF a reference search for a deletion candidate returns one or more live references, THEN THE School_System SHALL NOT delete the candidate, SHALL retain the candidate unchanged, and SHALL record each live reference (file path and line) in the Phase_Report.
5. WHEN a reference search confirms zero live references for a deletion candidate, THE School_System SHALL perform the deletion only after explicit sign-off per Requirement 1 and SHALL record the sign-off identity and timestamp in the Phase_Report.
6. IF a Phase 9 deletion is attempted without a recorded zero-reference result and recorded sign-off for that candidate, THEN THE School_System SHALL block the deletion and SHALL record the missing prerequisite in the Phase_Report.

### Requirement 13: Phase 10 — End-to-End Verification and Final Report

**User Story:** As a maintainer, I want a final verification pass and a traceability matrix, so that I can confirm every audit finding is resolved or explicitly deferred and that no other vertical regressed.

#### Acceptance Criteria

1. WHEN Phase 10 executes, THE School_System SHALL run the full lint/analyze step and the full test suite and SHALL record in the final Phase_Report the total, passed, and failed counts for both the lint/analyze step and the test suite.
2. IF the recorded lint/analyze error count or test fail count is greater than zero, THEN THE School_System SHALL record a Fail status in the final Phase_Report and SHALL enumerate each failure.
3. THE School_System SHALL produce a Verification_Matrix that maps every audit finding to exactly one of Resolved, Partially-Resolved, Deferred, or Out-of-Scope, with no finding left unmapped and no finding assigned more than one status.
4. WHERE an audit finding is mapped to Resolved or Partially-Resolved, THE Verification_Matrix SHALL cite the evidence (test output, search output, or changed location) supporting that status.
5. THE School_System SHALL confirm that the grants in `businessCapabilityRegistry['schoolErp']` are read by the live schoolErp UI and SHALL record a pass or fail result for that confirmation in the Verification_Matrix.
6. THE School_System SHALL list every pending human decision, including any deferred Phase 4 policy decision or pending Mini_Gate or deletion sign-off, in the final Phase_Report, recording for each the decision required and its current status.
7. WHEN Phase 10 completes, THE School_System SHALL record a pass or fail result per business type other than `schoolErp`, where pass means the sidebar, dashboard, quick actions, and alerts widget for that business type resolve unchanged behavior.
8. IF any business type other than `schoolErp` shows changed behavior in its sidebar, dashboard, quick actions, or alerts widget, THEN THE School_System SHALL record a fail result identifying the affected surface and business type.

### Requirement 14: Phase Ordering and Stop Gates

**User Story:** As a maintainer, I want the phases executed in strict order with human stop gates and written reports, so that I retain control over every step of the remediation.

#### Acceptance Criteria

1. THE School_System SHALL execute the phases in strict ascending order beginning with Phase 0 and ending with Phase 10, and SHALL NOT begin Phase N+1 until Phase N has received an approval reply consisting of exactly the case-sensitive literal `APPROVED`.
2. WHEN a phase completes, THE School_System SHALL produce a Phase_Report that contains all of the following, with no item left blank: (a) every file created, modified, or deleted, each identified by its full path; (b) the specific change made to each listed file; (c) each verification step executed together with its pass or fail result; and (d) a mapping from each change to the identifier of the audit finding it addresses.
3. WHEN a phase completes and its Phase_Report has been produced, THE School_System SHALL emit the literal text `PHASE N COMPLETE — AWAITING APPROVAL`, with `N` replaced by the completed phase number, and SHALL halt all further phase execution until an approval reply is received.
4. IF an approval reply requests changes, THEN THE School_System SHALL apply the requested changes, re-emit the Stop_Gate text for that same phase, and SHALL NOT advance to the next phase.
5. IF an approval reply is neither the exact literal `APPROVED` nor an actionable change request, THEN THE School_System SHALL NOT advance to the next phase, SHALL preserve the current phase state unchanged, and SHALL emit an indication that clarification is required.
6. WHERE a change can be applied as a line-level surgical diff to existing code, THE School_System SHALL apply the surgical diff rather than rewriting the surrounding code block.
