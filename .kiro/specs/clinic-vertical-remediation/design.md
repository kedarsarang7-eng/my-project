# Clinic Vertical Remediation — Bugfix Design

## Overview

The DukanX **Clinic (Doctor Clinic / OPD)** vertical (`BusinessType.clinic`) suffers from five **Critical** defects — a cross-tenant patient-data leak in `DoctorDashboardRepository.getPatientStats()`, a literal `'SYSTEM'` tenant id written on every patient/appointment create, the complete absence of a clinic RBAC layer, missing PHI/consent safeguards, and the lack of an allergy↔prescription clinical-safety check — alongside a cluster of High/Medium/Low defects spanning miswired navigation (`patient_history` → `PatientListScreen`), orphaned OPD screens (queue/token, calendar, refill, consultation), two parallel clinic stacks (`features/doctor/*` vs `features/clinic/*`), hardcoded V2 dashboard counts, missing OPD features (UHID/MRN, DOB, appointment slots, reminders), validation gaps (vitals, phone, medicine-quantity parsing), and theming/accessibility issues.

Scope is the **Flutter app layer only** — `features/doctor/`, `features/clinic/`, the sidebar config + navigation handler, the V2 dashboard widgets, and the Drift local DB. **No DynamoDB/Lambda backend work is in scope this pass.** Where a fix crosses the backend boundary (SMS/WhatsApp dispatch, lab-file storage, server-side reconciliation), the design provides the app-layer integration point and flags the backend portion as out of scope.

The fix strategy is **phased (Phases 0–8) with human STOP gates**, matching the bugfix requirements and steering rules. Phase 0 is **verify-before-fix**: every audit item marked *unverified* must be confirmed against the live codebase before any fix touches it; if Ground Truth contradicts the code, work STOPS and reports. Phase 2 contains **two open architecture decision gates** that this design treats **conditionally and does not pre-resolve**:

- **Decision 2.1 — Canonical clinic stack:** which of `features/doctor/*` (sidebar-wired) or `features/clinic/*` (route-wired) is canonical; the other is deprecated, **not deleted, without explicit sign-off**.
- **Decision 2.2 — Inventory contradiction:** either (a) grant clinic a minimal pharmacy-inventory capability + sidebar item, **OR** (b) stop auto-deducting stock in `clinic_billing_service`.

Fix conditions that depend on these gates are written conditionally and must not be implemented until the corresponding decision is signed off.

## Glossary

