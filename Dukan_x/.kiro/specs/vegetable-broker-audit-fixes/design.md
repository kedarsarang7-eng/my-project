# Vegetable Broker (Mandi) Audit Fixes — Bugfix Design

## Overview

Direct re-verification of the current codebase against `bugfix.md`'s 14-item defect list found that 12 of the 14 items are already resolved by prior remediation work: the dedicated `_getVegetablesBrokerSections()` sidebar case exists and is wired to five real screens (`LotRegisterScreen`, `FarmerLedgerEntryScreen`, `MandiCommissionReportScreen`, `SettlementScreen`, `RateBoardScreen`); the orphaned Stack A (`VegetableBrokerRepository` + freezed models) and `lib/modules/vegetables_broker/` have been deleted entirely; the dashboard alert panel queries real `VegetableLots` data instead of the literals `'12'`/`'45'`; the "New Lot Entry" quick action opens the real Mandi weight sheet; commission is persisted as a captured flat amount with no flat→%→flat round-trip; `recordBrokerSale`/`recordMultiLotBrokerSale` capture and validate labor/hamali/weighing/market-fee charges; `MandiSaleValidator` rejects invalid gross/tare/rate/commission input instead of silently clamping or zeroing it; `Farmers`/`CommissionLedger` carry working `syncState`/`lastModifiedAt` columns synced by a `VegetablesBrokerSyncHandler` that targets those exact tables; the Mandi weight sheet uses `Theme.of(context).colorScheme` instead of a hardcoded white/green palette; `payoutFarmer` accepts an explicit `PayoutRequest.paymentMode` (cash or bank) instead of hardcoding `'CASH'`; `recordMultiLotBrokerSale` attributes commission per-lot to each lot's own farmer instead of collapsing to one bill-level `brokerId`; and both `recordBrokerSale` and `payoutFarmer` use `getSingleOrNull()` with a handled `'Farmer not found: ...'` return instead of a throwing `getSingle()`.

Of item 1.13 ("`useCrateManagement`/`useDailyRates` granted with no UI consumer"), the `useDailyRates` half is also already resolved — `RateBoardScreen` reads real per-vegetable min/max/avg rates from the `RateHistory` table. Only the `useCrateManagement` half remains genuinely defective: the capability is granted to `vegetablesBroker` in both `business_capability.dart` and `plan_mapping_builder.dart`, but no crate table, screen, or any other consumer exists anywhere in the codebase — it is advertised and sold (via plan mapping) as a feature with zero implementation.

Additionally, re-verification surfaced one defect not in the original 14-item list: `lib/features/dashboard/logic/concrete_strategies.dart`'s `VegetableBrokerStrategy` class — whose `getWidgets()` still returns `[]`, matching the original audit's complaint — is dead code. It is registered only in `DashboardStrategyFactory` (`dashboard_strategy_factory.dart`), which has zero importers anywhere in `lib/`. The dashboard screen users actually see (`home_screen.dart`) resolves its strategy through a completely different, correctly-implemented `_MandiStrategy` class in `dashboard_strategies.dart` (non-empty `quickActions`, non-empty `widgets`). So the empty-widgets symptom never reaches a real user, but the orphaned class sits in a file already in this spec's scope (`concrete_strategies.dart`) and its continued presence risks a future maintainer wiring the wrong factory back in.

This design covers exactly two fixes, both minimal and additive-only:

1. **Revoke `useCrateManagement` from vegetablesBroker.** Remove it from `business_capability.dart`'s `vegetablesBroker` registry entry and `plan_mapping_builder.dart`'s broker/mandi plan mapping, per Requirement 2.13's explicit "either implement... or revoke" alternative. Revocation is chosen over building a minimal crate-tracking screen/table because no crate-tracking UI, data model, or user-facing workflow exists anywhere to build on, and inventing one from scratch is out of proportion to a capability-registry defect — the fix stops advertising a feature that doesn't exist rather than rushing a minimal one into existence.
2. **Remove the orphaned `VegetableBrokerStrategy` and its unused `DashboardStrategyFactory`.** Delete `dashboard_strategy_factory.dart` (zero importers) and the dead strategy classes it exclusively registers in `concrete_strategies.dart` (`VegetableBrokerStrategy`, `GroceryDashboardStrategy`, `PharmacyDashboardStrategy`, `ClinicDashboardStrategy`, `RestaurantDashboardStrategy`, `DefaultDashboardStrategy`, `MenuAction`, `DashboardWidget`) — all reachable only through the same dead factory. The live `_MandiStrategy`/`DashboardStrategyFactory` pair in `dashboard_strategies.dart`, which `home_screen.dart` actually imports and uses, is untouched.

This bugfix is scoped strictly to `lib/core/isolation/business_capability.dart`'s `vegetablesBroker` entry, `lib/core/subscription/plan_mapping_builder.dart`'s broker/mandi mapping, and `lib/features/dashboard/logic/concrete_strategies.dart` / `lib/features/dashboard/logic/dashboard_strategy_factory.dart`. No other business type, capability, screen, table, or the live `dashboard_strategies.dart` strategy factory is touched.

## Glossary

- **Bug_Condition (C)**: The disjunction of two independent surface conditions — see the formal `isBugCondition` below.
- **Property (P)**: The two surface-specific expected behaviors defined in the Correctness Properties section.
- **Preservation**: Every other business type's capability registry/plan mapping, every already-fixed vegetablesBroker behavior listed in the Overview (sidebar, screens, alerts, quick action, commission capture, charge fields, weight-sheet validation, sync, theme, payout mode, multi-farmer attribution, farmer-lookup error handling, `useDailyRates`/`RateBoardScreen`), and the live `_MandiStrategy`/`dashboard_strategies.dart` factory must remain byte-for-byte unchanged.
- **`businessCapabilityRegistry['vegetablesBroker']`**: `lib/core/isolation/business_capability.dart` — the hard-isolation capability set for the Mandi/broker vertical; currently includes `useCommission`, `useCrateManagement`, `useFarmerLinking`, `useDailyRates`, `useCreditManagement` under the "Specialized" comment block.
- **`plan_mapping_builder.dart`**: `lib/core/subscription/plan_mapping_builder.dart` — maps capabilities into subscription-plan tiers; the "Broker / mandi" block currently lists `useCommission`, `useCrateManagement`, `useFarmerLinking`, `useDailyRates`.
- **`VegetableBrokerStrategy`**: `lib/features/dashboard/logic/concrete_strategies.dart` — a `DashboardStrategy` subclass whose `getWidgets(BuildContext)` returns `[]` and whose `getMenuActions(BuildContext)` returns Mandi menu actions; reachable only via the dead `DashboardStrategyFactory` in `dashboard_strategy_factory.dart`.
- **`_MandiStrategy`**: `lib/features/dashboard/logic/dashboard_strategies.dart` — the live, correctly-implemented `DashboardStrategy` subclass for `BusinessType.vegetablesBroker`, resolved via `dashboard_strategies.dart`'s own `DashboardStrategyFactory.getStrategy`, which `home_screen.dart` calls directly. Not touched by this fix.
- **`RateHistory` / `RateBoardScreen`**: `lib/core/database/tables.dart` (table) and `lib/features/vegetable_broker/presentation/screens/rate_board_screen.dart` (screen) — the already-working reference pattern that `useDailyRates` is satisfied by; cited to show why `useDailyRates` is NOT part of this fix's scope.

## Bug Details

### Bug Condition

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type VegetablesBrokerSurfaceInput
  OUTPUT: boolean

  RETURN (X.surface = 'capability.crateManagementNoConsumer'
          AND X.businessType = BusinessType.vegetablesBroker
          AND X.capability = BusinessCapability.useCrateManagement)
      OR (X.surface = 'dashboard.orphanedVegetableBrokerStrategy'
          AND X.strategyClass = 'VegetableBrokerStrategy'
          AND X.resolvedVia = 'DashboardStrategyFactory (dashboard_strategy_factory.dart)')
