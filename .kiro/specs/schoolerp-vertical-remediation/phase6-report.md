# Phase 6 — Orphaned Screen Disposition Report

**Spec:** `schoolerp-vertical-remediation`
**Phase:** 6 — Orphaned Screen Disposition
**Requirements covered:** 9.1, 9.2, 9.3, 9.4, 9.5, 9.6

---

## Summary

- **Production-Ready screens:** 5 (wired in task 13.1)
- **Needs-Work screens:** 7 (gaps recorded below — no route, guard, or sidebar entry added per Req 9.3)
- **Stale screens:** 0 (no deletion candidates)

---

## Needs-Work Screen Dispositions (Req 9.3)

Per Requirement 9.3: each screen's specific gaps are recorded as discrete items. No route, guard, or sidebar entry is added for any Needs-Work screen.

### 1. `AcDocumentsScreen`

- **File:** `lib/features/academic_coaching/presentation/screens/ac_documents_screen.dart`
- **Rating:** Needs-Work
- **Gaps:**
  1. **No AcRepository wiring** — screen does not import or call any `AcRepository` method; document CRUD is entirely absent from the data layer.
  2. **Hardcoded mock list** — uses `itemCount: 20` (line 166) to render placeholder document cards with fabricated data.
  3. **No backend endpoint** — `AcRepository` has no `/ac/documents` endpoint; document upload/download/list APIs do not exist.
  4. **No file storage integration** — upload button exists in UI shell but is not connected to S3/presigned-URL flow or any storage service.

### 2. `AcHostelScreen`

- **File:** `lib/features/academic_coaching/presentation/screens/ac_hostel_screen.dart`
- **Rating:** Needs-Work
- **Gaps:**
  1. **No AcRepository wiring** — screen does not import or call any `AcRepository` method; hostel data is entirely local mock.
  2. **Hardcoded mock rooms** — uses `itemCount: 20` (line 125) for rooms list with fabricated room numbers/capacities.
  3. **Hardcoded mock allocations** — uses `itemCount: 15` (line 157) for allocation list with fabricated student-to-room assignments.
  4. **No backend endpoint** — `AcRepository` has no `/ac/hostels` or `/ac/hostel-allocations` endpoint.
  5. **No allocation/vacancy model** — no data model exists for hostel rooms, beds, or student-room mappings.

### 3. `AcLeaveScreen`

- **File:** `lib/features/academic_coaching/presentation/screens/ac_leave_screen.dart`
- **Rating:** Needs-Work
- **Gaps:**
  1. **No AcRepository wiring** — screen does not import or call any `AcRepository` method; leave data is entirely local mock.
  2. **Hardcoded mock list** — uses `itemCount: 10` (line 50) for leave applications with fabricated dates/statuses.
  3. **No backend endpoint** — `AcRepository` has no `/ac/leaves` endpoint for leave application CRUD or approval workflow.
  4. **No leave model** — no data model exists for leave types, leave balances, or approval chains.

### 4. `AcSiblingScreen`

- **File:** `lib/features/academic_coaching/presentation/screens/ac_sibling_screen.dart`
- **Rating:** Needs-Work
- **Gaps:**
  1. **No AcRepository wiring** — screen does not import or call any `AcRepository` method; family/sibling data is entirely local mock.
  2. **Hardcoded mock families** — uses `itemCount: 10` (line 88) for family groups with fabricated names.
  3. **Hardcoded mock students** — uses `itemCount: 20` (line 133) for student-within-family list with fabricated data.
  4. **No backend endpoint** — `AcRepository` has no `/ac/siblings` or `/ac/families` endpoint for sibling linking or family-group management.
  5. **No sibling-discount model** — discount info card references sibling-discount logic that has no data-layer backing.

### 5. `AcPaymentsScreen`

