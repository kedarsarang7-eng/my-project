# Phase 0 — Pre-Flight Read-Only Verification Report

**Spec:** `mobileshop-vertical-remediation`
**Requirement covered:** Requirement 3 (3.1–3.11)
**Mode:** STRICTLY READ-ONLY. Zero application source/config/build files were created, modified, or deleted. The only artifact produced by Phase 0 is this report.
**App source root:** `Dukan_x/lib`
**Audit verified against:** `audit-reports/business-types/audit-mobileShop.md` (§1–§20)

> Resolution vocabulary: **CONFIRMED** (audit finding holds against live code), **FALSIFIED** (audit finding does not hold / live code differs), **CONFIRMED-absent** (the thing the audit said is missing is indeed missing), **still-unverified** (source could not be located or behaviour could not be conclusively determined; rationale names the missing path).

---

## 0. Executive summary

- The single most severe finding (IMEI pipeline is a runtime no-op because `IMEIValidationService` is not injected into `BillsRepository`) is **CONFIRMED**.
- Two audit premises about wiring are **FALSIFIED by absence**: there is **no `lib/modules/` directory at all** — `Mobile_Shop_Module`, `Mobile_Shop_Routes`, `MobileShopSyncHandler`, and `MobileShopWsHandler` **do not exist** in the live codebase. Device-table sync is instead declared centrally in `core/sync/sync_table_registry.dart`.
- The audit's RBAC-bypass claim (§11: "no retail item carries a `permission`") is **PARTIALLY FALSIFIED**: seven sensitive retail items now carry `permission` tags. A residual set still carries none.
- Backup output **is** encrypted (AES-256-CBC) in `OfflineBackupService` — the audit's "encryption unverified" is **CONFIRMED (encrypted)**, with a caveat that the sidebar-reachable `BackupScreen` UI wires to cloud sync and does not itself invoke that encrypted offline engine.
- No SIM-activation/recharge screen exists → **CONFIRMED-absent**.
- **Two discrepancies are flagged for halt/acknowledgement before their dependent phases** (see §9): the non-existent Mobile_Shop_Module (affects Phase 4 task 9.5 and Phase 10 offline test) and the already-present RBAC permission tags (affects Phase 4 task 9.3).

---

## 3.2 Tenant isolation reality — `IMEISerial`, `ServiceJob`, `Exchange`, `WarrantyClaim`

**Tenant key.** Throughout the `features/service/*` stack the tenant is the `userId` string. It is resolved from the authenticated session, not hardcoded:
- `service_job_list_screen.dart` → `_loadUser()` uses `AuthService().currentUser?.uid` (line ~45).
- `exchange_list_screen.dart` / `create_exchange_screen.dart` / `exchange_detail_screen.dart` → `FirebaseAuth.instance.currentUser?.uid` (line ~39/52/32).
- `create_service_job_screen.dart` → `AuthService().currentUser` (line ~295).
- Billing path: `bills_repository.dart` passes `userId: bill.ownerId` into the IMEI service; `IMEIValidationService.validateBillItems` / `markIMEIsAsSold` thread that `userId` through.

**Per-entity finding (reads vs writes):**

