# 🚨 CRITICAL FINDINGS — Tenant Isolation Security Audit (Phase 0)

**Date**: 2026-06-19
**Auditor**: AI Security/QA Engineer
**Status**: 🔴 CRITICAL FINDINGS — MUST FIX BEFORE PRODUCTION

---

## Finding #1 — 🔴 P0/CRITICAL: `x-tenant-id` Header Fallback Bypasses JWT in Lambda Handlers

> [!CAUTION]
> **THIS IS THE #1 FINDING. STOP AND FIX BEFORE ANY OTHER WORK.**

### Location

| File | Line | Code |
|------|------|------|
| `lambda/storageHandler/index.mjs` | 358 | `const tenantId = decoded.tenantId \|\| event.headers['x-tenant-id'];` |
| `lambda/batchHandler/index.mjs` | 202 | `const tenantId = decoded.tenantId \|\| event.headers['x-tenant-id'];` |
| `lambda/shared/utils/request-context.mjs` | 51 | `const tenantHeader = event.headers?.['x-tenant-id'] \|\| event.headers?.['X-Tenant-ID'];` |

### Impact

**Business-ending BOLA/IDOR vulnerability.** If `decoded.tenantId` is falsy (e.g., missing from JWT claim, null, empty string), the code **falls back to a client-supplied HTTP header** (`x-tenant-id`). An attacker can:

1. Obtain any valid JWT token (even one with a missing/null tenantId claim)
2. Set `x-tenant-id: <victim-tenant-id>` in the request header
3. Gain **full read/write/delete access** to the victim's S3 objects (storageHandler) and **arbitrary DynamoDB tables** (batchHandler)

**This is a straight client-controlled tenantId bypass.** The `||` fallback makes the JWT claim advisory, not authoritative.

### Affected Surfaces

- **S3**: Upload, download, delete, list ANY tenant's files via presigned URLs
- **DynamoDB Batch**: Set, update, delete records in ANY tenant's data across 18+ tables
- **Request Context**: RID generation and tracing can be poisoned with wrong tenantId

### Recommended Fix

```javascript
// BEFORE (vulnerable):
const tenantId = decoded.tenantId || event.headers['x-tenant-id'];

// AFTER (secure):
const tenantId = decoded.tenantId;
if (!tenantId) {
    return error('Token missing tenantId — cannot proceed', 403);
}
```

**Never fall back to client-supplied values for identity claims.**

---

## Finding #2 — 🔴 P0/CRITICAL: Public Endpoints Accept `x-tenant-id` from Unauthenticated Requests

### Location

| File | Line | Code |
|------|------|------|
| `my-backend/src/handlers/ac-admissions.ts` | 74 | `const tenantId = event.headers?.['x-tenant-id'] \|\| event.headers?.['X-Tenant-Id'];` |
| `my-backend/src/routes/pharmacy-dashboard.routes.ts` | 69+ | `const tenantId = req.headers['x-tenant-id'] as string;` (12 occurrences) |

### Impact

The `submitApplication` endpoint at `/ac/admissions/public/apply` is explicitly **unauthenticated** (no `authorizedHandler` wrapper). It reads `tenantId` directly from the `x-tenant-id` header. An attacker can:

1. Submit admission applications **to any tenant** by setting the header
2. The application is **written to the target tenant's DynamoDB partition** (`TENANT#<victimId>`)
3. This is a **cross-tenant write** into the victim's data partition

Similarly, the pharmacy dashboard routes read `x-tenant-id` from request headers without JWT validation.

### Recommended Fix

For public endpoints: require a signed/verifiable tenant identifier (e.g., tenant slug lookup from a public table, not a raw header). For authenticated routes: always derive from JWT via `auth.tenantId`.

---

## Finding #3 — 🟠 HIGH: `lambda/shared/auth.ts` Does NOT Verify JWT Signatures

### Location

`lambda/shared/auth.ts` lines 34-35:

```typescript
const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
```

### Impact

