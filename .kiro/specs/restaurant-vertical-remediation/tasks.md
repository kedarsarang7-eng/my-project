# Implementation Plan

## Overview

Phased implementation plan for the restaurant vertical remediation bugfix. Follows the bug condition methodology: explore the bug (Property 1), preserve existing behavior (Property 2), implement the fix, then validate. Phases are ordered P0 (critical tenant isolation) → P1 (feature defects) → P2 (validation/UX) → P3 (cleanup).

## Tasks

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Tenant Isolation Breach via Hardcoded vendorId
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the tenant isolation breach
  - **Scoped PBT Approach**: Scope the property to the 4 concrete failing sidebar items: `restaurant_tables`, `kitchen_display`, `menu_management`, `daily_summary`
  - Write a widget test that calls `SidebarNavigationHandler.tryGetScreenForItem` for each restaurant sidebar item
  - Assert: returned widget's `vendorId` == `SessionManager.currentBusinessId` (from Bug Condition: `input.resolvedVendorId == 'SYSTEM' AND SessionManager.currentBusinessId != 'SYSTEM'`)
  - Assert: returned widget's `vendorId` != `'SYSTEM'`
  - Mock `SessionManager` with a real businessId (e.g., `'usr_pizza_palace_123'`)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS because all 4 screens receive `vendorId: 'SYSTEM'` instead of the session businessId
  - Document counterexamples found (e.g., `TableManagementScreen.vendorId == 'SYSTEM'` when `currentBusinessId == 'usr_pizza_palace_123'`)
  - Also test `OrderType.fromString('DELIVERY')` returns `OrderType.delivery` (will fail - falls back to `dineIn`)
  - Also test `UserRole` parsing for `'waiter'` returns `UserRole.waiter` (will fail - falls to `unknown`)
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.13, 1.14_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Restaurant Sidebar Resolution & Existing Behavior Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: For all non-restaurant sidebar items (`new_sale`, `revenue_overview`, `sales_register`, `stock_summary`, `item_stock`, `low_stock`, etc.), record the widget type returned by `tryGetScreenForItem` on UNFIXED code
  - Observe: `RestaurantBusinessRules.splitBill(1000, 2)` returns `500` on unfixed code
  - Observe: `RestaurantBusinessRules.serviceCharge(1000)` returns `50` on unfixed code
  - Observe: `OrderType.fromString('DINE_IN')` returns `OrderType.dineIn` on unfixed code
  - Observe: `OrderType.fromString('TAKEAWAY')` returns `OrderType.takeaway` on unfixed code
  - Write property-based test: for all non-restaurant sidebar item IDs (generate from full catalog of 23+ items), the widget type returned is identical before and after fix
  - Write property-based test: for all existing `OrderType` values (`dineIn`, `takeaway`), `fromString` continues to return the correct enum value
  - Write property-based test: for any subtotal > 0, `RestaurantBusinessRules.serviceCharge(subtotal)` returns `subtotal * 0.05`
  - Write unit test: `BusinessQuickActions` for restaurant still navigates to same sidebar item IDs (`restaurant_tables`, `kitchen_display`, `menu_management`)
  - Write unit test: GST rate for restaurant remains 5% non-editable via `BusinessTypeRegistry`
  - Verify all tests PASS on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.10, 3.11_

