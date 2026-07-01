# DukanX Business-Type Audit — Clinic (Doctor Clinic / OPD)

> READ-ONLY, evidence-based audit. No source files were modified. Every "missing/broken/orphaned" claim cites the file/function actually inspected. Items not verified by reading the relevant code are explicitly marked **unverified**.

**Audit date:** 2026
**Business type:** `BusinessType.clinic` (display: "Doctor Clinic / OPD", `Dukan_x/lib/models/business_type.dart`)
**Method:** Static reading of config, sidebar config + navigation handler, capability registry, RBAC role model, dashboard widgets, and the `features/doctor/` + `features/clinic/` modules.

### What was sampled vs skipped
**Sampled (read in full or substantially):**
- `lib/models/business_type.dart`
- `lib/core/billing/business_type_config.dart` (clinic config block)
- `lib/widgets/desktop/sidebar_configuration.dart` (`_getClinicSections()`)
- `lib/widgets/desktop/sidebar_navigation_handler.dart` (full `getScreenForItem`)
- `lib/core/isolation/business_capability.dart` (clinic registry block)
- `lib/core/models/user_role.dart`, `lib/core/session/session_manager.dart` (`effectiveRole`)
- `lib/features/dashboard/v2/widgets/business_quick_actions.dart` (clinic case)
- `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` (clinic case)
- `features/doctor/`: `doctor_dashboard_repository.dart`, `appointment_repository.dart`, `patient_repository.dart`, `clinic_billing_service.dart`, `doctor_dashboard_screen.dart`, `visit_screen.dart`, `patient_model.dart`, `prescriptions_list_screen.dart` (head); grep-confirmed data sources for `lab_reports_screen.dart`, `doctor_revenue_screen.dart`, `medicine_master_screen.dart`
- `lib/app/routes.dart` (clinic route block), `lib/modules/clinic/routes/clinic_routes.dart`
- Directory enumeration of `features/doctor/` and `features/clinic/`

**Skipped / shallow (flagged as unverified where claims depend on them):**
- Full body of `appointment_screen.dart`, `patient_list_screen.dart`, `add_patient_screen.dart`, `medicine_master_screen.dart`, `lab_report_repository.dart`, `prescription_repository.dart`, `followup_repository.dart`, `doctor_repository.dart`, `medical_template_repository.dart`
- Full bodies of the parallel `features/clinic/presentation/screens/*` (consultation, patient_queue, lab_order, patient_history, clinic_calendar) — existence and route-wiring verified, internals not deeply read
- Responsive/accessibility were inferred from widget code patterns, not device-tested

---

## 1. Header — Sidebar resolution, config, capabilities

**Config (`business_type_config.dart`, `BusinessType.clinic`):**
- requiredFields: `itemName`, `quantity`, `price`
- optionalFields: `doctorName`, `batchNo`, `expiryDate`, `drugSchedule`
- `defaultGstRate: 0.0`, `gstEditable: true`
- itemLabel `Medicine/Service`, addItemLabel `Add Med/Service`, priceLabel `Charge`
- unitOptions: `pcs`, `strip`, `nos`
- modules: `['appointments','patients','prescriptions','inventory','reports']`

**Capabilities (`business_capability.dart`, `'clinic'` key):**
`useInvoiceList`, `useInvoiceSearch`, `useInvoiceCreate`, `useDailySnapshot`, `useRevenueOverview`, `useAppointments`, `useConsultationBilling`, `usePatientRegistry`, `usePrescription`, `useDoctorLinking`.
Explicitly NOT granted: any `useProduct*`, any `useInventory*`, `useLowStockAlert`, `usePurchase*`, `useSalesReturn`, `useBatchExpiry`, `useDrugSchedule`, `useScanOCR`, `useBarcodeScanner`.

**RBAC (`lib/core/models/user_role.dart`):** `enum UserRole { owner, manager, staff, accountant, unknown }`. `effectiveRole = staffRole ?? role` (`session_manager.dart`). No clinic roles (doctor / receptionist / nurse) exist.

**Sidebar resolution table** — clinic sidebar ids from `_getClinicSections()` cross-checked against `SidebarNavigationHandler.getScreenForItem()`:

| Section | Item id | Resolves to | Status |
|---|---|---|---|
| Clinic Dashboard | `clinic_dashboard` | `DoctorDashboardScreen` | ✅ real DB |
| Clinic Dashboard | `daily_appointments` | `AppointmentScreen` | ✅ |
| Patient Management | `patients_list` | `PatientListScreen` | ✅ |
| Patient Management | `add_patient` | `AddPatientScreen` | ✅ |
| Patient Management | `patient_history` | `PatientListScreen` (**not** `PatientHistoryScreen`) | ⚠️ miswired (§6) |
| Patient Management | `scan_qr` (cap `usePatientRegistry`) | `QrScannerScreen` | ✅ gated correctly |
| Clinical Desk | `appointments` | `AppointmentScreen` | ✅ |
| Clinical Desk | `prescriptions` (cap `usePrescription`) | `SafePrescriptionListScreen` | ✅ gated correctly |
| Clinical Desk | `medicine_master` (cap `usePrescription`) | `MedicineMasterScreen` | ✅ gated correctly |
| Clinical Desk | `lab_reports` | `LabReportsScreen` | ✅ (no capability gate) |
| Clinical Desk | `doctor_revenue` | `DoctorRevenueScreen` | ✅ |
| Billing & Revenue | `new_sale` | `BillCreationScreenV2` | ✅ |
| Billing & Revenue | `revenue_overview` | `RevenueOverviewScreen` | ✅ |
| System | `sync_status` | `BackupScreen` (reused) | ⚠️ reuse |
| System | `device_settings` | `DeviceSettingsScreen` | ✅ |

All 15 clinic sidebar ids resolve to a real widget (none fall through to the placeholder). Note: a stale artifact (`sidebar_results.csv`) reports `appointments` as "No/N/A", but the actual handler code maps both `daily_appointments` and `appointments` to `AppointmentScreen` — so that CSV row is incorrect; trust the code.

---

## 2. Missing generic features (vs Vyapar benchmark)

The clinic sidebar (`_getClinicSections()`) is a deliberately slim 5-section layout (Dashboard, Patient Management, Clinical Desk, Billing & Revenue, System). Compared to the Vyapar benchmark and the full `_getRetailSections()` available in the same codebase, clinic is missing:

| # | Vyapar capability | Clinic state | Priority |
|---|---|---|---|
| 4 | Accounting (Trial Balance / P&L / Day Book) | `AccountingReportsScreen`, `PnlScreen`, `DayBookScreen` exist and are handler-resolvable but **no clinic sidebar item** exposes them | High |
| 5 | Receivables / Payables | No `outstanding` / `party_ledger` item in clinic sidebar; patients carry no ledger. OPD credit/unpaid-bill tracking absent in nav | High |
| 6 | Bank / Cash | `BankScreen`, `CashflowScreen` exist but unexposed for clinic | Medium |
| 9 | Reports (37+) | Clinic only exposes `revenue_overview` + `doctor_revenue`; `ReportsHubScreen` not surfaced | High |
| 10 | RBAC + audit | No `audit_trail`/`activity_logs` item; RBAC has no clinic roles (§11) | High |
| 12 | Backup | Only `sync_status` → `BackupScreen`; no explicit "Backup & Restore" item | Medium |
| 4/7 | Expenses / purchases | No `expenses` item (clinics have consumables, salaries, rent); `ExpensesScreen` exists but unexposed | High |
| 8 | OCR | `useScanOCR` not granted to clinic; no document/report scanning in-flow | Low |
| 14 | e-Way bill | N/A for clinic | N/A |
| 15 | Loyalty | N/A / low value for clinic | Low |

**Recommended solution:** Add a "Reports & Accounts" section to `_getClinicSections()` exposing at minimum `expenses`, `daybook`, `accounting_reports`, `outstanding` (receivables), and `backup`. These ids already resolve in `sidebar_navigation_handler.dart`, so the change is config-only (low-risk).

---

## 3. Missing industry-specific features (clinic / OPD)

Verified against the actual `features/doctor/` + `features/clinic/` code:

| Need | Evidence of state | Priority |
|---|---|---|
| **Patient UHID / MRN** | `patient_model.dart` has `id` (UUID) + `qrToken` only; no human-readable UHID/MRN field | High |
| **Date of birth** | `PatientModel.age` is a static `int?` — no DOB; age goes stale and can't be recomputed | Medium |
| **Appointment slots / duration** | `appointment_model`/`appointment_repository.dart` store `scheduledTime` only; no slot length, no double-booking guard | High |
| **Token / queue management** | EXISTS as `features/clinic/.../patient_queue_screen.dart` (route `/clinic/queue`, `/clinic/tokens`) but is **not** in the clinic sidebar — orphaned from desktop nav (§6) | High |
| **OPD consultation fee billing** | Implemented: `clinic_billing_service.createBillFromVisit()` adds "Consultation Fee" line. But fee is `defaultConsultationFee = 500.0` hardcoded (§13) | Medium |
| **Prescription (Rx) + drug master** | Implemented: `SafePrescriptionListScreen`, `AddPrescriptionScreen`, `MedicineMasterScreen` (backed by `ProductsRepository`) | ✅ present |
| **Vitals / diagnosis / EMR** | Implemented in `visit_screen.dart` (BP, Pulse, Temp, Weight, SpO2, symptoms chips, diagnosis, templates, private notes) | ✅ present |
| **Lab test orders & reports** | Implemented: `visit_screen` lab test selector + `LabReportsScreen` (`LabReportRepository`). Report file upload is a **placeholder** ("placeholder for file picking", `lab_reports_screen.dart`) | Medium |
| **Follow-up scheduling** | `followup_repository.dart` + `FollowUpModel` exist, but no sidebar/visit entry point verified — **likely orphaned**; **unverified** whether any screen invokes it | Medium |
| **Medicine refill** | `refill_queue_screen.dart`, `refill_data_repair_screen.dart` exist but are not in sidebar or handler — orphaned (§6) | Medium |
| **Doctor-wise revenue** | Implemented: `DoctorRevenueScreen` + `getRevenueStats/getRevenueChartData(doctorId)` | ✅ present |
| **Pharmacy mini-inventory / dispensing** | `clinic_billing_service.addPrescriptionToBill()` deducts stock via `InventoryService.deductStockInTransaction`, but clinic has **no inventory capability** and **no inventory sidebar item** → cannot add/replenish stock (§13) | High |
| **Patient history / visit timeline** | `PatientHistoryScreen` exists (in BOTH `features/doctor` and `features/clinic`) but sidebar `patient_history` resolves to `PatientListScreen` (§6) | High |
| **Certificates (fitness/medical)** | No screen/model found in `features/doctor` or `features/clinic` enumeration | Medium |
| **SMS / WhatsApp appointment reminders** | grep for `sms|whatsapp|reminder` in `appointment_screen.dart` found none | High |
| **Multi-doctor scheduling** | `ClinicCalendarScreen` and `DoctorRevenueScreen` doctor-picker exist; `doctor_repository.dart` supports multiple doctors, but calendar is orphaned from sidebar | Medium |
| **Consent / PII privacy** | No consent fields/flags in `PatientModel`; health data stored plaintext (§11) | High |

---

## 4. Missing UI components

- **No patient detail / EMR-timeline screen wired.** The richest patient view in nav is `PatientListScreen` (also used for `patient_history`). `PatientHistoryScreen` is not wired (§6). Priority: High.
- **No appointment calendar in clinic nav.** `appointment_screen.dart` uses a horizontal 30-day date strip (`itemCount: 30`), not a week/month calendar grid. `ClinicCalendarScreen` exists but is route-only. Priority: Medium.
- **No queue/token board** in nav despite `PatientQueueScreen` existing. Priority: High.
- **Lab report file upload** is a stub (placeholder), so the "upload result" UI affordance is non-functional. Priority: Medium.
- **Emergency-visit dialog** (`doctor_dashboard_screen._startEmergencyVisit`) collects only a name; no gender/age/phone, defaults gender `'Unknown'` and address `'Emergency Walk-in'` — minimal but functional. Priority: Low.

---

