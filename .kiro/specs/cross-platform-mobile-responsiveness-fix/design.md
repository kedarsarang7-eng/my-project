# Cross-Platform Mobile Responsiveness Fix — Bugfix Design

## Overview

Three screens in the BuyFlow module (`StockEntryScreen`, `StockReversalScreen`, `BuyFlowDashboard`) unconditionally render desktop-style side-by-side or 4-wide layouts regardless of screen width. On mobile devices (< 600px), this causes text to render vertically, content to overflow/clip, and KPI cards to be unreadable. The fix applies the same `context.isMobile` conditional layout pattern already proven in `AddPurchaseScreen`, switching to stacked Column layouts on mobile while preserving existing desktop/tablet behavior.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — screen width < 600px AND the user is viewing one of the three affected screens (StockEntryScreen, StockReversalScreen, BuyFlowDashboard)
- **Property (P)**: The desired behavior when on mobile — stacked single-column layouts for entry/reversal screens, 2-column grid for KPI cards, with responsive font sizes and padding
- **Preservation**: Existing desktop/tablet layouts (side-by-side Row with flex:4/flex:6, 4-wide KPI cards) and all business logic must remain unchanged
- **`context.isMobile`**: Extension property on `BuildContext` (from `responsive_layout.dart`) that returns `true` when `MediaQuery.of(context).size.width < 600`
- **`responsiveValue()`**: Utility function that returns different values based on current screen size breakpoint (mobile/tablet/desktop)
- **`DesktopContentContainer`**: Wrapper widget used by all BuyFlow screens that provides title bar and standard layout shell

## Bug Details

### Bug Condition

The bug manifests when a user opens any of the three affected BuyFlow screens on a mobile device (screen width < 600px). The layout code in each screen unconditionally renders `Row` with `Expanded` children, forcing side-by-side arrangement regardless of available width. The responsive system (`context.isMobile`, `responsiveValue()`) exists and works — these screens simply don't use mobile checks in their top-level layout logic.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type ScreenRenderInput { screenWidth: double, screenName: string }
  OUTPUT: boolean
  
  RETURN input.screenWidth < 600
         AND input.screenName IN {"StockEntryScreen", "StockReversalScreen", "BuyFlowDashboard"}
         AND layoutRendersAsSideBySide(input.screenName)
