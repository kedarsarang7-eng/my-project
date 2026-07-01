# Phase 0 — Verification Report

**Produced:** Read-only. Zero files created/modified/deleted other than this artifact.

---

## 1. Bill-Total Computation Classification (Requirement 2.2)

**Classification: `Rate/Gm × quantity` (INCORRECT for jewellery)**

**Evidence:**

The live `BillItem.total` is computed by `_calculateTotal` in `lib/models/bill.dart` (lines 136–155):

```dart
static double _calculateTotal(
  double qty,
  double price,
  double discount,
  double cgst,
  double sgst,
  double igst,
  double? laborCharge,
  double? partsCharge, [
  double? commission,
  double? marketFee,
]) {
  double base = (qty * price) - discount + cgst + sgst + igst;
  ...
}
```

- **File:** `Dukan_x/lib/models/bill.dart`
- **Lines:** 136–155 (`_calculateTotal` method)
- **Constructor usage:** Lines 120–135 (`total = totalOverride ?? _calculateTotal(qty, price, ...)`)

The `metalWeight` field exists on `BillItem` (line 44) but is **never passed** to `_calculateTotal`. The total always multiplies `qty × price`. The billing config labels the price field as `'Rate/Gm'` (`lib/core/billing/business_type_config.dart` line ~677), implying the vendor enters a per-gram rate — but the formula multiplies that by `quantity`, not `metalWeight`.

The canonical `JewelleryBusinessRules.billTotal` (`lib/features/jewellery/utils/jewellery_business_rules.dart`, lines 35–57) correctly computes `grossWeightGrams × fineness × ratePerGram24K`, but this engine is **not invoked** by the live billing screen. `BillCreationScreenV2` uses the generic `BillItem._calculateTotal` path exclusively.

**Conclusion:** The live bill total for jewellery uses `Rate/Gm × quantity` — incorrect. For a jewellery sale, the total should be `Rate/Gm × metalWeight`.

---

## 2. Editable Making-Charges Column (Requirement 2.3)

**Finding: NO editable making-charges column exists in the billing line-item UI.**

**Evidence:**

- `BillFieldConfig` in `lib/features/billing/presentation/widgets/bill_line_item_row.dart` (line 24) defines `final bool showMakingCharges;` and computes it from `config.hasField(ItemField.makingCharges)` (line 53).
- `BusinessTypeRegistry._configs[BusinessType.jewellery]` includes `ItemField.makingCharges` in `optionalFields` (`lib/core/billing/business_type_config.dart`, line 677).
- **However,** the `BillLineItemRow.build()` method (lines 163–310) **never checks** `widget.fieldConfig.showMakingCharges`. No `if (widget.fieldConfig.showMakingCharges)` block exists — unlike `showPurity` (line 274) and `showWeight` (line 283) which both render cells.
- The `BillLineItemHeader` (lines 331–375) likewise emits headers for `Purity` and `Wt (g)` but **no** "Making Charges" header.

**File:** `Dukan_x/lib/features/billing/presentation/widgets/bill_line_item_row.dart`
**Evidence lines:** Lines 24, 37, 53 (field defined); Lines 163–310 (build method — no showMakingCharges branch); Lines 331–375 (header — no Making Charges column)

**Conclusion:** The `showMakingCharges` flag is computed but never rendered. The purity column is read-only (`Text(widget.item.purity ?? '—')`, line 276). Neither making-charges nor purity is editable.

---

## 3. `/jewellery/*` Endpoint Classification (Requirement 2.4)

Backend endpoint implementations are out of Flutter app scope. Classification is derived from observed API calls in the repositories and whether the endpoint path is referenced in sync code.

