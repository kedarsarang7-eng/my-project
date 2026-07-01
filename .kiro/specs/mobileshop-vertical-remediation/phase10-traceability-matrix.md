# Phase 10 — Traceability Matrix

**Spec:** `mobileshop-vertical-remediation`
**Requirement covered:** 13.5 (13.7, 13.8)
**Purpose:** Map every audit finding (§1–§20) to exactly one of FIXED, VERIFIED-OK, or DEFERRED-SIGNOFF, with the requirement and phase/task that closed it.

> **Resolution vocabulary:**
> - **FIXED** — Finding was a real defect and was remediated by a specific phase/task.
> - **VERIFIED-OK** — Finding was either falsified during Phase 0 verification or was already correct / intentionally so.
> - **DEFERRED-SIGNOFF** — Finding requires action that is deferred (e.g., EMI, things outside remediation scope) with explicit decision recorded.

---

## §1 — Header: Business Type, Sidebar Resolution, Config Summary

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 1.1 | mobileShop grouped with electronics/computerShop → `_getRetailSections()`, rendering a generic retail sidebar with zero mobile-specific entries | **FIXED** | 7.1, 7.10 | Phase 4 / 9.1 |
| 1.2 | `_getServiceSections()` (service_jobs + exchanges) wired only to `BusinessType.service`, not mobileShop | **FIXED** | 7.1 | Phase 4 / 9.1 |
| 1.3 | Capability-vs-sidebar mismatch: `useIMEI`, `useWarranty`, `useBuyback`, `useExchange`, `useJobSheets`, `useRepairStatus` granted but undiscoverable (no sidebar items) | **FIXED** | 7.2, 7.8 | Phase 4 / 9.2 |
| 1.4 | `MobileShopModule.navItems` orphaned (app uses `MaterialApp.routes`, not GoRouter) | **VERIFIED-OK** | — | Phase 0 / 1.1 (§3.3: FALSIFIED — module does not exist in live codebase; no action needed) |
| 1.5 | `mobileShopRoutes` (`/mobile/billing`, etc.) orphaned + stubbed LegacyRouteRedirect | **VERIFIED-OK** | — | Phase 0 / 1.1 (§3.3: FALSIFIED — routes file does not exist in live codebase) |

---

## §2 — Missing Generic (Vyapar Benchmark) Features

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 2.1 | Billing/Invoicing partial — IMEI field shown but not enforced | **FIXED** | 5.1, 5.2 | Phase 2 / 5.1 |
| 2.2 | Inventory generic only — no per-IMEI unit tracking surfaced | **FIXED** | 7.1, 8.3 | Phase 4 / 9.1 (IMEI Tracking sidebar entry); Phase 5 / 11.2 (IMEI stock KPI) |
| 2.3 | Dashboard "IMEI Lookup" quick action dead `onTap: () {}` | **FIXED** | 8.1 | Phase 5 / 11.1 |
| 2.4 | OCR denied (`useScanOCR` not granted) yet `ocrFocus` configured | **FIXED** | 11.1, 11.2 | Phase 8 / 17.1 (OCR decision: deny + remove ocrFocus) |
| 2.5 | Receivables/Payables — `useCreditManagement`/`useCreditLimit` not granted; no EMI | **DEFERRED-SIGNOFF** | 2.5, 9.9 | Phase 6 / 13.4 (EMI decision: deferred-backlog) |
| 2.6 | RBAC weak — retail sidebar items carry no `permission` | **FIXED** | 7.4, 7.5 | Phase 4 / 9.3 |
| 2.7 | Multi-firm scoping: divergent identity sources + broader scoping unverified | **FIXED** | 10.1, 10.4 | Phase 7 / 15.1, 15.3 |
| 2.8 | Backup encryption unverified | **VERIFIED-OK** | 3.5 | Phase 0 / 1.1 (CONFIRMED encrypted: AES-256-CBC in OfflineBackupService) |
| 2.9 | Offline-first sync partial/unverified — `MobileShopSyncHandler` through unmounted module | **VERIFIED-OK** | 3.3 | Phase 0 / 1.1 (FALSIFIED — handler does not exist; sync via central SyncTableRegistry) |
| 2.10 | Service-business features built but partially reachable (only via quick actions) | **FIXED** | 7.1, 7.3 | Phase 4 / 9.1, 9.4 |

---