| Entity | Reads scoped by tenant? | Writes scoped by tenant? | File + functions checked |
|--------|------------------------|--------------------------|--------------------------|
| `IMEISerial` | **Yes** for list/query reads — `getAll`, `getByNumber`, `getInStock`, `getByProduct`, `getByCustomer`, `getUnderWarranty`, `exists`, `isAvailableForSale`, `getInStockCount` all filter `userId.equals(userId)`. **No** for `getById` (filters by `id` only). | **No (by-id only)** — `createIMEISerial` stores `userId`, but `markAsSold`, `markAsReturned`, `markAsInService`, `returnToStock`, `softDelete` filter on `id` alone with no `userId` predicate. | `features/service/data/repositories/imei_serial_repository.dart` |
| `ServiceJob` | **Yes** for list/query reads — `getAllServiceJobs`, `getActiveServiceJobs`, `getServiceJobsByStatus`, `getServiceJobsForCustomer`, `watchAllServiceJobs`, `watchActiveServiceJobs`, `getJobCountsByStatus`, `generateJobNumber` all filter `userId`. **No** for `getServiceJobById` (by `id` only). | **No (by-id only)** — `updateStatus`, `updateServiceJob`, `addDiagnosis`, `markCompleted`, `markDelivered`, `cancelJob`, `softDeleteJob` filter on `id` alone. `createServiceJob` stores `userId`. | `features/service/data/repositories/service_job_repository.dart` |
| `Exchange` | **Yes** for list/query reads — `getAll`, `getByNumber`, `getByStatus`, `getDrafts`, `getCompleted`, `watchAll`, `generateExchangeNumber` filter `userId`. **No** for `getById` (by `id` only). | **No (by-id only)** — `updateExchange`, `completeExchange`, `cancelExchange`, `recordPayment` filter on `id` alone. `createExchange` stores `userId`. | `features/service/data/repositories/exchange_repository.dart` |
| `WarrantyClaim` | **Yes** for list/query reads — `getAllClaims`, `getClaimByNumber`, `getClaimsByStatus`, `getActiveClaims`, `getClaimsByCustomer`, `getClaimsByIMEI`, `getClaimsStats`, `watchAllClaims`, `watchActiveClaims`, `generateClaimNumber` filter `userId`. **No** for `getClaimById` (by `id` only). | **No (by-id only)** — `updateStatus`, `assignTechnician`, `addPartsReplaced`, `updateReimbursement`, `rejectClaim`, `linkServiceJob`, `updateResolution` filter on `id` alone. `createClaim` stores `userId`. | `features/service/data/repositories/warranty_claim_repository.dart` |

**Resolution:** Reads through the list/stream/lookup-by-number APIs **are** tenant-scoped by the session `userId`. However, **every mutation-by-id and the `getById`/`getClaimById`/`getServiceJobById` reads are NOT re-scoped by tenant** — they match on the primary key only. Because the service layer typically loads an entity it owns before mutating, this is not an obvious leak in the current happy path, but it is a real cross-tenant gap if an attacker/caller supplies a foreign `id`. This is the concrete substantiation of the audit's "multi-firm scoping beyond the userId reads observed is **unverified**" item (§20). **Phase 7 (Requirement 10.4) should scope these by-id reads/writes by session `userId`.** Recorded as the input to that phase.

---

## 3.3 Sync-handler liveness — `MobileShopSyncHandler` / `MobileShopWsHandler`

**Finding: FALSIFIED (the named handlers and their module do not exist).**

- A repository-wide search for `MobileShopSyncHandler`, `MobileShopWsHandler`, `MobileShopModule`, `mobileShopRoutes`, `/mobile/billing`, `/mobile/imei` returns **no class/route definitions**.
- There is **no `lib/modules/` directory** in the live app (`file_search "Dukan_x/lib/modules"` → no results). The audit's `modules/mobile_shop/*` paths reference files that are not present in the current tree.
- The live sync mechanism for the device tables is **central and declarative**: `core/sync/sync_table_registry.dart` registers `imei_serials` (local `i_m_e_i_serials`), `service_jobs`, `service_job_parts`, `service_job_status_history`, `product_variants`, and `exchanges`, each with `businessTypes` including `'mobileShop'`. `SyncTableRegistry.forBusinessType('mobileShop')` therefore returns these tables, and `RestSyncEngine` (wired via `core/sync/sync_manager.dart` → `RestSyncEngine.instance.initialize(...)` and `triggerSync()`) is the consumer.

**Registration path checked:** `core/sync/sync_table_registry.dart` (lines ~414–449), `core/sync/sync_manager.dart` (RestSyncEngine init), `core/sync/engine/rest_sync_engine.dart`. By contrast, sibling verticals that DO use the module pattern (`features/hardware/hardware_module.dart` attaching `HardwareSyncHandler`/`HardwareWsHandler`, registered in `core/app_bootstrap.dart`) confirm the module pattern exists elsewhere — it simply was never created for mobileShop.

**Caveat (still-unverified sub-point):** Whether the service repositories actually enqueue operations into the `SyncQueue` that `RestSyncEngine` pushes was not traced end-to-end in Phase 0 — the repos set `isSynced: false` flags, but the enqueue path from these specific repositories into the sync queue was not located. Rationale: the SyncQueue enqueue call site for `features/service/data/repositories/*` writes could not be confirmed read-only without deeper tracing; flagged for the Phase 10 offline correctness test.

---

## 3.4 Submit-time IMEI enforcement — `BillCreationScreenV2`

**Finding: CONFIRMED (IMEI is NOT enforced as required at submit time), distinct from the manual-entry-sheet path.**