The marketplace Lambda auth layer (`validateBusinessToken`, `validateCustomerToken`) decodes JWTs by **base64-decoding the payload without signature verification**. Any attacker can forge a JWT with arbitrary claims (businessId, sub, email) and bypass auth entirely.

The code has a comment "In production, verify JWT signature against Cognito JWKS" — **this was never implemented**.

> [!WARNING]
> The separate `lambda/shared/utils.mjs` `verifyToken()` DOES use `CognitoJwtVerifier` properly, and the `my-backend` `cognito-auth.ts` also verifies properly. But any handler using `lambda/shared/auth.ts` directly is vulnerable.

---

## Finding #4 — 🟡 MEDIUM: DynamoDB Single-Table Key Design Analysis

### Main Table Schema (`my-backend` — `dynamodb.config.ts`)

| Key | Pattern | Tenant-Scoped? |
|-----|---------|----------------|
| **PK** | `TENANT#<tenantId>` | ✅ Yes — tenantId is baked into PK |
| **SK** | `PRODUCT#<id>`, `INVOICE#<id>`, `CUSTOMER#<id>`, etc. | N/A (scoped by PK) |
| **GSI1PK** | Various: `EMAIL#<email>`, `ENTITY#<type>`, `AC_BATCH_STUDENTS#<tid>#<bid>` | ⚠️ Mixed |
| **GSI2PK** | `COGNITOSUB#<sub>` | ❌ Not tenant-scoped |
| **GSI3PK** | `TENANT#<tenantId>` (barcode) | ✅ Yes |

### Positive Findings

- **Primary key design is sound**: All tenant data lives under `TENANT#<tenantId>` PK, which means `queryItems(Keys.tenantPK(auth.tenantId), ...)` is **structurally incapable** of returning other tenants' data. This is the correct pattern.
- The `queryItems` function always starts from PK, ensuring tenant scoping at the key level.

### Risk Areas

- **GSI1 with `EMAIL#<email>`** — querying by email could return users from ANY tenant. This is used for login/lookup and is intentional, but must be audited to ensure cross-tenant data isn't returned in user-facing responses.
- **GSI2 with `COGNITOSUB#<sub>`** — similar cross-tenant lookup by Cognito user ID.
- **`ENTITY#<type>` GSI1PK** — some entity listing GSIs don't embed tenantId. If these are queried without a tenant filter, they could return cross-tenant data.

### Marketplace Table Schema (`lambda/shared/dynamodb.ts` + `types.ts`)

| Key | Pattern | Tenant-Scoped? |
|-----|---------|----------------|
| **PK** | `BUSINESS#<businessId>` | ✅ Scoped by businessId |
| **SK** | `PRODUCT#<id>`, `ORDER#<id>`, etc. | N/A |
| **GSI1PK** | `CATEGORY#<cat>`, `ORDER#STATUS#<status>` | ❌ **NOT tenant-scoped** |
| **GSI2PK** | `BRAND#<brand>`, `CUSTOMER#<custId>` | ❌ **NOT tenant-scoped** |

> [!WARNING]
> **GSI1 and GSI2 in the marketplace table are NOT tenant-scoped.** Querying `GSI1PK = CATEGORY#grocery` would return products from ALL businesses. This is a cross-tenant data leakage vector if any handler queries these GSIs without a tenant-scoped filter.

### SAM Template Tables (Non-Single-Table)

| Table | PK | Tenant Isolation |
|-------|-----|-----------------|
| `AuthSessionsTable` | `sessionId` | ❌ No tenantId in key |
| `TenantsTable` | `tenantId` | ✅ By definition |
| `UsersTable` | `tenantId#userId` | ✅ Composite key |
| `BillingTable` | `tenantId` (PK) + `SK` | ✅ Tenant-scoped |
| `AuditLogsTable` | `tenantId` (PK) + `SK` | ✅ Tenant-scoped |
| `CustomerInvoicesTable` | `PK` + `SK` | ⚠️ PK pattern unclear |
| `CustomerPaymentsTable` | `PK` + `SK` | ⚠️ PK pattern unclear |