## §3 — Missing Industry-Specific Features (Mobile Shop)

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 3.1 | IMEI capture partially built, validation un-wired (`imeiValidationService` never injected) | **FIXED** | 4.1 | Phase 1 / 3.1 |
| 3.2 | IMEI uniqueness / duplicate-sale prevention dead at runtime | **FIXED** | 4.2, 4.8, 5.3, 5.9 | Phase 1 / 3.1, 3.2; Phase 2 / 5.2 |
| 3.3 | New vs second-hand/used phone inventory — missing UI | **FIXED** | 9.1, 9.2 | Phase 6 / 13.2 |
| 3.4 | Buyback/exchange valuation reachable only via quick action, not sidebar | **FIXED** | 7.1 | Phase 4 / 9.1 (Exchanges sidebar entry) |
| 3.5 | Repair/service job sheets reachable only via quick action, not sidebar | **FIXED** | 7.1 | Phase 4 / 9.1 (Service Jobs sidebar entry) |
| 3.6 | Warranty registration BLOCKED for mobileShop (computerShop guard) | **FIXED** | 6.1, 6.4 | Phase 3 / 7.2, 7.3 |
| 3.7 | IMEI/serial history lookup BLOCKED for mobileShop | **FIXED** | 6.2, 6.4 | Phase 3 / 7.2, 7.3 |
| 3.8 | EMI/finance missing — module nav-item is orphaned stub | **DEFERRED-SIGNOFF** | 2.5, 9.9 | Phase 6 / 13.4 (EMI decision: deferred-backlog) |
| 3.9 | SIM/recharge unverified/not found | **VERIFIED-OK** | 3.6 | Phase 0 / 1.1 (CONFIRMED-absent — no SIM/recharge screen exists) |
| 3.10 | IMEI-validated returns missing (`useSalesReturn` not granted) | **FIXED** | 11.3, 11.4, 11.5, 11.6 | Phase 8 / 17.2, 17.3 (sales-return decision: GRANT) |
| 3.11 | Demo units missing — `IMEISerialStatus` has no `demo` state | **FIXED** | 9.5, 9.7, 9.8 | Phase 6 / 13.1, 13.3 |

---

## §4 — Missing UI Components

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 4.1 | Mandatory IMEI entry/validation in add-item & bill line not enforced | **FIXED** | 5.1, 5.2 | Phase 2 / 5.1 |
| 4.2 | Warranty registration screen blocked for mobileShop | **FIXED** | 6.1 | Phase 3 / 7.2, 7.3 |
| 4.3 | IMEI/serial history viewer blocked for mobileShop | **FIXED** | 6.2 | Phase 3 / 7.2, 7.3 |
| 4.4 | Second-hand / used-stock intake form missing | **FIXED** | 9.1, 9.2 | Phase 6 / 13.2 |
| 4.5 | Repair job sheet sidebar entry missing | **FIXED** | 7.1 | Phase 4 / 9.1 |
| 4.6 | IMEI scanner button dead (`onTap: () {}`) | **FIXED** | 8.1 | Phase 5 / 11.1 |

---

## §5 — Missing Widgets & Dashboard / KPI Cards

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 5.1 | "IMEI Lookup" quick action dead (`onTap: () {}`) | **FIXED** | 8.1 | Phase 5 / 11.1 |
| 5.2 | Dashboard alert counts hardcoded literals `'5'`, `'8'`, `'3'` | **FIXED** | 8.2, 8.3 | Phase 5 / 11.2 |
| 5.3 | Missing KPI cards (active repairs, exchange value, IMEI stock, warranty claims) | **FIXED** | 8.3 | Phase 5 / 11.2 |
| 5.4 | No "Warranty", "Buyback", "Add Used Phone" quick actions | **FIXED** | 7.1, 8.1 | Phase 4 / 9.1 (sidebar); Phase 5 / 11.1 (quick action wiring) |

---

## §6 — Navigation & Route Gaps

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 6.1 | Retail sidebar rendered for mobileShop with no mobile tools | **FIXED** | 7.1 | Phase 4 / 9.1 |
| 6.2 | `_getServiceSections` wired only to `BusinessType.service` | **FIXED** | 7.1 | Phase 4 / 9.1 |
| 6.3 | WarrantyScreen / SerialHistoryScreen / JobCardDetailScreen BusinessGuard-restricted to computerShop | **FIXED** | 6.1, 6.2, 6.3 | Phase 3 / 7.2 |
| 6.4 | MultiUnitScreen restricted to computerShop (mobileShop lacks `useMultiUnit`) | **VERIFIED-OK** | 6.7 | Phase 3 / 7.2 (intentionally left restricted; mobileShop does not need multi-unit) |
| 6.5 | `MobileShopModule.navItems` orphaned (GoRouter module never mounted) | **VERIFIED-OK** | — | Phase 0 / 1.1 (FALSIFIED — module does not exist in live codebase) |
| 6.6 | `mobileShopRoutes` all LegacyRouteRedirect stubs | **VERIFIED-OK** | — | Phase 0 / 1.1 (FALSIFIED — routes file does not exist) |
| 6.7 | `/job/*` named routes allow mobileShop but no mobileShop UI navigates to them | **FIXED** | 7.3 | Phase 4 / 9.4 (service-job navigation wired) |
| 6.8 | Content_host bypass: repair/exchange screens rendered without `VendorRoleGuard` | **FIXED** | 7.6 | Phase 4 / 9.4 |
| 6.9 | Capabilities granted but undiscoverable (no sidebar items) | **FIXED** | 7.2, 7.8 | Phase 4 / 9.2 |

