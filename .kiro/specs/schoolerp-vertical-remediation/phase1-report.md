# Phase 1 Report — Routing and Navigation Wiring

## Summary

Phase 1 wired the existing `Ac*Screen` widgets into the live schoolErp navigation surface.
Three tasks were completed (3.1, 3.2, 3.3) touching three files. No files were created or
deleted in application source. Zero errors, zero warnings from `flutter analyze`.

---

## Files Modified

| File | Task | Change Summary | Requirements |
|------|------|---------------|--------------|
| `lib/widgets/desktop/sidebar_configuration.dart` | 3.1 | Added `case BusinessType.schoolErp: return _getSchoolSections();` + the `_getSchoolSections()` function (15 items across 12 sections) | 4.1, 4.2, 4.3, 4.10, 1.11, 1.12 |
| `lib/widgets/desktop/sidebar_navigation_handler.dart` | 3.2 | Added 15 `case 'school_*':` branches mapping item ids to existing `Ac_Screen` widgets | 4.4, 4.5 |
| `lib/core/routing/legacy_routes.dart` | 3.3 | Added `/ac/students/register` GoRoute for `AcStudentRegistrationScreen`, alignment comments, navItems redundancy flag | 4.6, 4.7, 4.8, 4.9 |

### Files Created

| File | Purpose |
|------|---------|
| `.kiro/specs/schoolerp-vertical-remediation/phase1-report.md` | This Phase_Report |

### Files Deleted

None.

---

## Task 3.1 — `_getSchoolSections()` and explicit `case BusinessType.schoolErp`

### Change

In `lib/widgets/desktop/sidebar_configuration.dart`:
- Added `case BusinessType.schoolErp: return _getSchoolSections();` in the `_getSectionsForBusiness` switch (line 203).
- Added the `_getSchoolSections()` function (line 2337) returning 15 school-specific items across 12 sections:

| Section | Item ID | Label | Screen | Capability Gate |
|---------|---------|-------|--------|-----------------|
| Dashboard | `school_dashboard` | Dashboard | `AcDashboardScreen` | `useDailySnapshot` |
| Students & Admissions | `school_students` | Students | `AcStudentsScreen` | `useStudentRegistry` |
| Students & Admissions | `school_classes` | Classes & Sections | `AcClassSectionsScreen` | `useStudentRegistry` |
| Fees | `school_fees` | Fee Collection | `AcFeeCollectionScreen` | `useFeeCollection` |
| Fees | `school_fee_structure` | Classwise Fee Structure | `AcClasswiseFeeScreen` | `useFeeCollection` |
| Attendance | `school_attendance` | Attendance | `AcAttendanceScreen` | `useAttendanceTracking` |
| Exams & Report Cards | `school_exams` | Exams | `AcExamsScreen` | `useTestResults` |
| Exams & Report Cards | `school_report_cards` | Report Cards | `AcReportCardsScreen` | `useTestResults` |
| Timetable | `school_timetable` | Timetable | `AcTimetableScreen` | `useTimetable` |
| Faculty | `school_faculty` | Faculty | `AcFacultyScreen` | `useStaffManagement` |
| Transport | `school_transport` | Transport | `AcTransportScreen` | `useStudentRegistry` |
| Library | `school_library` | Library | `AcLibraryScreen` | `useStudentRegistry` |
| Communication | `school_notifications` | Notifications | `AcNotificationsScreen` | `useParentNotifications` |
| Reports | `school_reports` | Reports | `AcReportsScreen` | `useRevenueOverview` |
| Certificates | `school_certificates` | Certificates | `AcCertificateGeneratorScreen` | `useCertificates` |

Every item carries a non-empty label (Req 4.2) and a capability gate evaluated by `sidebarSectionsProvider` via `FeatureResolver.canAccess` (Req 4.3).

---

## Task 3.2 — Map `school_*` sidebar ids to `Ac_Screen` widgets

### Change

In `lib/widgets/desktop/sidebar_navigation_handler.dart`:
- Added 15 `case 'school_*':` branches (lines 786–816) in `tryGetScreenForItem`, each returning the corresponding `Ac_Screen` widget.
- Added the 15 school screen imports at the top of the file.
- An unknown `school_*` id that is not matched falls through to `default: return null`, which lets `getScreenForItem` surface the placeholder — satisfying Req 4.5.
- No other business type's `case` branches were touched (additive only).

---

## Task 3.3 — Resolve `/ac/students` collision and align GoRouter entries

### Collision Resolution (Requirement 4.6)

- **`/ac/students`** → `AcStudentsScreen` (CONFIRMED more feature-complete per Phase 0 §3.9) — **unchanged, retained as-is**.
- **`/ac/students/register`** → `AcStudentRegistrationScreen` — **new distinct non-colliding path added** with `VendorRoleGuard(requiredPermission: Permissions.viewClients)` + `BusinessGuard(allowedTypes: [BusinessType.schoolErp])`. Temporary `viewClients` permission will be replaced with a school-specific permission in Phase 3 (Req 6.3).

### Dormant GoRouter Alignment (Requirement 4.7)

GoRouter is the SOLE navigation root (confirmed by the `gorouter-navigation-migration` spec). The GoRoute entries in `legacy_routes.dart` ARE the live bindings — there are no "dormant" entries separate from them. Each `/ac/*` entry already references the correct target screen. Alignment confirmed and documented in a code comment.

### Navigation Source (Requirement 4.8)

School navigation items are sourced exclusively from `sidebarSectionsProvider`. GoRouter routes serve as the URL-based navigation layer.

### NavItems Redundancy Flag (Requirement 4.9)

**Flagged:** The backend module manifest duplicates navigation provided by `sidebarSectionsProvider`. Flagged in code comment — NOT deleted, deferred to Phase 9 per Requirement 12.2.

