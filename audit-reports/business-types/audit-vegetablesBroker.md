# DukanX Business-Type Audit — Vegetable Broker / Mandi (`vegetablesBroker`)

**Scope:** READ-ONLY, evidence-based audit of the `vegetablesBroker` business type (Vegetable Broker / Mandi / Commission Agent).
**Method:** Static source inspection only. No files were modified. Every claim cites the file path/function inspected. Items not directly verified are marked **unverified**.
**Benchmark:** Vyapar feature set + Mandi/Commission-Agent industry needs.

---

## 1. Header — Resolution, Config & Capabilities

**Enum:** `BusinessType.vegetablesBroker` exists — `Dukan_x/lib/models/business_type.dart` (line 15). `displayName` = "Vegetable Broker / Mandi", icon `Icons.agriculture_rounded`, emoji 🥦, color `0xFF16A34A` (`business_type_config.dart`).

**Billing Config** — `Dukan_x/lib/core/billing/business_type_config.dart` (`BusinessType.vegetablesBroker` entry):
- requiredFields: `itemName`, `quantity`, `netWeight`, `price`
- optionalFields: `grossWeight`, `tareWeight`, `commission`, `lotId`, `marketFee`, `vehicleNumber`, `discount`
- defaultGstRate `0.0`, `gstEditable: false`
- unitOptions: `kg`, `pcs`, `box`
- itemLabel `Vegetable`, addItemLabel `Add Lot`, priceLabel `Rate/Kg`
- modules: `['auction','sales','farmers','buyers','reports']`
- **Verified.** Note: none of the `modules` strings (`auction`, `farmers`, `buyers`) resolve to any screen — there is no module-string router for this type (see §6).

**Sidebar resolution:** `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` → `_getSectionsForBusiness(BusinessType)` has **no `case BusinessType.vegetablesBroker`**, so it falls through `default: _getRetailSections()`. **Verified.** The Mandi user sees the full generic 10-section retail sidebar (Revenue Desk, BuyFlow, Inventory, Parties, BI, Financial Reports, Tax & Compliance, Operations, Utilities).

**Capabilities:** `Dukan_x/lib/core/isolation/business_capability.dart` has a dedicated `'vegetablesBroker'` capability set (line 682+) including `useCommission`, `useCrateManagement`, `useFarmerLinking`, `useDailyRates`, `useCreditManagement`, plus product/inventory/invoice/purchase basics. **Verified.**

**⚠️ CRITICAL — NO PRESENTATION LAYER:** `Dukan_x/lib/features/vegetable_broker/` contains **only** `data/models/` and `data/repositories/` — there is **NO `presentation/` or `screens/` folder**. **Verified by directory listing.** There is no Mandi dashboard, no lot register screen, no farmer ledger screen, no auction/rate-discovery screen, no patti/settlement screen. The only Mandi-specific UI that actually renders is a weight-entry bottom sheet embedded inside the shared billing screen (`bill_creation_screen_v2.dart` — see §4).

**Two disconnected data stacks exist (key structural finding):**
1. **Stack A (orphaned, API-based):** `features/vegetable_broker/data/models/vegetable_broker_models.dart` (freezed: `VegetableLot`, `Farmer`, `VegetableBuyer`, `MandiSession`, `RateTrend`, `FarmerSettlement`) + `vegetable_broker_repository.dart` (`VegetableBrokerRepository` calling `/vegetable-broker/...`). **Not consumed anywhere** — see §6/§8.
2. **Stack B (live, local Drift):** `features/billing/services/broker_billing_service.dart` (`BrokerBillingService`) backed by Drift tables `Farmers` + `CommissionLedger` (`core/database/tables.dart` lines 3449-3499). This is the path the billing screen actually uses.

These two stacks share no models and no storage. This duplication is the root cause of most gaps below.

---

## 2. Missing Generic Features (vs Vyapar)

