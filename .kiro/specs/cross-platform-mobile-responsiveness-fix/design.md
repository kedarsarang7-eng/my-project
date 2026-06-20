# Cross-Platform Mobile Responsiveness Fix — Bugfix Design

## Overview

The Dukanx Flutter application has widespread mobile responsiveness failures across 9 screens when rendered on devices with screen width < 600px. The responsive system (`context.isMobile`, `responsiveValue()`, `ResponsiveLayout`, `ResponsiveRowColumn`) exists and functions correctly — but affected screens either (a) unconditionally render desktop-style Row/two-column layouts, (b) use fixed-width containers that overflow on narrow viewports, (c) render AppBar titles that wrap/overflow, (d) display empty data cards due to layout constraint failures, or (e) show raw API exceptions to users.

**Fix strategy:** Apply the proven `context.isMobile ? Column(...) : Row(...)` pattern (already working in `AddPurchaseScreen`, `StockEntryScreen`, `StockReversalScreen`) to all affected screens. Introduce 3 shared reusable widgets to eliminate duplication. Add error handling architecture for API failure states.

**Severity tiers:**
- CRITICAL (Screens 4, 9): Vertical text rendering, completely unusable on mobile
- HIGH (Screens 1, 2, 5, 6, 8): Overflow, clipping, missing data, raw exceptions
- MEDIUM (Screens 3, 7): AppBar overflow, spacing inconsistency

## Glossary

- **Bug_Condition (C)**: Screen width < 600px AND the user is on one of the 9 affected screens, OR user encounters an API auth failure on PaymentGatewaySettingsScreen
- **Property (P)**: Mobile-appropriate single-column layouts with no overflow, readable text, visible data, and user-friendly error states
- **Preservation**: Desktop/tablet layouts (≥ 600px) and all business logic must remain unchanged across all screens
- **`context.isMobile`**: Extension on `BuildContext` from `responsive_layout.dart` — returns `true` when `MediaQuery.of(context).size.width < 600`
- **`responsiveValue<T>()`**: Utility returning different values per breakpoint: `responsiveValue(context, mobile: X, tablet: Y, desktop: Z)`
- **`DesktopContentContainer`**: Shell widget providing title bar, subtitle, action buttons; used by all affected screens
- **`ResponsiveRowColumn`**: Existing widget that auto-switches between Row (desktop) and Column (mobile)
- **Vertical text rendering**: Text forced into a container so narrow (< 30px) that each character renders on its own line
- **RenderFlex overflow**: Flutter's "yellow/black stripe" error when child widgets exceed parent container bounds

## Bug Details

### Bug Condition

The bug manifests across 9 screens with three distinct failure modes:

1. **Desktop layout on mobile** (Screens 4, 9): `Row` with `Expanded` children unconditionally rendered, crushing panels to < 30px on 360px viewports → vertical text
2. **Fixed-width/overflow** (Screens 1, 2, 3, 5, 7): Non-adaptive containers, AppBar titles that wrap, search fields that clip, fonts too large for viewport
3. **Data/API failure** (Screens 6, 8): Empty data cards from layout constraints preventing render; raw `ApiException(401)` shown to user

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type ScreenRenderInput { screenWidth: double, screenName: string, apiState: AuthState }
  OUTPUT: boolean
  
  // Layout responsiveness bug condition
  layoutBug := input.screenWidth < 600 
    AND input.screenName IN {
      "ProcessReturnScreen",
      "NewEstimateScreen",
      "BuyOrdersListScreen",
      "NewPurchaseOrderScreen",
      "CatalogueScreen",
      "CashflowScreen",
      "PaymentRemindersScreen",
      "StorageManagementScreen"
    }
  
  // API error handling bug condition
  apiBug := input.screenName = "PaymentGatewaySettingsScreen"
    AND input.apiState = AuthState.EXPIRED_OR_INVALID
  
  RETURN layoutBug OR apiBug