### ⚠️ `BillingTable` GSI Risk

`GSI_BillingStatus` has PK = `status` and SK = `dueAt`. This is **NOT tenant-scoped**. Querying this GSI returns billing records across ALL tenants. If any handler uses this GSI for user-facing data, it's a cross-tenant leak.

---

## Finding #5 — 🟡 MEDIUM: S3 Tenant Isolation — Generally Sound with Caveats

### Positive

- `storageHandler/index.mjs` enforces `{tenantId}/{folder}/{filename}` key structure
- `validateKey()` function prevents path traversal (`..`, `//`)
- Presigned URLs are scoped to the tenant's key prefix

### Risk (Dependent on Finding #1)

If tenantId is spoofed via `x-tenant-id` header (Finding #1), the entire S3 scoping breaks — the attacker gets presigned URLs for the victim's S3 prefix.

---

## Finding #6 — 🟡 MEDIUM: Cache Key Isolation — Properly Scoped

### Analysis

Cache keys in `core/db/cache.ts` use `CacheKeys`:

```typescript
tenantConfig: (tenantId: string) => `tenant:config:${tenantId}`,
tenantPlan: (tenantId: string) => `tenant:plan:${tenantId}`,
tenantModules: (tenantId: string) => `tenant:modules:${tenantId}`,
productCatalog: (tenantId: string, page: number) => `catalog:${tenantId}:p${page}`,
```

**Positive**: All tenant-specific cache keys include `tenantId` in the key. Cache collision between tenants is not possible via this pattern.

**Risk**: The pharmacy WebSocket handler uses hardcoded cache key patterns like `pharmacy-inventory-status:${event.tenantId}` — these are also properly scoped. However, if `tenantId` is spoofed (Finding #1), cache poisoning is possible.

---

## Finding #7 — 🟡 MEDIUM: EventBridge/SNS Event Payloads

### Analysis

`eventbridge.service.ts` puts `businessId` in the event `Detail`:

```typescript
const detail: WSEventBridgeDetail = {
    businessId,  // This is the tenant/business ID
    event,
    data,
    targetAudience,
};
```

The `ws-broadcaster` Lambda (consumer) then queries DynamoDB for connections matching this `businessId` and broadcasts only to those connections.

**Risk**: If `businessId` in the event payload can be manipulated (e.g., by a compromised handler), the broadcaster could send events to the wrong tenant's WebSocket connections. However, since `businessId` comes from `auth.tenantId` in the handler (derived from JWT), this is **only exploitable if Finding #1 is present**.

---

## Finding #8 — 🟢 LOW: WebSocket Connection Isolation — Properly Scoped

### Analysis

`websocket.ts` handler:
1. Verifies JWT via `CognitoJwtVerifier` at `$connect` time
2. Extracts `tenantId` from `custom:tenant_id` JWT claim
3. Validates `businessId` ownership via DynamoDB lookup
4. Stores connection with `businessId` in DynamoDB
5. Broadcasting filters by `businessId`

**This is properly implemented.** The only risk is Finding #1 (header fallback) doesn't apply here since WebSocket uses query params, not headers, and the JWT is properly verified.

---

## Finding #9 — UNVERIFIABLE: SQS Consumer Tenant Validation

### Status: UNVERIFIABLE

The `process-import-row.ts` handler processes SQS messages. From test code (`import-pipeline.test.ts`), messages contain `tenantId` in the payload. However:

- **Cannot verify** whether the SQS consumer validates that the `tenantId` in the message matches the original authenticated context
- The SQS message could theoretically be poisoned with a different tenantId if the queue is not properly IAM-scoped

### Recommended Action

Add explicit tenantId validation in all SQS consumer Lambdas — compare message tenantId against the expected tenant context.

---

## Finding #10 — 🟡 MEDIUM: `handler-wrapper.ts` Cross-Tenant Detection is Excellent BUT Has a Gap

### Positive

The `detectCrossTenantAccess()` function in `handler-wrapper.ts` is **best-in-class**:
- Checks `x-tenant-id` header vs JWT ✅
- Checks query params (`tenantId`, `tenant_id`, `tid`) ✅
- Checks path params ✅
- Checks request body ✅
- **Recursively** checks nested objects up to depth 3 ✅
- Emits CloudWatch metric for alerting ✅

### Gap

This protection **only applies to handlers wrapped in `authorizedHandler()`**. The Lambda handlers in `lambda/` directory (storageHandler, batchHandler, tenantHandler, etc.) use their own auth flow (`verifyToken` from `shared/utils.mjs`) and **DO NOT** go through `authorizedHandler()`. These handlers are where Finding #1 exists.

---

## Summary Table

| # | Severity | Component | Finding | Status |
|---|----------|-----------|---------|--------|
| 1 | 🔴 P0 | storageHandler, batchHandler | `x-tenant-id` header fallback bypasses JWT tenantId | **MUST FIX** |
| 2 | 🔴 P0 | ac-admissions, pharmacy routes | Public endpoints accept raw `x-tenant-id` header | **MUST FIX** |
| 3 | 🟠 HIGH | lambda/shared/auth.ts | JWT decoded without signature verification | **MUST FIX** |
| 4 | 🟡 MED | Marketplace GSI1/GSI2 | GSIs not tenant-scoped (CATEGORY#, BRAND#) | Audit all queries |
| 5 | 🟡 MED | S3 | Sound design, depends on Finding #1 fix | Fix #1 first | **MUST FIX**
| 6 | 🟡 MED | Cache | Properly scoped, depends on Finding #1 fix | Fix #1 first |
| 7 | 🟡 MED | EventBridge | Payload trust depends on handler integrity | Fix #1 first |  **MUST FIX**
| 8 | 🟢 LOW | WebSocket | Properly scoped via JWT + DynamoDB | OK | **MUST FIX**
| 9 | ⚠️ UNVERIFIABLE | SQS consumers | Cannot confirm tenant validation | Manual audit | **MUST FIX**
| 10 | 🟡 MED | handler-wrapper.ts | Excellent detection, but Lambda handlers bypass it | Extend coverage | **MUST FIX**

---

## Architecture Diagram — Auth Flow (Two Systems)

```
┌─────────────────────────────────────────────────────────────────┐
│                        my-backend/                              │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐    │
│  │ JWT      │→ │ verifyAuth() │→ │ authorizedHandler()    │    │
│  │ Header   │  │ (cognito-    │  │ detectCrossTenantAccess│    │
│  │          │  │  auth.ts)    │  │ ✅ SECURE              │    │
│  └──────────┘  └──────────────┘  └────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        lambda/                                  │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐    │
│  │ JWT      │→ │ verifyToken()│→ │ decoded.tenantId       │    │
│  │ Header   │  │ (shared/     │  │   || event.headers     │    │
│  │          │  │  utils.mjs)  │  │   ['x-tenant-id']      │    │
│  │          │  │ ✅ VERIFIES  │  │ 🔴 FALLBACK BYPASS     │    │
│  └──────────┘  └──────────────┘  └────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## DynamoDB Single-Table Key Schema

```
Main Table (my-backend):
  PK: TENANT#<tenantId>          ← ✅ Tenant-scoped
  SK: PRODUCT#<id> | INVOICE#<id> | CUSTOMER#<id> | ...
  GSI1PK: EMAIL#<email> | ENTITY#<type> | ...    ← ⚠️ Mixed scoping
  GSI2PK: COGNITOSUB#<sub>                        ← ❌ Cross-tenant
  GSI3PK: TENANT#<tenantId>                       ← ✅ Scoped
  GSI4PK: TENANT#<tenantId>                       ← ✅ Scoped

Marketplace Table (lambda/):
  PK: BUSINESS#<businessId>      ← ✅ Business-scoped
  SK: PRODUCT#<id> | ORDER#<id> | ...
  GSI1PK: CATEGORY#<cat>         ← ❌ NOT business-scoped
  GSI2PK: BRAND#<brand>          ← ❌ NOT business-scoped
```
