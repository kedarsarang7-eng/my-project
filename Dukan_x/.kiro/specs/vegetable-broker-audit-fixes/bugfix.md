# Bugfix Requirements Document

## Introduction

The vegetable broker / Mandi business-type audit (`audit-reports/business-types/audit-vegetablesBroker.md`) found that `BusinessType.vegetablesBroker` has almost no dedicated presentation layer: a full domain model (`VegetableLot`, `Farmer`, `VegetableBuyer`, `MandiSession`, `RateTrend`, `FarmerSettlement`) and a REST repository (`VegetableBrokerRepository`, "Stack A") were built but are never instantiated anywhere in the app, while the only Mandi feature that actually renders — a weight-entry bottom sheet embedded in the shared `BillCreationScreenV2`, backed by a second, unrelated local-Drift stack (`BrokerBillingService` + `Farmers`/`CommissionLedger`, "Stack B") — has its own set of unfixed correctness, validation, and UX defects. The sidebar has no dedicated case for this business type at all, so Mandi users see the full generic retail navigation instead of Mandi-relevant sections, and none of the Mandi-specific screens the config/capabilities/models imply (lot register, farmer ledger, patti/settlement, rate board, crate tracking) exist.

Direct re-verification of the current codebase against every file/line cited in the audit confirms 14 distinct, still-present defects, grouped below by shared root cause rather than 1:1 with every audit bullet. Two root causes are structural and touch many of the others: (a) the **two disconnected data stacks** (orphaned Stack A vs. live-but-incomplete Stack B), and (b) the **absent sidebar case / presentation layer**, which is why Mandi-specific screens (lot register, farmer ledger, patti/settlement, rate board, crate tracking) were never built even though the config, capabilities, and Stack A models all assume they exist.

This bugfix is scoped strictly to `BusinessType.vegetablesBroker` — files under `lib/features/vegetable_broker/`, `lib/modules/vegetables_broker/`, the `vegetablesBroker` blocks of `sidebar_configuration.dart`/`sidebar_navigation_handler.dart`/`business_capability.dart`/`business_type_config.dart`/`business_alerts_widget.dart`/`business_quick_actions.dart`/`dashboard_business_config.dart`/`concrete_strategies.dart`, and the Mandi-gated branches of `bill_creation_screen_v2.dart`/`bills_repository.dart`/`broker_billing_service.dart`. Other business types already covered by their own specs (`clinic-audit-fixes`, `petrol-pump-audit-fixes`, `pharmacy-audit-fixes`, `hardware-audit-fixes`) are not touched, and vegetablesBroker's own already-correct behaviors (GST 0%/non-editable default, barcode/POS disabled, capability enforcement at the billing write path, the existing division-by-zero guard in commission calc, farmer picker/quick-add streaming, keyboard-aware bottom sheet padding) are preserved unchanged.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a user's business type is `vegetablesBroker` THEN `sidebar_configuration.dart`'s `_getSectionsForBusiness` has no `case BusinessType.vegetablesBroker` and falls through to `default: _getRetailSections()`, so the user sees the full generic 10-section retail sidebar (BuyFlow, Inventory valuation, Tax & Compliance/GSTR-1/HSN, Margin Analysis, etc.) and no Lot Register, Auction/Rate Board, Farmers ledger, Buyers ledger, Commission report, or Settlement/Patti entry appears anywhere in the sidebar

1.2 WHEN a vegetablesBroker user needs a Mandi dashboard, lot register, farmer ledger/passbook, patti/settlement statement, or auction/rate-discovery board THEN no `presentation/`/`screens/` folder exists under `features/vegetable_broker/` for any of them; `vegetables_broker_routes.dart` redirects every Mandi route (`/veg-broker/billing`, `/veg-broker/farmers`, `/veg-broker/commission`, `/veg-broker/settlement`) to unrelated legacy screens (`/billing_flow`, `/customers_list`, `/reports`, `/party_ledger`) via `LegacyRouteRedirect`; `VegetablesBrokerModule.navItems` are built but have no consumer (the desktop sidebar uses the separate `sidebarSectionsProvider` instead); and `VegetableBrokerStrategy.getWidgets()`/`quickActions` both return empty lists, contributing no dashboard content