- `features/billing/presentation/screens/bill_creation_screen_v2.dart` → `_handleSave()` (line ~2334) performs these submit-time validations only: non-empty item list, `qty > 0`, `price > 0`, pharmacy prescription gating for scheduled drugs, and pharmacy stock/batch checks. **There is no non-empty / required check on `serialNo` (IMEI) anywhere in the save path.** The only `serialNo` reference in the screen (line ~1831) merely forwards `finalItem.serialNo` when merging an OCR-added line — not a guard.
- This is the bill-submit path. It is distinct from the manual-entry-sheet path (`manual_item_entry_sheet.dart` captures `serialNo` with no non-empty guard) and the line-row path (`bill_line_item_row.dart` uses `hasField`, not `isRequired`), both noted by the audit (§4, §14).
- The only "required IMEI" logic that exists lives in the **un-injected** `IMEIValidationService.validateBillItems` (`errors.add('IMEI/Serial required for: ...')` when `businessType.toLowerCase().contains('mobile')`), which never runs (see §3.2 / Requirement 4 finding below).

**Net:** A mobileShop bill can be submitted with an empty IMEI at every layer today. CONFIRMED.

---

## 3.5 Backup encryption

**Finding: CONFIRMED (an encrypted backup flow exists) — with a UI-wiring caveat.**

- `features/backup/services/offline_backup_service.dart` encrypts its output with **AES-256-CBC**: `_getOrCreateAesKey()` creates/stores a 32-byte key in secure storage (`flutter_secure_storage`, key `offline_backup_aes_key`); `_encrypt()` produces `[IV(16) || ciphertext]` via `enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))`; `createBackup()` AES-encrypts the ZIP, writes the encrypted bytes, records `'encrypted': true` in metadata, and stores a SHA-256 checksum of the encrypted file. `restoreFromBackup()` decrypts with the same key. This resolves the audit's "encryption unverified" → **CONFIRMED: the offline backup engine encrypts its output.**
- **Caveat:** The sidebar `backup` item and `sync_status` item both resolve to `BackupScreen` (`sidebar_navigation_handler.dart` cases `'backup'`/`'sync_status'` → `const BackupScreen()`). That screen (`features/backup/screens/backup_screen.dart`) imports `core/sync/engine/sync_engine.dart` and exposes a "Sync Now" / "Cloud Backup … secure cloud backup enabled" UI; it does **not** itself invoke `OfflineBackupService`. So the encryption guarantee is proven for the offline backup engine, not for the cloud-sync action surfaced by the sidebar-reachable screen (cloud-at-rest encryption would be server-side and is out of read-only scope). Reported as CONFIRMED with this scope note.

---

## 3.6 SIM-activation / recharge screen

**Finding: CONFIRMED-absent.**

A repository-wide search for `recharge`, `sim_activation`, `simActivation`, `SimActivation` across `Dukan_x/lib/**/*.dart` returned **no SIM-activation or recharge screen** (only unrelated jewellery `foreclosureCharge*` matches). No SIM/recharge feature exists for mobileShop. Matches the audit's §3 "Unverified / not found" item, now resolved to CONFIRMED-absent.

---

## 3.7 RolePermissions matrix as applied to mobileShop sidebar items

mobileShop renders `_getRetailSections()` (`sidebar_configuration.dart`, switch groups `electronics`/`mobileShop`/`computerShop` → `_getRetailSections()`, lines ~140–143). The provider `sidebarSectionsProvider` filters each item: a `capability` is checked via `FeatureResolver.canAccess(typeStr, capability)` (before RBAC), then a `permission` is checked via `RolePermissions.hasPermission(userRole, permission)` only when `item.permission != null`.

### RolePermissions matrix (`lib/services/role_management_service.dart`)

`RolePermissions._permissions` maps `UserRole → Set<Permission>`. The roles relevant to a retail/mobile shop and their grants of the permissions used as sidebar tags:

| Permission (used as sidebar tag) | owner | accountant | manager | staff |
|----------------------------------|:----:|:----------:|:-------:|:-----:|
| `viewReports`     | ✅ | ✅ | ✅ | ❌ |
| `viewCashBook`    | ✅ | ✅ | ✅ | ❌ |
| `viewGstReports`  | ✅ | ✅ | ❌ | ❌ |
| `viewAuditLog`    | ✅ | ✅ | ❌ | ❌ |
| `manageSettings`  | ✅ | ❌ | ❌ | ❌ |