| # | Vyapar feature | Status for vegetablesBroker | Evidence |
|---|---|---|---|
| 1 | Billing | Partial — shared `BillCreationScreenV2` with Mandi weight sheet | `bill_creation_screen_v2.dart` `_showMandiEntrySheet` |
| 2 | Inventory | Generic retail inventory shown; perishable not modeled | `_getRetailSections()` Inventory section |
| 3 | Barcode/POS | **Disabled** for this type (reasonable for loose produce) | `features/barcode/integration/bill_creation_barcode_integration.dart` lines 90-91, 378-379 |
| 4 | Accounting | Generic; farmer payout posts a payment entry | `broker_billing_service.payoutFarmer` → `accountingService.createPaymentEntry` |
| 5 | Receivables/Payables | Buyer receivable via generic ledger; farmer payable via `Farmers.currentBalance` (local only) | `tables.dart` Farmers; `party_ledger` |
| 6 | Bank/Cash | Generic only; payout hardcoded `'CASH'` | `broker_billing_service.payoutFarmer` (paymentMode: 'CASH') |
| 7 | Orders/Delivery | Generic BuyFlow/dispatch shown (retail) | `_getRetailSections()` |
| 8 | OCR | **unverified** — not found for this type | — |
| 9 | Reports (37+) | Generic retail reports; **no Mandi-specific report** (lot register, patti, rate trend) | nav handler maps; no veg report screens |
| 10 | RBAC + audit | Shared RBAC; capability gating present | `sidebar_configuration.dart` permission filter |
| 11 | Multi-firm | **unverified** (shared platform feature) | — |
| 12 | Backup | Shared `BackupScreen` | nav handler `backup` |
| 13 | Online store | Generic catalogue | nav handler `catalogue` |
| 14 | e-Way bill | **Missing/unverified** | — |
| 15 | Loyalty | Not relevant; absent | — |
| 16 | Service-business | N/A | — |
| 17 | Offline-first sync | **Partial/broken** — live broker data (Farmers/CommissionLedger) has no sync columns; sync handler points at an unrelated `veg_rate_entries` collection | §8, §12 |

**Priority:** Mandi-specific reporting (9) is **High**; e-Way bill (14) **Low** (agri produce often exempt).

---

## 3. Missing Industry-Specific Features (Mandi / Commission Agent)

All assessed against the live, reachable UI (Stack B + billing sheet). Stack A models exist but are unreachable (§6).

| Mandi need | Status | Evidence / Priority |
|---|---|---|
| Lot/consignment intake (arrival, vehicle, gross/tare/net) | **Partial** — weight sheet captures gross/tare/net + lotId; no arrival date / grade / vehicle field in the live sheet despite config listing `vehicleNumber` | `bill_creation_screen_v2.dart` 638-800. **High** |
| Auction / rate discovery | **Missing UI** — `MandiSession`/`RateTrend` models exist in Stack A but no screen; `modules` lists `'auction'` with no router | models orphaned. **High** |
| Sale to buyers | Via generic bill; buyer = generic customer | **Medium** |
| Commission (arhat) % calc | **Partial & inconsistent** — sheet captures flat ₹ "Commission"; `recordBrokerSale` expects a **rate %**; bills_repository back-converts flat→% | §13. **High** |
| Market fee / mandi tax / hamali (labor) / weighing charges | **Missing in live flow** — `recordBrokerSale` defaults `laborCharges=0, otherExpenses=0`; bill carries `marketCess` column but sheet has no input | `bills_repository.dart` 718-728; `tables.dart` 242. **High** |
| Farmer (consignor) payable | **Partial** — `Farmers.currentBalance` updated locally; no dedicated ledger screen | `broker_billing_service`. **High** |
| Buyer (consignee) receivable | Generic party ledger | **Medium** |
| Patti / farmer settlement statement | **Missing UI** — `FarmerSettlement` model orphaned; no patti print | models orphaned. **High** |
| Daily lot register | **Missing** — no screen; `getLots`/`getDailySummary` in unused repo | **High** |
| Weighbridge integration | **Missing/unverified** | **Low** |
| Perishable same-day settlement | **Missing** — no settlement workflow screen | **Medium** |
| Cash advances to farmers | **Missing** — payout exists, advance/recovery does not | **Medium** |
| APMC compliance | **Missing/unverified** | **Low** |
| Multi-commodity rates | **Partial** — `RateTrend` per veg modeled but unused | **Medium** |

---

## 4. Missing UI Components

