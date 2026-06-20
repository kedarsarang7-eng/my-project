# Implementation Plan

## Overview

Fix 18 production bugs across DukanX spanning four severity phases: Phase 0 crashes (unregistered GetIt services, null-check failures), Phase 1 text wrapping bugs, Phase 2 visual defects (black backgrounds, status bar overlap, mojibake, overlapping cards, stuck overlay), and Phase 3 cosmetic truncation. Uses the bug condition methodology: explore bugs first, write preservation tests, implement fixes, then validate.

## Tasks

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Production Crash & UI Defect Reproduction
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bugs exist across all four phases
  - **Scoped PBT Approach**: Scope the property to the concrete failing cases for each bug condition
  - Phase 0 Crash Tests:
    - Test that `sl<DunningService>()` throws StateError after `initializeDependencies()` (service not registered)
    - Test that `sl<PaymentGatewayApiService>()` throws StateError after `initializeDependencies()` (service not registered)
    - Test that DataImportExportScreen crashes when `SessionManager.userId == null`
    - Test that DatabaseManagementScreen crashes when session state is null
  - Phase 1 Layout Tests:
    - Render BuyFlowDashboard stat cards in a 320px-wide viewport and assert text does NOT wrap vertically (will fail on unfixed code)
    - Render StockEntry "Total/Due" labels in narrow Row and assert single-line rendering (will fail)
    - Render StockReversal info banner in narrow Row and assert single-line rendering (will fail)
    - Render NewPurchaseOrder vendor sidebar text and assert single-line rendering (will fail)
  - Phase 2 Visual Tests:
    - Build SettingsScreen and assert `Scaffold.backgroundColor` is non-null and matches theme (will fail)
    - Build FinancialReportsScreen and assert `Scaffold.backgroundColor` is non-null (will fail)
    - Assert SafeArea is present in widget tree for Settings, Financial Reports, Data Import/Export, Database Management (will fail)
    - Assert ₹ symbol codepoint == 0x20B9 on NewPurchaseOrder total amount (will fail - mojibake)
    - Assert dashboard cards do not overlap at 360px viewport width (will fail)
    - Assert loading overlay is dismissed after data fetch completes on Inventory screen (will fail)
  - Phase 3 Cosmetic Tests:
    - Assert "Vendor Details" dropdown label is not truncated (will fail)
    - Assert "Payment Info" dropdown label is not truncated (will fail)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct - it proves the bugs exist)
  - Document counterexamples found to understand root causes
  - Mark task complete when tests are written, run, and failures are documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Existing Functionality Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - **Observe on UNFIXED code** (cases where isBugCondition returns false):
    - Observe: All 50+ previously-registered services resolve correctly from GetIt
    - Observe: DataImportExportScreen works correctly when userId is non-null (CSV import, export)
    - Observe: DatabaseManagementScreen works correctly when session is initialized (VACUUM, ANALYZE, integrity checks)
    - Observe: Text widgets already inside Expanded/Flexible render correctly (no vertical wrapping)
    - Observe: Screens with existing Scaffold backgroundColor render their correct theme color
    - Observe: ₹ symbol renders correctly on billing/invoice screens (codepoint 0x20B9)
    - Observe: Dashboard cards that are already responsive do not overlap
    - Observe: Inventory empty-state UI renders without stuck overlay
    - Observe: Dropdown labels with sufficient container space render full text
  - **Write property-based tests capturing observed behavior patterns**:
    - Property: For all registered services in service_locator.dart, `sl<ServiceType>()` resolves without exception after fix
    - Property: For all non-null userId values, DataImportExportScreen and DatabaseManagementScreen render without crash
    - Property: For all viewport widths (300–1920px), text widgets already in Expanded/Flexible do not wrap vertically
    - Property: For all screens with existing Scaffold backgroundColor, the color value is unchanged after fix
    - Property: For all subscription-gated features accessed on correct plan tier, full access is maintained
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