1.3 WHEN any code path reads or writes vegetable-broker domain entities (lots, farmers, buyers, mandi sessions, rate trends, farmer settlements) THEN two disconnected data stacks exist — Stack A (`VegetableBrokerRepository` + freezed models `VegetableLot`/`Farmer`/`VegetableBuyer`/`MandiSession`/`RateTrend`/`FarmerSettlement`, targeting a REST backend) has zero screen/provider/service consumers anywhere in `lib/`, while Stack B (`BrokerBillingService` + Drift `Farmers`/`CommissionLedger`) is the only stack the live billing sheet actually uses and has no analogue for lots, sessions, settlements, or rate trends

1.4 WHEN the vegetablesBroker dashboard alert panel renders (`business_alerts_widget.dart`) THEN "Lots Pending Payment / Farmer commission due" always displays the literal string `'12'` and "Crate Returns Due / Return empty crates" always displays the literal string `'45'`, regardless of actual pending commissions, and regardless of the fact that no crate-tracking data exists at all

1.5 WHEN a user taps the "New Lot Entry" quick action on the dashboard (`business_quick_actions.dart`) THEN the system navigates to the generic `AppScreen.stockEntry` screen instead of opening the Mandi weight-entry bottom sheet (`_showMandiEntrySheet`), which is the actual Mandi lot-intake workflow

1.6 WHEN a lot is entered via the Mandi weight sheet THEN the "Commission (₹)" field captures and stores a **flat rupee amount** on `BillItem.commission`, but `bills_repository.dart` (~718-728) converts `Bill.commissionAmount` back into a **percentage** (`commissionRate = commissionAmount/grandTotal*100`) and `recordBrokerSale` recomputes `commissionAmount = saleAmount*rate/100` from that derived rate — discarding any intended per-lot/per-farmer commission percentage and misrepresenting commission as a blended, bill-level rate

1.7 WHEN `recordBrokerSale` posts a broker sale THEN it is always called with `laborCharges`/`otherExpenses` defaulting to `0`, and the Mandi weight sheet has no input fields for market fee, hamali/labor charge, or weighing charge, even though `CommissionLedger` and `Bills.marketCess` already have columns to store them — so the net amount payable to the farmer is systematically overstated

1.8 WHEN gross/tare weights, commission, or rate are entered in the Mandi weight sheet THEN: (a) if tare exceeds gross, `net = (gross - tare).clamp(0, double.infinity)` silently produces net weight `0` instead of rejecting the input; (b) a lot can be saved with net weight `0` (zero-quantity bill line); (c) the "Commission (₹)" field accepts any numeric value with no range/percentage cap and `double.tryParse(v) ?? 0` silently zeroes invalid input; (d) `rate = double.tryParse(v) ?? 0` silently turns invalid/empty rate input into `0`, allowing a ₹0 sale line to be saved

1.9 WHEN vegetable-broker data changes (farmer balances, commission ledger entries) THEN the `Farmers`/`CommissionLedger` Drift tables carry no `isSynced`/`syncStatus`/`version` columns and no sync handler covers them, while `VegetablesBrokerSyncHandler` syncs an unrelated collection (`veg_rate_entries` at `/veg-broker/rates`) that matches neither Stack A's endpoints nor Stack B's tables — so farmer balances and commission ledger entries never leave the device and are lost on reinstall or across multiple devices at the same mandi

1.10 WHEN the Mandi weight sheet (`_showMandiEntrySheet`) renders THEN its container uses a hardcoded `color: Colors.white` background with green text regardless of the active app theme, so it visually breaks (jarring light panel) in dark mode

1.11 WHEN `BrokerBillingService.payoutFarmer` pays out a farmer THEN it always posts the payment with `paymentMode: 'CASH'` hardcoded, with no cash/bank selection exposed to the user before the payout is recorded

1.12 WHEN a single bill contains lots from multiple different farmers THEN the system stores only one `Bill.brokerId` for the entire bill, so per-lot farmer attribution is lost when the sale is posted to `CommissionLedger` — commission/payable amounts cannot be correctly split across the actual consignor farmers of that bill

1.13 WHEN `BusinessCapability` grants `useCrateManagement` and `useDailyRates` to vegetablesBroker (and `plan_mapping_builder.dart` maps them into a subscription plan) THEN no UI anywhere consumes either capability — there is no crate-tracking screen/table and no daily-rate board — yet the dashboard alert panel implies crate tracking exists via the "Crate Returns Due: 45" alert

1.14 WHEN `recordBrokerSale` or `payoutFarmer` looks up a farmer via `(select farmers where id==farmerId).getSingle()` and the referenced farmer id does not exist THEN `getSingle()` throws a `StateError`; `recordBrokerSale`'s caller catches and logs this non-blocking, but `payoutFarmer`'s caller error-handling is unverified/absent, so the exception can propagate uncaught to the UI