END FUNCTION
```

### Examples

- **NewPurchaseOrderScreen at 360px (CRITICAL)**: Expected single-column stacked layout. Actual: `Row(children: [Expanded(flex:4), Expanded(flex:6)])` renders left panel at ~135px — "Purchase Order" text renders vertically P-u-r-c-h-a-s-e, dropdown is unusable, items panel is unreadable.
- **StorageManagementScreen at 375px (CRITICAL)**: Expected responsive usage cards. Actual: `DesktopContentContainer` with constrained inner containers renders "App Data" and "Cache data" vertically, usage row overflows card boundary.
- **ProcessReturnScreen at 393px**: Expected search field fills card width. Actual: fixed-width search card clips "Tap to se..." text, return button has insufficient spacing.
- **NewEstimateScreen at 412px**: Expected date fields stack vertically. Actual: date labels overlap values ("Valid Until" on top of "20 Jul 2026"), "₹" renders as "â,¹" (UTF-8 mojibake), empty-state text oversized.
- **CatalogueScreen at 360px**: Expected title on single line. Actual: "Share Catalogue" wraps vertically, search misaligned relative to product grid.
- **CashflowScreen at 375px**: Expected data cards with visible content. Actual: dashboard data cards render as empty rectangles, cashflow chart area shows only date selector.
- **PaymentGatewaySettingsScreen (any width, expired token)**: Expected user-friendly error with retry. Actual: `"ApiException(401): Unknown error [getGatewayConfigs]"` raw string displayed.
- **PaymentRemindersScreen at 360px**: Expected AppBar title fits. Actual: "Payment Reminders" wraps onto two lines in AppBar.
- **BuyOrdersListScreen at 393px**: Expected AppBar title fits on one line. Actual: "Buy Orders (PO)" wraps, empty state off-center.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Desktop/tablet (≥ 600px) layouts for ALL 9 screens must remain pixel-identical
- NewPurchaseOrderScreen two-column Row(flex:4, flex:6) layout on desktop must be preserved
- CatalogueScreen 4-column product grid on desktop must be preserved
- CashflowScreen tab-based layout with date range selector and chart on desktop must be preserved
- StorageManagementScreen usage card layout on desktop must be preserved
- PaymentGatewaySettingsScreen credential management flow when API succeeds must be preserved
- All business logic (PO creation, estimates, returns, catalogue sharing, payment config) must remain identical
- Navigation flows, dialog interactions, and data operations must be unaffected at any screen size
- Previously fixed screens (StockEntryScreen, StockReversalScreen, BuyFlowDashboard) must not regress

**Scope:**
All inputs where `screenWidth >= 600` should be completely unaffected by this fix. This includes:
- Desktop viewing (≥ 1100px) on Windows, macOS, Linux
- Tablet viewing (600–1099px) on iPad, Android tablets
- All screen sizes for screens not in the affected list
- All business logic regardless of screen size
- All API calls that succeed with valid authentication

## Hypothesized Root Cause

Based on code analysis of all 9 affected screens, the root causes fall into 5 architectural categories:

1. **Unconditional desktop Row layout (Screens 4, 9 — CRITICAL)**:
   - `_CreateOrderScreen.build()` in `buy_orders_screen.dart` (line ~278) renders `Row(children: [Expanded(flex:4, ...), SizedBox(width:24), Expanded(flex:6, ...)])` unconditionally
   - `StorageManagementScreen` wraps content in `DesktopContentContainer` which imposes width constraints that cascade into child containers rendering text vertically at narrow widths
   - **Root cause**: No `context.isMobile` conditional at the top-level layout decision point

2. **Non-responsive AppBar titles (Screens 3, 7)**:
   - `DesktopContentContainer` renders title via a `Text` widget without `overflow: TextOverflow.ellipsis` or `maxLines: 1`
   - Long titles ("Payment Reminders", "Buy Orders (PO)") exceed AppBar width on mobile and wrap to multiple lines
   - **Root cause**: `DesktopContentContainer.title` parameter displayed without text overflow handling or responsive font sizing

3. **Fixed-width containers and overflow (Screens 1, 2, 5)**:
   - ProcessReturnScreen: Search field card uses non-responsive width
   - NewEstimateScreen: Date fields laid out in a `Row` without wrapping, labels overlap values; `TextStyle` uses fixed large font for empty state
   - CatalogueScreen: Description area has fixed padding and width constraints that compress text
   - **Root cause**: Missing `responsiveValue()` calls for padding/sizing, missing `Flexible`/`Expanded` wrappers

4. **Empty data cards and missing content (Screen 6)**:
   - `CashflowScreen` renders data cards/charts that may have implicit minimum height/width constraints from desktop-optimized chart widgets
   - At mobile widths, chart containers get insufficient height or the layout constraints propagate incorrectly
   - **Root cause**: Chart/card widgets have fixed dimensions designed for desktop, no mobile layout adaptation

5. **Raw API exception display (Screen 8)**:
   - `PaymentGatewaySettingsScreen._loadConfigs()` catches errors with `_error = e.toString()` and renders `Text(_error!)` directly
   - OpenAPI-generated client throws `ApiException(401): Unknown error [getGatewayConfigs]` which is shown verbatim
   - **Root cause**: No error classification, no user-friendly messaging layer, no token refresh attempt before displaying error

6. **Unicode/encoding issue (Screen 2)**:
   - NewEstimateScreen (proforma_screen.dart) displays currency using string literals that contain improperly encoded `₹` symbols
   - The file may be saved with incorrect encoding or the string interpolation uses a raw byte sequence instead of the Unicode escape `\u20B9`
   - **Root cause**: Source file encoding or hardcoded byte sequence for ₹ symbol instead of proper Unicode

## Correctness Properties

Property 1: Bug Condition - Mobile Layouts Render Correctly

_For any_ screen render input where the screen width is less than 600px and the screen is one of the 9 affected screens, the fixed screen SHALL render a mobile-appropriate layout: single-column vertical stacking for two-column screens (NewPurchaseOrderScreen, StorageManagementScreen), properly constrained text and containers with no overflow/clipping for all screens, AppBar titles on a single line with ellipsis or responsive font size, visible data content in dashboard cards, and correct Unicode rendering of currency symbols.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15, 2.16, 2.17, 2.18, 2.19, 2.20, 2.21, 2.24, 2.25, 2.26**

Property 2: Bug Condition - API Error Handling

_For any_ screen render input where the PaymentGatewaySettingsScreen encounters an API authentication failure (401/403), the fixed screen SHALL display a user-friendly error message with a retry button, attempt token refresh, and SHALL NOT expose raw API exception text to the user.

**Validates: Requirements 2.22, 2.23, 2.27**

Property 3: Preservation - Desktop/Tablet Layouts Unchanged

_For any_ screen render input where the screen width is 600px or greater, the fixed screens SHALL produce exactly the same layout as the original code, preserving all existing desktop/tablet behavior including two-column layouts, 4-column grids, chart dimensions, AppBar styling, and business logic.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12**

Property 4: Preservation - Successful API Behavior Unchanged

_For any_ screen render input where the PaymentGatewaySettingsScreen API call succeeds with valid authentication, the fixed screen SHALL render gateway configuration data exactly as before with no changes to the success path UI or behavior.

**Validates: Requirements 3.8**

## Fix Implementation

### Shared Components to Introduce

Before fixing individual screens, create 3 reusable widgets to prevent duplication:

#### 1. `ResponsiveAppBarTitle` (new widget)

**File**: `lib/widgets/responsive_app_bar_title.dart`

Wraps AppBar title text with mobile-aware overflow handling:
```
Widget build(context):
  return Text(
    title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style?.copyWith(fontSize: context.isMobile ? 16 : style.fontSize)
           ?? TextStyle(fontSize: context.isMobile ? 16 : 20)
  )
