# Implementation Plan

## Overview

This plan fixes mobile responsiveness across 9 screens in the Dukanx Flutter application plus a global codebase audit. The workflow follows bug condition methodology: explore the bug with tests first, capture preservation baseline, create shared components, then implement fixes by severity (CRITICAL → HIGH → MEDIUM), verify, audit, and validate. Previously fixed screens (StockEntryScreen, StockReversalScreen, BuyFlowDashboard) are excluded.

## Tasks

- [x] 1. Write bug condition exploration tests (BEFORE implementing fix)
  - **Property 1: Bug Condition** - Mobile Layout Responsiveness Failures Across 9 Screens
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists across all 9 affected screens
  - **Scoped PBT Approach**: For each screen, scope to concrete failing viewport widths (360px, 375px, 393px, 412px)
  - **Test file**: `test/bug_condition/mobile_responsiveness_exploration_test.dart`
  - **Test cases to write**:
    - NewPurchaseOrderScreen at 360px: Assert top-level layout uses vertical axis (Column), not horizontal (Row). Unfixed code will have Row → FAIL confirms desktop layout forced on mobile
    - StorageManagementScreen at 375px: Assert no RenderFlex overflow and container minWidth >= 200px. Unfixed code has crushed containers → FAIL confirms vertical text bug
    - ProcessReturnScreen at 393px: Assert search field fits within card boundary with no text clipping. Unfixed code clips text → FAIL
    - NewEstimateScreen at 412px: Assert date field labels do not overlap values, currency renders as "₹" not "â,¹". Unfixed code has overlap and mojibake → FAIL
    - CatalogueScreen at 360px: Assert title renders on single line (maxLines: 1 or no vertical wrapping). Unfixed code wraps title → FAIL
    - CashflowScreen at 375px: Assert data cards have visible content (non-zero size, non-empty). Unfixed code shows empty cards → FAIL
    - PaymentGatewaySettingsScreen with mocked 401 error: Assert no raw "ApiException" text visible in UI, assert user-friendly message present. Unfixed code shows raw exception → FAIL
    - PaymentRemindersScreen at 360px: Assert AppBar title on single line. Unfixed code wraps title → FAIL
    - BuyOrdersListScreen at 393px: Assert AppBar title on single line and empty state centered. Unfixed code wraps title → FAIL
  - **Bug Condition**: `isBugCondition(input)` where `input.screenWidth < 600 AND input.screenName IN {9 affected screens}` OR `input.screenName = "PaymentGatewaySettingsScreen" AND input.apiState = EXPIRED`
  - **Expected Behavior**: All screens render mobile-appropriate layouts with no overflow, no vertical text, titles on single line, visible data, user-friendly errors
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct — proves the bugs exist)
  - Document counterexamples found to understand root cause for each screen
  - Mark task complete when tests are written, run, and failures are documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Desktop/Tablet Layouts Unchanged at ≥ 600px
  - **IMPORTANT**: Follow observation-first methodology
  - **Test file**: `test/bug_condition/mobile_responsiveness_preservation_test.dart`
  - **Observation phase** (run on UNFIXED code, record baseline):
    - Observe: NewPurchaseOrderScreen at 800px renders Row with flex:4 and flex:6 children (two-column layout)
    - Observe: StorageManagementScreen at 1024px renders usage cards in current desktop layout
    - Observe: CatalogueScreen at 700px renders 2-column grid, at 1200px renders 4-column grid
    - Observe: CashflowScreen at 1024px renders tab layout with chart dimensions
    - Observe: PaymentGatewaySettingsScreen with successful API returns credential management UI
    - Observe: All screens at 600px boundary render desktop/tablet layout (not mobile)
    - Observe: BuyOrdersListScreen at 800px renders full "Buy Orders (PO)" title without wrapping
    - Observe: PaymentRemindersScreen at 800px renders full "Payment Reminders" title without wrapping
  - **Property-based tests to write**:
    - Generate random widths in [600, 1920] range: verify NewPurchaseOrderScreen renders two-column Row(flex:4, flex:6) layout
    - Generate random widths in [600, 1920] range: verify StorageManagementScreen renders usage cards unchanged
    - Generate random widths in [600, 1920] range: verify CatalogueScreen grid columns match expected (2 for tablet, 4 for desktop)
    - Generate random widths in [600, 1920] range: verify CashflowScreen tab/chart layout unchanged
    - Generate random widths at breakpoint boundary [598, 601]: verify correct layout switching
    - Verify PaymentGatewaySettingsScreen renders credentials normally when API succeeds (mock 200)
    - Verify all business logic (PO creation, estimate creation, catalogue sharing) functions identically at desktop widths
  - **Non-Bug Condition**: `NOT isBugCondition(input)` — all inputs where `screenWidth >= 600` for layout screens, or API succeeds for PaymentGatewaySettingsScreen
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12_