- **Bug_Condition (C)**: The family of conditions that trigger a clinic defect — an input/state in which the clinic vertical leaks data across tenants, writes an unattributable `'SYSTEM'` owner id, renders doctor-only clinical content without role enforcement, stores PHI without consent/audit, prescribes a contraindicated drug, displays hardcoded dashboard data, or accepts unvalidated clinical input. `isBugCondition(input)` (below) decides membership.
- **Property (P)**: The desired behavior for buggy inputs — counts are tenant-scoped, writes carry the real session owner id (aligned to `clinic_billing_service`), doctor-only content is role-gated, PHI capture records consent + access logs, contraindicated Rx is warned/blocked, dashboard counts come from live queries, and clinical input is range/format validated.
- **Preservation**: Existing behavior that must remain unchanged — every other business vertical, the audit-confirmed `✅ present` clinic features, the `defaultGstRate: 0.0` / `gstEditable: true` semantics, the `clinic_billing_service` `doctorId` attribution (the alignment target, not the thing being changed), the offline-first write→enqueue contract, and the 13 already-correct clinic sidebar ids.
- **F / F'**: Original (unfixed) vs fixed clinic code.
- **Decision Gate**: An open architecture choice (2.1 canonical stack, 2.2 inventory) requiring human sign-off; dependent fixes are conditional on it.
- **`DoctorDashboardRepository`**: `features/doctor/.../doctor_dashboard_repository.dart` — owns `getPatientStats`, `getSmartInsights`, weekly/monthly analytics, revenue/visit counts. Source of the unfiltered patient query (§8 of audit).
- **`PatientRepository` / `AppointmentRepository`**: `features/doctor/*` repos that write Drift rows + `SyncManager.enqueue` with literal `userId: 'SYSTEM'`.
- **`clinic_billing_service`**: `features/doctor/.../clinic_billing_service.dart` — already correctly attributes bills/sync to `doctorId`; the **alignment target** for tenant id, plus owner of the hardcoded `defaultConsultationFee = 500.0` and `addPrescriptionToBill()` stock deduction.
- **`PatientModel`**: `features/doctor/.../patient_model.dart` — holds `name`, `phone`, `address`, `bloodGroup`, `chronicConditions`, `allergies`, static `age int?`, `id` (UUID) + `qrToken`; no consent flag, no DOB, no UHID/MRN.
- **`UserRole` / `RolePermissions`**: `lib/core/models/user_role.dart` — `{owner, manager, staff, accountant, unknown}`; no clinic roles. `effectiveRole = staffRole ?? role` (`session_manager.dart`).
- **`ClinicRole` / clinic `role_guard.dart`**: a parallel, unenforced clinic-role concept in `features/clinic/` not integrated with the sidebar `RolePermissions`.
- **`SidebarNavigationHandler` / `_getClinicSections()`**: `lib/widgets/desktop/sidebar_navigation_handler.dart` (`getScreenForItem`) + `sidebar_configuration.dart` — the `itemId → Widget` resolver and clinic sidebar config.
- **`BusinessAlertsWidget`**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` — clinic branch hardcodes `'18'` (Today's Appointments) and `'7'` (Pending Lab Reports), ignoring the real `alertCountsProvider`.
- **`SessionManager` owner id**: the tenant-scoped identity (`ownerId` / `currentBusinessId`) the app already uses for isolation; the `clinic_billing_service` `doctorId` convention resolves from it.

## Bug Details

### Bug Condition

The clinic vertical exhibits a **family** of bug conditions grouped by phase. Membership in the bug set is the union of the sub-conditions below; preservation applies to every input outside this set. Decision-gated items (2.1, 2.2) are explicitly excluded from the actionable bug set until their gate is signed off.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input — one of { DbQuery, RepoWrite, Navigation, Render, RxSave, FieldEntry }
  OUTPUT: boolean

  // --- Phase 1: tenant isolation & attribution (Critical) ---
  IF input is DbQuery on patients via getPatientStats
       AND query has NO owner/tenant filter
    RETURN true
  IF input is RepoWrite by PatientRepository OR AppointmentRepository
       AND written userId == 'SYSTEM'
    RETURN true
  IF input is RepoWrite AND session.ownerId == null
       AND code falls back to (ownerId ?? 'SYSTEM')
    RETURN true

  // --- Phase 2: RBAC, PHI & clinical safety (Critical) ---
  IF input is Render of visit_screen diagnosis/private-notes
       AND NO clinical role check is enforced
    RETURN true
  IF input is RepoWrite of a patient record
       AND PatientModel has no consent flag OR no access-log entry is produced
    RETURN true
  IF input is RxSave for a drug
       AND patient.allergies CONTAINS a contraindication for that drug
       AND NO warn/block occurs
    RETURN true

  // --- Phase 3 / 5 / 6 / 7: nav, dashboard, billing, validation ---
  IF input is Navigation with itemId == 'patient_history'
       AND resolvedScreen == PatientListScreen   // should be PatientHistoryScreen
    RETURN true
  IF input is Render of clinic BusinessAlertsWidget
       AND displayed counts are literals ('18' / '7') instead of live queries
    RETURN true
  IF input is FieldEntry of vitals/phone/age/medicine-quantity
       AND value is out-of-range/invalid AND is silently accepted or defaulted
    RETURN true

  // --- Decision-gated: NOT actionable until sign-off ---
  // (2.1 canonical stack, 2.2 inventory contradiction) -> excluded here

  RETURN false
END FUNCTION
```

**Expected correct behavior for buggy inputs (P):**
```
FUNCTION expectedBehavior(result)
  RETURN tenantScoped(result)                 // counts/writes carry real owner id, never 'SYSTEM'
     AND failsSafeWhenOwnerMissing(result)    // block/error instead of 'SYSTEM' bucket
     AND clinicalContentRoleGated(result)     // diagnosis/private notes enforce role
     AND phiConsentAndAuditCaptured(result)   // consent flag + access log present
     AND contraindicationWarnedOrBlocked(result)
     AND dashboardCountsFromLiveQueries(result)
     AND clinicalInputValidated(result)       // ranges/format enforced with feedback
END FUNCTION
```

### Examples