```

#### 2. `ApiErrorStateWidget` (new widget)

**File**: `lib/widgets/api_error_state_widget.dart`

Standardized error state display for API failures:
```
class ApiErrorStateWidget extends StatelessWidget {
  final String? userMessage;  // Friendly message shown to user
  final VoidCallback? onRetry;
  final VoidCallback? onReLogin;
  final bool showReLogin;     // True for 401/403 errors

  // Renders: Icon + message + retry button + optional re-login button
  // NEVER exposes raw exception details
}
```

#### 3. `ResponsiveEmptyState` (enhance existing `EmptyStateWidget`)

**File**: `lib/widgets/desktop/empty_state.dart` (already exists)

Add responsive font sizing and spacing:
- Title: `responsiveValue(context, mobile: 14, tablet: 16, desktop: 18)`
- Description: `responsiveValue(context, mobile: 12, tablet: 13, desktop: 14)`
- Icon size: `responsiveValue(context, mobile: 48, tablet: 56, desktop: 64)`
- Centered layout with `mainAxisAlignment: MainAxisAlignment.center`

### Per-Screen Changes

#### Screen 1 — Process Return

**File**: `lib/features/buy_flow/screens/process_return_screen.dart` (or equivalent)

**Changes**:
1. Replace fixed-width search container with `Expanded` or `Flexible` wrapper respecting card boundaries
2. Add `responsiveValue` for search field padding/margins
3. Ensure return button has consistent spacing: `SizedBox(height: responsiveValue(context, mobile: 12, desktop: 16))`
4. Wrap search card content to prevent text clipping: add `overflow: TextOverflow.ellipsis` to hint text

#### Screen 2 — New Estimate (proforma_screen.dart)

**File**: `lib/features/revenue/screens/proforma_screen.dart`

**Changes**:
1. **Date fields**: Replace horizontal `Row` layout for date fields with `context.isMobile ? Column(...) : Row(...)` to prevent label/value overlap
2. **Empty state font**: Change "No Items Added" text to use `responsiveValue(context, mobile: 14, tablet: 16, desktop: 18)` font size
3. **Currency encoding fix**: Replace garbled ₹ string literals with proper Unicode `'\u20B9'` or use `CurrencyService.symbol` utility
4. **Spacing**: Use `responsiveValue` for card internal padding

#### Screen 3 — Buy Orders (PO List)

**File**: `lib/features/buy_flow/screens/buy_orders_screen.dart` — `BuyOrdersScreen` class

**Changes**:
1. **AppBar title**: `DesktopContentContainer(title: 'Buy Orders (PO)')` — update `DesktopContentContainer` to handle title overflow with `maxLines: 1, overflow: TextOverflow.ellipsis` or use responsive font sizing
2. **Empty state**: Use enhanced `EmptyStateWidget` with responsive sizing, centered alignment
3. **Create PO button**: On mobile, render as full-width `SizedBox(width: double.infinity, child: ElevatedButton(...))` for consistent alignment

#### Screen 4 — New Purchase Order (CRITICAL)

**File**: `lib/features/buy_flow/screens/buy_orders_screen.dart` — `_CreateOrderScreen` class

**Changes**:
1. **Replace unconditional Row with mobile conditional**:
   ```dart
   child: context.isMobile
     ? SingleChildScrollView(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             _buildVendorDetailsSection(isDark),
             SizedBox(height: 16),
             _buildItemsSection(isDark),
           ],
         ),
       )
     : Row(  // PRESERVED: Existing desktop layout unchanged
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Expanded(flex: 4, child: _buildVendorDetailsSection(isDark)),
           SizedBox(width: 24),
           Expanded(flex: 6, child: _buildItemsSection(isDark)),
         ],
       ),
   ```
2. **Remove `Expanded` on items list in mobile**: Use `SizedBox(height: 400)` or `ConstrainedBox` instead of `Expanded` (which requires bounded parent)
3. **Vendor section full-width on mobile**: Remove flex constraints, use `CrossAxisAlignment.stretch`
4. **Create Purchase button**: Full-width at bottom of scrollable content

#### Screen 5 — Catalogue (Share Catalogue)

**File**: `lib/features/catalogue/presentation/screens/catalogue_screen.dart`

**Changes**:
1. **Title handling**: Already using `DesktopContentContainer(title: 'Share Catalogue')` — fix in `DesktopContentContainer` title rendering (global fix, see below)
2. **Description text**: Already has subtitle parameter — ensure subtitle uses `maxLines: 2, overflow: TextOverflow.ellipsis`
3. **Share button width**: On mobile, action buttons in `DesktopContentContainer.actions` should wrap or collapse — use `responsiveValue` for button label (show icon-only on mobile)
4. **Search alignment**: Add consistent padding `EdgeInsets.symmetric(horizontal: responsiveValue(context, mobile: 12, desktop: 0))` to search container
5. **Grid columns**: Already has `responsiveValue(context, mobile: 1, tablet: 2, desktop: 4)` — verify this works correctly

#### Screen 6 — Funds Flow (CashflowScreen)

**File**: `lib/features/reports/presentation/screens/cashflow_screen.dart`

**Changes**:
1. **Data cards**: Wrap summary data cards in `context.isMobile ? Column(...) : Row(...)` so each card gets full width on mobile
2. **Chart/cashflow area**: Add minimum height constraint for chart widget on mobile: `SizedBox(height: responsiveValue(context, mobile: 200, desktop: 300))`
3. **Date range selector**: Ensure the date range row wraps on mobile or uses a compact format
4. **Tab bar**: Verify TabBar labels fit on mobile — use `isScrollable: true` if needed
5. **Flow items list**: Ensure `_FlowItem` card layout adapts to mobile width

#### Screen 7 — Payment Reminders

**File**: `lib/features/settings/presentation/screens/payment_reminders_screen.dart`

**Changes**:
1. **AppBar title**: Already uses `DesktopContentContainer(title: 'Payment Reminders')` — global `DesktopContentContainer` title fix handles this
2. **Action buttons row**: The "Send Test" and "Save Settings" buttons at bottom — wrap in `context.isMobile ? Column(...) : Row(...)` to prevent overflow on narrow screens

#### Screen 8 — Payment Gateway Settings (API Error Fix)

**File**: `lib/features/payment/presentation/screens/payment_gateway_settings_screen.dart`

**Changes**:
1. **Replace raw error display**: Change `Text(_error!)` to `ApiErrorStateWidget`:
   ```dart
   if (_error != null) ...[
     const SizedBox(height: 16),
     ApiErrorStateWidget(
       userMessage: 'Unable to load payment settings. Please try again.',
       onRetry: _loadConfigs,
       showReLogin: _isAuthError,
       onReLogin: () => _triggerReAuth(context),
     ),
   ],
   ```
2. **Error classification**: Parse exception type to detect auth errors:
   ```dart
   bool get _isAuthError => _error?.contains('401') == true || _error?.contains('403') == true;
   ```
3. **Token refresh attempt**: Before showing error, attempt token refresh via Cognito auth chain:
   ```dart
   } catch (e) {
     if (_isApiAuthError(e)) {
       final refreshed = await _attemptTokenRefresh();
       if (refreshed) { await _loadConfigs(); return; }
     }
     _error = e.toString(); // Internal only — never shown to user directly
   }
   ```
4. **Loading state**: Already has `_isLoading` with `CircularProgressIndicator` — confirm it shows during retry
5. **Snackbar errors**: Also sanitize catch blocks in `_verifyConfig`, `_deleteConfig` that do `Text('Error: $e')` → use generic message

#### Screen 9 — Storage Management (CRITICAL)

**File**: `lib/features/settings/presentation/screens/storage_management_screen.dart`

**Changes**:
1. **Usage row labels**: The `_usageRow` widget uses `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(label)), Text(value)])` — this is actually correct but the parent container may be getting crushed by `DesktopContentContainer` width constraints
2. **Root fix**: The `DesktopContentContainer` wraps content with a max-width constraint that may combine with sidebar to leave < 200px for content on mobile. Ensure `SingleChildScrollView` padding uses `responsiveValue(context, mobile: 12, tablet: 20, desktop: 24)`
3. **Container constraints**: Add `constraints: BoxConstraints(minWidth: 280)` to the usage card container to prevent text compression
4. **Button layout**: "Recalculate" and "Clear Cache" buttons — ensure they use `SizedBox(width: double.infinity)` on mobile for full-width tap targets

### Global Fix — DesktopContentContainer Title Overflow

**File**: `lib/widgets/desktop/desktop_content_container.dart`

**Changes**:
1. Modify the title `Text` widget to include `maxLines: 1, overflow: TextOverflow.ellipsis`
2. Use responsive font size: `fontSize: context.isMobile ? 16 : 20`
3. This single fix resolves AppBar title overflow for Screens 3, 5, 7, and all future screens using this container

### Global Fix — DesktopContentContainer Mobile Action Buttons

**Changes**:
1. On mobile, collapse action button labels to icon-only or use a popup menu
2. Alternatively, wrap actions in a `Wrap` widget that flows to next line on narrow viewports

### Architecture: API Error Handling Pattern

Establish a reusable pattern for all API-calling screens:

```dart
// 1. Classify error
enum ApiErrorType { auth, network, server, unknown }

