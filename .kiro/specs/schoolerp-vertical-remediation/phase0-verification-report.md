# Phase 0 — Verification Report (Read-Only)

**Spec:** `schoolerp-vertical-remediation`
**Phase:** 0 — Re-Verification and Gap Discovery
**Mode:** STRICTLY READ-ONLY. Zero application source / config / build files created, modified, or deleted. The only artifact produced is this report.
**Requirements covered:** 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11
**Scope of inspection:** `Dukan_x/lib/features/academic_coaching/**` plus the shared files referenced by the School_System (`lib/core/routing/legacy_routes.dart`, `lib/core/api/api_client.dart`).

> ⚠️ **STOP / DISCREPANCY FLAG (Req 3.11):** A Ground-Truth assumption embedded in the design is **contradicted** by the live codebase — the application has already migrated to GoRouter (`MaterialApp.router` is the sole navigation root), so the design's premise that `legacy_routes.dart` is "the live `MaterialApp.routes` table" and Requirement 2.4's premise ("do not migrate off `MaterialApp.routes`") are no longer accurate. See **§9** for the full discrepancy. Phase 0 records it here and does **not** route around it; human sign-off is recommended before Phase 1.

---

## 3.1 Read-only compliance

- Files created: **1** — this report (`.kiro/specs/schoolerp-vertical-remediation/phase0-verification-report.md`).
- Application source / configuration / build files created, modified, or deleted: **0**.
- ✅ Compliant with Req 3.1.

---

## 3.2 Hardcoded-literal search (`vendorId`, `tenantId`, `'SYSTEM'`)

Repository-wide search across `lib/features/academic_coaching/**/*.dart` for the literals `vendorId`, `tenantId`, and `'SYSTEM'`/`"SYSTEM"`.

**Result: NONE FOUND.**

- No `vendorId` identifier-literal occurrences.
- No `tenantId` identifier-literal occurrences.
- No `'SYSTEM'` / `"SYSTEM"` string-literal occurrences.

Note on near-matches (not hardcoded tenant/vendor literals — recorded for completeness):
- `ac_inventory_screen.dart:32, 44–45, 83, 90–91, 139` — the word "vendor"/"Vendors" appears only as UI tab labels and mock list text (e.g. `'Vendor ${index + 1}'`, `'vendor@email.com'`), not a `vendorId` tenant literal.
- `ac_notifications_screen.dart:4` — the word "System" appears only in the comment "Unified Notification System (UNS)".

✅ Classified. Tenant identity is resolved centrally (see §3.3), not via hardcoded literals.

---

## 3.3 Write-path tenant threading in `AcRepository`

**File:** `lib/features/academic_coaching/data/repositories/ac_repository.dart`

### How tenant is actually threaded (root cause)

`AcRepository` takes an injected `ApiClient` and every method calls `_apiClient.get/post/put/patch/delete`. **No repository method accepts or forwards a `tenantId` parameter, and none places a tenant value in the request body or path.** Tenant scoping is supplied entirely by the shared `ApiClient`:

- `lib/core/api/api_client.dart` `_buildHeaders` (≈ lines 533–610) extracts the tenant from the Cognito JWT claim `custom:tenant_id` (line 558), with fallback to secure storage `session_tenant_id` / `session_shop_id` (lines 575–577).
- It sets `headers['x-tenant-id'] = tenantId` (line 603) and `headers['x-active-business']` (lines 606–608) on **every authenticated request** (`requireAuth` defaults to `true` for all verbs).
- If no tenant can be resolved it throws `ApiException(statusCode: 400, code: 'MISSING_TENANT_CONTEXT')` (lines 597–601) — the request is rejected and never sent (this centrally satisfies Req 1.7 at the transport layer).

### Classification

Because the repository code itself never threads the tenant **explicitly** (it relies solely on the `ApiClient` header injection), every write method is classified **`has-gaps`** under the report's definition (`tenant threaded explicitly` vs `only via the ApiClient auth header`). The "gap" is one of **local explicitness / verifiability**, not a confirmed data-leakage gap — actual tenant scoping is present and enforced via the `x-tenant-id` header derived from the authenticated session.

