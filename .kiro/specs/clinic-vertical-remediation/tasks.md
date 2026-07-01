# Implementation Plan

## Overview

Phased implementation plan for the DukanX Clinic (Doctor Clinic / OPD) vertical remediation bugfix. Follows the bug condition methodology: explore the bug (Property 1), preserve existing behavior (Property 2), implement the fix, then validate. Phases run in order with human STOP gates — Phase 0 (verify-before-fix) → Phase 1 (critical tenant isolation & attribution) → Phase 2 (RBAC, PHI & clinical safety + decision gates) → Phase 3 (navigation & screen exposure) → Phase 5 (dashboard data integrity) → Phase 6 (billing & business logic) → Phase 7 (validation, theming & accessibility) → Phase 8 (final verification). Decision Gates 2.1 (canonical clinic stack) and 2.2 (inventory contradiction) are NOT pre-resolved; dependent fixes stay conditional until signed off.

## Tasks

> **Bug-condition methodology + phased STOP gates.** Tasks 2 and 3 are written and run on the
> UNFIXED code first: the Bug Condition exploration test (Property 1) MUST FAIL (proving the
> defects exist), and the Preservation tests (Property 2) MUST PASS (capturing the baseline to
> protect). Implementation then proceeds in phases (1 → 2 → 3 → 5 → 6 → 7) with a STOP gate after
> each phase. After every phase: list files created/modified/deleted, run `flutter analyze` on
> touched files, output `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`.
> Do NOT auto-continue. Decision Gates 2.1 (canonical stack) and 2.2 (inventory) are NOT
> pre-resolved — their dependent fixes stay conditional until signed off. No deletions without
> sign-off. All schema/data changes use explicit, versioned Drift migrations (never silent).
> New code follows steering conventions (RID ids, integer paise for new money fields, tenant
> isolation, `defaultGstRate`/`gstEditable` semantics untouched, no other vertical modified).

- [x] 1. Phase 0 — Verification Gate (read-only, no code)
  - Confirm every audit item flagged **unverified** against the live codebase and record the result for each
  - Read full bodies of `appointment_screen.dart`, `patient_list_screen.dart`, `add_patient_screen.dart`, `lab_report_repository.dart`, `prescription_repository.dart`, `followup_repository.dart`, and `SafePrescriptionListScreen` past line 80
  - Confirm whether `features/doctor/*` and `features/clinic/*` write the **same** Drift `patients` table (decisive input for Decision 2.1)
  - Confirm `prescription_pharmacy_bridge.dart` wiring and the exact lab-upload placeholder behavior
  - Confirm the literal `userId: 'SYSTEM'` writes and `ownerId ?? 'SYSTEM'` fallbacks, the unfiltered `_db.select(_db.patients).get()` in `getPatientStats()`, the `'18'`/`'7'` literals in `business_alerts_widget.dart` clinic branch, and the `patient_history → PatientListScreen` mapping
  - **If any Ground Truth/audit claim contradicts the code → STOP and report the discrepancy; do not route around it**
  - No source files modified. Output `PHASE 0 COMPLETE — AWAITING APPROVAL` and stop
  - _Requirements: 1.1, 2.1_

