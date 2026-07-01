# Phase 5 Report — Offline Sync and Real-Time Consistency

## Mini_Gate: School ERP Drift Cache Tables (v52)

### Proposed Change

Add **3 new Drift tables** to `lib/core/database/tables.dart` and register them in
`lib/core/database/app_database.dart`:

1. `school_students_cache` (`SchoolStudentsCache`) — tenant-scoped student record cache
2. `school_fees_cache` (`SchoolFeesCache`) — tenant-scoped fee/invoice record cache
3. `school_attendance_cache` (`SchoolAttendanceCache`) — tenant-scoped attendance record cache

Schema version bumped from **v51 → v52**.

### Consumers

| Consumer | Usage |
|----------|-------|
| `SchoolErpSyncHandler` | Writes synced student/fee/attendance data to these tables on sync-down |
| `AcDashboardScreen` / offline reads | Reads cached data when offline for KPI cards, alerts, and list views |
| `AcRepository` (offline path) | Falls back to these cache tables when network is unavailable |

### Migration Plan

- **Additive only** — 3 new `CREATE TABLE` statements; no existing tables are modified or dropped.
- **No existing data affected** — fresh tables with no pre-existing rows.
- **Safe defaults** — all nullable columns default to NULL; non-nullable columns have explicit `withDefault()` (e.g., `0` for Paise columns, `'active'`/`'pending'`/`'present'` for status).
- **Idempotent** — guarded by `if (from < 52)` so the migration runs only once.
- **Rollback** — if migration fails mid-way, the transaction rolls back and schema stays at v51.

### Column Summary

#### `school_students_cache`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT (PK) | RID pattern |
| tenantId | TEXT (NOT NULL) | Tenant isolation |
| name | TEXT | Student name |
| classSection | TEXT (default '') | e.g. "10-A" |
| enrollmentDate | DATETIME (nullable) | |
| totalFeesPaise | INTEGER (default 0) | Money: integer Paise |
| totalPaidPaise | INTEGER (default 0) | Money: integer Paise |
| balancePaise | INTEGER (default 0) | Money: integer Paise |
| status | TEXT (default 'active') | active/inactive/graduated/transferred |
| syncVersion | INTEGER (default 0) | Conflict resolution |
| lastModified | DATETIME (nullable) | Last modification timestamp |

#### `school_fees_cache`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT (PK) | RID pattern |
| tenantId | TEXT (NOT NULL) | Tenant isolation |
| studentId | TEXT | FK to student RID |
| invoiceId | TEXT (default '') | Invoice RID |
| amountPaise | INTEGER (default 0) | Money: integer Paise |
| paidAmountPaise | INTEGER (default 0) | Money: integer Paise |
| balancePaise | INTEGER (default 0) | Money: integer Paise |
| dueDate | DATETIME (nullable) | |
| status | TEXT (default 'pending') | pending/partial/paid/overdue/cancelled |
| syncVersion | INTEGER (default 0) | Conflict resolution |
| lastModified | DATETIME (nullable) | Last modification timestamp |

#### `school_attendance_cache`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT (PK) | RID pattern |
| tenantId | TEXT (NOT NULL) | Tenant isolation |
| studentId | TEXT | FK to student RID |
| date | DATETIME | Attendance date |
| status | TEXT (default 'present') | CHECK: present/absent/late |
| markedBy | TEXT (default '') | User who marked |
| syncVersion | INTEGER (default 0) | Conflict resolution |
| lastModified | DATETIME (nullable) | Last modification timestamp |

---

## Files Modified (Task 11.1)

| File | Change |
|------|--------|
| `lib/core/database/tables.dart` | Added `SchoolStudentsCache`, `SchoolFeesCache`, `SchoolAttendanceCache` table definitions |
| `lib/core/database/app_database.dart` | Registered 3 tables in `@DriftDatabase(tables: [...])`, bumped `schemaVersion` to 52, added `if (from < 52)` migration block |

## Audit Finding Addressed

- **Requirement 8.1**: Drift_Cache local caching for students, fees, and attendance with tenant isolation
- **Requirement 8.6**: Currency columns as integer Paise, identifiers in RID pattern
- **Requirement 1.8**: Mini_Gate recorded for schema change (new Drift tables)
