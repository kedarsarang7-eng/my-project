# Production Crash & UI Fixes — Bugfix Design

## Overview

This design addresses 18 production bugs across DukanX (a multi-tenant Flutter desktop/mobile app). The bugs span four severity tiers: Phase 0 crashes (unregistered GetIt services and null-check failures), Phase 1 layout regressions (text wrapping one letter per line), Phase 2 recurring UI defects (black backgrounds, status bar overlap, ₹ mojibake, overlapping cards, stuck loading overlay), and Phase 3 cosmetic truncation. The fix strategy is minimal and targeted: register missing services, add null guards, wrap text in flex constraints, provide Scaffold/SafeArea where absent, fix encoding, and adjust layout constraints.

## Glossary

- **Bug_Condition (C)**: The set of navigation/render states that trigger one of the 18 defects
- **Property (P)**: The desired correct behavior — no crash, proper layout, correct encoding
- **Preservation**: All existing functionality unrelated to the bug conditions must remain unchanged
- **GetIt / sl**: The global service locator (`GetIt.instance`) used for dependency injection
- **DesktopContentContainer**: A shared content wrapper widget (not a Scaffold) that provides max-width constraints, scrolling, and a header bar
- **SessionManager**: The single source of auth/session state; `userId` is nullable before sign-in completes
- **DunningService**: Automated payment reminder service in `lib/core/billing/dunning_service.dart`
- **PaymentGatewayApiService**: Desktop ↔ backend payment gateway integration in `lib/features/payment/services/payment_gateway_api_service.dart`

## Bug Details

### Bug Condition

The bugs manifest across four distinct condition classes:

1. **Service Resolution Crash**: When navigating to Dunning Configuration or Payment Gateway Settings screens, `sl<DunningService>()` / `sl<PaymentGatewayApiService>()` throws because neither service is registered in `service_locator.dart`.

2. **Null-Check Crash**: When navigating to Data Import/Export or Database Management screens before session initialization completes, accessing nullable session properties via `!` operator crashes.

3. **Layout/Rendering Defects**: When specific screens render their widget trees, missing Scaffold `backgroundColor`, absent SafeArea, unconstrained Text in Row, incorrect string encoding, or stale loading state produce visual defects.

4. **Cosmetic Truncation**: When dropdown labels render in constrained containers without overflow handling.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type NavigationEvent | RenderEvent
  OUTPUT: boolean

  // Phase 0 — Crashes
  IF input.targetScreen IN ['DunningConfigScreen', 'PaymentGatewaySettingsScreen']
     AND NOT sl.isRegistered(input.requiredServiceType)
     RETURN true

  IF input.targetScreen IN ['DataImportExportScreen', 'DatabaseManagementScreen']
     AND SessionManager.userId == null
     RETURN true

  // Phase 1 — Text wrapping
  IF input.targetScreen IN ['BuyFlowDashboard', 'StockEntryScreen',
     'StockReversalScreen', 'NewPurchaseOrderScreen']
     AND input.hasTextInRowWithoutFlexConstraint
     RETURN true

  // Phase 2 — Visual defects
  IF input.targetScreen IN ['SettingsScreen', 'FinancialReportsScreen',
     'DataImportExportScreen', 'DatabaseManagementScreen']
     AND (input.scaffoldMissingBackgroundColor OR input.missingSafeArea)
     RETURN true

  IF input.targetScreen == 'NewPurchaseOrderScreen'
     AND input.rupeeLiteralIsNotUTF8
     RETURN true

  IF input.targetScreen == 'DashboardScreen'
     AND input.cardsUseFixedWidthLayout
     RETURN true

  IF input.targetScreen == 'InventoryScreen'
     AND input.loadingOverlayNotDismissed
     RETURN true

  // Phase 3 — Truncation
  IF input.targetScreen == 'NewPurchaseOrderScreen'
     AND input.dropdownLabelConstrainedWithoutOverflow
     RETURN true

  RETURN false