- [x] 2. Write bug condition exploration tests (BEFORE implementing any fix)
  - **Property 1: Bug Condition** - Clinic Vertical Defect Family
  - **CRITICAL**: These tests MUST FAIL on unfixed code — failure confirms the defects exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: These tests encode the expected behavior — they will validate the fix when they pass after implementation
  - **GOAL**: Surface counterexamples that demonstrate each defect, confirming/refuting the root-cause analysis
  - **Scoped PBT Approach**: For deterministic defects, scope each property to concrete failing case(s) for reproducibility; use generators where a domain exists (owner-id sets, sidebar ids, drug/allergy pairs, slot pairs, vitals/phone/dosage strings)
  - Test details derived from the Bug Condition `isBugCondition(input)` in design; assertions match the Expected Behavior Properties:
    - Cross-tenant leak: seed two owners' patients, call `getPatientStats()`, assert the count leaks the other owner's rows (Property 1 / 1.2 → 2.2)
    - `'SYSTEM'` attribution: create a patient and an appointment, inspect the written Drift row + enqueued sync op, assert `userId == 'SYSTEM'` (Property 2 / 1.3, 1.4 → 2.3, 2.4, 2.6)
    - Fail-unsafe fallback: null `ownerId` write → assert it is bucketed under `'SYSTEM'` via `ownerId ?? 'SYSTEM'` (Property 3 / 1.7 → 2.7)
    - Unenforced doctor-only: render `visit_screen` as a non-doctor role → assert diagnosis/private notes are visible (Property 5 / 1.10 → 2.10)
    - Contraindicated Rx: patient allergic to drug X, save Rx for X → assert it saves with no warning (Property 7 / 1.12 → 2.12)
    - Miswired history: resolve `patient_history` → assert returned widget is `PatientListScreen` (Property 8 / 1.15 → 2.15)
    - Hardcoded dashboard: render clinic `BusinessAlertsWidget` → assert literal `'18'`/`'7'` text present regardless of data (Property 10 / 1.21 → 2.21)
    - Silent quantity default: dosage `"1-0-1"` / duration `"5 days"` parse failure → assert quantity becomes `1.0` silently (Property 11 / 1.26 → 2.26)
    - Vitals out-of-range: SpO2 `"250"` / `"abc"` → assert accepted with no validation (Property 11 / 1.28 → 2.28)
  - Run all tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct — it proves the defects exist)
  - Document counterexamples found to confirm root cause (e.g., "getPatientStats total includes foreign-owner rows"; "patient row written with userId == 'SYSTEM'"; "patient_history resolves to PatientListScreen")
  - Mark task complete when tests are written, run, and the failures are documented
  - _Requirements: 1.2, 1.3, 1.4, 1.7, 1.10, 1.12, 1.15, 1.21, 1.26, 1.28_

- [x] 3. Write preservation property tests (BEFORE implementing any fix)
  - **Property 2: Preservation** - Non-Clinic Verticals, Billing/GST & Confirmed Features
  - **IMPORTANT**: Follow observation-first methodology — run UNFIXED code on non-bug-condition inputs, record actual outputs, then assert those observed outputs
  - **GOAL**: Capture the regression baseline that the fix must not change
  - Observe behavior on UNFIXED code for inputs where `isBugCondition` is false, then write property-based tests asserting it (from Preservation Requirements in design):
    - Non-clinic verticals: for every non-clinic business type, observe sidebar/capability/RBAC/dashboard resolution and assert it is identical after the fix (Property 13 / 3.1, 3.6, 3.7, 3.12)
    - Already-correct clinic ids: the 13 ids (`clinic_dashboard`, `daily_appointments`, `patients_list`, `add_patient`, `scan_qr`, `appointments`, `prescriptions`, `medicine_master`, `lab_reports`, `doctor_revenue`, `new_sale`, `revenue_overview`, `device_settings`) resolve to the same screens with the same capability gating (Property 13 / 3.6)
    - Billing attribution + GST: clinic bills still attribute to `doctorId`; OPD lines keep `taxPercent: 0.0`, `defaultGstRate: 0.0`, `gstEditable: true` (Property 14 / 3.2, 3.3)
    - Confirmed `✅ present` features: Doctor dashboard real KPIs, `SafePrescriptionListScreen`/`AddPrescriptionScreen`, `MedicineMasterScreen`, `visit_screen` capture, `LabReportsScreen` pending query, `DoctorRevenueScreen` behave identically (Property 15 / 3.4)
    - Offline-first contract: writes still go local Drift → `SyncManager.enqueue`; only the tenant id changes (Property 15 / 3.8)
    - Backfill scoping: non-`'SYSTEM'` rows that already carry a real owner id are left untouched (Property 4 preservation half / 3.9)
    - Decision-gate preservation: both clinic stacks remain on disk; clinic inventory capability set unchanged — pre-sign-off (Property 15 / 3.5, 3.11)
  - Property-based testing generates many cases across sidebar ids, business types, and field inputs for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms the baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.11, 3.12_