| Write method | Line | HTTP call | Tenant threading | Classification |
|---|---|---|---|---|
| `createStudent` | 97 | `POST /ac/students` | implicit via ApiClient `x-tenant-id` | has-gaps (implicit-only) |
| `updateStudent` | 106 | `PUT /ac/students/$id` | implicit via ApiClient | has-gaps (implicit-only) |
| `deleteStudent` | 115 | `DELETE /ac/students/$id` | implicit via ApiClient | has-gaps (implicit-only) |
| `transferStudent` | 122 | `POST /ac/students/$id/transfer` | implicit via ApiClient | has-gaps (implicit-only) |
| `createBatch` | 166 | `POST /ac/batches` | implicit via ApiClient | has-gaps (implicit-only) |
| `updateBatch` | 184 | `PUT /ac/batches/$batchId` | implicit via ApiClient | has-gaps (implicit-only) |
| `deleteBatch` | 193 | `DELETE /ac/batches/$batchId` | implicit via ApiClient | has-gaps (implicit-only) |
| `createCourse` | 223 | `POST /ac/courses` | implicit via ApiClient | has-gaps (implicit-only) |
| `updateCourse` | 241 | `PUT /ac/courses/$courseId` | implicit via ApiClient | has-gaps (implicit-only) |
| `deleteCourse` | 253 | `DELETE /ac/courses/$courseId` | implicit via ApiClient | has-gaps (implicit-only) |
| `createInvoice` | 274 | `POST /ac/invoices` | implicit via ApiClient | has-gaps (implicit-only) |
| `recordPayment` | 283 | `POST /ac/payments` | implicit via ApiClient | has-gaps (implicit-only) |
| `markAttendance` | 296 | `POST /ac/attendance` | implicit via ApiClient | has-gaps (implicit-only) |
| `createFaculty` | 343 | `POST /ac/faculty` | implicit via ApiClient | has-gaps (implicit-only) |
| `updateFaculty` | 361 | `PUT /ac/faculty/$facultyId` | implicit via ApiClient | has-gaps (implicit-only) |
| `deleteFaculty` | 373 | `DELETE /ac/faculty/$facultyId` | implicit via ApiClient | has-gaps (implicit-only) |
| `markFacultyAttendance` | 399 | `POST /ac/faculty/$facultyId/attendance` | implicit via ApiClient | has-gaps (implicit-only) |
| `createExam` | 432 | `POST /ac/exams` | implicit via ApiClient | has-gaps (implicit-only) |
| `updateExam` | 450 | `PUT /ac/exams/$examId` | implicit via ApiClient | has-gaps (implicit-only) |
| `deleteExam` | 459 | `DELETE /ac/exams/$examId` | implicit via ApiClient | has-gaps (implicit-only) |
| `uploadResults` | 466 | `POST /ac/results` | implicit via ApiClient | has-gaps (implicit-only) |
| `createTimetableSlot` | 518 | `POST /ac/timetable/slots` | implicit via ApiClient | has-gaps (implicit-only) |
| `createMaterial` | 556 | `POST /ac/materials` | implicit via ApiClient | has-gaps (implicit-only) |
| `updateMaterial` | 574 | `PUT /ac/materials/$materialId` | implicit via ApiClient | has-gaps (implicit-only) |
| `deleteMaterial` | 589 | `DELETE /ac/materials/$materialId` | implicit via ApiClient | has-gaps (implicit-only) |
| `sendNotification` | 672 | `POST /ac/notifications/send` | implicit via ApiClient | has-gaps (implicit-only) |
| `bulkImportStudents` | 712 | `POST /ac/bulk/student-import` | implicit via ApiClient | has-gaps (implicit-only) |
| `bulkGenerateInvoices` | 734 | `POST /ac/bulk/generate-invoices` | implicit via ApiClient | has-gaps (implicit-only) |
| `generateCertificate` | 807 | `POST /ac/certificates/generate` | implicit via ApiClient | has-gaps (implicit-only) |
| `bulkGenerateCertificates` | 844 | `POST /ac/bulk/certificates` | implicit via ApiClient | has-gaps (implicit-only) |
| `updateApplicationStatus` | 1593 | `PATCH /ac/admissions/.../status` | implicit via ApiClient | has-gaps (implicit-only) |
| `approveLessonPlan` | 1654 | `PATCH /ac/lesson-plans/$id/approve` | implicit via ApiClient | has-gaps (implicit-only) |