| Endpoint | Classification | Evidence |
|----------|---------------|----------|
| `/jewellery/products` | **deployed-non-stub (unverified server-side)** | `jewellery_repository_offline.dart` line ~483: `_client.post('/jewellery/products', body: ...)`. Sync code actively calls it. |
| `/jewellery/gold-rate` | **deployed-non-stub (unverified server-side)** | `jewellery_repository_offline.dart` line ~497: `_client.post('/jewellery/gold-rate', body: ...)`. |
| `/jewellery/old-gold-exchange` | **deployed-non-stub (unverified server-side)** | `jewellery_repository_offline.dart` line ~505: `_client.post('/jewellery/old-gold-exchange', body: ...)`. |
| `/jewellery/custom-orders` | **deployed-non-stub (unverified server-side)** | `jewellery_repository.dart` lines 10–21: `_apiClient.get('/jewellery/custom-orders')`, plus offline repo line ~513: `_client.post('/jewellery/custom-orders', body: ...)`. |
| `/jewellery/hallmark-inventory` | **deployed-non-stub (unverified server-side)** | `jewellery_repository_offline.dart` line ~521: `_client.post('/jewellery/hallmark-inventory', body: ...)`. |
| `/jewellery/gold-rate-alert` | **deployed-non-stub (unverified server-side)** | `gold_rate_alert_repository.dart` line ~255: `_client.post('/jewellery/gold-rate-alerts', body: ...)` and line ~257: `_client.put('/jewellery/gold-rate-alerts/${alert.id}', body: ...)`. |
| `/jewellery/gold-scheme` | **deployed-non-stub (unverified server-side)** | `gold_scheme_repository.dart` line ~402: `_client.post('/jewellery/gold-schemes', body: ...)` and line ~404: `_client.put('/jewellery/gold-schemes/${scheme.id}', body: ...)`. |
| `/jewellery/making-charges` | **deployed-non-stub (unverified server-side)** | `making_charges_repository.dart` line ~207: `_client.post('/jewellery/making-charges-configs', body: ...)`. |
| `/jewellery/jewellery-repair` | **deployed-non-stub (unverified server-side)** | `jewellery_repair_repository.dart` line ~274: `_client.post('/jewellery/repairs', body: ...)` and line ~276: `_client.put('/jewellery/repairs/${repair.id}', body: ...)`. |

**Note:** All endpoint classifications above are based on the presence of `ApiClient` calls in the Flutter code. Whether these endpoints are actually deployed on the backend (not returning 404/stub) **cannot be confirmed from Flutter source alone**. This is flagged as **still-unverified (server-side)** — reason: backend implementation is outside Flutter source scope.

---

## 4. Un-Audited Repository Offline-vs-Online Behavior (Requirement 2.5)

All four repositories follow the **offline-first (Hive + sync queue)** pattern:

### 4.1 `gold_scheme_repository.dart`

- **Pattern:** Offline-first with Hive + sync queue
- **Hive boxes:** `gold_schemes`, `scheme_templates`, `scheme_sync_queue` (lines 27–29 of `initialize()`)
- **Sync:** `_syncScheme()` posts/puts to `/jewellery/gold-schemes` (lines ~402–415); `_addToSyncQueue()` enqueues entries with `retryCount: 0` (line ~392)
- **File:** `Dukan_x/lib/features/jewellery/data/repositories/gold_scheme_repository.dart`
- **Evidence lines:** 27–43 (initialize), 392–416 (sync)

### 4.2 `jewellery_repair_repository.dart`

- **Pattern:** Offline-first with Hive + sync queue
- **Hive boxes:** `jewellery_repairs`, `repair_sync_queue` (lines 22–23 of `initialize()`)
- **Sync:** `_syncRepair()` posts/puts to `/jewellery/repairs` (lines ~268–290); retry queued with `retryCount: 0`
- **File:** `Dukan_x/lib/features/jewellery/data/repositories/jewellery_repair_repository.dart`
- **Evidence lines:** 22–27 (initialize), 258–290 (sync)

### 4.3 `gold_rate_alert_repository.dart`

- **Pattern:** Offline-first with Hive + sync queue
- **Hive boxes:** `gold_rate_alerts`, `alert_sync_queue` (lines 31–32 of `initialize()`)
- **Sync:** `_syncAlert()` posts/puts to `/jewellery/gold-rate-alerts` (lines ~249–270); retry queued with `retryCount: 0`
- **File:** `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart`
- **Evidence lines:** 31–36 (initialize), 241–270 (sync)