- [x] 4. Phase 1 — Tenant Isolation & Data Attribution (Critical)

  - [x] 4.1 Add owner/tenant filter to `getPatientStats()`
    - In `features/doctor/.../doctor_dashboard_repository.dart`, filter `patients` by the authenticated owner/clinic id (`where(patients.userId.equals(ownerId))`) so total/new-patient counts reflect only the current tenant
    - _Bug_Condition: isBugCondition(DbQuery on patients via getPatientStats with no owner filter)_
    - _Expected_Behavior: tenantScoped(result) — counts reflect only the authenticated owner_
    - _Preservation: Property 13/14/15 — non-clinic + `✅ present` behavior unchanged_
    - _Requirements: 2.2_

  - [x] 4.2 Introduce a shared owner-id resolver with fail-safe behavior
    - Centralize a single owner-id resolver used by patients, appointments, bills, and sync (same source `clinic_billing_service` uses for `doctorId`)
    - If `ownerId` is null → **fail safe**: block the write and surface an error; do NOT apply `?? 'SYSTEM'`
    - _Bug_Condition: isBugCondition(RepoWrite AND session.ownerId == null AND fallback to 'SYSTEM')_
    - _Expected_Behavior: failsSafeWhenOwnerMissing(result) AND one consistent owner-id source_
    - _Preservation: offline-first write→enqueue contract unchanged (3.8)_
    - _Requirements: 2.6, 2.7_

  - [x] 4.3 Replace `'SYSTEM'` on patient and appointment writes with the real owner id
    - `features/doctor/.../patient_repository.dart`: write the resolved session owner id on create instead of `userId: 'SYSTEM'`
    - `features/doctor/.../appointment_repository.dart`: enqueue the sync op with the resolved session owner id instead of `'SYSTEM'`
    - _Bug_Condition: isBugCondition(RepoWrite by PatientRepository OR AppointmentRepository AND written userId == 'SYSTEM')_
    - _Expected_Behavior: tenantScoped(result) — writes/sync carry real owner id, never 'SYSTEM'_
    - _Preservation: offline-first contract preserved; only tenant id corrected (3.8)_
    - _Requirements: 2.3, 2.4, 2.6_

  - [x] 4.4 Add explicit Drift migration to backfill `'SYSTEM'` rows
    - Add a versioned, guarded Drift migration that re-attributes `userId == 'SYSTEM'` patient/appointment rows to the correct owner id; rows already carrying a real owner id are untouched (no silent schema/data change)
    - Note the multi-owner-on-one-device caveat for sign-off; document + test the migration
    - _Bug_Condition: isBugCondition(existing rows written with userId == 'SYSTEM')_
    - _Expected_Behavior: backfill re-attributes only 'SYSTEM' rows; no data loss_
    - _Preservation: non-'SYSTEM' rows unchanged (3.9); all columns/rows preserved (3.10)_
    - _Requirements: 2.5, 3.9, 3.10_

  - [x] 4.5 Verify bug condition exploration tests for Phase 1 now pass
    - **Property 1: Expected Behavior** - Tenant-Scoped Counts, Real Owner-Id, Fail-Safe, Backfill
    - **IMPORTANT**: Re-run the SAME tests from task 2 (cross-tenant leak, `'SYSTEM'` attribution, fail-unsafe) — do NOT write new tests
    - Add the migration unit test (re-attributes only `'SYSTEM'` rows; preserves others; no data loss)
    - **EXPECTED OUTCOME**: Tests PASS (confirms Properties 1–4 satisfied)
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 4.6 Verify preservation tests still pass; run `flutter analyze` and STOP
    - **Property 2: Preservation** - Offline-First & Billing Attribution Unchanged
    - **IMPORTANT**: Re-run the SAME preservation tests from task 3 — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (no regressions; only tenant id corrected)
    - List files created/modified/deleted, run `flutter analyze` on touched files, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`
    - _Requirements: 3.2, 3.8, 3.9, 3.10_

- [x] 5. Phase 2 — RBAC, PHI/Privacy & Clinical Safety (Critical) + Decision Gates

  - [x] 5.1 Add clinic RBAC roles and integrate the parallel clinic-role concept
    - `lib/core/models/user_role.dart`: add clinic roles (doctor / receptionist / nurse) or map them onto existing roles, sufficient to allow receptionist appointment booking while blocking diagnosis/private notes
    - `lib/core/session/session_manager.dart`: extend role-string mapping + `effectiveRole` for the new/mapped roles (preserve, do not escalate, `unknown`)
    - Integrate the existing `ClinicRole` enum + `features/clinic/widgets/role_guard.dart` with the main `RolePermissions` used by the sidebar
    - _Bug_Condition: isBugCondition(Render of clinical content with NO clinical role check)_
    - _Expected_Behavior: clinicalContentRoleGated(result)_
    - _Preservation: non-clinic RBAC unchanged (3.1); other verticals unaffected_
    - _Requirements: 2.8, 2.9_

  - [x] 5.2 Enforce clinical-role gate on `visit_screen` diagnosis/private notes
    - `features/doctor/.../visit_screen.dart`: gate diagnosis and "private notes" behind the clinical-role check so doctor-only content is actually restricted; a doctor-role user retains full access
    - _Bug_Condition: isBugCondition(Render of visit_screen diagnosis/private-notes without role check)_
    - _Expected_Behavior: clinicalContentRoleGated(result) — restricted for non-doctor, full for doctor_
    - _Preservation: `visit_screen` capture for authorized doctor unchanged (3.4)_
    - _Requirements: 2.10_

  - [x] 5.3 Add PHI consent flag and access logging
    - `features/doctor/.../patient_model.dart` + Drift `patients` table: add a `consent` flag via explicit migration (nullable, default unconsented)
    - Add append-only **access logging** for patient/visit reads and writes (new audit table via migration); document an at-rest protection strategy for sensitive columns (app-layer scope)
    - _Bug_Condition: isBugCondition(RepoWrite of patient AND no consent flag OR no access-log entry)_
    - _Expected_Behavior: phiConsentAndAuditCaptured(result)_
    - _Preservation: all existing patient columns/rows preserved via migration (3.10)_
    - _Requirements: 2.11, 3.10_

  - [x] 5.4 Add allergy↔prescription contraindication check
    - In the Rx-save path (`AddPrescriptionScreen` / prescription repository): before persisting, cross-reference the prescribed drug against `patient.allergies` and **warn or block** on contraindication; non-contraindicated drugs save unchanged
    - _Bug_Condition: isBugCondition(RxSave for a drug contraindicated by patient.allergies with NO warn/block)_
    - _Expected_Behavior: contraindicationWarnedOrBlocked(result)_
    - _Preservation: `AddPrescriptionScreen` save of safe drugs unchanged (3.4)_
    - _Requirements: 2.12_

  - [x] 5.5 Decision Gate 2.1 — Canonical clinic stack (conditional; do NOT pre-resolve)
    - Until sign-off: leave **both** stacks on disk; keep `features/doctor` as the primary sidebar path; MAY wire the superior orphaned screens (token/queue, calendar) into the sidebar WITHOUT deleting either stack
    - On sign-off: adopt the chosen canonical stack and **deprecate (not delete)** the other; the survivor keeps its `VendorRoleGuard` + `BusinessGuard` guards
    - **STOP and request sign-off before adopting/deprecating either stack** (Property G2.1 deferred)
    - _Preservation: both stacks remain on disk pre-sign-off (3.11); guards preserved (3.7)_
    - _Requirements: 2.13_

  - [x] 5.6 Decision Gate 2.2 — Inventory contradiction (conditional; do NOT pre-resolve)
    - On sign-off, implement exactly one of: (a) grant clinic a minimal pharmacy-inventory capability + sidebar item enabling stock-in for dispensed meds, making modules/capability/sidebar/billing consistent; OR (b) stop auto-deducting stock in `clinic_billing_service.addPrescriptionToBill()`
    - Until sign-off: capability set unchanged
    - **STOP and request sign-off before changing capability set or billing deduction** (Property G2.2 deferred)
    - _Preservation: clinic inventory capability set unchanged pre-sign-off (3.5)_
    - _Requirements: 2.14_

  - [x] 5.7 Verify bug condition exploration tests for Phase 2 now pass
    - **Property 1: Expected Behavior** - Role Enforcement, PHI Consent/Audit, Contraindication
    - **IMPORTANT**: Re-run the SAME tests from task 2 (unenforced doctor-only, contraindicated Rx) — do NOT write new tests
    - Add unit tests: clinical-role gate hides content for non-doctor and shows for doctor; consent captured on create; access-log entry produced on read/write; contraindication warns/blocks for contraindicated drug and allows others
    - **EXPECTED OUTCOME**: Tests PASS (confirms Properties 5–7 satisfied)
    - _Requirements: 2.8, 2.9, 2.10, 2.11, 2.12_

  - [x] 5.8 Verify preservation tests still pass; run `flutter analyze` and STOP
    - **Property 2: Preservation** - Non-Clinic RBAC & Confirmed Features Unchanged
    - **IMPORTANT**: Re-run the SAME preservation tests from task 3 — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (non-clinic RBAC, capability set, and stacks unchanged)
    - List files created/modified/deleted, run `flutter analyze` on touched files, output `PHASE 2 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`
    - _Requirements: 3.1, 3.4, 3.5, 3.7, 3.11_

- [x] 6. Phase 3 — Navigation Correctness & Screen Exposure (High)

  - [x] 6.1 Fix `patient_history` to reach `PatientHistoryScreen`
    - `lib/widgets/desktop/sidebar_navigation_handler.dart`: route `patient_history` to a patient picker that opens `PatientHistoryScreen(patientId:)`, or relabel the item — never silently to `PatientListScreen` under a "History" label
    - _Bug_Condition: isBugCondition(Navigation itemId == 'patient_history' AND resolvedScreen == PatientListScreen)_
    - _Expected_Behavior: history/timeline view reachable via picker_
    - _Preservation: the 13 already-correct ids resolve unchanged (3.6)_
    - _Requirements: 2.15_

  - [x] 6.2 Wire orphaned OPD screens and add Reports & Accounts section
    - `sidebar_navigation_handler.dart`: register cases for the orphaned OPD screens to wire (at minimum token/queue + calendar) with proper owner id and capability gating; add imports (conditional on Decision 2.1 for canonical source)
    - `lib/widgets/desktop/sidebar_configuration.dart` (`_getClinicSections()`): add a **"Reports & Accounts"** section exposing at minimum `expenses`, `daybook`, `accounting_reports`, `outstanding` (receivables), and `backup` — config-only, since these ids already resolve
    - _Bug_Condition: isBugCondition(orphaned OPD screens unreachable from sidebar; no financial/ops items)_
    - _Expected_Behavior: queue/calendar wired (gated); Reports & Accounts exposed_
    - _Preservation: existing 13 clinic ids and other verticals' sidebars unchanged (3.1, 3.6)_
    - _Requirements: 2.16, 2.17_

  - [x] 6.3 Add appointment slot duration and double-booking guard
    - `appointment_model` / `appointment_repository.dart` + Drift migration: add slot length/duration and a guard rejecting/flagging overlapping slots for the same doctor; non-overlapping slots schedule normally
    - _Bug_Condition: isBugCondition(appointment overlaps an existing slot for the same doctor)_
    - _Expected_Behavior: overlap rejected/flagged; non-overlapping scheduled normally_
    - _Preservation: existing appointment columns/rows preserved via migration (3.10)_
    - _Requirements: 2.18_

  - [x] 6.4 Add human-readable UHID/MRN and reminder opt-in integration point
    - `patient_model.dart` + Drift migration: add a UHID/MRN alongside the internal UUID (RID-pattern generated; backfill generated MRN; preserve existing columns/rows)
    - `appointment_screen.dart`: add an opt-in SMS/WhatsApp reminder integration point with patient opt-in; **backend dispatch is out of scope this pass and flagged accordingly**
    - _Bug_Condition: isBugCondition(patient has no human-readable MRN; appointment sends no reminder)_
    - _Expected_Behavior: MRN assigned; reminder opt-in integration point present_
    - _Preservation: existing patient columns/rows preserved via migration (3.10)_
    - _Requirements: 2.19, 2.20, 3.10_

  - [x] 6.5 Verify bug condition exploration test for Phase 3 now passes
    - **Property 1: Expected Behavior** - Reachable Patient History & Double-Booking Guard
    - **IMPORTANT**: Re-run the SAME `patient_history` resolution test from task 2 — do NOT write a new test
    - Add unit tests: `patient_history` resolves to `PatientHistoryScreen` (via picker); double-booking guard rejects overlapping slots and allows non-overlapping
    - **EXPECTED OUTCOME**: Tests PASS (confirms Properties 8, 9 satisfied)
    - _Requirements: 2.15, 2.16, 2.17, 2.18, 2.19, 2.20_

  - [x] 6.6 Verify preservation tests still pass; run `flutter analyze` and STOP
    - **Property 2: Preservation** - Existing Sidebar Ids & Other Verticals Unchanged
    - **IMPORTANT**: Re-run the SAME preservation tests from task 3 — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (13 clinic ids + non-clinic sidebars unchanged)
    - List files created/modified/deleted, run `flutter analyze` on touched files, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`
    - _Requirements: 3.1, 3.6, 3.10_