- [x] 3. Fix Phase 0 — App Crashes (Service Registration & Null Guards)

  - [x] 3.1 Register DunningService in service_locator.dart
    - Add `sl.registerLazySingleton<DunningService>(() => DunningService(db: sl<AppDatabase>(), billsRepo: sl<BillsRepository>(), customersRepo: sl<CustomersRepository>(), whatsAppService: sl<WhatsAppService>()))` in the services section of `initializeDependencies()`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'DunningConfigScreen' AND NOT sl.isRegistered(DunningService)_
    - _Expected_Behavior: sl<DunningService>() returns valid instance without throwing_
    - _Preservation: All previously-registered services continue to resolve normally (Req 3.1)_
    - _Requirements: 2.1_

  - [x] 3.2 Register PaymentGatewayApiService in service_locator.dart
    - Add `sl.registerLazySingleton<PaymentGatewayApiService>(() => PaymentGatewayApiService(sl<ApiClient>()))` in the payment services section of `initializeDependencies()`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'PaymentGatewaySettingsScreen' AND NOT sl.isRegistered(PaymentGatewayApiService)_
    - _Expected_Behavior: sl<PaymentGatewayApiService>() returns valid instance without throwing_
    - _Preservation: All previously-registered services continue to resolve normally (Req 3.1)_
    - _Requirements: 2.2_

  - [x] 3.3 Add null guard on Data Import/Export screen
    - In `data_import_export_screen.dart`, add early-return widget showing "Please sign in" when `SessionManager.userId` is null or empty
    - Ensure the hosting route/provider does not use `userId!` without null check
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'DataImportExportScreen' AND SessionManager.userId == null_
    - _Expected_Behavior: Screen shows "Please sign in" fallback UI without crashing_
    - _Preservation: Signed-in users see full import/export functionality unchanged (Req 3.2)_
    - _Requirements: 2.3_

  - [x] 3.4 Add null guard on Database Management screen
    - In `database_management_screen.dart`, guard nullable session property access; show fallback UI if session is not ready
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'DatabaseManagementScreen' AND SessionManager.userId == null_
    - _Expected_Behavior: Screen shows appropriate fallback UI without crashing_
    - _Preservation: Signed-in users see full DB management functionality unchanged (Req 3.2)_
    - _Requirements: 2.4_

- [x] 4. Fix Phase 1 — Text Layout (Vertical Wrapping)

  - [x] 4.1 Fix BuyFlow Dashboard stat card text wrapping
    - In `buy_flow_dashboard.dart`, wrap Text widgets inside stat card Rows with `Expanded` and set `overflow: TextOverflow.ellipsis, maxLines: 1`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'BuyFlowDashboard' AND input.hasTextInRowWithoutFlexConstraint_
    - _Expected_Behavior: Text fills horizontal space and truncates gracefully, never wraps vertically_
    - _Preservation: Existing Expanded/Flexible text on other screens unchanged (Req 3.3)_
    - _Requirements: 2.5_

  - [x] 4.2 Fix Stock Entry "Total/Due" label wrapping
    - In `stock_entry_screen.dart`, find Row children containing "Total"/"Due" labels and wrap Text in `Expanded` with `TextOverflow.ellipsis`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'StockEntryScreen' AND input.hasTextInRowWithoutFlexConstraint_
    - _Expected_Behavior: Labels render on single line with ellipsis overflow_
    - _Preservation: Existing text layouts unchanged (Req 3.3)_
    - _Requirements: 2.6_

  - [x] 4.3 Fix Stock Reversal info banner text wrapping
    - In `stock_reversal_screen.dart`, wrap the info banner Row's Text child in `Expanded` with `TextOverflow.ellipsis`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'StockReversalScreen' AND input.hasTextInRowWithoutFlexConstraint_
    - _Expected_Behavior: Info banner text renders on single line_
    - _Preservation: Existing text layouts unchanged (Req 3.3)_
    - _Requirements: 2.7_

  - [x] 4.4 Fix New Purchase Order vendor sidebar and empty state text wrapping
    - In the New Purchase Order screen, wrap vendor sidebar Text and "No items added" empty state Text in `Expanded` with `TextOverflow.ellipsis`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'NewPurchaseOrderScreen' AND input.hasTextInRowWithoutFlexConstraint_
    - _Expected_Behavior: Text renders horizontally with ellipsis, never one-char-per-line_
    - _Preservation: Existing text layouts unchanged (Req 3.3)_
    - _Requirements: 2.8_

