# Bugfix Requirements Document

## Introduction

This document defines the remediation of the DukanX **Clinic (Doctor Clinic / OPD)** business vertical (`BusinessType.clinic`) in the Flutter + Riverpod v2 + Drift (local-first, sync-queue-to-cloud) app. Scope is the **Flutter app layer only** — `features/doctor/`, `features/clinic/`, the sidebar config + navigation handler, the V2 dashboard widgets, and the Drift local DB. **No DynamoDB/Lambda backend work is in scope for this pass.**

The authoritative source is the read-only audit at `audit-reports/business-types/audit-clinic.md` and the phased remediation plan (Phases 0–8 with human STOP gates). The bug conditions below are organized to map onto the 8-phase plan and the audit's 59-item traceability checklist.

The clinic vertical contains five **Critical** defects — a cross-tenant patient-data leak, a literal `'SYSTEM'` tenant id written on every patient/appointment create, an absent clinic RBAC layer, missing PHI/consent safeguards, and the lack of an allergy↔prescription safety check — plus a cluster of High/Medium/Low defects spanning miswired navigation, orphaned screens, duplicate clinic stacks, hardcoded dashboard data, missing OPD features, validation gaps, and theming/accessibility issues.

**Two architecture decision gates (Phase 2) are open decisions requiring human sign-off and are NOT pre-resolved by this document:**

- **Decision 2.1 — Canonical clinic stack:** which of the two parallel stacks (`features/doctor/*`, wired to the sidebar, vs `features/clinic/*`, wired only via named routes) is canonical. The other is deprecated, **not deleted, without explicit sign-off**.
- **Decision 2.2 — Inventory contradiction:** either grant clinic a minimal pharmacy-inventory capability + sidebar item (stock-in for dispensed meds), **OR** stop auto-deducting stock in `clinic_billing_service`.

The fix conditions for items that depend on these gates are written conditionally and must not be implemented until the corresponding decision is signed off.

**Non-negotiable conventions carried from steering and the phase plan:**

- Execute phases in order with STOP gates; do not auto-continue. **Phase 0 is verify-before-fix** — every audit item marked **unverified** must be confirmed against the live codebase before any fix touches it; if Ground Truth contradicts the code, STOP and report.
- No deletions without sign-off. Schema/data changes require explicit Drift migrations (never silent). Every Critical/High fix requires a test.
- Use existing Riverpod v2 patterns. Preserve all functionality the audit marks `✅ present` as a regression baseline.
- Do **not** change `defaultGstRate` (0.0) / `gstEditable` (true) semantics beyond what is explicitly specified.

---

## Bug Analysis

### Current Behavior (Defect)

**Phase 0 — Verification gate (verify-before-fix)**

1.1 WHEN remediation begins THEN the system has no recorded confirmation step for audit items flagged **unverified** (follow-up/refill screen invocation paths; whether both clinic stacks write the same Drift `patients` table; full bodies of `appointment_screen`, `patient_list_screen`, `add_patient_screen`, `lab_report_repository`, `prescription_repository`; `prescription_pharmacy_bridge` wiring; exact lab-upload placeholder behavior; `SafePrescriptionListScreen` body beyond line 80), so fixes risk being applied against assumptions rather than verified facts

**Phase 1 — Tenant isolation & data attribution (Critical)**

1.2 WHEN `DoctorDashboardRepository.getPatientStats()` runs THEN the system executes `_db.select(_db.patients).get()` with no tenant/owner filter ("all patients for now"), so total and new-patient counts leak across all clinics/owners sharing the local DB

1.3 WHEN `PatientRepository` creates a patient THEN the system writes a literal `userId: 'SYSTEM'` (with an in-code comment "Should be doctor/vendor ID ideally") instead of the real session owner id, leaving patient rows un-scoped to any tenant

1.4 WHEN `AppointmentRepository` creates an appointment THEN the system enqueues the sync op with literal `userId: 'SYSTEM'`, so the sync payload is not attributable to the real clinic/owner

1.5 WHEN existing patient/appointment rows have already been written with `userId: 'SYSTEM'` THEN the system has no backfill path to re-attribute those rows to a real owner, so simply changing new writes leaves historical data un-scoped

1.6 WHEN `clinic_billing_service` correctly uses `doctorId` as `userId` for bills/sync while `PatientRepository`/`AppointmentRepository` use `'SYSTEM'` THEN the system has an internally inconsistent attribution model across the same feature (the correct convention already exists in `clinic_billing_service` and is the alignment target)