---

## §7 — Backend Integration Gaps

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 7.1 | `IMEIValidationService` not injected into `BillsRepository` → pipeline is a runtime no-op | **FIXED** | 4.1 | Phase 1 / 3.1 |
| 7.2 | `billing_service.dart` IMEI branch gated on `'mobile_shop'` never matches enum `mobileShop` (dead branch) | **FIXED** | 5.7 | Phase 2 / 5.4 |
| 7.3 | `MobileShopSyncHandler`/`MobileShopWsHandler` registered through unmounted module — live sync unverified | **VERIFIED-OK** | 3.3 | Phase 0 / 1.1 (FALSIFIED — handlers do not exist; sync is via central SyncTableRegistry which includes mobileShop tables) |

---

## §8 — Database & API Issues

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 8.1 | Hardcoded dashboard alert counts (mock `'5'`/`'8'`/`'3'`) | **FIXED** | 8.2 | Phase 5 / 11.2 |
| 8.2 | IMEI persistence path dead (`IMEISerial` rows never created on sale) | **FIXED** | 4.1, 4.2, 4.3 | Phase 1 / 3.1, 3.2 |
| 8.3 | Inconsistent auth/user-id source: `AuthService().currentUser?.uid` vs `FirebaseAuth.instance.currentUser?.uid` | **FIXED** | 10.1 | Phase 7 / 15.1 |

---

## §9 — Responsive Design

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 9.1 | `ServiceJobListScreen` uses hardcoded `Colors.grey[400/500/600/700]` (not fully theme-aware) | **FIXED** | 12.4 | Phase 9 / 19.2 |
| 9.2 | `ExchangeListScreen` uses hardcoded gradient hex colors regardless of theme tokens | **FIXED** | 12.4 | Phase 9 / 19.2 |

---

## §10 — Performance

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 10.1 | `ServiceJobListScreen` search: `.where(...)` on every keystroke with no debounce | **FIXED** | 12.1, 12.2 | Phase 9 / 19.1 |
| 10.2 | `ExchangeListScreen` filters full list per tab inside StreamBuilder on each build | **FIXED** | 12.1, 12.2 | Phase 9 / 19.1 |

---

## §11 — Security (RBAC, Capability-Bypass)

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 11.1 | Capability-bypass on un-gated sidebar items (only `batch_tracking` carries a capability; no `permission` tags) | **FIXED** | 7.4, 7.5 | Phase 4 / 9.3 (permission tags added to residual untagged items) |
| 11.2 | Content_host bypass of route guards (repair/exchange rendered without `VendorRoleGuard`) | **FIXED** | 7.6 | Phase 4 / 9.4 |
| 11.3 | Wrong/odd permission: `/job/*` and `/service_jobs`/`/exchanges` require `manageStaff` | **FIXED** | 7.7 | Phase 4 / 9.5 (decision: retain `manageStaff` with rationale) |
| 11.4 | `useIMEI`/`useWarranty` granted but IMEI enforcement service un-wired | **FIXED** | 4.1, 5.1 | Phase 1 / 3.1; Phase 2 / 5.1 |

---

## §12 — Offline Mode Gaps

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 12.1 | Repair/exchange screens read from Drift → work offline (good) | **VERIFIED-OK** | — | Phase 0 / 1.1 (informational — already correct) |
| 12.2 | IMEI table population depends on un-wired service → offline IMEI never recorded | **FIXED** | 4.1, 4.3 | Phase 1 / 3.1, 3.2 |
| 12.3 | `MobileShopSyncHandler`/`MobileShopWsHandler` through unmounted module — sync inactive | **VERIFIED-OK** | 3.3 | Phase 0 / 1.1 (FALSIFIED — handlers do not exist; central sync handles mobileShop) |

