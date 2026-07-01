# Phase 3 Report — RBAC and Scoped School Permissions

## Summary

Phase 3 implemented a scoped School_Permissions layer that maps existing `UserRole` values
to school-specific permissions and replaced all 22 `/ac/*` route guards from generic retail
permissions (`viewInvoices`/`viewClients`) to school-specific `SchoolPermissionGuard` guards.
Two new files were created, one file was modified. The global `UserRole` enum was NOT
changed — no Mini_Gate was required. Zero errors, zero warnings from `flutter analyze`.

---

## Files Created

| File | Task | Purpose | Requirements |
|------|------|---------|--------------|
| `lib/features/academic_coaching/utils/school_permissions.dart` | 7.1 | `SchoolPermission` enum + `hasSchoolPermission(UserRole, SchoolPermission)` total pure function mapping existing roles to school-specific permissions | 6.1, 6.2 |
| `lib/features/academic_coaching/utils/school_permission_guard.dart` | 7.2 | `SchoolPermissionGuard` widget for `/ac/*` route protection — checks `hasSchoolPermission` against the user's effective role | 6.3, 6.4, 6.5, 6.6, 6.7 |

## Files Modified

| File | Task | Change Summary | Requirements |
|------|------|---------------|--------------|
| `lib/core/routing/legacy_routes.dart` | 7.2 | Replaced all 22 `/ac/*` route guards from `VendorRoleGuard(requiredPermission: Permissions.xxx)` to `SchoolPermissionGuard(permission: SchoolPermission.xxx)`; added imports for `school_permission_guard.dart` and `school_permissions.dart` | 6.3, 6.4, 6.5, 6.6, 6.7 |

## Files Deleted

None.

---

## Task 7.1 — School_Permissions Mapping Layer

### Change

Created `lib/features/academic_coaching/utils/school_permissions.dart`:

1. **`SchoolPermission` enum** — seven school-specific permissions:
   - `viewStudents`, `viewFees`, `collectFees`, `markAttendance`, `enterMarks`, `viewStudentPII`, `exportStudentPII`

2. **`_schoolPermissionMap`** — constant `Map<UserRole, Set<SchoolPermission>>`:
   - `owner`: ALL 7 permissions
   - `manager`: ALL 7 permissions
   - `staff`: `viewStudents`, `markAttendance`, `enterMarks`
   - `accountant`: `viewStudents`, `viewFees`, `collectFees`
   - All other roles (`pharmacist`, `waiter`, `chef`, `captain`, `doctor`, `receptionist`, `nurse`, `unknown`): no mapping → deny-by-default

3. **`hasSchoolPermission(UserRole role, SchoolPermission permission) -> bool`** — total pure function:
   - Returns `true` only if the role's grant set contains the permission
   - Returns `false` (deny-by-default) for any unmapped pair
   - Reusable by both the sidebar filter and the route guards

### Key design decisions

- **No `UserRole` enum change** — the mapping operates entirely over existing enum values
- **Deny-by-default** — unmapped (role, permission) pairs return `false`
- **Total function** — defined for every possible (`UserRole`, `SchoolPermission`) pair

---

## Task 7.2 — Replace Generic `/ac/*` Route Guards with School_Permission Guards

### Change

Created `lib/features/academic_coaching/utils/school_permission_guard.dart`:

- **`SchoolPermissionGuard` widget** — `StatelessWidget` wrapping `ListenableBuilder` on `SessionManager`:
  - Loading/uninitialized → shows `AuthLoadingScreen` (Req 6.4)
  - Unauthenticated → redirects to splash (Req 6.5)
  - Not owner/vendor → redirects to splash (Req 6.5)
  - Has required `SchoolPermission` → renders child screen (Req 6.4)
  - Lacks permission → blocks, renders no part of child, redirects to `/home`, shows access-denied snackbar (Req 6.5)
  - No mapping defined (null permission) → denied, redirected (Req 6.6)

Modified `lib/core/routing/legacy_routes.dart`:

- Replaced all **22** `/ac/*` route guards from `VendorRoleGuard(requiredPermission: Permissions.viewInvoices/viewClients)` to `SchoolPermissionGuard(permission: SchoolPermission.xxx)`
- Added imports for the new guard and permission modules

### Route-to-permission mapping