1.7 WHEN a session lacks `ownerId` THEN the system falls back to `'SYSTEM'` via `ownerId ?? 'SYSTEM'` in dashboard/visit/revenue/prescription paths, so all such sessions silently share one `'SYSTEM'` bucket

**Phase 2 — RBAC, PHI/privacy & clinical safety (Critical) + architecture decision gates**

1.8 WHEN clinic staff access the app THEN the system offers no clinic-specific RBAC roles — `UserRole` is only `{owner, manager, staff, accountant, unknown}` — so a receptionist cannot be allowed to book appointments while being blocked from diagnosis/private notes

1.9 WHEN the `ClinicRole` enum and `features/clinic/widgets/role_guard.dart` are present THEN the system does not integrate them with the main `RolePermissions` used by the sidebar, leaving a parallel, unenforced clinic-role concept

1.10 WHEN a user opens `visit_screen.dart` THEN the system renders diagnosis and "private notes (only visible to doctor)" with no role enforcement, so "doctor-only" is not actually enforced for any user

1.11 WHEN a patient record is stored THEN `PatientModel` holds `name`, `phone`, `address`, `bloodGroup`, `chronicConditions`, `allergies` with no consent flag and no access logging, so PHI is stored and read without consent capture or an audit trail

1.12 WHEN a clinician saves a prescription (Rx) THEN the system performs no allergy↔prescription contraindication check, so a drug the patient is recorded as allergic to can be prescribed without warning (allergies are shown only as a passive banner in `visit_screen`)

1.13 WHEN deciding which clinic stack to maintain THEN the system has two parallel stacks (`features/doctor/*` via sidebar; `features/clinic/*` via named routes) duplicating patient history, lab ordering, consultation, and dashboard, with no recorded decision on which is canonical (**Decision 2.1 — open, needs sign-off**)

1.14 WHEN medicines are dispensed THEN clinic `modules` config lists `'inventory'`, the capability registry grants **no** inventory capability, the sidebar has **no** inventory item, yet `clinic_billing_service.addPrescriptionToBill()` deducts stock via `InventoryService` — a three-way contradiction where stock is deducted but can never be stocked-in or viewed (**Decision 2.2 — open, needs sign-off**)

**Phase 3 — Navigation correctness & screen exposure (High)**

1.15 WHEN a user clicks "Patient History" in the sidebar THEN the system resolves `patient_history` to `PatientListScreen` (with comment "Default to patient list for selection") instead of `PatientHistoryScreen`, so the dedicated history/timeline view is never reached

1.16 WHEN a user navigates the clinic sidebar THEN the system provides no path to existing screens `PatientQueueScreen` (token/queue), `ConsultationScreen`, `LabOrderScreen`, `ClinicCalendarScreen`, `RefillQueueScreen`, `RefillDataRepairScreen`, and the `PatientHistoryScreen` copies — all reachable only via named routes or programmatically, orphaning core OPD flow controls

1.17 WHEN a clinic owner needs financial/operational tooling THEN the system exposes no sidebar items for Accounting/P&L/Day Book, Receivables (outstanding), Bank/Cash, Reports Hub, Expenses, Backup, or Audit/Activity logs, even though those screens already resolve in `sidebar_navigation_handler.dart` (so exposure is config-only)

1.18 WHEN appointments are scheduled THEN the system stores only `scheduledTime` with no slot length/duration and no double-booking guard, allowing overlapping appointments for the same doctor

1.19 WHEN a patient is registered THEN `PatientModel` has only `id` (UUID) + `qrToken` and no human-readable UHID/MRN, so patients have no clinic-facing medical record number

1.20 WHEN an appointment is booked THEN the system sends no SMS/WhatsApp reminder (grep for `sms|whatsapp|reminder` in `appointment_screen.dart` finds none)

**Phase 5 — Dashboard data integrity (High/Medium)**

1.21 WHEN the V2 `business_alerts_widget.dart` clinic case renders THEN the system shows hardcoded literal counts ("Today's Appointments" = `'18'`, "Pending Lab Reports" = `'7'`), ignoring the real `alertCountsProvider`, so values never change

1.22 WHEN `DoctorDashboardScreen._buildSmartInsights` renders THEN the system displays `avgTime: '15 mins'` as a hardcoded literal (no duration tracking in the Visits table)