- **Cross-tenant leak (1.2 → 2.2):** Clinic A (owner `usr_A`) and Clinic B (owner `usr_B`) share one local DB. `getPatientStats()` runs `_db.select(_db.patients).get()` with no filter → Clinic A's dashboard "Total Patients" includes Clinic B's patients. Expected: count filtered to `usr_A` only.
- **`'SYSTEM'` attribution (1.3/1.4 → 2.3/2.4):** Receptionist registers patient "Asha Rao" → row written with `userId: 'SYSTEM'`; sync op enqueued as `'SYSTEM'`. Expected: row + sync carry the real session owner id (same source `clinic_billing_service` uses for `doctorId`).
- **Fail-unsafe fallback (1.7 → 2.7):** A session with `ownerId == null` writes a visit → `ownerId ?? 'SYSTEM'` silently buckets it under `'SYSTEM'`. Expected: the write is blocked/surfaced as an error, never bucketed.
- **Unenforced doctor-only (1.10 → 2.10):** A receptionist opens `visit_screen` → sees diagnosis and "private notes (only visible to doctor)". Expected: role check hides/blocks those fields for non-clinical roles.
- **No consent/audit (1.11 → 2.11):** A patient with `allergies`, `chronicConditions` is stored/read with no consent flag and no access-log entry. Expected: consent captured on create; read/write access logged.
- **Contraindicated Rx (1.12 → 2.12):** Patient allergic to "Penicillin"; clinician saves an Rx for "Amoxicillin" → saved silently. Expected: contraindication check warns/blocks before save.
- **Miswired history (1.15 → 2.15):** User clicks "Patient History" → lands on plain `PatientListScreen`. Expected: opens `PatientHistoryScreen` for a chosen patient (via picker) or the item is relabeled.
- **Hardcoded dashboard (1.21 → 2.21):** Clinic dashboard always shows "Today's Appointments = 18", "Pending Lab Reports = 7" regardless of reality. Expected: both sourced from live queries.
- **Unvalidated vitals (1.28 → 2.28):** SpO2 entered as `"250"` or `"abc"` is accepted. Expected: range 0–100 enforced with feedback.
- **Silent quantity default (1.26 → 2.26):** Dosage `"1-0-1"` / duration `"5 days"` fails to parse → quantity silently becomes `1.0`, under-billing. Expected: parse failure surfaced to the user.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- All non-clinic business types (retail, grocery, pharmacy, restaurant, vegetablesBroker, etc.) resolve their sidebar, capabilities, RBAC, and dashboards exactly as before — no change leaks out of the clinic vertical (3.1).
- `clinic_billing_service` continues attributing bills/sync to `doctorId` as it already does correctly; patient/appointment repos are aligned **to it**, not the reverse (3.2).
- Clinic billing continues using `defaultGstRate: 0.0` / `gstEditable: true` with `taxPercent: 0.0` on OPD lines; GST semantics are not changed beyond what is explicitly specified (3.3).
- Audit-confirmed `✅ present` features continue functioning with identical behavior except where a clause explicitly changes them — `DoctorDashboardScreen` real KPIs (`getPatientStats`, `watchDailyAppointments`, weekly/monthly analytics, revenue/visit counts), `SafePrescriptionListScreen` + `AddPrescriptionScreen`, `MedicineMasterScreen`, `visit_screen` vitals/diagnosis/templates/private-notes capture, `LabReportsScreen` pending-report query, `DoctorRevenueScreen` per-doctor revenue (3.4).
- The clinic capability registry continues granting exactly its current capabilities and excluding all product/inventory/purchase/scan capabilities — **except** any minimal inventory capability explicitly added under signed-off Decision 2.2 (3.5).
- The 13 already-correct clinic sidebar ids (`clinic_dashboard`, `daily_appointments`, `patients_list`, `add_patient`, `scan_qr`, `appointments`, `prescriptions`, `medicine_master`, `lab_reports`, `doctor_revenue`, `new_sale`, `revenue_overview`, `device_settings`) continue resolving to their current screens with the same capability gating (3.6).
- `/clinic/*` named routes wrapped in `VendorRoleGuard` + `BusinessGuard(allowedTypes:[clinic])` remain guarded as before; deprecating a stack under Decision 2.1 does not remove guards from the survivor (3.7).
- Clinic data stays offline-first (write local Drift, then `SyncManager.enqueue`); only the tenant id on enqueue is corrected, not the offline-first contract (3.8).
- Existing non-`'SYSTEM'` patient/appointment rows that already carry a real owner id remain correctly attributed; the backfill migration touches only `'SYSTEM'` rows (3.9).
- Any Drift table modified for UHID/MRN, DOB, consent flag, slot duration, or access logging preserves all existing columns and rows via an explicit migration with no data loss (3.10).
- Both clinic stacks remain on disk prior to Decision 2.1 sign-off (no deletion); the `features/doctor` sidebar path stays the primary path (3.11).
- The V2 dashboard alerts/quick-actions continue showing the dedicated clinic branches (New Patient / Appointments / Write Rx, low-stock "Alerts" correctly hidden since clinic lacks `accessLowStockAlert`) — only the hardcoded counts are replaced with live data (3.12).

**Scope:**
All inputs that do NOT match `isBugCondition` are completely unaffected by this remediation. This explicitly includes:
- Every other business vertical's sidebar items, capability config, and dashboards.
- Generic billing, parties, reports, and system screens for non-clinic types.
- Cloud sync for non-clinic entities and the offline-first write→enqueue mechanism itself.
- Authentication/session resolution for non-clinic roles.
- The two decision-gated stacks/inventory behaviors until their gate is signed off.

## Hypothesized Root Cause

Based on the audit (read-only, evidence-cited) and the bugfix requirements, the most likely causes are:

1. **Unfiltered patient query (Critical):** `getPatientStats()` runs `_db.select(_db.patients).get()` with an explicit "all patients for now" comment — the owner filter was deferred and never added. Other queries (`visits`, `appointments`) are filtered by `doctorId`, so the omission is isolated to the patient count path.

2. **Placeholder tenant id (Critical):** `PatientRepository`/`AppointmentRepository` write `userId: 'SYSTEM'` with in-code comments "Should be doctor/vendor ID ideally". This is a development placeholder never replaced with the session owner id. The correct convention already exists in `clinic_billing_service` (`doctorId` as `userId`) — the patient/appointment repos simply never adopted it. Compounding this, `ownerId ?? 'SYSTEM'` fallbacks across dashboard/visit/revenue/prescription paths mean any null-owner session silently shares one bucket.