### Expected Behavior (Correct)

2.1 WHEN a user's business type is `vegetablesBroker` THEN the system SHALL resolve a dedicated `_getVegBrokerSections()` (via a new `case BusinessType.vegetablesBroker` in `_getSectionsForBusiness`) surfacing Lot Register, Farmers, Buyers, Commission, Settlement/Patti, and Rate Board, and hiding BuyFlow/Tax & Compliance/inventory-valuation/Margin-Analysis sections that do not apply to a commission agent

2.2 WHEN a vegetablesBroker user needs a Mandi dashboard, lot register, farmer ledger/passbook, patti/settlement statement, or auction/rate-discovery board THEN the system SHALL provide reachable screens for each, mapped in `sidebar_navigation_handler.getScreenForItem`, with `vegetables_broker_routes.dart` routing to these real screens instead of `LegacyRouteRedirect`, `VegetablesBrokerModule.navItems` wired into the sidebar consumer that actually renders navigation, and `VegetableBrokerStrategy.getWidgets()`/`quickActions` returning real Mandi dashboard content instead of empty lists

2.3 WHEN any code path reads or writes vegetable-broker domain entities THEN the system SHALL use a single source of truth: Stack B (Drift `Farmers`/`CommissionLedger`) SHALL be extended with the lot/session/settlement/rate-trend data the new screens (2.2) require, and Stack A (`VegetableBrokerRepository` and its freezed models) SHALL either be wired to a real provider/service consumer or removed as dead code — it SHALL NOT remain both present and orphaned

2.4 WHEN the vegetablesBroker dashboard alert panel renders THEN "Lots Pending Payment / Farmer commission due" SHALL display a count computed from a live query over `CommissionLedger`/`Farmers` pending payables, and the crate-returns alert SHALL either display a count computed from a real crate-tracking data source or SHALL be removed until crate management (2.13) is implemented — neither SHALL be the literals `'12'`/`'45'`

2.5 WHEN a user taps the "New Lot Entry" quick action THEN the system SHALL open the Mandi weight-entry bottom sheet (`_showMandiEntrySheet`), not the generic stock-entry screen

2.6 WHEN a lot's commission is entered and saved THEN the system SHALL store and round-trip an explicit commission **percentage rate** per lot/farmer (not a flat ₹ amount silently converted to and from a blended bill-level percentage), so the farmer's intended commission rate is preserved exactly

2.7 WHEN `recordBrokerSale` posts a broker sale THEN the system SHALL capture market fee, hamali/labor charge, and weighing charge as explicit input fields in the Mandi weight sheet and SHALL pass their real values into `recordBrokerSale`'s `laborCharges`/`otherExpenses` parameters instead of defaulting to `0`, so net-payable-to-farmer reflects actual deductions

2.8 WHEN gross/tare weights, commission, or rate are entered in the Mandi weight sheet THEN the system SHALL: (a) reject entry when tare exceeds gross with a validation error instead of silently clamping net to `0`; (b) reject saving a lot with net weight `<= 0`; (c) reject or bound commission input outside a sane range instead of silently zeroing invalid input; (d) reject saving a lot with rate `<= 0` instead of silently defaulting to `0`

2.9 WHEN vegetable-broker data changes THEN the system SHALL add `isSynced`/`syncStatus`/`version`-equivalent sync columns to the `Farmers`/`CommissionLedger` Drift tables and SHALL provide (or correct) a sync handler that covers those actual tables, retiring or reconciling the stray `veg_rate_entries`/`/veg-broker/rates` handler with a real collection/table it is meant to represent

2.10 WHEN the Mandi weight sheet renders THEN it SHALL use theme-aware colors (`Theme.of(context)` / `ColorScheme`) instead of hardcoded `Colors.white` background and green text, so it renders correctly in both light and dark mode

2.11 WHEN `BrokerBillingService.payoutFarmer` pays out a farmer THEN the system SHALL accept and persist an explicit cash/bank payment-mode selection from the caller instead of hardcoding `'CASH'`

2.12 WHEN a single bill contains lots from multiple different farmers THEN the system SHALL attribute commission/payable amounts to each lot's own farmer when posting to `CommissionLedger`, instead of collapsing all lots to one bill-level `Bill.brokerId`

2.13 WHEN `useCrateManagement`/`useDailyRates` capabilities are granted to vegetablesBroker THEN the system SHALL either implement a minimal UI consumer for each (a crate-tracking record/screen and a daily-rate board screen) or SHALL revoke the capability from the vegetablesBroker registry/plan mapping so it is not advertised without a consumer