END FUNCTION
```

### Examples

- **Crate management with no consumer**: A vegetablesBroker account is provisioned on a plan tier that includes `useCrateManagement` (per `plan_mapping_builder.dart`'s broker/mandi mapping). `FeatureResolver.canAccess('vegetablesBroker', BusinessCapability.useCrateManagement)` returns `true`. There is no crate table, no crate screen, no sidebar item, and no code path anywhere that reads or writes crate data — the capability grants access to nothing. A user or support agent reading the plan/capability manifest would reasonably expect a crate-tracking feature to exist; it does not. Expected: the capability is not granted, so no such expectation is created.
- **`useDailyRates` — NOT a defect (contrast case)**: The sibling capability `useDailyRates`, granted alongside `useCrateManagement` in the same registry block, IS backed by a real consumer: `RateBoardScreen` (sidebar id `mandi_rate_board`) queries the `RateHistory` table and renders per-vegetable min/max/avg rates. This capability is correctly implemented and is explicitly out of scope for this fix — Requirement 2.13 names both capabilities together, but only the `useCrateManagement` half is still broken.
- **Orphaned dashboard strategy**: `DashboardStrategyFactory.getStrategy(BusinessType.vegetablesBroker)` in `dashboard_strategy_factory.dart` returns a `VegetableBrokerStrategy()` whose `getWidgets(context)` returns `[]` — reproducing the exact "contributes no dashboard content" symptom from the original audit. However, `grep` for `dashboard_strategy_factory.dart` importers across `lib/` returns zero results — nothing calls this factory. The dashboard a real user sees (`home_screen.dart` → `dashboard_strategies.dart`'s `DashboardStrategyFactory.getStrategy` → `_MandiStrategy`) has non-empty `quickActions` (New Entry / Farmer Ledger / Daily Rates) and non-empty `widgets` (`salesSummary`, `recentBills`). Expected: the dead class and its dead factory are removed so no future wiring accidentally resurrects the broken one.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Every other capability in `businessCapabilityRegistry['vegetablesBroker']` (`useCommission`, `useFarmerLinking`, `useDailyRates`, `useCreditManagement`, and the shared product/inventory/invoice/purchase basics) is untouched — only `useCrateManagement` is removed.
- Every other business type's capability registry entry and `plan_mapping_builder.dart` mapping is untouched — only the vegetablesBroker/broker-mandi entries lose `useCrateManagement`.
- `RateBoardScreen`, the `RateHistory` table, and `useDailyRates`'s grant are not modified — `useDailyRates` already has a real consumer and is out of scope.
- The five Mandi sidebar sections/screens (`mandi_lot_register`, `mandi_farmer_ledger`, `mandi_commission_report`, `mandi_settlement`, `mandi_rate_board`), the real `mandiAlertCountsProvider` alert query, the "New Lot Entry" quick action → weight-sheet wiring, `MandiSaleValidator`, `recordBrokerSale`/`recordMultiLotBrokerSale`/`payoutFarmer`'s validation and error-handling behavior, the `VegetablesBrokerSyncHandler`, and the weight sheet's theme-aware colors are all unaffected by this fix — none of them reference `useCrateManagement` or `VegetableBrokerStrategy`.
- `dashboard_strategies.dart`'s `DashboardStrategyFactory`, `_MandiStrategy`, and every other strategy class in that file are untouched — `home_screen.dart` continues to resolve exactly the same live strategy instance it does today, with byte-for-byte identical `quickActions`/`widgets`.
- Every non-vegetablesBroker business type's dashboard strategy resolution (through `dashboard_strategies.dart`) is unaffected — this fix removes a parallel, unused factory/class hierarchy that no business type's live dashboard path depends on.

**Scope:**
All inputs that do NOT match one of the two `isBugCondition` disjuncts are unaffected. This includes: every non-vegetablesBroker business type's capabilities/plan mapping/dashboard strategy; every already-fixed vegetablesBroker behavior listed in the Overview; and `useDailyRates`/`RateBoardScreen` specifically.

## Hypothesized Root Cause

1. **`useCrateManagement` was added speculatively alongside `useFarmerLinking`/`useDailyRates`** when the broker/mandi capability set was first drafted (`business_capability.dart` "Broker / Mandi" comment block, `plan_mapping_builder.dart` "Broker / mandi" block) — likely because crate/empty-container tracking is a genuine Mandi industry need (per the original audit's §3 table), but unlike `useDailyRates` (which later gained `RateBoardScreen`+`RateHistory` in the same remediation pass that fixed the sidebar/screens/validation/sync defects), no equivalent crate table or screen was ever scheduled or built. The capability was never revisited once the rest of the vertical was remediated.

2. **`VegetableBrokerStrategy`/`DashboardStrategyFactory` (in `concrete_strategies.dart`/`dashboard_strategy_factory.dart`) appear to be an earlier, abandoned implementation attempt** that was superseded by `_MandiStrategy`/`dashboard_strategies.dart`'s own factory — both files define a same-named `DashboardStrategyFactory` class with a `getStrategy` method and a parallel set of per-business-type strategy classes, which is the classic signature of a rewrite where the old file was never deleted. `home_screen.dart` imports only the newer `dashboard_strategies.dart`, confirming which one "won."

## Correctness Properties

Property 1: Bug Condition - `useCrateManagement` Revoked for vegetablesBroker

_For any_ query of `businessCapabilityRegistry['vegetablesBroker']` or `plan_mapping_builder.dart`'s broker/mandi plan mapping where `isBugCondition` holds for the `capability.crateManagementNoConsumer` surface, the fixed system SHALL NOT include `BusinessCapability.useCrateManagement` in either the capability registry entry or the plan mapping for `vegetablesBroker`, so `FeatureResolver.canAccess('vegetablesBroker', BusinessCapability.useCrateManagement)` returns `false`.

**Validates: Requirements 2.13**

Property 2: Bug Condition - Orphaned `VegetableBrokerStrategy`/`DashboardStrategyFactory` Removed

_For any_ reference to `dashboard_strategy_factory.dart`'s `DashboardStrategyFactory` or `concrete_strategies.dart`'s per-business-type `DashboardStrategy` subclasses (`VegetableBrokerStrategy` and its siblings) where `isBugCondition` holds for the `dashboard.orphanedVegetableBrokerStrategy` surface, the fixed codebase SHALL contain neither file/class — `dashboard_strategy_factory.dart` SHALL be deleted and the dead strategy classes SHALL be removed from `concrete_strategies.dart`, so no code path can resolve a `DashboardStrategy` with an empty `getWidgets()` for vegetablesBroker.

**Validates: Requirements 2.13**

Property 3: Preservation - Other Capabilities, Business Types, and the Live Dashboard Strategy Unaffected

_For any_ input where neither `isBugCondition` disjunct holds — every other vegetablesBroker capability, every non-vegetablesBroker business type's capability registry/plan mapping, `useDailyRates`/`RateBoardScreen`, `dashboard_strategies.dart`'s `DashboardStrategyFactory`/`_MandiStrategy` and every sibling strategy class in that file, and every already-fixed vegetablesBroker behavior listed in the Overview — the fixed code SHALL produce exactly the same result as the original code.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

## Fix Implementation

### 1. Revoke `useCrateManagement` from vegetablesBroker

**File**: `lib/core/isolation/business_capability.dart`

**Change**: remove `BusinessCapability.useCrateManagement,` from the `vegetablesBroker` entry's "Specialized" block (~line 764), leaving the enum value itself defined (other code, e.g. shared tests/backend mirrors, may still reference the enum member — only the grant to `vegetablesBroker` is removed):

```dart
'vegetablesBroker': {
  // ...
  // Specialized
  BusinessCapability.useCommission,
  // useCrateManagement removed — no crate table/screen/consumer exists
  // anywhere in the codebase (bugfix.md 2.13). Re-add only alongside a
  // real crate-tracking implementation.
  BusinessCapability.useFarmerLinking,
  BusinessCapability.useDailyRates, // backed by RateBoardScreen + RateHistory
  BusinessCapability.useCreditManagement,
},
```

**File**: `lib/core/subscription/plan_mapping_builder.dart`

**Change**: remove `BusinessCapability.useCrateManagement,` from the "Broker / mandi" block (~line 206):

```dart
// Broker / mandi
BusinessCapability.useCommission,
BusinessCapability.useFarmerLinking,
BusinessCapability.useDailyRates,
```

No other line in either file changes. The `BusinessCapability.useCrateManagement` enum value itself is left defined (removing it would be a breaking API change for any other type or external reference and is not needed to resolve the defect — only vegetablesBroker's grant of it is the bug).

### 2. Remove the orphaned `VegetableBrokerStrategy`/`DashboardStrategyFactory`

**File**: `lib/features/dashboard/logic/dashboard_strategy_factory.dart`

**Change**: delete the file entirely. It has zero importers anywhere in `lib/` (confirmed by repo-wide search) — nothing depends on it.

**File**: `lib/features/dashboard/logic/concrete_strategies.dart`

**Change**: delete the file entirely. Every class it defines (`MenuAction`, `DashboardWidget`, `GroceryDashboardStrategy`, `PharmacyDashboardStrategy`, `ClinicDashboardStrategy`, `RestaurantDashboardStrategy`, `VegetableBrokerStrategy`, `DefaultDashboardStrategy`) is referenced only by `dashboard_strategy_factory.dart`, which is also being deleted. Confirm before deleting that no other file imports `concrete_strategies.dart` besides the factory being removed in this same change (re-run the importer search as part of the fix task, not just at design time, since new code may have been added between design and implementation).

**Not modified**: `lib/features/dashboard/logic/dashboard_strategies.dart` (the live `DashboardStrategyFactory`/`_MandiStrategy`/every sibling strategy) and `lib/features/dashboard/presentation/screens/home_screen.dart` (which imports only `dashboard_strategies.dart`) are untouched — this fix removes a parallel, dead hierarchy, not the live one.

## Testing Strategy

### Validation Approach

For each of the two surfaces, first write a test that demonstrates the defect on unfixed code (exploration — expected to fail/demonstrate the bug), then implement the fix, then re-run the same test (now passing) alongside a preservation test that pins the unaffected behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples confirming each of the two defects before implementing fixes, and — since this design followed a re-verification that found 12 of the original 14 items already fixed — also record the passing state of those 12 already-fixed items as a baseline so the preservation suite has something concrete to pin.

**Test Plan / Test Cases**:
1. **Crate management no consumer**: assert `businessCapabilityRegistry['vegetablesBroker']` contains `BusinessCapability.useCrateManagement` (true on unfixed code — this is the bug) AND a repo-wide source scan finds no file under `lib/` referencing a crate table, crate screen, or crate sidebar item — confirms the capability is granted with nothing behind it.
2. **`useDailyRates` control case (must NOT show the same defect)**: assert `businessCapabilityRegistry['vegetablesBroker']` contains `useDailyRates` AND `rate_board_screen.dart` exists and queries `rate_history` — passes on current code, demonstrating `useDailyRates` is correctly out of scope.
3. **Orphaned strategy**: assert `dashboard_strategy_factory.dart` exists and defines `class DashboardStrategyFactory`, AND a repo-wide search for `dashboard_strategy_factory.dart` as an import target returns zero results outside the file itself — true (bug confirmed) on unfixed code.
4. **Live strategy control case**: assert `home_screen.dart` imports `dashboard_strategies.dart` (not `concrete_strategies.dart` or `dashboard_strategy_factory.dart`) and that `dashboard_strategies.dart`'s `_MandiStrategy.widgets`/`quickActions` are non-empty — passes on current code, confirming the real dashboard path is unaffected by the bug.

**Expected Counterexamples**: `useCrateManagement` present in the vegetablesBroker registry/plan-mapping with zero matching consumer files; `dashboard_strategy_factory.dart` present with zero importers.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := handleVegBrokerSurface_fixed(input)
  ASSERT expectedBehavior(result)   // per surface, see Correctness Properties 1–2
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT handleVegBrokerSurface_original(input) = handleVegBrokerSurface_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is used for the non-vegetablesBroker business-type domain (every other `BusinessType`'s capability set/plan mapping), since it has a natural generated input space; deterministic example tests are used for the vegetablesBroker-specific preserved sub-cases (`useDailyRates`, the five Mandi screens, the live `_MandiStrategy`).

**Test Plan**: Observe on UNFIXED code first (existing capability/plan-mapping goldens under `test/preservation/__goldens__/*/capabilities.json` already snapshot the full `vegetablesBroker` set including `useCrateManagement` — these goldens must be updated as part of this fix, not treated as an unrelated preservation baseline to protect), then write tests asserting the corrected set is reproduced after the fix, plus the two new behaviors from Fix Checking.

**Test Cases**:
1. Every non-vegetablesBroker business type's capability registry entry and plan mapping is byte-for-byte unchanged.
2. `businessCapabilityRegistry['vegetablesBroker']` retains `useCommission`, `useFarmerLinking`, `useDailyRates`, `useCreditManagement` (only `useCrateManagement` removed).
3. `RateBoardScreen`/`RateHistory` and the other four Mandi screens/sidebar items are unaffected — sidebar id→screen resolution for `mandi_lot_register`/`mandi_farmer_ledger`/`mandi_commission_report`/`mandi_settlement`/`mandi_rate_board` is unchanged.
4. `dashboard_strategies.dart`'s `_MandiStrategy` (and every sibling strategy class in that file) is byte-for-byte unchanged; `home_screen.dart`'s resolved `quickActions`/`widgets` for every business type are unchanged.
5. Existing goldens/tests that previously asserted `useCrateManagement` is granted to vegetablesBroker (`test/core/isolation/business_capability_test.dart`'s "broker-specific capabilities enabled" test, and the `capabilities.json` goldens under `test/preservation/__goldens__/{clinic_audit_non_clinic,hardware_vertical_remediation,electronics_vertical_remediation}/`) are updated to reflect the corrected set, and no other entry in those goldens changes.

### Unit Tests

- `businessCapabilityRegistry['vegetablesBroker']` does not contain `BusinessCapability.useCrateManagement` and does contain the other four Specialized capabilities.
- `plan_mapping_builder.dart`'s broker/mandi plan mapping does not contain `BusinessCapability.useCrateManagement`.
- `FeatureResolver.canAccess('vegetablesBroker', BusinessCapability.useCrateManagement)` returns `false` after the fix.
- `lib/features/dashboard/logic/dashboard_strategy_factory.dart` and the dead classes formerly in `concrete_strategies.dart` no longer exist / no longer compile-reference anywhere in `lib/`.
- `home_screen.dart` still resolves `_MandiStrategy` for `BusinessType.vegetablesBroker` via `dashboard_strategies.dart`'s `DashboardStrategyFactory`, with unchanged `quickActions`/`widgets`.

### Property-Based Tests

- Generate every non-vegetablesBroker `BusinessType` and assert its capability set and plan mapping are identical to the pre-fix baseline (preservation).
- Generate every `BusinessCapability` value other than `useCrateManagement` and assert its membership in `businessCapabilityRegistry['vegetablesBroker']` is unchanged before/after the fix (fix check + preservation combined — exactly one capability's membership flips, all others are stable).

### Integration Tests

- Provision a vegetablesBroker session and confirm the sidebar, dashboard, and any capability-gated UI show no crate-related affordance, while `mandi_rate_board`/`RateBoardScreen` and the other four Mandi sections remain fully reachable and functional exactly as before.
- Render the vegetablesBroker dashboard end to end (`home_screen.dart`) and confirm quick actions and widgets match the pre-fix `_MandiStrategy` output — the removal of the dead `VegetableBrokerStrategy`/`DashboardStrategyFactory` produces zero observable change for a real user.