- [x] 5. Fix Phase 2 — Visual Defects (Background, SafeArea, Mojibake, Cards, Overlay)

  - [x] 5.1 Add Scaffold with backgroundColor and SafeArea to Settings screen
    - In `main_settings_screen.dart`, wrap content in `Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: SafeArea(child: ...))`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'SettingsScreen' AND (scaffoldMissingBackgroundColor OR missingSafeArea)_
    - _Expected_Behavior: Theme-appropriate background color; content below status bar_
    - _Preservation: Screens with existing Scaffold/SafeArea unchanged (Req 3.4)_
    - _Requirements: 2.9, 2.13_

  - [x] 5.2 Add Scaffold with backgroundColor and SafeArea to Financial Reports screen
    - Locate the Financial Reports screen and wrap in `Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: SafeArea(child: ...))`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'FinancialReportsScreen' AND (scaffoldMissingBackgroundColor OR missingSafeArea)_
    - _Expected_Behavior: Theme-appropriate background color; content below status bar_
    - _Preservation: Screens with existing Scaffold/SafeArea unchanged (Req 3.4)_
    - _Requirements: 2.10, 2.13_

  - [x] 5.3 Add Scaffold with backgroundColor and SafeArea to Data Import/Export screen
    - In `data_import_export_screen.dart`, wrap `DesktopContentContainer` in `Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: SafeArea(child: ...))`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'DataImportExportScreen' AND (scaffoldMissingBackgroundColor OR missingSafeArea)_
    - _Expected_Behavior: Theme-appropriate background color; content below status bar_
    - _Preservation: Screens with existing Scaffold/SafeArea unchanged (Req 3.4)_
    - _Requirements: 2.11, 2.13_

  - [x] 5.4 Add Scaffold with backgroundColor and SafeArea to Database Management screen
    - In `database_management_screen.dart`, wrap content in `Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: SafeArea(child: ...))`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'DatabaseManagementScreen' AND (scaffoldMissingBackgroundColor OR missingSafeArea)_
    - _Expected_Behavior: Theme-appropriate background color; content below status bar_
    - _Preservation: Screens with existing Scaffold/SafeArea unchanged (Req 3.4)_
    - _Requirements: 2.12, 2.13_

  - [x] 5.5 Fix ₹ mojibake on New Purchase Order screen
    - Replace byte-level rupee construction with Unicode literal `'₹'` or `'\u20B9'` or use `CurrencyService.symbol`
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'NewPurchaseOrderScreen' AND input.rupeeLiteralIsNotUTF8_
    - _Expected_Behavior: Rupee sign renders as ₹ (U+20B9) without mojibake_
    - _Preservation: ₹ symbol on billing/invoice screens remains correct (Req 3.5)_
    - _Requirements: 2.14_

  - [x] 5.6 Fix overlapping dashboard cards with responsive layout
    - Replace `Row` with fixed-width children with `Wrap` or responsive `LayoutBuilder`-based layout for "Recent Transactions" and "Tax Summary" cards
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'DashboardScreen' AND input.cardsUseFixedWidthLayout_
    - _Expected_Behavior: Cards never visually overlap regardless of viewport width_
    - _Preservation: Already-responsive dashboard cards unchanged (Req 3.6)_
    - _Requirements: 2.15_

  - [x] 5.7 Fix stuck loading overlay on Inventory screen
    - Ensure `setState(() => _isLoading = false)` is called in ALL code paths (success, error, empty) — add to `finally` block of data fetch
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'InventoryScreen' AND input.loadingOverlayNotDismissed_
    - _Expected_Behavior: Loading overlay dismissed immediately after data fetch completes_
    - _Preservation: Inventory empty-state UI continues to work (Req 3.7)_
    - _Requirements: 2.16_