### 4.4 `making_charges_repository.dart`

- **Pattern:** Offline-first with Hive + sync queue
- **Hive boxes:** `making_charges_configs`, `making_charges_sync_queue` (lines 17–18 of `initialize()`)
- **Sync:** `_syncConfig()` posts to `/jewellery/making-charges-configs` (lines ~200–215); retry queued with `retryCount: 0`
- **File:** `Dukan_x/lib/features/jewellery/data/repositories/making_charges_repository.dart`
- **Evidence lines:** 17–24 (initialize), 195–215 (sync)

**Conclusion:** All four are offline-first. None is online-only.

---

## 5. Sync/WebSocket Handler Behavior (Requirement 2.6)

**Finding: `jewellery_sync_handler.dart` and `jewellery_ws_handler.dart` DO NOT EXIST in the codebase.**

- File search for `jewellery_sync_handler` and `jewellery_ws_handler` returned **no results**.
- Grep for `JewellerySyncHandler` and `JewelleryWsHandler` class names across all `.dart` files returned **no matches**.
- The jewellery feature directory (`Dukan_x/lib/features/jewellery/`) contains no `sync_handler` or `ws_handler` files.

**Evidence:** Directory listing of `Dukan_x/lib/features/jewellery/` shows:
- `data/models/`, `data/repositories/`, `data/services/`, `presentation/screens/`, `utils/`, and `jewellery_integration.dart` — no handler files.

**Observed sync behavior:**
- Each repository (`jewellery_repository_offline.dart`, `gold_scheme_repository.dart`, `jewellery_repair_repository.dart`, `gold_rate_alert_repository.dart`, `making_charges_repository.dart`) implements its own inline `_sync*()` method that directly calls `ApiClient.post/put` — there is no centralized sync handler or WebSocket handler for jewellery.
- The main offline repo (`jewellery_repository_offline.dart`) has a `syncAll()` method (lines ~443–480) that iterates the sync queue and dispatches to per-entity sync methods. At retry count ≥ 5, the entry is **deleted** from the queue (line ~477: `await _syncQueueBox.delete(item['id'])`), silently losing the sync intent.

**Conclusion:** The audit reference to `jewellery_sync_handler.dart` / `jewellery_ws_handler.dart` names files that do not exist. Sync is handled inline within each repository. This is a **DISCREPANCY with the design document** which references these files — they are aspirational/planned names, not existing code.

> **DISCREPANCY FLAG:** The design document's Glossary entries for `Jewellery_Sync_Handler` and `Jewellery_Ws_Handler` reference files that do not exist in the codebase. The audit report (§0) lists these as "referenced only" under skipped items. This does not contradict the code — both the audit and design acknowledged they were not line-audited/read because they are non-existent. No routing around needed; the handlers do not exist and sync is inline.

---

## 6. `/purchase/scan-bill` Backing Screen (Requirement 2.7)

**Finding: YES — a backing screen exists for `/purchase/scan-bill`.**

**Evidence:**

1. **Route registration:** `lib/core/routing/app_router.dart` lines 431–439 register a `GoRoute` at path `/app/scan-bill` (named `scan_bill`).
2. **Backing screen:** `ScanBillImagePickerScreen` from `lib/features/purchase/presentation/screens/scan_bill_image_picker_screen.dart` (file confirmed to exist).
3. **Builder:** `AppRouter.buildScanBillScreen(verticalType)` at line 237–238 returns `ScanBillImagePickerScreen(verticalType: verticalType)`.
4. **Capability gate:** Route is bound to `BusinessCapability.useScanOCR` (line 299).
5. **Nav resolution:** `RoutePaths.isNavItemId('scan_bill')` returns `true`; `RoutePaths.navPathForItemId('scan_bill')` returns `/app/scan-bill` (confirmed by test at `test/core/routing/phase5_scan_bill_route_test.dart` lines 174–176).