END FUNCTION
```

### Examples

- **Bug 1.1**: User navigates to Dunning Configuration → `sl<DunningService>()` throws `StateError("Object/factory with type DunningService is not registered inside GetIt")` → app crashes
- **Bug 1.3**: User opens Data Import/Export before login completes → `SessionManager.userId!` is null → throws `Null check operator used on a null value`
- **Bug 1.5**: BuyFlow Dashboard stat card renders ₹12,500 in a narrow Row → text wraps as `₹\n1\n2\n,\n5\n0\n0` (one char per line)
- **Bug 1.9**: Settings screen opens → black background because no `backgroundColor` is set on the Scaffold
- **Bug 1.14**: Purchase order shows "â‚¹" instead of "₹" due to byte-level string construction

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- All screens where services ARE properly registered in GetIt continue to resolve services normally
- Signed-in users accessing Data Import/Export and Database Management see full functionality unchanged
- Text widgets already wrapped in Expanded/Flexible continue rendering correctly
- Screens with existing Scaffold `backgroundColor` and SafeArea continue rendering correctly
- The ₹ symbol on billing/invoice screens (already correct) remains unchanged
- Dashboard cards that are already responsive continue without overlap
- Inventory screen empty-state UI continues to work
- Dropdown labels with sufficient container space remain full-width
- All 19+ dashboards continue to navigate without exceptions

**Scope:**
All inputs that do NOT match the bug conditions above should be completely unaffected by the fix. This includes:
- Navigation to screens with already-registered services
- Session-dependent screens accessed after successful sign-in
- Text widgets already inside Expanded/Flexible containers
- Screens that already use Scaffold with backgroundColor and SafeArea

## Hypothesized Root Cause

Based on code analysis and the bug descriptions:

1. **Unregistered Services (Bugs 1.1, 1.2)**: `DunningService` and `PaymentGatewayApiService` were implemented but never added to `initializeDependencies()` in `service_locator.dart`. Their screen widgets call `sl<DunningService>()` / `sl<PaymentGatewayApiService>()` which throws at runtime.

2. **Null-Check Without Guard (Bugs 1.3, 1.4)**: The `DataImportExportScreen` uses `sl<SessionManager>().userId ?? ''` (safe) but the screen that hosts it (or a related provider/route guard) may use `userId!` without null-safety. The `DatabaseManagementScreen` similarly accesses session state without a null guard at the navigation layer.

3. **Text in Row Without Flex Constraint (Bugs 1.5–1.8)**: A `Text` widget placed directly inside a `Row` (or nested inside a Row child that doesn't constrain width) receives near-zero intrinsic width from the Row's layout algorithm, causing each character to wrap to a new line. The fix is wrapping in `Expanded` or `Flexible` with `TextOverflow.ellipsis`.

4. **Missing Scaffold backgroundColor (Bugs 1.9–1.12)**: The affected screens use `DesktopContentContainer` as their root widget but are hosted inside a route that either has no `Scaffold` or has a `Scaffold` without explicit `backgroundColor`. Flutter defaults to `ThemeData.scaffoldBackgroundColor` — but if the screen is pushed as a full-page route without a Scaffold wrapper, the background defaults to black (the Canvas default).

5. **Missing SafeArea (Bug 1.13)**: The same screens lack SafeArea wrapping, so on mobile the system status bar (time, battery) overlaps the content header.

6. **Mojibake (Bug 1.14)**: The ₹ symbol is constructed via byte concatenation or a non-UTF-8 string literal (e.g., `String.fromCharCodes([0xE2, 0x82, 0xB9])` interpreted as Latin-1 instead of UTF-8). Should use the Unicode literal `'₹'` or `'\u20B9'` directly.

7. **Overlapping Dashboard Cards (Bug 1.15)**: "Recent Transactions" and "Tax Summary" cards use `Row` with fixed-width children instead of `Wrap` or responsive flex, causing overlap on narrow viewports.

8. **Stuck Loading Overlay (Bug 1.16)**: The inventory screen sets `_isLoading = true` but never sets it to `false` in the error/empty path of the data fetch, leaving the overlay permanently visible.

9. **Truncated Dropdown Labels (Bugs 1.17, 1.18)**: DropdownButton labels ("Vendor Details", "Payment Info") are inside a `SizedBox` or container with a hard-coded width that is too narrow for the text, causing ellipsis at "Ven..." / "Pai...".

## Correctness Properties

Property 1: Bug Condition - Service Registration Prevents Crash

_For any_ navigation event where the target screen resolves `DunningService` or `PaymentGatewayApiService` from GetIt, the fixed `initializeDependencies()` SHALL have registered both services as lazy singletons so that `sl<DunningService>()` and `sl<PaymentGatewayApiService>()` return valid instances without throwing.

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition - Null-Safe Session Access

_For any_ navigation event where the target screen is Data Import/Export or Database Management and `SessionManager.userId` is null, the fixed screen SHALL gracefully handle the null state by showing fallback UI or a "Please sign in" message, without crashing.

**Validates: Requirements 2.3, 2.4**

Property 3: Bug Condition - Text Layout Correctness

_For any_ render event where a Text widget is inside a Row in the affected screens (BuyFlow Dashboard, Stock Entry, Stock Reversal, New Purchase Order), the fixed layout SHALL wrap the Text in Expanded/Flexible with TextOverflow.ellipsis, ensuring the text never wraps one character per line.

**Validates: Requirements 2.5, 2.6, 2.7, 2.8**

Property 4: Bug Condition - Scaffold Background and SafeArea

_For any_ render event on Settings, Financial Reports, Data Import/Export, or Database Management screens, the fixed screens SHALL render with the theme-appropriate background color and position content below the system status bar using SafeArea or AppBar.

**Validates: Requirements 2.9, 2.10, 2.11, 2.12, 2.13**

Property 5: Bug Condition - Rupee Symbol Encoding

_For any_ render event on the New Purchase Order screen displaying currency amounts, the fixed code SHALL render the correct Unicode rupee sign (₹, U+20B9) without mojibake.

**Validates: Requirements 2.14**

Property 6: Bug Condition - Dashboard Card Layout

_For any_ viewport width on the main Dashboard, the fixed layout SHALL arrange "Recent Transactions" and "Tax Summary" cards responsively so they never visually overlap.

**Validates: Requirements 2.15**

Property 7: Bug Condition - Loading Overlay Dismissal

_For any_ data fetch completion (success, error, or empty result) on the Inventory screen, the fixed code SHALL dismiss the loading overlay immediately, restoring full interactivity.

**Validates: Requirements 2.16**

Property 8: Bug Condition - Dropdown Label Readability

_For any_ render event on the New Purchase Order screen, the "Vendor Details" and "Payment Info" dropdown labels SHALL be fully readable (not truncated) by using sufficient width or overflow handling.

**Validates: Requirements 2.17, 2.18**

Property 9: Preservation - Existing Functionality

_For any_ input where the bug condition does NOT hold (already-registered services, signed-in users, correctly-wrapped text, screens with existing Scaffold/SafeArea, correct ₹ encoding elsewhere, responsive cards, properly-dismissed overlays, full-width labels), the fixed code SHALL produce the same result as the original code, preserving all existing behavior.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10**

## Fix Implementation

### Changes Required

**File**: `lib/core/di/service_locator.dart`

**Changes**:
1. **Register DunningService**: Add `sl.registerLazySingleton<DunningService>(() => DunningService(db: sl<AppDatabase>(), billsRepo: sl<BillsRepository>(), customersRepo: sl<CustomersRepository>(), whatsAppService: sl<WhatsAppService>()))` in the services section.
2. **Register PaymentGatewayApiService**: Add `sl.registerLazySingleton<PaymentGatewayApiService>(() => PaymentGatewayApiService(sl<ApiClient>()))` in the payment services section.

---

**File**: `lib/features/settings/presentation/screens/data_import_export_screen.dart`

**Changes**:
3. **Add null guard for userId**: The screen already uses `?? ''` for userId. Verify the hosting route or provider doesn't use `!`. If the screen is accessed before session init, add an early-return widget showing "Please sign in" when `_userId.isEmpty` at build time.
4. **Wrap in Scaffold with backgroundColor**: Wrap the `DesktopContentContainer` in a `Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: SafeArea(child: ...))`.

---

**File**: `lib/features/settings/presentation/screens/database_management_screen.dart`

**Changes**:
5. **Add null-safe session access**: Guard any nullable session property access; show fallback UI if session is not ready.
6. **Wrap in Scaffold with backgroundColor and SafeArea**: Same pattern as Data Import/Export.

---

**File**: `lib/features/settings/presentation/screens/main_settings_screen.dart`

**Changes**:
7. **Wrap in Scaffold with backgroundColor and SafeArea**: Ensure Scaffold provides `backgroundColor: Theme.of(context).scaffoldBackgroundColor` and content is wrapped in SafeArea.

---

**File**: Financial Reports screen (likely `lib/features/accounting/` or `lib/features/academic_coaching/presentation/screens/ac_financial_reports_screen.dart`)

**Changes**:
8. **Wrap in Scaffold with backgroundColor and SafeArea**: Same pattern.

---

**File**: `lib/features/buy_flow/screens/buy_flow_dashboard.dart`

**Changes**:
9. **Fix text wrapping in stat cards**: Inside `_buildSummaryCard`, ensure the value `Text` and title `Text` widgets handle overflow. Since cards are already in `Expanded` within the outer Row, the issue is likely that the Text widgets inside the card's internal Column/Row need `maxLines: 1` and `overflow: TextOverflow.ellipsis` to prevent vertical wrapping on very narrow cards.

---

**File**: `lib/features/buy_flow/screens/stock_entry_screen.dart`

**Changes**:
10. **Wrap Text in Expanded/Flexible**: Find Row children containing "Total"/"Due" labels and wrap the Text in Expanded with TextOverflow.ellipsis.

---

**File**: `lib/features/buy_flow/screens/stock_reversal_screen.dart`

**Changes**:
11. **Wrap Text in Expanded/Flexible**: Find the info banner Row and wrap the Text in Expanded with TextOverflow.ellipsis.

---

**File**: New Purchase Order screen (likely in `lib/features/purchase/` or `lib/features/buy_flow/`)

**Changes**:
12. **Wrap Text in Expanded/Flexible**: Fix vendor sidebar and "No items added" empty state text.
13. **Fix ₹ mojibake**: Replace byte-level rupee construction with `'₹'` Unicode literal or `'\u20B9'` or use `CurrencyService.symbol`.
14. **Fix dropdown label truncation**: Increase container width or remove hard-coded width constraint from "Vendor Details" and "Payment Info" dropdown wrappers; use `isExpanded: true` on DropdownButton.

---

**File**: Main Dashboard screen (likely `lib/screens/` or `lib/features/dashboard/`)

**Changes**:
15. **Fix overlapping cards**: Replace `Row` with fixed-width children with a `Wrap` or responsive `LayoutBuilder`-based layout for "Recent Transactions" and "Tax Summary" cards.

---

**File**: Inventory screen (the one with a loading overlay)

**Changes**:
16. **Fix stuck loading overlay**: Ensure `setState(() => _isLoading = false)` is called in all code paths — success, error, and empty. Add it to the `finally` block of the data fetch.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write widget tests and unit tests that exercise each bug condition on the UNFIXED code to observe failures and confirm root causes.

**Test Cases**:
1. **GetIt Resolution Test**: Call `sl<DunningService>()` and `sl<PaymentGatewayApiService>()` after `initializeDependencies()` — will throw StateError on unfixed code
2. **Null Session Navigation Test**: Navigate to DataImportExportScreen with `SessionManager.userId == null` — will crash on unfixed code
3. **Text Layout Golden Test**: Render BuyFlowDashboard stat cards in a 320px-wide viewport — text will wrap vertically on unfixed code
4. **Scaffold Background Test**: Build Settings screen and check `Scaffold.of(context).widget.backgroundColor` — will be null on unfixed code

**Expected Counterexamples**:
- `sl<DunningService>()` throws StateError
- Null check operator throws on session access before sign-in
- Text widget renderBox height exceeds single-line height (vertical wrapping detected)

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := navigateOrRender_fixed(input)
  ASSERT noException(result)
  ASSERT correctVisualOutput(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT navigateOrRender_original(input) == navigateOrRender_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many screen/state combinations automatically
- It catches regressions in layouts across different viewport sizes
- It provides strong guarantees that signed-in user flows remain unchanged

**Test Plan**: Observe behavior on UNFIXED code first for all non-bug scenarios (signed-in navigation, properly-registered services, already-wrapped text), then write property-based tests capturing that behavior.

**Test Cases**:
1. **Service Resolution Preservation**: Verify all previously-registered services (50+ in service_locator.dart) still resolve correctly after adding the 2 new ones
2. **Signed-In Screen Preservation**: Verify Data Import/Export and Database Management work identically when userId is non-null
3. **Existing Layout Preservation**: Verify screens with existing Expanded/Flexible text don't change layout
4. **Theme Preservation**: Verify screens that already set backgroundColor continue to use their existing color

### Unit Tests

- Test `sl<DunningService>()` resolves after registration
- Test `sl<PaymentGatewayApiService>()` resolves after registration
- Test DataImportExportScreen shows "Please sign in" when userId is null
- Test DatabaseManagementScreen shows fallback UI when session is not ready
- Test BuyFlowDashboard stat card text does not wrap vertically at 320px width
- Test ₹ symbol renders correctly (codepoint == 0x20B9)
- Test loading overlay state is false after data fetch completes (success and error paths)

### Property-Based Tests

- Generate random viewport widths (300–1920px) and verify no text wraps vertically in stat cards
- Generate random service resolution sequences and verify no StateError after fix
- Generate random session states (null/non-null userId) and verify no crash on navigation
- Generate random dashboard card counts and viewport widths and verify no card overlap

### Integration Tests

- Full app boot → navigate all 19+ dashboards → verify zero unhandled exceptions
- Navigate to Dunning Configuration and Payment Gateway Settings → verify screens render
- Navigate to Data Import/Export pre-login → verify graceful fallback
- Render BuyFlow Dashboard on narrow mobile viewport → verify readable text
- Open Settings, Financial Reports, Data Import/Export, Database Management → verify correct background and no status bar overlap
