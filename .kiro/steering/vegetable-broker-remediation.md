---
inclusion: always
---

# Vegetable Broker (Mandi) Remediation — Persistent Session Rules

This steering file captures the authoritative Ground Truth, Conventions, and Operating
Rules for the multi-phase remediation of the `vegetablesBroker` business vertical in the
DukanX Flutter app. It exists so these facts persist across the whole session and are
never re-derived. Treat the Ground Truth section as authoritative unless the live
codebase directly contradicts it — in which case STOP and report.

---

## GROUND TRUTH (verified by prior audit — authoritative, do not re-discover)

### Two disconnected data stacks exist

- **Stack A (DEAD CODE)** — `lib/features/vegetable_broker/data/models/vegetable_broker_models.dart`
  + `data/repositories/vegetable_broker_repository.dart`. Freezed models
  (`VegetableLot`, `Farmer`, `VegetableBuyer`, `MandiSession`, `RateTrend`,
  `FarmerSettlement`) calling `/vegetable-broker/*` via `ApiClient`. Zero consumers
  anywhere in `lib/` outside the files themselves and their generated
  `.freezed.dart`/`.g.dart`.
- **Stack B (LIVE, LOCAL-ONLY)** — `lib/features/billing/services/broker_billing_service.dart`
  (`BrokerBillingService`) backed by Drift tables `Farmers` + `CommissionLedger`
  (`lib/core/database/tables.dart`, lines 3449–3499). This is what the app actually
  uses. No sync columns; never leaves the device.

### Other verified facts

- No `presentation/` or `screens/` folder under `features/vegetable_broker/`. Only
  Mandi-specific UI is `_showMandiEntrySheet` (weight-entry bottom sheet) in
  `lib/features/billing/presentation/screens/bill_creation_screen_v2.dart`, plus a
  farmer picker/quick-add in the same file.
- `sidebar_configuration.dart` has no `case BusinessType.vegetablesBroker` in
  `_getSectionsForBusiness` — falls through to `_getRetailSections()`. Users get an
  irrelevant retail sidebar and are missing Lot Register, Farmer Ledger, Commission
  Report, Settlement/Patti, Rate Board.
- `lib/modules/vegetables_broker/routes/vegetables_broker_routes.dart` redirects every
  Mandi route to legacy screens via `LegacyRouteRedirect`. `VegetablesBrokerModule.navItems`
  (built by `module_registry.buildNavItems()`) has zero UI consumers — desktop sidebar
  uses a separate hardcoded provider.
- **COMMISSION BUG** (`bill_creation_screen_v2.dart` + `lib/core/repository/bills_repository.dart`
  lines ~718–728): entry sheet captures a FLAT ₹ commission; bills_repository
  back-converts to a % (`commissionAmount/grandTotal*100`); `recordBrokerSale` recomputes
  a flat amount from that %. Round-trip discards true per-lot/per-farmer rates.
- labor/hamali/weighing/market-fee are never captured — `recordBrokerSale` always passes
  `laborCharges=0`, `otherExpenses=0`, despite `CommissionLedger` and `Bills.marketCess`
  supporting them. Net payable to farmer is overstated.
- `Bill.brokerId` is a single farmer per bill, but bills can contain lots from multiple
  farmers — per-lot attribution is lost on save.
- **HARDCODED FAKE DATA**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
  has literal counts: "Lots Pending Payment" count: `'12'` and "Crate Returns Due"
  count: `'45'`. Crate management (`useCrateManagement`) has zero implementation.
- `VegetableBrokerStrategy.getWidgets()` and `.quickActions` in
  `lib/features/dashboard/logic/concrete_strategies.dart` both return `[]`, despite
  `dashboard_business_config.dart` defining real labels ("Mandi Sales", "Lot Pending",
  "Commission Due").
- "New Lot Entry" quick action (`business_quick_actions.dart`) opens generic
  `AppScreen.stockEntry`, not the Mandi sheet. "Farmer List" opens generic
  `AppScreen.suppliers`.
- `VegetablesBrokerSyncHandler` syncs `veg_rate_entries` at `/veg-broker/rates` — matches
  neither stack. Sync code for a concept with no backing model.
- No validation: gross < tare silently clamps net to 0; invalid rate/commission silently
  becomes 0 (`double.tryParse(v) ?? 0`), allowing ₹0 sales.
- `payoutFarmer` hardcodes `paymentMode: 'CASH'`, no bank option, no authorization step.
- `recordBrokerSale`/`payoutFarmer` call `.getSingle()` on farmer lookup → throws
  `StateError` if id missing. `recordBrokerSale` catches non-blocking; `payoutFarmer`'s
  caller-side handling is unverified and may crash.
- GST: `defaultGstRate 0.0` / `gstEditable false` is CORRECT (APMC produce exempt) — DO
  NOT TOUCH.
- Weight sheet hardcodes `Colors.white` regardless of theme — breaks dark mode.

---

## NON-NEGOTIABLE CONVENTIONS (apply to all new code)

- RID pattern for all new IDs: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
- All money fields are integer paise — never float/double for currency.
- Tenant isolation via single-table DynamoDB design (same as rest of DukanX).
- All new Lambda endpoints wrapped in `withRequestContext`.
- Do NOT modify any other business type's code, capability config, or sidebar sections.
- Do NOT change `defaultGstRate` / `gstEditable` for this business type.

> NOTE: Existing Stack B Drift tables (`Farmers`, `CommissionLedger`) currently use
> `RealColumn` (double) for money. The paise-integer convention applies to ALL NEW code
> and tables; reconciling the existing double columns is a Phase 1 concern to be handled
> explicitly via migration, not silently.

---

## OPERATING RULES FOR KIRO

- Execute phases in order. Never skip ahead. Keep the spec task list updated as you go.
- After each phase: (a) list every file created/modified/deleted, (b) run `flutter analyze`
  on touched files and report results, (c) output exactly `PHASE N COMPLETE — AWAITING
  APPROVAL`, then stop and yield control.
- Do NOT auto-continue to the next phase. Wait for `APPROVED`. If the reply contains
  changes, apply them and stop again.
- If any Ground Truth item contradicts the actual codebase, STOP immediately and report
  the discrepancy. Do not route around it.
- Never invent commission/tax/settlement logic not specified in the spec. If a rule is
  ambiguous, STOP and ask — do not guess.
- Prefer surgical diffs over rewrites. Show diffs for review before applying where
  practical.

---

## PHASE MAP (high level)

- **Phase 0** — Architecture decision (read-only, no code).
- **Phase 1** — Data layer unification (delete losing stack, add Drift tables, sync
  columns, migration, fix sync handler).
- **Phase 2** — Commission & business logic fixes (rate not round-trip, capture
  labor/fees, multi-farmer per bill, validation, harden lookups, cash/bank payout).
- **Phase 3** — Missing screens (Mandi Dashboard, Lot Register, Farmer Ledger,
  Patti/Settlement, Rate Board).
- **Phase 4** — Navigation & sidebar wiring.
- **Phase 5** — Dashboard data integrity (kill hardcoded counts; crate decision).
- **Phase 6** — Offline sync correctness (end-to-end).
- **Phase 7** — Theming & polish (dark mode, semantics, validation).
- **Phase 8** — Final verification.
