# Jewellery Backend Endpoint Backlog

> **Created:** Phase 7, Task 14.2 (Requirement 16.3, 16.4)
>
> **Context:** All 9 `/jewellery/*` endpoints were classified as
> "deployed-non-stub (unverified server-side)" in Phase 0. The Flutter client
> actively calls these endpoints from sync code, but their backend deployment
> (Node.js Lambda + DynamoDB) cannot be confirmed from Flutter source alone.
>
> **Action required:** Each endpoint below must be verified on the backend. If
> absent, it must be built following the DukanX conventions:
> - Wrapped in `withRequestContext`
> - Tenant-scoped single-table DynamoDB items (partition key includes `tenantId`)
> - All money attributes stored as integer paise
> - RID-pattern entity identifiers

---

## Endpoint Status Table

| # | Endpoint Path | Flutter Caller | Sync Queue Entity | Backend Status | Action |
|---|---------------|----------------|-------------------|----------------|--------|
| 1 | `POST /jewellery/products` | `jewellery_repository_offline.dart` `_syncProduct()` | `product` | **UNVERIFIED** | Verify or build Lambda |
| 2 | `POST /jewellery/gold-rate` | `jewellery_repository_offline.dart` `_syncGoldRate()` | `gold_rate` | **UNVERIFIED** | Verify or build Lambda |
| 3 | `POST /jewellery/old-gold-exchange` | `jewellery_repository_offline.dart` `_syncOldGoldExchange()` | `old_gold_exchange` | **UNVERIFIED** | Verify or build Lambda |
| 4 | `POST /jewellery/custom-orders` | `jewellery_repository_offline.dart` `_syncOrder()` | `jewellery_order` | **UNVERIFIED** | Verify or build Lambda |
| 5 | `POST /jewellery/hallmark-inventory` | `jewellery_repository_offline.dart` `_syncHallmark()` | `hallmark` | **UNVERIFIED** | Verify or build Lambda |
| 6 | `POST/PUT /jewellery/gold-rate-alerts` | `gold_rate_alert_repository.dart` `_syncAlert()` | `gold_rate_alert` | **UNVERIFIED** | Verify or build Lambda |
| 7 | `POST/PUT /jewellery/gold-schemes` | `gold_scheme_repository.dart` `_syncScheme()` | `gold_scheme` | **UNVERIFIED** | Verify or build Lambda |
| 8 | `POST /jewellery/making-charges-configs` | `making_charges_repository.dart` `_syncConfig()` | `making_charges` | **UNVERIFIED** | Verify or build Lambda |
| 9 | `POST/PUT /jewellery/repairs` | `jewellery_repair_repository.dart` `_syncRepair()` | `jewellery_repair` | **UNVERIFIED** | Verify or build Lambda |

---

## Backend Build Requirements (per endpoint)

Each new Lambda endpoint MUST:

1. **Wrap in `withRequestContext`** — the standard DukanX request-context middleware
   that extracts `tenantId`, `userId`, and enforces authentication.

2. **Use tenant-scoped single-table design** — DynamoDB partition key includes
   `tenantId` (e.g., `PK: TENANT#{tenantId}#JEWELLERY_PRODUCT#{id}`).

3. **Store money as integer paise** — no `float`/`double` for currency attributes.

4. **Accept and return a `version` field** — the Flutter client uses version-based
   reconciliation (Requirement 14.4). The server must:
   - Accept `version` from the client payload.
   - Compare with the stored server version.
   - Return the current `serverVersion` in the response body.
   - Reject stale writes (client version < server version) with a conflict response.

5. **Return appropriate HTTP status codes**:
   - `200` — success (create/update)
   - `404` — entity not found
   - `409` — version conflict (client has stale data)
   - `400` — validation error

---

## Sync-Failure Handling (Requirement 16.4)

**Already implemented in Phase 5 (Task 10.5):**

If any `/jewellery/*` endpoint returns an error (including 404 for a missing endpoint),
the Flutter sync layer handles it as follows:

1. The sync method (`_syncProduct`, `_syncGoldRate`, etc.) throws on any non-success response.
2. `syncAll()` catches the exception and increments `retryCount` on the sync-queue entry.
3. After 5 failed retries, the entry is marked `failedPermanently: true` and
   `syncFailed: true` — never discarded.
4. The associated local record is annotated with `syncFailed` state via
   `_markLocalRecordSyncFailed()`.
5. `SyncResult.hasFailedSyncIndication` returns `true`, surfacing the failure to the UI.

**Result:** A missing endpoint does NOT silently leave records unsynced. The vendor sees
a failed-sync indication after the retry cap is exhausted.

---

## Priority

- **P0 (must have for launch):** Endpoints 1–5 (products, gold-rate, old-gold-exchange,
  custom-orders, hallmark-inventory) — these are the core jewellery CRUD paths.
- **P1 (should have):** Endpoints 6–9 (alerts, schemes, making-charges, repairs) —
  secondary domain features that degrade gracefully to local-only without sync.

---

## Notes

- The Flutter client is complete and correct for all 9 endpoints (offline-first with
  retry + failed-sync indication).
- Backend verification/build is outside the Flutter app remediation scope.
- This backlog item is tracked here and does not block Phase 7 completion for the
  Flutter app.