- **File:** `lib/features/academic_coaching/presentation/screens/ac_payments_screen.dart`
- **Rating:** Needs-Work
- **Gaps:**
  1. **No AcRepository wiring** — screen does not import or call any `AcRepository` method; payment data is entirely local mock.
  2. **Mock payment list** — uses `itemCount: 15` (line 116) with fabricated payment records.
  3. **Mock Razorpay dialog** — the "Collect Payment" flow (line 241) renders a simulated Razorpay integration with a fabricated `Order ID: order_${DateTime.now().millisecondsSinceEpoch}`; no actual Razorpay SDK integration.
  4. **No backend endpoint** — while `AcRepository.recordPayment` exists (POST `/ac/payments`), this screen does not invoke it; it uses its own mock flow.
  5. **No payment-gateway integration** — no Razorpay/payment-gateway SDK dependency or configuration wired to this screen.

### 6. `AcReportsScreen`

- **File:** `lib/features/academic_coaching/presentation/screens/ac_reports_screen.dart`
- **Rating:** Needs-Work
- **Gaps:**
  1. **No AcRepository wiring** — screen does not import or call any `AcRepository` method; report data is entirely local mock. (Note: this is distinct from the routed `/ac/financial` → `AcFinancialReportsScreen` and `/ac/risk` → `AcRiskDetectionScreen` which ARE repo-wired.)
  2. **Hardcoded mock list** — uses `itemCount: 10` (line 401) for generated reports with fabricated content.
  3. **No report-generation backend** — while `AcRepository.getReportsSummary` and `getFinancialReports` exist, this custom-reports screen does not invoke them; it has its own hardcoded template list and mock generation flow.
  4. **No export/download integration** — report generation and PDF/CSV export buttons are UI-only shells.

### 7. `AcInventoryScreen`

- **File:** `lib/features/academic_coaching/presentation/screens/ac_inventory_screen.dart`
- **Rating:** Needs-Work
- **Gaps:**
  1. **No AcRepository wiring** — screen does not import or call any `AcRepository` method; all inventory data is local mock.
  2. **Entirely mock data across all tabs** — Items (`itemCount: 20`), Vendors (`itemCount: 10`), Movements (`itemCount: 15`), Purchase Orders (`itemCount: 8`) are all hardcoded.
  3. **No backend endpoint** — `AcRepository` has no `/ac/inventory` or related endpoints.
  4. **No inventory model** — no data model exists for inventory items, stock movements, vendors, or purchase orders.
  5. **Arguably outside core school scope** — inventory/asset management is a shared concern that may belong to a platform-level capability rather than the school vertical specifically. Flagged for product review.

---

## Stale Screen Dispositions (Req 9.4, 9.5)

**Result: ZERO Stale screens identified in Phase 0.**

Per the Phase 0 Verification Report (§3.8), all 12 orphaned screens contain real UI implementations (either Production-Ready with repo wiring, or Needs-Work with complete UI shells backed by mock data). No screen was rated Stale (abandoned/empty). Therefore:

- No reference search is required (Req 9.4 applies only to Stale-rated screens).
- No deletion flag is required (Req 9.5 applies only to Stale-rated screens).
- No screen is flagged for deletion in this phase.

---

## Disposition Summary Table

| Screen | File | Rating | Action Taken |
|--------|------|--------|--------------|
| `AcDocumentsScreen` | `ac_documents_screen.dart` | Needs-Work | Gaps recorded (4 items); no wiring |
| `AcHostelScreen` | `ac_hostel_screen.dart` | Needs-Work | Gaps recorded (5 items); no wiring |
| `AcLeaveScreen` | `ac_leave_screen.dart` | Needs-Work | Gaps recorded (4 items); no wiring |
| `AcSiblingScreen` | `ac_sibling_screen.dart` | Needs-Work | Gaps recorded (5 items); no wiring |
| `AcPaymentsScreen` | `ac_payments_screen.dart` | Needs-Work | Gaps recorded (5 items); no wiring |
| `AcReportsScreen` | `ac_reports_screen.dart` | Needs-Work | Gaps recorded (4 items); no wiring |
| `AcInventoryScreen` | `ac_inventory_screen.dart` | Needs-Work | Gaps recorded (5 items); no wiring |

---

## Files created/modified/deleted by this task

| Action | File |
|--------|------|
| Created | `.kiro/specs/schoolerp-vertical-remediation/phase6-report.md` (this file) |

No application source, configuration, or build files were created, modified, or deleted.