1.23 WHEN the `DoctorDashboardScreen` builds THEN the system issues multiple independent `FutureBuilder`s (`getPatientStats`, `getSmartInsights`, `getWeeklyAnalytics`, `getMonthlyAnalytics`, `getDashboardAlerts`), each hitting the DB on every build with no shared caching, so a rebuild re-runs all queries

1.24 WHEN weekly/monthly analytics are computed THEN the system loads all matching visit rows and buckets them in Dart instead of using SQL `GROUP BY`, degrading as history grows

**Phase 6 — Billing & business-logic correctness (Medium)**

1.25 WHEN `clinic_billing_service.createBillFromVisit()` adds the consultation line THEN the system uses `defaultConsultationFee = 500.0` hardcoded (comment: should come from `DoctorProfile`), regardless of doctor/profile

1.26 WHEN `_calculateMedicineQuantity` parses dosage (e.g., `"1-0-1"`) and duration (e.g., `"5 days"`) and parsing fails THEN the system silently defaults to `1.0`, causing under-dispensing and under-billing with no warning

1.27 WHEN a lab report result is uploaded THEN the system runs a placeholder ("placeholder for file picking" in `lab_reports_screen.dart`) with no file/storage backend, so the upload affordance is non-functional

**Phase 7 — Data validation (Medium)**

1.28 WHEN vitals are entered in `visit_screen.dart` THEN the system uses `TextInputType.text` with no validators, so BP/Pulse/Temp/SpO2 accept any string with no range checks (e.g., SpO2 outside 0–100)

1.29 WHEN a patient is created (including the emergency-visit flow) THEN the system treats `phone`/`age` as optional and unvalidated, defaults `gender: 'Unknown'`, and performs no phone-format check or duplicate-patient detection

1.30 WHEN `PatientModel.age` is stored THEN the system keeps a static `int?` with no date of birth, so age goes stale and cannot be recomputed

1.31 WHEN `SafePrescriptionListScreen` calls `_fetchAllPrescriptions()` and the repository throws THEN the system has no error-state branch in its `FutureBuilder` (only waiting + data), so a repo error surfaces with no error UI

**Phase 7 — Theming & accessibility (Low)**

1.32 WHEN clinic dialogs/`visit_screen`/dashboard render text THEN the system uses hardcoded `Colors.white` / `FuturisticColors`, which can clash with light themes

1.33 WHEN symptom `FilterChip`s / `ActionChip` templates render THEN the system provides no explicit semantic labels beyond their visible text

1.34 WHEN status is conveyed (visit status banner, allergy alert, alert count badges) THEN the system relies on color-only signaling for some elements (count badges are color-coded only)

1.35 WHEN the `sync_status` sidebar item is selected THEN the system opens `BackupScreen` under a "System" label, conflating sync with backup (mismatched mental model)

---

### Expected Behavior (Correct)

**Phase 0 — Verification gate**

2.1 WHEN remediation begins THEN the system SHALL first confirm each **unverified** audit item against the live codebase and record the result; if any Ground Truth/audit claim contradicts the code, work SHALL STOP and report the discrepancy rather than route around it

**Phase 1 — Tenant isolation & data attribution**

2.2 WHEN `DoctorDashboardRepository.getPatientStats()` runs THEN the system SHALL filter `patients` by the real owner/clinic id so counts reflect only the authenticated tenant

2.3 WHEN `PatientRepository` creates a patient THEN the system SHALL write the real session owner id (aligned to the `clinic_billing_service` convention) instead of `'SYSTEM'`

2.4 WHEN `AppointmentRepository` creates an appointment THEN the system SHALL enqueue the sync op with the real session owner id instead of `'SYSTEM'`

2.5 WHEN the fix is applied THEN the system SHALL provide a Drift migration that backfills existing `userId: 'SYSTEM'` patient/appointment rows to the correct owner id (no silent schema/data change), with the migration documented and tested

2.6 WHEN attribution is written across the clinic feature THEN the system SHALL use one consistent owner-id source for patients, appointments, bills, and sync (matching the already-correct `clinic_billing_service`)

2.7 WHEN a session lacks `ownerId` THEN the system SHALL fail safe (e.g., block the write or surface an error) rather than silently bucketing data under `'SYSTEM'`

**Phase 2 — RBAC, PHI/privacy & clinical safety + decision gates**