- **No Mandi dashboard screen.** Dashboard is the shared retail `DashboardController` (nav handler `executive_dashboard`). A `VegetableBrokerStrategy` exists (`features/dashboard/logic/concrete_strategies.dart` 259+) but `getWidgets()` returns `[]` and `quickActions` returns `[]` — it contributes no widgets. **High.**
- **Weight entry sheet (present):** `_showMandiEntrySheet` — captures Lot ID, Commission (₹), Gross Wt, Tare Wt, live Net Weight, Rate/Kg. **Verified working & gated** via `FeatureResolver.isMandiMode` (`bill_creation_screen_v2.dart` 262-267, 345-350). This is the only bespoke Mandi UI.
- **Farmer picker + quick-add (present):** `_buildFarmerList` / `_showFarmerSearch` / `_showAddFarmerDialog` stream farmers from local DB (`brokerService.watchFarmers`). **Verified.**
- **Missing:** lot register list, auction/rate board, farmer ledger/passbook, patti/settlement statement, crate-return tracker (despite the alert in §5), commodity rate-history screen. **High.**
- **Missing fields in live sheet:** market fee, hamali/labor, weighing charge, grade, arrival date, vehicle number — all are industry-standard and several are declared in config/models but absent from the only input UI. **High.**

---

## 5. Missing Widgets & Dashboard / KPI Cards

- **Dashboard config exists:** `features/dashboard/v2/config/dashboard_business_config.dart` (line 156): revenueCardLabel "Mandi Sales", kpi2 "Lot Pending", kpi3 "Commission Due", invoiceTableName "Mandi Bill". **Verified labels exist** but the underlying values are sourced from generic dashboard data, not Mandi entities (Stack A is unused). **Medium.**
- **Quick actions:** `features/dashboard/v2/widgets/business_quick_actions.dart` (line 309) — "New Lot Entry" → `AppScreen.stockEntry` (generic stock entry), "Farmer List" → `AppScreen.suppliers` (generic suppliers). Functional but reuses generic retail screens; "New Lot Entry" does **not** open the Mandi weight sheet. **Medium.**
- **Alerts widget — HARDCODED COUNTS (confirmed):** `features/dashboard/v2/widgets/business_alerts_widget.dart`:
  - title getter "Mandi Lot Alerts" (line ~237).
  - alert items (line ~538): "Lots Pending Payment / Farmer commission due" `count: '12'`, and "Crate Returns Due / Return empty crates" `count: '45'`. **Both counts are string literals**, not derived from any query. **High** (misleading data).
  - Note: "Crate Returns Due" implies crate management, but **no crate tracking exists** anywhere (capability `useCrateManagement` is declared but has no consumer — §6).

---

## 6. Navigation & Route Gaps

**Retail sidebar IDs → screen resolution** (`sidebar_navigation_handler.dart` `getScreenForItem`): every ID present in `_getRetailSections()` was cross-checked and resolves to a real screen widget (e.g., `executive_dashboard`→`DashboardController`, `new_sale`→`BillCreationScreenV2`, `customers`→`CustomersListScreen`, `party_ledger`→`PartyLedgerListScreen`, financial/tax/ops IDs→reports/GST screens). **No `default→placeholder` hits found for retail IDs.** So the shared sidebar navigates cleanly — but it is **generic retail, not Mandi** (§18).

**Mandi-specific navigation is essentially absent / redirect-only:**
- **Module routes redirect to legacy screens.** `Dukan_x/lib/modules/vegetables_broker/routes/vegetables_broker_routes.dart`: `/veg-broker/billing`→`/billing_flow`, `/veg-broker/farmers`→`/customers_list`, `/veg-broker/commission`→`/reports`, `/veg-broker/settlement`→`/party_ledger`, all via `LegacyRouteRedirect`. The file comment itself states "the vegetable-broker vertical has no dedicated screens yet." **Verified. High.**
- **Module `navItems` are orphaned in desktop.** `VegetablesBrokerModule.navItems` (Rate Entry / Farmers / Commission / Settlement) feed only `module_registry.buildNavItems(...)`. A repo-wide grep for `buildNavItems` finds **only its definition** (`core/module/module_registry.dart`) — **no UI consumer**. The desktop sidebar uses the separate hardcoded `sidebarSectionsProvider` instead. So these nav items never render. **High.**
- **Module registered:** `VegetablesBrokerModule()` is instantiated in `core/module/module_loader.dart` (line 63), so its sync/ws handlers load even though its nav/routes are unreachable from the main sidebar.

