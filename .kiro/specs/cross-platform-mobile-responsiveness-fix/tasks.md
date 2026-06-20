# Implementation Plan

## Overview

This plan fixes mobile responsiveness on three BuyFlow screens by applying the proven `context.isMobile` conditional layout pattern from AddPurchaseScreen. The workflow follows the bug condition methodology: explore the bug first with tests, preserve existing desktop behavior, then implement and validate the fix.

## Tasks

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Mobile Layouts Render Side-by-Side Instead of Stacked
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists on all three affected screens
  - **Scoped PBT Approach**: Generate random screen widths in [300, 599] range and verify layout axis for each affected screen
  - Test that StockEntryScreen at mobile widths (< 600px) renders with `Axis.vertical` (Column) — will find `Axis.horizontal` (Row) on unfixed code
  - Test that StockReversalScreen at mobile widths (< 600px) renders with `Axis.vertical` (Column) — will find `Axis.horizontal` (Row) on unfixed code
  - Test that BuyFlowDashboard at mobile widths (< 600px) renders KPI cards with at most 2 per row — will find 4 cards in a single Row on unfixed code
  - Test that BuyFlowDashboard summary cards at mobile widths use responsive font/padding — will find fixed fontSize:24 and padding:20 on unfixed code
  - Use `MediaQuery` override to set screen width, render each screen in a `MaterialApp` test harness
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "StockEntryScreen at 375px renders Row instead of Column", "BuyFlowDashboard at 360px forces 4 cards in single Row")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Desktop/Tablet Layouts Unchanged at ≥ 600px
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: StockEntryScreen at 800px renders side-by-side Row with Expanded(flex:4) and Expanded(flex:6) on unfixed code
  - Observe: StockReversalScreen at 800px renders side-by-side Row with Expanded(flex:4) and Expanded(flex:6) on unfixed code
  - Observe: BuyFlowDashboard at 1200px renders 4 KPI cards in a single Row on unfixed code
  - Observe: BuyFlowDashboard summary cards at ≥ 600px use fontSize:24 for values and padding:20 on unfixed code
  - Write property-based test: for all screen widths in [600, 1920], StockEntryScreen renders Row layout with flex:4/flex:6 children
  - Write property-based test: for all screen widths in [600, 1920], StockReversalScreen renders Row layout with flex:4/flex:6 children
  - Write property-based test: for all screen widths in [1100, 1920], BuyFlowDashboard renders 4 KPI cards in a single Row
  - Write property-based test: for all screen widths in [600, 1920], BuyFlowDashboard summary cards maintain desktop font sizes and padding
  - Test breakpoint boundary: verify 600px renders desktop layout and 599px would trigger mobile (boundary precision)
  - Verify all tests PASS on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.7_