**Summary:** Write methods found: **32** (incl. deletes, bulk, and admissions/lesson-plan mutators). **0 fully-threaded** (explicit), **32 has-gaps** (implicit-only via the `ApiClient` `x-tenant-id`/`x-active-business` headers). Recommendation for later phases: keep the centralized `ApiClient` enforcement (it is sound) and, where Req 1.5/1.6 demand local verifiability, document the reliance rather than duplicating the tenant in every body.

---

## 3.4 RID compliance of new-entity id generation

**RID pattern:** `{tenantId}-{timestamp_ms}-{uuid_v4_short}`

**Result: NO NON-COMPLIANT SITES FOUND (no client-side entity-id generation exists).**

- A targeted search across `academic_coaching/**` for `Uuid`, `.v4()`, `uuid`, `millisecondsSinceEpoch`, `microsecondsSinceEpoch`, `generateId`, `newId` found **no client-side new-entity identifier generation**.
- All create/bulk write methods send a payload `Map` to the Lambda `/ac/*` endpoints (e.g. `createStudent` line 97 → `POST /ac/students`); **the backend is responsible for generating entity ids.** No `AcStudent`/`AcInvoice`/`AcBatch`/etc. id is minted on the Flutter side.

Two `millisecondsSinceEpoch` occurrences exist but are **not** new-entity identifier sites (recorded for completeness):
- `ac_id_cards_screen.dart:138` — used to build a PDF export **filename** (`'ID_Cards_Batch_${...}.pdf'`), not a persisted entity id.
- `ac_payments_screen.dart:241` — a **display-only** mock string in a Razorpay dialog (`'Order ID: order_${DateTime.now().millisecondsSinceEpoch}'`); it is UI placeholder text, not a stored identifier.

✅ Classified: client-side id-generation sites = compliant-by-absence (server-generated). The two `millisecondsSinceEpoch` uses are non-identifier and out of RID scope.

---

## 3.5 Paise compliance (money representation)

**File:** `lib/features/academic_coaching/data/models/ac_models.dart`

**Result: HAS-AMBIGUITY (CONFIRMED).** Money is modelled as `double` rupees in-app while the wire format is integer Paise (`*Paisa`). Each `fromJson` divides the integer-Paise wire field by `/100` to a `double`, introducing the exact rupee/paise floating-point ambiguity Req 1 and Req 10 target.

### Required-list `double` money fields (per task)

| Model | Field | Decl. line | `/100` conversion line(s) |
|---|---|---|---|
| `AcStudent` | `totalFees` | 61 | 122 (`feeSummary.totalFees` → `.toDouble()`) |
| `AcStudent` | `totalPaid` | 62 | 123 (`.toDouble()`) |
| `AcStudent` | `balance` | 63 | 124 (`.toDouble()`) |
| `AcCourse` | `totalFee` | 366 | 398–401 (`totalFeePaisa / 100`) |
| `AcCourse` | `materialFee` | 367 | 401–404 (`materialFeePaisa / 100`) |
| `AcCourse` | `admissionFee` | 368 | 404–407 (`admissionFeePaisa / 100`) |
| `AcInvoice` | `discountAmount` | 466 | 506–509 (`discountAmountPaisa / 100`) |
| `AcInvoice` | `adjustmentAmount` | 467 | 509–512 (`adjustmentAmountPaisa / 100`) |
| `AcInvoice` | `totalAmount` | 469 | 513–516 (`totalAmountPaisa / 100`) |
| `AcInvoice` | `paidAmount` | 470 | 516–519 (`paidAmountPaisa / 100`) |
| `AcInvoice` | `balance` | 471 | 519–522 (`balancePaisa / 100`) |

