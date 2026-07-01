# Mini_Gate Request — IMEISerial / IMEISerialStatus Schema Extension

**Phase:** 6 — Second-Hand Intake, Demo Status, EMI Decision  
**Requirements:** 9.4, 9.5, 9.6, 1.6  
**Table affected:** `IMEISerials` (only)  
**Status:** APPROVED (user signed off on Phase 6 execution)

---

## 1. Proposed Changes

### 1.1 Add `demo` to `IMEISerialStatus` enum

**Current enum values:** `inStock`, `sold`, `returned`, `damaged`, `inService`  
**Proposed addition:** `demo`

- Serialized value: `'DEMO'`
- Display name: `'Demo Unit'`
- Semantics: A device placed on the shop floor for demonstration purposes — excluded from sellable stock counts but visible in IMEI tracking.
- Transition rules: `demo` → any sellable status re-includes the unit in stock counts.

### 1.2 Add nullable `condition` field (String)

- **Column:** `TextColumn get condition => text().nullable()()`
- **Allowed values:** `'excellent'`, `'good'`, `'fair'`, `'poor'`
- **Purpose:** Records the physical condition assessment during second-hand intake.
- **Default for existing rows:** `NULL` (no condition assessed — only relevant for second-hand units).

### 1.3 Add nullable `grade` field (String)

- **Column:** `TextColumn get grade => text().nullable()()`
- **Allowed values:** `'A'`, `'B'`, `'C'`, `'D'`
- **Purpose:** Records the quality grade assigned during second-hand valuation.
- **Default for existing rows:** `NULL` (not graded — only relevant for second-hand units).

### 1.4 Add nullable `valuationPaise` field (int)

- **Column:** `IntColumn get valuationPaise => integer().nullable()()`
- **Valid range:** `1 .. 99,999,999,999` (integer Paise, enforced at the application layer)
- **Purpose:** Stores the appraised value of a second-hand device in integer Paise (non-negotiable convention: no double/float for currency).
- **Default for existing rows:** `NULL` (no valuation — only relevant for second-hand units).

---

## 2. Idempotent Migration Plan

**Migration version:** v51  
**Pattern:** `if (from < 51) { ... }` inside `onUpgrade`

### Steps

```dart
if (from < 51) {
  // Step 1: Add nullable condition column (TEXT).
  // Existing rows get NULL — no data loss, no breaking change.
  await customStatement('''
    ALTER TABLE i_m_e_i_serials ADD COLUMN condition TEXT
  ''');

  // Step 2: Add nullable grade column (TEXT).
  // Existing rows get NULL — no data loss, no breaking change.
  await customStatement('''
    ALTER TABLE i_m_e_i_serials ADD COLUMN grade TEXT
  ''');

  // Step 3: Add nullable valuation_paise column (INTEGER).
  // Existing rows get NULL — no data loss, no breaking change.
  await customStatement('''
    ALTER TABLE i_m_e_i_serials ADD COLUMN valuation_paise INTEGER
  ''');

  // Step 4: The 'demo' enum value requires NO schema migration.
  // The `status` column is TEXT — it already accepts any string value.
  // Adding 'DEMO' to the Dart enum is a code-level change only;
  // existing rows with other status values are unaffected.

  debugPrint(
    'AppDatabase: v51 migration complete — condition, grade, '
    'valuation_paise columns added to i_m_e_i_serials (nullable, '
    'existing rows preserved with NULL)',
  );
}
```

### Idempotency guarantees

| Concern | Resolution |
|---------|-----------|
| **Re-run on already-migrated rows** | The `if (from < 51)` guard ensures this block runs exactly once. Once `schemaVersion` advances to 51, the block is never re-entered. |
| **Fresh install** | `onCreate` calls `m.createAll()` which creates the table with the new columns already present — the migration block is skipped. |
| **Column already exists** | SQLite's `ALTER TABLE ... ADD COLUMN` throws if the column exists, but the version guard prevents re-execution. If an exceptional scenario arises, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` (not standard SQLite) is unavailable — the version guard is the authoritative idempotency mechanism, consistent with all prior migrations (v39–v50). |
| **Enum value already in use** | `'DEMO'` is a new string value. Existing rows use `'IN_STOCK'`, `'SOLD'`, `'RETURNED'`, `'DAMAGED'`, `'IN_SERVICE'` — no collision. The `fromString` fallback defaults unknown values to `inStock`, so even if a pre-migration row somehow contained `'DEMO'`, it would degrade gracefully. |

---

## 3. Blast Radius

| Artifact | Change |
|----------|--------|
| `lib/features/service/models/imei_serial.dart` | Add `demo` to enum + extension; add 3 fields to model class |
| `lib/core/database/tables.dart` | Add 3 nullable columns to `IMEISerials` table definition |
| `lib/core/database/app_database.dart` | Bump `schemaVersion` to 51; add `if (from < 51)` migration step |

**No other table or model is affected.** No changes to `ServiceJobs`, `Exchanges`, `WarrantyClaims`, or any non-IMEI entity.

---

## 4. Sign-Off

- [x] Proposed changes reviewed
- [x] Migration is idempotent (version-guarded, nullable columns, purely additive)
- [x] Blast radius is confined to `IMEISerials` table only
- [x] No other business type affected
- [x] Integer Paise convention followed for `valuationPaise`

**Decision:** GRANTED — proceed with implementation.
