# Design Document — School ERP (`schoolErp`) Vertical Full Remediation

## Overview

The DukanX `schoolErp` vertical (`BusinessType.schoolErp`, "School ERP") already ships a substantial school product surface — roughly 34 `Ac*Screen` widgets under `lib/features/academic_coaching/presentation/screens/`, a full REST repository `ac_repository.dart` bound to Lambda `/ac/*` endpoints, an input validator utility `ac_validators.dart`, a thermal print service, a capability-rich `businessCapabilityRegistry['schoolErp']` entry, and a set of `/ac/*` named routes guarded to `schoolErp`. The audit (`audit-reports/business-types/audit-schoolErp.md`) confirms the problem is **not absence of features — it is reachability and data-correctness**. The school screens are *orphaned* from the live shell: the sidebar dispatcher `_getSectionsForBusiness` in `sidebar_configuration.dart` has no `case BusinessType.schoolErp`, so it falls through to `default: _getRetailSections()` and a school operator sees a retail sidebar. The dashboard quick actions and alerts widgets have no school case (they fall to a generic default with hardcoded/empty counts), the bill template returns the generic `_serviceTemplate`, the `/ac/*` routes are guarded by generic retail permissions (`viewInvoices`, `viewClients`), the repository is online-only (no offline cache), and the declared `school.*` WebSocket events have no UI consumer.

This design specifies how the phased remediation defined in `requirements.md` (Requirement 1 through Requirement 14, delivered across Phase 0 through Phase 10) is realized in code. The strategic directive is **integrate the existing code, do not rebuild or delete working screens**. The `Ac*Screen` widgets and `AcRepository` are assets to wire up. The design mirrors the requirements: the cross-cutting invariants of Requirement 1 and the scope boundary of Requirement 2 become design-wide invariants; each subsequent phase maps to a design section with concrete components, interfaces, and data models; and the money, identifier, validation, sync, and template surfaces are specified precisely enough to support property-based testing.

### Live-reality findings that anchor this design (from the audit + a code re-read)

- **Sidebar fall-through (CONFIRMED).** `_getSectionsForBusiness(BusinessType type)` in `lib/widgets/desktop/sidebar_configuration.dart` has explicit cases for clinic, pharmacy, restaurant, petrolPump, mobileShop, service, hardware, vegetablesBroker, decorationCatering, jewellery, and clothing — but **no `schoolErp` case** → `default: _getRetailSections()`.
- **Capability/permission filter exists.** `sidebarSectionsProvider` already filters every `SidebarMenuItem` by `item.capability` (via `FeatureResolver.canAccess(typeStr, capability)`) and `item.permission` (via `RolePermissions.hasPermission(userRole, permission)`). A school section plugs into this existing pipeline; no filter rewrite is needed.
- **Navigation handler has no school cases (CONFIRMED).** `SidebarNavigationHandler.getScreenForItem(itemId, context)` delegates to `tryGetScreenForItem`, which switches on `itemId` and returns `_buildPlaceholderScreen('Unknown Screen', …)` for any unmapped id. No `school_*` ids are mapped.
- **Route surface discrepancy (Phase 0 reconciliation item).** The audit states the `/ac/*` named routes live in `lib/app/routes.dart`. A code re-read finds them in **`lib/core/routing/legacy_routes.dart`**, wrapped in `BusinessGuard(allowedTypes: [BusinessType.schoolErp])` with generic permission guards. Phase 0 MUST record the true live route-registration file before any Phase 1 wiring; this design treats `legacy_routes.dart` (the live `MaterialApp.routes` table) as the route surface and does **not** migrate to GoRouter (Requirement 2.4).
- **Money is double-in-model, paise-on-wire (CONFIRMED ambiguity).** `ac_models.dart` exposes `double` money fields (`AcStudent.totalFees/totalPaid/balance`, `AcCourse.totalFee/materialFee/admissionFee`, `AcInvoice.totalAmount/paidAmount/balance/discountAmount/adjustmentAmount`) populated by dividing a `*Paisa` integer wire field by 100. This is exactly the rupee/paise ambiguity Requirement 1 and Requirement 10 target.
- **Validators exist but are rupee/double-based.** `AcValidators.validateFeeAmount` parses a `double` and permits `min = 0` (zero), conflicting with Requirement 10.5 (zero/negative must be rejected). Validation is not uniformly invoked on repository write paths.
- **Sync is students-only.** `SchoolErpSyncHandler` syncs collection `school_students` → `/ac/students`; fees/attendance/exams are not synced. `SchoolErpWsHandler` declares `school.fee.due`, `school.attendance.marked`, `school.exam.result` with no UI consumer.
- **Bill template falls back to service.** `bill_template_system.dart` `getTemplate` returns `_serviceTemplate` for `BusinessType.schoolErp` (and the sample-items switch groups schoolErp with service).

### Guiding principles