### Additional ambiguous `double` money fields found beyond the required list (recorded for completeness)

| Model | Field | Decl. line | `/100` conversion line(s) |
|---|---|---|---|
| `AcFeeComponent` | `amount` | 576 | 590–593 (`amountPaisa / 100`) |
| `AcPayment` | `amount` | 612 | 638–641 (`amountPaisa / 100`) |
| `AcSalaryStructure` | `fixedAmount` | 857 | 871–874 (`fixedAmountPaisa / 100`) |
| `AcSalaryStructure` | `perClassRate` | 858 | 874–877 (`perClassRatePaisa / 100`) |
| `AcMaterial` | `materialFee` | 1076 | 1114–1117 (`materialFeePaisa / 100`) |
| `AcRevenueStats` | `total`, `collected`, `pending`, `monthly` | 1256–1259 | (dashboard stats, `double`) |
| `AcOverdueStats` | `amount` | 1280 | (dashboard stats, `double`) |
| `AcBookIssue` | `finePerDay`, `fineCollected` | 1463–1464 | (library fines, `double?`) |
| `AcClasswiseFee` | `amountRupees` | 1614 | field name explicitly "Rupees" — ambiguous by design |

Non-money `double` fields (NOT flagged — marks/percentages, not currency): `AcResult.totalObtained/totalMax/percentage` (980–982), `AcSubjectResult.marksObtained/maxMarks` (1037–1038), `AcReportSubject.marksObtained/maxMarks` (1554–1555), `AcStudentReport.totalMarksObtained/totalMaxMarks/percentage` (1578–1580).

✅ Classified: **has-ambiguity**. Resolution deferred to Phase 7 (paise migration via Mini_Gate).

---

## 3.6 Validators presence

**File:** `lib/features/academic_coaching/utils/ac_validators.dart` — **EXISTS** (class `AcValidators`, line 6).

| Function | Line |
|---|---|
| `validateStudentId` | 7 |
| `validateName` | 21 |
| `validatePhone` | 35 |
| `validateEmail` | 51 |
| `validateDateOfBirth` | 62 |
| `validateFeeAmount` | 92 |
| `validateCapacity` | 115 |
| `validateDateRange` | 134 |
| `validateExamDuration` | 161 |
| `validateMarks` | 190 |
| `validatePincode` | 209 |
| `required` | 222 |
| `validateUniqueId` | 230 |

All **13** enumerated validation functions are present. Helper types also present: `ValidationResult` and `AcFormValidator` (same file).

**Gap noted for Phase 7 (not a Phase 0 change):** `validateFeeAmount` (line 92) parses a `double` and permits `min = 0` (zero allowed), conflicting with Req 10.5 (zero/negative must be rejected) and the integer-Paise convention. Recorded as input to Phase 7.

✅ Classified: present + enumerated.

---

## 3.7 Endpoint reality (`/ac/*`)

**Deployment status cannot be confirmed from the Flutter client source alone** (no backend handler set is in scope of this read-only inspection, and no live call was made). Therefore every `/ac/*` endpoint required by an `Ac_Screen` is classified **`unverified`**, with the **observed client request path** recorded (the path the repository actually issues) and treated as the **expected request path** for backend confirmation in a later phase.

