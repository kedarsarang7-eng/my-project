# Phase 6 — Endpoint Confirmation Record

## Task 13.7: Confirm or Feature-Flag Absent `/clothing/*` Sync Endpoints

**Requirements validated:** 12.9, 2.3  
**Phase 0 Finding Reference:** 3.7 (Backend Response Shape)

---

## Confirmed Endpoints (sync path dependencies)

The `ClothingRepositoryOffline` sync queue (Task 13.1) drains via the following `/clothing/*` endpoints. Each is cross-referenced against the Phase 0 verification report (finding 3.7) and the backend deployment manifest (`serverless.yml`).

| # | Endpoint | Method | Phase 0 Status | serverless.yml Function | Handler File + Lines | Sync Operation |
|---|----------|--------|---------------|------------------------|---------------------|----------------|
| 1 | `/clothing/variants/{productId}` | GET | deployed-non-stub | `clothingGetVariants` | `handlers/clothing.ts` L24–46 | Variant read / inventory load |
| 2 | `/clothing/variants/bulk` | PUT | deployed-non-stub | `clothingBulkUpdateVariants` | `handlers/clothing.ts` L51–103 | Bulk variant create/update (grid save) |
| 3 | `/clothing/tailoring-notes` | POST | deployed-non-stub | `clothingCreateTailoringNote` | `handlers/clothing.ts` L120–187 | Create tailoring measurement |
| 4 | `/clothing/tailoring-notes` | GET | deployed-non-stub | `clothingListTailoringNotes` | `handlers/clothing.ts` L321–367 | List tailoring notes |
| 5 | `/clothing/tailoring-notes/{tailoringId}` | GET | deployed-non-stub | `clothingGetTailoringNote` | `handlers/clothing.ts` L190–205 | Get specific tailoring note |
| 6 | `/clothing/tailoring-notes/{tailoringId}/status` | PUT | deployed-non-stub | `clothingUpdateTailoringStatus` | `handlers/clothing.ts` L208–271 | Update tailoring status |
| 7 | `/clothing/tailoring-notes/{tailoringId}/measurements` | PUT | deployed-non-stub | `clothingUpdateTailoringMeasurements` | `handlers/clothing.ts` L274–318 | Update tailoring measurements |
| 8 | `/clothing/variants/{variantId}/barcode` | PUT | deployed-non-stub | `clothingAssignBarcodeToVariant` | `handlers/clothing.ts` L370–433 | Assign barcode to variant |
| 9 | `/clothing/barcode/{barcode}` | GET | deployed-non-stub | `clothingGetVariantByBarcode` | `handlers/clothing.ts` L436–end | Barcode → variant lookup (scanner) |

**All 9 endpoints above are CONFIRMED as deployed and non-stub.** They fully cover the sync path for:
- Variant CRUD (read via GET, create/update via PUT bulk)
- Tailoring notes full lifecycle (create, read, list, update status, update measurements)
- Barcode assignment and lookup

---

## Absent Endpoint — Feature-Flagged

| # | Endpoint | Method | Status | Consumer |
|---|----------|--------|--------|----------|
| 10 | `/clothing/variants/{variantId}/stock` | PUT | **NOT DEPLOYED** | `VariantRepository.sizeSwapExchange()` |

### Analysis

The `sizeSwapExchange` method in `lib/features/clothing/data/variant_repository.dart` (lines 191–320) calls:
- `PUT /clothing/variants/$issuedVariantId/stock` — to decrement issued variant stock
- `PUT /clothing/variants/$returnedVariantId/stock` — to increment returned variant stock
- Same endpoint for rollback on failure

**This endpoint does not exist:**
- Not present in `my-backend/src/handlers/clothing.ts` — no `stock`-specific handler is defined
- Not registered in `serverless.yml` — no `clothingUpdateVariantStock` function exists
- No route matching `/clothing/variants/{variantId}/stock` is deployed

**Impact:** The size-swap exchange (Requirement 11.5–11.7) will always fail at runtime because the endpoint returns 404. The exchange was implemented in Task 11.5 assuming this endpoint existed or would be created, but Requirement 2.3 states: "THE Clothing_System SHALL NOT create any new backend endpoint."

### Resolution: Feature-flagged behind `clothing_size_swap_exchange`

Per Requirement 12.9 and 2.3, the exchange feature is placed behind a feature flag (`clothing_size_swap_exchange`) rather than failing silently or creating a new endpoint:

- **Feature flag key:** `clothing_size_swap_exchange`
- **Default state:** disabled (false)
- **Checked via:** `FeatureFlagService.isEnabled('clothing_size_swap_exchange')`
- **Behavior when disabled:** `sizeSwapExchange()` returns a `Left(FeatureNotAvailableFailure(...))` immediately without attempting any API call
- **Behavior when enabled:** proceeds with the stock endpoint calls as currently implemented
- **Activation path:** when the backend `PUT /clothing/variants/{variantId}/stock` endpoint is deployed, the feature flag can be enabled via the license/plan system

This approach:
1. Prevents silent failure (the user gets an explicit "feature not available" message)
2. Creates no new backend endpoint (Requirement 2.3 satisfied)
3. Preserves the exchange implementation for future activation
4. Uses the existing `FeatureFlagService` infrastructure

---

## No New Endpoint Confirmation (Requirement 2.3)

Per Requirement 2.3: "THE Clothing_System SHALL NOT create any new backend endpoint, and SHALL only add or adjust an endpoint where it is required to satisfy an API contract already referenced by an existing clothing screen."

**Confirmation:** No new endpoint is created by this task. The 9 confirmed endpoints fully satisfy all existing clothing-screen API contracts for the sync path (variant CRUD, tailoring CRUD, barcode operations). The one absent endpoint (`/clothing/variants/{variantId}/stock`) is feature-flagged rather than created, deferring the exchange sync capability until the backend team deploys the handler.

---

## Summary

| Category | Count | Status |
|----------|-------|--------|
| Endpoints confirmed (deployed-non-stub) | 9 | ✅ All sync path dependencies satisfied |
| Endpoints absent (feature-flagged) | 1 | ⚠️ `PUT /clothing/variants/{variantId}/stock` — exchange behind flag |
| New endpoints created | 0 | ✅ Requirement 2.3 honored |

---

*Recorded as part of Phase 6 (Requirement 12, Task 13.7). Requirements validated: 12.9, 2.3.*
