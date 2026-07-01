# Phase 2 Report — Dashboard, Quick Actions, and Alerts with Real Data

## Summary

Phase 2 wired schoolErp-specific quick actions, real-data alerts, and enhanced KPI states
into the Dashboard V2 widgets. Four tasks were completed (5.1, 5.2, 5.3, 5.4) touching
three files. No files were created or deleted in application source. Zero errors, zero
warnings from `flutter analyze`.

---

## Files Modified

| File | Task | Change Summary | Requirements |
|------|------|---------------|--------------|
| `lib/features/dashboard/v2/widgets/business_quick_actions.dart` | 5.1 | Added `case BusinessType.schoolErp:` with 4 quick actions (Collect Fee → `/ac/fees`, New Admission → `/ac/students/register`, Mark Attendance → `/ac/attendance`, Enter Marks → `/ac/exams`) | 5.1, 5.10 |
| `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` | 5.2, 5.4 | Added `SchoolAlertSnapshot` class, `schoolAlertCountsProvider` (StreamProvider with UNS WebSocket subscription + tenant filtering), `case BusinessType.schoolErp:` in `_getTitle` ("School Alerts") and `_buildAlertsForBusiness` with 3 real-data alerts (Fees Due, Absentees Today, Upcoming Exams), `_kSchoolAlertEvents` constant | 5.2, 5.3, 5.5, 5.6, 5.10 |
| `lib/features/academic_coaching/presentation/screens/ac_dashboard_screen.dart` | 5.3 | Enhanced loading/empty/error states: `_buildSkeletonLoader()` for loading, `_isDashboardEmpty()` + KPI empty-state display for zero-data, `_buildError()` with retry for query failure | 5.4, 5.7, 5.8, 5.9 |

### Files Created

| File | Purpose |
|------|---------|
| `.kiro/specs/schoolerp-vertical-remediation/phase2-report.md` | This Phase_Report |

### Files Deleted

None.

---

## Task 5.1 — schoolErp Quick-Action Case

### Change

In `lib/features/dashboard/v2/widgets/business_quick_actions.dart`:
- Added `case BusinessType.schoolErp:` in `_buildActionsForBusiness` (line 510).
- Presents exactly **four** actions:

| # | Icon | Label | Navigation | Screen Target |
|---|------|-------|-----------|---------------|
| 1 | `Icons.payments_outlined` | Collect Fee | `context.push('/ac/fees')` | `AcFeeCollectionScreen` |
| 2 | `Icons.person_add_outlined` | New Admission | `context.push('/ac/students/register')` | `AcStudentRegistrationScreen` |
| 3 | `Icons.fact_check_outlined` | Mark Attendance | `context.push('/ac/attendance')` | `AcAttendanceScreen` |
| 4 | `Icons.grade_outlined` | Enter Marks | `context.push('/ac/exams')` | `AcExamsScreen` |

Each navigates to an existing `Ac_Screen` widget via the GoRouter paths established in Phase 1.

---

## Task 5.2 — schoolErp Alerts Case Backed by Real Tenant-Scoped Queries

### Change

In `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`:

1. **`SchoolAlertSnapshot` class** — immutable data class holding three independently-fetched metrics:
   - `feesDue` (int) + `feesDueAvailable` (bool)
   - `absenteesToday` (int) + `absenteesTodayAvailable` (bool)
   - `upcomingExams` (int) + `upcomingExamsAvailable` (bool)

2. **`schoolAlertCountsProvider`** (StreamProvider) — fetches all three metrics from `AcRepository`:
   - Fees Due: from `repo.getReportsSummary(type: 'fee')` → extracts `pendingCount`/`dueCount`/`totalDueStudents`
   - Absentees Today: from `repo.getAttendanceReport(fromDate: today, toDate: today)` → extracts `absentCount`/`absentees`
   - Upcoming Exams: from `repo.listExams()` → filters for `date >= today && isScheduled`

3. **`case BusinessType.schoolErp:` in `_getTitle`** → returns `'School Alerts'`