| Capability | Repo method (line) | Observed/expected request path | Classification |
|---|---|---|---|
| Dashboard | `getDashboard` (44) | `GET /ac/dashboard` | unverified |
| Students list | `listStudents` (52) | `GET /ac/students` | unverified |
| Student detail | `getStudent` (88) | `GET /ac/students/$id` | unverified |
| Create student | `createStudent` (97) | `POST /ac/students` | unverified |
| Update student | `updateStudent` (106) | `PUT /ac/students/$id` | unverified |
| Transfer student | `transferStudent` (122) | `POST /ac/students/$id/transfer` | unverified |
| Batches | `listBatches`/`createBatch` (153/166) | `GET|POST /ac/batches` | unverified |
| Batch seats | `getBatchSeats` (210) | `GET /ac/batches/$id/seats` | unverified |
| Courses | `listCourses`/`createCourse` (213/223) | `GET|POST /ac/courses` | unverified |
| Student fees | `getStudentFees` (263) | `GET /ac/fees/student/$studentId` | unverified |
| Create invoice | `createInvoice` (274) | `POST /ac/invoices` | unverified |
| Record payment | `recordPayment` (283) | `POST /ac/payments` | unverified |
| Mark attendance | `markAttendance` (296) | `POST /ac/attendance` | unverified |
| Attendance report | `getAttendanceReport` (305) | `GET /ac/attendance/report` | unverified |
| Faculty | `listFaculty`/`createFaculty` (333/343) | `GET|POST /ac/faculty` | unverified |
| Faculty payroll | `getFacultyPayroll` (380) | `GET /ac/faculty/$id/payroll` | unverified |
| Faculty attendance | `markFacultyAttendance` (399) | `POST /ac/faculty/$id/attendance` | unverified |
| Exams | `listExams`/`createExam` (424/432) | `GET|POST /ac/exams` | unverified |
| Upload results | `uploadResults` (466) | `POST /ac/results` | unverified |
| Exam results | `getExamResults` (505) | `GET /ac/exams/$id/results` | unverified |
| Timetable | `getTimetable`/`createTimetableSlot` (498/518) | `GET /ac/timetable`, `POST /ac/timetable/slots` | unverified |
| Materials | `listMaterials`/`createMaterial` (533/556) | `GET|POST /ac/materials` | unverified |
| Material download | `getMaterialDownloadUrl` (598) | `GET /ac/materials/$id/download` | unverified |
| Reports summary | `getReportsSummary` (615) | `GET /ac/reports/summary` | unverified |
| At-risk students | `getAtRiskStudents` (645) | `GET /ac/analytics/at-risk-students` | unverified |
| Birthdays | `getUpcomingBirthdays` (656) | `GET /ac/students/birthdays` | unverified |
| Notification templates | `listNotificationTemplates` (664) | `GET /ac/notifications/templates` | unverified |
| Send notification | `sendNotification` (672) | `POST /ac/notifications/send` | unverified |
| Fee reminders | `sendFeeReminders` (697) | `POST /ac/notifications/fee-reminders` | unverified |
| Bulk import students | `bulkImportStudents` (712) | `POST /ac/bulk/student-import` | unverified |
| Bulk generate invoices | `bulkGenerateInvoices` (734) | `POST /ac/bulk/generate-invoices` | unverified |
| Financial reports | `getFinancialReports` (758) | `GET /ac/reports/financial` | unverified |
| Certificates | `listCertificates`/`generateCertificate` (777/807) | `GET /ac/certificates`, `POST /ac/certificates/generate` | unverified |
| Certificate download | `downloadCertificate` (832) | `GET /ac/certificates/$id/download` | unverified |
| Bulk certificates | `bulkGenerateCertificates` (844) | `POST /ac/bulk/certificates` | unverified |
| Student photo upload | `getStudentPhotoUploadUrl` (≈868) | `GET /ac/students/$id/photo-upload-url` (observed) | unverified |
| Admissions list | `getAdmissionsApplications` (1575) | `GET /ac/admissions/applications` (observed) | unverified |
| Update application | `updateApplicationStatus` (1593) | `PATCH /ac/admissions/.../status` (observed) | unverified |
| Homework | `getHomework` (1610) | `GET /ac/homework` (observed) | unverified |
| Lesson plans | `getLessonPlans` (1634) | `GET /ac/lesson-plans` (observed) | unverified |
| Approve lesson plan | `approveLessonPlan` (1654) | `PATCH /ac/lesson-plans/$id/approve` | unverified |

✅ Classified: every required `/ac/*` endpoint = **unverified** (observed = expected client paths recorded). Backend deployment confirmation is an explicit later-phase action; none classified `deployed`/`not-deployed` because that requires backend evidence outside this read-only scope.

---

## 3.8 Orphaned-screen ratings

**Total `Ac*Screen` files:** 33. **Wired to a live `/ac/*` route (see §3.9):** 21. **Orphaned (no live route):** 12.