- [x] 6. Fix Phase 3 — Cosmetic Truncation

  - [x] 6.1 Fix dropdown label truncation on New Purchase Order screen
    - Remove hard-coded width constraint from "Vendor Details" and "Payment Info" dropdown wrappers
    - Set `isExpanded: true` on DropdownButton or increase container width
    - _Bug_Condition: isBugCondition(input) where input.targetScreen == 'NewPurchaseOrderScreen' AND input.dropdownLabelConstrainedWithoutOverflow_
    - _Expected_Behavior: "Vendor Details" and "Payment Info" labels fully readable_
    - _Preservation: Dropdown labels with sufficient space remain full-width (Req 3.8)_
    - _Requirements: 2.17, 2.18_

- [x] 7. Verify bug condition exploration test now passes

  - [x] 7.1 Re-run bug condition exploration test
    - **Property 1: Expected Behavior** - All Bug Conditions Resolved
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior for all 18 bug conditions
    - When this test passes, it confirms all bugs are fixed:
      - `sl<DunningService>()` rdcfvesolves without exception
      - `sl<PaymentGatewayApiService>()` resolves without exception
      - DataImportExportScreen shows fallback UI when userId is null (no crash)
      - DatabaseManagementScreen shows fallback UI when session is null (no crash)
      - Text widgets in affected screens render single-line with ellipsis
      - All 4 screens have Scaffold with backgroundColor and SafeArea
      - ₹ symbol codepoint == 0x20B9
      - Dashboard cards do not overlap at any viewport width
      - Loading overlay dismissed after fetch
      - Dropdown labels fully readable
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms all bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15, 2.16, 2.17, 2.18_

  - [x] 7.2 Verify preservation tests still pass
    - **Property 2: Preservation** - No Regressions After Fix
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all property-based tests still pass after fix:
      - All 50+ previously-registered services still resolve
      - Signed-in user flows unchanged
      - Existing text layouts unchanged
      - Existing Scaffold backgrounds unchanged
      - ₹ on other screens unchanged
      - Responsive cards unchanged
      - Empty-state UI unchanged
      - Full-width dropdown labels unchanged
      - All 19+ dashboards navigate without exceptions
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_

- [x] 8. Checkpoint - Ensure all tests pass
  - Run full test suite: `flutter test`
  - Ensure all unit tests, property-based tests, and widget tests pass
  - Run integration test: navigate all 19+ dashboards and verify zero unhandled exceptions
  - Ensure `flutter analyze` reports no new issues introduced by the fix
  - Ask the user if questions arise

## Task Dependency Graph

```json
{
  "waves": [
    { "tasks": ["1"] },
    { "tasks": ["2"] },
    { "tasks": ["3", "4", "5", "6"] },
    { "tasks": ["7"] },
    { "tasks": ["8"] }
  ]
}
```

## Notes

- Tasks 1 and 2 MUST be completed before any implementation (tasks 3–6)
- Tasks 3, 4, 5, 6 can be executed in parallel after preservation tests pass
- Task 7 verifies both bug fix and preservation after all implementation tasks complete
- Task 8 is the final checkpoint ensuring the full suite passes
- For Phase 0 crashes: the fix is minimal (register services, add null guards)
- For Phase 1 text layout: wrap Text in Expanded/Flexible with TextOverflow.ellipsis
- For Phase 2 visual: add Scaffold backgroundColor + SafeArea, fix encoding, fix layout, fix state
- For Phase 3 cosmetic: remove hard-coded width constraints or use isExpanded on DropdownButton