2.14 WHEN `recordBrokerSale` or `payoutFarmer` looks up a farmer via `getSingle()` and the referenced farmer id does not exist THEN the system SHALL catch the resulting error and surface a handled, user-facing message instead of allowing an uncaught exception to propagate, consistent with `recordBrokerSale`'s existing non-blocking catch/log pattern

### Unchanged Behavior (Regression Prevention)

3.1 WHEN any business type OTHER than `vegetablesBroker` resolves its sidebar sections, dashboard widgets, alerts, quick actions, or navigation routes THEN the system SHALL CONTINUE TO behave exactly as it does today, with zero references to `_getVegBrokerSections()`, the new Mandi screens, or any vegetablesBroker-specific capability/table change added by this fix

3.2 WHEN vegetablesBroker's already-correct behaviors run — `defaultGstRate: 0.0`/`gstEditable: false`, barcode/POS being disabled for this type, `FeatureResolver.enforceAccess(bill.businessType, BusinessCapability.useCommission)` gating the broker save path, the existing `grandTotal>0 ? grandTotal : 1` division-by-zero guard in commission-rate calculation, `_buildFarmerList`/`_showFarmerSearch`/`_showAddFarmerDialog` streaming farmers from `watchFarmers`, and the keyboard-aware `MediaQuery.viewInsets.bottom` padding on the weight sheet — THEN the system SHALL CONTINUE TO behave exactly as today, unaffected by this fix

3.3 WHEN business types other than vegetablesBroker are read from `business_capability.dart`'s capability registry, `plan_mapping_builder.dart`'s plan mappings, or any other module's routes/sync handlers/navItems (`clinic`, `petrolPump`, `pharmacy`, `hardware`, and all others) THEN the system SHALL CONTINUE TO return/behave exactly as before this fix

3.4 WHEN a non-vegetablesBroker bill is created, saved, or posted through `bill_creation_screen_v2.dart`, `bills_repository.dart`, or any billing service other than `BrokerBillingService` THEN the system SHALL CONTINUE TO behave exactly as today — this fix touches only the Mandi-gated (`FeatureResolver.isMandiMode`) branches of these shared files

3.5 WHEN `Farmer.createFarmer`'s existing optional phone/village fields and lack of duplicate-check behavior, or any other vegetablesBroker behavior not named in Current/Expected Behavior above, are exercised THEN the system SHALL CONTINUE TO behave exactly as today — this fix does not alter farmer-creation validation, APMC/lot-number uniqueness, e-Way bill hooks, or accessibility semantics, none of which are in scope

### Bug Condition

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type VegetablesBrokerOperation
  OUTPUT: boolean

  // True when the operation is scoped to vegetablesBroker AND touches one of
  // the 14 verified-still-defective surfaces
  RETURN X.businessType = BusinessType.vegetablesBroker
     AND X.surface IN {
           'navigation.sidebarFallthrough',           // 1.1 / 2.1
           'presentation.missingMandiScreens',        // 1.2 / 2.2
           'data.orphanedStackA',                      // 1.3 / 2.3
           'dashboard.hardcodedAlertCounts',            // 1.4 / 2.4
           'quickAction.newLotEntryWrongScreen',        // 1.5 / 2.5
           'billing.commissionRoundTripInconsistency',  // 1.6 / 2.6
           'billing.laborMarketFeeDropped',             // 1.7 / 2.7
           'validation.weightAndRateInputs',            // 1.8 / 2.8
           'sync.offlineSyncGap',                       // 1.9 / 2.9
           'theme.hardcodedLightTheme',                  // 1.10 / 2.10
           'payout.hardcodedCashMode',                   // 1.11 / 2.11
           'billing.perLotFarmerAttributionLoss',        // 1.12 / 2.12
           'capability.crateDailyRateNoConsumer',        // 1.13 / 2.13
           'error.getSingleUncaughtException'            // 1.14 / 2.14
         }
END FUNCTION
```

### Property Specification

```pascal
// Property: Fix Checking - each of the 14 vegetablesBroker defects resolved
FOR ALL X WHERE isBugCondition(X) DO
  result ← F'(X)
  ASSERT expectedBehaviorFor(X.surface)(result)   // per 2.1-2.14 above
END FOR

// Property: Preservation - all other business types and vegetablesBroker's
// own already-correct behaviors are unaffected
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)
END FOR
```