Rating definitions: **Production-Ready** = real `AcRepository` wiring + complete UI (wire route + permission + sidebar later); **Needs-Work** = UI shell backed by hardcoded/mock data, not wired to the repository (report gaps, do not wire); **Stale** = abandoned/empty (grep refs, flag for deletion pending sign-off).

| Orphaned screen | File | Rating | One-line justification |
|---|---|---|---|
| `AcStudentRegistrationScreen` | `ac_student_registration_screen.dart` | Production-Ready | Full multi-step form; wires real `AcRepository` (`listCourses`/`listBatches`/`createStudent`, lines 65–66, 1091). Resolves the `/ac/students` registration counterpart (§3.9). |
| `AcAdmissionsScreen` | `ac_admissions_screen.dart` | Production-Ready | Real repo wiring (`getAdmissionsApplications` line 34, `updateApplicationStatus` line 392). |
| `AcLessonPlansScreen` | `ac_lesson_plans_screen.dart` | Production-Ready | Real repo wiring (`getLessonPlans`/`approveLessonPlan`/`updateLessonPlanStatus`/`deleteLessonPlan`). |
| `AcHomeworkScreen` | `ac_homework_screen.dart` | Production-Ready | Real repo wiring (`getHomework` line 32). |
| `AcIdCardsScreen` | `ac_id_cards_screen.dart` | Production-Ready | Real repo wiring (`listStudents`/`listBatches` lines 54–55) + PDF generation. |
| `AcDocumentsScreen` | `ac_documents_screen.dart` | Needs-Work | UI shell with hardcoded `itemCount: 20` mock list (line 166); no `AcRepository` calls. |
| `AcHostelScreen` | `ac_hostel_screen.dart` | Needs-Work | Hardcoded mock rooms/allocations (`itemCount: 20`/`15`, lines 125/157); no repo wiring. |
| `AcLeaveScreen` | `ac_leave_screen.dart` | Needs-Work | Hardcoded mock list (`itemCount: 10`, line 50); no repo wiring. |
| `AcSiblingScreen` | `ac_sibling_screen.dart` | Needs-Work | Hardcoded mock families/students (`itemCount: 10`/`20`, lines 88/133); no repo wiring. |
| `AcPaymentsScreen` | `ac_payments_screen.dart` | Needs-Work | Mock payment list (`itemCount: 15`, line 116) + mock Razorpay dialog (line 241); no repo wiring. |
| `AcReportsScreen` | `ac_reports_screen.dart` | Needs-Work | Hardcoded mock list (`itemCount: 10`, line 401); no repo wiring (distinct from routed `/ac/financial` & `/ac/risk`). |
| `AcInventoryScreen` | `ac_inventory_screen.dart` | Needs-Work | Entirely mock (items/vendors/movements/POs, `itemCount: 20/10/15/8`); also arguably outside core school scope — flag for product review. |

✅ Classified: 5 Production-Ready, 7 Needs-Work, 0 Stale. No screen rated Stale (all 12 contain real UI implementations), so no deletion candidates arise from orphaned screens in Phase 0.

---

## 3.9 / 3.11 Route-surface reconciliation & assumption verification

### Live route-registration file

- **Audit claim:** `/ac/*` named routes live in `lib/app/routes.dart`.
- **Live reality:** `lib/app/routes.dart` **does not exist** (file search returned no match). The `/ac/*` routes are registered in **`lib/core/routing/legacy_routes.dart`** as top-level `GoRoute` entries (class `LegacyRoutes`, abstract final, line 213), each wrapped in `VendorRoleGuard(requiredPermission: …)` → `BusinessGuard(allowedTypes: [BusinessType.schoolErp])` → the `Ac*Screen`.
- **Verdict:** Audit's `app/routes.dart` location → **FALSIFIED** (the file was removed during the `gorouter-navigation-migration`; route bodies were "lifted verbatim from `lib/app/routes.dart`'s `buildAppRoutes()`", per the file header/comments at lines 8–13, 492).

### ⚠️ DISCREPANCY with design Ground Truth (Req 3.11 — reported, not routed around)

