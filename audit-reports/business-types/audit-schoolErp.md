# DukanX Business-Type Audit — School ERP (`schoolErp`)

READ-ONLY, evidence-based audit. No source files were modified. Every claim cites the file/function inspected. Items I could not verify by reading code are marked **unverified**.

---

## 1. Header — Resolution, Config, Capabilities, Placeholder Assessment

**Enum / identity**
- `BusinessType.schoolErp` is a real enum member — `Dukan_x/lib/models/business_type.dart` (line ~21). `displayName` = `'School ERP'`, `icon` = `Icons.school_rounded` (same file, `displayName`/`icon` switches).
- Emoji `🏫`, primary color `0xFF2563EB` (Blue), PDF color `#2563EB` — `Dukan_x/lib/core/billing/business_type_config.dart` (`emoji`, `primaryColor`, `pdfPrimaryColor` extensions).
- Selectable in onboarding: `Dukan_x/lib/screens/business_type_selection_screen.dart` (line ~209 `case BusinessType.schoolErp`). String mapping `schoolerp`/`school`/`institute`/`academiccoaching` → `BusinessType.schoolErp` in `Dukan_x/lib/providers/app_state_providers.dart` (~lines 1058-1068).

**Billing config** — `business_type_config.dart`, `BusinessTypeRegistry._configs[BusinessType.schoolErp]`:
- requiredFields: `itemName, quantity, price`; optionalFields: `notes, gst`; `defaultGstRate 0.0`, `gstEditable true`; units `pcs, set`; `itemLabel 'Fee/Item'`, `addItemLabel 'Add Fee/Item'`, `priceLabel 'Amount'`; modules `['students','fees','attendance','exams','reports']`. Confirmed as described.

**Sidebar resolution (CONFIRMED WRONG)**
- `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart`, `_getSectionsForBusiness(BusinessType type)`: there is **no `case BusinessType.schoolErp`** → it falls to `default: return _getRetailSections();`. A school sees the full retail/billing sidebar (Revenue Desk, BuyFlow, Inventory & Stock, Parties & Ledger, GST/Tax, etc.). This is the single most serious structural defect.

**Capabilities (EXIST and are rich)**
- `Dukan_x/lib/core/isolation/business_capability.dart` has a `'schoolErp'` key in `businessCapabilityRegistry` granting: `useStudentRegistry, useFeeCollection, useAttendanceTracking, useTimetable, useTestResults, useCertificates, useScholarshipDiscount, useParentNotifications, useCourseMaterial, useDemoClasses, useAppointments, useStaffManagement, useBatchManagement`, plus `useInvoiceCreate/List/Search`, `useDailySnapshot, useRevenueOverview, useGeneralAlerts`.
- `Dukan_x/lib/core/isolation/feature_resolver.dart` `_normalizeType()` maps `academiccoaching`/`academic_coaching`/`schoolerp`/`school_erp` → `'schoolErp'`. Capability gating works.

**Placeholder assessment (the key question)**
schoolErp is **NOT** a near-empty placeholder, but it is **NOT** a coherent product either. It is a *half-wired* business type:
- A substantial in-app ERP feature exists: `Dukan_x/lib/features/academic_coaching/` with **34 screens** (students, fees, attendance, exams, report cards, timetable, hostel, library, transport, certificates, faculty, payroll, admissions, etc.) and a **full REST repository** `data/repositories/ac_repository.dart` calling Lambda `/ac/*` endpoints.
- A module exists: `Dukan_x/lib/modules/school_erp/school_erp_module.dart` (loaded by `Dukan_x/lib/core/module/module_loader.dart` → `SchoolErpModule()`), with sync + websocket handlers.
- **21 named routes** are registered and guarded to `schoolErp` in `Dukan_x/lib/app/routes.dart` (`/ac/dashboard`, `/ac/students`, `/ac/fees`, `/ac/attendance`, `/ac/exams`, … `/ac/fee-structure`).
- **BUT**: none of these are reachable from the schoolErp shell UI. The sidebar shows retail items; the dashboard quick-actions/alerts have no school case; and no UI code navigates to any `/ac/*` route (verified by searching `pushNamed('/ac`).
- Separately, **standalone Flutter apps** exist at repo root: `school_admin_app/`, `school_teacher_app/`, `school_student_app/`, `school_common/` (confirmed via root directory listing). These appear to be the customer-facing school product.

