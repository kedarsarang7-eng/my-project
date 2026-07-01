# Restaurant Vertical Remediation — Bugfix Design

## Overview

The restaurant vertical in DukanX suffers from a critical tenant isolation breach (P0) where four screens hardcode `vendorId: 'SYSTEM'` instead of resolving the real business identity from `SessionManager.currentBusinessId`. This causes all restaurant tenants to share a single data bucket — a data-leakage and integrity risk in multi-tenant deployments.

Beyond P0, the vertical has five P1 defects (hardcoded fake dashboard data, 11 orphaned screens, unwired billing logic, incomplete `OrderType` enum, missing RBAC roles), three P2 defects (validation gaps, UX/performance issues, accessibility gaps), and two P3 cosmetic issues (dead code, misleading labels). The fix strategy is phased by priority: P0 is a surgical one-line-per-screen data-isolation fix, P1 involves model/enum extensions and UI wiring, P2 addresses validation and UX polish, and P3 cleans up dead branches.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the tenant isolation breach — any restaurant screen constructed via `SidebarNavigationHandler` receives the literal string `'SYSTEM'` as its `vendorId`, causing it to read/write a shared global data bucket instead of per-tenant data
- **Property (P)**: The desired behavior — restaurant screens SHALL resolve `vendorId` from `SessionManager.currentBusinessId` so data is scoped to the authenticated tenant
- **Preservation**: Existing behavior that must remain unchanged — non-restaurant verticals, generic sidebar items, existing Drift query APIs, sync contracts, and the `RestaurantBusinessRules` utility functions
- **`SidebarNavigationHandler`**: The shared `itemId → Widget` resolver in `lib/widgets/desktop/sidebar_navigation_handler.dart` — single source of truth for shell screen construction
- **`SessionManager.currentBusinessId`**: `activeBusinessId ?? userId` — the tenant-scoped identity the app already uses elsewhere for data isolation
- **`BusinessAlertsWidget`**: Dashboard V2 widget (`lib/features/dashboard/v2/widgets/business_alerts_widget.dart`) that shows per-vertical alert counts — restaurant branch currently hardcodes fake values
- **`OrderType`**: Enum in `lib/features/restaurant/data/models/food_order_model.dart` — currently only `dineIn` and `takeaway`
- **`UserRole`**: Enum in `lib/core/models/user_role.dart` — currently `owner`, `manager`, `staff`, `accountant`, `pharmacist`, `unknown`

## Bug Details

### Bug Condition

The bug manifests when a restaurant owner/staff member navigates to any of the 4 restaurant-specific sidebar items (`restaurant_tables`, `kitchen_display`, `menu_management`, `daily_summary`). The `SidebarNavigationHandler.tryGetScreenForItem` method constructs each screen widget with a hardcoded `vendorId: 'SYSTEM'` literal instead of resolving the real tenant identity from the session. These screens then pass `widget.vendorId` directly into Drift repository queries, meaning all tenants share one data partition.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type SidebarNavigationEvent
  OUTPUT: boolean
  
  RETURN input.itemId IN ['restaurant_tables', 'kitchen_display', 'menu_management', 'daily_summary']
         AND input.resolvedVendorId == 'SYSTEM'
         AND SessionManager.currentBusinessId != null
         AND SessionManager.currentBusinessId != 'SYSTEM'