- [x] 3. Create shared reusable components

  - [x] 3.1 Create `ResponsiveAppBarTitle` widget
    - File: `lib/widgets/responsive_app_bar_title.dart`
    - Wraps AppBar title text with `maxLines: 1, overflow: TextOverflow.ellipsis`
    - Responsive font size: `context.isMobile ? 16 : 20`
    - Accepts `title` string and optional `style` parameter
    - Used by Screens 3, 5, 7 and globally via DesktopContentContainer
    - _Requirements: 2.8, 2.15, 2.21_

  - [x] 3.2 Create `ApiErrorStateWidget` widget
    - File: `lib/widgets/api_error_state_widget.dart`
    - Props: `userMessage`, `onRetry`, `onReLogin`, `showReLogin`
    - Renders: Icon + user-friendly message + retry button + optional re-login button
    - NEVER exposes raw exception details to users
    - Add `classifyError()` utility and `userMessageFor()` mapping
    - Add `ApiErrorType` enum: `{auth, network, server, unknown}`
    - _Requirements: 2.22, 2.23, 2.27_

  - [x] 3.3 Enhance `ResponsiveEmptyState` in existing `EmptyStateWidget`
    - File: `lib/widgets/desktop/empty_state.dart`
    - Add responsive font sizing via `responsiveValue()`: title (mobile: 14, tablet: 16, desktop: 18), description (mobile: 12, tablet: 13, desktop: 14), icon (mobile: 48, tablet: 56, desktop: 64)
    - Ensure centered layout with `mainAxisAlignment: MainAxisAlignment.center`
    - Used by Screens 2, 3 for empty states
    - _Requirements: 2.6, 2.9_

- [x] 4. Fix CRITICAL screens (vertical text rendering — completely unusable on mobile)

  - [x] 4.1 Fix NewPurchaseOrderScreen — replace unconditional Row with mobile Column
    - File: `lib/features/buy_flow/screens/buy_orders_screen.dart` — `_CreateOrderScreen` class
    - Replace unconditional `Row(children: [Expanded(flex:4), SizedBox(width:24), Expanded(flex:6)])` with `context.isMobile ? Column(children: [vendorSection, SizedBox(h:16), itemsSection]) : Row(...existing...)`
    - Wrap mobile layout in `SingleChildScrollView` with `CrossAxisAlignment.stretch`
    - Remove `Expanded` on items list in mobile — use `SizedBox(height: 400)` or `ConstrainedBox`
    - Vendor section uses full width on mobile
    - Create Purchase button: full-width at bottom of scrollable content on mobile
    - PRESERVE: Desktop two-column Row(flex:4, flex:6) layout unchanged
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "NewPurchaseOrderScreen"_
    - _Expected_Behavior: Single-column stacked layout, no vertical text, vendor details readable, items full-width_
    - _Preservation: Desktop Row(flex:4, flex:6) layout unchanged at ≥ 600px_
    - _Requirements: 2.11, 2.12, 2.13, 2.14, 3.4_

  - [x] 4.2 Fix StorageManagementScreen — responsive container constraints
    - File: `lib/features/settings/presentation/screens/storage_management_screen.dart`
    - Add `constraints: BoxConstraints(minWidth: 280)` to usage card container
    - Use `responsiveValue(context, mobile: 12, tablet: 20, desktop: 24)` for `SingleChildScrollView` padding
    - Ensure `_usageRow` widget parent container has adequate width on mobile
    - Buttons ("Recalculate", "Clear Cache"): `SizedBox(width: double.infinity)` on mobile for full-width tap targets
    - PRESERVE: Desktop usage card layout unchanged at ≥ 600px
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "StorageManagementScreen"_
    - _Expected_Behavior: "App Data" and "Cache data" render horizontally, no vertical text, no overflow_
    - _Preservation: Desktop storage layout unchanged at ≥ 600px_
    - _Requirements: 2.24, 2.25, 3.9_