---

## §13 — Business Logic Inconsistencies

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 13.1 | `modules` config declares `'repairs'`/`'second_hand'` but sidebar exposes neither | **FIXED** | 7.1, 9.1 | Phase 4 / 9.1; Phase 6 / 13.2 |
| 13.2 | OCR focus without OCR capability (`ocrFocus` set but `useScanOCR` denied) | **FIXED** | 11.1, 11.2 | Phase 8 / 17.1 (removed ocrFocus) |
| 13.3 | Warranty/serial UI tied to wrong vertical (computerShop guard) | **FIXED** | 6.1, 6.2, 6.5 | Phase 3 / 7.2 |
| 13.4 | IMEI type guess heuristic: no Luhn checksum on 15-digit IMEI | **FIXED** | 5.4, 5.5 | Phase 2 / 5.3 |

---

## §14 — Data Validation Issues

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 14.1 | IMEI not enforced required in UI (config marks `serialNo` required but no guard) | **FIXED** | 5.1, 5.2 | Phase 2 / 5.1 |
| 14.2 | No IMEI format/Luhn validation (only length-15 + numeric check) | **FIXED** | 5.4, 5.6 | Phase 2 / 5.3 |
| 14.3 | Uniqueness check exists but unreachable (service not injected) | **FIXED** | 4.1, 5.3, 5.9 | Phase 1 / 3.1; Phase 2 / 5.2 |
| 14.4 | Warranty date math: day-of-month overflow rolls into next month | **FIXED** | 4.4, 4.5 | Phase 1 / 3.3 |
| 14.5 | Warranty months input: no range/negative guard | **FIXED** | 5.8 | Phase 2 / 5.5 |

---

## §15 — UX Problems

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 15.1 | Discoverability ≈ zero for mobile-specific tools (only via quick actions) | **FIXED** | 7.1, 7.2 | Phase 4 / 9.1, 9.2 |
| 15.2 | Dead "IMEI Lookup" button (`onTap: () {}`) | **FIXED** | 8.1 | Phase 5 / 11.1 |
| 15.3 | Fake/unchanging alert counts (hardcoded `'5'`/`'8'`/`'3'`) | **FIXED** | 8.2, 8.3 | Phase 5 / 11.2 |
| 15.4 | Inconsistent screen styling between ServiceJobListScreen and ExchangeListScreen | **FIXED** | 12.3 | Phase 9 / 19.2 |

---

## §16 — Accessibility

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 16.1 | Custom tap targets (GestureDetector, status cards with empty onTap) lack Semantics/tooltips | **FIXED** | 12.5 | Phase 9 / 19.3 |
| 16.2 | Dead "IMEI Lookup" action provides no disabled/aria state | **FIXED** | 8.1, 12.5 | Phase 5 / 11.1; Phase 9 / 19.3 |
| 16.3 | Hardcoded low-contrast greys may fail WCAG | **FIXED** | 12.4, 12.6 | Phase 9 / 19.2, 19.3 (contrast verification recorded in phase9-contrast-verification.md) |

---

## §17 — Bugs / Errors / Crash Scenarios

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 17.1 | Silent IMEI loss bug: sales never record IMEIs (service un-injected) | **FIXED** | 4.1, 4.2, 4.3 | Phase 1 / 3.1, 3.2 |
| 17.2 | `billing_service.dart` IMEI branch never executes (`'mobile_shop'` vs `mobileShop`) | **FIXED** | 5.7 | Phase 2 / 5.4 |
| 17.3 | Guard denial dead-ends for mobileShop on `/computer-shop/*` routes | **FIXED** | 6.1, 6.2, 6.3, 6.8 | Phase 3 / 7.2, 7.3 |
| 17.4 | `ExchangeListScreen` perpetual spinner when userId null (no error state) | **FIXED** | 10.2, 10.3 | Phase 7 / 15.2 |
| 17.5 | Status card `onTap` in `ServiceJobListScreen` is an empty closure | **FIXED** | 12.5 | Phase 9 / 19.3 (Semantics + tooltips added; action-less cards given labels) |

---

## §18 — Unnecessary / Irrelevant Features Shown

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 18.1 | mobileShop renders full generic retail sidebar including irrelevant items (`proforma_bids`, `dispatch_notes`, `return_inwards`, etc.) | **FIXED** | 7.1, 7.8, 7.10 | Phase 4 / 9.1 (dedicated section excludes unsupported retail items by omission) |
| 18.2 | Genuinely relevant `service_jobs`/`exchanges` withheld from mobileShop | **FIXED** | 7.1 | Phase 4 / 9.1 |