END FUNCTION
```

### Examples

- **Table Management**: Owner of restaurant "Pizza Palace" (businessId: `usr_abc123`) navigates to Table Management → screen queries `watchTables('SYSTEM')` → sees tables created by "Burger Joint" (businessId: `usr_xyz789`) because both write to the `'SYSTEM'` bucket
- **Kitchen Display**: Chef at "Sushi Spot" opens KDS → `watchPendingOrders('SYSTEM')` → sees orders from all restaurants on the same device/installation
- **Menu Management**: Owner adds menu item "Paneer Tikka" → stored with `vendorId: 'SYSTEM'` → visible to every restaurant tenant's menu screen
- **Daily Summary**: Owner views daily revenue → `getOrdersByDate('SYSTEM', date)` → aggregates revenue from ALL tenants, showing inflated/incorrect numbers

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Non-restaurant business types (grocery, pharmacy, hardware, etc.) sidebar resolution remains identical — no code path changes
- `alertCountsProvider` consumed by grocery, pharmacy, hardware branches continues sourcing/displaying their respective live counts unchanged
- Restaurant `BillCreationScreenV2` continues applying fixed 5% GST (non-editable) as per `BusinessTypeRegistry` config
- Existing `dineIn` and `takeaway` `OrderType` enum values continue to function identically — no breaking change to existing consumers
- `SessionManager` role resolution for non-restaurant verticals (owner, manager, staff, accountant, pharmacist) remains unchanged
- Generic common sidebar sections (Parties & Ledger, Reports & Analytics, System) continue resolving to the same screens
- `BusinessQuickActions` restaurant quick actions (Table View, Kitchen Display, Menu Mgmt) continue navigating to the same sidebar item IDs
- Drift repositories (`RestaurantTableRepository`, `FoodOrderRepository`, `FoodMenuRepository`, `RestaurantBillRepository`) continue using Drift-based local-first architecture with no schema-breaking changes
- `restaurant_sync_service.dart` continues operating with the same sync contract — only the vendorId key changes from `'SYSTEM'` to real tenant ID
- `RestaurantBusinessRules` utility functions (`splitBill`, `serviceCharge`, `isInHappyHour`) continue returning the same computed results — only their UI integration is new

**Scope:**
All inputs that do NOT involve restaurant sidebar navigation or restaurant-specific features should be completely unaffected by this fix. This includes:
- All other business vertical sidebar items and screen construction
- Generic billing, inventory, parties, and reports screens
- Cloud sync for non-restaurant entities
- Authentication/session management flows

## Hypothesized Root Cause

Based on the bug description and code analysis, the confirmed root causes are:

1. **Hardcoded `vendorId` in SidebarNavigationHandler (P0)**: Lines 375–383 of `sidebar_navigation_handler.dart` construct all four restaurant screens with the literal `vendorId: 'SYSTEM'`. This was likely a development placeholder that was never replaced with the proper session-resolved identity. The `SessionManager.currentBusinessId` getter already exists and is used by other verticals — the restaurant branch simply never adopted it.

2. **Hardcoded counts in BusinessAlertsWidget (P1)**: The restaurant `case` branch in `_buildAlertsForBusiness` uses literal strings `'7'`, `'12'`, `'4'` instead of querying a live data source. Unlike the grocery branch (which reads from `counts['lowStock']`/`counts['expiringSoon']`) and the hardware branch (which uses `hardwareKpisProvider`), the restaurant branch was never wired to real data. No provider for active-order/kitchen-queue counts exists yet.

3. **Orphaned screens never registered in sidebar config (P1)**: 11 restaurant screens exist under `features/restaurant/presentation/screens/` but were never added to `_getRestaurantSections()` in `sidebar_configuration.dart` or registered in `SidebarNavigationHandler`. These are fully built screens that simply lack navigation entry points.

4. **Billing UI ignores BusinessTypeRegistry optional fields (P1)**: `bill_line_item_row.dart` renders `showTableNo` for restaurant context but never reads `isHalf`/`isParcel` from the config's `optionalFields`. The service charge, split bill, happy-hour, and tips logic all exist in `RestaurantBusinessRules` and `Bill` model but have no UI affordances in `BillCreationScreenV2`.

5. **OrderType enum incomplete (P1)**: `food_order_model.dart` declares only `dineIn('DINE_IN')` and `takeaway('TAKEAWAY')` with a `fromString` fallback to `dineIn`. The `BusinessTypeRegistry` config declares `isParcel` as an optional field and `RestaurantDeliveryOpsScreen` exists, but the enum cannot represent delivery or parcel orders.

6. **UserRole enum missing restaurant-specific roles (P1)**: The enum defines `owner`, `manager`, `staff`, `accountant`, `pharmacist`, `unknown`. There are no `waiter`, `chef`, or `captain` roles. The capability registry declares `useWaiterLinking` but the role it requires doesn't exist.

7. **Silent validation fallbacks (P2)**: `double.tryParse(...) ?? 0` and `int.tryParse(...) ?? 4` patterns silently produce invalid data (₹0 price items, default capacity) with no user feedback.

## Correctness Properties

Property 1: Bug Condition - Tenant Isolation via vendorId Resolution

_For any_ sidebar navigation event where `itemId` is one of `['restaurant_tables', 'kitchen_display', 'menu_management', 'daily_summary']` and `SessionManager.currentBusinessId` is non-null, the fixed `SidebarNavigationHandler` SHALL construct the screen with `vendorId` equal to `SessionManager.currentBusinessId`, never the literal `'SYSTEM'`.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

Property 2: Preservation - Non-Restaurant Sidebar Resolution Unchanged

_For any_ sidebar navigation event where `itemId` is NOT one of the four restaurant-specific items, the fixed `SidebarNavigationHandler` SHALL produce exactly the same screen widget as the original code, preserving all existing navigation for every other vertical and generic screen.

**Validates: Requirements 3.1, 3.6, 3.7, 3.11**

Property 3: Dashboard Alerts - Restaurant Live Data

_For any_ dashboard render where `businessType == BusinessType.restaurant`, the fixed `BusinessAlertsWidget` SHALL display alert counts sourced from live data providers (active orders count from `watchPendingOrders`, kitchen queue from order status filtering, low ingredients from `alertCountsProvider`), never hardcoded literal values.

**Validates: Requirements 2.5**

Property 4: OrderType Enum Completeness

_For any_ order creation with type string `'DELIVERY'` or `'PARCEL'`, the fixed `OrderType.fromString` SHALL return the corresponding enum value (`OrderType.delivery` or `OrderType.parcel`), and `OrderType.values` SHALL contain exactly 4 members.

**Validates: Requirements 2.13**

Property 5: Input Validation - Price Field

_For any_ menu item creation where the price input is non-numeric, negative, or zero, the fixed validation logic SHALL reject the input with a user-visible error message and prevent saving, never silently defaulting to ₹0.

**Validates: Requirements 2.15**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

---

### Phase 0 — P0: Tenant Isolation Fix (Critical)

**File**: `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart`

**Function**: `tryGetScreenForItem` — restaurant case block (lines 375–383)

**Specific Changes**:
1. **Resolve vendorId from session**: Replace all four `vendorId: 'SYSTEM'` literals with a call to `sl<SessionManager>().currentBusinessId!`
2. **Null safety**: Add a defensive fallback — if `currentBusinessId` is null (should never happen for an authenticated user), log a warning and fall back to `userId` (same pattern `currentBusinessId` getter uses internally)
3. **Remove 'SYSTEM' constant entirely**: No restaurant screen should ever receive the literal `'SYSTEM'`

**Implementation pattern** (same for all 4 cases):
```dart
case 'restaurant_tables':
  final vendorId = sl<SessionManager>().currentBusinessId ?? sl<SessionManager>().userId ?? 'SYSTEM';
  return TableManagementScreen(vendorId: vendorId);