**Verdict:** The real, usable School ERP lives (a) in the separate `school_*_app/` projects and (b) as an orphaned-but-built `academic_coaching` feature inside Dukan_x. The `schoolErp` *business type* inside Dukan_x is a shell whose UI surfaces (sidebar, dashboard, quick actions, alerts) were never customized, so the built academic screens are effectively unreachable from it.

---

## 2. Missing Generic Features (Vyapar benchmark — fee/billing-relevant only)

A school ERP is not retail, so most Vyapar items are N/A. Mapping the relevant ones:

| # | Vyapar capability | Status for schoolErp | Evidence |
|---|---|---|---|
| 1 | Billing (fee receipts) | Built but unreachable from shell | `ac_repository.createInvoice`/`recordPayment` (`/ac/invoices`,`/ac/payments`); `AcFeeCollectionScreen` routed at `/ac/fees` but no UI links to it |
| 4 | Accounting | Generic only | retail sidebar exposes `accounting_reports`, `daybook` (`sidebar_configuration.dart` retail) — not school-aware |
| 5 | Receivables/Payables (fee dues) | Partial/unreachable | `AcFinancialReportsScreen` `/ac/financial`, dues logic in `ac_repository.getStudentFees` — not surfaced |
| 6 | Bank/Cash | Generic only | retail `cash_bank`, `bank_accounts` items |
| 9 | Reports | Built but unreachable | `AcReportsScreen`/`AcFinancialReportsScreen` exist; sidebar points to retail reports instead |
| 10 | RBAC + audit | **Missing school roles** | `UserRole` enum = `owner, manager, staff, accountant, unknown` only (`Dukan_x/lib/core/models/user_role.dart`). No teacher/parent/student/principal |
| 11 | Multi-firm | unverified | not inspected for school context |
| 12 | Backup | Generic only | retail `backup` item |
| 16 | Service | N/A-ish | fee billing is the closest analog |
| 17 | Offline-first sync | Partial | `SchoolErpSyncHandler` (`collection 'school_students'`, `apiBasePath '/ac/students'`) exists; AC repository itself is online-only REST (no local Drift cache observed in `ac_repository.dart`) |

**Priority — High:** Fee receipt/billing flow is implemented but not reachable from the schoolErp shell.

---

## 3. Missing Industry-Specific Features (School ERP needs)

The academic feature set is largely BUILT (in `features/academic_coaching/presentation/screens/`), but reachability from the `schoolErp` shell is the problem. Status legend: **Built+Routed** (named route in `routes.dart`), **Built, Orphaned** (screen exists, no named route), **Missing**.