- [x] 7. Phase 5 — Dashboard Data Integrity (High/Medium)

  - [x] 7.1 Replace hardcoded clinic dashboard counts with live queries
    - `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`: replace the clinic-branch literals `'18'`/`'7'` with live counts (today's appointments; pending lab reports) via the real `alertCountsProvider`, mirroring the grocery/hardware branches
    - _Bug_Condition: isBugCondition(Render of clinic BusinessAlertsWidget with literal '18'/'7' counts)_
    - _Expected_Behavior: dashboardCountsFromLiveQueries(result)_
    - _Preservation: dedicated clinic branches (New Patient / Appointments / Write Rx, hidden low-stock Alerts) unchanged — only counts replaced (3.12)_
    - _Requirements: 2.21_

  - [x] 7.2 Replace hardcoded `avgTime` and consolidate dashboard queries
    - `features/doctor/.../doctor_dashboard_screen.dart` + `doctor_dashboard_repository.dart`: compute `avgTime` from real visit-duration data, or **omit** the metric until duration tracking exists (no `'15 mins'` literal)
    - Introduce a consolidated Riverpod provider so a rebuild does not independently re-run `getPatientStats`/`getSmartInsights`/weekly/monthly/alerts
    - Move weekly/monthly bucketing to SQL `GROUP BY` instead of loading all rows and aggregating in Dart
    - _Bug_Condition: isBugCondition(Render with hardcoded avgTime; rebuild re-runs all queries; Dart-side bucketing)_
    - _Expected_Behavior: avgTime live-or-omitted; shared/cached provider; SQL GROUP BY_
    - _Preservation: Doctor dashboard real KPIs continue functioning (3.4)_
    - _Requirements: 2.22, 2.23, 2.24_

  - [x] 7.3 Verify dashboard exploration test now passes; preservation holds; analyze and STOP
    - **Property 1: Expected Behavior** - Live Dashboard Counts
    - **IMPORTANT**: Re-run the SAME hardcoded-dashboard test from task 2 — do NOT write a new test
    - **Property 2: Preservation** - V2 Dashboard Branches & KPIs Unchanged (re-run task 3 tests)
    - **EXPECTED OUTCOME**: Property 1 test PASSES (live counts); Property 2 tests PASS (no regressions)
    - List files created/modified/deleted, run `flutter analyze` on touched files, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`
    - _Requirements: 2.21, 2.22, 2.23, 2.24, 3.4, 3.12_

- [x] 8. Phase 6 — Billing & Business-Logic Correctness (Medium)

  - [x] 8.1 Source consultation fee from DoctorProfile
    - `features/doctor/.../clinic_billing_service.dart`: source the consultation fee from `DoctorProfile` instead of the hardcoded `defaultConsultationFee = 500.0`; GST semantics unchanged
    - _Bug_Condition: isBugCondition(consultation line uses hardcoded 500.0 regardless of doctor)_
    - _Expected_Behavior: fee sourced from DoctorProfile_
    - _Preservation: `doctorId` attribution + `taxPercent: 0.0`/`defaultGstRate: 0.0`/`gstEditable: true` unchanged (3.2, 3.3)_
    - _Requirements: 2.25_

  - [x] 8.2 Surface medicine-quantity parse failures and implement real lab-report upload
    - `clinic_billing_service.dart` `_calculateMedicineQuantity`: on dosage/duration parse failure, surface the failure to the user instead of silently defaulting to `1.0`
    - `features/doctor/.../lab_reports_screen.dart`: replace the "placeholder for file picking" with a real file pick + storage write (app-layer); flag the storage backend integration where it crosses the no-backend boundary
    - _Bug_Condition: isBugCondition(FieldEntry medicine-quantity parse failure silently defaulted; lab upload placeholder)_
    - _Expected_Behavior: clinicalInputValidated(result) — parse failure surfaced; real file pick + storage write_
    - _Preservation: existing billing/medicine flow for valid input unchanged (3.4)_
    - _Requirements: 2.26, 2.27_

  - [x] 8.3 Verify billing exploration test now passes; preservation holds; analyze and STOP
    - **Property 1: Expected Behavior** - Surfaced Parse Failure & Fee from Profile
    - **IMPORTANT**: Re-run the SAME silent-quantity-default test from task 2 — do NOT write a new test
    - **Property 2: Preservation** - Billing Attribution & GST Semantics Unchanged (re-run task 3 tests)
    - **EXPECTED OUTCOME**: Property 1 test PASSES; Property 2 tests PASS (`doctorId`/GST unchanged)
    - List files created/modified/deleted, run `flutter analyze` on touched files, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`
    - _Requirements: 2.25, 2.26, 2.27, 3.2, 3.3_

- [x] 9. Phase 7 — Data Validation + Theming & Accessibility (Medium/Low)

  - [x] 9.1 Add clinical input validation (vitals, phone, DOB) and prescription error state
    - `visit_screen.dart`: add validators/ranges for vitals (SpO2 0–100; plausible BP/Pulse/Temp) with feedback, rejecting out-of-range input
    - Patient create / emergency-visit flow: validate phone format, prompt for required fields, detect likely duplicate patients
    - `patient_model.dart` + Drift migration: store date of birth and derive age so it stays current (preserve existing columns/rows)
    - `SafePrescriptionListScreen`: add an error-state branch to the `FutureBuilder` with a clear message + retry affordance
    - _Bug_Condition: isBugCondition(FieldEntry of vitals/phone/age out-of-range/invalid silently accepted; FutureBuilder repo throw unhandled)_
    - _Expected_Behavior: clinicalInputValidated(result) AND error-state UI for prescription list_
    - _Preservation: existing valid-input capture and DOB-derived age preserve data via migration (3.4, 3.10)_
    - _Requirements: 2.28, 2.29, 2.30, 2.31, 3.10_

  - [x] 9.2 Apply theming and accessibility fixes
    - Replace hardcoded `Colors.white` / `FuturisticColors` in clinic dialogs/`visit_screen`/dashboard with theme-aware colors so light and dark themes read correctly
    - Add explicit semantic labels to symptom `FilterChip`s / `ActionChip` templates for screen readers
    - Pair color with text/icon for status (visit banner, allergy alert, alert count badges) so meaning is not color-only
    - Relabel `sync_status` to reflect Backup, or split Sync and Backup into accurately labeled items
    - _Bug_Condition: isBugCondition(Render uses hardcoded colors / color-only signaling / mislabeled sync_status)_
    - _Expected_Behavior: theme-aware colors; semantic labels; color+text/icon; accurate label_
    - _Preservation: other verticals' theming/labels unchanged (3.1)_
    - _Requirements: 2.32, 2.33, 2.34, 2.35_

  - [x] 9.3 Verify validation exploration tests now pass; preservation holds; analyze and STOP
    - **Property 1: Expected Behavior** - Validated Clinical Input & Prescription Error State
    - **IMPORTANT**: Re-run the SAME vitals-out-of-range and silent-default tests from task 2 — do NOT write new tests
    - Add unit tests: vitals range validation (SpO2 0–100), phone-format validation, medicine-quantity parse-failure surfacing, `SafePrescriptionListScreen` renders error-state branch on repo throw
    - **Property 2: Preservation** - Confirmed Features Unchanged (re-run task 3 tests)
    - **EXPECTED OUTCOME**: Property 1 tests PASS (Properties 11, 12 satisfied); Property 2 tests PASS
    - List files created/modified/deleted, run `flutter analyze` on touched files, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`
    - _Requirements: 2.28, 2.29, 2.30, 2.31, 2.32, 2.33, 2.34, 2.35, 3.4, 3.10_

- [x] 10. Phase 8 — Final Verification Checkpoint
  - **Fix Checking**: re-run the full Property 1 (Bug Condition) suite from task 2 — ALL tests now PASS, confirming `expectedBehavior` holds for every buggy input (tenant-scoped, real owner id, role-gated, consent+audit, contraindication handled, reachable history, double-booking guarded, live counts, validated input, prescription error state)
  - **Preservation Checking**: re-run the full Property 2 (Preservation) suite from task 3 — ALL tests still PASS, confirming non-clinic verticals, the 13 clinic ids, billing/GST attribution, `✅ present` features, the offline-first contract, backfill scoping, and the decision-gated stacks/inventory are unchanged
  - Run the full clinic integration test set (tenant isolation end-to-end, role enforcement, contraindication, patient-history navigation, live dashboard counts, migration upgrade with `'SYSTEM'` rows present, decision-gate preservation)
  - Run `flutter analyze` across all touched files; confirm no new warnings/errors
  - Confirm Decision Gates 2.1 and 2.2 are either signed off and implemented, or explicitly left deferred with both stacks on disk and the inventory capability set unchanged
  - Ensure all tests pass; ask the user if questions arise
  - _Requirements: 2.1, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12_

## Notes

- Phase 0 is verify-before-fix and read-only: confirm every audit item flagged **unverified** against the live code; if Ground Truth contradicts the code, STOP and report — do not route around it.
- Execute phases in order with STOP gates. After each phase: list files created/modified/deleted, run `flutter analyze` on touched files, output `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for `APPROVED`. Do NOT auto-continue.
- Bug condition exploration tests (task 2) MUST FAIL on unfixed code (proving defects exist); preservation tests (task 3) MUST PASS on unfixed code (capturing the baseline). Re-run both before and after each phase to catch regressions early.
- Decision Gates 2.1 (canonical clinic stack) and 2.2 (inventory contradiction) require explicit human sign-off. Until signed off: both clinic stacks stay on disk (no deletion) and the clinic inventory capability set is unchanged. Tasks 5.5 and 5.6 must STOP for sign-off before acting.
- No deletions without sign-off. All schema/data changes use explicit, versioned Drift migrations (never silent), preserving existing columns/rows. The `'SYSTEM'` backfill migration touches only `'SYSTEM'` rows.
- The correct owner-id convention already exists in `clinic_billing_service` (`doctorId` as `userId`); patient/appointment repos are aligned TO it, not the reverse. Null `ownerId` fails safe — never `?? 'SYSTEM'`.
- New code follows steering conventions: RID-pattern ids (`{tenantId}-{timestamp_ms}-{uuid_v4_short}`), integer paise for new money fields, tenant isolation preserved, `defaultGstRate: 0.0`/`gstEditable: true` semantics untouched, and no other business vertical's code/capabilities/sidebar modified.
- SMS/WhatsApp reminder dispatch and lab-file storage backend cross the no-backend boundary; only the app-layer integration point is in scope this pass and is flagged accordingly.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "name": "Wave 1 - Verification Gate",
      "tasks": ["1"],
      "description": "Phase 0 read-only confirmation of all unverified audit items before any fix"
    },
    {
      "name": "Wave 2 - Exploration & Preservation Tests",
      "tasks": ["2", "3"],
      "dependsOn": ["1"],
      "description": "Write bug condition (must fail) and preservation (must pass) tests on UNFIXED code"
    },
    {
      "name": "Wave 3 - Phase 1 Tenant Isolation & Attribution",
      "tasks": ["4.1", "4.2", "4.3", "4.4"],
      "dependsOn": ["2", "3"],
      "description": "Owner filter on getPatientStats, fail-safe resolver, real owner id on writes, backfill migration"
    },
    {
      "name": "Wave 4 - Phase 1 Verification (STOP gate)",
      "tasks": ["4.5", "4.6"],
      "dependsOn": ["4.1", "4.2", "4.3", "4.4"],
      "description": "Verify Phase 1 exploration tests pass and preservation holds; analyze; AWAITING APPROVAL"
    },
    {
      "name": "Wave 5 - Phase 2 RBAC, PHI & Clinical Safety + Decision Gates",
      "tasks": ["5.1", "5.2", "5.3", "5.4", "5.5", "5.6"],
      "dependsOn": ["4.5", "4.6"],
      "description": "Clinic roles, visit_screen role gate, consent+audit, contraindication check; decision gates 2.1/2.2 conditional"
    },
    {
      "name": "Wave 6 - Phase 2 Verification (STOP gate)",
      "tasks": ["5.7", "5.8"],
      "dependsOn": ["5.1", "5.2", "5.3", "5.4"],
      "description": "Verify Phase 2 exploration tests pass and preservation holds; analyze; AWAITING APPROVAL"
    },
    {
      "name": "Wave 7 - Phase 3 Navigation & Screen Exposure",
      "tasks": ["6.1", "6.2", "6.3", "6.4"],
      "dependsOn": ["5.7", "5.8"],
      "description": "patient_history fix, orphaned screen wiring + Reports & Accounts, slot/double-booking guard, UHID/MRN + reminders"
    },
    {
      "name": "Wave 8 - Phase 3 Verification (STOP gate)",
      "tasks": ["6.5", "6.6"],
      "dependsOn": ["6.1", "6.2", "6.3", "6.4"],
      "description": "Verify Phase 3 exploration tests pass and preservation holds; analyze; AWAITING APPROVAL"
    },
    {
      "name": "Wave 9 - Phase 5 Dashboard Data Integrity (STOP gate)",
      "tasks": ["7.1", "7.2", "7.3"],
      "dependsOn": ["6.5", "6.6"],
      "description": "Live dashboard counts, avgTime live-or-omitted, consolidated provider + SQL GROUP BY; verify; AWAITING APPROVAL"
    },
    {
      "name": "Wave 10 - Phase 6 Billing & Business Logic (STOP gate)",
      "tasks": ["8.1", "8.2", "8.3"],
      "dependsOn": ["7.3"],
      "description": "Consultation fee from DoctorProfile, surfaced parse failures, real lab upload; verify; AWAITING APPROVAL"
    },
    {
      "name": "Wave 11 - Phase 7 Validation, Theming & Accessibility (STOP gate)",
      "tasks": ["9.1", "9.2", "9.3"],
      "dependsOn": ["8.3"],
      "description": "Vitals/phone/DOB validation, prescription error state, theme-aware colors + semantics; verify; AWAITING APPROVAL"
    },
    {
      "name": "Wave 12 - Phase 8 Final Checkpoint",
      "tasks": ["10"],
      "dependsOn": ["4.5", "4.6", "5.7", "5.8", "6.5", "6.6", "7.3", "8.3", "9.3"],
      "description": "Re-run full fix-checking and preservation suites; integration tests; confirm decision-gate state; all tests pass"
    }
  ]
}
```