END FUNCTION
```

### Examples

- **StockEntryScreen on 375px (iPhone SE)**: Expected vertical Column layout with vendor details on top, items below. Actual: side-by-side Row with vendor details squeezed to ~150px, text renders vertically letter-by-letter, "Add Item" button overflows.
- **StockReversalScreen on 390px (iPhone 14)**: Expected vertical Column layout with vendor section on top, return items below. Actual: side-by-side Row with vendor section crushed, "Return Item" button text clips, "Items to Return" header truncated.
- **BuyFlowDashboard on 360px (Samsung Galaxy S21)**: Expected 2-column grid for 4 KPI cards (~160px each). Actual: 4 cards in one Row at ~80px each, titles show as "T...", "P...", "A...", "R...", values unreadable.
- **BuyFlowDashboard on 320px (iPhone SE narrow)**: Worst case — each KPI card gets ~70px, icon+padding alone exceeds available width, causing overflow errors.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Desktop/tablet layouts (≥ 600px) for StockEntryScreen must continue rendering side-by-side Row with Expanded(flex:4) and Expanded(flex:6)
- Desktop/tablet layouts (≥ 600px) for StockReversalScreen must continue rendering side-by-side Row with Expanded(flex:4) and Expanded(flex:6)
- Desktop layouts (≥ 1100px) for BuyFlowDashboard must continue rendering 4 KPI cards in a single Row
- All business logic (stock entry saving, reversal processing, KPI data streams) must remain identical
- Mouse/touch interactions, navigation, dialogs, and data flows must be unaffected
- `responsiveValue()` calls already in the code (for padding/font sizes) must continue working as before
- Summary card styling (font sizes, padding, colors) on desktop/tablet must remain unchanged

**Scope:**
All inputs where `screenWidth >= 600` should be completely unaffected by this fix. This includes:
- Desktop viewing (≥ 1100px)
- Tablet viewing (600px–1099px)
- All screen sizes for non-affected screens (AddPurchaseScreen already fixed, other modules unrelated)
- All business logic regardless of screen size

## Hypothesized Root Cause

Based on code analysis, the root causes are confirmed (not hypothetical):

1. **StockEntryScreen — Missing mobile layout branch**: The `build()` method directly returns `Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex:4, ...), SizedBox(width:24), Expanded(flex:6, ...)])` as the child of `DesktopContentContainer`. No `context.isMobile` check exists at the top-level layout decision point (line ~530 in stock_entry_screen.dart).

2. **StockReversalScreen — Missing mobile layout branch**: The `build()` method directly returns `Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex:4, ...), SizedBox(width:24), Expanded(flex:6, ...)])` as the child of `DesktopContentContainer`. No `context.isMobile` check exists at the top-level layout decision point.

3. **BuyFlowDashboard — Missing mobile layout branch for KPI cards**: The summary cards section uses `Row(children: [Expanded(_buildSummaryCard(...)), SizedBox(width:16), ...])` with 4 Expanded cards. No responsive check wraps this into a `Wrap` or grid on mobile.

4. **BuyFlowDashboard — Non-responsive card styling**: The `_buildSummaryCard` uses fixed `padding: EdgeInsets.all(20)` and `fontSize: 24` which overflow on narrow mobile cards even if arranged in a 2-column grid.

## Correctness Properties

Property 1: Bug Condition - Mobile Layouts Render Stacked/Grid

_For any_ screen render input where the screen width is less than 600px and the screen is one of {StockEntryScreen, StockReversalScreen, BuyFlowDashboard}, the fixed screen SHALL render a mobile-appropriate layout: single-column vertical stacking for entry/reversal screens, and a 2-column grid for dashboard KPI cards, with no horizontal overflow and all text fully readable.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

Property 2: Preservation - Desktop/Tablet Layouts Unchanged

_For any_ screen render input where the screen width is 600px or greater, the fixed screens SHALL produce exactly the same layout as the original code: side-by-side Row(flex:4, flex:6) for entry/reversal screens, and 4-wide Row for dashboard KPI cards on desktop, preserving all existing desktop/tablet behavior, styling, and business logic.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Fix Implementation

### Changes Required

The fix applies the proven `context.isMobile` conditional pattern from `AddPurchaseScreen` to each affected screen.

**File**: `lib/features/buy_flow/screens/stock_entry_screen.dart`

**Function**: `build()` method of `_StockEntryScreenState`

**Specific Changes**:
1. **Add mobile layout branch**: Wrap the top-level `Row(...)` in a `context.isMobile ? Column(...) : Row(...)` ternary
2. **Column layout for mobile**: Stack vendor details section on top, stock items section below, both at full width
3. **Remove SizedBox(width:24) spacer on mobile**: Replace with `SizedBox(height: 16)` vertical spacing
4. **Remove Expanded wrappers on mobile**: Each section takes full width in Column, no flex needed

---

**File**: `lib/features/buy_flow/screens/stock_reversal_screen.dart`

**Function**: `build()` method of `_StockReversalScreenState`

**Specific Changes**:
1. **Add mobile layout branch**: Wrap the top-level `Row(...)` in a `context.isMobile ? Column(...) : Row(...)` ternary
2. **Column layout for mobile**: Stack vendor details section on top, items-to-return section below
3. **Remove SizedBox(width:24) spacer on mobile**: Replace with `SizedBox(height: 16)` vertical spacing
4. **Remove Expanded wrappers on mobile**: Each section takes full width in Column

---

**File**: `lib/features/buy_flow/screens/buy_flow_dashboard.dart`

**Function**: `build()` method of `_BuyFlowDashboardState`

**Specific Changes**:
1. **Add mobile layout branch for KPI cards**: Replace the hardcoded `Row(children: [Expanded * 4])` with a conditional:
   - Mobile (< 600px): `Wrap` with 2 cards per row, or `GridView.count(crossAxisCount: 2)`
   - Desktop/tablet (≥ 600px): Existing `Row` layout preserved unchanged
2. **Responsive card styling**: In `_buildSummaryCard`, use `responsiveValue()` for padding and font size:
   - Mobile: `padding: EdgeInsets.all(12)`, value `fontSize: 18`
   - Desktop: `padding: EdgeInsets.all(20)`, value `fontSize: 24` (unchanged)
3. **Import responsive extension**: Add `import 'package:dukanx/core/responsive/responsive_layout.dart';` if not already present

---

**File**: `lib/features/buy_flow/screens/buy_flow_dashboard.dart` (import)

**Specific Changes**:
5. **Add responsive import**: `import 'package:dukanx/core/responsive/responsive_layout.dart';` to access `context.isMobile`

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm the root cause by verifying that the current code produces overflow and unreadable layouts at mobile widths.

**Test Plan**: Write widget tests that render each affected screen at mobile widths (e.g., 375px) and assert on layout properties. Run these tests on the UNFIXED code to observe failures and confirm the bug.

**Test Cases**:
1. **StockEntryScreen at 375px**: Render screen, find the top-level layout widget, assert its axis — will find `Axis.horizontal` (Row) on unfixed code when it should be `Axis.vertical` (Column)
2. **StockReversalScreen at 375px**: Render screen, find the top-level layout widget, assert its axis — will find `Axis.horizontal` (Row) on unfixed code
3. **BuyFlowDashboard KPI cards at 360px**: Render dashboard, find summary card Row, count children in single row — will find 4 cards in one Row on unfixed code
4. **BuyFlowDashboard card width at 320px**: Render dashboard at extreme narrow width, assert no overflow errors — will likely trigger RenderFlex overflow on unfixed code

**Expected Counterexamples**:
- All three screens render Row/horizontal layouts at mobile widths
- BuyFlowDashboard forces 4 cards into ~80px each, text truncated to single characters
- Possible RenderFlex overflow errors at widths below 360px

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds (mobile width + affected screen), the fixed screens produce the expected mobile-friendly layout.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  renderedLayout := renderScreen_fixed(input)
  IF input.screenName IN {"StockEntryScreen", "StockReversalScreen"} THEN
    ASSERT renderedLayout.topLevelAxis = Axis.vertical
    ASSERT renderedLayout.hasNoHorizontalOverflow = true
    ASSERT renderedLayout.allSectionsFullWidth = true
  END IF
  IF input.screenName = "BuyFlowDashboard" THEN
    ASSERT renderedLayout.kpiCardsPerRow <= 2
    ASSERT renderedLayout.kpiCardMinWidth >= 140
    ASSERT renderedLayout.cardTextNotTruncated = true
  END IF
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold (screen width ≥ 600px), the fixed screens produce the same result as the original code.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT renderScreen_original(input) = renderScreen_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases across the width range (600–1920px) automatically
- It catches edge cases at breakpoint boundaries (599px vs 600px)
- It provides strong guarantees that desktop/tablet behavior is unchanged

**Test Plan**: Observe behavior on UNFIXED code first for desktop/tablet widths, then write property-based tests capturing that exact behavior continues after the fix.

**Test Cases**:
1. **StockEntryScreen at 600–1920px**: Verify side-by-side Row layout with flex:4/flex:6 is preserved across all desktop/tablet widths
2. **StockReversalScreen at 600–1920px**: Verify side-by-side Row layout with flex:4/flex:6 is preserved
3. **BuyFlowDashboard at 1100–1920px**: Verify 4 KPI cards in single Row is preserved on desktop
4. **BuyFlowDashboard at 600–1099px**: Verify KPI cards adapt appropriately (2x2 grid or 4-wide)
5. **Business logic preservation**: Verify stock entry save, reversal processing work identically at all widths

### Unit Tests

- Test `context.isMobile` returns true at 599px and false at 600px (breakpoint boundary)
- Test StockEntryScreen renders Column at 375px and Row at 800px
- Test StockReversalScreen renders Column at 375px and Row at 800px
- Test BuyFlowDashboard renders 2-column grid at 375px and 4-wide Row at 1200px
- Test `_buildSummaryCard` uses responsive padding/font size based on screen width

### Property-Based Tests

- Generate random widths in [300, 599] range and verify all three screens render mobile layouts (vertical axis, no overflow)
- Generate random widths in [600, 1920] range and verify all three screens render unchanged desktop/tablet layouts
- Generate random widths at breakpoint boundary [598, 601] and verify correct layout switching
- Generate random KPI card data and verify cards render readable at mobile widths

### Integration Tests

- Test full StockEntryScreen flow on mobile: navigate, fill vendor, add items, save — all functional
- Test full StockReversalScreen flow on mobile: navigate, select vendor, add return items, confirm — all functional
- Test BuyFlowDashboard navigation on mobile: view KPI cards, tap quick actions, navigate to sub-screens
- Test orientation change: verify layout adapts when rotating device from portrait to landscape