| Need | Status | Evidence |
|---|---|---|
| Student admission & profiles | Built+Routed (`/ac/students`); admissions **Built, Orphaned** | `AcStudentsScreen`, `AcStudentRegistrationScreen`; `ac_admissions_screen.dart` exists but no route |
| Class/section/roll management | Built+Routed | `/ac/classes` → `AcClassSectionsScreen` |
| Academic year/term | Built+Routed | `/ac/academic-year` → `AcAcademicYearScreen` |
| Batches/courses | Built+Routed | `/ac/batches`, `/ac/courses` |
| Fee structure & multi-class fee heads | Built+Routed | `/ac/fee-structure` → `AcClasswiseFeeScreen` |
| Fee collection / receipts / dues | Built+Routed | `/ac/fees` → `AcFeeCollectionScreen`; `getStudentFees`, `recordPayment` |
| Attendance (student) | Built+Routed | `/ac/attendance` → `AcAttendanceScreen` |
| Attendance (staff) & payroll | Built (repo), screen **Orphaned** | `ac_repository` `/ac/faculty/$id/attendance`, `/ac/faculty/$id/payroll`; `ac_leave_screen.dart` exists, no route |
| Timetable | Built+Routed | `/ac/timetable` |
| Exams/marks | Built+Routed | `/ac/exams` |
| Report cards | Built+Routed | `/ac/report-cards` → `AcReportCardsScreen` |
| Teacher/staff management | Built+Routed | `/ac/faculty` |
| Transport/route & fees | Built+Routed | `/ac/transport` |
| Library | Built+Routed | `/ac/library` → `AcLibraryScreen` |
| Hostel | **Built, Orphaned** | `ac_hostel_screen.dart` exists, no named route |
| Homework / lesson plans | **Built, Orphaned** | `ac_homework_screen.dart`, `ac_lesson_plans_screen.dart`, `ac_materials` routed |
| ID cards / documents / siblings | **Built, Orphaned** | `ac_id_cards_screen.dart`, `ac_documents_screen.dart`, `ac_sibling_screen.dart` — no routes |
| Parent communication (SMS/app) | Built+Routed | `/ac/notifications` → `AcNotificationsScreen`; `useParentNotifications` capability |
| Concessions/scholarships | Capability only | `useScholarshipDiscount` capability; no dedicated screen verified |
| Certificates | Built+Routed | `/ac/certificates` |
| At-risk detection | Built+Routed | `/ac/risk` → `AcRiskDetectionScreen` |

**Priority — Critical (integration):** The features exist but the `schoolErp` shell does not expose them. **Priority — Medium:** Orphaned screens (admissions, hostel, homework, lesson plans, id cards, documents, siblings, leave, inventory, payments) have no route at all.

---

## 4. Missing UI Components

- No school-specific sidebar component — `sidebar_configuration.dart` has dedicated builders `_getClinicSections`, `_getPharmacySections`, `_getRestaurantSections`, `_getPetrolPumpSections`, `_getServiceSections`, but **no `_getSchoolSections`** → falls to `_getRetailSections`. **(High)**
- No school dashboard surfaced through the shell. `AcDashboardScreen` exists and is routed at `/ac/dashboard` but the default owner dashboard (`DashboardController`) is what a schoolErp user lands on. **(High)**
- Item-entry labels ("Fee/Item", "Amount") from config are generic; no fee-head/student-linked bill entry component in the main billing screen (`BillCreationScreenV2`) verified for schoolErp. **(Medium, partially unverified)**

---

## 5. Missing Widgets & Dashboard/KPI Cards

- `Dukan_x/lib/features/dashboard/v2/widgets/business_quick_actions.dart` — `_buildActionsForBusiness` switch has **no `case BusinessType.schoolErp`** → hits `default:` showing "Add Customer" + "Reports". No "Collect Fee", "Mark Attendance", "New Admission" actions. **(High)**
- `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart`:
  - `_getTitle` has no schoolErp case → returns generic `'Business Alerts'`. **(Medium)**
  - `_buildAlertsForBusiness` has no schoolErp case → `default:` shows "No Active Alerts / Business running smoothly". No "Fees Due", "Absentees Today", "Exam Schedule" cards. **(High)**
- No fee-collection / dues / attendance KPI cards anywhere in the shell dashboard. `AcDashboardStats` model exists (`ac_repository.getDashboard()`), but only consumed by the orphaned `AcDashboardScreen`. **(High)**

---

## 6. Navigation & Route Gaps

**Retail sidebar IDs for schoolErp users:** every retail item (e.g. `executive_dashboard`, `new_sale`, `stock_summary`, `gstr1`, `purchase_orders`, `customers`) resolves via `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart` `getScreenForItem()`. None of these are school screens. So the school user navigates a fully retail app.

**Reachability of school screens:**
- `getScreenForItem()` has **no school cases** (`school_students`, `school_fees`, `school_attendance`, `school_exams` are absent) → if such an ID were used it returns `_buildPlaceholderScreen('Unknown Screen')`. **(High)**
- 21 `/ac/*` named routes exist in `app/routes.dart`, all guarded `BusinessGuard(allowedTypes:[schoolErp])`, but **no UI navigates to them** — confirmed by searching `'/ac/` usages: only the route table, the module `navItems`, and the module `GoRoute` table reference these paths; there is no `pushNamed('/ac/...')` call from any screen/sidebar. **(Critical — features are stranded.)**