3. **No clinic RBAC integration (Critical):** `UserRole` was defined for generic retail/owner staffing and never extended for clinical roles. A parallel `ClinicRole` enum + `features/clinic/widgets/role_guard.dart` were built but never wired into the sidebar `RolePermissions`, so `visit_screen` "doctor-only" content renders for everyone.

4. **PHI stored without governance (Critical):** `PatientModel` was modeled as a plain data holder; consent and access-logging were never requirements at model-design time, so sensitive columns are stored/read with no consent flag and no audit trail.

5. **No contraindication logic (Critical):** Allergies were treated as a display concern (a passive banner in `visit_screen`); the Rx-save path has no hook that cross-references `patient.allergies` against the prescribed drug.

6. **Navigation config drift (High):** `patient_history` maps to `PatientListScreen` with comment "Default to patient list for selection" — a stopgap before a patient-picker existed. Numerous OPD screens (queue/token, calendar, consultation, refill) were built under `features/clinic/*` and `features/doctor/*` but only ever wired via named routes, never added to `_getClinicSections()`.

7. **Two parallel stacks (High, decision-gated):** `features/doctor/*` and `features/clinic/*` independently implement patient history, lab ordering, consultation, and dashboard — likely two iterations that were never reconciled. Whether they write the same Drift `patients` table is *unverified* (a Phase 0 confirmation item).

