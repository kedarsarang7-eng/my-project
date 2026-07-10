# Implementation Plan

## Overview

Scope: the 2 verified-still-defective surfaces identified by `design.md`'s re-verification against `bugfix.md`'s 14-item list — `capability.crateManagementNoConsumer` (revoke `useCrateManagement` from vegetablesBroker) and `dashboard.orphanedVegetableBrokerStrategy` (delete the dead `VegetableBrokerStrategy`/`DashboardStrategyFactory` pair). The other 12 items in `bugfix.md`'s original 14-item list are already resolved by prior remediation work and are treated here as preservation baselines to protect, not as fix targets. No task may alter behavior for any other business type, for vegetablesBroker's own already-fixed behaviors (sidebar sections/screens, alert counts, quick action wiring, commission capture, charge fields, weight-sheet validation, sync columns/handler, theme-aware colors, payout mode, multi-farmer attribution, farmer-lookup error handling), for `useDailyRates`/`RateBoardScreen`, or for `dashboard_strategies.dart`'s live `_MandiStrategy`/`DashboardStrategyFactory` and every sibling strategy class in that file.

Testing mandate: write both bug-condition exploration tests (Correctness Properties 1-2) and all preservation property tests (Correctness Property 3, split by preserved-behavior group) FIRST, run them on UNFIXED code (exploration tests demonstrate the bug, preservation tests PASS), then implement each surface's fix, then re-run the same tests unchanged to confirm the fix resolves that surface's bug and introduces no regressions.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "description": "Both bug-condition exploration tests, written and run on UNFIXED code before any fix",
      "tasks": ["1", "2"]
    },
    {
      "wave": 2,
      "description": "All 4 preservation property tests, written and run on UNFIXED code before any fix - each MUST PASS",
      "tasks": ["3", "4", "5", "6"]
    },
    {
      "wave": 3,
      "description": "Surface 1 (capability registry / plan mapping) and Surface 2 (dead dashboard strategy files) - fully independent files, no cross-surface dependency",
      "tasks": ["7.1", "7.2", "7.3", "8.1", "8.2", "8.3"]
    },
    {
      "wave": 4,
      "description": "Final checkpoint - full suite green across both exploration tests and all 4 preservation tests",
      "tasks": ["9"]
    }
  ]
}
```

**Key dependency notes:**
- **Surface 1 (`capability.crateManagementNoConsumer`, task 7) and Surface 2 (`dashboard.orphanedVegetableBrokerStrategy`, task 8) are fully independent** of each other and of every other surface — Surface 1 touches only `business_capability.dart`/`plan_mapping_builder.dart`; Surface 2 touches only `dashboard_strategy_factory.dart` (deleted) and `concrete_strategies.dart` (deleted), neither of which is imported by anything Surface 1 changes.
- Both exploration tests (Phase 1 / wave 1) and all 4 preservation tests (Phase 2 / wave 2) MUST be written and run on UNFIXED code before any implementation task begins — this ordering applies globally, not just per-surface.
- Within each surface's parent task, the three sub-tasks (implement → verify fix → verify preservation) are strictly sequential, but the two surfaces' parent tasks (7-8) may be implemented in either order.

## Tasks

### Phase 1: Exploration Tests (Bug Condition, Correctness Properties 1-2) — write and run BEFORE any fix

- [x] 1. Write bug condition exploration test — Crate Management No Consumer
  - **Property 1: Bug Condition** - `useCrateManagement` Revoked for vegetablesBroker
  - **CRITICAL**: This test MUST demonstrate the bug on unfixed code — the assertion that `useCrateManagement` is granted with zero consumer confirms the defect exists. Do NOT fix the test or the code when it demonstrates the bug.
  - **Surface**: `capability.crateManagementNoConsumer`
  - Assert `businessCapabilityRegistry['vegetablesBroker']` contains `BusinessCapability.useCrateManagement` and assert `plan_mapping_builder.dart`'s broker/mandi plan mapping contains it too
  - Separately, run a repo-wide source scan under `lib/` and assert zero files reference a crate table, crate screen, or crate sidebar item (no consumer exists)
  - **Control case (must NOT show the same defect)**: assert `businessCapabilityRegistry['vegetablesBroker']` contains `BusinessCapability.useDailyRates` AND `lib/features/vegetable_broker/presentation/screens/rate_board_screen.dart` exists and queries the `RateHistory`/`rate_history` table — this passes on current code, confirming `useDailyRates` is correctly out of scope for this fix
  - Run on UNFIXED code — expect the crate-management assertions to hold true (capability granted, zero consumer) and the `useDailyRates` control case to already pass
  - Document the counterexample (e.g. "useCrateManagement present in businessCapabilityRegistry['vegetablesBroker'] and plan_mapping_builder.dart's broker/mandi mapping, with zero matching crate-table/screen/sidebar-item files under lib/")
  - _Requirements: 2.13_

- [x] 2. Write bug condition exploration test — Orphaned VegetableBrokerStrategy/DashboardStrategyFactory
  - **Property 2: Bug Condition** - Orphaned `VegetableBrokerStrategy`/`DashboardStrategyFactory` Removed
  - **CRITICAL**: This test MUST demonstrate the bug on unfixed code.
  - **Surface**: `dashboard.orphanedVegetableBrokerStrategy`
  - Assert `lib/features/dashboard/logic/dashboard_strategy_factory.dart` exists and defines `class DashboardStrategyFactory` with a `getStrategy` method that resolves `BusinessType.vegetablesBroker` to a `VegetableBrokerStrategy` whose `getWidgets(context)` returns `[]`
  - Separately, run a repo-wide search for `dashboard_strategy_factory.dart` as an import target and assert zero results outside the file itself (confirms zero importers/dead code)
  - **Control case (live strategy unaffected)**: assert `lib/features/dashboard/presentation/screens/home_screen.dart` imports `dashboard_strategies.dart` (not `concrete_strategies.dart` or `dashboard_strategy_factory.dart`), and assert `dashboard_strategies.dart`'s `_MandiStrategy.widgets`/`quickActions` are non-empty — this passes on current code, confirming the real dashboard path a user sees is unaffected by the bug
  - Run on UNFIXED code — expect the orphaned-factory assertions to hold true (file exists, zero importers, empty `getWidgets()`) and the live-strategy control case to already pass
  - Document the counterexample (e.g. "dashboard_strategy_factory.dart defines DashboardStrategyFactory with zero importers in lib/; VegetableBrokerStrategy.getWidgets() returns []")
  - _Requirements: 2.13_

### Phase 2: Preservation Tests (Correctness Property 3) — write and verify PASS on UNFIXED code BEFORE any fix

- [x] 3. Write preservation property test — Non-VegetablesBroker Business Types Unaffected
  - **Property 3: Preservation** - Non-VegetablesBroker Capability Registry & Plan Mapping Unaffected
  - **IMPORTANT**: Follow observation-first methodology — observe `businessCapabilityRegistry[type]` and `plan_mapping_builder.dart`'s plan mapping for every non-vegetablesBroker `BusinessType` on UNFIXED code, record it, then assert it in the test
  - Property-based test: generate every non-vegetablesBroker `BusinessType` value and assert its capability registry entry and plan mapping are byte-for-byte identical to the recorded baseline, with zero reference to `useCrateManagement`'s removal or any vegetablesBroker-specific change
  - Verify test PASSES on UNFIXED code (confirms baseline behavior to preserve)
  - _Requirements: 3.1, 3.3_

- [x] 4. Write preservation property test — VegetablesBroker's Other Capabilities and Mandi Screens Unaffected
  - **Property 3: Preservation** - VegetablesBroker's Other Capabilities, `useDailyRates`, and the Five Mandi Screens Unaffected
  - **IMPORTANT**: Observe on UNFIXED code that `businessCapabilityRegistry['vegetablesBroker']` contains `useCommission`, `useFarmerLinking`, `useDailyRates`, `useCreditManagement` (alongside `useCrateManagement`), and that sidebar id→screen resolution for `mandi_lot_register`/`mandi_farmer_ledger`/`mandi_commission_report`/`mandi_settlement`/`mandi_rate_board` resolves to their respective real screens
  - Property-based/example test: generate arbitrary lookups of these four capabilities and five sidebar ids and assert their presence/resolution is unchanged after the `useCrateManagement` removal — only `useCrateManagement`'s membership flips, all other capabilities and every Mandi screen/sidebar item are stable
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.2, 3.4, 3.5_

- [x] 5. Write preservation property test — Live Dashboard Strategy (`_MandiStrategy`) Unaffected
  - **Property 3: Preservation** - `dashboard_strategies.dart`'s `_MandiStrategy` and Sibling Strategies Unaffected
  - **IMPORTANT**: Observe on UNFIXED code that `home_screen.dart` resolves `_MandiStrategy` for `BusinessType.vegetablesBroker` via `dashboard_strategies.dart`'s own `DashboardStrategyFactory.getStrategy`, with non-empty `quickActions` (New Entry / Farmer Ledger / Daily Rates) and non-empty `widgets` (`salesSummary`, `recentBills`); also observe every other business type's resolved strategy/`quickActions`/`widgets` in that same file
  - Property-based test: generate every `BusinessType` value and assert `home_screen.dart`'s resolved strategy, `quickActions`, and `widgets` for each are byte-for-byte identical before and after the `dashboard_strategy_factory.dart`/`concrete_strategies.dart` deletion
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.4, 3.5_

- [x] 6. Write preservation property test — Existing Capability Goldens/Tests Baseline
  - **Property 3: Preservation** - Existing Goldens and Unit Tests Reflect the Corrected Capability Set After the Fix
  - **IMPORTANT**: Observe on UNFIXED code the current content of `test/core/isolation/business_capability_test.dart`'s "broker-specific capabilities enabled" test and the `capabilities.json` goldens under `test/preservation/__goldens__/{clinic_audit_non_clinic,hardware_vertical_remediation,electronics_vertical_remediation}/` — record which currently assert `useCrateManagement` is granted to vegetablesBroker
  - Property-based/example test: assert that every OTHER entry in those goldens/tests (i.e. every capability/business-type assertion not about vegetablesBroker's `useCrateManagement`) is unchanged, and flag the `useCrateManagement`-specific assertions as needing an update in lockstep with the Surface 1 fix (tracked as part of task 7.1, not a separate defect)
  - Verify test PASSES on UNFIXED code for the "every other entry unchanged" portion; the `useCrateManagement`-specific assertions are expected to need updating once the fix lands (tracked as a follow-up re-run in task 7.3)
  - _Requirements: 3.1, 3.2_

### Phase 3: Implementation (one parent task per surface)

- [x] 7. Fix Surface 1: capability.crateManagementNoConsumer

  - [x] 7.1 Implement the fix
    - In `lib/core/isolation/business_capability.dart`'s `businessCapabilityRegistry['vegetablesBroker']` entry, remove `BusinessCapability.useCrateManagement,` from the "Specialized" block (~line 764), leaving `useCommission`, `useFarmerLinking`, `useDailyRates`, `useCreditManagement` in place; leave the `BusinessCapability.useCrateManagement` enum value itself defined
    - In `lib/core/subscription/plan_mapping_builder.dart`'s "Broker / mandi" block (~line 206), remove `BusinessCapability.useCrateManagement,`, leaving `useCommission`, `useFarmerLinking`, `useDailyRates` in place
    - Update `test/core/isolation/business_capability_test.dart`'s "broker-specific capabilities enabled" test and the `capabilities.json` goldens under `test/preservation/__goldens__/{clinic_audit_non_clinic,hardware_vertical_remediation,electronics_vertical_remediation}/` to reflect the corrected vegetablesBroker capability set (no other entry in those goldens changes)
    - _Bug_Condition: isBugCondition(X) where X.surface = 'capability.crateManagementNoConsumer'_
    - _Expected_Behavior: Correctness Property 1 from design.md_
    - _Preservation: every other vegetablesBroker capability, every non-vegetablesBroker business type's registry/plan mapping, and `useDailyRates`/`RateBoardScreen` are unaffected (Correctness Property 3)_
    - _Requirements: 2.13, 3.1, 3.2, 3.3_

  - [x] 7.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - `useCrateManagement` Revoked for vegetablesBroker
    - Re-run the SAME test from task 1 — do NOT write a new test
    - Expected outcome: the crate-management assertions now show `useCrateManagement` absent from both the registry and the plan mapping, and `FeatureResolver.canAccess('vegetablesBroker', BusinessCapability.useCrateManagement)` returns `false`; the `useDailyRates` control case continues to pass unchanged
    - _Requirements: 2.13_

  - [x] 7.3 Verify preservation tests still pass
    - **Property 3: Preservation** - Other Capabilities, Business Types, and Goldens Unchanged
    - Re-run tasks 3, 4, and 6's tests — do NOT write new tests
    - Expected outcome: tests PASS (no regression to non-vegetablesBroker business types, to vegetablesBroker's other capabilities/Mandi screens, or to the updated goldens beyond the intended `useCrateManagement` change)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 8. Fix Surface 2: dashboard.orphanedVegetableBrokerStrategy

  - [x] 8.1 Implement the fix
    - Re-confirm, as part of this task (not just at design time), that no file other than `dashboard_strategy_factory.dart` imports `concrete_strategies.dart`, and that no file other than `home_screen.dart`'s own import chain resolves through `dashboard_strategies.dart` — run a repo-wide importer search for both `dashboard_strategy_factory.dart` and `concrete_strategies.dart` immediately before deleting
    - Delete `lib/features/dashboard/logic/dashboard_strategy_factory.dart` in its entirety
    - Delete `lib/features/dashboard/logic/concrete_strategies.dart` in its entirety (removing `MenuAction`, `DashboardWidget`, `GroceryDashboardStrategy`, `PharmacyDashboardStrategy`, `ClinicDashboardStrategy`, `RestaurantDashboardStrategy`, `VegetableBrokerStrategy`, `DefaultDashboardStrategy`)
    - Do NOT modify `lib/features/dashboard/logic/dashboard_strategies.dart` or `lib/features/dashboard/presentation/screens/home_screen.dart`
    - _Bug_Condition: isBugCondition(X) where X.surface = 'dashboard.orphanedVegetableBrokerStrategy'_
    - _Expected_Behavior: Correctness Property 2 from design.md_
    - _Preservation: `dashboard_strategies.dart`'s `_MandiStrategy`/`DashboardStrategyFactory` and every sibling strategy class, and `home_screen.dart`'s resolved strategy for every business type, are unaffected (Correctness Property 3)_
    - _Requirements: 2.13, 3.4, 3.5_

  - [x] 8.2 Verify bug condition exploration test now passes
    - **Property 2: Expected Behavior** - Orphaned `VegetableBrokerStrategy`/`DashboardStrategyFactory` Removed
    - Re-run the SAME test from task 2 — do NOT write a new test
    - Expected outcome: `dashboard_strategy_factory.dart` and `concrete_strategies.dart` no longer exist / no longer compile-reference anywhere in `lib/`; the assertion that the dead factory exists now fails-to-find (confirming removal); the live-strategy control case continues to pass unchanged
    - _Requirements: 2.13_

  - [x] 8.3 Verify preservation tests still pass
    - **Property 3: Preservation** - Live Dashboard Strategy Unchanged
    - Re-run task 5's test — do NOT write a new test
    - Expected outcome: test PASSES (`home_screen.dart` still resolves `_MandiStrategy` for `BusinessType.vegetablesBroker` via `dashboard_strategies.dart`'s `DashboardStrategyFactory`, with unchanged `quickActions`/`widgets`, and every other business type's resolved strategy is unchanged)
    - _Requirements: 3.4, 3.5_

### Phase 4: Checkpoint

- [ ] 9. Checkpoint - Ensure all tests pass
  - Run the full test suite (both exploration tests from Phase 1, all 4 preservation tests from Phase 2, and every sub-task verification from Phase 3)
  - Confirm both exploration tests now demonstrate the fix (bug resolved) and all 4 preservation tests still PASS (no regressions)
  - Ask the user if any test fails unexpectedly or if a root-cause hypothesis was refuted during Phase 1
  - Run the project's full build/analyze step (`flutter analyze`, relevant `flutter test` targets) and resolve any errors before considering the bugfix complete

## Notes

- Property numbers 1-2 map 1:1 to the 2 surfaces and to `design.md`'s Correctness Properties 1-2 (Bug Condition). Property 3 is the single shared Preservation property, split across tasks 3-6 by preserved-behavior group for testability, and re-verified in each surface's `.3` sub-task.
- Both exploration tests (tasks 1-2) MUST demonstrate the bug on unfixed code before their corresponding implementation task begins — a test that fails to demonstrate the bug at that stage means the test does not actually exercise the surface and must be revised.
- Both preservation tests groups (tasks 3-6) MUST pass on unfixed code before any implementation begins, establishing the baseline that Phase 3's `.3` sub-tasks re-verify after each fix.
- Surfaces 1 and 2 are fully independent and may be implemented in either order.
- This spec intentionally does NOT re-implement the other 12 items from `bugfix.md`'s original 14-item defect list — `design.md`'s re-verification found those already resolved by prior remediation work. They are covered here only as preservation baselines (tasks 4 and 6).