- [x] 5. Fix HIGH severity screens (overflow, clipping, missing data, raw exceptions)

  - [x] 5.1 Fix ProcessReturnScreen — responsive search field and button spacing
    - File: `lib/features/buy_flow/screens/process_return_screen.dart` (or equivalent)
    - Replace fixed-width search container with `Expanded` or `Flexible` wrapper
    - Add `responsiveValue` for search field padding/margins
    - Add `overflow: TextOverflow.ellipsis` to search hint text
    - Button spacing: `SizedBox(height: responsiveValue(context, mobile: 12, desktop: 16))`
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "ProcessReturnScreen"_
    - _Expected_Behavior: Search field fits within card, no text clipping, button has adequate spacing_
    - _Preservation: Desktop layout unchanged at ≥ 600px_
    - _Requirements: 2.1, 2.2, 2.3, 3.1_

  - [x] 5.2 Fix NewEstimateScreen — date fields, font sizing, currency encoding
    - File: `lib/features/revenue/screens/proforma_screen.dart`
    - Date fields: Replace horizontal `Row` with `context.isMobile ? Column(...) : Row(...)` to prevent label/value overlap
    - Empty state font: Change "No Items Added" to use `responsiveValue(context, mobile: 14, tablet: 16, desktop: 18)`
    - Currency fix: Replace garbled ₹ string literals with `'\u20B9'` or `CurrencyService.symbol`
    - Card spacing: Use `responsiveValue` for internal padding
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "NewEstimateScreen"_
    - _Expected_Behavior: Date labels don't overlap, correct ₹ symbol, responsive font sizes_
    - _Preservation: Desktop date field alignment and currency formatting unchanged at ≥ 600px_
    - _Requirements: 2.4, 2.5, 2.6, 2.7, 3.2_

  - [x] 5.3 Fix CatalogueScreen — title, description, button width, search alignment
    - File: `lib/features/catalogue/presentation/screens/catalogue_screen.dart`
    - Title: Fixed via global DesktopContentContainer title fix (task 7.1)
    - Description: Ensure subtitle uses `maxLines: 2, overflow: TextOverflow.ellipsis`
    - Share button: On mobile use `responsiveValue` for button width or icon-only variant
    - Search alignment: Add `EdgeInsets.symmetric(horizontal: responsiveValue(context, mobile: 12, desktop: 0))`
    - Verify grid columns: `responsiveValue(context, mobile: 1, tablet: 2, desktop: 4)` works correctly
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "CatalogueScreen"_
    - _Expected_Behavior: Title on single line, description readable, button responsive, search aligned_
    - _Preservation: Desktop 4-column grid and layout unchanged at ≥ 600px_
    - _Requirements: 2.15, 2.16, 2.17, 2.18, 3.5_

  - [x] 5.4 Fix CashflowScreen — data cards visibility and chart layout
    - File: `lib/features/reports/presentation/screens/cashflow_screen.dart`
    - Data cards: Wrap summary cards in `context.isMobile ? Column(...) : Row(...)` for full width per card on mobile
    - Chart area: Add `SizedBox(height: responsiveValue(context, mobile: 200, desktop: 300))` minimum height
    - Date range selector: Ensure row wraps on mobile or uses compact format
    - Tab bar: Add `isScrollable: true` if labels don't fit on mobile
    - Flow items list: Ensure `_FlowItem` card layout adapts to mobile width
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "CashflowScreen"_
    - _Expected_Behavior: Data cards show content, chart area visible, date selector usable_
    - _Preservation: Desktop tab layout with chart dimensions unchanged at ≥ 600px_
    - _Requirements: 2.19, 2.20, 3.6_

  - [x] 5.5 Fix PaymentGatewaySettingsScreen — API error handling
    - File: `lib/features/payment/presentation/screens/payment_gateway_settings_screen.dart`
    - Replace `Text(_error!)` with `ApiErrorStateWidget(userMessage: 'Unable to load payment settings...', onRetry: _loadConfigs, showReLogin: _isAuthError, onReLogin: _triggerReAuth)`
    - Add error classification: `bool get _isAuthError => _error?.contains('401') == true || _error?.contains('403') == true`
    - Add token refresh attempt before showing error (via Cognito auth chain / SessionManager)
    - Confirm loading indicator shows during retry
    - Sanitize catch blocks in `_verifyConfig`, `_deleteConfig` — use generic messages, never raw exception
    - _Bug_Condition: isBugCondition(input) where input.screenName = "PaymentGatewaySettingsScreen" AND input.apiState = EXPIRED_
    - _Expected_Behavior: User-friendly error with retry button, no raw exception text, token refresh attempted_
    - _Preservation: Credential management UI unchanged when API succeeds (200)_
    - _Requirements: 2.22, 2.23, 2.27, 3.8_