## 5. Missing widgets & dashboard/KPI cards

**Two different dashboards exist for clinic:**
1. `DoctorDashboardScreen` (`features/doctor`) — this is what the sidebar `clinic_dashboard` resolves to. It renders real KPI widgets from `DoctorDashboardRepository`: `PatientOverviewCard`, `DailyPatientView`, `SmartInsightsCard`, `WeeklyAnalyticsChart`, `MonthlyAnalyticsChart`, `AlertsPanel`.
2. `features/clinic/screens/clinic_dashboard_screen.dart` + panels (`overview_panel`, `clinic_performance_panel`, `patient_insights_panel`, `appointment_activity_panel`, `staff_rooms_panel`) — a richer dashboard that is **not** reached by the desktop sidebar.

**Findings:**
- The Dashboard-V2 `BusinessAlertsWidget` clinic case shows **hardcoded** KPI counts (§8): "Today's Appointments" = `'18'`, "Pending Lab Reports" = `'7'`. These are static strings, not queries. Priority: High.
- `DoctorDashboardScreen._buildSmartInsights` displays `avgTime: '15 mins'` hardcoded (`doctor_dashboard_repository.getSmartInsights` comment: "Requires duration tracking in Visits table"). Priority: Medium.
- The two dashboards are **duplicative**; the better one (clinic panels) is orphaned. Priority: High (architecture).

---

## 6. Navigation & route gaps

**Every clinic sidebar id resolves** (table in §1) — no dead links to the placeholder screen. However:

**Miswired item (Critical):**
- `patient_history` → `getScreenForItem` returns `const PatientListScreen()` with an explicit comment "Default to patient list for selection". The dedicated `PatientHistoryScreen` (which takes a `patientId`) is never reached from the sidebar. Users clicking "Patient History" land on the plain patient list. **Recommended:** route `patient_history` to a patient-picker that then opens `PatientHistoryScreen`, or relabel the item.

**Orphaned clinic screens (High):**
- Entire `features/clinic/presentation/screens/` set is wired ONLY via named routes in `lib/app/routes.dart` (`/clinic/queue`, `/clinic/consultation`, `/clinic/history`, `/clinic/labs`, `/clinic/appointment`, `/clinic/prescription`) and `lib/modules/clinic/routes/clinic_routes.dart` — NONE are referenced by the desktop `sidebar_navigation_handler.dart`:
  - `PatientQueueScreen` (token/queue) — orphaned from sidebar
  - `ConsultationScreen` — orphaned from sidebar
  - `LabOrderScreen` — orphaned from sidebar
  - `PatientHistoryScreen` (clinic copy) — orphaned from sidebar
  - `PatientManagementScreen` — orphaned from sidebar
  - `ClinicCalendarScreen` — orphaned from sidebar
- `features/doctor` orphans (not in sidebar; reachable only programmatically): `VisitScreen` (opened from dashboard emergency / appointment tap), `AddPrescriptionScreen` (opened from visit/dashboard), `RefillQueueScreen`, `RefillDataRepairScreen`, `PatientHistoryScreen` (doctor copy).

**Duplicate-implementation hazard (High):** there are two parallel clinic stacks — `features/doctor/*` (sidebar) and `features/clinic/*` (named routes). They duplicate patient history, lab ordering, consultation, and dashboard. This is a maintenance and data-consistency risk; the two stacks may read/write different tables/models (`features/doctor/models/patient_model.dart` vs `features/clinic/data/models/patient_model.dart`). **Unverified** whether both write the same Drift `patients` table.

**Reused mappings:** `sync_status` → `BackupScreen` (acceptable but mislabeled — sync ≠ backup). Priority: Low.

**Missing common sections (gap, High):** clinic sidebar has no Parties/Ledger, no Accounting/Financial Reports, no Tax/GST (acceptable — GST mostly N/A for OPD), no Operations/Audit logs, no dedicated Backup. Several target screens already resolve in the handler, so exposure is config-only.