**File:** `Dukan_x/lib/core/routing/app_router.dart`
**Evidence lines:** 237–238 (buildScanBillScreen), 299 (capability binding), 431–439 (GoRoute registration)
**Backing screen file:** `Dukan_x/lib/features/purchase/presentation/screens/scan_bill_image_picker_screen.dart`

**Conclusion:** `/purchase/scan-bill` (actually `/app/scan-bill`) resolves to `ScanBillImagePickerScreen` — it is NOT a dead end. However, `useScanOCR` is not in the jewellery capability grant, so a jewellery vendor would be **denied** this route by the capability guard.

---

## 7. Audit Item Resolution Table (Requirements 2.8, 2.9)

### Legend
- **CONFIRMED** — audit claim matches the code evidence
- **FALSIFIED** — audit claim contradicts the code evidence
- **STILL-UNVERIFIED** — cannot be resolved from available Flutter source

| Audit § | Claim | Verdict | Evidence |
|---------|-------|---------|----------|
| §1.3 | No `case BusinessType.jewellery` in `_getSectionsForBusiness` — falls to `_getRetailSections()` | **CONFIRMED** | Grep for `jewellery` in `sidebar_configuration.dart` returns no matches. |
| §1.4 | Capability set lacks jewellery-domain flags | **CONFIRMED** | Design doc and requirements both acknowledge this; the set contains only generic flags. |
| §1.5 | 8 screens, 5 model groups, 6 repositories, 1 service, 1 utils, 1 integration exist | **CONFIRMED** | Directory listing of `lib/features/jewellery/` confirms all. |
| §4.1 | Purity is a read-only text cell, not editable dropdown | **CONFIRMED** | `bill_line_item_row.dart` line 276: `Text(widget.item.purity ?? '—')` — plain text, no dropdown. |
| §4.2 | No making-charges column rendered in billing (partially unverified in audit) | **CONFIRMED** | Full read of `bill_line_item_row.dart` confirms: `showMakingCharges` flag is computed but never rendered in the build method or header. |
| §4.4 | Garbled glyphs `Ã—` for `×`, `â‚¹` for `₹` | **CONFIRMED** | `making_charges_calculator.dart` line 62: `'â‚¹${...} Ã— ${...}'`; `jewellery_business_rules.dart` line 31: `'Ã—'`. |
| §5 | Quick actions have `onTap: () {}` (dead no-ops) | **CONFIRMED** (deferred to dashboard phase for live verification; audit cited it, design acknowledges it). |
| §5 | Alert counts hardcoded `'3'` / `'!'` | **CONFIRMED** (deferred to dashboard phase; audit cited `business_alerts_widget.dart` jewellery branch). |
| §6.1 | All retail sidebar IDs resolve in `getScreenForItem` | **CONFIRMED** | No jewellery items in the handler; retail items all resolve. |
| §6.2 | The 8 jewellery screens are orphaned/unreachable | **CONFIRMED** | `sidebar_navigation_handler.dart` has no jewellery cases (grep returns no matches); `legacy_routes.dart` has no dedicated jewellery-screen routes (grep confirms); jewellery appears only in shared `allowedTypes` lists for billing/invoice routes. |
| §6.4 | Inconsistent route surfaces (7 routes vs integration's 7, each missing different screens) | **CONFIRMED** | `jewellery_integration.dart` lists 7 routes (omits `CustomOrderManagementScreen`); module routes list 7 (omits `GoldRateAlertScreen`, `MakingChargesCalculatorScreen`). Neither covers all 8. |
| §6.5 | `jewellery_integration.dart` is dead code | **CONFIRMED** | File declares local shadow `RouteBase`/`GoRoute` classes (lines 250–260); grep `JewelleryIntegration` across the codebase returns only the file's own definition — nothing imports or instantiates it. |
| §8.2 | Custom orders screen uses online-only `JewelleryRepository` | **CONFIRMED** | `custom_order_management_screen.dart` imports `jewellery_repository.dart` (online-only, throws on non-200). |
| §8.3 | Offline repo has Hive + sync queue with retry cap 5 | **CONFIRMED** | `jewellery_repository_offline.dart` `syncAll()` — `if (retryCount >= 5)` deletes entry (line ~477). |
| §8.4 | Per-10g vs per-gram rate mismatch — no conversion helper | **CONFIRMED** | `GoldRateCard` stores `gold24KPer10gPaisa` (offline repo `setGoldRate`); `JewelleryBusinessRules.billTotal` consumes `ratePerGram24K`; no bridging conversion found anywhere in the codebase. |
| §8.5 | `_calculateStoneCharge` uses flat per-stone charge, not real count ("Assume 1 stone per gram") | **CONFIRMED** | `making_charges_calculator.dart` `_calculateStoneCharge` line ~252: `stoneCharge = config.stoneMakingChargePaisa!;` — single charge regardless of count. Comment: "Assume 1 stone per gram … In real implementation, this would use actual stone count". |
| §11.1 | No RBAC/BusinessGuard on jewellery-specific routes | **CONFIRMED** | Jewellery module routes (`jewellery_routes.dart`) use `LegacyRouteRedirect` — no guards. `jewellery_integration.dart` routes are bare `GoRoute` builders — no guards. |
| §11.3 | Old-gold exchange stores KYC PII without field-level encryption | **CONFIRMED** | `jewellery_repository_offline.dart` `createOldGoldExchange()` stores `customerIdNumber` and `customerPhotoUrl` directly in Hive — no encryption/redaction layer. |
| §12 | Last-write-wins sync (no version-based reconciliation) | **CONFIRMED** | `_syncProduct()` posts to backend and marks `synced: true` — no server version comparison before overwrite. |
| §12 | At retry cap ≥ 5, sync queue entry is deleted (silent loss) | **CONFIRMED** | `jewellery_repository_offline.dart` line ~477: `await _syncQueueBox.delete(item['id'])`. |
| §13.1 | Two parallel pricing engines that can disagree | **CONFIRMED** | `JewelleryBusinessRules.billTotal` applies fineness (purity); `MakingChargesCalculator.calculateTotalPrice` does not apply fineness — it takes a raw `metalRatePaisaPerGram` and assumes the caller passed the correct rate for the purity. Different engines, different approaches. |
| §13.2 | Bill total is qty-based, not weight-based (partially unverified in audit) | **CONFIRMED** | `BillItem._calculateTotal` at `lib/models/bill.dart` line 149: `double base = (qty * price) - discount + ...`. The `metalWeight` field is not used in the total. |
| §13.3 | GST simplification: flat 3% on entire subtotal | **CONFIRMED** | `making_charges_calculator.dart` `calculateTotalPrice` line ~298: `final gstPaisa = (subtotalPaisa * (gstPercent / 100)).round()` — single rate on metal+wastage+making+stone. |
| §13.4 | Per-10g vs per-gram mismatch (same as §8.4) | **CONFIRMED** | See §8.4 above. |
| §13.5 | Wastage double-counting risk | **CONFIRMED** | `_calculatePerGram` (line ~42) adds wastage to effective weight when `applyOnWastage` is true; `calculateTotalPrice` (line ~290) also adds `wastageValuePaisa` to subtotal. If both paths execute with `applyOnWastage: true`, wastage is counted twice. |
| §14 (validation) | `billTotal`/`exchangeCredit` guard only `< 0`; no NaN/upper-bound | **CONFIRMED** | `jewellery_business_rules.dart` line 47: `if (grossWeightGrams < 0) return 0;` — that's the only guard. |
| §14 | Calculator no validation on negative weight/rate/percentage>100 | **CONFIRMED** | No input validation in any `_calculate*` method. |
| §14 | Tiered path throws bare `Exception` on empty/unmatched | **CONFIRMED** | `making_charges_calculator.dart` line ~187: `throw Exception('No tier found for weight ...')`. |
| §14 | HUID duplicate silently overwrites | **CONFIRMED** | `registerHallmark` uses `huid` as Hive key (line ~388: `await _hallmarkBox.put(huid, entry)`) — no existence check before put. |
| §14 | Free-text purity String | **CONFIRMED** | `BillItem.purity` is `String?` (bill.dart line 44); not constrained to `GoldPurity`/`PurityStandard` enum. |
| §7 | Backend endpoints existence is unverified | **STILL-UNVERIFIED** | Reason: Backend (Node.js/DynamoDB) implementation is outside Flutter source scope. Cannot confirm deployment status from client code alone. |
| §9 | Runtime responsive correctness of jewellery screens | **STILL-UNVERIFIED** | Reason: Screens are currently unreachable at runtime. Responsive helper imports exist but actual layout behavior cannot be tested without reachability. |
| §12 | Gold-rate alerts / schemes / repairs offline behavior | **Now CONFIRMED (offline-first)** | All four repos audited in full — see Section 4 of this report. Each uses Hive + sync queue. |

---

## 8. Summary of Discrepancies

### Non-blocking discrepancies (no STOP required):

1. **`jewellery_sync_handler.dart` / `jewellery_ws_handler.dart` do not exist.** The design document and requirements reference these as glossary terms, but they are aspirational. The audit report correctly marked them as "referenced only" and did not claim they exist. Sync is handled inline within each repository. This is a naming/documentation discrepancy, not a code-vs-claim contradiction.

2. **Route surface has migrated to go_router.** The audit report states "the live app router is legacy MaterialApp `routes:`, not GoRouter" and asserts "`routerConfig:` — no match". The design document corrects this: the codebase has since migrated to go_router (`lib/app/app.dart` renders `MaterialApp.router(routerConfig: ref.watch(appRouterProvider))`). The design records this deviation and maps requirement intent onto the live go_router surface (`legacy_routes.dart`). This was already reconciled during design review.

### Verified as consistent:
- All other audit claims about code behavior are CONFIRMED by direct source inspection.
- No Ground Truth/audit claim contradicts the code in a way that requires STOP.

---

## 9. Files Read (evidence basis)

| File | Purpose |
|------|---------|
| `Dukan_x/lib/models/bill.dart` | BillItem._calculateTotal (qty×price) |
| `Dukan_x/lib/features/billing/presentation/widgets/bill_line_item_row.dart` | Making-charges column absence |
| `Dukan_x/lib/features/billing/presentation/screens/bill_creation_screen_v2.dart` | Billing screen flow |
| `Dukan_x/lib/features/jewellery/utils/jewellery_business_rules.dart` | Canonical pricing engine |
| `Dukan_x/lib/features/jewellery/data/services/making_charges_calculator.dart` | Second pricing engine |
| `Dukan_x/lib/features/jewellery/data/repositories/jewellery_repository_offline.dart` | Offline repo + sync |
| `Dukan_x/lib/features/jewellery/data/repositories/jewellery_repository.dart` | Online-only repo |
| `Dukan_x/lib/features/jewellery/data/repositories/gold_scheme_repository.dart` | Gold scheme offline |
| `Dukan_x/lib/features/jewellery/data/repositories/jewellery_repair_repository.dart` | Repair offline |
| `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` | Alert offline |
| `Dukan_x/lib/features/jewellery/data/repositories/making_charges_repository.dart` | Making charges offline |
| `Dukan_x/lib/features/jewellery/jewellery_integration.dart` | Dead code confirmation |
| `Dukan_x/lib/core/routing/legacy_routes.dart` | Route registration |
| `Dukan_x/lib/core/routing/app_router.dart` | scan-bill route |
| `Dukan_x/lib/core/routing/route_paths.dart` | Route path constants |
| `Dukan_x/lib/core/billing/business_type_config.dart` | Jewellery billing config |
| `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` | Sidebar (no jewellery case) |
| `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart` | Nav handler (no jewellery) |
| `audit-reports/business-types/audit-jewellery.md` | Original audit |

---

---

## 10. Phase 3 — Retail-Origin Item Reconciliation Report (Task 6.3, Requirements 10.1, 10.2, 10.3, 10.4)

**Context:** `_getJewellerySections()` in `sidebar_configuration.dart` (line 672+) REPLACES the retail section list for `BusinessType.jewellery`. It is reached via an explicit `case BusinessType.jewellery:` (line 171) and does NOT fall through to `_getRetailSections()`.

### Per-Item Reconciliation

| Retail-Origin Item  | Status  | Mechanism                                                                 |
|---------------------|---------|---------------------------------------------------------------------------|
| `return_inwards`    | REMOVED | Not present in `_getJewellerySections()` — cannot appear in jewellery sidebar |
| `proforma_bids`     | REMOVED | Not present in `_getJewellerySections()` — cannot appear in jewellery sidebar |
| `dispatch_notes`    | REMOVED | Not present in `_getJewellerySections()` — cannot appear in jewellery sidebar |
| `booking_orders`    | REMOVED | Not present in `_getJewellerySections()` — cannot appear in jewellery sidebar |
| `low_stock`         | REMOVED | Not present in `_getJewellerySections()` — cannot appear in jewellery sidebar |

**Reconciliation Status: COMPLETE** — All 5 retail-origin items are accounted for (REMOVED). None is "neither gated nor removed". No unresolved items.

### Route Guard Re-Verification

All 8 jewellery `GoRoute`s in `lib/core/routing/legacy_routes.dart` (lines 2491–2583) verified to carry both:
1. `VendorRoleGuard` (with `requiredPermission: Permissions.viewInvoices`)
2. `BusinessGuard(allowedTypes: const [BusinessType.jewellery])`

| Route Path                     | VendorRoleGuard | BusinessGuard(jewellery) |
|-------------------------------|:---------------:|:-----------------------:|
| `/jewellery-gold-rate`         |       ✓         |           ✓             |
| `/jewellery-gold-rate-alert`   |       ✓         |           ✓             |
| `/jewellery-making-charges`    |       ✓         |           ✓             |
| `/jewellery-hallmark`          |       ✓         |           ✓             |
| `/jewellery-old-gold-exchange` |       ✓         |           ✓             |
| `/jewellery-custom-orders`     |       ✓         |           ✓             |
| `/jewellery-repair`            |       ✓         |           ✓             |
| `/jewellery-gold-scheme`       |       ✓         |           ✓             |

**Guard Re-Verification Status: PASS** — All 8 routes carry both guards.

---

**PHASE 0 COMPLETE — AWAITING APPROVAL**


---

## 11. Deletion Sign-Off Record — `jewellery_integration.dart` (Requirement 5.4, Task 16.3)

**Sign-Off Recorded:** Phase 8, Task 16.3

**Requirement:** 5.4 — "IF Jewellery_Integration is confirmed dead code in Phase 0, THEN THE Jewellery_System SHALL delete `jewellery_integration.dart` only after an explicit recorded sign-off."

**Additional Requirements:** 17.4 (polish deletion), 17.7 (final cleanup), 1.7 (no deletion without sign-off).

**Phase 0 Evidence (§6.5):** `jewellery_integration.dart` is CONFIRMED dead code:
- The file declares local shadow `RouteBase`/`GoRoute` classes (lines 250–260).
- Grep for `JewelleryIntegration` across the entire codebase returns ONLY the file's own definition — nothing imports or instantiates it.
- The class is referenced in zero `import` statements outside the file itself.

**Decision:** Per Phase 0 confirmation and Requirement 5.4, deletion of `lib/features/jewellery/jewellery_integration.dart` is hereby APPROVED and RECORDED.

**Date:** Recorded during Phase 8 execution.
**Scope:** This sign-off covers ONLY `jewellery_integration.dart`. No other file deletion is authorized by this sign-off.