- [x] 3. Phase 0 — P0: Tenant Isolation Fix (Critical)

  - [x] 3.1 Replace hardcoded `vendorId: 'SYSTEM'` in SidebarNavigationHandler
    - In `lib/widgets/desktop/sidebar_navigation_handler.dart`, function `tryGetScreenForItem`, restaurant case block (lines 375–383)
    - Replace all 4 instances of `vendorId: 'SYSTEM'` with `vendorId: sl<SessionManager>().currentBusinessId ?? sl<SessionManager>().userId ?? 'SYSTEM'`
    - Affected cases: `restaurant_tables` → `TableManagementScreen`, `kitchen_display` → `KitchenDisplayScreen`, `menu_management` → `FoodMenuManagementScreen`, `daily_summary` → `RestaurantDailySummaryScreen`
    - _Bug_Condition: isBugCondition(input) where input.itemId IN ['restaurant_tables', 'kitchen_display', 'menu_management', 'daily_summary'] AND input.resolvedVendorId == 'SYSTEM'_
    - _Expected_Behavior: Screen.vendorId == SessionManager.currentBusinessId for all 4 restaurant sidebar items_
    - _Preservation: Non-restaurant sidebar items continue resolving identically; no code path changes for other verticals_
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 3.2 Fix vendorId in restaurant module routes
    - In `modules/restaurant/routes/restaurant_routes.dart`, replace `vendorId: 'SYSTEM'` with session-resolved vendorId (same pattern as sidebar handler)
    - _Requirements: 2.1, 2.3_

  - [x] 3.3 Implement one-time data migration for existing 'SYSTEM' records
    - Create migration function that runs on app launch for restaurant business type
    - Query all rows in `restaurant_tables`, `food_orders`, `food_menu_items`, `food_menu_categories` where `vendorId == 'SYSTEM'`
    - Update them to `vendorId = SessionManager.currentBusinessId`
    - Track migration completion via `SharedPreferences` key `'restaurant_vendorid_migrated'`
    - Only runs once per installation
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
    - _Preservation: Sync contract continues with same API shape; only vendorId value changes from 'SYSTEM' to real tenant ID_

  - [x] 3.4 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Tenant Isolation via vendorId Resolution
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior (vendorId == currentBusinessId)
    - When this test passes, it confirms the tenant isolation bug is fixed
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed — all 4 screens now receive real businessId)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 3.5 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Restaurant Sidebar Resolution Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions to non-restaurant verticals, GST, business rules, or generic sidebar items)
    - Confirm all tests still pass after fix (no regressions)
    - _Requirements: 3.1, 3.4, 3.5, 3.6, 3.7, 3.10, 3.11_