- **Evidence before change.** Phase 0 produces a read-only `Verification_Report` resolving every unverified audit item to CONFIRMED, FALSIFIED, or still-unverified, including the `legacy_routes.dart` vs `app/routes.dart` discrepancy. No later phase acts on an assumption.
- **Integrate, never rebuild.** Every wired screen references an existing `Ac*Screen` widget. No screen is copied or replaced (Requirement 2.2, 2.3, 9.6).
- **Surgical, additive shared edits.** Shared files (`sidebar_configuration.dart`, `sidebar_navigation_handler.dart`, `business_quick_actions.dart`, `business_alerts_widget.dart`, `business_capability.dart`, `bill_template_system.dart`, the route table) are touched only by adding a `schoolErp` branch or a new gated item; no other business type's resolution path changes, and a regression pass records per-vertical results.
- **One canonical money path.** All touched school money is integer Paise end-to-end; rupee display is a presentation-time conversion only.
- **Offline-first repository.** Students, fees, and attendance gain a Drift-backed local cache and a sync queue mirroring the established per-vertical offline pattern; the sync handler is extended beyond students.
- **Gate-driven progression.** Each phase ends with the literal `PHASE N COMPLETE — AWAITING APPROVAL` and resumes only on the literal `APPROVED`. Schema changes (Mini_Gate — including any `UserRole` enum change) and hard deletions (reference search + sign-off) require their own explicit approval.
- **Policy gate is a hard stop.** Phase 4 (minors' PII) writes no code until retention, consent, authorized-role, and audit policies are confirmed and recorded with owner + timestamp.

## Architecture

### Current-state component map

```mermaid
graph TD
    subgraph Live shell
        SHELL[Desktop shell / mobile drawer] --> SBPROV[sidebarSectionsProvider]
        SBPROV --> SBCFG[sidebar_configuration.dart _getSectionsForBusiness]
        SBCFG -->|schoolErp: NO case| RETAIL[default: _getRetailSections]
        SHELL --> DASH[Dashboard V2]
        DASH --> QA0[business_quick_actions: no schoolErp -> default]
        DASH --> AW0[business_alerts_widget: no schoolErp -> default/empty]
    end
    subgraph Orphaned school code lib/features/academic_coaching
        SCR[34 Ac*Screen widgets]
        REPO[AcRepository ApiClient-direct, online-only]
        VAL[AcValidators rupee/double]
        PRINT[AcThermalPrintService]
    end
    subgraph Route + module surface
        LR[core/routing/legacy_routes.dart /ac/* guarded viewInvoices/viewClients]
        MOD[modules/school_erp SchoolErpModule navItems unused]
        SYNC[SchoolErpSyncHandler school_students only]
        WS[SchoolErpWsHandler school.* events, no consumer]
    end
    RETAIL -.->|no link| SCR
    LR -->|BusinessGuard schoolErp| SCR
    REPO -->|REST| EP[/ac/* Lambda]
    BILL[bill_template_system schoolErp -> _serviceTemplate] -.-> SCR
```

### Target-state component map (post-remediation)

```mermaid
graph TD
    SHELL[Desktop shell / mobile drawer] --> SBPROV[sidebarSectionsProvider]
    SBPROV --> SBCFG[sidebar_configuration.dart]
    SBCFG -->|case schoolErp| SSECT[_getSchoolSections]
    SSECT -->|items: capability + School_Permission tags| NAV[SidebarNavigationHandler getScreenForItem]
    NAV --> SCR[existing Ac*Screen widgets]
    QA[business_quick_actions case schoolErp] --> SCR
    QA --> A1[Collect Fee / New Admission / Mark Attendance / Enter Marks]
    AW[business_alerts_widget case schoolErp] --> REPOFF
    AW --> A2[Fees Due / Absentees Today / Upcoming Exams - live counts]
    SCR --> REPOFF[AcRepository + offline cache + sync queue]
    REPOFF -->|tenant-scoped, paise| EP[/ac/* Lambda]
    REPOFF --> DRIFT[Drift cache: students, fees, attendance]
    SYNC[SchoolErpSyncHandler students+fees+attendance+exams] --> EP
    WS[SchoolErpWsHandler school.* events] -->|mirror inventory.* pattern| AW
    PERM[School_Permissions layer maps UserRole -> viewFees/collectFees/...] --> NAV
    PERM --> GUARD[/ac/* route guards]
    BILL[bill_template_system case schoolErp] --> FRT[Fee_Receipt_Template]
    VAL[AcValidators paise + linkage] --> SCR
```

### Phase-to-requirement map

| Phase | Requirements | Theme | Primary artifacts |
|-------|--------------|-------|-------------------|
| 0 | 3 | Read-only re-verification + gap discovery | `Verification_Report` (Markdown only) |
| 1 | 4 | Routing & navigation wiring | `sidebar_configuration.dart` (`_getSchoolSections`), `sidebar_navigation_handler.dart`, route table |
| 2 | 5 | Dashboard, quick actions, alerts with real data | `business_quick_actions.dart`, `business_alerts_widget.dart`, alert/KPI providers, WS consumer |
| 3 | 6 | RBAC & scoped School_Permissions | `School_Permissions` layer, `/ac/*` route guards |
| 4 | 7 | Minors' PII & compliance (policy stop) | policy sign-off record, PII access audit log, encryption-at-rest report |
| 5 | 8 | Offline sync & real-time consistency | Drift cache, `SchoolErpSyncHandler` extension, reconciliation/idempotency |
| 6 | 9 | Orphaned screen disposition | route + guard + sidebar entry per Production-Ready screen; gap/stale records |
| 7 | 10 | Data validation & money/ID compliance | `AcValidators` extension, paise migration, write-path validation |
| 8 | 11 | Fee receipt template | `Fee_Receipt_Template` in `bill_template_system.dart` |
| 9 | 12 | Dead code & duplicate cleanup | `/ac/students` collision, Nav_Items, `/ac/fees` redirect — reference search + sign-off |
| 10 | 13 | End-to-end verification & final report | `Verification_Matrix`, test suites, per-vertical regression |

The cross-cutting constraints of Requirement 1 (integer Paise, RID ids, tenant scoping, Mini_Gate, no hard deletes, idempotent migrations, additive shared edits, regression pass, STOP GATE protocol) are not a phase — they are invariants enforced in every section below. The scope boundary of Requirement 2 (four allowed locations, no GoRouter migration, exclude `school_*_app/` projects) bounds every change. Requirement 14 (strict ordering + stop gates + Phase_Report) governs progression.

### Design-wide invariants (Requirement 1 & 2)

1. **Integer-Paise money (1.1, 1.2, 1.3).** Every money value in created/modified school code is an `int` of Paise. The `double` money fields in `ac_models.dart` that are touched migrate to integer-Paise fields (e.g. `totalFeesPaise`, `paidAmountPaise`, `balancePaise`), with rupee values derived only at display time. No `double`/`float`/decimal currency is introduced; touched float currency fields migrate only via the Mini_Gate.
2. **RID ids (1.4).** New entities use `{tenantId}-{timestamp_ms}-{uuid_v4_short}` via the shared RID generator, where `tenantId` is the active `Tenant_Id`, `timestamp_ms` is Unix epoch milliseconds, and `uuid_v4_short` is a non-empty shortened UUID v4. Any bare `Uuid().v4()` on a touched write path is replaced.
3. **Tenant scoping (1.5, 1.6, 1.7).** Every query/write/sync resolves `Tenant_Id` from the authenticated session (no hardcoded `'SYSTEM'` or other literal). An unresolved tenant aborts the operation with an unresolved-tenant error, performs no read or write, and leaves persisted data unchanged.
4. **Mini_Gate for schema (1.8).** Any DynamoDB table-shape change, local-store (Drift table) change, or `UserRole` enum change halts and requests a Mini_Gate stating the proposed change, every consumer of the changed symbol, and a migration plan before applying.
5. **No hard deletes without sign-off (1.9).** Removal of a file/route/screen/symbol first runs a repository-wide reference search, records the result and an explicit deletion request in the Phase_Report, and proceeds only on the literal `APPROVED`.
6. **Idempotent migrations (1.10).** Any data migration is guarded so repeated runs produce the same persisted result and modify zero records after the first execution.
7. **Additive shared edits + regression (1.11, 1.12, 1.15).** Shared components gain only a `schoolErp` branch or a new gated item; no other business type's sidebar/quick-action/alert/capability/template resolution changes. A regression pass records pass/fail per non-school vertical.
8. **Gate discipline (1.13, 1.14, 1.16).** Each phase runs lint/analyze + tests on touched code, records counts, resolves any failure before completing, and emits the literal gate text, waiting for `APPROVED`.
9. **Scope boundary (2.1–2.7).** Changes are restricted to `lib/features/academic_coaching/*`, the `schoolErp` case in Shared_Components, the schoolErp offline sync handler, and the navigation entries needed for reachability. No GoRouter migration; the standalone `school_admin_app/`, `school_teacher_app/`, `school_student_app/`, `school_common/` projects are out of scope.

## Components and Interfaces

### Phase 0 — Verification_Report (Requirement 3)

A single read-only Markdown artifact at `.kiro/specs/schoolerp-vertical-remediation/phase0-verification-report.md`. Phase 0 creates, modifies, and deletes zero files other than this report and touches no application source/config/build file (3.1). It records, each with file path + line numbers:

- **Hardcoded-literal search (3.2).** Result of a repository-wide search for hardcoded `vendorId`, `tenantId`, or `'SYSTEM'` literals within `lib/features/academic_coaching/*`; explicit "none found" if zero.
- **Write-path tenant threading (3.3).** Each `AcRepository` write method (`createStudent`, `updateStudent`, `transferStudent`, `createBatch`, `createCourse`, `createInvoice`, `recordPayment`, `markAttendance`, `createExam`, `uploadResults`, `createMaterial`, `createFaculty`, `markFacultyAttendance`, `createTimetableSlot`, `generateCertificate`, `bulkImportStudents`, `bulkGenerateInvoices`, …) classified `fully-threaded` or `has-gaps`, noting whether `Tenant_Id` is threaded explicitly or only via the `ApiClient` auth header.
- **RID compliance (3.4).** Every new-entity id-generation site classified `compliant` or `non-compliant` against the RID pattern; explicit "no non-compliant sites found" if all comply.
- **Paise compliance (3.5).** Every money field classified `paise-consistent` or `has-ambiguity`; this report MUST list the `double` fields in `ac_models.dart` (`AcStudent.totalFees/totalPaid/balance`, `AcCourse.totalFee/materialFee/admissionFee`, `AcInvoice.totalAmount/paidAmount/balance/discountAmount/adjustmentAmount`) and the `*Paisa`-divided-by-100 conversions as ambiguities.
- **Validators presence (3.6).** Records that `ac_validators.dart` exists and enumerates each function (`validateStudentId`, `validateName`, `validatePhone`, `validateEmail`, `validateDateOfBirth`, `validateFeeAmount`, `validateCapacity`, `validateDateRange`, `validateExamDuration`, `validateMarks`, `validatePincode`, `required`, `validateUniqueId`).
- **Endpoint reality (3.7).** Each `/ac/*` endpoint required by an `Ac_Screen` classified `deployed`, `not-deployed`, or `unverified`, recording observed vs expected request paths.
- **Orphaned-screen ratings (3.8).** Every orphaned `Ac_Screen` (the screens with no live route — admissions, hostel, homework, lesson plans, id cards, documents, siblings, leave, payments, inventory, etc.) rated `Production-Ready`, `Needs-Work`, or `Stale` with a one-line justification and file path.
- **Route-surface reconciliation (3.9, 3.11).** Records the verified live route file. The audit's `app/routes.dart` claim is re-checked against the observed `lib/core/routing/legacy_routes.dart`; if the audit is contradicted, Phase 0 halts and reports the discrepancy rather than routing around it (3.11). Resolves the `/ac/students` collision question (which screen each registry binds) as input to Requirement 4.6.
- **Completeness (3.10).** Every check in 3.2–3.9 has a recorded result with nothing left unclassified.

### Phase 1 — Routing and navigation wiring (Requirement 4)

**`_getSchoolSections()` in `sidebar_configuration.dart`.** A new private function returning the school section list, reached via an explicit `case BusinessType.schoolErp:` in `_getSectionsForBusiness` — no fall-through to `default: _getRetailSections()` (4.1). Every item carries a non-empty label (4.2) and an `id` that resolves via `SidebarNavigationHandler.getScreenForItem` to an existing `Ac_Screen`, never a placeholder (4.3). Each gated item carries the matching `BusinessCapability` (already granted in `businessCapabilityRegistry['schoolErp']`) and, from Phase 3, a `School_Permission` tag so the existing `sidebarSectionsProvider` filter includes/excludes it.

Initial section/item set (Production-Ready, routed screens only; orphaned screens are added in Phase 6 per their rating):

| Section | Item id | Screen | Capability gate |
|---------|---------|--------|-----------------|
| Dashboard | `school_dashboard` | `AcDashboardScreen` | `useDailySnapshot` |
| Students & Admissions | `school_students` | `AcStudentsScreen` | `useStudentRegistry` |
| Students & Admissions | `school_classes` | `AcClassSectionsScreen` | `useStudentRegistry` |
| Fees | `school_fees` | `AcFeeCollectionScreen` | `useFeeCollection` |
| Fees | `school_fee_structure` | `AcClasswiseFeeScreen` | `useFeeCollection` |
| Attendance | `school_attendance` | `AcAttendanceScreen` | `useAttendanceTracking` |
| Exams & Report Cards | `school_exams` | `AcExamsScreen` | `useTestResults` |
| Exams & Report Cards | `school_report_cards` | `AcReportCardsScreen` | `useTestResults` |
| Timetable | `school_timetable` | `AcTimetableScreen` | `useTimetable` |
| Faculty | `school_faculty` | `AcFacultyScreen` | `useStaffManagement` |
| Transport | `school_transport` | `AcTransportScreen` | `useStudentRegistry` |
| Library | `school_library` | `AcLibraryScreen` | `useStudentRegistry` |
| Communication | `school_notifications` | `AcNotificationsScreen` | `useParentNotifications` |
| Reports | `school_reports` | `AcReportsScreen` | `useRevenueOverview` |
| Certificates | `school_certificates` | `AcCertificateGeneratorScreen` | `useCertificates` |

**`SidebarNavigationHandler.getScreenForItem` (4.4, 4.5).** New `case 'school_*':` branches in the `tryGetScreenForItem` switch map each id to exactly one existing `Ac_Screen` widget (the same widgets the live route table references). An id that cannot resolve retains the current screen, performs no navigation, surfaces an "unavailable" indication, and raises no unhandled exception (the existing `_buildPlaceholderScreen` fallthrough is never reached for a wired id).

**`/ac/students` collision (4.6).** Resolved by binding `/ac/students` to the screen recorded as more feature-complete in the Phase 0 report (`AcStudentsScreen` per the live named-route table) and assigning `AcStudentRegistrationScreen` a distinct non-colliding path (e.g. `/ac/students/register`).

**Dormant GoRouter alignment (4.7).** Each dormant `school_erp` GoRouter `/ac/*` entry is aligned to reference the same target as its live binding without activating GoRouter.

**Single source of truth (4.8, 4.9).** School navigation items are sourced only from `sidebarSectionsProvider`. The unused `SchoolErpModule.navItems` redundancy is flagged in the Phase_Report and not deleted in this phase (deletion is Phase 9).

**Preservation (4.10).** For any `BusinessType` other than `schoolErp`, `_getSectionsForBusiness` returns sections identical to pre-change (only a new `case` and a new function are added; no other case or the `default` branch is edited).

### Phase 2 — Dashboard, quick actions, alerts with real data (Requirement 5)

**Quick actions (5.1, 5.10).** A new `case BusinessType.schoolErp:` in `business_quick_actions.dart` `_buildActionsForBusiness` presents exactly four actions — **Collect Fee** (→ `AcFeeCollectionScreen`), **New Admission** (→ `AcStudentRegistrationScreen`), **Mark Attendance** (→ `AcAttendanceScreen`), **Enter Marks** (→ `AcExamsScreen`) — each navigating to the corresponding existing screen. No other business type's action set changes.

**Alerts (5.2, 5.3, 5.10).** A new `case BusinessType.schoolErp:` in `business_alerts_widget.dart` `_getTitle` (returns "School Alerts") and `_buildAlertsForBusiness` presents exactly three alerts — **Fees Due**, **Absentees Today**, **Upcoming Exams** — each backed by a real tenant-scoped query through `AcRepository`/the offline cache (e.g. fee dues from `getReportsSummary`/fee aggregates, absentees from `getAttendanceReport` for today, upcoming exams from `listExams`). No hardcoded count is displayed; every count derives from a live query result.

**KPI cards (5.4, 5.7, 5.8, 5.9).** The schoolErp dashboard surfaces `Ac_Dashboard_Stats` (from `AcRepository.getDashboard()`), each KPI a non-negative integer derived from a tenant-scoped query for the active `Tenant_Id`. Each alert/KPI shows a loading indicator while its query is in progress (5.8), a zero/empty-state indicator when the query returns no data (5.7), and an error indicator on query failure (5.9) — never a fabricated count.

**Real-time updates (5.5, 5.6).** A WebSocket consumer mirrors the existing `inventory.*` consumption pattern in `business_alerts_widget`: on a `school.fee.due`, `school.attendance.marked`, or `school.exam.result` event **for the active `Tenant_Id`**, the corresponding alert/KPI updates; an event for any other tenant is ignored and updates nothing.

### Phase 3 — RBAC and scoped School_Permissions (Requirement 6)

**`School_Permissions` layer (6.1, 6.2).** A new scoped permission layer maps one or more existing `UserRole` values (`owner`, `manager`, `staff`, `accountant`) to each school-specific permission (`viewStudents`, `viewFees`, `collectFees`, `markAttendance`, `enterMarks`, `viewStudentPII`, `exportStudentPII`, …) **without** adding, removing, renaming, or reordering any `UserRole` value. If a global `UserRole` enum change is ever proposed, the enum is left unchanged and a Mini_Gate is emitted first (6.1). The mapping is expressed as a pure function `hasSchoolPermission(UserRole role, SchoolPermission p) -> bool`, reusable by both the sidebar filter and the route guards.

**Route guards (6.3–6.7).** Every `/ac/*` route guard is changed from a generic retail permission (`viewInvoices`, `viewClients`) to a school-specific permission, so no `/ac/*` route retains a `viewInvoices`/`viewClients` guard (6.3). A user holding the required `School_Permission` resolves the route to its `Ac_Screen` with no redirect (6.4). A user lacking it is blocked, renders no part of the screen, is redirected to the default authorized landing screen, and sees an access-denied indication (6.5). A guarded route with no mapping defined denies access and redirects (6.6). The change is scoped to schoolErp routes; no other business type's route guard changes (6.7).

### Phase 4 — Minors' PII and compliance (policy stop) (Requirement 7)

**Hard stop (7.1, 7.9).** While any of the four policy decisions — data retention period (7.3), parent/guardian consent mechanism (7.4), authorized-role list (7.5), audit-logging policy — is unconfirmed, Phase 4 implements no minors'-PII handling code and surfaces each unconfirmed decision by name for sign-off. A decision is "confirmed" only when a record captures the decision, the agreed value, the confirming compliance owner, and the confirmation timestamp (7.2).

**Audit log (7.6, 7.7).** Once policies are confirmed: when a user views or exports a minor's PII, the system writes a per-record audit entry capturing acting user, record accessed, action (`view`/`export`), and timestamp, scoped by `Tenant_Id`. A user whose role is not in the confirmed authorized-role list is denied, returns/exports no data, and an audit entry recording the denied attempt is written.

**Encryption-at-rest report (7.8).** For each DynamoDB table storing minors' PII, the boolean encryption-at-rest status is verified and recorded in the Phase_Report.

### Phase 5 — Offline sync and real-time consistency (Requirement 8)

**`Drift_Cache` (8.1, 8.6).** New Drift tables cache students, fees, and attendance, mirroring the offline caching pattern used by other verticals. Every cached row carries `tenantId`; a read never returns a row whose `tenantId` differs from the active `Tenant_Id`. Currency columns are integer Paise and identifiers follow the RID pattern. Any new table is additive and applied only after a Mini_Gate (1.8).

**`SchoolErpSyncHandler` extension (8.2).** The handler is extended beyond `school_students` to also synchronize fees, attendance, and exams (additional collection → `/ac/*` base-path mappings).

**Reconciliation & idempotency (8.3, 8.4, 8.5, 8.7).** On connectivity restore, local and remote state reconcile so each record (identified by its RID) has exactly one stored version with no duplicate (8.3). Applying the same RID-identified change more than once yields the same persisted result as a single application (8.4 — idempotent upsert keyed by RID). When a WebSocket event and an offline sync operation target the same record, the operations are serialized, the change applied at most once, and the resulting version is independent of arrival order (8.5). A failed sync retains that record's pending local change, leaves successfully synced records unaffected, and retries the failed record on the next connectivity-restored event without discarding it (8.7).

### Phase 6 — Orphaned screen disposition (Requirement 9)

Driven by Phase 0 ratings:

- **Production-Ready (9.1, 9.2, 9.6).** Made reachable by adding **exactly one** route, **one** `School_Permission` guard, and **one** sidebar entry, referencing the existing screen widget (never copied/rebuilt). The Phase_Report records screen identifier, route, guard permission name, and sidebar label.
- **Needs-Work (9.3).** Specific gaps recorded as discrete Phase_Report items; no route/guard/sidebar entry added.
- **Stale (9.4, 9.5).** A reference search across the schoolErp source tree runs; the resulting count and file paths are recorded and the screen flagged for deletion — but not deleted until explicit sign-off (Phase 9 / Requirement 1.9).

### Phase 7 — Data validation and money/ID compliance (Requirement 10)

**RID & paise gap closure (10.1, 10.2).** Each RID gap recorded in Phase 0 is closed via the Mini_Gate process to the canonical RID pattern. Each rupee/paise ambiguity recorded in Phase 0 is resolved so the affected screen represents currency as integer Paise (the `ac_models.dart` `double` money fields touched are migrated to integer-Paise fields; rupee display converts at the edge).

**Write-path validation (10.3, 10.4, 10.5, 10.6).** Every School_System write path routes through `AcValidators` before persistence (10.4). A saved fee entry is validated to link to an existing student record **and** an existing class record scoped to the active `Tenant_Id` before any data is persisted (10.3). A fee amount that is null, non-numeric, zero, or negative in integer Paise is rejected: nothing is persisted, entered values are retained, and an error is shown on the amount field (10.5). Any write-path validation failure (including invalid student/class linkage) rejects the write, leaves any previously stored record unchanged, retains entered values, and shows an error identifying the invalid field or linkage (10.6). `AcValidators.validateFeeAmount` is extended/replaced with an integer-Paise validator whose lower bound is strictly positive.

### Phase 8 — Fee receipt template (Requirement 11)

**`Fee_Receipt_Template` (11.1, 11.4).** `bill_template_system.dart` `getTemplate` returns a new dedicated `Fee_Receipt_Template` for `BusinessType.schoolErp` instead of `_serviceTemplate`. For every other business type the function returns the identical template it returned before (only the `schoolErp` case changes; the sample-items switch is updated in lockstep for schoolErp only).

**Rendering (11.2, 11.3, 11.5, 11.6).** The template renders the student name, the class, and a per-fee-head breakdown where each fee head is a separate line item with its own label and amount (11.2). Each integer-Paise value (paid amount, due amount, every per-fee-head amount) is converted to its rupee value displayed with exactly two decimal places (11.3). A missing/empty required field (student name, class, or breakdown) renders a fixed placeholder string in its place while the remaining fields still render without error (11.5). A breakdown with zero fee-head line items renders the breakdown section containing the fixed placeholder string and still renders the paid and due amounts (11.6).

### Phase 9 — Dead code and duplicate cleanup (Requirement 12)

Each candidate — the `/ac/students` collision residue (12.1), the flagged `Nav_Items` redundancy (12.2), and the redundant `/ac/fees` `LegacyRouteRedirect` (12.3) — is handled by a repository-wide reference search recorded in the Phase_Report (scope, exact path/symbol, live-reference count, where a live reference is any reference outside the candidate's own definition file and outside generated `.freezed.dart`/`.g.dart` files). One or more live references ⇒ no deletion, candidate retained, each live reference recorded (12.4). Zero live references ⇒ deletion only after explicit sign-off with recorded identity + timestamp (12.5). A deletion attempted without a recorded zero-reference result **and** sign-off is blocked and the missing prerequisite recorded (12.6).

### Phase 10 — End-to-end verification and final report (Requirement 13)

A final pass runs the full lint/analyze step and full test suite, recording total/passed/failed counts for both (13.1); a non-zero error/fail count records a Fail status with each failure enumerated (13.2). The `Verification_Matrix` maps every audit finding to exactly one of Resolved, Partially-Resolved, Deferred, or Out-of-Scope, with none unmapped and none multiply-assigned (13.3); Resolved/Partially-Resolved entries cite evidence (test output, search output, or changed location) (13.4). The matrix records a pass/fail for whether `businessCapabilityRegistry['schoolErp']` grants are actually read by the live schoolErp UI (13.5). Every pending human decision (deferred Phase 4 policy, pending Mini_Gate, deletion sign-off) is listed with its status (13.6). A pass/fail is recorded per non-school business type for unchanged sidebar/dashboard/quick-action/alert behavior (13.7, 13.8).

## Data Models

### Money representation (Requirement 1.1, 10.2)

The canonical in-app representation for all touched school money is **integer Paise**. The current `ac_models.dart` `double` rupee fields are migrated (under Mini_Gate) to integer-Paise fields, and rupee values are derived only at the presentation edge.

| Model | Current (double, rupees) | Target (int, Paise) | Notes |
|-------|--------------------------|---------------------|-------|
| `AcStudent` | `totalFees`, `totalPaid`, `balance` | `totalFeesPaise`, `totalPaidPaise`, `balancePaise` | derived fee-summary fields |
| `AcCourse` | `totalFee`, `materialFee`, `admissionFee` | `totalFeePaise`, `materialFeePaise`, `admissionFeePaise` | wire already carries `*Paisa` |
| `AcInvoice` | `totalAmount`, `paidAmount`, `balance`, `discountAmount`, `adjustmentAmount` | `*Paise` integer equivalents | `balancePaise = totalPaise - paidPaise` |
| `AcFeeComponent` | per-head amount (double) | `amountPaise` (int) | one line item per fee head |
| `AcPayment` | amount (double) | `amountPaise` (int) | paise-on-wire preserved |

Rupee display uses a single conversion helper (Paise → rupees with exactly two decimals) shared by screens and the `Fee_Receipt_Template` (11.3). No arithmetic is performed on rupee doubles; `balancePaise` is computed in integer Paise.

### RID identifier (Requirement 1.4)

```
{tenantId}-{timestamp_ms}-{uuid_v4_short}
```

`tenantId` is the active `Tenant_Id`, `timestamp_ms` is Unix epoch milliseconds, and `uuid_v4_short` is a non-empty shortened UUID v4. A shared RID generator produces ids for all new school entities on touched write paths, replacing any bare UUID generation.

### School_Permissions (Requirement 6.2)

A pure mapping layer; values are illustrative and finalized in Phase 3 without touching `UserRole`:

| School_Permission | Mapped `UserRole`(s) |
|-------------------|----------------------|
| `viewStudents` | owner, manager, staff, accountant |
| `viewFees` | owner, manager, accountant |
| `collectFees` | owner, manager, accountant |
| `markAttendance` | owner, manager, staff |
| `enterMarks` | owner, manager, staff |
| `viewStudentPII` | owner, manager (+ Phase 4 confirmed list) |
| `exportStudentPII` | owner (+ Phase 4 confirmed list) |

`hasSchoolPermission(role, permission)` is a total function returning `false` for any unmapped (role, permission) pair, giving deny-by-default semantics for the route guards (6.6) and the sidebar filter.

### Drift cache + sync queue (Requirement 8)

| Table | Key fields | Notes |
|-------|-----------|-------|
| `school_students_cache` | `rid` (PK), `tenantId`, payload, `synced`, `pendingOperation`, `pendingSince`, `version` | tenant-scoped reads only |
| `school_fees_cache` | `rid` (PK), `tenantId`, `studentRid`, `classId`, `amountPaise`, `paidPaise`, `status`, sync fields | currency in Paise |
| `school_attendance_cache` | `rid` (PK), `tenantId`, `studentRid`, `date`, `status`, sync fields | one record per student/day |
| `school_sync_queue` | `id`, `entityType` (`student`/`fee`/`attendance`/`exam`), `operation` (`create`/`update`/`delete`), `entityRid`, `retryCount`, `lastError`, `failed` | FIFO drain, retry cap, mark-failed not discard |

Reconciliation is an idempotent upsert keyed by `rid`: applying an entry whose `rid` already exists at the same-or-newer `version` is a no-op (8.4). Any new table/column is additive with safe defaults and applied only after a Mini_Gate (1.8).

### Fee receipt model (Requirement 11)

| Field | Type | Placeholder when missing/empty |
|-------|------|-------------------------------|
| `studentName` | `String` | fixed placeholder (11.5) |
| `className` | `String` | fixed placeholder (11.5) |
| `feeHeads` | `List<{label: String, amountPaise: int}>` | placeholder line when empty (11.6) |
| `paidAmountPaise` | `int` | always rendered (11.6) |
| `dueAmountPaise` | `int` | always rendered (11.6) |

### Audit log entry — minors' PII (Requirement 7.6)

| Field | Type |
|-------|------|
| `id` | `String` (RID) |
| `tenantId` | `String` |
| `actingUserId` | `String` |
| `recordRef` | `String` (student/record id accessed) |
| `action` | enum (`view` / `export`) |
| `outcome` | enum (`allowed` / `denied`) |
| `timestamp` | `DateTime` |

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

These properties are derived from the acceptance-criteria prework and consolidated to remove redundancy. Process-governance, scope, artifact-content, and UI-state criteria (all of Requirements 3, 9, 12, 14; 1.3, 1.6, 1.8, 1.9, 1.13, 1.14, 1.16; 2.1–2.5, 2.7; 4.1, 4.6–4.9; 5.1, 5.2, 5.3, 5.8, 5.9; 6.1; 7.1–7.5, 7.8, 7.9; 8.2; 10.4; 11.1; 13.1–13.6, 13.8) are validated by example-based, integration, smoke, or governance checks described in the Testing Strategy, not by properties. The integer-Paise invariants (1.1/8.6/10.2) are one property; the RID invariants (1.4/8.6/10.1) are one property; the preservation criteria (1.11/1.12/1.15/2.6/4.10/5.10/6.7/11.4/13.7) are one property; the sidebar well-formedness/reachability criteria (4.2/4.3/4.4) are one property; the sync reconciliation criteria (8.3/8.4/8.5) are one property.

### Property 1: Money is integer Paise

*For any* fee, payment, invoice, or course-fee value supplied to the touched School_System money path, every stored and transmitted monetary result is an `int` number of Paise (never a `double`/`float`), equal to the integer reference computation, and any balance is computed as `totalPaise - paidPaise` in integer Paise.

**Validates: Requirements 1.1, 1.2, 8.6, 10.2**

### Property 2: RID identifiers are well-formed

*For any* active tenant id, an identifier produced for a new School_System entity matches the pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`, embeds that exact tenant id as its prefix, contains a millisecond Unix timestamp segment, and ends with a non-empty shortened UUID v4 segment.

**Validates: Requirements 1.4, 8.6, 10.1**

### Property 3: Tenant isolation across reads, writes, and the cache

*For any* two distinct tenant ids and any School_System records (students, fees, attendance, exams) written or cached under the first, a query, repository read, sync, or Drift-cache read performed under the second never returns those records.

**Validates: Requirements 1.5, 8.1**

### Property 4: Unresolved tenant aborts the operation

*For any* School_System read or write attempted while the active `Tenant_Id` cannot be resolved, the operation is rejected, performs no read or write, leaves persisted data unchanged, and returns an unresolved-tenant error.

**Validates: Requirements 1.7**

### Property 5: Migrations are idempotent

*For any* starting persisted state, applying a School_System remediation migration twice produces the same persisted result as applying it once, and the second application modifies zero records.

**Validates: Requirements 1.10**

### Property 6: Other business types are unchanged

*For any* `BusinessType` other than `schoolErp`, the sidebar sections, granted capability set, quick-action set, alert set, route-guard set, and resolved bill template after the remediation are identical (no item added, removed, or reordered) to those before the `case BusinessType.schoolErp` additions and the shared-component edits.

**Validates: Requirements 1.11, 1.12, 1.15, 2.6, 4.10, 5.10, 6.7, 11.4, 13.7**

### Property 7: Every school sidebar item is well-formed and resolves to a real screen

*For any* school sidebar item produced by `_getSchoolSections()`, the item's label contains at least one non-whitespace character, and `SidebarNavigationHandler.getScreenForItem` resolves the item's id to exactly one existing `Ac_Screen` widget and never the "Unknown Screen" placeholder fallthrough.

**Validates: Requirements 4.2, 4.3, 4.4**

### Property 8: Unknown navigation ids are handled safely

*For any* item id not mapped for schoolErp, `SidebarNavigationHandler.tryGetScreenForItem` returns null (and `getScreenForItem` returns the placeholder) without raising an unhandled exception and without performing navigation.

**Validates: Requirements 4.5**

### Property 9: KPI and alert counts are non-negative integers with honest empty state

*For any* tenant-scoped dashboard or alert query result, the displayed KPI/alert count is a non-negative integer derived from that result, and a result with no data yields a zero/empty-state indicator rather than a fabricated count.

**Validates: Requirements 5.4, 5.7**

### Property 10: Real-time updates are tenant-filtered

*For any* `school.fee.due`, `school.attendance.marked`, or `school.exam.result` WebSocket event, the corresponding dashboard alert/KPI updates if and only if the event's tenant equals the active `Tenant_Id`; an event for any other tenant updates nothing displayed.

**Validates: Requirements 5.5, 5.6**

### Property 11: `/ac/*` route access is granted exactly by school permission

*For any* `/ac/*` route and any authenticated user, the route's guard is a `School_Permission` (never `viewInvoices`/`viewClients`), and the route resolves to its `Ac_Screen` with no redirect when `hasSchoolPermission(user.role, requiredPermission)` is true; otherwise (including when the route has no permission mapping) access is blocked, no part of the screen renders, the user is redirected to the default authorized landing screen, and an access-denied indication is shown.

**Validates: Requirements 6.3, 6.4, 6.5, 6.6**

### Property 12: School permission mapping is total and leaves UserRole unchanged

*For any* `(UserRole, SchoolPermission)` pair, `hasSchoolPermission` returns a boolean (deny-by-default for unmapped pairs), and the global `UserRole` enum's values are unchanged in count, order, and names.

**Validates: Requirements 6.2**

### Property 13: Minors' PII access is always audited with the correct outcome

*For any* attempt to view or export a minor's PII, exactly one audit entry is written, scoped by `Tenant_Id`, capturing the acting user, the record accessed, the action (`view` or `export`), and the timestamp; the entry's outcome is `allowed` and data is returned when the user's role is in the confirmed authorized-role list, and `denied` with no data returned/exported otherwise.

**Validates: Requirements 7.6, 7.7**

### Property 14: Sync reconciliation is idempotent and order-independent

*For any* combination of local and remote School_System state and any interleaving of sync operations and `school.*` events targeting the same RID, after reconciliation each RID maps to exactly one stored version, applying the same RID-identified change more than once produces the same persisted result as a single application, and the final version is independent of arrival order.

**Validates: Requirements 8.3, 8.4, 8.5**

### Property 15: Failed sync entries are retained and retried, never discarded

*For any* sequence of sync entries containing a forced-failure entry, the failed entry retains its pending local change and is retried on the next connectivity-restored event, while successfully synced entries are unaffected and never re-applied or lost.

**Validates: Requirements 8.7**

### Property 16: Write-path validation rejects invalid input without side effects

*For any* fee or School_System write input that is invalid — an amount that is null, non-numeric, zero, or negative in integer Paise, or a fee entry whose student or class linkage does not exist under the active `Tenant_Id` — the write is rejected, nothing is persisted, any previously stored record is left unchanged, the entered values are retained, and an error indication identifies the invalid field or linkage.

**Validates: Requirements 10.3, 10.5, 10.6**

### Property 17: Fee receipt renders student, class, and per-head breakdown with placeholders

*For any* fee record, the rendered receipt contains the student name, the class, and one labeled line item per fee head; when the student name, class, or breakdown is missing or empty, a fixed placeholder string is rendered in its place and the remaining fields still render without error; and a record with zero fee heads renders the breakdown section containing the placeholder while still rendering the paid amount and the due amount.

**Validates: Requirements 11.2, 11.5, 11.6**

### Property 18: Paise values format to exactly two decimal places

*For any* integer-Paise value (paid amount, due amount, or per-fee-head amount), the receipt renders its rupee value as a string with exactly two decimal places equal to the Paise value divided by 100.

**Validates: Requirements 11.3**

## Error Handling

Error handling follows DukanX conventions (observable response or propagation; never a silent swallow) and the requirements' explicit error behaviors:

- **Tenant context unavailable (1.5, 1.7).** If the active `Tenant_Id` cannot be resolved from the session, the operation aborts, accesses no data, leaves persisted data unchanged, and returns an unresolved-tenant error.
- **Unknown navigation id (4.5).** An unmapped school id resolves to no screen via `tryGetScreenForItem` (null), the current screen is retained, an "unavailable" indication is shown, and no unhandled exception is raised.
- **Dashboard/alert query states (5.7, 5.8, 5.9).** A query in progress shows a loading indicator; an empty result shows a zero/empty-state indicator; a failed query shows an error indication — none fabricate a count.
- **Route access denied (6.5, 6.6).** A user lacking the required `School_Permission`, or a route with no mapping, is blocked, redirected to the default authorized landing screen, and shown an access-denied indication; no part of the guarded screen renders.
- **Unauthorized PII access (7.7).** A user not in the confirmed authorized-role list is denied, returns/exports no data, and a denied audit entry is written.
- **Sync failures (8.7).** A failed sync entry retains its pending local change, leaves successfully synced records unaffected, and is retried on the next connectivity-restored event; it is never discarded.
- **Write validation (10.5, 10.6).** A null/non-numeric/zero/negative fee amount, or an invalid student/class linkage, rejects the save, persists nothing, leaves any prior record unchanged, retains entered values, and shows an error identifying the field or linkage.
- **Fee receipt missing fields (11.5, 11.6).** A missing student name/class/breakdown renders a fixed placeholder and still renders the remaining fields; a zero-head breakdown renders the placeholder and still renders paid and due amounts — never an error.
- **Governance halts (1.3, 1.8, 1.9, 1.13, 1.16, 2.7, 3.11, 7.1, 7.9, 14.x).** Schema/enum changes (Mini_Gate), hard deletions (reference search + sign-off), out-of-scope changes, ground-truth contradictions, unconfirmed PII policy, and phase completion halt for explicit recorded sign-off rather than proceeding.

## Testing Strategy

Property-based testing **is appropriate** for this feature: integer-Paise money invariants, RID well-formedness, tenant isolation, idempotent migration and sync reconciliation, write-path validation rejection, fee-receipt rendering and paise formatting, sidebar reachability, route access control, school-permission mapping, PII audit logging, and the other-types-unchanged invariant are pure-logic surfaces with universal "for all inputs" statements. Reachability/route registration, dashboard wiring, theming, UI loading/error states, and the Phase 0/4/9/10 artifacts are validated by example, widget, integration, smoke, or governance checks.

A property-based testing library is used for the language under test (Dart: `package:test` with a property-based helper such as `glados`; any backend Node.js logic uses `fast-check`). Properties are **not** implemented from scratch.

### Property-based tests

- Each correctness property above is implemented by a **single** property-based test running a **minimum of 100 iterations**.
- Each test is tagged with a comment referencing its design property in the format: **Feature: schoolerp-vertical-remediation, Property {number}: {property_text}**.
- Money generators produce integer Paise so floating-point never enters assertions (Property 1, 18); tenant generators produce distinct tenant pairs (Property 3); RID generators vary tenant ids including ids containing hyphens (Property 2); sync generators include forced-failure transports and interleaved WS/sync operations on the same RID (Property 14, 15); validation generators include null/non-numeric/zero/negative amounts and dangling student/class linkages (Property 16); receipt generators include missing name/class and zero-head records (Property 17); permission generators cover every `(UserRole, SchoolPermission)` pair including unmapped ones (Property 11, 12).
- **Highest-value properties to land first:** Property 1 (integer Paise), Property 3 (tenant isolation), Property 6 (other types preserved), Property 7 (sidebar reachability), Property 11 (route access control), Property 14 (sync reconciliation), Property 16 (write validation).

### Example-based unit & widget tests (non-property criteria)

- **Sidebar/scope (4.1, 4.6):** `getSectionsForBusinessType(schoolErp)` returns `_getSchoolSections()` (not retail); `/ac/students` binds to the more-complete screen and `AcStudentRegistrationScreen` gets a distinct non-colliding path.
- **Quick actions/alerts (5.1, 5.2, 5.3):** the schoolErp case presents exactly the four quick actions and three alerts, each wired to its screen/query, with no hardcoded count literal in the school branch.
- **Dashboard UI states (5.8, 5.9):** loading indicator while a query is in progress; error indication on failure.
- **Template dispatch (11.1):** `getTemplate(schoolErp)` returns `Fee_Receipt_Template`, not `_serviceTemplate`.
- **Write-path coverage (10.4):** each repository write invokes `AcValidators` before persistence.

### Integration & smoke tests (not PBT)

- **Offline-first (8.2):** 1–3 integration examples for the offline students/fees/attendance load + sync path; assert the screens read through the offline cache and the sync handler covers fees/attendance/exams.
- **Capability wiring (13.5):** confirm `businessCapabilityRegistry['schoolErp']` grants are actually read by the live schoolErp sidebar.
- **Encryption-at-rest (7.8):** verify and record per-PII-table encryption status.
- **Phase 0 (Requirement 3):** verify the `Verification_Report` exists, carries the required classifications with citations, resolves the `legacy_routes.dart` vs `app/routes.dart` discrepancy, and that zero non-report files changed during Phase 0.

### Governance checks (process gates)

Mini_Gate (schema/`UserRole`/Drift-table changes), deletion sign-off (reference search + `APPROVED`), STOP GATE adherence, ground-truth-contradiction halt, the Phase 4 policy-confirmation record, the regression-pass evidence, and the `Verification_Matrix` completeness are process checks recorded at each phase gate (Requirements 1.3, 1.8, 1.9, 1.13, 1.14, 1.16, 2.1–2.5, 2.7, 3.x, 7.x, 9.x, 12.x, 13.x, 14.x).

### Regression suite (Requirements 1.15, 13.7)

Each phase compares every non-school vertical against a recorded pre-change baseline across sidebar sections, capability flags, quick-action set, alert set, route guards, and resolved bill template, passing only when zero items change in any category for any vertical. Property 6 provides automated, input-varying coverage of this no-regression invariant; the full existing test suite runs at the Phase 10 gate to confirm no other vertical regresses before the vertical is declared shippable.