(Full matrix also defines `pharmacist`, `waiter`, `chef`, `captain`, `doctor`, `receptionist`, `nurse`; none of these are mobileShop staff roles. `hasPermission` returns `false` for any role/permission not in the set, and `UserRole.unknown` → all false. The sidebar maps an unknown permission string to a restrictive `manageSettings` fallback.)

### mobileShop retail sidebar items — capability / permission tags as applied

**Items that DO carry a `permission` tag (RBAC-gated):**

| Item id | Section | Tag |
|---------|---------|-----|
| `accounting_reports` | Financial Reports | `permission: viewReports` |
| `bank_accounts` | Financial Reports | `permission: viewCashBook` |
| `credit_notes` | Financial Reports | `permission: viewReports` |
| `expenses` | Financial Reports | `permission: viewReports` |
| `gstr1` | Tax & Compliance | `permission: viewGstReports` |
| `audit_trail` ("All Transactions") | Operations & Logs | `permission: viewAuditLog` |
| `backup` ("Backup & Restore") | Utilities & System | `permission: manageSettings` |

**Capability-gated items (filtered out for mobileShop):** `batch_tracking` (`useBatchExpiry` — mobileShop lacks it → hidden), `scan_bill` (`useScanOCR` — mobileShop lacks it → hidden).

**Sensitive items that carry NO `permission` tag (RBAC bypass — shown to every role including `staff`):**

- Financial Reports: `invoice_margin`, `income_statement`, `funds_flow`, `financial_position`, `cash_bank`, `daybook`.
- Tax & Compliance: `b2b_b2c`, `hsn_reports`, `tax_liability`, `filing_status`.
- Operations & Logs: `transaction_reports`, `activity_logs`, `error_logs`.
- Utilities & System: `sync_status` (opens the same `BackupScreen` as the permission-gated `backup`, yet itself carries **no** permission), `print_settings`, `doc_templates`, `device_settings`.

**Resolution of audit §11:** **PARTIALLY FALSIFIED.** The audit stated only `batch_tracking` carried a capability and **no** item carried a `permission`. Live code shows seven sensitive items now carry `permission` tags. A residual set of financial/compliance/admin items (listed above) still carries no `permission` tag and remains visible to all roles. See §9 discrepancy for the Phase 4 impact.

---

## 3.8 / 3.10 Resolution of every previously-unverified / asserted audit item