8. **Hardcoded dashboard data (High/Medium):** the clinic branch of `BusinessAlertsWidget` and `getSmartInsights.avgTime` use literals because the corresponding live providers/columns (today's-appointments count, pending-lab count, visit-duration tracking) were never wired/added.

9. **Inventory three-way contradiction (High, decision-gated):** `modules` config lists `'inventory'`, the capability registry grants none, the sidebar exposes none, yet `addPrescriptionToBill()` deducts stock — an unreconciled mismatch between config intent and capability/UI reality.

10. **Validation gaps (Medium):** vitals use `TextInputType.text` with no validators; `phone`/`age` are optional/unvalidated; `_calculateMedicineQuantity` swallows parse failures and defaults to `1.0` — all symptomatic of happy-path-only input handling.

> **Phase 0 caveat:** Items flagged *unverified* in the audit (follow-up/refill invocation paths; whether both stacks share the `patients` table; full bodies of `appointment_screen`, `patient_list_screen`, `add_patient_screen`, `lab_report_repository`, `prescription_repository`; `prescription_pharmacy_bridge` wiring; lab-upload placeholder behavior; `SafePrescriptionListScreen` body past line 80) MUST be confirmed against the live code before the dependent fix is applied. If Ground Truth contradicts the code, STOP and report.

## Correctness Properties

Property 1: Bug Condition — Tenant-Scoped Patient Counts

_For any_ invocation of `getPatientStats()` where multiple owners' rows exist in the shared local DB, the fixed `DoctorDashboardRepository` SHALL return counts filtered to the authenticated owner/clinic id, never aggregating rows belonging to other owners.

**Validates: Requirements 2.2**

Property 2: Bug Condition — Real Owner-Id Attribution on Write

_For any_ patient or appointment create where `session.ownerId` is a valid non-null id, the fixed `PatientRepository`/`AppointmentRepository` SHALL write the Drift row and enqueue the sync op with that real owner id (the same source `clinic_billing_service` uses for `doctorId`), never the literal `'SYSTEM'`.

**Validates: Requirements 2.3, 2.4, 2.6**

Property 3: Bug Condition — Fail-Safe on Missing Owner

_For any_ patient/appointment/visit write where `session.ownerId` is null, the fixed code SHALL block the write or surface an error, never silently substituting `'SYSTEM'` via `ownerId ?? 'SYSTEM'`.

**Validates: Requirements 2.7**

Property 4: Bug Condition — Backfill Re-Attribution Correctness

_For any_ existing patient/appointment row whose `userId == 'SYSTEM'`, the fixed migration SHALL re-attribute it to the correct owner id, while _for any_ row already carrying a real owner id the migration SHALL leave it unchanged (no data loss, explicit migration).

**Validates: Requirements 2.5, 3.9, 3.10**

Property 5: Bug Condition — Clinical Role Enforcement

_For any_ render of `visit_screen` diagnosis/private-notes by a user lacking the required clinical (doctor) role, the fixed code SHALL restrict that content, so "doctor-only" is actually enforced; conversely a doctor-role user SHALL retain full access.

**Validates: Requirements 2.8, 2.9, 2.10**

Property 6: Bug Condition — PHI Consent & Access Logging

_For any_ patient record create/read, the fixed code SHALL capture a consent flag on create and produce an access-log entry on patient/visit read or write.

**Validates: Requirements 2.11**

Property 7: Bug Condition — Allergy↔Prescription Safety Check

_For any_ Rx save where the prescribed drug is contraindicated by the patient's recorded allergies, the fixed code SHALL warn or block before persisting; _for any_ non-contraindicated drug the save SHALL proceed unchanged.

**Validates: Requirements 2.12**

Property 8: Bug Condition — Reachable Patient History

_For any_ sidebar activation of `patient_history`, the fixed handler SHALL route to `PatientHistoryScreen` for a selected `patientId` (via picker) or to an accurately relabeled target, never silently to the plain `PatientListScreen` under a "History" label.

**Validates: Requirements 2.15**

Property 9: Bug Condition — Appointment Slot & Double-Booking Guard

_For any_ appointment scheduled for a doctor that overlaps an existing appointment's slot for the same doctor, the fixed scheduling logic SHALL reject/flag the overlap; non-overlapping slots SHALL schedule normally.

**Validates: Requirements 2.18**

Property 10: Bug Condition — Live Dashboard Counts

_For any_ render of the clinic `BusinessAlertsWidget`, the fixed code SHALL source "Today's Appointments" and "Pending Lab Reports" from live queries (and SHALL compute or omit `avgTime` rather than show the `'15 mins'` literal), never the `'18'`/`'7'` literals.

**Validates: Requirements 2.21, 2.22**

Property 11: Bug Condition — Clinical Input Validation

_For any_ clinical field entry — vitals (e.g., SpO2 must be 0–100), patient phone format, and medicine-quantity dosage/duration parsing — the fixed code SHALL validate and either reject out-of-range/invalid input with feedback or surface parse failure, never silently accept or default (e.g., quantity → `1.0`).

**Validates: Requirements 2.28, 2.29, 2.26**

Property 12: Bug Condition — Error-State UI for Prescription List

_For any_ load of `SafePrescriptionListScreen` where the repository throws, the fixed `FutureBuilder` SHALL render an error-state branch with a message and retry affordance, never leaving the error unhandled.

**Validates: Requirements 2.31**

Property 13: Preservation — Non-Clinic Verticals & Generic Screens Unchanged

_For any_ input that does NOT match `isBugCondition` and does NOT target the clinic vertical, the fixed code SHALL produce exactly the same result as the original — every other business type's sidebar, capabilities, RBAC, dashboards, and the generic billing/parties/reports/system screens are byte-for-byte unaffected.

**Validates: Requirements 3.1, 3.6, 3.7, 3.12**

Property 14: Preservation — Billing Attribution & GST Semantics Unchanged

_For any_ clinic bill/sync op, the fixed code SHALL CONTINUE attributing to `doctorId` and SHALL CONTINUE applying `defaultGstRate: 0.0` / `gstEditable: true` with `taxPercent: 0.0` on OPD lines — the patient/appointment repos are aligned to `clinic_billing_service`, not the reverse.

**Validates: Requirements 3.2, 3.3**

Property 15: Preservation — Confirmed `✅ present` Features & Offline-First Contract

_For any_ exercise of an audit-confirmed `✅ present` feature (Doctor dashboard KPIs, `SafePrescriptionListScreen`/`AddPrescriptionScreen`, `MedicineMasterScreen`, `visit_screen` capture, `LabReportsScreen` pending query, `DoctorRevenueScreen`) and _for any_ clinic write, the fixed code SHALL preserve existing behavior and the offline-first write→enqueue contract, changing only the tenant id on enqueue and the specific clauses above.

**Validates: Requirements 3.4, 3.5, 3.8, 3.11**

> **Decision-gated properties (NOT asserted until sign-off):** Property G2.1 (canonical-stack adoption / deprecation per Decision 2.1) and Property G2.2 (inventory consistency per Decision 2.2) are deferred. Until their gate is signed off, the only related assertion is preservation: both stacks remain on disk and the inventory capability set is unchanged (covered by Properties 13–15).

## Fix Implementation

### Changes Required

Assuming the root-cause analysis holds (and Phase 0 confirms the *unverified* items), changes are sequenced by phase with STOP gates between them. Each phase ends by listing touched files, running `flutter analyze` on them, and yielding for approval.

---

### Phase 0 — Verification Gate (read-only, no code)

**Goal**: Confirm every *unverified* audit item against the live codebase and record the result.

**Actions**:
1. Read full bodies of `appointment_screen.dart`, `patient_list_screen.dart`, `add_patient_screen.dart`, `lab_report_repository.dart`, `prescription_repository.dart`, `followup_repository.dart`, and `SafePrescriptionListScreen` past line 80.
2. Confirm whether `features/doctor` and `features/clinic` write the **same** Drift `patients` table (decisive input for Decision 2.1).
3. Confirm `prescription_pharmacy_bridge.dart` wiring and the exact lab-upload placeholder behavior.
4. Record each confirmation. **If any Ground Truth/audit claim contradicts the code → STOP and report; do not route around it.**

**Output**: `PHASE 0 COMPLETE — AWAITING APPROVAL`. No source files modified.

---

### Phase 1 — Tenant Isolation & Data Attribution (Critical)

**File**: `features/doctor/.../doctor_dashboard_repository.dart`
- **`getPatientStats()`**: add an owner/tenant filter (`where(patients.userId.equals(ownerId))`) so totals/new-patient counts reflect only the authenticated tenant. (Property 1 / 2.2)

**File**: `features/doctor/.../patient_repository.dart`
- Replace `userId: 'SYSTEM'` on create with the resolved session owner id (same source as `clinic_billing_service.doctorId`). (Property 2 / 2.3, 2.6)

**File**: `features/doctor/.../appointment_repository.dart`
- Replace `userId: 'SYSTEM'` on the enqueued sync op with the resolved session owner id. (Property 2 / 2.4, 2.6)

**Owner-id resolution helper** (shared)
- Introduce/centralize a single owner-id resolver used by patients, appointments, bills, and sync. If `ownerId` is null → **fail safe**: block the write and surface an error; do **not** apply `?? 'SYSTEM'`. (Property 3 / 2.7)

**File**: `lib/core/database/*` (Drift migration)
- Add an **explicit, versioned** Drift migration that backfills `userId == 'SYSTEM'` patient/appointment rows to the correct owner id. Rows with a real owner id are untouched. Documented + tested; no silent schema/data change. (Property 4 / 2.5, 3.9, 3.10)
- Migration guard so it runs once; on a single-device local-first install the "current owner" is the re-attribution target (note the multi-owner-on-one-device caveat for sign-off).

---

### Phase 2 — RBAC, PHI/Privacy & Clinical Safety (Critical) + Decision Gates

**RBAC (Property 5 / 2.8, 2.9, 2.10)**
- **File**: `lib/core/models/user_role.dart` — add clinic roles (doctor / receptionist / nurse) **or** map them onto existing roles, sufficient to allow receptionist appointment booking while blocking diagnosis/private notes.
- **File**: `lib/core/session/session_manager.dart` — extend role-string mapping + `effectiveRole` for the new/mapped roles (preserve, do not escalate, unknown).
- **Integrate** the existing `ClinicRole` enum + `features/clinic/widgets/role_guard.dart` with the main `RolePermissions` used by the sidebar.
- **File**: `features/doctor/.../visit_screen.dart` — gate diagnosis and "private notes" behind the clinical-role check so doctor-only content is actually restricted.

**PHI / consent / audit (Property 6 / 2.11)**
- **File**: `features/doctor/.../patient_model.dart` + Drift `patients` table — add a `consent` flag (explicit migration). 
- Add **access logging** for patient/visit reads and writes (append-only audit entries), plus an at-rest protection strategy for sensitive columns (documented; app-layer scope).

**Clinical safety (Property 7 / 2.12)**
- **Rx-save path** (`AddPrescriptionScreen` / prescription repository) — before persisting, cross-reference the prescribed drug against `patient.allergies` and **warn or block** on contraindication. Non-contraindicated drugs save unchanged.

**Decision Gate 2.1 — Canonical clinic stack (conditional, do NOT pre-resolve)**
- Until sign-off: leave **both** stacks on disk; keep `features/doctor` as the primary sidebar path; MAY wire the *superior orphaned screens* (token/queue, calendar) into the sidebar **without deleting either stack**.
- On sign-off: adopt the chosen canonical stack and **deprecate (not delete)** the other; the survivor keeps its guards. (Property G2.1 — deferred)

**Decision Gate 2.2 — Inventory contradiction (conditional, do NOT pre-resolve)**
- On sign-off, implement exactly one of:
  - (a) grant clinic a **minimal pharmacy-inventory capability** + a sidebar item enabling stock-in for dispensed meds, making `modules`/capability/sidebar/billing mutually consistent; **or**
  - (b) **stop auto-deducting stock** in `clinic_billing_service.addPrescriptionToBill()`.
- Until sign-off: capability set unchanged (Property 15 / 3.5). (Property G2.2 — deferred)

---

### Phase 3 — Navigation Correctness & Screen Exposure (High)

**File**: `lib/widgets/desktop/sidebar_navigation_handler.dart`
- `patient_history` → route to a **patient picker** that opens `PatientHistoryScreen(patientId:)`, or relabel the item. (Property 8 / 2.15)
- Register cases for the orphaned OPD screens to be wired (at minimum token/queue + calendar), with proper owner id and capability gating; imports added. (2.16 — conditional on Decision 2.1 for canonical source)

**File**: `lib/widgets/desktop/sidebar_configuration.dart` (`_getClinicSections()`)
- Add a **"Reports & Accounts"** section exposing at minimum `expenses`, `daybook`, `accounting_reports`, `outstanding` (receivables), and `backup` — **config-only**, since these ids already resolve in the handler. (2.17)
- Add the queue/calendar items gated by appropriate capabilities. (2.16)

**Appointments model** (`appointment_model` / `appointment_repository.dart`) + Drift migration
- Add slot length/duration and a **double-booking guard** for the same doctor on overlapping slots. (Property 9 / 2.18)

**Patient identity** (`patient_model.dart` + Drift migration)
- Add a human-readable **UHID/MRN** alongside the internal UUID. (2.19, 3.10)

**Reminders** (`appointment_screen.dart`)
- Add an **opt-in SMS/WhatsApp reminder** integration point with patient opt-in; backend dispatch is **out of scope this pass** and flagged accordingly. (2.20)

---

### Phase 5 — Dashboard Data Integrity (High/Medium)

**File**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
- Replace the clinic-branch literals `'18'`/`'7'` with live counts (today's appointments; pending lab reports) via the real provider, mirroring the grocery/hardware branches. (Property 10 / 2.21)

**File**: `features/doctor/.../doctor_dashboard_screen.dart` + `doctor_dashboard_repository.dart`
- Compute `avgTime` from real visit-duration data, or **omit** the metric until duration tracking exists (no `'15 mins'` literal). (Property 10 / 2.22)
- Introduce a **consolidated Riverpod provider** so a rebuild does not independently re-run `getPatientStats`/`getSmartInsights`/weekly/monthly/alerts. (2.23)
- Move weekly/monthly bucketing to SQL `GROUP BY` instead of loading all rows and aggregating in Dart. (2.24)

---

### Phase 6 — Billing & Business-Logic Correctness (Medium)

**File**: `features/doctor/.../clinic_billing_service.dart`
- Source the consultation fee from `DoctorProfile` instead of the hardcoded `defaultConsultationFee = 500.0`. (2.25) — GST semantics unchanged (Property 14 / 3.3).
- `_calculateMedicineQuantity`: on dosage/duration parse failure, **surface the failure to the user** instead of defaulting to `1.0`. (Property 11 / 2.26)

**File**: `features/doctor/.../lab_reports_screen.dart`
- Replace the "placeholder for file picking" with a real **file pick + storage write** (app-layer); the storage backend integration is flagged where it crosses the no-backend boundary. (2.27)

---

### Phase 7 — Data Validation + Theming & Accessibility (Medium/Low)

**Validation (Property 11 / Property 12)**
- `visit_screen.dart`: add validators/ranges for vitals (SpO2 0–100; plausible BP/Pulse/Temp) with feedback. (2.28)
- Patient create / emergency-visit flow: validate phone format, prompt for required fields, detect likely duplicate patients. (2.29)
- `patient_model.dart` + Drift migration: store **date of birth** and derive age so it stays current. (2.30, 3.10)
- `SafePrescriptionListScreen`: add an **error-state branch** to the `FutureBuilder` with message + retry. (2.31)

**Theming & accessibility (Low)**
- Replace hardcoded `Colors.white` / `FuturisticColors` in clinic dialogs/`visit_screen`/dashboard with **theme-aware colors**. (2.32)
- Add explicit **semantic labels** to symptom `FilterChip`s / `ActionChip` templates. (2.33)
- Pair color with text/icon for status (visit banner, allergy alert, alert count badges) so meaning is not color-only. (2.34)
- Relabel `sync_status` to reflect Backup, or split Sync and Backup into accurately labeled items. (2.35)

---

### Data Model & Migration Summary

All schema changes are **additive** and applied via **explicit, versioned Drift migrations** preserving existing columns/rows (3.10):

| Change | Table/Model | Phase | Migration |
|---|---|---|---|
| Backfill `'SYSTEM'` → real owner id | `patients`, `appointments` | 1 | Data migration, guarded, `'SYSTEM'`-only |
| `consent` flag | `patients` / `PatientModel` | 2 | Add nullable column, default unconsented |
| Access-log entries | new audit table | 2 | Append-only table create |
| Slot length / duration | `appointments` | 3 | Add nullable column + guard logic |
| UHID/MRN | `patients` / `PatientModel` | 3 | Add column, backfill generated MRN |
| Date of birth | `patients` / `PatientModel` | 7 | Add nullable DOB; derive age |

> **Conventions** (steering): new IDs follow the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`; money in **new** code uses integer paise; tenant isolation preserved; `defaultGstRate`/`gstEditable` semantics untouched; no other business vertical modified.

## Testing Strategy

### Validation Approach

Two-phase: first surface counterexamples that demonstrate each defect on the UNFIXED code (confirming/refuting root causes), then verify the fix corrects buggy inputs and preserves all non-buggy behavior. Every Critical/High fix requires a test. Property-based testing is favored for preservation because it generates many inputs across the domain and catches edge cases manual tests miss.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples BEFORE implementing the fix; confirm or refute root-cause analysis. If refuted, re-hypothesize.

**Test Plan**: Build tests that exercise each defect path against the UNFIXED code and assert the (currently wrong) behavior.

**Test Cases**:
1. **Cross-tenant leak**: seed two owners' patients → call `getPatientStats()` → assert count includes the other owner's rows (will fail/leak on unfixed code).
2. **`'SYSTEM'` attribution**: create a patient/appointment → inspect the written Drift row + enqueued sync op → assert `userId == 'SYSTEM'` (will be true on unfixed code).
3. **Fail-unsafe fallback**: null `ownerId` → write → assert it is bucketed under `'SYSTEM'` (will be true on unfixed code).
4. **Unenforced doctor-only**: render `visit_screen` as a non-doctor role → assert diagnosis/private notes are visible (will be visible on unfixed code).
5. **Contraindicated Rx**: patient allergic to drug X → save Rx for X → assert it saves with no warning (will save on unfixed code).
6. **Miswired history**: resolve `patient_history` → assert returned widget is `PatientListScreen` (will be true on unfixed code).
7. **Hardcoded dashboard**: render clinic `BusinessAlertsWidget` → assert literal `'18'`/`'7'` Text present regardless of data (will be true on unfixed code).
8. **Silent quantity default**: dosage `"1-0-1"`/duration `"5 days"` parse failure → assert quantity becomes `1.0` silently (will be true on unfixed code).
9. **Vitals out-of-range**: SpO2 `"250"` → assert accepted (will be accepted on unfixed code).

**Expected Counterexamples**:
- `getPatientStats()` total includes foreign-owner rows; new rows carry `userId == 'SYSTEM'`; diagnosis visible to receptionist; contraindicated Rx saved silently; `patient_history → PatientListScreen`; dashboard shows static `'18'`/`'7'`.
- Possible causes: missing owner filter, placeholder tenant id, absent role gate, no contraindication hook, stopgap nav mapping, hardcoded literals, happy-path-only validation.

### Fix Checking

**Goal**: For all inputs where the bug condition holds, the fixed code produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := clinic_fixed(input)
  ASSERT expectedBehavior(result)   // tenant-scoped, real owner id, role-gated,
                                     // consent+audit, contraindication handled,
                                     // live counts, validated input
END FOR
```

### Preservation Checking

**Goal**: For all inputs where the bug condition does NOT hold, the fixed code produces the same result as the original.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT clinic_original(input) == clinic_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation because:
- It generates many cases across the full set of sidebar ids, business types, and field inputs.
- It catches edge cases where an unrelated id/type accidentally matches a new code path.
- It gives strong guarantees that non-clinic and `✅ present` behavior is unchanged.

**Test Plan**: Catalog non-buggy inputs (all non-clinic sidebar ids and business types; the 13 already-correct clinic ids; `✅ present` clinic features; non-`'SYSTEM'` rows; both decision-gated stacks pre-sign-off), observe their behavior on UNFIXED code, then assert identical behavior on FIXED code.

**Test Cases**:
1. **Non-clinic verticals**: for every non-clinic business type, assert sidebar/capability/RBAC/dashboard resolution is identical before and after.
2. **Already-correct clinic ids**: the 13 ids resolve to the same screens with the same capability gating.
3. **Billing attribution + GST**: clinic bills still attribute to `doctorId`; OPD lines keep `taxPercent: 0.0`, `defaultGstRate: 0.0`, `gstEditable: true`.
4. **Offline-first contract**: writes still go local Drift → `SyncManager.enqueue`; only the tenant id changes.
5. **Backfill scoping**: non-`'SYSTEM'` rows are untouched by the migration.
6. **Decision gates**: both stacks remain on disk; inventory capability set unchanged — pre-sign-off.

### Unit Tests

- `getPatientStats()` filters by owner id (Critical).
- Patient/appointment create writes real owner id; null owner fails safe (Critical).
- Backfill migration re-attributes only `'SYSTEM'` rows; preserves others; no data loss (Critical).
- Clinical-role gate hides diagnosis/private notes for non-doctor roles, shows for doctor (Critical).
- Consent flag captured on create; access-log entry produced on read/write (Critical).
- Allergy↔Rx contraindication warns/blocks for contraindicated drug, allows others (Critical).
- `patient_history` resolves to `PatientHistoryScreen` (via picker) (High).
- Double-booking guard rejects overlapping slots, allows non-overlapping (High).
- Vitals range validation (SpO2 0–100), phone-format validation, medicine-quantity parse-failure surfacing (Medium).
- `SafePrescriptionListScreen` renders error-state branch on repo throw (Medium).

### Property-Based Tests

- Generate random sidebar ids (clinic + non-clinic) → assert resolution unchanged for all non-buggy ids; `patient_history` always reaches history (preservation + Property 8).
- Generate random `(ownerId, otherOwnerId)` patient sets → assert `getPatientStats` count equals only `ownerId`'s rows (Property 1).
- Generate random owner-id values (including null) → assert real-id writes attribute correctly and null fails safe (Properties 2, 3).
- Generate random existing rows (`'SYSTEM'` and real) → assert migration re-attributes only `'SYSTEM'` (Property 4).
- Generate random `(drug, allergyList)` pairs → assert warn/block iff contraindicated (Property 7).
- Generate random appointment slot pairs → assert overlap rejected iff same doctor + overlapping window (Property 9).
- Generate random vitals/phone/dosage strings → assert validation accepts iff in-range/valid (Property 11).

### Integration Tests

- Login as Clinic A → dashboard counts exclude Clinic B's patients (tenant isolation end-to-end).
- Register patient → row + sync op carry real owner id; appears only under the correct tenant.
- Receptionist role → cannot view diagnosis/private notes; doctor role → can.
- Save contraindicated Rx → blocked/warned; save safe Rx → succeeds.
- Click "Patient History" → patient picker → `PatientHistoryScreen` opens with timeline.
- Render clinic dashboard → appointment/lab counts reflect seeded live data, update on change.
- Run app upgrade with `'SYSTEM'` rows present → migration backfills correctly, existing real-owner rows unchanged.
- Pre-sign-off: both clinic stacks load; inventory sidebar/capability unchanged (decision-gate preservation).