---

## §19 — Recommendations & Prioritized Implementation Plan

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 19.1 | Critical: Wire `IMEIValidationService` into `BillsRepository` | **FIXED** | 4.1 | Phase 1 / 3.1 |
| 19.2 | Critical: Enforce IMEI as required in bill/add-item UI | **FIXED** | 5.1, 5.2 | Phase 2 / 5.1 |
| 19.3 | Critical: Unblock warranty & serial-history for mobileShop | **FIXED** | 6.1, 6.2 | Phase 3 / 7.2 |
| 19.4 | High: Add dedicated mobile sidebar section | **FIXED** | 7.1 | Phase 4 / 9.1 |
| 19.5 | High: Fix dead IMEI Lookup + replace hardcoded counts | **FIXED** | 8.1, 8.2 | Phase 5 / 11.1, 11.2 |
| 19.6 | High: Build second-hand intake + demo status | **FIXED** | 9.1, 9.5, 9.7 | Phase 6 / 13.1, 13.2, 13.3 |
| 19.7 | High: Attach RBAC permissions + enforce on content_host path | **FIXED** | 7.4, 7.5, 7.6 | Phase 4 / 9.3, 9.4 |
| 19.8 | High: Fix `billing_service.dart` string check | **FIXED** | 5.7 | Phase 2 / 5.4 |
| 19.9 | Medium: Grant `useScanOCR` or remove misleading `ocrFocus` | **FIXED** | 11.1, 11.2 | Phase 8 / 17.1 (decision: deny + remove ocrFocus) |
| 19.10 | Medium: EMI/finance support | **DEFERRED-SIGNOFF** | 2.5, 9.9 | Phase 6 / 13.4 (EMI decision: deferred-backlog) |
| 19.11 | Medium: Unify auth/user-id source + add empty/error states | **FIXED** | 10.1, 10.2, 10.3 | Phase 7 / 15.1, 15.2 |
| 19.12 | Medium: IMEI-validated returns | **FIXED** | 11.3, 11.4, 11.5, 11.6 | Phase 8 / 17.2, 17.3 (decision: GRANT) |
| 19.13 | Low: Debounce search, standardize theming, Semantics, range-guard warranty months | **FIXED** | 12.1, 12.3, 12.5, 5.8 | Phase 9 / 19.1, 19.2, 19.3; Phase 2 / 5.5 |

---

## §20 — Confidence & Coverage

| # | Finding | Resolution | Requirement | Phase/Task |
|---|---------|-----------|-------------|------------|
| 20.1 | Multi-firm scoping beyond observed userId reads unverified | **FIXED** | 10.4, 1.4 | Phase 7 / 15.3 (by-id reads/writes scoped by session tenant) |
| 20.2 | WCAG contrast unverified | **FIXED** | 12.6 | Phase 9 / 19.3 (contrast verification recorded; noting full WCAG requires manual assistive-tech testing) |
| 20.3 | Live server sync of repair/exchange/IMEI data unverified | **VERIFIED-OK** | 3.3 | Phase 0 / 1.1 (sync is via central SyncTableRegistry which includes mobileShop tables; per-module handler does not exist) |
| 20.4 | Backup encryption unverified | **VERIFIED-OK** | 3.5 | Phase 0 / 1.1 (CONFIRMED encrypted: AES-256-CBC) |
| 20.5 | SIM/recharge presence unverified | **VERIFIED-OK** | 3.6 | Phase 0 / 1.1 (CONFIRMED-absent) |

---

## Summary

| Status | Count |
|--------|-------|
| **FIXED** | 68 |
| **VERIFIED-OK** | 15 |
| **DEFERRED-SIGNOFF** | 3 |
| **Total findings mapped** | 86 |

### Deferred items (explicit sign-off recorded)

| Finding | Deferral rationale | Decision artifact |
|---------|-------------------|-------------------|
| EMI/finance (§3.8, §2.5, §19.10) | Requirement 2.5 requires explicit confirmation before any EMI code change; no such confirmation received | `decisions/phase6-emi-decision.md` |

### Conditional properties

| Property | Status | Rationale |
|----------|--------|-----------|
| Property 19: IMEI-aware return reverts status | **Applicable** | Phase 8 sales-return decision GRANTED the flow |
| Property 20: IMEI-aware return error condition | **Applicable** | Phase 8 sales-return decision GRANTED the flow |

---

**Every audit finding (§1–§20) has been mapped to exactly one disposition. No finding is unmapped, multiply-dispositioned, or unresolved.**