- [x] 3. Fix for mobile responsiveness on BuyFlow screens

  - [x] 3.1 Add mobile Column layout branch to StockEntryScreen
    - In `stock_entry_screen.dart`, locate the `build()` method's top-level `Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex:4, ...), SizedBox(width:24), Expanded(flex:6, ...)])`
    - Wrap in `context.isMobile ? Column(...) : Row(...)` ternary
    - Mobile branch: `Column(crossAxisAlignment: CrossAxisAlignment.start, children: [vendorDetailsSection, SizedBox(height: 16), stockItemsSection])`
    - Desktop branch: existing `Row(...)` unchanged
    - Ensure `responsive_layout.dart` import is present for `context.isMobile`
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND screenName = "StockEntryScreen"_
    - _Expected_Behavior: renderedLayout.topLevelAxis = Axis.vertical, no horizontal overflow, all text readable_
    - _Preservation: Desktop/tablet (≥ 600px) continues Row with flex:4/flex:6_
    - _Requirements: 2.1, 3.1, 3.5_

  - [x] 3.2 Add mobile Column layout branch to StockReversalScreen
    - In `stock_reversal_screen.dart`, locate the `build()` method's top-level `Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex:4, ...), SizedBox(width:24), Expanded(flex:6, ...)])`
    - Wrap in `context.isMobile ? Column(...) : Row(...)` ternary
    - Mobile branch: `Column(crossAxisAlignment: CrossAxisAlignment.start, children: [vendorDetailsSection, SizedBox(height: 16), itemsToReturnSection])`
    - Desktop branch: existing `Row(...)` unchanged
    - Ensure `responsive_layout.dart` import is present for `context.isMobile`
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND screenName = "StockReversalScreen"_
    - _Expected_Behavior: renderedLayout.topLevelAxis = Axis.vertical, no horizontal overflow, all buttons visible_
    - _Preservation: Desktop/tablet (≥ 600px) continues Row with flex:4/flex:6_
    - _Requirements: 2.2, 3.2, 3.6_

  - [x] 3.3 Add 2-column grid for KPI cards on mobile in BuyFlowDashboard
    - In `buy_flow_dashboard.dart`, locate the KPI summary cards `Row(children: [Expanded(_buildSummaryCard(...)), SizedBox(width:16), ...])` section
    - Wrap in `context.isMobile ? Wrap(...) : Row(...)` conditional
    - Mobile branch: Use `Wrap(spacing: 12, runSpacing: 12, children: [...cards])` or `GridView.count(crossAxisCount: 2)` so each card gets ~160px minimum width
    - Desktop branch (≥ 600px): existing `Row(...)` with 4 Expanded cards unchanged
    - Add `responsive_layout.dart` import if not already present
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND screenName = "BuyFlowDashboard"_
    - _Expected_Behavior: renderedLayout.kpiCardsPerRow <= 2, kpiCardMinWidth >= 140, all text readable_
    - _Preservation: Desktop (≥ 1100px) continues 4 cards in single Row; tablet adapts similarly_
    - _Requirements: 2.3, 3.3, 3.4_

  - [x] 3.4 Add responsive card styling to BuyFlowDashboard summary cards
    - In `buy_flow_dashboard.dart`, locate `_buildSummaryCard` method
    - Replace fixed `padding: EdgeInsets.all(20)` with `padding: EdgeInsets.all(context.isMobile ? 12 : 20)`
    - Replace fixed value `fontSize: 24` with `fontSize: context.isMobile ? 18 : 24`
    - Keep title fontSize (13) and other styling unchanged
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND screenName = "BuyFlowDashboard"_
    - _Expected_Behavior: Card content fits within available width without overflow or truncation_
    - _Preservation: Desktop/tablet (≥ 600px) retains fontSize:24 and padding:20_
    - _Requirements: 2.4, 3.7_

  - [x] 3.5 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Mobile Layouts Render Stacked/Grid After Fix
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior (vertical axis for entry/reversal, 2-col grid for dashboard)
    - When this test passes, it confirms the expected behavior is satisfied for all mobile widths
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 3.6 Verify preservation tests still pass
    - **Property 2: Preservation** - Desktop/Tablet Layouts Still Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all desktop/tablet layouts (≥ 600px) remain identical after fix
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.7_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run full test suite to verify no regressions
  - Confirm bug condition test (Property 1) passes — mobile layouts are stacked/grid
  - Confirm preservation test (Property 2) passes — desktop/tablet layouts unchanged
  - Verify no new lint warnings or analysis errors introduced
  - Ensure all tests pass, ask the user if questions arise

## Task Dependency Graph

```json
{
  "waves": [
    { "tasks": ["1", "2"] },
    { "tasks": ["3.1", "3.2", "3.3", "3.4"] },
    { "tasks": ["3.5", "3.6"] },
    { "tasks": ["4"] }
  ]
}
```

## Notes

- The `context.isMobile` extension is defined in `lib/core/responsive/responsive_layout.dart` and returns `true` when `MediaQuery.of(context).size.width < 600`
- The proven pattern from `AddPurchaseScreen` uses a simple ternary: `context.isMobile ? Column(...) : Row(...)`
- All tests should use `MediaQuery` override in a test harness to simulate different screen widths
- For BuyFlowDashboard, `Wrap` widget is preferred over `GridView.count` for simpler integration with existing layout
- Business logic (stock entry save, reversal processing, KPI data streams) is untouched by this fix
