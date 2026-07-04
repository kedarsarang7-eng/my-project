# Staff Management Module

Universal, configuration-driven staff management for DukanX. ONE module adapts to
every business type (Grocery … Jewellery … School ERP) purely through
`Staff_Feature_Config` (BusinessType × SubscriptionTier) — **no per-industry code
forks**. It extends the existing platform (Cognito auth, RBAC, offline Sync_Engine,
subscription tiers, WhatsApp gateway) rather than replacing any of it.

- **Manifest:** [`manifest.ts`](./manifest.ts)
- **Directory skeleton:** `handlers/`, `repositories/`, `services/`, `schemas/`
  (currently empty barrel placeholders; populated in later tasks)

---

# Phase 0 — Discovery & Codebase Audit Artifact

> **STOP_GATE.** This document is the Phase 0 discovery deliverable required by
> Requirement 0. Phase 0 is analysis + documentation only; no feature code ships
> until this artifact is signed off (Req 0.1, 0.9). Findings below are recorded
> from the actual `my-backend` / `Dukan_x` codebase as of scaffolding. Items that
> could **not** be confirmed against the code are recorded as **OPEN QUESTIONS**
> rather than assumed true (Req 0.8).

## 0.2 — Existing staff-related code: ACTIVE / ORPHANED / DEAD classification

Classification of every staff / HR / attendance / payroll / leave / shift /
commission artifact discovered.

| Artifact | Location | Domain | Classification | Notes |
|---|---|---|---|---|
| `staff-sale.ts` | `my-backend/src/handlers/` | Petrol-pump staff **sales** (fuel), not HR | **ACTIVE** | Gated `PETROL_PUMP` + `PETROL_BASIC_SHIFT_ENTRY`; atomic stock deduct + QR pay. Unrelated to HR staff lifecycle — name collision only. |
| `staff-sale-history.ts` | `my-backend/src/handlers/` | Petrol-pump staff sales history | **ACTIVE** | Read side of staff-sale. Not HR. |
| `ac-leave.ts` | `my-backend/src/handlers/` | School ERP leave (students **and** staff) | **ACTIVE** | Gated `SCHOOL_ERP` + `AC_ATTENDANCE_MANAGEMENT`. School-specific; not universal. Reference model for leave workflow. |
| `ac-payslip.ts` | `my-backend/src/handlers/` | School ERP faculty/staff payroll + payslip | **ACTIVE** | Gated `SCHOOL_ERP` + `AC_FEE_MANAGEMENT`. Stores payslips via `StorageService`; **DynamoDB-based**, not a relational ACID store. |
| `ac-period-attendance.ts` | `my-backend/src/handlers/` | School ERP period-wise attendance | **ACTIVE** | Gated `SCHOOL_ERP` + `AC_ATTENDANCE_MANAGEMENT`. Mutable marking model (not append-only event sourcing). |
| `ac-department.ts` | `my-backend/src/handlers/` | School ERP academic departments | **ACTIVE** | School-specific `DEPT`-like concept; distinct from universal `DEPT#`. |
| `ac-biometric.ts` | `my-backend/src/handlers/` | School ERP biometric interface | **ACTIVE (interface)** | Confirms biometric should stay an interface; consistent with deferral (Req 3.2, 15.3). |
| `DC_STAFF_MANAGEMENT` FeatureKey | `config/plan-feature-registry.ts` | Decoration/Catering "staff management" flag | **ACTIVE** | Belongs to the `decoration-catering` module — **not** the universal staff module. Do not reuse; register dedicated `STAFF_*` keys (task 2.4). |
| `Keys.staffSK` → `STAFF#` | `config/dynamodb.config.ts`, `dynamodb/keys.ts` | Tenant **user** records ("staff" = employee-user) | **ACTIVE** | Existing `STAFF#` SK is for platform users. Universal module uses `EMP#` for Employee to avoid collision. |
| `Keys.auditSK` / `AUDIT_SK_PREFIX` → `AUDIT#` | `dynamodb/keys.ts` | Generic append-only audit | **ACTIVE** | See **OQ-1** — the staff manifest also declares `AUDIT#`. |
| `broadcastToStaff`, `STAFF_APP` client type, `STAFF_ACTIVITY` WS event | `services/websocket.service.ts`, `types/websocket.types.ts` | Realtime staff-app channel | **ACTIVE** | Reuse for `staff:` WS channel prefix; no new gateway needed. |
| `calculateCommission(...)` | `__tests__/specialized-business-logic.test.ts` | Vegetable-broker commission (test-only helper) | **ORPHANED (test-only)** | Not a shared service; a local test helper. The universal `Commission_Engine` is new work. |
| `dukan_restro_chef`, `dukan_restro_pos` | `.archive/restaurant-trio-2026-05/` | Archived restaurant apps | **DEAD** | Archived; ignore. |
| `WS-1/WS-2 cleanup` fix-scripts & logs | `.archive/…` | One-off migration scripts | **DEAD** | Archived; ignore. |