**Orphaned data layer (confirmed):** grep for `VegetableBrokerRepository`, `VegetableLot`, `MandiSession`, `VegetableBuyer`, `FarmerSettlement` across `lib/` returns matches **only** within the model/repo files themselves, their generated `.freezed.dart`/`.g.dart`, and the codegen tool `tool/generate_freezed_files.dart`. **No screen, provider, or service consumes Stack A.** It is fully orphaned dead code. **High.**

**Capability mismatches:** `useCrateManagement` and `useDailyRates` are granted to `vegetablesBroker` (and plan-mapped in `core/subscription/plan_mapping_builder.dart`) but have **no UI consumer** (grep shows only capability defs, plan mapping, tests, and dashboard `keyCapabilities`). Crate management and daily-rate board are advertised by capability but not implemented. **Medium.**

---

## 7. Backend Integration Gaps

- **Stack A repository targets a REST backend** (`/vegetable-broker/lots|farmers|buyers|session|settlements|daily-summary|rate-history`) via `ApiClient` — but is never instantiated, so **none of these endpoints are ever called from the app.** `vegetable_broker_repository.dart`. **High.**
- **Stack B (live) is local-only.** `BrokerBillingService` writes to Drift (`Farmers`, `CommissionLedger`) with no API/sync call. Farmer balances and commission ledger never leave the device. **High.**
- **Sync handler mismatch:** `VegetablesBrokerSyncHandler` syncs collection `veg_rate_entries` at `/veg-broker/rates` — this matches **neither** Stack A (`/vegetable-broker/...`) **nor** Stack B (Drift `Farmers`/`CommissionLedger`). It appears to sync a "rate entries" concept that has no model or table in the app. **High.**
- **WS handler:** `VegetablesBrokerWsHandler` listens for `vegbroker.rate.updated`, `vegbroker.settlement.due` — no consumer wiring found for these events beyond the handler stub. **Medium / unverified** (handler body not fully traced).

---

## 8. Database & API Issues (real vs mock; hardcoded; wiring)

- **Hardcoded alert counts (real bug):** `business_alerts_widget.dart` counts `'12'` and `'45'` are literals (§5). **High.**
- **Live persistence is real but local:** `Farmers` + `CommissionLedger` Drift tables (`tables.dart` 3449-3499) are real, with migration creating them (`app_database.dart` ~597-599). `Bills` table also carries `brokerId`, `commissionAmount`, `marketCess` columns (`tables.dart` 241-242). **Verified.**
- **No sync columns on broker tables:** `Farmers`/`CommissionLedger` have `createdAt/updatedAt/isActive` but no `isSynced`/`syncStatus`/`version` fields, and no sync handler covers them. They are excluded from offline-first sync. **High.**
- **Stack A repository is wired to nothing** (no provider/service holds a `VegetableBrokerRepository`). **High.**
- **Dashboard KPIs ("Lot Pending", "Commission Due") draw from generic dashboard data, not from `CommissionLedger`** — **unverified** that they reflect real broker numbers; given Stack A is unused and no query joins `CommissionLedger` into the dashboard, these KPIs are likely placeholder. Marked **unverified** pending dashboard-data-source trace.

---

## 9. Responsive Design

- The Mandi weight sheet uses `showModalBottomSheet(isScrollControlled: true)` with `MediaQuery.viewInsets.bottom` padding — keyboard-aware (`bill_creation_screen_v2.dart` 660-668). Reasonable on mobile. **Low.**
- The sheet uses a hardcoded white background (`color: Colors.white`) and green text regardless of theme — breaks dark mode (`_showMandiEntrySheet` Container decoration). **Low/Medium (theming).**
- Desktop layout inherits the generic retail sidebar/shell; **no Mandi-specific responsive concerns verified** beyond the shared shell. **unverified** for very wide/very narrow breakpoints.

---

## 10. Performance

- `watchFarmers` issues a filtered reactive query (`userId == ? AND isActive`) — fine for small farmer lists. No pagination; could degrade with thousands of farmers. **Low.**
- `_showMandiEntrySheet` recomputes `net` per build via `StatefulBuilder` — trivial cost. **Low.**
- No N+1 or heavy-loop issues found in the Mandi path. Orphaned Stack A adds dead code/codegen weight but no runtime cost. **Low.**

---

## 11. Security (RBAC, capability-bypass)