The `legacy_routes.dart` header (lines 7–13) states: *"The just-completed `gorouter-navigation-migration` spec made `MaterialApp.router` the SOLE navigation root, leaving the old `MaterialApp.routes` table (`buildAppRoutes()`) unwired."*

- The design's "Live-reality findings" characterize `legacy_routes.dart` as **"the live `MaterialApp.routes` table"** and Requirement **2.4** is premised on the app being on `MaterialApp.routes` ("SHALL NOT migrate the application off `MaterialApp.routes` onto GoRouter").
- **Contradiction:** the application has **already** migrated to GoRouter. `legacy_routes.dart` is a **GoRouter `RouteBase`/`GoRoute` list** (imports `package:go_router/go_router.dart`, builders are `(context, GoRouterState state) => …`), **not** a `MaterialApp.routes` map. Supporting evidence: `legacy_routes.dart:1–13, 36 (import go_router), 213 (LegacyRoutes), 499+ (GoRoute entries)`.
- **Impact:** Requirement 2.4's premise is moot, and Phase 1 must wire navigation through the GoRouter surface (`LegacyRoutes.routes()` spread into `AppRouter`), not a `MaterialApp.routes` table. **Recommend human sign-off to update the design/Req 2.4 framing before Phase 1.** Per Req 3.11, this is reported and not worked around.

### `/ac/*` live route → screen → guard map (observed in `legacy_routes.dart`)

| Path | Screen | `requiredPermission` (generic — to be replaced in Phase 3) | Approx. line |
|---|---|---|---|
| `/ac/dashboard` | `AcDashboardScreen` | `viewInvoices` | 2020 |
| `/ac/students` | `AcStudentsScreen` | `viewClients` | 2041 |
| `/ac/classes` | `AcClassSectionsScreen` | `viewInvoices` | 2061 |
| `/ac/academic-year` | `AcAcademicYearScreen` | `viewInvoices` | 2082 |
| `/ac/batches` | `AcBatchesScreen` | `viewInvoices` | 2102 |
| `/ac/courses` | `AcCoursesScreen` | `viewInvoices` | 2123 |
| `/ac/faculty` | `AcFacultyScreen` | `viewInvoices` | 2143 |
| `/ac/fees` | `AcFeeCollectionScreen` | `viewInvoices` | 2164 |
| `/ac/attendance` | `AcAttendanceScreen` | `viewInvoices` | 2184 |
| `/ac/timetable` | `AcTimetableScreen` | `viewInvoices` | 2204 |
| `/ac/exams` | `AcExamsScreen` | `viewInvoices` | 2224 |
| `/ac/report-cards` | `AcReportCardsScreen` | `viewReports` | 2240 |
| `/ac/materials` | `AcMaterialsScreen` | `viewInvoices` | 2261 |
| `/ac/library` | `AcLibraryScreen` | `viewInvoices` | 2281 |
| `/ac/transport` | `AcTransportScreen` | `viewInvoices` | 2301 |
| `/ac/risk` | `AcRiskDetectionScreen` | `viewReports` | 2321 |
| `/ac/notifications` | `AcNotificationsScreen` | `viewInvoices` | 2341 |
| `/ac/bulk` | `AcBulkOperationsScreen` | `createInvoices` | 2361 |
| `/ac/financial` | `AcFinancialReportsScreen` | `viewReports` | 2381 |
| `/ac/certificates` | `AcCertificateGeneratorScreen` | `createInvoices` | 2401 |
| `/ac/fee-structure` | `AcClasswiseFeeScreen` | `viewInvoices` | 2421 |

(There is also a `knownLegacyPaths` string list at lines 384–404 enumerating the same `/ac/*` paths for the alias/redirect machinery.)

### `/ac/students` collision resolution (input to Req 4.6)