**Summary:** No pre-existing *universal* staff/HR module exists. The closest
implementations are **School-ERP-scoped** (`ac-leave`, `ac-payslip`,
`ac-period-attendance`, `ac-department`) and are ACTIVE but industry-forked —
exactly the pattern this module replaces with configuration. There is **no
generic Employee/Department/Designation/Shift/Roster/Payroll engine** to extend;
this module builds them new while reusing platform primitives.

## 0.3 — RBAC granularity

Source: `config/permission-matrix.ts` (`checkPermission(feature, userRole, plan)`),
`types/tenant.types.ts` (`UserRole`), `middleware/handler-wrapper.ts`
(`authorizedHandler([...roles])`).

| Control level | Implemented today? | Evidence |
|---|---|---|
| **Screen / feature level** | ✅ Yes | `checkPermission` maps `FeatureKey → { minRole, requiredPlan }`; **fail-closed** (unknown feature → denied). |
| **API / route level** | ✅ Yes | `authorizedHandler([roles], …)` + per-handler `requiredBusinessType` / `requiredFeature` options enforced server-side. |
| **Role level** | ✅ Yes | `UserRole` enum: super_admin, owner, admin, manager, accountant, cashier, staff, pumpboy, viewer, ca, customer. Owner/Admin auto-pass in-plan role checks. |
| **Field level** | ❌ **Gap** | No field-level descriptors. Required for PII masking/unmasking (Req 2.5, 2.6) and salary fields. |
| **Button / action level** | ❌ **Gap** | No button/action descriptors. Required for approve/export/delete gating (Req 8.1). |
| **Report / dashboard / export / delete / approval level** | ❌ **Gap** | Not modeled as discrete permissions today. |

**Conclusion:** RBAC operates at screen/feature/API/role granularity and is
fail-closed. Field-, button-, action-, report-, export-, delete-, and
approval-level control are a **genuine gap** — this confirms the RBAC extension in
Req 8.1 / task 11.1 is warranted (extend, do not replace — AD-3).

## 0.4 — DynamoDB table inventory (staff-relevant)

Source: `config/dynamodb.config.ts`, `dynamodb/keys.ts`.

- **Design:** **Single-table**. One table (`TABLE_NAME = config.dynamodb.tableName`),
  billing `PAY_PER_REQUEST`, all entities share the table with GSIs. Header note:
  "Replaces PostgreSQL (RDS) with DynamoDB" — reaffirms AD-1's DynamoDB-only
  decision (payroll uses DynamoDB transactions, not a relational store).
- **Partition key invariant:** every PK includes tenant. `tenantPK → TENANT#{tenantId}`;
  business-scoped `businessPK → TENANT#{tenantId}#BIZ#{businessId}`. Key builders
  reject `#` injection (`validateKeySegment`). This is the exact partition the
  staff module uses (BusinessID as leading scope — Req 1.5, 11.1).
- **Existing SK prefixes (selected):** `PROFILE`, `SETTINGS`, `LICENSE`, `USER#`,
  `PRODUCT#`, `INVOICE#`, `LINEITEM#`, `CUSTOMER#`, `CUSTOMER#…#BALANCE`,
  `PAYMENT#`, `TXN#`, `BUSINESS#`, `STAFF#`, `INVENTORY#`, `AUDIT#`.
- **GSIs referenced:** `GSI1` (ByDate), `GSI2`, `GSI3` (barcode) among others.
- **Staff module ownership:** exclusive SK prefixes `EMP# DEPT# DESIG# ATT# SHIFT#
  ROSTER# LVTYPE# LVREQ# LVBAL# TASK# COMMRULE# PERFSCORE# AUDIT# NOTIFLOG#
  STAFFCFG#` (declared in `manifest.ts`); uses `GSI1`.

## 0.5 — Offline conflict-resolution strategy (implemented vs intended)

Source: `Dukan_x/lib/core/sync/` — `sync_table_registry.dart`, plus (per design
research) `OfflineQueue`, `SyncManager`, `sync_queue_state_machine.dart`,
`version_reconciliation.dart`, `conflict_resolution_dialog.dart`.