**Module navItems are not consumed by the active shell:**
- `SchoolErpModule.navItems` defines 10 entries (`school_students`→`/ac/students`, `school_batches`, `school_fees`, …). `ModuleRegistry.buildNavItems()` collects them, but the desktop shell (`Dukan_x/lib/widgets/desktop/enterprise_sidebar.dart`) and mobile drawer (`Dukan_x/lib/core/responsive/mobile_drawer.dart`) both render `sidebarSectionsProvider` (from `sidebar_configuration.dart`), **not** module navItems. No caller of `buildNavItems` was found in the shell. **(Critical — the module's own menu never renders.)**

**Dual/inconsistent route registries:**
- `Dukan_x/lib/modules/school_erp/routes/school_erp_routes.dart` defines a go_router table (`/ac/students`→`AcStudentRegistrationScreen`, `/ac/batches`→`AcBatchesScreen`, `/ac/fees`→`LegacyRouteRedirect`, …). Per `Dukan_x/lib/core/module/legacy_route_redirect.dart` docs, go_router module routes are **not yet wired** (app still uses `MaterialApp.routes`), so this table is dormant. **(Medium — divergence risk.)**
- Inconsistency: in the go_router table `/ac/students` → `AcStudentRegistrationScreen`, but in the active named-route table `/ac/students` → `AcStudentsScreen`. Two different screens for the same path. **(Medium)**
- `/ac/fees` go_router entry is a `LegacyRouteRedirect` (placeholder→named route) even though `AcFeeCollectionScreen` is directly available; redundant indirection. **(Low)**

**Capability vs route mismatch:** Capability `useStudentRegistry` etc. are granted, but the sidebar never queries them (retail sidebar items use retail capabilities). So capability grants have no UI effect for schoolErp. **(High)**

**Relationship to `academic_coaching` and separate apps:** The `schoolErp` type's intended functionality = `academic_coaching` screens (confirmed by both the module routes and the named routes importing from `features/academic_coaching/...`). The separate `school_admin_app`/`school_teacher_app`/`school_student_app` are independent products (root-level), not wired into Dukan_x navigation.

---

## 7. Backend Integration Gaps

- `ac_repository.dart` is a **real REST integration** via `ApiClient` against Lambda `/ac/*` (students, batches, courses, fees, payments, attendance, faculty, payroll, exams, dashboard). Amounts documented as paise-on-wire. So backend wiring at the data layer exists. **(Good)**
- Backend endpoint existence/deployment is **unverified** (did not inspect `lambda/` or `my-backend/`).
- `SchoolErpSyncHandler` maps `collection 'school_students'` → `apiBasePath '/ac/students'`. Only students are covered by the sync handler; fees/attendance/exams sync **not** evident in `Dukan_x/lib/modules/school_erp/sync/school_erp_sync_handler.dart`. **(Medium)**
- `SchoolErpWsHandler` declares events `school.fee.due`, `school.attendance.marked`, `school.exam.result` but the dashboard alerts widget does not subscribe to them (it only listens to `inventory.*` UNS events). So real-time school events never update any visible UI. **(High)**

---

## 8. Database & API Issues (real vs mock, hardcoded counts, default dashboard)

- **Default dashboard case:** schoolErp has no dedicated dashboard in the shell; `business_alerts_widget`/`business_quick_actions` fall to `default`. **(High)**
- **Hardcoded alert counts:** `business_alerts_widget.dart` uses hardcoded literal counts for most types (e.g., pharmacy `'5'`/`'3'`/`'15'`, restaurant `'7'`/`'12'`). For schoolErp the default branch shows static "No Active Alerts / 0". No real fee-due/absentee counts are computed. **(High)**
- **Alert data source mismatch:** `alertCountsProvider` queries `productBatches`/low-stock (`ProductsRepository.getLowStockProducts`) — inventory concepts irrelevant to a school. Even if a school case were added, the provider has no fee/attendance queries. **(High)**
- **Local DB:** `ac_repository` reads/writes only via REST; no Drift table caching observed → offline behavior weak (see §12). **(Medium)**

---

## 9. Responsive Design

- The shell is responsive via `adaptive_shell.dart` + shared `sidebarSectionsProvider` (desktop sidebar and `mobile_drawer.dart` use the same source — `navigation_destinations.dart` comments confirm parity). But because schoolErp inherits retail sections, responsiveness applies to the *wrong* menu. **(Low for layout, High for relevance.)**
- Individual AC screens' responsiveness **unverified** (e.g., `ac_fee_collection_screen.dart` imports `core/responsive/responsive.dart`, suggesting some responsive handling — not fully reviewed).

---

## 10. Performance

- `sidebarSectionsProvider` is memoized (rebuilds only on business-type/auth change) — good (`sidebar_configuration.dart` doc comment).
- Retail sidebar builds ~10 sections / 60+ items that a school never needs — minor wasted build cost. **(Low)**
- `ac_repository` list calls are paginated (`PaginatedResponse`, page/limit) — good design. **(Low/positive)**
- Online-only repository means every screen load hits the network with no cache; perceived latency risk. **(Medium, partly unverified.)**

---

## 11. Security (RBAC + PII of minors)

- **RBAC roles missing:** `UserRole` enum (`Dukan_x/lib/core/models/user_role.dart`) = `owner, manager, staff, accountant, unknown`. There is **no teacher, parent, student, principal, or accountant-for-school role**. All `/ac/*` routes are guarded with generic retail permissions: `Permissions.viewInvoices`, `viewClients`, `viewReports`, `createInvoices` (`app/routes.dart`). A "fee collection" screen is gated behind `viewInvoices`, "students" behind `viewClients`. This conflates school concepts with retail RBAC. **(High)**
- **PII of minors:** Student profiles, siblings, ID cards, documents, attendance, and parent contact data are personal data of children. No evidence of: field-level access controls for minors, parent-consent handling, data-retention/anonymization, or encryption-at-rest specific to this data (`ac_repository` sends plain JSON to REST). This is a privacy/compliance concern. **(Critical for production — privacy.)**
- No school-scoped audit trail; the retail sidebar exposes a generic `audit_trail` item mapped to `AllTransactionsScreen` (`sidebar_navigation_handler.dart`), which tracks transactions, not student-data access. **(High)**

---

## 12. Offline Mode Gaps

- `business_alerts_widget` does an initial offline fetch then listens to UNS — but only for inventory events, irrelevant to school.
- `ac_repository` has no local persistence layer (all methods are `_apiClient.get/post/put/delete`). If offline, student/fee/attendance screens will throw (`throw Exception('Failed to load ...')`). **(High)**
- `SchoolErpSyncHandler` exists for `school_students` only; fees/attendance/exam offline sync not present. **(Medium)**

---

## 13. Business Logic Inconsistencies

- **Retail sidebar for a school is fundamentally wrong** (`_getSectionsForBusiness` default). A school owner sees BuyFlow, Purchase Orders, Stock Valuation, GSTR-1, HSN reports, Dispatch Notes — none applicable. **(Critical)**
- **Capability grants without UI:** `businessCapabilityRegistry['schoolErp']` grants student/fee/attendance capabilities, but no sidebar/dashboard reads them → grants are inert. **(High)**
- **Two screens for one path** (`/ac/students` → `AcStudentsScreen` in named routes vs `AcStudentRegistrationScreen` in module routes). **(Medium)**
- **GST editable + 0% default** for a school is reasonable for tuition (exempt) but the retail GST/Tax & Compliance sidebar section is still shown. **(Medium)**
- Bill template falls back to `_serviceTemplate` for schoolErp (`Dukan_x/lib/features/onboarding/bill_template_system.dart` ~line 85) — acceptable as a fee receipt analog, but not a true fee-receipt layout. **(Low)**

---

## 14. Data Validation Issues

- `ac_repository` posts raw `Map<String,dynamic>` (`createStudent`, `createFaculty`, `recordPayment`) with no client-side schema validation visible in the repository layer. Validation may live in `utils/ac_validators.dart` (exists, **not fully reviewed**). **(Medium, partly unverified.)**
- Fee/payment amounts are paise-on-wire per file header; mis-conversion risk if a screen passes rupees. Conversion correctness **unverified per screen**. **(Medium)**
- The generic billing config requires only `itemName, quantity, price` — no validation that a fee is linked to a student/class. **(Medium)**

---

## 15. UX Problems

- A school owner is dropped into a retail UI: confusing labels (Invoice/Bill, Suppliers, BuyFlow) for a school context. **(High)**
- Quick Actions show "Add Customer" / "Reports" (default branch) — not school tasks. **(High)**
- Built academic screens are invisible (no menu entry), so users cannot discover fees/attendance/exams without deep-linking. **(Critical for usability.)**
- Alerts panel says "Business running smoothly / No Active Alerts" regardless of fee dues or absentees. **(Medium)**

---

## 16. Accessibility

- Not specifically degraded for schoolErp beyond the app baseline; same widgets as other types. Detailed a11y (labels, contrast, screen-reader, focus order) of AC screens **unverified**. Full WCAG validation requires manual assistive-technology testing and expert review. **(Unverified)**

---

## 17. Bugs / Errors / Crash Scenarios

- **Stranded features (functional bug):** all 21 `/ac/*` routes are unreachable from the shell (no navigation entry). Effective "feature not implemented" from the user's view. **(Critical)**
- **Offline crash path:** AC screens call `ac_repository` which throws on non-200/offline; no cached fallback → error states or exceptions. **(High)**
- **Unknown-screen placeholder:** if any school `nav id` (e.g., `school_students`) were ever routed through `getScreenForItem`, it returns the "Unknown Screen / Feature Not Found" placeholder. **(Medium)**
- **Path collision:** `/ac/students` resolves to different screens in the two route registries; whichever is active changes behavior, a latent bug when go_router migration lands. **(Medium)**
- **Real-time no-op:** `SchoolErpWsHandler` events are declared but no consumer updates UI → silent. **(Low/Medium)**

---

## 18. Unnecessary / Irrelevant Features Shown

The **entire retail sidebar is irrelevant** to a school (`_getRetailSections()` in `sidebar_configuration.dart`). Specifically irrelevant sections/items surfaced to schoolErp:
- BuyFlow: `buyflow_dashboard`, `purchase_orders`, `stock_entry`, `stock_reversal`, `procurement_log`, `supplier_bills`, `purchase_register`.
- Inventory & Stock: `stock_summary`, `item_stock`, `batch_tracking`, `low_stock`, `stock_valuation`, `damage_logs`.
- Tax & Compliance: `gstr1`, `b2b_b2c`, `hsn_reports`, `tax_liability`, `filing_status`.
- Parts of Revenue Desk: `return_inwards`, `dispatch_notes`, `booking_orders`, `proforma_bids`.
- Parties & Ledger: `suppliers` (a school has no suppliers in the retail sense).

**Priority — Critical:** replace the entire menu with a school-specific one.

---

## 19. Recommendations & Prioritized Implementation Plan

**Strategic decision first (Critical):** The functionality already exists (`academic_coaching` + 21 routes + REST backend). Recommend **integrating** rather than removing the type. Removing it would waste 34 built screens and a working repository. The separate `school_*_app/` projects can remain the parent/teacher/student-facing apps; the Dukan_x `schoolErp` type should be the **admin/office** surface that reuses `academic_coaching`.

**P0 — Critical (make built features reachable)**
1. Add `_getSchoolSections()` in `sidebar_configuration.dart` and a `case BusinessType.schoolErp` in `_getSectionsForBusiness`. Sections: Dashboard, Students & Admissions, Fees, Attendance, Exams & Report Cards, Timetable, Faculty & Payroll, Transport, Library/Hostel, Communication, Reports.
2. Add school `case`s in `sidebar_navigation_handler.dart` `getScreenForItem()` mapping new IDs to the `Ac*Screen` widgets (reuse the same widgets `app/routes.dart` already references).
3. Surface `AcDashboardScreen` as the landing dashboard for schoolErp (or embed `AcDashboardStats` KPI cards in the V2 dashboard).

**P1 — High**
4. Add `case BusinessType.schoolErp` to `business_quick_actions.dart` (Collect Fee, New Admission, Mark Attendance, Enter Marks) and to `business_alerts_widget.dart` (`_getTitle` + `_buildAlertsForBusiness`) with **real** counts from `ac_repository` (fees due, today's absentees, upcoming exams).
5. Introduce school RBAC roles (extend `UserRole` or add a school role layer) — principal/admin/teacher/accountant/parent — and replace generic `Permissions.viewInvoices/viewClients` guards on `/ac/*` with school-specific permissions.
6. Add minors' PII safeguards: access scoping, audit logging of student-data access, encryption/retention policy. Treat as a compliance gate before production.
7. Subscribe the dashboard to `SchoolErpWsHandler` events (`school.fee.due`, `school.attendance.marked`, `school.exam.result`) so real-time updates render.

**P2 — Medium**
8. Add offline cache (Drift tables) for students/fees/attendance, and extend `SchoolErpSyncHandler` beyond `school_students`.
9. Resolve the `/ac/students` path collision and the dormant go_router table; pick one registry. Remove the `/ac/fees` `LegacyRouteRedirect` indirection.
10. Route the orphaned screens (admissions, hostel, homework, lesson plans, id cards, documents, siblings, leave, payments, inventory) or delete if superseded.
11. Provide a true fee-receipt PDF template instead of `_serviceTemplate`.

**P3 — Low**
12. Trim the build cost of the retail sidebar for schoolErp (resolved automatically by P0-1).
13. Add client-side validation surfacing in fee/payment/student forms (audit `utils/ac_validators.dart`).

---

## 20. Confidence & Coverage

**Sampled (read directly):**
- `models/business_type.dart`, `core/billing/business_type_config.dart`, `widgets/desktop/sidebar_configuration.dart`, `widgets/desktop/sidebar_navigation_handler.dart`.
- `features/dashboard/v2/widgets/business_quick_actions.dart`, `business_alerts_widget.dart`.
- `core/isolation/business_capability.dart`, `core/isolation/feature_resolver.dart`, `core/config/business_capabilities.dart`.
- `modules/school_erp/school_erp_module.dart`, `.../routes/school_erp_routes.dart`, `core/module/legacy_route_redirect.dart`.
- `app/routes.dart` (school section, lines ~903-1072), `core/models/user_role.dart`, `features/academic_coaching/data/repositories/ac_repository.dart` (first ~430 lines), directory listing of `features/academic_coaching/` (34 screens) and repo root.
- Targeted searches: `schoolErp`/`FeeCollection`/`navItems`/`sidebarSectionsProvider`/`buildNavItems`/`'/ac/` usages.

**Skipped / not fully reviewed (unverified):**
- Individual AC screen widgets (responsiveness, a11y, validation UI) beyond imports.
- `utils/ac_validators.dart`, `data/models/ac_models.dart`, `data/providers/ac_providers.dart`.
- Full `session_manager.dart` `RolePermissions` matrix; `enterprise_sidebar.dart` rendering internals.
- Backend (`lambda/`, `my-backend/`) — endpoint existence/deployment for `/ac/*`.
- The standalone `school_admin_app/`, `school_teacher_app/`, `school_student_app/`, `school_common/` internals (only confirmed to exist).
- Subscription tier-gating layer (`gating_config`, `plan_mapping_*`) effect on schoolErp beyond noting `useStudentRegistry/useFeeCollection/useAttendanceTracking` appear in `plan_mapping_builder.dart`.

**Confidence:** High for the core finding — schoolErp resolves to the retail sidebar, has no dashboard/quick-action/alert customization, and its rich `academic_coaching` screens + 21 guarded routes are unreachable from the shell UI (no navigation entry; module navItems unused). Medium confidence on backend/offline/validation specifics (data layer read, but backend and per-screen behavior not exhaustively verified).