- [x] 4. Phase 1A — Dashboard Live Data

  - [x] 4.1 Create `restaurantAlertCountsProvider` StreamProvider
    - Create a new `StreamProvider` that watches `FoodOrderRepository.watchPendingOrders(currentBusinessId)`
    - Compute "Active Orders" = orders with status IN [`accepted`, `cooking`, `ready`, `served`]
    - Compute "Kitchen Queue" = orders with status IN [`pending`, `accepted`]
    - Compute "Low Ingredients" = reuse existing `alertCountsProvider` `lowStock` count
    - _Requirements: 2.5_

  - [x] 4.2 Replace hardcoded restaurant branch in BusinessAlertsWidget
    - In `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
    - Replace literal `'7'`, `'12'`, `'4'` in the restaurant `case` branch of `_buildAlertsForBusiness`
    - Wire to `restaurantAlertCountsProvider` live counts (same pattern as hardware/mandi branches)
    - _Bug_Condition: Restaurant dashboard always shows hardcoded counts regardless of real data_
    - _Expected_Behavior: Dashboard shows real-time counts from live order stream_
    - _Preservation: Grocery, pharmacy, hardware dashboard branches remain unchanged_
    - _Requirements: 2.5, 3.2_

  - [x] 4.3 Write integration test for dashboard live data
    - Verify `BusinessAlertsWidget` with `businessType == restaurant` displays dynamic values from provider
    - Verify counts update when order statuses change
    - Verify other business types' alert widgets remain unchanged
    - _Requirements: 2.5, 3.2_

- [x] 5. Phase 1B — Orphaned Screen Navigation

  - [x] 5.1 Add "Advanced Operations" sidebar section in `sidebar_configuration.dart`
    - In `_getRestaurantSections()`, add new section with items: `floor_management`, `kot_report`, `recipe_management`, `delivery_ops`, `restaurant_command_center`
    - Gate `floor_management` by `useTableManagement` capability
    - Gate `kot_report` by `useKOT` capability
    - Gate `delivery_ops` as always-visible for restaurant
    - _Requirements: 2.6_

  - [x] 5.2 Register new case entries in SidebarNavigationHandler
    - Add `case 'floor_management'` → `FloorManagementScreen(vendorId: vendorId)`
    - Add `case 'kot_report'` → `KotReportScreen(vendorId: vendorId)`
    - Add `case 'recipe_management'` → `RecipeManagementScreen(vendorId: vendorId)`
    - Add `case 'delivery_ops'` → `RestaurantDeliveryOpsScreen(vendorId: vendorId)`
    - Add `case 'restaurant_command_center'` → `RestaurantOwnerCommandScreen(vendorId: vendorId)`
    - Use session-resolved `vendorId` for all (same pattern as P0 fix)
    - Import all orphaned screen files
    - _Requirements: 2.6_
    - _Preservation: Existing sidebar items and navigation remain unchanged_

  - [x] 5.3 Write navigation tests for newly-wired screens
    - Verify each new sidebar item resolves to the correct screen widget
    - Verify `vendorId` is session-resolved (not 'SYSTEM')
    - Verify capability gating works (item hidden when capability disabled)
    - Verify no crash when navigating to each orphaned screen
    - _Requirements: 2.6, 3.6_

- [x] 6. Phase 1C — Billing Logic Wiring

  - [x] 6.1 Add half-portion toggle to bill line items
    - In `bill_creation_screen_v2.dart`, when `businessType == restaurant` and config `optionalFields` includes `isHalf`
    - Render toggle on each bill line item that sets `isHalf` flag
    - _Requirements: 2.7_

  - [x] 6.2 Add parcel flag to bill line items
    - In `bill_creation_screen_v2.dart`, when config `optionalFields` includes `isParcel`
    - Render parcel/takeaway chip per line item that sets `isParcel` flag
    - _Requirements: 2.8_

  - [x] 6.3 Wire service charge to bill finalization
    - Add service charge row in bill totals section for dine-in restaurant bills
    - Default to 5% via `RestaurantBusinessRules.serviceCharge(subtotal)`, user-adjustable
    - Include service charge in bill total calculation
    - _Requirements: 2.9_
    - _Preservation: RestaurantBusinessRules.serviceCharge logic unchanged — only UI integration is new_

  - [x] 6.4 Add split bill action button
    - Add "Split Bill" action button that opens dialog accepting split count
    - Invoke `RestaurantBusinessRules.splitBill(total, count)` and display per-guest amounts
    - _Requirements: 2.10_
    - _Preservation: RestaurantBusinessRules.splitBill logic unchanged — only UI affordance is new_

  - [x] 6.5 Wire happy-hour pricing logic
    - When `RestaurantBusinessRules.isInHappyHour(...)` returns true for configured window
    - Auto-apply discount to eligible menu items
    - Requires happy-hour config (hourStart/hourEnd from business settings)
    - _Requirements: 2.11_

  - [x] 6.6 Add tip input field to billing flow
    - Add optional "Tip" field in payment section of `BillCreationScreenV2`
    - Store value in `Bill.tipAmount` field
    - _Requirements: 2.12_

  - [x] 6.7 Write billing integration tests
    - Test half-portion toggle appears and sets `isHalf` correctly
    - Test parcel flag appears and sets `isParcel` correctly
    - Test service charge calculation and display for dine-in bills
    - Test split bill dialog and amount computation
    - Test tip field saves to bill
    - Verify GST rate (5% non-editable) still applies correctly alongside new fields
    - _Requirements: 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 3.3_

- [x] 7. Phase 1D — OrderType Enum Completion

  - [x] 7.1 Add `delivery` and `parcel` enum values to OrderType
    - In `lib/features/restaurant/data/models/food_order_model.dart`
    - Add `delivery('DELIVERY')` and `parcel('PARCEL')` to `OrderType` enum
    - Verify `fromString` handles new values via existing `firstWhere` pattern
    - _Requirements: 2.13_
    - _Preservation: Existing dineIn/takeaway values and fromString fallback remain unchanged_

  - [x] 7.2 Update daily summary to bucket by all 4 order types
    - Modify `RestaurantDailySummaryScreen._processOrders` to include delivery and parcel buckets
    - _Requirements: 2.13_

  - [x] 7.3 Write OrderType unit tests
    - Test `OrderType.fromString('DELIVERY')` returns `OrderType.delivery`
    - Test `OrderType.fromString('PARCEL')` returns `OrderType.parcel`
    - Test `OrderType.fromString('DINE_IN')` still returns `OrderType.dineIn` (preservation)
    - Test `OrderType.fromString('TAKEAWAY')` still returns `OrderType.takeaway` (preservation)d6566y
    - Test `OrderType.fromString('INVALID')` falls back to `dineIn` (preservation)
    - Test `OrderType.values.length == 4`
    - _Requirements: 2.13, 3.4_

- [x] 8. Phase 1E — RBAC Role Expansion

  - [x] 8.1 Add `waiter`, `chef`, `captain` to UserRole enum
    - In `lib/core/models/user_role.dart`, add new enum values
    - Define permission sets: waiter (create orders, view tables), chef (view KDS, update order status), captain (all waiter + assign tables + view reports)
    - Update `RolePermissions` accordingly
    - _Requirements: 2.14_

  - [x] 8.2 Update SessionManager role string mapping
    - In `lib/core/session/session_manager.dart`, add `'waiter'`, `'chef'`, `'captain'` cases in `_loadUserSession` role switch
    - Update `resolveFallbackStaffRole` to include new roles in "preserve, do NOT escalate" branch
    - _Requirements: 2.14_
    - _Preservation: Existing role resolution for owner, manager, staff, accountant, pharmacist unchanged_

  - [x] 8.3 Write RBAC role tests
    - Test parsing `'waiter'` → `UserRole.waiter`
    - Test parsing `'chef'` → `UserRole.chef`y
    - Test parsing `'captain'` → `UserRole.captain`
    - Test existing roles still parse correctly (preservation)
    - Test permission sets for each new role
    - Test `resolveFallbackStaffRole` does not escalate new roles
    - _Requirements: 2.14, 3.5_

- [x] 9. Phase 2A — Input Validation

  - [x] 9.1 Fix menu item price validation
    - In `food_menu_management_screen.dart`, replace `double.tryParse(v) ?? 0` with proper validation
    - If parse fails or value ≤ 0, show `FormField` error text and disable save button
    - _Requirements: 2.15_

  - [x] 9.2 Fix table bulk-add capacity validation
    - In `table_management_screen.dart`, validate 1 ≤ capacity ≤ 50, show error for out-of-range
    - Validate startNumber ≥ 1, show error for invalid
    - _Requirements: 2.16_

  - [x] 9.3 Fix category reorder persistence
    - In `food_menu_management_screen.dart`, after `onReorder` callback, call repository method to persist the new sort indices
    - _Requirements: 2.17_
y
  - [x] 9.4 Write input validation tests
    - Test price field rejects non-numeric, empty, zero, and negative inputs with error message
    - Test price field accepts valid positive numeric inputs
    - Test capacity field rejects values outside 1–50 range
    - Test startNumber field rejects values < 1
    - Test category reorder persists new order to repository
    - _Requirements: 2.15, 2.16, 2.17_

- [x] 10. Phase 2B — KDS Performance & UX

  - [x] 10.1 Remove/repurpose redundant Refresh button
    - In `kitchen_display_screen.dart`, replace manual Refresh button with "Last updated: X" timestamp indicator
    - StreamBuilder already provides live updates
    - _Requirements: 2.18_

  - [x] 10.2 Implement responsive layout for KDS
    - Replace fixed 3-column `Row` with `LayoutBuilder`
    - 1 column on narrow (<600px), 2 on medium (600–1000px), 3+ on wide (>1000px)
    - _Requirements: 2.19_

  - [x] 10.3 Fix sound toggle behavior
    - Either wire `audioplayers` package to play notification sound on new orders
 y   - Or remove the toggle with a comment noting future feature
    - Decide based on whether `audioplayers` is already in pubspec
    - _Requirements: 2.20_

  - [x] 10.4 Fix "Customer notified!" SnackBar
    - Either invoke `restaurant_notification_service.dart` to send real notification
    - Or change message to "Order marked ready" (honest UX without false claim)
    - _Requirements: 2.21_

- [x] 11. Phase 2C — Accessibility

  - [x] 11.1 Add tooltips to KDS icon-only actions
    - In `kitchen_display_screen.dart` app bar actions
    - Add `tooltip: 'Toggle sound notifications'` to sound icon
    - Add `tooltip: 'Refresh orders'` to refresh icon (or replacement timestamp widget)
    - _Requirements: 2.22_

  - [x] 11.2 Write accessibility test
    - Verify all icon-only actions in KDS app bar have non-empty `tooltip` properties
    - Use `find.byType(IconButton)` and assert `tooltip` is not null/empty
    - _Requirements: 2.22_

- [x] 12. Phase 3 — Dead Code & Labels

  - [x] 12.1 Remove dead `'hotel'` branch from RestaurantGuard
    - In `lib/domain/guards/restaurant_guard.dart`, delete the `'hotel'` case that cannot be triggered by any valid `BusinessType` enum value
    - _Requirements: 2.23_

  - [x] 12.2 Relabel misleading sidebar items
    - In `sidebar_configuration.dart`, change "Ingredients Stock" → "Stock Dashboard"
    - Change "Profit & Loss" → "P&L Report"
    - Or point them to restaurant-aware variants if built in Phase 1B
    - _Requirements: 2.24_

  - [x] 12.3 Write guard and label tests
    - Test `RestaurantGuard.canAccess` does not accept `'hotel'` as valid type
    - Test sidebar labels match their navigation destinations accurately
    - _Requirements: 2.23, 2.24_

- [x] 13. Checkpoint - Ensure all tests pass
  - Run full test suite: exploration tests, preservation tests, unit tests, integration tests
  - Verify P0 tenant isolation test passes (bug fixed)
  - Verify preservation tests still pass (no regressions)
  - Verify all new feature tests pass (P1–P3)
  - Run `flutter analyze` on all touched files — zero warnings/errors
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Phase 0 (P0) is a surgical fix — only the vendorId value changes, no schema or API changes required
- Data migration (task 3.3) is required because existing Drift rows are stored with `vendorId = 'SYSTEM'`
- OrderType and UserRole enum additions are purely additive — no migration needed for local enums
- `RestaurantBusinessRules` utility functions are NOT modified — only their UI integration is new
- Preservation tests should be run BEFORE and AFTER each phase to catch regressions early
- The `?? 'SYSTEM'` fallback in the vendorId resolution is a dead-code safety net for corrupt session state

## Task Dependency Graph

```json
{
  "waves": [
    {
      "name": "Wave 1 - Exploration & Preservation Tests",
      "tasks": ["1", "2"],
      "description": "Write bug condition and preservation tests BEFORE any fix"
    },
    {
      "name": "Wave 2 - P0 Tenant Isolation Fix",
      "tasks": ["3.1", "3.2", "3.3"],
      "dependsOn": ["1", "2"],
      "description": "Critical fix: replace hardcoded vendorId with session-resolved value"
    },
    {
      "name": "Wave 3 - P0 Verification",
      "tasks": ["3.4", "3.5"],
      "dependsOn": ["3.1", "3.2", "3.3"],
      "description": "Verify exploration test passes and preservation tests still pass"
    },
    {
      "name": "Wave 4 - P1 Features (Parallel)",
      "tasks": ["4.1", "4.2", "4.3", "5.1", "5.2", "5.3", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "7.1", "7.2", "7.3", "8.1", "8.2", "8.3"],
      "dependsOn": ["3.4", "3.5"],
      "description": "Dashboard live data, orphaned screens, billing logic, OrderType, RBAC roles"
    },
    {
      "name": "Wave 5 - P2 Validation & UX",
      "tasks": ["9.1", "9.2", "9.3", "9.4", "10.1", "10.2", "10.3", "10.4", "11.1", "11.2"],
      "dependsOn": ["3.4", "3.5"],
      "description": "Input validation fixes, KDS performance/UX, accessibility"
    },
    {
      "name": "Wave 6 - P3 Cleanup",
      "tasks": ["12.1", "12.2", "12.3"],
      "dependsOn": ["3.4", "3.5", "5.1"],
      "description": "Dead code removal and misleading label fixes"
    },
    {
      "name": "Wave 7 - Final Checkpoint",
      "tasks": ["13"],
      "dependsOn": ["4.3", "5.3", "6.7", "7.3", "8.3", "9.4", "10.4", "11.2", "12.3"],
      "description": "Run full test suite and verify all phases complete"
    }
  ]
}
```