- **Implemented:** A `SyncTableRegistry` is the single source of truth for which
  Drift/SQLite tables sync, their remote mapping, priority, and per-business-type
  applicability. Sync-queue operations carry **stable idempotency keys**
  (`operationId` / `requestId` / `idempotencyKey`) for **server-side dedup**.
  A queue state machine, version reconciliation, and a conflict-resolution dialog
  exist — so per-entity conflict handling + manager-surfaced conflicts (Req 4.4,
  12.4) plug into existing machinery rather than being built fresh.
- **OPEN QUESTION (OQ-2):** `sync_table_registry.dart` maps local tables to
  **"remote PostgreSQL tables"**, but the backend is DynamoDB single-table. The
  mapping abstraction is real but the "PostgreSQL" naming appears legacy. The
  precise wire path for staff entities (REST sync handler + collection names) must
  be confirmed before wiring Drift tables in task 15.1 / 16.1.

## 0.6 — OpenWA_Gateway integration contract

- **Requirement/design intent:** route WhatsApp through the existing
  **OpenWA_Gateway** (Baileys, PostgreSQL, per-tenant API key, HMAC-SHA256 webhook
  verification); add **no second** WhatsApp gateway (Req 8.5).
- **What exists in the repo:**
  - An OpenWA/Baileys service tree lives under `Dukan_x/OpenWA/` (scripts, sqlite,
    dashboard) — a standalone gateway.
  - The **backend** currently ships `services/whatsapp.service.ts` which calls the
    **Meta WhatsApp Business Cloud API** (`graph.facebook.com/v17.0`) with
    pre-approved templates — **not** OpenWA. `academic_coaching.ts` also posts
    directly to the Meta Cloud API.
  - HMAC-SHA256 verification **is** an established platform pattern, implemented for
    payment webhooks in `services/gateway/razorpay.gateway.ts` and
    `phonepe.gateway.ts` using `crypto.createHmac('sha256', …)` + constant-time
    `crypto.timingSafeEqual` (timing-attack safe). This is the template to reuse
    for per-tenant HMAC verification.
- **OPEN QUESTION (OQ-3):** The backend has **two** potential WhatsApp paths — the
  Meta Cloud API (`whatsapp.service.ts`, active) and the OpenWA/Baileys gateway
  (`Dukan_x/OpenWA`). Req 8.5 says route through OpenWA and add no second gateway.
  Before task 11.3, confirm which is the canonical `OpenWA_Gateway` for
  notifications and whether `whatsapp.service.ts` is being migrated/retired, so the
  staff `Notification_Service` does not become a "second gateway".

## 0.7 — Subscription / feature-gating configuration format

Source: `config/plan-feature-registry.ts`, `config/permission-matrix.ts`.

- **Tiers:** `PlanTier = { BASIC='basic', PRO='pro', PREMIUM='premium',
  ENTERPRISE='enterprise' }`. (Legacy `SubscriptionPlan` aliases also exist in
  `tenant.types.ts`.)
- **Feature keys:** `FeatureKey` enum — a single, self-documenting enumeration of
  every gatable capability (e.g. `CLINIC_*`, `AC_*`, `DC_*`, `PETROL_*`).
- **Registry shape:** `PlanTier × BusinessType → FeatureKey[]` grants, combined with
  `permission-matrix.ts` `{ [FeatureKey]: { minRole, requiredPlan } }`. Access =
  `checkPermission(feature, role, plan)` and is **fail-closed**.
- **Module contract:** each `ModuleManifest` declares `featureKeys`, `requiredPlan`,
  `minRole`, `businessTypes`, and `db.skPrefixes` (see `core/types/module.types.ts`).