---

## Checkpoint — Phase 1 (Task 4)

### 1. `flutter analyze` Results

```
Analyzing 3 items...
No issues found! (ran in 5.0s)
```

| File | Errors | Warnings | Info |
|------|--------|----------|------|
| `lib/widgets/desktop/sidebar_configuration.dart` | 0 | 0 | 0 |
| `lib/widgets/desktop/sidebar_navigation_handler.dart` | 0 | 0 | 0 |
| `lib/core/routing/legacy_routes.dart` | 0 | 0 | 0 |
| **Total** | **0** | **0** | **0** |

### 2. Shared_Component Blast Radius

**Confirmed: For any `BusinessType` other than `schoolErp`, `_getSectionsForBusiness` returns sections identical to pre-change.**

Evidence:
- The `case BusinessType.schoolErp:` is a standalone case that returns `_getSchoolSections()`.
- No other `case` branch was modified.
- The `default: return _getRetailSections();` branch is byte-for-byte unchanged.
- The `_getRetailSections()`, `_getClinicSections()`, `_getPharmacySections()`, `_getRestaurantSections()`, `_getPetrolPumpSections()`, `_getMobileShopSections()`, `_getServiceSections()`, `_getHardwareSections()`, `_getVegetablesBrokerSections()`, `_getDecorationCateringSections()`, `_getJewellerySections()`, and `_getClothingSections()` functions are unmodified.
- `sidebarSectionsProvider` logic is unchanged; it just evaluates the new section list when `businessTypeState.type == BusinessType.schoolErp`.

Similarly for `sidebar_navigation_handler.dart`:
- The 15 new `case 'school_*':` branches are additive.
- All pre-existing `case` branches (dashboard, clinic, revenue, buyflow, inventory, petrol pump, restaurant, service, hardware, mandi, DC, jewellery, clothing, etc.) are unmodified.

For `legacy_routes.dart`:
- Only `/ac/students/register` was added as a new `GoRoute`.
- All pre-existing routes (billing, settings, pharmacy, hardware, DC, jewellery, etc.) remain byte-for-byte unchanged.
- The `_knownLegacyPaths` set only gained the `/ac/students/register` entry.

### 3. Per-Vertical Regression Result

| Business Type | Sidebar Dispatch | Navigation Handler | Route Table | Result |
|---------------|:----------------:|:------------------:|:-----------:|:------:|
| clinic | unchanged | unchanged | unchanged | ✓ PASS |
| pharmacy | unchanged | unchanged | unchanged | ✓ PASS |
| restaurant | unchanged | unchanged | unchanged | ✓ PASS |
| petrolPump | unchanged | unchanged | unchanged | ✓ PASS |
| electronics | unchanged | unchanged | unchanged | ✓ PASS |
| computerShop | unchanged | unchanged | unchanged | ✓ PASS |
| mobileShop | unchanged | unchanged | unchanged | ✓ PASS |
| service | unchanged | unchanged | unchanged | ✓ PASS |
| hardware | unchanged | unchanged | unchanged | ✓ PASS |
| vegetablesBroker | unchanged | unchanged | unchanged | ✓ PASS |
| decorationCatering | unchanged | unchanged | unchanged | ✓ PASS |
| jewellery | unchanged | unchanged | unchanged | ✓ PASS |
| clothing | unchanged | unchanged | unchanged | ✓ PASS |
| grocery (default) | unchanged | unchanged | unchanged | ✓ PASS |
| wholesale (default) | unchanged | unchanged | unchanged | ✓ PASS |
| bookStore (default) | unchanged | unchanged | unchanged | ✓ PASS |
| autoParts (default) | unchanged | unchanged | unchanged | ✓ PASS |
| other (default) | unchanged | unchanged | unchanged | ✓ PASS |

**All non-school verticals: PASS — zero changes to their sidebar dispatch, navigation handler cases, or route table entries.**

### 4. Requirement Traceability

| Requirement | Status | Evidence |
|-------------|--------|----------|
| 4.1 | ✓ Met | `case BusinessType.schoolErp: return _getSchoolSections();` — no fall-through to default |
| 4.2 | ✓ Met | Every item label contains at least one non-whitespace character |
| 4.3 | ✓ Met | Every item carries a `BusinessCapability` gate; each id resolves to an `Ac_Screen` (not placeholder) |
| 4.4 | ✓ Met | 15 `case 'school_*':` branches map to exactly one `Ac_Screen` widget each |
| 4.5 | ✓ Met | Unmatched ids fall to `default: return null` → `getScreenForItem` surfaces placeholder, no exception |
| 4.6 | ✓ Met | `/ac/students` → `AcStudentsScreen`; `/ac/students/register` → `AcStudentRegistrationScreen` (distinct, non-colliding) |
| 4.7 | ✓ Met | GoRouter entries ARE the live bindings; alignment confirmed in code comment |
| 4.8 | ✓ Met | Sidebar_Sections_Provider is single source of truth; GoRouter is URL layer only |
| 4.9 | ✓ Met | NavItems redundancy flagged in Phase_Report and code comment; not deleted |
| 4.10 | ✓ Met | No other business type's `_getSectionsForBusiness` resolution changed |
| 1.11 | ✓ Met | Shared edits are additive and scoped to schoolErp case only |
| 1.12 | ✓ Met | No other business type's sidebar, quick actions, alerts, capability, or template changed |

---

## Conclusion

Phase 1 is complete. All three tasks (3.1, 3.2, 3.3) are implemented. `flutter analyze` reports 0 errors and 0 warnings across all touched files. The Shared_Component blast radius is confined to the `schoolErp` case only. All other verticals are unaffected.