2.8 WHEN clinic staff access the app THEN the system SHALL provide clinic RBAC roles (doctor / receptionist / nurse) — either as new roles or mapped onto existing roles — sufficient to allow receptionist appointment booking while restricting diagnosis/private notes

2.9 WHEN clinic roles exist THEN the system SHALL integrate the `ClinicRole` enum / `features/clinic/widgets/role_guard.dart` with the main `RolePermissions` used by the sidebar

2.10 WHEN a user opens `visit_screen.dart` without the required clinical role THEN the system SHALL enforce role checks on diagnosis and private notes so "doctor-only" content is actually restricted

2.11 WHEN a patient record is created/read THEN the system SHALL capture a consent flag on `PatientModel` and log access to patient/visit data (access logging), with an at-rest protection strategy for sensitive columns

2.12 WHEN a clinician saves an Rx THEN the system SHALL run an allergy↔prescription contraindication check against the patient's recorded allergies and warn/block before saving a contraindicated drug

2.13 WHEN Decision 2.1 is signed off THEN the system SHALL adopt the chosen canonical clinic stack and deprecate (not delete, absent further sign-off) the other; until then, the superior orphaned screens (queue/token, calendar) MAY be wired into the sidebar without deleting either stack

2.14 WHEN Decision 2.2 is signed off THEN the system SHALL either (a) grant clinic a minimal pharmacy-inventory capability + sidebar item enabling stock-in for dispensed meds, OR (b) stop auto-deducting stock in `clinic_billing_service` — making the modules config, capability registry, sidebar, and billing behavior mutually consistent

**Phase 3 — Navigation correctness & screen exposure**

2.15 WHEN a user clicks "Patient History" THEN the system SHALL open `PatientHistoryScreen` (via a patient picker that supplies `patientId`), or relabel the item, so the history/timeline view is actually reachable

2.16 WHEN the canonical stack is decided THEN the system SHALL wire the relevant orphaned OPD screens (at minimum token/queue and calendar) into the clinic sidebar, gated by appropriate capabilities

2.17 WHEN the clinic sidebar renders THEN the system SHALL expose a "Reports & Accounts" section surfacing at minimum Expenses, Day Book, Accounting Reports, Receivables (outstanding), and Backup (config-only, since these ids already resolve)

2.18 WHEN an appointment is scheduled THEN the system SHALL support a slot length/duration and SHALL guard against double-booking the same doctor for overlapping slots

2.19 WHEN a patient is registered THEN the system SHALL assign a human-readable UHID/MRN in addition to the internal UUID

2.20 WHEN an appointment is booked THEN the system SHALL support SMS/WhatsApp reminders with patient opt-in (app-layer integration point; backend dispatch out of scope this pass and flagged accordingly)

**Phase 5 — Dashboard data integrity**

2.21 WHEN the V2 `business_alerts_widget.dart` clinic case renders THEN the system SHALL source "Today's Appointments" and "Pending Lab Reports" from live queries instead of the `'18'`/`'7'` literals

2.22 WHEN `_buildSmartInsights` renders THEN the system SHALL compute `avgTime` from real visit-duration data, or omit the metric until duration tracking exists, instead of showing `'15 mins'`

2.23 WHEN the `DoctorDashboardScreen` builds THEN the system SHALL share/cache dashboard data (e.g., a consolidated Riverpod provider) so a rebuild does not re-run all queries independently

2.24 WHEN weekly/monthly analytics are computed THEN the system SHALL bucket using SQL `GROUP BY` rather than loading all rows and aggregating in Dart

**Phase 6 — Billing & business-logic correctness**

2.25 WHEN the consultation line is added THEN the system SHALL source the consultation fee from `DoctorProfile` rather than the hardcoded `500.0`

2.26 WHEN `_calculateMedicineQuantity` fails to parse dosage/duration THEN the system SHALL surface the parse failure to the user instead of silently defaulting to `1.0`

2.27 WHEN a lab report result is uploaded THEN the system SHALL perform a real file pick + storage write (app-layer; storage backend integration flagged where it crosses the no-backend boundary), replacing the placeholder

**Phase 7 — Data validation**

2.28 WHEN vitals are entered THEN the system SHALL validate ranges (e.g., SpO2 0–100, plausible BP/Pulse/Temp) and reject out-of-range input with feedback

2.29 WHEN a patient is created THEN the system SHALL validate phone format, prompt for required fields, and detect likely duplicate patients

2.30 WHEN patient age is needed THEN the system SHALL store date of birth and derive age, so age stays current