- [x] 6. Fix MEDIUM severity screens (AppBar overflow, spacing)

  - [x] 6.1 Fix BuyOrdersListScreen — AppBar title, empty state, button alignment
    - File: `lib/features/buy_flow/screens/buy_orders_screen.dart` — `BuyOrdersScreen` class
    - AppBar title: Handled by global DesktopContentContainer title fix (task 7.1)
    - Empty state: Use enhanced `EmptyStateWidget` with responsive sizing, centered alignment
    - Create PO button: On mobile render as `SizedBox(width: double.infinity, child: ElevatedButton(...))` for full-width
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "BuyOrdersListScreen"_
    - _Expected_Behavior: Title on single line, empty state centered, button full-width on mobile_
    - _Preservation: Desktop AppBar title and empty state layout unchanged at ≥ 600px_
    - _Requirements: 2.8, 2.9, 2.10, 3.3_

  - [x] 6.2 Fix PaymentRemindersScreen — AppBar title and action buttons
    - File: `lib/features/settings/presentation/screens/payment_reminders_screen.dart`
    - AppBar title: Handled by global DesktopContentContainer title fix (task 7.1)
    - Action buttons ("Send Test", "Save Settings"): Wrap in `context.isMobile ? Column(...) : Row(...)` to prevent overflow
    - _Bug_Condition: isBugCondition(input) where input.screenWidth < 600 AND input.screenName = "PaymentRemindersScreen"_
    - _Expected_Behavior: Title on single line, action buttons wrap on mobile_
    - _Preservation: Desktop layout with full title unchanged at ≥ 600px_
    - _Requirements: 2.21, 3.7_

- [x] 7. Apply global fixes

  - [x] 7.1 Fix DesktopContentContainer title overflow (global)
    - File: `lib/widgets/desktop/desktop_content_container.dart`
    - Modify title `Text` widget: add `maxLines: 1, overflow: TextOverflow.ellipsis`
    - Use responsive font size: `fontSize: context.isMobile ? 16 : 20`
    - This single fix resolves AppBar title overflow for Screens 3, 5, 7 and all future screens
    - _Bug_Condition: Title text exceeds available AppBar width on mobile viewports_
    - _Expected_Behavior: Title always renders on single line with ellipsis fallback_
    - _Preservation: Desktop title rendering (font size 20, no ellipsis needed) unchanged_
    - _Requirements: 2.8, 2.15, 2.21, 2.26_

  - [x] 7.2 Fix DesktopContentContainer mobile action buttons (global)
    - File: `lib/widgets/desktop/desktop_content_container.dart`
    - On mobile: collapse action button labels to icon-only or wrap actions in `Wrap` widget
    - Alternatively use popup menu for overflow actions on mobile
    - _Requirements: 2.26_

- [x] 8. Verify exploration tests now PASS (confirms bug is fixed)

  - [x] 8.1 Re-run bug condition exploration tests
    - **Property 1: Expected Behavior** - Mobile Layouts Render Correctly After Fix
    - **IMPORTANT**: Re-run the SAME tests from task 1 — do NOT write new tests
    - The tests from task 1 encode the expected behavior for all 9 screens
    - When these tests pass, it confirms the expected behavior is satisfied
    - Run `test/bug_condition/mobile_responsiveness_exploration_test.dart`
    - **EXPECTED OUTCOME**: All 9 screen tests PASS (confirms bugs are fixed)
    - If any test still fails, identify which screen fix is incomplete and address it
    - _Requirements: 2.1–2.25_

- [x] 9. Verify preservation tests still PASS (confirms no regressions)

  - [x] 9.1 Re-run preservation property tests
    - **Property 2: Preservation** - Desktop/Tablet Layouts Still Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run `test/bug_condition/mobile_responsiveness_preservation_test.dart`
    - **EXPECTED OUTCOME**: All preservation tests PASS (confirms no regressions)
    - Verify: NewPurchaseOrderScreen still has two-column layout at ≥ 600px
    - Verify: CatalogueScreen still has 4-column grid on desktop
    - Verify: CashflowScreen tab/chart layout unchanged on desktop
    - Verify: PaymentGatewaySettingsScreen credentials UI unchanged on success
    - Verify: All business logic operates identically
    - If any test fails, identify which screen fix introduced a regression and address it
    - _Requirements: 3.1–3.12_