**Capability mismatches:** `lab_reports` and `doctor_revenue` carry no capability gate, while `prescriptions`/`medicine_master`/`scan_qr` are gated. Inconsistent but not harmful since clinic always has these. Priority: Low. More importantly, clinic `modules` config lists `'inventory'` yet the capability registry grants **no** inventory capability and the sidebar has **no** inventory item — a three-way inconsistency (§13).

---

## 7. Backend integration gaps

- **Sync uses a placeholder tenant id.** `AppointmentRepository` and `PatientRepository` enqueue sync ops with `userId: 'SYSTEM'` (literal), with in-code comments "Should be doctor/vendor ID ideally". Sync payloads therefore aren't attributed to the real clinic/owner. Priority: High.
- **`clinic_billing_service`** correctly uses `doctorId` as `userId` for bills and sync — inconsistent with the patient/appointment repos that use `'SYSTEM'`. Priority: High (data attribution mismatch across the same feature).
- **Lab report upload** has no file/storage backend ("placeholder for file picking" in `lab_reports_screen.dart`). Priority: Medium.
- **Reminders/notifications backend**: no SMS/WhatsApp integration found for appointments. Priority: High.
- `prescription_pharmacy_bridge.dart` exists in `features/clinic/services` (clinic→pharmacy hand-off) but its wiring is **unverified**.

---

## 8. Database & API issues (real vs mock; hardcoded counts)

**Real-data screens (verified):**
- `DoctorDashboardScreen` → `DoctorDashboardRepository` queries real Drift tables (`patients`, `appointments`, `visits`, `bills`) via `getPatientStats`, `watchDailyAppointments`, `getWeeklyAnalytics`, `getMonthlyAnalytics`, `getRevenueStats`, `getVisitCounts`.
- `SafePrescriptionListScreen` → `PrescriptionRepository.getRecentPrescriptions(docId)` (real).
- `LabReportsScreen` → `LabReportRepository.getPendingReports(doctorId)` (real).
- `DoctorRevenueScreen` → `DoctorDashboardRepository` + `DoctorRepository` (real).
- `MedicineMasterScreen` → `ProductsRepository.getAll(userId:)` (real).