4. **`case BusinessType.schoolErp:` in `_buildAlertsForBusiness`** → renders three alert tiles:
   - Fees Due (icon: `Icons.payments_outlined`, color: warning)
   - Absentees Today (icon: `Icons.person_off_outlined`, color: error)
   - Upcoming Exams (icon: `Icons.event_note_outlined`, color: info)

**No hardcoded count** — every count derives from a live query result. On retrieval failure, the metric shows an error indication, not a fabricated default.

---

## Task 5.3 — KPI Cards with Loading/Empty/Error States

### Change

In `lib/features/academic_coaching/presentation/screens/ac_dashboard_screen.dart`:

1. **Loading state** (`_buildSkeletonLoader()`):
   - Renders a 6-card grid of skeleton containers, each with a `CircularProgressIndicator`
   - Displays "Loading dashboard..." text below the grid
   - Triggered while `acDashboardProvider` is in the `AsyncLoading` state (Req 5.8)

2. **Empty state** (`_isDashboardEmpty()` + KPI section):
   - When all KPIs are zero (query returned data but no school activity), shows `'—'` for values and `'No data yet'` for subtitles
   - Displays a contextual banner: "No school activity recorded yet" (Req 5.7)
   - Non-negative integers: the check returns `true` only when all counts are exactly zero

3. **Error state** (`_buildError()`):
   - Displays error icon, "Failed to load dashboard" title, error message, and a Retry button
   - Retry invalidates `acDashboardProvider` to re-fetch (Req 5.9)
   - Never shows a fabricated count on failure

---

## Task 5.4 — WebSocket Consumer Mirroring `inventory.*` Pattern

### Change

In `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`:

1. **`_kSchoolAlertEvents` constant** — set of three event names:
   - `'school.fee.due'`
   - `'school.attendance.marked'`
   - `'school.exam.result'`

2. **UNS stream subscription** in `schoolAlertCountsProvider`:
   - After initial fetch, subscribes to `sdk.onNotification()`
   - Filters to only `_kSchoolAlertEvents` (ignores unrelated traffic)
   - **Tenant isolation (Req 5.6):** extracts `tenantId`/`tenant_id`/`userId`/`user_id` from `delivery.payload`; if it differs from `activeTenantId`, the event is ignored and nothing updates
   - On matching event: re-fetches all three school counts and yields updated snapshot

3. **Legacy fallback** — when UNS SDK not yet registered, listens to `EventDispatcher.whereAny([BusinessEvent.stockChanged])` as a generic refresh signal, gated by `session.activeBusinessType == BusinessType.schoolErp`

---

## Checkpoint — Phase 2 (Task 6)

### 1. `flutter analyze` Results

```
Analyzing 3 items...
No issues found! (ran in 2.9s)
```

| File | Errors | Warnings | Info |
|------|--------|----------|------|
| `lib/features/dashboard/v2/widgets/business_quick_actions.dart` | 0 | 0 | 0 |
| `lib/features/dashboard/v2/widgets/business_alerts_widget.dart` | 0 | 0 | 0 |
| `lib/features/academic_coaching/presentation/screens/ac_dashboard_screen.dart` | 0 | 0 | 0 |
| **Total** | **0** | **0** | **0** |

### 2. Shared_Component Blast Radius

**Confirmed: The `schoolErp` case is additive and no other business type's quick actions or alerts changed.**

Evidence for `business_quick_actions.dart`:
- The `case BusinessType.schoolErp:` is a standalone case that was inserted between `service` and `clinic`.
- All other `case` branches (grocery, pharmacy, restaurant, clothing, electronics, mobileShop, computerShop, hardware, petrolPump, bookStore, autoParts, wholesale, decorationCatering, vegetablesBroker, jewellery, service, clinic) are byte-for-byte unchanged.
- The `default:` branch (generic "Add Customer" + "Reports") is unchanged.
- The common leading action (`New Sale`) and trailing action (`Alerts`) are unchanged.