- **Implication for staff:** `Staff_Feature_Config` (STAFFCFG#{businessType}#{tier})
  **extends** this mechanism — it layers enabled-modules/enabled-fields on top of
  the existing registry. New `STAFF_*` `FeatureKey`s must be added to the enum
  **before** they are referenced (why `manifest.featureKeys` is an empty
  placeholder here; populated in task 2.4). Express business-type differences as
  config values only — no `switch(businessType)` (AD-2, Req 1.8, 13.3).

## Open Questions (Req 0.8)

- **OQ-1 — `AUDIT#` SK prefix overlap — RESOLVED (task 1.2).** The staff manifest
  declares `AUDIT#`, but `dynamodb/keys.ts` already defines `auditSK`/`AUDIT_SK_PREFIX`
  = `AUDIT#` for generic audit. **Resolution (see `modules/staff/keys.ts`):** accept
  **PK-level separation** as the primary boundary — generic audit lives in the tenant
  partition (`TENANT#{t}`) while staff audit lives in the business partition
  (`TENANT#{t}#BIZ#{b}`), so they never share a partition and item ULIDs never
  overwrite. As defence-in-depth, every staff item carries an `entity_type`
  (`STAFF_AUDIT`) that base-table `begins_with(SK,'AUDIT#')` scans filter on, and
  staff audit lists on GSI1 under the namespaced entity type `STAFF_AUDIT` (never the
  generic `AUDIT`). The manifest's declared prefix is kept intact.
- **OQ-1b — `SHIFT#` SK prefix overlap — RESOLVED (task 1.2).** Discovered during key
  design: `dynamodb/keys.ts` already defines `SHIFT_SK_PREFIX`/`buildShiftKeys` =
  `SHIFT#` for **petrol-pump fuel shifts**, which are ALSO business-scoped, so unlike
  `AUDIT#` the PK does not separate them. **Resolution:** staff shift keeps the `SHIFT#`
  SK prefix but carries `entity_type = STAFF_SHIFT`; base-table `begins_with(SK,'SHIFT#')`
  reads MUST filter by `entity_type`, and staff shifts list on GSI1 under `STAFF_SHIFT`
  (distinct from petrol pump's `SHIFT` GSI entity type). Item IDs are ULID/UUID so no
  overwrite occurs. Flagged for design awareness; no manifest change required.
- **OQ-2 — Sync remote-store naming.** `sync_table_registry.dart` references "remote
  PostgreSQL tables" while the backend is DynamoDB. Confirm the real sync wire path
  and collection names for staff entities before task 15.1 / 16.1.
- **OQ-3 — Canonical WhatsApp gateway.** Two WhatsApp paths exist (Meta Cloud API in
  `whatsapp.service.ts` vs OpenWA/Baileys in `Dukan_x/OpenWA`). Confirm the
  canonical `OpenWA_Gateway` before task 11.3 to satisfy "no second gateway" (Req 8.5).
- **OQ-4 — Payroll store (AD-1) — RESOLVED (DynamoDB).** An earlier design draft proposed
  an Aurora Serverless v2 relational store for payroll/statutory. This was **rejected** by
  decision: the platform standardized on DynamoDB single-table (`dynamodb.config.ts`:
  "Replaces PostgreSQL (RDS) with DynamoDB") and AGENTS.md defaults to DynamoDB. Payroll ACID
  needs are met with native DynamoDB `TransactWriteCommand` (atomic run + payslips) and a
  conditional-write single-writer lock — the same primitives already used for duplicate-IMEI
  prevention. No relational store / SQL migrations are introduced.
- **OQ-5 — `BaseRepository`.** The design says repositories `extends BaseRepository`,
  but no `BaseRepository` class currently exists in `my-backend/src`. Confirm whether
  to introduce one or extend the existing `config/dynamodb.config.ts` helpers
  (`putItem`, `getItem`, `queryItems`, `transactWrite`) before task 3.2.

## Phase 0 sign-off

- [x] Discovery findings reviewed
- [x] Open questions OQ-1 … OQ-5 triaged
- [x] Explicit sign-off to proceed to feature code (Req 0.9) — **GRANTED**

### Sign-off decisions (recorded at the Phase 0 STOP_GATE)

- **OQ-5 (BaseRepository) → DECISION: create a lightweight `BaseRepository`.** A small
  `BaseRepository<T>` will wrap the existing `dynamodb.config.ts` helpers
  (`putItem`/`getItem`/`queryItems`/`transactWrite`) to give staff repositories a
  consistent CRUD surface, matching the design's `extends BaseRepository`. Implemented
  as part of task 3.2.
- **OQ-3 (WhatsApp gateway) → DECISION: OpenWA/Baileys is canonical.** Staff
  `Notification_Service` routes WhatsApp through the existing OpenWA_Gateway only; it
  does NOT call `whatsapp.service.ts` (Meta Cloud API) and introduces no second gateway
  (Req 8.5). Reuse the HMAC-SHA256 pattern from the payment gateways. Applied in task 11.3.
- **OQ-2 (sync wire path) → DECISION: confirm at task 15.1.** The "remote PostgreSQL
  tables" naming in `sync_table_registry.dart` is treated as legacy; the real backend is
  DynamoDB. The concrete REST sync path/collection names will be confirmed when wiring
  Drift tables in task 15.1 before any frontend sync code is finalized.
