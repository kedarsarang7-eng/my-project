# Bugfix Requirements Document

## Introduction

The Restaurant business vertical in DukanX has a critical tenant isolation bug and multiple high-severity defects spanning hardcoded fake data, unreachable screens, unwired billing logic, incomplete order-type modeling, and missing RBAC roles. This remediation addresses these issues in priority order (P0 → P3) across a phased, human-gated plan. The P0 bug causes data cross-contamination between restaurant tenants; the P1 issues render major features non-functional or invisible to users.

---

## Bug Analysis

### Current Behavior (Defect)

**P0 — Tenant Isolation Breach (Critical)**

1.1 WHEN a restaurant owner navigates to Table Management via the sidebar THEN the system constructs `TableManagementScreen(vendorId: 'SYSTEM')` instead of using the session's real `currentBusinessId`, causing all restaurant tenants to read/write a single shared data bucket

1.2 WHEN a restaurant owner navigates to Kitchen Display via the sidebar THEN the system constructs `KitchenDisplayScreen(vendorId: 'SYSTEM')`, making pending orders from all tenants visible to any restaurant user

1.3 WHEN a restaurant owner navigates to Menu Management via the sidebar THEN the system constructs `FoodMenuManagementScreen(vendorId: 'SYSTEM')`, causing menu items and categories to be shared across all tenants

1.4 WHEN a restaurant owner navigates to Daily Summary via the sidebar THEN the system constructs `RestaurantDailySummaryScreen(vendorId: 'SYSTEM')`, showing aggregated revenue and order data from all tenants rather than the logged-in business

**P1 — Dashboard Hardcoded Fake Data**

1.5 WHEN the dashboard `BusinessAlertsWidget` renders for a restaurant business type THEN the system displays hardcoded literal counts ("Active Orders": '7', "Kitchen Queue": '12', "Low Ingredients": '4') ignoring the `alertCountsProvider` entirely, misleading the owner with fabricated metrics

**P1 — Orphaned Screens (Unreachable from Navigation)**

1.6 WHEN a restaurant owner uses the sidebar navigation THEN the system provides no path to reach 11 existing restaurant screens (FloorManagementScreen, KotReportScreen, MenuItemManagementScreen, RecipeManagementScreen, RestaurantInventoryScreen, RestaurantOwnerCommandScreen, RestaurantPricingAdminScreen, RestaurantTableOpsScreen, RestaurantAggregatorReceiptScreen, RestaurantDeliveryOpsScreen, CustomerMenuScreen-standalone) despite these screens being built and functional on disk

**P1 — Unwired Billing Logic Fields**

1.7 WHEN a restaurant bill is created via `BillCreationScreenV2` THEN the system does not render the `isHalf` (half-portion) toggle despite it being declared in `BusinessTypeRegistry` config as an optional field

1.8 WHEN a restaurant bill is created via `BillCreationScreenV2` THEN the system does not render the `isParcel` flag despite it being declared in config as an optional field and a delivery-ops screen existing

1.9 WHEN a dine-in restaurant bill is finalized THEN the system never applies a service charge despite `RestaurantBusinessRules.serviceCharge(5%)` existing, the `Bill.serviceCharge` field existing, and the backend supporting `serviceChargeCents`

1.10 WHEN a restaurant owner wants to split a bill THEN the system provides no UI to invoke the split despite `RestaurantBusinessRules.splitBill` being implemented, tested, and having a backend endpoint (`restoSplitBill`)

1.11 WHEN a restaurant owner wants to apply happy-hour pricing THEN the system provides no mechanism despite `RestaurantBusinessRules.isInHappyHour` helper existing (only referenced in tests)

1.12 WHEN a restaurant owner wants to accept tips THEN the system provides no tip field anywhere in the billing flow

**P1 — Incomplete OrderType Enum**

1.13 WHEN a restaurant creates an order THEN the system only supports `OrderType.dineIn` and `OrderType.takeaway` in `food_order_model.dart`, despite config declaring `isParcel`, a delivery-ops screen existing, and the daily summary only bucketing dine-in vs takeaway

**P1 — Missing RBAC Roles**

1.14 WHEN `session_manager.dart` resolves a restaurant staff member's role THEN the system only maps to `manager`/`staff`(cashier→staff)/`accountant`/`owner` with no `waiter`, `chef`, or `captain` roles, despite `useWaiterLinking` capability being declared in the capability registry

**P2 — Input Validation Gaps**

1.15 WHEN a user enters a non-numeric value in the menu item price field THEN the system silently defaults to ₹0 via `double.tryParse(...) ?? 0` with no error feedback, creating zero-price menu items

1.16 WHEN a user bulk-adds tables with capacity/startNumber fields THEN the system silently falls back to defaults via `int.tryParse(...) ?? 4/1` with no upper bound or negative guard beyond the defaults