ApiErrorType classifyError(dynamic error) {
  final msg = error.toString();
  if (msg.contains('401') || msg.contains('403')) return ApiErrorType.auth;
  if (msg.contains('SocketException') || msg.contains('timeout')) return ApiErrorType.network;
  if (msg.contains('500') || msg.contains('502')) return ApiErrorType.server;
  return ApiErrorType.unknown;
}

// 2. User-friendly message mapping
String userMessageFor(ApiErrorType type) => switch (type) {
  ApiErrorType.auth => 'Session expired. Please try again or re-login.',
  ApiErrorType.network => 'Network error. Check your connection and retry.',
  ApiErrorType.server => 'Server error. Please try again later.',
  ApiErrorType.unknown => 'Something went wrong. Please try again.',
};

// 3. Token refresh before showing auth error
// Uses existing AWS Cognito refresh token flow via SessionManager
```

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write widget tests that render each affected screen at mobile widths (360px, 375px, 393px) and assert on layout properties. Run these tests on the UNFIXED code to observe failures and confirm the root cause.

**Test Cases**:
1. **NewPurchaseOrderScreen at 360px (CRITICAL)**: Render screen, find top-level layout — will find `Row` (horizontal axis) on unfixed code, confirming desktop layout forced on mobile
2. **StorageManagementScreen at 375px (CRITICAL)**: Render screen, check for RenderFlex overflow errors or vertical text — will find container width < 200px on unfixed code
3. **ProcessReturnScreen at 393px**: Render screen, find search field — will find text clipped/overflowing card boundary
4. **NewEstimateScreen at 412px**: Render screen, check date field layout — will find labels overlapping values
5. **CatalogueScreen at 360px**: Render screen, check title rendering — will find multi-line wrapping
6. **CashflowScreen at 375px**: Render screen, check data card visibility — will find empty/invisible content
7. **PaymentGatewaySettingsScreen with 401 error**: Mock API to return 401, render screen — will find raw exception text displayed
8. **PaymentRemindersScreen at 360px**: Render screen, check AppBar title — will find multi-line wrapping
9. **BuyOrdersListScreen at 393px**: Render screen, check AppBar title and empty state — will find title wrapping and off-center alignment

**Expected Counterexamples**:
- Screens 4, 9: Horizontal `Row` layout at mobile widths → vertical text rendering
- Screens 3, 7: AppBar title exceeds available width → wraps to multiple lines
- Screens 1, 2, 5: Content overflow → text clipping, overlap, misalignment
- Screen 6: Data cards render with zero visible content
- Screen 8: Raw `ApiException(401)` string visible in UI

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  renderedLayout := renderScreen_fixed(input)
  
  // CRITICAL screens: verify no vertical text
  IF input.screenName IN {"NewPurchaseOrderScreen", "StorageManagementScreen"} THEN
    ASSERT renderedLayout.topLevelAxis = Axis.vertical  // Column layout
    ASSERT renderedLayout.minContainerWidth >= 200
    ASSERT renderedLayout.noVerticalTextRendering = true
  END IF
  
  // AppBar overflow screens
  IF input.screenName IN {"BuyOrdersListScreen", "PaymentRemindersScreen", "CatalogueScreen"} THEN
    ASSERT renderedLayout.titleMaxLines = 1
    ASSERT renderedLayout.titleNotWrapped = true
  END IF
  
  // Content overflow screens
  IF input.screenName IN {"ProcessReturnScreen", "NewEstimateScreen", "CatalogueScreen"} THEN
    ASSERT renderedLayout.hasNoHorizontalOverflow = true
    ASSERT renderedLayout.allTextReadable = true
    ASSERT renderedLayout.noLabelOverlap = true
  END IF
  
  // Data visibility screen
  IF input.screenName = "CashflowScreen" THEN
    ASSERT renderedLayout.dataCardsHaveContent = true
    ASSERT renderedLayout.chartAreaVisible = true
  END IF
  
  // Unicode fix
  IF input.screenName = "NewEstimateScreen" THEN
    ASSERT renderedLayout.currencySymbol = "₹"  // Not "â,¹"
  END IF
  
  // API error handling
  IF input.screenName = "PaymentGatewaySettingsScreen" AND input.apiState = EXPIRED THEN
    ASSERT renderedLayout.noRawExceptionText = true
    ASSERT renderedLayout.hasRetryButton = true
    ASSERT renderedLayout.showsUserFriendlyMessage = true
  END IF
  
  // Universal: no overflow
  ASSERT renderedLayout.hasNoRenderFlexOverflow = true
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT renderScreen_original(input) = renderScreen_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases across the width range (600–1920px) automatically
- It catches edge cases at breakpoint boundaries (599px vs 600px, 1099px vs 1100px)
- It provides strong guarantees that desktop/tablet behavior is unchanged for all 9 screens
- It tests combinations of screen × width × theme (light/dark) systematically

**Test Plan**: Observe behavior on UNFIXED code first for desktop/tablet widths, then write property-based tests capturing that exact behavior continues after the fix.

**Test Cases**:
1. **NewPurchaseOrderScreen at 600–1920px**: Verify two-column Row(flex:4, flex:6) layout preserved
2. **StorageManagementScreen at 600–1920px**: Verify usage card layout unchanged
3. **CatalogueScreen at 600–1920px**: Verify 2-column (tablet) and 4-column (desktop) grid preserved
4. **CashflowScreen at 600–1920px**: Verify tab layout with chart dimensions preserved
5. **PaymentGatewaySettingsScreen on success**: Verify credential management UI unchanged when API returns 200
6. **All screens at 600px boundary**: Verify exact breakpoint behavior at 599→600 transition
7. **Business logic at all widths**: Verify PO creation, estimate creation, catalogue sharing all function identically

### Unit Tests

- Test `DesktopContentContainer` title renders with `maxLines: 1` and `overflow: TextOverflow.ellipsis`
- Test `ApiErrorStateWidget` shows user-friendly message and hides raw exception
- Test `ApiErrorStateWidget` shows re-login button when `showReLogin: true`
- Test `classifyError()` correctly identifies 401, 403, SocketException, 500 errors
- Test `_CreateOrderScreen` renders Column at 375px and Row at 800px
- Test `StorageManagementScreen` renders without overflow at 360px
- Test `CatalogueScreen` grid uses 1 column at 375px, 2 at 700px, 4 at 1200px
- Test currency symbol renders as "₹" not garbled characters in NewEstimate
- Test `PaymentRemindersScreen` action buttons wrap to Column on mobile

### Property-Based Tests

- Generate random widths in [300, 599] range and verify ALL 9 screens render mobile-appropriate layouts (no overflow, no vertical text, titles on single line)
- Generate random widths in [600, 1920] range and verify ALL 9 screens render unchanged desktop/tablet layouts
- Generate random widths at breakpoint boundaries [598, 601] and verify correct layout switching across all screens
- Generate random API error responses (401, 403, 500, timeout, network) and verify PaymentGatewaySettingsScreen never displays raw exception text
- Generate random screen × width × theme combinations to verify no RenderFlex overflow in any configuration
- Generate random content lengths (long vendor names, long product names, many items) and verify no overflow at mobile widths

### Integration Tests

- Test full NewPurchaseOrderScreen flow on mobile: navigate, enter vendor, add items, save PO — all functional
- Test full CatalogueScreen flow on mobile: search products, select items, share to WhatsApp — all functional
- Test PaymentGatewaySettingsScreen: simulate expired token, verify error state renders, tap retry, verify reload
- Test StorageManagementScreen on mobile: view usage stats, tap recalculate, clear cache — all functional
- Test CashflowScreen on mobile: verify data loads, switch tabs, change date range — all functional
- Test global audit: render all 9 screens at 360px, 393px, 412px and verify zero RenderFlex overflow warnings
- Test orientation change: verify layouts adapt correctly when device rotates portrait↔landscape
- Test target viewports: 360×640, 393×851, 412×915, 768×1024, 1024×1366, 1920×1080