| Route | Previous Guard | New Guard |
|-------|---------------|-----------|
| `/ac/dashboard` | `viewInvoices` | `SchoolPermission.viewStudents` |
| `/ac/students` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/students/register` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/classes` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/academic-year` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/batches` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/courses` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/faculty` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/fees` | `viewInvoices` | `SchoolPermission.viewFees` |
| `/ac/attendance` | `viewClients` | `SchoolPermission.markAttendance` |
| `/ac/timetable` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/exams` | `viewInvoices` | `SchoolPermission.enterMarks` |
| `/ac/report-cards` | `viewInvoices` | `SchoolPermission.enterMarks` |
| `/ac/materials` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/library` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/transport` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/risk` | `viewInvoices` | `SchoolPermission.viewFees` |
| `/ac/notifications` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/bulk` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/financial` | `viewInvoices` | `SchoolPermission.viewFees` |
| `/ac/certificates` | `viewClients` | `SchoolPermission.viewStudents` |
| `/ac/fee-structure` | `viewInvoices` | `SchoolPermission.viewFees` |

**No `/ac/*` route retains a `viewInvoices` or `viewClients` guard.**

---

## Checkpoint — Phase 3 (Task 8)

### 1. `flutter analyze` Results

```
Analyzing 3 items...
No issues found! (ran in 3.9s)
```

| File | Errors | Warnings | Info |
|------|--------|----------|------|
| `lib/features/academic_coaching/utils/school_permissions.dart` | 0 | 0 | 0 |
| `lib/features/academic_coaching/utils/school_permission_guard.dart` | 0 | 0 | 0 |
| `lib/core/routing/legacy_routes.dart` | 0 | 0 | 0 |
| **Total** | **0** | **0** | **0** |

### 2. `UserRole` Enum — No Change Applied

**CONFIRMED: The global `UserRole` enum at `lib/core/models/user_role.dart` was NOT modified.**

The enum retains its original 12 values in original order:
`owner`, `manager`, `staff`, `accountant`, `pharmacist`, `waiter`, `chef`, `captain`, `doctor`, `receptionist`, `nurse`, `unknown`

No Mini_Gate was required because no enum change was proposed. The School_Permissions layer
maps existing values only.

### 3. Per-Vertical Regression Result — Route Guards

**Confirmed: No other business type's route guard changed.**

Evidence from `lib/core/routing/legacy_routes.dart`:
- Clinic routes (`/clinic/appointment`, `/clinic/prescription`, `/clinic/queue`) → still use `VendorRoleGuard(requiredPermission: Permissions.viewClients)` ✓
- Hardware routes (`/hardware/credit-control`, `/hardware/fast-billing`, `/hardware/invoice-profiles`) → still use `VendorRoleGuard` ✓
- Decoration & Catering routes (`/dc/*`) → still use `VendorRoleGuard` ✓
- Computer shop routes (`/computer-shop/*`) → still use `VendorRoleGuard` ✓
- Petrol pump routes (`/pump/*`) → still use `VendorRoleGuard` ✓
- Service routes (`/service_jobs`, `/exchanges`, `/job/*`) → still use `VendorRoleGuard` ✓
- Book store routes (`/book_store/*`) → still use `VendorRoleGuard` ✓
- Jewellery routes (`/jewellery-*`) → still use `VendorRoleGuard` ✓
- Pharmacy routes (`/pharmacy/*`) → still use `ProtectedRoute`/`VendorRoleGuard` ✓
- Billing routes (`/pending`, `/billing_flow`, etc.) → still use `VendorRoleGuard` ✓

| Business Type | Route Guards | Result |
|---------------|:------------:|:------:|
| clinic | unchanged | ✓ PASS |
| pharmacy | unchanged | ✓ PASS |
| restaurant | unchanged | ✓ PASS |
| petrolPump | unchanged | ✓ PASS |
| electronics | unchanged | ✓ PASS |
| computerShop | unchanged | ✓ PASS |
| mobileShop | unchanged | ✓ PASS |
| service | unchanged | ✓ PASS |
| hardware | unchanged | ✓ PASS |
| vegetablesBroker | unchanged | ✓ PASS |
| decorationCatering | unchanged | ✓ PASS |
| jewellery | unchanged | ✓ PASS |
| clothing | unchanged | ✓ PASS |
| bookStore | unchanged | ✓ PASS |
| grocery (default) | unchanged | ✓ PASS |
| wholesale (default) | unchanged | ✓ PASS |
| autoParts (default) | unchanged | ✓ PASS |
| other (default) | unchanged | ✓ PASS |

**All non-school verticals: PASS — zero changes to their route guards.**

### 4. Requirement Traceability

| Requirement | Status | Evidence |
|-------------|--------|----------|
| 6.1 | ✓ Met | `UserRole` enum unchanged; no Mini_Gate needed (no change was proposed) |
| 6.2 | ✓ Met | `hasSchoolPermission` is a total pure function mapping existing `UserRole` values to `SchoolPermission` without modifying the enum |
| 6.3 | ✓ Met | All 22 `/ac/*` routes now use `SchoolPermissionGuard`; no route retains `viewInvoices`/`viewClients` |
| 6.4 | ✓ Met | A holder of the required `SchoolPermission` sees the child screen with no redirect |
| 6.5 | ✓ Met | A non-holder is blocked, renders no part of the screen, is redirected to `/home`, and sees an access-denied snackbar |
| 6.6 | ✓ Met | A route with no permission mapping (deny-by-default) denies access and redirects |
| 6.7 | ✓ Met | Change scoped to schoolErp routes only; all other business type route guards confirmed unchanged |

---

## Conclusion

Phase 3 is complete. Both tasks (7.1, 7.2) are implemented. `flutter analyze` reports
0 errors and 0 warnings. The `UserRole` enum is unchanged — the School_Permissions layer
maps existing roles without modification. All 22 `/ac/*` routes are now guarded by
school-specific permissions. No other business type's route guard was affected.