1.17 WHEN a user reorders categories via drag-and-drop THEN the system shows drag feedback but the new order is not persisted to the repository, silently discarding the change on reload

**P2 — Performance / UX Issues**

1.18 WHEN the Kitchen Display Screen renders with a live `StreamBuilder` THEN the system also shows a manual "Refresh" button that merely calls `setState((){})`, which is redundant and confusing since the stream auto-updates

1.19 WHEN the Kitchen Display Screen is displayed on a narrow or wide window THEN the system renders a fixed 3-column `Row` layout with no responsive fallback, causing cramped or underutilized space

1.20 WHEN a user toggles the sound setting in KDS THEN the system shows a SnackBar confirmation but no actual audio plays (no audio player is wired; `_soundEnabled` only gates a feedback SnackBar)

1.21 WHEN an order is marked "Ready" in KDS THEN the system shows "Customer notified!" SnackBar but no actual notification is dispatched (notification service exists but is not invoked)

**P2 — Accessibility Gaps**

1.22 WHEN the KDS sound/refresh icon-only actions render in the app bar THEN the system provides no `tooltip` (accessible name) for these actions, unlike the table screen which does provide tooltips

**P3 — Dead Code / Misleading Labels**

1.23 WHEN `RestaurantGuard.canAccess` evaluates access THEN the system accepts `'hotel'` as a valid type despite `'hotel'` not being a `BusinessType` enum value, creating dead unreachable code

1.24 WHEN the sidebar shows "Ingredients Stock" and "Profit & Loss" labels THEN the system navigates to the generic `InventoryDashboardScreen` and `PnlScreen` respectively, which have no restaurant-specific behavior despite the labels implying otherwise

---

### Expected Behavior (Correct)

**P0 — Tenant Isolation Fix**

2.1 WHEN a restaurant owner navigates to Table Management via the sidebar THEN the system SHALL resolve `vendorId` from `SessionManager.currentBusinessId` so tables are scoped to the authenticated tenant

2.2 WHEN a restaurant owner navigates to Kitchen Display via the sidebar THEN the system SHALL resolve `vendorId` from `SessionManager.currentBusinessId` so pending orders are scoped to the authenticated tenant

2.3 WHEN a restaurant owner navigates to Menu Management via the sidebar THEN the system SHALL resolve `vendorId` from `SessionManager.currentBusinessId` so menu items and categories are scoped to the authenticated tenant

2.4 WHEN a restaurant owner navigates to Daily Summary via the sidebar THEN the system SHALL resolve `vendorId` from `SessionManager.currentBusinessId` so revenue and order data reflect only the authenticated tenant

**P1 — Dashboard Live Data**

2.5 WHEN the dashboard `BusinessAlertsWidget` renders for a restaurant business type THEN the system SHALL source "Active Orders" and "Kitchen Queue" counts from a live data provider (e.g., `watchPendingOrders` length by status) and "Low Ingredients" from the existing `alertCountsProvider` low-stock count, displaying real-time values instead of hardcoded literals

**P1 — Orphaned Screen Navigation**

2.6 WHEN a restaurant owner uses the sidebar navigation THEN the system SHALL provide reachable paths to relevant orphaned screens (at minimum: FloorManagementScreen, KotReportScreen, RecipeManagementScreen, RestaurantDeliveryOpsScreen, RestaurantOwnerCommandScreen) via new sidebar items or sub-navigation, gated by appropriate capabilities

**P1 — Billing Logic Wiring**

2.7 WHEN a restaurant bill is created and the config `isHalf` optional field applies THEN the system SHALL render a half-portion toggle on bill line items that sets the `isHalf` flag on the line

2.8 WHEN a restaurant bill is created and the config `isParcel` optional field applies THEN the system SHALL render a parcel/takeaway flag on bill line items that sets the `isParcel` flag

2.9 WHEN a dine-in restaurant bill is finalized THEN the system SHALL apply the configured service charge percentage (default 5% or user-configurable) to the subtotal and include it in the bill total

2.10 WHEN a restaurant owner chooses to split a bill THEN the system SHALL provide a UI action that invokes `RestaurantBusinessRules.splitBill` and displays the split result to the user

2.11 WHEN a restaurant owner activates happy-hour pricing THEN the system SHALL apply `RestaurantBusinessRules.isInHappyHour` discount logic to eligible menu items during the configured time window

2.12 WHEN a restaurant bill is being finalized THEN the system SHALL provide an optional tip input field whose value is recorded on the bill

**P1 — OrderType Enum Completion**

2.13 WHEN a restaurant creates an order THEN the system SHALL support `delivery` and `parcel` in the `OrderType` enum in addition to `dineIn` and `takeaway`, and the daily summary SHALL bucket orders by all supported types

**P1 — RBAC Role Expansion**

2.14 WHEN `session_manager.dart` resolves restaurant staff roles THEN the system SHALL recognize `waiter`, `chef`, and `captain` roles with appropriate permission sets, enabling capability gating (e.g., `useWaiterLinking` bound to the waiter role, KDS restricted to chef/kitchen roles)