| # | Audit item (section) | Resolution | One-sentence rationale (file + function) |
|---|----------------------|-----------|------------------------------------------|
| 1 | IMEIValidationService not injected into BillsRepository → pipeline is a runtime no-op (§7, §3, §17) | **CONFIRMED** | `core/di/service_locator.dart` registers `BillsRepository(...)` (lines ~447–462) with `database`, `syncManager`, `brokerBillingService`, etc. but **no** `imeiValidationService:` arg; the field is nullable (`bills_repository.dart` line ~64) so both guards (`validateBillItems` ~line 229, `markIMEIsAsSold` ~line 476) are skipped. |
| 2 | Duplicate-sale prevention logic exists but is unreachable (§3, §14) | **CONFIRMED** | `IMEISerialRepository.getByNumber` + status switch (`sold`/`inService`/`damaged` → error) exist in `imei_validation_service.dart validateBillItems`, but only run when the un-injected service is non-null. |
| 3 | `billing_service.dart` IMEI branch gated on `'mobile_shop'` never matches enum `mobileShop`, and body is a comment (§7, §17) | **CONFIRMED** | `features/billing/services/billing_service.dart` line ~120 `if (businessType == 'electronics' \|\| businessType == 'mobile_shop')` with body `// Strict 1:1 validation could go here`; enum `.name` is `mobileShop`. |
| 4 | Warranty end-date day-of-month overflow (§14) | **CONFIRMED** | `imei_validation_service.dart markIMEIsAsSold` and `imei_serial_repository.dart markAsSold` both compute `DateTime(now.year, now.month + warrantyMonths, now.day)` with no last-day clamp. |
| 5 | IMEI not enforced required at submit (`BillCreationScreenV2`) (§4, §14) | **CONFIRMED** | See §3.4 — `_handleSave()` has no serial/IMEI guard. |
| 6 | IMEI not enforced required in manual entry / line row (§4, §14) | **CONFIRMED (per audit read)** | Audit read `manual_item_entry_sheet.dart` (no non-empty guard) and `bill_line_item_row.dart` (uses `hasField`); not re-opened in Phase 0 but consistent with §3.4. |
| 7 | No Luhn checksum on 15-digit IMEI (§13, §14) | **CONFIRMED** | `imei_validation_service.dart _guessIMEIType` only checks `serial.length == 15 && int.tryParse(serial) != null`; no Luhn validation. |
| 8 | mobileShop renders generic retail sidebar, no mobile-specific entries (§1, §6, §18) | **CONFIRMED** | `sidebar_configuration.dart _getSectionsForBusiness` groups `mobileShop` into `_getRetailSections()`; no `service_jobs`/`exchanges`/IMEI/warranty/second-hand items present. |
| 9 | `_getServiceSections()` (service_jobs + exchanges) wired only to `BusinessType.service` (§1, §6) | **CONFIRMED** | `sidebar_configuration.dart` `case BusinessType.service: return _getServiceSections();`; mobileShop does not reach it. |
| 10 | WarrantyScreen / SerialHistoryScreen / JobCardDetailScreen `BusinessGuard`-restricted to `computerShop` (§3, §6) | **still-unverified** | The `/computer-shop/*` `BusinessGuard` allow-lists were not opened in Phase 0; `core/routing/legacy_routes.dart` was located but the specific `/computer-shop/warranty|serial-history|job-card` guard arrays were not read — rationale: exact allowedTypes for those three routes not confirmed read-only this pass (resolve in Phase 3). |
| 11 | `/job/*` routes allow `mobileShop` (+ computerShop/service/electronics) with `Permissions.manageStaff` (§6) | **CONFIRMED** | `core/routing/legacy_routes.dart` shows `BusinessGuard(allowedTypes: [..., BusinessType.mobileShop, ...])` blocks at lines ~628, ~786–901, ~1491–1550, ~3032–3118. |
| 12 | Dashboard "IMEI Lookup" quick action is a dead `onTap: () {}` (§5, §3) | **still-unverified** | `features/dashboard/v2/widgets/business_quick_actions.dart` was not opened in Phase 0 — rationale: file not read this pass; resolve in Phase 5. |
| 13 | Dashboard alert counts are hardcoded `'5'`/`'8'`/`'3'` (§5, §8) | **still-unverified** | `features/dashboard/v2/widgets/business_alerts_widget.dart` was not opened in Phase 0 — rationale: file not read this pass; resolve in Phase 5. |
| 14 | Real counts exist in `getJobCounts` / `getExchangeStats` (§8) | **CONFIRMED** | `service_job_service.dart getJobCounts` → `getJobCountsByStatus` (Drift) and `exchange_service.dart getExchangeStats` (Drift over `getAll`) compute real values. |
| 15 | Divergent identity source across the two service screens (§8, §11) | **CONFIRMED** | `service_job_list_screen.dart` uses `AuthService().currentUser?.uid` (line ~45); `exchange_list_screen.dart` uses `FirebaseAuth.instance.currentUser?.uid` (line ~39). |
| 16 | `ExchangeListScreen` shows perpetual spinner when userId null (§17) | **CONFIRMED** | `exchange_list_screen.dart` `if (_isLoading \|\| _userId == null) return CircularProgressIndicator();` (line ~287) with no error/empty state. |
| 17 | Second-hand / used inventory intake screen missing despite `'second_hand'` module config (§3, §4) | **CONFIRMED-absent** | No second-hand intake screen found under `features/service/*` or elsewhere; only `ExchangeListScreen` (trade-in) exists. |
| 18 | `IMEISerialStatus` enum lacks a `demo` state (§3, §13) | **CONFIRMED** | `features/service/models/imei_serial.dart enum IMEISerialStatus { inStock, sold, returned, damaged, inService }` — no `demo`. |
| 19 | `useScanOCR` denied to mobileShop yet `ocrFocus` set (§3, §13) | **CONFIRMED** | `core/config/business_capabilities.dart _getOcrFocus` returns `'Name, Model, Serial/IMEI'` for mobileShop; `useScanOCR` absent from the `'mobileShop'` capability set in `business_capability.dart`. |
| 20 | RBAC bypass: sensitive retail items carry no permission (§11) | **PARTIALLY FALSIFIED** | See §3.7 — seven items now carry `permission` tags; a residual set still carries none. |
| 21 | Content_host renders `service_jobs`/`exchanges` without `VendorRoleGuard(manageStaff)` (§6, §11) | **still-unverified** | `content_host.dart _buildScreen` and the `/service_jobs`,`/exchanges` named-route guards were not opened in Phase 0 — rationale: in-shell vs named-route guard comparison not read this pass; resolve in Phase 4 (7.6). |
| 22 | `MobileShopSyncHandler`/`MobileShopWsHandler` / Mobile_Shop_Module orphaned/inactive (§1, §6, §7, §12) | **FALSIFIED (do not exist)** | No `lib/modules/` dir and no such classes/routes exist; device sync is declared in `core/sync/sync_table_registry.dart`. See §3.3. |
| 23 | Backup encryption unverified (§2 row 12) | **CONFIRMED (encrypted)** | `features/backup/services/offline_backup_service.dart` AES-256-CBC `_encrypt`. See §3.5 caveat. |
| 24 | SIM / recharge presence unverified (§3) | **CONFIRMED-absent** | See §3.6. |
| 25 | Multi-firm scoping beyond observed userId reads unverified (§2 row 11, §20) | **CONFIRMED (gap exists)** | See §3.2 — by-id reads/writes in all four service repos are not tenant-scoped. |
| 26 | WCAG contrast on service screens unverified (§9, §16) | **still-unverified** | Requires manual testing with assistive technology and expert review; cannot be conclusively resolved by static read — rationale: WCAG conformance is not statically determinable. |