2.31 WHEN `SafePrescriptionListScreen` loads and the repository throws THEN the system SHALL render an error-state branch in the `FutureBuilder` with a clear message and retry affordance

**Phase 7 — Theming & accessibility**

2.32 WHEN clinic dialogs/`visit_screen`/dashboard render text THEN the system SHALL use theme-aware colors instead of hardcoded `Colors.white` so light and dark themes both read correctly

2.33 WHEN symptom chips / template chips render THEN the system SHALL provide explicit semantic labels for screen readers

2.34 WHEN status is conveyed THEN the system SHALL pair color with text/icon so meaning is not color-only (including alert count badges)

2.35 WHEN the `sync_status` item is selected THEN the system SHALL either relabel it to reflect Backup, or split Sync and Backup into accurately labeled items

---

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a non-clinic business type (retail, grocery, pharmacy, restaurant, vegetablesBroker, etc.) is used THEN the system SHALL CONTINUE TO resolve its sidebar, capabilities, RBAC, and dashboards exactly as before, with no changes leaking out of the clinic vertical

3.2 WHEN `clinic_billing_service` creates bills and sync ops THEN the system SHALL CONTINUE TO attribute them to `doctorId` as it already does correctly — the patient/appointment repos are aligned to it, not the reverse

3.3 WHEN clinic billing computes tax THEN the system SHALL CONTINUE TO use `defaultGstRate: 0.0` and `gstEditable: true` with `taxPercent: 0.0` on OPD lines; this remediation SHALL NOT change GST semantics beyond what is explicitly specified

3.4 WHEN the audit-confirmed `✅ present` features run — `DoctorDashboardScreen` real KPIs (`getPatientStats`, `watchDailyAppointments`, weekly/monthly analytics, revenue/visit counts), `SafePrescriptionListScreen` + `AddPrescriptionScreen`, `MedicineMasterScreen`, `visit_screen` vitals/diagnosis/templates/private-notes capture, `LabReportsScreen` pending-report query, `DoctorRevenueScreen` per-doctor revenue — THEN the system SHALL CONTINUE TO function with the same behavior except where a clause above explicitly changes it (role enforcement, real counts, validation)

3.5 WHEN the clinic capability registry is evaluated THEN the system SHALL CONTINUE TO grant exactly its current capabilities and SHALL CONTINUE TO exclude all product/inventory/purchase/scan capabilities, **except** any minimal inventory capability explicitly added under signed-off Decision 2.2

3.6 WHEN the 13 clinic sidebar ids that already resolve correctly (`clinic_dashboard`, `daily_appointments`, `patients_list`, `add_patient`, `scan_qr`, `appointments`, `prescriptions`, `medicine_master`, `lab_reports`, `doctor_revenue`, `new_sale`, `revenue_overview`, `device_settings`) are used THEN the system SHALL CONTINUE TO resolve them to their current screens with the same capability gating

3.7 WHEN `/clinic/*` named routes wrapped in `VendorRoleGuard` + `BusinessGuard(allowedTypes:[clinic])` are used THEN the system SHALL CONTINUE TO guard them as before; deprecating a stack under Decision 2.1 SHALL NOT remove guards from the surviving stack

3.8 WHEN clinic data is created/edited THEN the system SHALL CONTINUE TO be offline-first (write local Drift, then `SyncManager.enqueue`); changes SHALL only correct the tenant id on enqueue, not the offline-first contract

3.9 WHEN existing non-`'SYSTEM'` patient/appointment rows already carry a real owner id THEN the system SHALL CONTINUE TO leave them correctly attributed; the backfill migration SHALL only re-attribute `'SYSTEM'` rows

3.10 WHEN any Drift table is modified for UHID/MRN, DOB, consent flag, slot duration, or access logging THEN the system SHALL CONTINUE TO preserve all existing columns and rows via an explicit migration with no data loss

3.11 WHEN both clinic stacks remain present prior to Decision 2.1 sign-off THEN the system SHALL CONTINUE TO leave both on disk (no deletion) and SHALL keep the sidebar path (`features/doctor`) working as the primary path

3.12 WHEN the V2 dashboard alerts/quick-actions render for clinic THEN the system SHALL CONTINUE TO show the dedicated clinic branches (New Patient / Appointments / Write Rx, with the low-stock "Alerts" action correctly hidden since clinic lacks `accessLowStockAlert`) — only the hardcoded counts are replaced with live data