**P2 — Input Validation Fixes**

2.15 WHEN a user enters a non-numeric or invalid value in the menu item price field THEN the system SHALL display a validation error and prevent saving the item with ₹0 price

2.16 WHEN a user bulk-adds tables THEN the system SHALL validate that capacity is a positive integer ≤ reasonable bounds (e.g., 1–50) and startNumber is a positive integer, showing an error for invalid inputs

2.17 WHEN a user reorders categories via drag-and-drop THEN the system SHALL persist the new sort order to the repository so it survives reload

**P2 — Performance / UX Fixes**

2.18 WHEN the Kitchen Display Screen renders with a live StreamBuilder THEN the system SHALL remove or repurpose the redundant manual Refresh button (e.g., convert to a "last updated" timestamp indicator)

2.19 WHEN the Kitchen Display Screen is displayed THEN the system SHALL use a responsive layout that adapts columns to the available width (e.g., 1 column on narrow, 3+ on wide/wall displays)

2.20 WHEN a user toggles the sound setting in KDS THEN the system SHALL either play an actual audio notification on new orders or remove the sound toggle entirely to avoid misleading the user

2.21 WHEN an order is marked "Ready" in KDS THEN the system SHALL either invoke the notification service to actually notify the customer or remove the "Customer notified!" message

**P2 — Accessibility Fix**

2.22 WHEN the KDS app bar renders icon-only actions THEN the system SHALL provide `tooltip` properties with descriptive text (e.g., "Toggle sound notifications", "Refresh orders") for screen reader accessibility

**P3 — Dead Code / Label Cleanup**

2.23 WHEN `RestaurantGuard.canAccess` evaluates access THEN the system SHALL remove the dead `'hotel'` branch that cannot be triggered by any valid `BusinessType`

2.24 WHEN the sidebar displays "Ingredients Stock" and "Profit & Loss" labels THEN the system SHALL either (a) point them to restaurant-aware variants or (b) use generic labels ("Stock Dashboard", "P&L Report") that accurately describe the destination screens

---

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a non-restaurant business type (grocery, pharmacy, hardware, etc.) navigates via the sidebar THEN the system SHALL CONTINUE TO resolve screens using their existing logic with no changes to vendorId handling or screen construction

3.2 WHEN the `alertCountsProvider` is consumed by grocery, pharmacy, or hardware dashboard branches THEN the system SHALL CONTINUE TO source and display their respective live counts (lowStock, expiringSoon, hardware KPIs) with no behavioral change

3.3 WHEN a restaurant owner creates a standard bill via `BillCreationScreenV2` THEN the system SHALL CONTINUE TO apply the fixed 5% GST rate (non-editable) as configured in `BusinessTypeRegistry`

3.4 WHEN an existing `dineIn` or `takeaway` order is created THEN the system SHALL CONTINUE TO function with these order types identically to current behavior — no breaking change to existing enum consumers

3.5 WHEN `SessionManager` resolves roles for non-restaurant verticals (owner, manager, staff, accountant, pharmacist) THEN the system SHALL CONTINUE TO map and enforce permissions identically to current behavior

3.6 WHEN the generic common sidebar sections (Parties & Ledger, Reports & Analytics, System) render for restaurant THEN the system SHALL CONTINUE TO resolve to the same generic screens as before unless explicitly re-targeted in this remediation

3.7 WHEN `BusinessQuickActions` renders for restaurant (Table View, Kitchen Display, Menu Mgmt) THEN the system SHALL CONTINUE TO navigate to the correct sidebar item IDs with the same gating logic

3.8 WHEN the restaurant Drift repositories (`RestaurantTableRepository`, `FoodOrderRepository`, `FoodMenuRepository`, `RestaurantBillRepository`) are queried THEN the system SHALL CONTINUE TO use the same Drift-based local-first architecture with no schema-breaking changes to existing tables

3.9 WHEN `restaurant_sync_service.dart` performs cloud sync THEN the system SHALL CONTINUE TO operate with the same sync contract, only updating the vendorId key from 'SYSTEM' to the real tenant ID

3.10 WHEN the `RestaurantBusinessRules` utility functions (`splitBill`, `serviceCharge`, `isInHappyHour`) are called THEN the system SHALL CONTINUE TO return the same computed results — only their integration into UI is new, not their logic

3.11 WHEN sidebar items `new_sale`, `revenue_overview`, `sales_register`, `stock_summary`, `item_stock`, `low_stock` resolve for restaurant THEN the system SHALL CONTINUE TO navigate to their respective generic screens unchanged

3.12 WHEN the `modules/restaurant/routes/restaurant_routes.dart` GoRouter module exists THEN the system SHALL CONTINUE TO coexist without conflict — sidebar navigation is the primary path; module routes may be updated separately