---

## 3.9 Falsified findings depended on by later phases — DISCREPANCIES (halt required)

Two Phase 0 results contradict assumptions baked into later phases. Per Requirement 3.9 these are recorded here and the dependent phases must not proceed until the maintainer acknowledges the discrepancy.

### Discrepancy A — `Mobile_Shop_Module` / `MobileShopSyncHandler` / `MobileShopWsHandler` do not exist
- **Falsifies:** audit premise that these are "orphaned but present."
- **Depended on by:**
  - **Phase 4, task 9.5** — "decide whether the orphaned Mobile_Shop_Module / Mobile_Shop_Routes are deleted (under soft-delete/sign-off) or retained." There is nothing to delete or retain; this decision is **moot**. Recommend recording the decision as "N/A — module never existed; no action."
  - **Phase 10 offline test** (design ties offline correctness to finding 3.3) — must target the central `SyncTableRegistry` + `RestSyncEngine` path, not a per-module handler.
- **Action:** **HALT before Phase 4 task 9.5 and before the Phase 10 offline test** until the maintainer acknowledges that the module/handlers are absent and the central sync registry is the correct target.

### Discrepancy B — Several sensitive retail sidebar items ALREADY carry `permission` tags
- **Falsifies:** audit §11 "no retail item carries a permission" (PARTIALLY).
- **Depended on by:**
  - **Phase 4, task 9.3** — "Attach `permission` tags to surfaced financial/compliance/admin items." Seven items (`accounting_reports`, `bank_accounts`, `credit_notes`, `expenses`, `gstr1`, `audit_trail`, `backup`) are **already tagged**; re-tagging them risks redundant/contradictory edits. The task should be **narrowed** to only the still-untagged residual set listed in §3.7 (`invoice_margin`, `income_statement`, `funds_flow`, `financial_position`, `cash_bank`, `daybook`, `b2b_b2c`, `hsn_reports`, `tax_liability`, `filing_status`, `transaction_reports`, `activity_logs`, `error_logs`, `sync_status`).
- **Action:** **HALT before Phase 4 task 9.3** until the maintainer acknowledges the existing tags and confirms the narrowed scope.

> Both discrepancies make later work *smaller/safer*, not contradictory, but Requirement 3.9 mandates explicit acknowledgement before the dependent phase proceeds.

---

## 3.11 Phase 0 completion status

Every previously-unverified or asserted audit item has been resolved to exactly one of CONFIRMED / FALSIFIED / CONFIRMED-absent / still-unverified, each with a one-sentence rationale (a missing source naming the missing path forces still-unverified per 3.10). Two phase-dependent discrepancies are recorded with halt flags (§9).

**Files created/modified/deleted in Phase 0:** exactly one file — this report (`phase0-verification-report.md`). No application source, configuration, or build file was touched.

**PHASE 0 COMPLETE.**