Evidence for `business_alerts_widget.dart`:
- The `case BusinessType.schoolErp:` was added in both `_getTitle` and `_buildAlertsForBusiness` as a standalone case.
- `SchoolAlertSnapshot` and `schoolAlertCountsProvider` are new additions — they do not modify any existing provider (`alertCountsProvider`, `mandiAlertCountsProvider`, `dcAlertCountsProvider`, `jewelleryAlertCountsProvider`, `mobileShopKpiProvider`, `hardwareKpisProvider`).
- The `_kSchoolAlertEvents` constant is new — it does not modify `_kInventoryAlertEvents`.
- All other `case` branches in `_getTitle` and `_buildAlertsForBusiness` are unchanged.

Evidence for `ac_dashboard_screen.dart`:
- This file is solely within the `features/academic_coaching/` scope — it is not a Shared_Component and cannot affect other verticals.

### 3. Per-Vertical Regression Result

| Business Type | Quick Actions | Alerts Widget | Dashboard | Result |
|---------------|:-------------:|:-------------:|:---------:|:------:|
| clinic | unchanged | unchanged | N/A | ✓ PASS |
| pharmacy | unchanged | unchanged | N/A | ✓ PASS |
| restaurant | unchanged | unchanged | N/A | ✓ PASS |
| petrolPump | unchanged | unchanged | N/A | ✓ PASS |
| electronics | unchanged | unchanged | N/A | ✓ PASS |
| computerShop | unchanged | unchanged | N/A | ✓ PASS |
| mobileShop | unchanged | unchanged | N/A | ✓ PASS |
| service | unchanged | unchanged | N/A | ✓ PASS |
| hardware | unchanged | unchanged | N/A | ✓ PASS |
| vegetablesBroker | unchanged | unchanged | N/A | ✓ PASS |
| decorationCatering | unchanged | unchanged | N/A | ✓ PASS |
| jewellery | unchanged | unchanged | N/A | ✓ PASS |
| clothing | unchanged | unchanged | N/A | ✓ PASS |
| grocery (default) | unchanged | unchanged | N/A | ✓ PASS |
| wholesale (default) | unchanged | unchanged | N/A | ✓ PASS |
| bookStore (default) | unchanged | unchanged | N/A | ✓ PASS |
| autoParts (default) | unchanged | unchanged | N/A | ✓ PASS |
| other (default) | unchanged | unchanged | N/A | ✓ PASS |

**All non-school verticals: PASS — zero changes to their quick-action set, alert set, or dashboard behavior.**

### 4. Requirement Traceability

| Requirement | Status | Evidence |
|-------------|--------|----------|
| 5.1 | ✓ Met | Exactly 4 quick actions: Collect Fee, New Admission, Mark Attendance, Enter Marks — each wired to an existing `Ac_Screen` |
| 5.2 | ✓ Met | 3 alerts (Fees Due, Absentees Today, Upcoming Exams) backed by real `AcRepository` queries |
| 5.3 | ✓ Met | No hardcoded count in any schoolErp alert; all counts from live query results |
| 5.4 | ✓ Met | KPI cards from `AcRepository.getDashboard()` — non-negative integers from tenant-scoped query |
| 5.5 | ✓ Met | `schoolAlertCountsProvider` subscribes to UNS `school.fee.due`, `school.attendance.marked`, `school.exam.result` events |
| 5.6 | ✓ Met | Events with differing `tenantId` are ignored — nothing updates |
| 5.7 | ✓ Met | Zero/empty-state indicator when query returns no data (`_isDashboardEmpty()` → "No data yet") |
| 5.8 | ✓ Met | Loading indicator (`_buildSkeletonLoader()`) while query is in progress |
| 5.9 | ✓ Met | Error indication (`_buildError()`) on query failure with Retry — never a fabricated count |
| 5.10 | ✓ Met | Changes additive within `schoolErp` case; no other business type's action set or alert set changed |

---

## Conclusion

Phase 2 is complete. All four tasks (5.1, 5.2, 5.3, 5.4) are implemented. `flutter analyze`
reports 0 errors and 0 warnings across all touched files. The Shared_Component blast radius
is confined to the `schoolErp` case only. All other verticals are unaffected. No hardcoded
counts exist in any school branch — every metric derives from a live tenant-scoped query.