- [x] 10. Global audit scan and remaining fixes

  - [x] 10.1 Run global codebase audit for remaining layout issues
    - Scan all screens for: RenderFlex overflow warnings, constraint exceptions, infinite height/width, text overflow/clipping, vertical text rendering, desktop layouts on mobile
    - Test across target viewports: 360×640, 393×851, 412×915, 768×1024, 1024×1366, 1920×1080
    - Identify any remaining screens not in the 9-screen list that have similar issues
    - _Requirements: 2.26_

  - [x] 10.2 Fix any remaining issues found in audit
    - Apply same patterns (context.isMobile conditional, responsiveValue, Flexible/Expanded wrappers) to any additional screens found
    - Ensure zero RenderFlex overflow warnings across entire codebase
    - _Requirements: 2.26, 2.27_

  - [x] 10.3 Verify previously fixed screens have not regressed
    - Confirm StockEntryScreen, StockReversalScreen, BuyFlowDashboard still work correctly
    - Run any existing tests for these screens
    - _Requirements: 3.11_

- [x] 11. Final validation checkpoint
  - Run full test suite: `flutter test`
  - Ensure ALL exploration tests (task 1) pass — bugs are fixed
  - Ensure ALL preservation tests (task 2) pass — no regressions
  - Ensure all unit tests for shared components pass
  - Verify no new lint warnings or analysis issues: `flutter analyze`
  - Test on representative viewports: 360px (phone), 768px (tablet), 1920px (desktop)
  - Confirm zero RenderFlex overflow in debug mode across all 9 screens + global audit screens
  - Ask the user if questions arise
  - _Requirements: 2.26, 3.10, 3.12_

---

## Task Dependency Graph

```json
{
  "waves": [
    {
      "name": "Wave 1: Bug Exploration",
      "tasks": ["1"],
      "description": "Write exploration tests that FAIL on unfixed code to confirm bugs exist"
    },
    {
      "name": "Wave 2: Preservation Baseline",
      "tasks": ["2"],
      "description": "Write preservation tests that PASS on unfixed code to capture baseline behavior"
    },
    {
      "name": "Wave 3: Shared Components",
      "tasks": ["3.1", "3.2", "3.3"],
      "description": "Create reusable widgets needed by screen fixes"
    },
    {
      "name": "Wave 4: Implementation (Parallel)",
      "tasks": ["4.1", "4.2", "5.1", "5.2", "5.3", "5.4", "5.5", "7.1", "7.2"],
      "description": "Fix CRITICAL screens, HIGH screens, and global DesktopContentContainer in parallel"
    },
    {
      "name": "Wave 5: MEDIUM Fixes",
      "tasks": ["6.1", "6.2"],
      "description": "Fix MEDIUM severity screens (depends on global DesktopContentContainer fix from Wave 4)"
    },
    {
      "name": "Wave 6: Verification",
      "tasks": ["8.1", "9.1"],
      "description": "Verify exploration tests now PASS (bug fixed) and preservation tests still PASS (no regressions)"
    },
    {
      "name": "Wave 7: Global Audit",
      "tasks": ["10.1", "10.2", "10.3"],
      "description": "Scan entire codebase for remaining layout issues and fix them"
    },
    {
      "name": "Wave 8: Final Checkpoint",
      "tasks": ["11"],
      "description": "Full test suite, lint, and manual verification across all target viewports"
    }
  ]
}
```

**Execution order**: 1 → 2 → 3 → (4 ∥ 5 ∥ 7) → 6 → 8 → 9 → 10 → 11

Tasks 4, 5, and 7 can be executed in parallel after Task 3 completes.
Task 6 depends on Task 7 (DesktopContentContainer global fix) being complete.
Tasks 8 and 9 require all implementation (Tasks 4–7) to be complete.

## Notes

- The `context.isMobile` extension is defined in `lib/core/responsive/responsive_layout.dart` and returns `true` when `MediaQuery.of(context).size.width < 600`
- The `responsiveValue<T>(context, mobile: X, tablet: Y, desktop: Z)` utility returns breakpoint-appropriate values
- The proven pattern from already-fixed screens uses: `context.isMobile ? Column(...) : Row(...)`
- `DesktopContentContainer` is the shared shell widget used by all affected screens — fixing its title overflow resolves AppBar issues globally
- All tests should use `MediaQuery` override in a test harness to simulate different screen widths
- The Unicode/₹ encoding fix requires checking source file encoding (UTF-8 BOM) or replacing raw bytes with `'\u20B9'`
- Screen 8 (PaymentGatewaySettings) requires investigation of AWS Cognito token refresh chain before implementing error UI
- Screen 6 (Funds Flow/Cashflow) may have data pipeline issues beyond layout — investigate state management and API response handling
- Target viewports: 360×640, 393×851, 412×915, 768×1024, 1024×1366, 1920×1080
- Target platforms: Android phone, Android tablet, iPhone, iPad, Windows, macOS, Linux
Y