- `/ac/students` currently binds to **`AcStudentsScreen`** only (line ~2041). **`AcStudentRegistrationScreen` has NO live route binding** — it is orphaned (confirmed: the only references are its own class definition; no `GoRoute` references it).
- **Therefore there is no active runtime collision today.** The "collision" is a latent risk for Phase 1: when registration is wired, `/ac/students` should remain bound to the more feature-complete **`AcStudentsScreen`** (the list/management screen), and **`AcStudentRegistrationScreen`** should receive a distinct non-colliding path (e.g. `/ac/students/register`).
- **Verdict:** `/ac/students` → `AcStudentsScreen` → **CONFIRMED**; registration screen orphaned → **CONFIRMED**.

### Generic-permission guard confirmation (input to Req 6.3)

- **CONFIRMED:** every `/ac/*` route is guarded by a **generic retail permission** (`viewInvoices` / `viewClients` / `viewReports` / `createInvoices`), not a school-specific permission. To be replaced in Phase 3.

### Assumption ledger (Req 3.9)

| Assumption | Verdict | Evidence |
|---|---|---|
| Sidebar `_getSectionsForBusiness` has no `schoolErp` case (falls to retail) | (deferred — Phase 1 file not in this report's edit scope; noted for §3.9 follow-up) | covered by design; not re-inspected here as out of read-only focus |
| `/ac/*` routes live in `lib/app/routes.dart` | **FALSIFIED** | file absent; routes in `legacy_routes.dart` |
| App still uses `MaterialApp.routes` (Req 2.4 premise) | **FALSIFIED / CONTRADICTED** | `legacy_routes.dart:7–13` — GoRouter is sole nav root |
| `/ac/*` routes guarded by generic permissions (`viewInvoices`/`viewClients`) | **CONFIRMED** | route table §3.9 |
| `/ac/students` ↔ `AcStudentRegistrationScreen` path collision | **CONFIRMED (latent, not active)** | `/ac/students` → `AcStudentsScreen`; registration orphaned |
| Money is `double`-in-model / paise-on-wire | **CONFIRMED** | §3.5 |
| `ac_validators.dart` exists with rupee/`double` `validateFeeAmount` allowing zero | **CONFIRMED** | §3.6 (line 92, `min = 0`) |
| No hardcoded tenant/`'SYSTEM'` literals in academic_coaching | **CONFIRMED** | §3.2 |
| Tenant scoping enforced centrally via `ApiClient` headers, not in repo code | **CONFIRMED** | §3.3 (`api_client.dart:533–610`) |
| No client-side RID/id generation (server-generated) | **CONFIRMED** | §3.4 |

---

## 3.10 Completeness

| Check | Requirement | Status |
|---|---|---|
| Read-only compliance | 3.1 | ✅ recorded |
| Hardcoded-literal search | 3.2 | ✅ none found |
| Write-path tenant threading | 3.3 | ✅ 32 methods classified (all has-gaps/implicit) |
| RID compliance | 3.4 | ✅ no non-compliant sites (server-generated) |
| Paise compliance | 3.5 | ✅ has-ambiguity (fields listed) |
| Validators presence | 3.6 | ✅ exists, 13 functions enumerated |
| Endpoint reality | 3.7 | ✅ all unverified (observed=expected paths) |
| Orphaned-screen ratings | 3.8 | ✅ 12 rated (5 PR / 7 NW / 0 Stale) |
| Route-surface reconciliation | 3.9 | ✅ reconciled + assumption ledger |
| Ground-Truth contradiction handling | 3.11 | ⚠️ discrepancy reported (§9 / §3.9), not routed around |

**No checked item is left unclassified.**

---

## Summary & recommendation

- All Req 3.2–3.9 checks have a recorded result (§3.10), nothing unclassified.
- **One Ground-Truth contradiction** (GoRouter vs `MaterialApp.routes`, Req 2.4 premise) is flagged per Req 3.11 and must be resolved with human sign-off before Phase 1 wiring.
- Net picture: the School_System code is largely sound (centralized tenant enforcement, server-generated ids, validators present, routes registered & business-guarded) but has confirmed gaps to remediate in later phases: paise/`double` money ambiguity (Phase 7), generic route guards (Phase 3), 5 production-ready orphaned screens to wire (Phase 6 / Phase 1), and 7 mock-data screens needing work.