**Hardcoded / mock (verified):**
- `business_alerts_widget.dart` clinic case: counts `'18'` (Today's Appointments) and `'7'` (Pending Lab Reports) are literal strings — NOT queried. Note the file has a real `alertCountsProvider` (low-stock/expiry from Drift), but the clinic branch ignores it. Priority: High.
- `getSmartInsights` returns `avgTime: '15 mins'` literal. Priority: Medium.
- `clinic_billing_service.defaultConsultationFee = 500.0` literal (comment says "should be fetched from DoctorProfile"). Priority: Medium.

**Multi-tenancy / data-isolation bug (Critical):**
- `DoctorDashboardRepository.getPatientStats()` runs `_db.select(_db.patients).get()` with **no tenant filter** ("all patients for now" per comment) → total/new patient counts leak across all clinics/owners in a shared DB. Other queries (`visits`, `appointments`) are filtered by `doctorId`, but patient creation writes `userId: 'SYSTEM'` (constant), so patient rows aren't tenant-scoped at all. Priority: Critical.

---

## 9. Responsive design

- `DoctorDashboardScreen` uses `context.isMobile` (from `core/responsive/responsive.dart`) to switch between stacked and `Row`-based layouts — responsive-aware. Good.
- `visit_screen.dart` imports `core/responsive/responsive.dart` and uses `DesktopContentContainer`. Reasonable.
- The `features/clinic` panels (`overview_panel`, etc.) responsiveness is **unverified** (not deeply read).
- No explicit breakpoints reviewed for very small widths in patient/appointment lists. **Unverified.** Priority: Low.

---

## 10. Performance

- `getPatientStats()` loads **all** patient rows into memory then filters in Dart (`.where(...).length`) for "new patients" — O(n) memory; fine at small scale, wasteful at large. Priority: Low/Medium.
- `getWeeklyAnalytics`/`getMonthlyAnalytics` load all matching visits then bucket in Dart rather than `GROUP BY` in SQL. Acceptable for a single clinic; degrades with history size. Priority: Low.
- `DoctorDashboardScreen` issues multiple independent `FutureBuilder`s (`getPatientStats`, `getSmartInsights`, `getWeeklyAnalytics`, `getMonthlyAnalytics`, `getDashboardAlerts`) each hitting the DB on build — no shared caching; a rebuild re-runs all. Priority: Medium.
- Duplicate clinic stacks double the code/asset surface. Priority: Low (perf), High (maintenance).

---

## 11. Security (RBAC, PII / health-data privacy, capability bypass)

- **No clinic-specific RBAC roles.** `UserRole` = `{owner, manager, staff, accountant, unknown}` (`core/models/user_role.dart`). There is no doctor / receptionist / nurse role, so you cannot, e.g., let a receptionist book appointments while blocking access to diagnosis/private notes. The `features/clinic/widgets/role_guard.dart` and a `ClinicRole` enum (referenced in `app_state_providers.dart` from `clinic_dashboard_models.dart`) suggest a parallel clinic-role concept that is **not** integrated with the main `RolePermissions` RBAC used by the sidebar. Priority: Critical.
- **Health data (PII/PHI) stored in plaintext.** `PatientModel` holds `name`, `phone`, `address`, `bloodGroup`, `chronicConditions`, `allergies` with no encryption, no access logging, and no consent flag. `visit_screen` stores diagnosis and "private notes (only visible to doctor)" — but with no role enforcement, "doctor-only" is not actually enforced. Priority: Critical (health-data sensitivity).
- **Capability hard-isolation is sound for clinic** (`FeatureResolver.canAccess` is applied before RBAC in `sidebar_sectionsProvider`), and clinic correctly excludes product/inventory/purchase capabilities. No capability-bypass found in the sidebar path. Priority: informational.
- **Tenant id constant `'SYSTEM'`** (§7/§8) is also a security issue: writes are not attributable to a user/owner, undermining audit and isolation. Priority: Critical.
- **Named routes are guarded.** `/clinic/*` routes in `app/routes.dart` wrap screens in `VendorRoleGuard(requiredPermission: Permissions.viewClients)` + `BusinessGuard(allowedTypes:[clinic])`. Good — but the desktop sidebar path to `features/doctor` screens relies only on capability gating + generic RBAC permissions; **unverified** whether each doctor screen re-checks permissions.

---

## 12. Offline mode gaps

- Clinic data is **offline-first**: `PatientRepository`/`AppointmentRepository` write to local Drift first, then `SyncManager.enqueue(...)`. Good baseline.
- `SyncStatusIndicator` is shown on the doctor dashboard. Sidebar `sync_status` → `BackupScreen`.
- **Gap:** sync queue items are enqueued with `userId:'SYSTEM'` (not real owner), so server-side reconciliation/conflict resolution per tenant may be wrong. Priority: High.
- **Unverified:** whether `bills`/`visits`/`prescriptions`/`lab_reports` all enqueue sync consistently (verified for appointments, patients, bills, prescription-to-bill stock ops; lab report and visit sync **unverified**).

---

## 13. Business logic inconsistencies

- **Inventory three-way contradiction:** clinic `modules` config includes `'inventory'`; the capability registry grants **no** inventory capability; the sidebar has **no** inventory item; yet `clinic_billing_service.addPrescriptionToBill()` deducts stock via `InventoryService`. Result: medicines can be dispensed/deducted but never stocked-in or viewed through clinic UI. Priority: High.
- **Hardcoded consultation fee** `500.0` regardless of doctor/profile (comment acknowledges it should come from `DoctorProfile`). Priority: Medium.
- **Two patient models / two clinic stacks** (`features/doctor` vs `features/clinic`) risk divergent business rules (e.g., `clinic_business_rules.dart` exists only in `features/clinic`). Priority: High.
- **GST:** clinic `defaultGstRate 0.0`, `gstEditable true`, and bill items in `clinic_billing_service` set `taxPercent: 0.0`. Consistent for OPD (exempt), but no handling for taxable items (e.g., some lab tests/medicines) — `gstEditable true` is never exercised in the clinic billing path. Priority: Low.
- **Patient `userId:'SYSTEM'` vs dashboard `doctorId=ownerId`** means newly created patients are not scoped to the querying doctor; the dashboard's "all patients" select masks this by ignoring the filter entirely. Logic is internally inconsistent. Priority: Critical.

---

## 14. Data validation issues

- **Vitals are free-text** (`visit_screen.dart` `_buildVitalInput` uses `TextInputType.text`, no validators) — BP/Pulse/Temp/SpO2 accept any string; no range checks (e.g., SpO2 0–100). Priority: Medium.
- **Patient phone/age optional & unvalidated.** `PatientModel.phone`/`age` nullable; emergency flow creates patients with `gender:'Unknown'`, no phone. No phone format / duplicate-patient detection verified. Priority: Medium.
- **Medicine quantity parsing** in `_calculateMedicineQuantity` parses dosage like `"1-0-1"` and duration like `"5 days"`; on parse failure it silently defaults to `1.0`, which can under-dispense and under-bill without warning. Priority: Medium.
- **No allergy↔prescription cross-check.** Allergies are displayed as a banner in `visit_screen`, but there is no logic preventing prescribing a drug the patient is allergic to. Priority: High (clinical safety).

---

## 15. UX problems

- "Patient History" opens a plain patient list, not a history (§6) — confusing affordance. Priority: High.
- Token/queue and calendar features exist but are unreachable from the clinic sidebar (§6) — users can't find core OPD flow controls. Priority: High.
- `sync_status` labeled in System but opens Backup screen — mismatched mental model. Priority: Low.
- Hardcoded dashboard counts ("18 appointments", "7 lab reports") will mislead users because they never change. Priority: High.
- Emergency-visit dialog drops phone/age permanently (no later prompt to complete the record). Priority: Medium.
- Heavy use of hardcoded white/`FuturisticColors` text in `visit_screen`/dashboard dialogs (e.g., `Colors.white`) may clash with light themes. Priority: Low.

---

## 16. Accessibility

- Vitals/diagnosis fields rely on `labelText`/`hintText` — acceptable for screen readers, but symptom `FilterChip`s and `ActionChip` templates have no explicit semantic labels beyond their text. **Unverified** for full WCAG.
- Color-only status signaling: visit status banner and allergy alert convey meaning largely via red/orange color; text accompanies them (good), but count badges in alerts are color-coded only. Priority: Low.
- No verified support for text scaling / large fonts in dense list rows. **Unverified.**
- Full accessibility compliance requires manual testing with assistive technologies and expert review — not performed here.

---

## 17. Bugs / errors / crash scenarios

- **Cross-tenant data leak** via unfiltered `getPatientStats` (§8) — not a crash, but a correctness/privacy defect. Critical.
- **`'SYSTEM'` fallback id** propagates everywhere `ownerId` is null (`ownerId ?? 'SYSTEM'` in dashboard, visit, revenue, prescriptions). If a session lacks `ownerId`, all clinics share the `'SYSTEM'` bucket. High.
- **`SafePrescriptionListScreen`** name implies a defensive wrapper around a previously crash-prone prescription list; the head shows a straightforward `FutureBuilder` with empty-state handling — no try/catch around `_fetchAllPrescriptions()`, so a repo throw surfaces as a `FutureBuilder` error with no error UI branch (only waiting + data). Priority: Medium. (Body beyond line 80 **unverified**.)
- **`visit_screen` quantity parser** swallows exceptions and defaults to 1.0 (§14) — silent mis-billing. Medium.
- **Lab report upload placeholder** — tapping upload may no-op or mislead. Medium (**unverified** exact behavior).
- Duplicate route stacks could cause two screens to mutate the same `patients` table via different models, risking schema drift. High (**unverified**).

---

## 18. Unnecessary / irrelevant features shown

- The clinic sidebar is tightly scoped (no retail/inventory clutter) — good isolation. No clearly irrelevant items present.
- `medicine_master` (Medicine Master) is reasonable for clinics that dispense, but without inventory capabilities it's a half-feature (§13).
- `BusinessQuickActions` clinic case shows New Patient / Appointments / Write Rx — all relevant. The trailing generic "Alerts" action is gated by `caps.accessLowStockAlert`, which clinic lacks, so it won't show — consistent.
- No irrelevant Vyapar retail widgets surface for clinic in the V2 dashboard alerts/actions (clinic branches are dedicated).

---

## 19. Recommendations & prioritized implementation plan

**Critical (correctness, privacy, security):**
1. Fix tenant scoping: replace literal `userId:'SYSTEM'` in `PatientRepository`/`AppointmentRepository` with the real session owner id; add a tenant filter to `getPatientStats` (filter `patients` by owner/clinic). (`patient_repository.dart`, `appointment_repository.dart`, `doctor_dashboard_repository.dart`)
2. Introduce clinic RBAC roles (doctor/receptionist/nurse) or map them onto existing roles, and enforce on the `features/doctor` sidebar screens (especially diagnosis/private notes). Integrate the orphan `features/clinic/widgets/role_guard.dart`/`ClinicRole` with the main `RolePermissions`.
3. Add PHI safeguards: consent flag on `PatientModel`, access logging for patient/visit reads, and at-rest protection strategy for sensitive columns. Add an allergy↔prescription contraindication check before saving an Rx.

**High:**
4. Resolve the duplicate clinic stack: choose `features/doctor` (sidebar) or `features/clinic` (routes) as canonical; deprecate the other (do not delete without sign-off). Until then, wire the superior screens (queue/token, calendar) into the clinic sidebar.
5. Fix `patient_history` to open `PatientHistoryScreen` (via a patient picker) instead of `PatientListScreen`.
6. Replace hardcoded dashboard counts in `business_alerts_widget.dart` clinic case (and `getSmartInsights.avgTime`) with real queries (today's appointments count, pending lab reports count).
7. Expose Reports/Accounts/Expenses/Receivables/Backup in `_getClinicSections()` (ids already resolve in the handler).
8. Resolve the inventory contradiction: either grant clinic a minimal pharmacy-inventory capability + sidebar item (stock-in for dispensed meds) or stop auto-deducting stock in `clinic_billing_service`.
9. Add SMS/WhatsApp appointment reminders backend + opt-in.

**Medium:**
10. Make consultation fee come from `DoctorProfile`, not `defaultConsultationFee = 500.0`.
11. Add DOB (derive age), validate vitals ranges, validate phone, and surface medicine-quantity parse failures instead of defaulting to 1.
12. Implement real lab-report file upload/storage.
13. Add error-state branches to `FutureBuilder`s (prescriptions, dashboard) and consider a shared dashboard data provider to avoid N independent DB hits per build.

**Low:**
14. Relabel `sync_status` or split Sync vs Backup. Add capability gates consistently (`lab_reports`, `doctor_revenue`). Theme-aware colors in clinic dialogs. Certificates module (fitness/medical) if in scope.

---

## 20. Confidence & Coverage

**Confidence: Medium-High** for navigation/config/capability/RBAC and dashboard-widget findings (read directly). **Medium** for repository/data-source claims (key repos read; some screen bodies and the entire parallel `features/clinic` internals only enumerated/route-verified, not deeply read).

**Coverage:**
- Config / enum / capability / RBAC: **High** (read in full for clinic).
- Sidebar + navigation handler: **High** (full `getScreenForItem` read; all 15 clinic ids cross-checked).
- Dashboard quick-actions & alerts widgets: **High** (clinic cases read; hardcoded counts confirmed).
- `features/doctor` data layer: **High** for `doctor_dashboard_repository`, `appointment_repository`, `patient_repository`, `clinic_billing_service`; **Medium** for screens (dashboard + visit read in full; prescriptions head only; lab/revenue/medicine confirmed via targeted grep of data sources).
- `features/clinic` parallel module: **Low-Medium** (existence + route wiring confirmed via `app/routes.dart` and `modules/clinic/routes/clinic_routes.dart`; screen internals **unverified**).

**Explicitly unverified claims:** follow-up/refill screen invocation paths; whether both clinic stacks write the same Drift tables; full bodies of `appointment_screen`, `patient_list_screen`, `add_patient_screen`, `lab_report_repository`, `prescription_repository`; responsiveness/accessibility under real devices; `prescription_pharmacy_bridge` wiring; exact behavior of the lab-report upload placeholder.