- **Capability enforcement at write path (good):** `bills_repository.dart` (~165) calls `FeatureResolver.enforceAccess(bill.businessType, BusinessCapability.useCommission)` before broker logic — server-of-record gate on commission. **Verified. Positive.**
- **Sidebar gating** filters items by capability + RBAC permission (`sidebar_configuration.dart` `sidebarSectionsProvider`). **Verified.**
- **Local-only farmer balances** mean payables are unauditable server-side and tamperable on-device (no sync, no server validation). For a money-bearing commission ledger this is a **High** integrity concern.
- **Payout hardcodes `paymentMode: 'CASH'`** with no cash/bank selection or authorization step (`payoutFarmer`). Potential for unreconciled cash leakage. **Medium.**
- No capability-bypass found in the Mandi UI itself. **unverified** whether legacy redirect routes (`/billing_flow` etc.) re-check `vegetablesBroker` capabilities.

---

## 12. Offline Mode Gaps

- Live broker data is **Drift-local**, so it works fully offline — but it **never syncs** (no sync columns, no handler covering `Farmers`/`CommissionLedger`; the module's sync handler targets an unrelated `veg_rate_entries`). Multi-device or post-reinstall data loss risk. **High.**
- Stack A (API repo) would require connectivity but is unused. **N/A.**
- **Conflict resolution / idempotency** for broker writes: not applicable since they don't sync. **High gap** for a commission-agent who may use multiple devices at the mandi.

---

## 13. Business Logic Inconsistencies

- **Commission unit mismatch (confirmed):** The entry sheet labels the field "Commission (₹)" and stores a **flat amount** on `BillItem.commission` (`_showMandiEntrySheet`). At save, `Bill.commissionAmount = Σ item.commission` (flat). Then `bills_repository.dart` (718-728) converts it back to a **percentage**: `commissionRate = commissionAmount/grandTotal*100`, and `recordBrokerSale` recomputes `commissionAmount = saleAmount*rate/100`. The flat→%→flat round-trip is mathematically self-consistent for a single bill but: (a) is confusing/fragile, (b) discards intended per-lot/per-farmer commission %, and (c) misrepresents commission as a blended bill-level rate. **High.**
- **Labor/market-fee dropped:** `recordBrokerSale` is always called with `laborCharges`/`otherExpenses` defaulting to 0 — hamali/weighing/market cess captured nowhere in the live flow even though `CommissionLedger` and `Bills.marketCess` support them. Net-payable-to-farmer is therefore overstated. **High.**
- **Net weight math:** `net = (gross - tare).clamp(0, double.infinity)` — clamps negatives to 0 silently instead of rejecting bad input (§14). **Medium.**
- **Single broker/farmer per bill:** `Bill.brokerId` is one farmer, but a bill can contain multiple lots from different farmers; per-lot farmer attribution is lost when posting to `CommissionLedger`. **High.**
- **GST 0% correctness:** `defaultGstRate 0.0`, `gstEditable false`, and the sheet sets `gstRate: 0`. Correct for typical APMC agri produce (exempt). **Verified correct.** (Edge: taxable commission services under GST are not modeled — **Low/unverified**.)

---

## 14. Data Validation Issues

- **No `gross >= tare` validation:** if tare > gross, net silently becomes 0 via `.clamp` rather than an error (`_showMandiEntrySheet`). **High.**
- **No positive-net guard:** a lot can be added with net weight 0 (e.g., empty/invalid weights), producing a zero-qty bill line. **Medium.**
- **Commission unbounded:** "Commission (₹)" accepts any number with no range/percentage cap; `double.tryParse(v) ?? 0` silently zeroes invalid input. **Medium.**
- **Rate parsing:** `rate = double.tryParse(v) ?? 0` — empty/invalid rate becomes 0, allowing a ₹0 sale. **Medium.**
- **Farmer add dialog:** `createFarmer` inserts with phone/village optional and no phone format / duplicate checks (`broker_billing_service.createFarmer`). **Low.**
- **No APMC/lot-number uniqueness** validation; `lotId` is free text and optional. **Low.**

---

## 15. UX Problems

- The Mandi user lands in a **generic retail workspace** (10 sections incl. BuyFlow, GSTR-1, HSN, B2B/B2C) that mostly doesn't apply to a commission agent (§18). High cognitive load, low relevance. **High.**
- "New Lot Entry" quick action opens **generic Stock Entry**, not the weight sheet — inconsistent mental model (`business_quick_actions.dart`). **Medium.**
- Weight sheet hardcodes light theme (white bg/green text) — jarring in dark mode (§9). **Low/Medium.**
- "Crate Returns Due: 45" alert implies a feature that doesn't exist — sets false expectations (`business_alerts_widget.dart`). **Medium.**
- No patti/settlement print or farmer passbook means the agent cannot hand a statement to the farmer — a core daily workflow is absent. **High.**

---

## 16. Accessibility

- Bottom-sheet text fields rely on `labelText` (good for screen readers) but the live "Net Weight" result is plain colored text with no semantic label/announcement (`_showMandiEntrySheet`). **Low.**
- Hardcoded green-on-white in the sheet may fail contrast in some conditions and ignores system theme/large-text. **Low.**
- Icon-only quick actions have text labels (good). No explicit `Semantics`/tooltips verified on Mandi widgets. **unverified.**
- Full WCAG validation requires manual assistive-tech testing — out of scope here. **unverified.**

---

## 17. Bugs / Errors / Crash Scenarios

- **`getSingle()` will throw if farmer missing:** `recordBrokerSale` and `payoutFarmer` use `(select farmers where id==farmerId).getSingle()`. If `brokerId` references a non-existent/foreign farmer id, `getSingle()` throws `StateError`. In `recordBrokerSale` this is caught/logged non-blocking (`bills_repository.dart` 729-731), but `payoutFarmer`'s caller error handling is **unverified** → potential uncaught exception. **Medium.**
- **Division guard present:** commission rate calc guards `grandTotal>0 ? grandTotal : 1` — no div-by-zero. **OK.**
- **Hardcoded alert counts** are not a crash but display wrong data always (§5). **High.**
- **Silent zeroing** of invalid weight/rate/commission (§14) can produce ₹0 or zero-net bills without warning. **Medium.**
- **Theme assumption** (white bg) is cosmetic, not a crash. **Low.**

---

## 18. Unnecessary / Irrelevant Features Shown (shared retail sidebar)

Because resolution falls to `_getRetailSections()`, the Mandi user is shown many sections that are irrelevant or confusing for a commission agent (`sidebar_configuration.dart`):
- **BuyFlow** (Purchase Orders, Supplier Bills, Stock Reversal) — a commission agent consigns, doesn't buy stock. **Flag.**
- **Tax & Compliance** (GSTR-1, B2B/B2C, HSN Reports, Tax Liability) — agri produce is GST-exempt for this type (`defaultGstRate 0.0`); these screens are noise. **Flag.**
- **Inventory & Stock** valuation/batch — perishable consignment isn't owned inventory. **Flag.**
- **Margin Analysis / Product Performance** — not the agent's economic model (commission is). **Flag.**

Conversely, **core Mandi entries are absent** from the sidebar: Lot Register, Auction/Rate Board, Farmers ledger, Buyers ledger, Commission report, Settlement/Patti. **Priority: High** — replace the retail fallthrough with a dedicated `_getVegBrokerSections()`.

---

## 19. Recommendations & Prioritized Implementation Plan

**Critical / High (do first)**
1. **Add a dedicated sidebar builder** `_getVegBrokerSections()` and a `case BusinessType.vegetablesBroker` in `_getSectionsForBusiness` — surface Lot Register, Farmers, Buyers, Commission, Settlement/Patti, Rate Board; hide BuyFlow/GST/inventory-valuation noise. (`sidebar_configuration.dart`)
2. **Unify the data model.** Pick one stack. Recommended: promote Stack A's richer domain (`VegetableLot`, `MandiSession`, `FarmerSettlement`, `RateTrend`) into real Drift tables + repository, OR extend Stack B (`Farmers`/`CommissionLedger`) with lot/session/settlement tables. Delete or wire the orphaned Stack A so there is a single source of truth.
3. **Build the missing screens:** Mandi dashboard (wire `VegetableBrokerStrategy.getWidgets`), Lot Register, Farmer Ledger/Passbook, Patti/Settlement statement (printable), Auction/Rate board. Map them in `sidebar_navigation_handler.getScreenForItem`.
4. **Fix commission semantics:** store commission as an explicit **% rate per lot/farmer** (not flat ₹ round-tripped), and capture **labor/hamali/weighing/market fee** in the weight sheet, passing them into `recordBrokerSale` instead of defaulting to 0. (`bill_creation_screen_v2.dart`, `bills_repository.dart`, `broker_billing_service.dart`)
5. **Replace hardcoded alert counts** ('12','45') with real queries over `CommissionLedger`/`Farmers` (pending payables) and a crate table; or remove the crate alert until crate management exists. (`business_alerts_widget.dart`)
6. **Add offline-first sync** for `Farmers`/`CommissionLedger` (sync columns + a sync handler that matches the actual tables), and reconcile the stray `veg_rate_entries`/`/veg-broker/rates` handler with reality. (`tables.dart`, `vegetables_broker_sync_handler.dart`)
7. **Validation:** enforce `gross >= tare`, net > 0, rate > 0, commission within bounds; reject rather than silently clamp/zero. (`_showMandiEntrySheet`)

**Medium**
8. Per-lot multi-farmer attribution on a single bill (don't collapse to one `brokerId`).
9. Implement crate management & daily-rate board to honor `useCrateManagement`/`useDailyRates` capabilities (or revoke the capabilities).
10. Make "New Lot Entry" quick action open the weight sheet; add cash/bank choice to `payoutFarmer`.
11. Theme-aware Mandi sheet (remove hardcoded white/green).

**Low**
12. Phone/duplicate validation on farmer add; lot-number uniqueness.
13. e-Way bill / APMC compliance hooks where applicable; weighbridge integration.
14. Accessibility passes (semantics on net-weight, contrast, large text).

---

## 20. Confidence & Coverage

**Confidence: High** for structural findings (no presentation layer, sidebar fallthrough, orphaned Stack A, hardcoded alert counts, commission round-trip, local-only persistence, redirect-only module routes, orphaned module navItems). These are directly evidenced by the cited files.

**Files sampled (read in full or relevant ranges):**
- `lib/models/business_type.dart` (full)
- `lib/core/billing/business_type_config.dart` (full)
- `lib/widgets/desktop/sidebar_configuration.dart` (retail/service/clinic/restaurant/petrol sections; ~1022/1162 lines)
- `lib/widgets/desktop/sidebar_navigation_handler.dart` (full)
- `lib/features/vegetable_broker/data/models/vegetable_broker_models.dart` (full)
- `lib/features/vegetable_broker/data/repositories/vegetable_broker_repository.dart` (full)
- `lib/modules/vegetables_broker/{vegetables_broker_module,routes/...,sync/...,websocket/...}.dart` (full)
- `lib/features/dashboard/v2/widgets/business_quick_actions.dart` (veg case), `business_alerts_widget.dart` (veg case), `v2/config/dashboard_business_config.dart` (veg case)
- `lib/features/dashboard/logic/concrete_strategies.dart` (VegetableBrokerStrategy)
- `lib/core/isolation/business_capability.dart` (vegetablesBroker set)
- `lib/core/billing/feature_resolver.dart` (mandi getters)
- `lib/features/billing/presentation/screens/bill_creation_screen_v2.dart` (Mandi sheet + farmer picker + save)
- `lib/features/billing/services/broker_billing_service.dart` (full)
- `lib/core/repository/bills_repository.dart` (broker save block + commission enforce)
- `lib/core/database/tables.dart` (Farmers, CommissionLedger, Bills broker columns), `app_database.dart` (migration)

**Grep cross-checks:** `vegetablesBroker`, `VegetableBrokerRepository|VegetableLot|MandiSession|FarmerSettlement|VegetableBuyer`, `useCommission|useCrateManagement|useFarmerLinking|useDailyRates`, `buildNavItems`, `recordBrokerSale|payoutFarmer|createFarmer`, `brokerService|watchFarmers`.

**Skipped / unverified:**
- Full body of `sidebar_configuration.dart` beyond line 1022 (pharmacy/remaining sections) — not needed; veg uses retail default.
- Exact data source feeding dashboard KPI cards ("Lot Pending"/"Commission Due") — **unverified** whether they query `CommissionLedger`.
- WS event consumers for `vegbroker.*` — handler stub only inspected.
- `payoutFarmer` caller error-handling path — **unverified**.
- Multi-firm, OCR, e-Way bill platform features — **unverified** for this type.
- Runtime/build verification not performed (read-only audit).