```

> **Note**: The `?? 'SYSTEM'` tail is a dead-code safety net — an authenticated user always has a `currentBusinessId`. It prevents a null crash if session state is somehow corrupt.

4. **Module routes parity**: Also fix `modules/restaurant/routes/restaurant_routes.dart` which repeats the same `vendorId: 'SYSTEM'` for `/restaurant/menu`.

---

### Phase 1A — P1: Dashboard Live Data

**File**: `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart`

**Specific Changes**:
1. **Create `restaurantAlertCountsProvider`**: A new `StreamProvider` that watches `FoodOrderRepository.watchPendingOrders(currentBusinessId)` and computes:
   - "Active Orders" = orders with status IN [`accepted`, `cooking`, `ready`, `served`]
   - "Kitchen Queue" = orders with status IN [`pending`, `accepted`] (not yet cooking)
   - "Low Ingredients" = reuse existing `alertCountsProvider` `lowStock` count
2. **Replace hardcoded restaurant branch**: Wire the restaurant `case` in `_buildAlertsForBusiness` to consume the new provider's live counts (same pattern as hardware/mandi branches)

---

### Phase 1B — P1: Orphaned Screen Navigation

**File**: `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart`

**Function**: `_getRestaurantSections()`

**Specific Changes**:
1. **Add new sidebar section "Advanced Operations"** with items for: `floor_management`, `kot_report`, `recipe_management`, `delivery_ops`, `restaurant_command_center`
2. **Gate items by capabilities**: `floor_management` gated by `useTableManagement`, `delivery_ops` gated by new capability or always-visible, `kot_report` gated by `useKOT`

**File**: `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart`

**Specific Changes**:
3. **Register new case entries**: Add `case 'floor_management'`, `case 'kot_report'`, etc., mapping to the corresponding orphaned screen widgets (with proper `vendorId` from session)
4. **Import the orphaned screen files** at the top of the handler

---

### Phase 1C — P1: Billing Logic Wiring

**File**: `Dukan_x/lib/features/billing/presentation/screens/bill_creation_screen_v2.dart`

**Specific Changes**:
1. **Half-portion toggle**: Add `isHalf` toggle on each bill line item when `businessType == restaurant` and config includes `isHalf` in `optionalFields`
2. **Parcel flag**: Add `isParcel` chip/toggle per line item under same conditions
3. **Service charge input**: Add a service charge row in the bill totals section for dine-in restaurant bills, defaulting to 5% via `RestaurantBusinessRules.serviceCharge(subtotal)`, user-adjustable
4. **Split bill action**: Add an action button "Split Bill" that opens a dialog accepting split count, invokes `RestaurantBusinessRules.splitBill(total, count)`, and displays per-guest amounts
5. **Happy-hour pricing**: When `RestaurantBusinessRules.isInHappyHour(...)` returns true for the configured window, auto-apply discount (requires happy-hour config — hourStart/hourEnd from business settings)
6. **Tip input**: Add an optional "Tip" field in the payment section, stored in `Bill.tipAmount` (new field or reuse metadata)

---

### Phase 1D — P1: OrderType Enum Completion

**File**: `Dukan_x/lib/features/restaurant/data/models/food_order_model.dart`

**Specific Changes**:
1. **Add enum values**: `delivery('DELIVERY')` and `parcel('PARCEL')` to `OrderType`
2. **Update `fromString`**: Ensure `'DELIVERY'` and `'PARCEL'` resolve correctly (the existing `firstWhere` with fallback handles this automatically once the values exist)
3. **Update daily summary**: Modify `RestaurantDailySummaryScreen._processOrders` to bucket by all 4 order types

**Migration note**: Existing database rows only contain `'DINE_IN'`/`'TAKEAWAY'` strings — `fromString` fallback to `dineIn` means old data continues to parse without migration.

---

### Phase 1E — P1: RBAC Role Expansion

**File**: `Dukan_x/lib/core/models/user_role.dart`

**Specific Changes**:
1. **Add enum values**: `waiter`, `chef`, `captain` to `UserRole`
2. **Update `RolePermissions`**: Define permission sets for each new role (waiter: create orders, view tables; chef: view KDS, update order status; captain: all waiter + assign tables + view reports)

**File**: `Dukan_x/lib/core/session/session_manager.dart`

**Specific Changes**:
3. **Update role string mapping**: Add `'waiter'`, `'chef'`, `'captain'` cases in `_loadUserSession` role switch
4. **Update `resolveFallbackStaffRole`**: Add the new roles to the "preserve, do NOT escalate" branch

---

### Phase 2A — P2: Input Validation

**File**: `Dukan_x/lib/features/restaurant/presentation/screens/food_menu_management_screen.dart`

**Specific Changes**:
1. **Price validation**: Replace `double.tryParse(v) ?? 0` with proper validation — if parse fails or value ≤ 0, show `FormField` error text and disable save button
2. **Category assignment**: Warn (not block) if no category is selected

**File**: `Dukan_x/lib/features/restaurant/presentation/screens/table_management_screen.dart`

**Specific Changes**:
3. **Capacity bounds**: Validate 1 ≤ capacity ≤ 50, show error for out-of-range
4. **Start number bounds**: Validate startNumber ≥ 1, show error for invalid

**File**: `Dukan_x/lib/features/restaurant/presentation/screens/food_menu_management_screen.dart`

**Specific Changes**:
5. **Category reorder persistence**: After `onReorder`, call repository method to persist the new sort indices

---

### Phase 2B — P2: KDS Performance & UX

**File**: `Dukan_x/lib/features/restaurant/presentation/screens/kitchen_display_screen.dart`

**Specific Changes**:
1. **Remove/repurpose Refresh button**: Replace with a "Last updated: X" timestamp indicator since the `StreamBuilder` is live
2. **Responsive layout**: Replace fixed 3-column `Row` with a `LayoutBuilder` that uses 1 column on narrow (<600px), 2 on medium, 3+ on wide
3. **Sound toggle**: Either wire `audioplayers` package to play a notification sound on new orders, or remove the toggle entirely with a comment noting it's a future feature
4. **"Customer notified!" SnackBar**: Either invoke `restaurant_notification_service.dart` to send a real push/SMS, or change the message to "Order marked ready" (honest UX)

---

### Phase 2C — P2: Accessibility

**File**: `Dukan_x/lib/features/restaurant/presentation/screens/kitchen_display_screen.dart`

**Specific Changes**:
1. **Add tooltips**: Add `tooltip: 'Toggle sound notifications'` and `tooltip: 'Refresh orders'` to the icon-only app bar actions

---

### Phase 3 — P3: Dead Code & Labels

**File**: `Dukan_x/lib/domain/guards/restaurant_guard.dart`

**Specific Changes**:
1. **Remove `'hotel'` branch**: Delete the dead `'hotel'` case that cannot be triggered by any valid `BusinessType` enum value

**File**: `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart`

**Specific Changes**:
2. **Relabel misleading items**: Change "Ingredients Stock" → "Stock Dashboard" and "Profit & Loss" → "P&L Report" (or point to restaurant-aware variants if built in Phase 1B)

---

### Data Model Changes

**OrderType enum** (additive — no migration required):
```dart
enum OrderType {
  dineIn('DINE_IN'),
  takeaway('TAKEAWAY'),
  delivery('DELIVERY'),
  parcel('PARCEL');
  // ...
}
```

**UserRole enum** (additive — no migration required for local enum, Firestore role strings just need the new cases in the switch):
```dart
enum UserRole { owner, manager, staff, accountant, pharmacist, waiter, chef, captain, unknown }
```

**No Drift schema changes required for P0** — the `vendorId` column already exists in all restaurant tables; only the value passed at query time changes.

---

### Migration Strategy for vendorId Fix (P0)

**Problem**: Existing restaurant data is stored with `vendorId = 'SYSTEM'`. After the fix, screens will query with the real `currentBusinessId`, returning empty results.

**Strategy**:
1. **One-time data migration on app launch**: After the fix deploys, run a migration that:
   - Queries all rows in `restaurant_tables`, `food_orders`, `food_menu_items`, `food_menu_categories` where `vendorId == 'SYSTEM'`
   - Updates them to `vendorId = SessionManager.currentBusinessId`
   - Only runs for the currently logged-in user (single-device local-first architecture means each device has one owner's data)
2. **Migration guard**: Track migration completion via `SharedPreferences` key `'restaurant_vendorid_migrated'` so it runs once per installation
3. **Sync contract update**: `restaurant_sync_service.dart` must use the real `vendorId` for cloud sync keys going forward — any cloud-side records keyed `'SYSTEM'` need a corresponding cloud migration (separate backend task)

**Risk**: If multiple tenants genuinely shared a device (unlikely in production but possible in demo), the migration would assign ALL `'SYSTEM'` records to whichever user logs in first. Mitigation: add `createdBy` audit field to Drift tables in a future release for proper attribution.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write widget tests that construct restaurant screens via `SidebarNavigationHandler.tryGetScreenForItem` and assert the `vendorId` property on the returned widget. Run these tests on the UNFIXED code to observe failures.

**Test Cases**:
1. **Tenant Isolation Test**: Call `tryGetScreenForItem('restaurant_tables', context)` → inspect returned `TableManagementScreen.vendorId` → expect real businessId, actual is `'SYSTEM'` (will fail on unfixed code)
2. **Dashboard Fake Data Test**: Render `BusinessAlertsWidget` with `businessType == restaurant` → find Text widgets → expect dynamic values, actual is literal `'7'`/`'12'`/`'4'` (will fail on unfixed code)
3. **OrderType Completeness Test**: Call `OrderType.fromString('DELIVERY')` → expect `OrderType.delivery`, actual falls back to `dineIn` (will fail on unfixed code)
4. **RBAC Role Test**: Attempt to parse `'waiter'` in SessionManager role switch → expect `UserRole.waiter`, actual falls to `unknown` (will fail on unfixed code)

**Expected Counterexamples**:
- `TableManagementScreen.vendorId == 'SYSTEM'` for any authenticated user
- Dashboard shows static text "7" regardless of actual order count
- `OrderType.fromString('DELIVERY') == OrderType.dineIn` (incorrect fallback)
- Possible causes: hardcoded literals, missing enum values, missing role mapping

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := SidebarNavigationHandler_fixed.tryGetScreenForItem(input.itemId, context)
  ASSERT result.vendorId == SessionManager.currentBusinessId
  ASSERT result.vendorId != 'SYSTEM'
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT SidebarNavigationHandler_original(input) == SidebarNavigationHandler_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the full set of sidebar item IDs
- It catches edge cases where an unrelated item might accidentally match a new code path
- It provides strong guarantees that behavior is unchanged for all non-restaurant sidebar items

**Test Plan**: Catalog all existing sidebar item IDs (23+ for restaurant, plus generic/common items), observe their resolution on UNFIXED code, then write property-based tests asserting identical resolution on FIXED code.

**Test Cases**:
1. **Generic Sidebar Preservation**: For every non-restaurant sidebar item (`new_sale`, `stock_summary`, etc.), verify the same widget type is returned before and after the fix
2. **GST Rate Preservation**: Verify that restaurant bills still apply fixed 5% GST non-editable
3. **Business Rules Preservation**: Verify `RestaurantBusinessRules.splitBill` and `.serviceCharge` return identical values (their logic isn't changing, only their UI integration)
4. **Drift Query API Preservation**: Verify that `watchTables(vendorId)` accepts and filters by any string vendorId — the query itself is correct, only the value passed changes

### Unit Tests

- Test `SidebarNavigationHandler.tryGetScreenForItem` returns correct widget types with correct `vendorId` for all restaurant items
- Test `OrderType.fromString` for all 4 valid strings + invalid inputs
- Test `UserRole` parsing for new roles (`waiter`, `chef`, `captain`)
- Test `RestaurantBusinessRules` functions are still pure and unchanged
- Test menu item price validation rejects non-numeric, zero, and negative inputs
- Test table capacity validation enforces 1–50 bounds

### Property-Based Tests

- Generate random sidebar item IDs from the full known set and verify resolution consistency before/after fix
- Generate random `vendorId` strings and verify Drift query correctly filters (repository layer)
- Generate random order type strings and verify `OrderType.fromString` handles all known and unknown values correctly
- Generate random subtotals and verify service charge calculation consistency

### Integration Tests

- Full flow: login → navigate to Table Management → verify data is scoped to logged-in business only
- Full flow: create menu item → verify `vendorId` stored in Drift matches session businessId
- Full flow: create order → mark ready in KDS → verify dashboard alert counts update
- Full flow: navigate to each of the 5 newly-wired orphaned screens → verify no crash, correct data scope
- Full flow: split bill via new UI → verify amounts sum to original total
