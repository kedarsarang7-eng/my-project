# Bugfix Requirements Document

## Introduction

The Dukanx Flutter application exhibits widespread cross-platform responsiveness failures across multiple screens when rendered on mobile devices (screen width < 600px). The responsive system (`context.isMobile` from `responsive_layout.dart`, `responsiveValue()`) exists and works correctly — but numerous screens do not use mobile-conditional layout logic, unconditionally rendering desktop-style layouts that cause: text rendering vertically letter-by-letter, content overflow/clipping, broken container constraints, desktop two-column layouts forced onto phone viewports, and in one case a raw API exception displayed to users.

**Previously fixed screens (excluded from this work):**
- `StockEntryScreen` — already uses `context.isMobile` conditional layout ✓
- `StockReversalScreen` — already uses `context.isMobile` conditional layout ✓
- `BuyFlowDashboard` — already uses responsive KPI card grid ✓

**Screens requiring fix (9 screens + global audit):**
1. Process Return screen
2. New Estimate screen
3. Buy Orders (PO List) screen
4. New Purchase Order screen (CRITICAL)
5. Catalogue / Share Catalogue screen
6. Funds Flow dashboard screen
7. Payment Reminders screen
8. Payment Gateway Settings screen (Auth/API failure)
9. Storage Management screen (CRITICAL)

**App context:** Flutter with Dukanx package. Breakpoints: Mobile < 600px, Tablet 600–1024px, Desktop > 1024px.

## Bug Analysis

### Current Behavior (Defect)

**Screen 1 — Process Return:**

1.1 WHEN the screen width is less than 600px AND the user opens the Process Return screen THEN the system renders a search field whose text "Tap to se..." overflows and clips within its containing card boundary

1.2 WHEN the screen width is less than 600px AND the user views the Process Return screen THEN the system renders the search container with non-responsive fixed width causing text to exceed card boundaries

1.3 WHEN the screen width is less than 600px AND the user views the Process Return button THEN the system renders the button with poor visibility and insufficient spacing from surrounding elements

**Screen 2 — New Estimate:**

1.4 WHEN the screen width is less than 600px AND the user opens the New Estimate screen THEN the system renders the customer-section card with inconsistent spacing between elements

1.5 WHEN the screen width is less than 600px AND the user views the date fields on the New Estimate screen THEN the system renders date-field labels overlapping their values (e.g., "Valid Until" overlapping "20 Jul 2026") due to broken alignment

1.6 WHEN the screen width is less than 600px AND the user views the empty items state on the New Estimate screen THEN the system renders "No Items Added" text at an oversized font that does not fit the mobile viewport

1.7 WHEN the screen width is less than 600px AND the user views the totals section on the New Estimate screen THEN the system renders garbled Unicode characters in subtotal and discount labels (displaying "Subtotalâ," and "Discount - â,¹" instead of proper currency symbols)

**Screen 3 — Buy Orders (PO List):**

1.8 WHEN the screen width is less than 600px AND the user opens the Buy Orders screen THEN the system renders the AppBar title "Buy Orders (PO)" wrapping incorrectly across multiple lines instead of fitting on a single line

1.9 WHEN the screen width is less than 600px AND the user views the empty state on the Buy Orders screen THEN the system renders the empty state content with poor spacing and off-center alignment

1.10 WHEN the screen width is less than 600px AND the user views the Create PO button on the Buy Orders screen THEN the system renders the button with inconsistent alignment relative to the screen layout

**Screen 4 — New Purchase Order (CRITICAL):**

1.11 WHEN the screen width is less than 600px AND the user opens the New Purchase Order screen THEN the system renders a desktop two-column layout on a mobile phone forcing content into an unusably narrow left panel

1.12 WHEN the screen width is less than 600px AND the user views the vendor details section on the New Purchase Order screen THEN the system renders the text "Purchase" vertically letter-by-letter (P-u-r-c-h-a-s-e-O) due to broken container width constraints

1.13 WHEN the screen width is less than 600px AND the user views the items panel on the New Purchase Order screen THEN the system renders a two-column item panel layout that is designed for desktop and is unusable on mobile

1.14 WHEN the screen width is less than 600px AND the user views the Create Purchase button on the New Purchase Order screen THEN the system renders the button in a misplaced position due to the broken two-column layout

**Screen 5 — Catalogue (Share Catalogue):**

1.15 WHEN the screen width is less than 600px AND the user opens the Share Catalogue screen THEN the system renders the "Share Catalogue" title wrapping across multiple lines vertically due to insufficient horizontal space

1.16 WHEN the screen width is less than 600px AND the user views the description text on the Catalogue screen THEN the system renders "Select items to share with your customers" wrapping too narrowly in a compressed layout

1.17 WHEN the screen width is less than 600px AND the user views the Share-to-WhatsApp button on the Catalogue screen THEN the system renders the button with incorrect width that does not adapt to the mobile viewport

1.18 WHEN the screen width is less than 600px AND the user views the search section on the Catalogue screen THEN the system renders the search field with misalignment relative to other UI elements

**Screen 6 — Funds Flow:**

1.19 WHEN the screen width is less than 600px AND the user opens the Funds Flow dashboard THEN the system renders dashboard data cards as empty placeholders without displaying actual data content

1.20 WHEN the screen width is less than 600px AND the user views the cashflow area on the Funds Flow dashboard THEN the system renders an empty cashflow area showing only the date range selector with no chart or data visible

**Screen 7 — Payment Reminders:**

1.21 WHEN the screen width is less than 600px AND the user opens the Payment Reminders screen THEN the system renders the AppBar title "Payment Reminders" overflowing and wrapping across multiple lines instead of fitting in the AppBar

**Screen 8 — Payment Gateway Settings (Auth/API Failure):**

1.22 WHEN the user opens the Payment Gateway Settings screen AND the authentication token is expired or invalid THEN the system displays a raw error message "ApiException(401): Unknown error [getGatewayConfigs]" directly to the user instead of a user-friendly error state

1.23 WHEN the user encounters the 401 error on Payment Gateway Settings THEN the system provides no loading UI, no retry action, and no user-friendly error messaging for the authentication failure

**Screen 9 — Storage Management (CRITICAL):**

1.24 WHEN the screen width is less than 600px AND the user opens the Storage Management screen THEN the system renders "App Data" and "Cache data" text vertically letter-by-letter (A-p-p-d-a-t-a-C-a-c-h-e-d-a-t) due to broken container constraints forcing text into an impossibly narrow column

1.25 WHEN the screen width is less than 600px AND the user views the usage cards on the Storage Management screen THEN the system renders severe overflow of the usage-card content beyond its container boundaries

**Global Codebase Issues:**

1.26 WHEN the Dukanx codebase is analyzed for layout issues THEN the system contains multiple screens with RenderFlex overflow warnings, constraint exceptions, infinite height/width issues, text overflow/clipping/vertical rendering, desktop layouts incorrectly shown on mobile, and fixed widths/heights that do not adapt to viewport size

1.27 WHEN screens are rendered on mobile AND they contain unhandled API error responses (401/403/500) THEN the system displays raw exception text to users instead of user-friendly error states

### Expected Behavior (Correct)

**Screen 1 — Process Return:**

2.1 WHEN the screen width is less than 600px AND the user opens the Process Return screen THEN the system SHALL render the search field with responsive width that fits fully within its containing card with no text clipping or overflow

2.2 WHEN the screen width is less than 600px AND the user views the Process Return screen THEN the system SHALL render the search container with adaptive width that respects card boundaries at all mobile viewport sizes

2.3 WHEN the screen width is less than 600px AND the user views the Process Return button THEN the system SHALL render the button with adequate visibility, proper padding, and correct spacing from surrounding elements

**Screen 2 — New Estimate:**

2.4 WHEN the screen width is less than 600px AND the user opens the New Estimate screen THEN the system SHALL render the customer-section card with consistent and proportional spacing between all elements

2.5 WHEN the screen width is less than 600px AND the user views the date fields on the New Estimate screen THEN the system SHALL render date-field labels and values with proper vertical stacking or sufficient horizontal spacing to prevent overlap

2.6 WHEN the screen width is less than 600px AND the user views the empty items state on the New Estimate screen THEN the system SHALL render "No Items Added" text at a responsive font size appropriate for the mobile viewport

2.7 WHEN the screen width is less than 600px AND the user views the totals section on the New Estimate screen THEN the system SHALL render currency symbols correctly (₹ for Indian Rupee) without garbled Unicode characters

**Screen 3 — Buy Orders (PO List):**

2.8 WHEN the screen width is less than 600px AND the user opens the Buy Orders screen THEN the system SHALL render the AppBar title "Buy Orders (PO)" on a single line with appropriate font size or abbreviation to fit the AppBar

2.9 WHEN the screen width is less than 600px AND the user views the empty state on the Buy Orders screen THEN the system SHALL render the empty state content centered and with proportional spacing

2.10 WHEN the screen width is less than 600px AND the user views the Create PO button on the Buy Orders screen THEN the system SHALL render the button with consistent alignment (centered or full-width) appropriate for mobile

**Screen 4 — New Purchase Order (CRITICAL):**

2.11 WHEN the screen width is less than 600px AND the user opens the New Purchase Order screen THEN the system SHALL render a single-column stacked layout with vendor details on top and items section below, using full viewport width

2.12 WHEN the screen width is less than 600px AND the user views the vendor details section on the New Purchase Order screen THEN the system SHALL render all text horizontally with readable font sizes and proper word wrapping

2.13 WHEN the screen width is less than 600px AND the user views the items panel on the New Purchase Order screen THEN the system SHALL render items in a single-column list layout that uses the full available width

2.14 WHEN the screen width is less than 600px AND the user views the Create Purchase button on the New Purchase Order screen THEN the system SHALL render the button at the bottom of the scrollable content with full-width or centered alignment

**Screen 5 — Catalogue (Share Catalogue):**

2.15 WHEN the screen width is less than 600px AND the user opens the Share Catalogue screen THEN the system SHALL render the "Share Catalogue" title on a single line with appropriate font size for the mobile viewport

2.16 WHEN the screen width is less than 600px AND the user views the description text on the Catalogue screen THEN the system SHALL render description text with adequate line width for comfortable reading

2.17 WHEN the screen width is less than 600px AND the user views the Share-to-WhatsApp button on the Catalogue screen THEN the system SHALL render the button at full width or with responsive width that fits the mobile viewport

2.18 WHEN the screen width is less than 600px AND the user views the search section on the Catalogue screen THEN the system SHALL render the search field aligned consistently with other UI elements at proper width

**Screen 6 — Funds Flow:**

2.19 WHEN the screen width is less than 600px AND the user opens the Funds Flow dashboard THEN the system SHALL render dashboard data cards with actual data content visible and properly laid out for mobile

2.20 WHEN the screen width is less than 600px AND the user views the cashflow area on the Funds Flow dashboard THEN the system SHALL render the cashflow chart or data visualization adapted to the mobile viewport width

**Screen 7 — Payment Reminders:**

2.21 WHEN the screen width is less than 600px AND the user opens the Payment Reminders screen THEN the system SHALL render the AppBar title "Payment Reminders" on a single line using responsive font size or text overflow ellipsis

**Screen 8 — Payment Gateway Settings (Auth/API Failure):**

2.22 WHEN the user opens the Payment Gateway Settings screen AND the authentication token is expired or invalid THEN the system SHALL display a user-friendly error message (e.g., "Unable to load payment settings. Please try again.") with a retry button, without exposing raw API exception details

2.23 WHEN the user encounters an authentication failure on Payment Gateway Settings THEN the system SHALL show a loading indicator during the request, attempt token refresh via the auth chain (AWS Cognito JWT/refresh token), and if refresh fails, display a clean error state with retry and re-login options

**Screen 9 — Storage Management (CRITICAL):**

2.24 WHEN the screen width is less than 600px AND the user opens the Storage Management screen THEN the system SHALL render "App Data" and "Cache data" labels horizontally with proper word wrapping and responsive container widths

2.25 WHEN the screen width is less than 600px AND the user views the usage cards on the Storage Management screen THEN the system SHALL render usage-card content fully within container boundaries with no overflow

**Global Codebase Requirements:**

2.26 WHEN the Dukanx codebase is audited for layout issues THEN the system SHALL have zero RenderFlex overflow warnings, zero constraint exceptions, zero text overflow/clipping/vertical rendering issues, and all screens SHALL use responsive layouts appropriate for the current viewport size

2.27 WHEN screens encounter API error responses (401/403/500) THEN the system SHALL display user-friendly error states with retry actions and SHALL NOT expose raw exception messages to users

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the Process Return screen THEN the system SHALL CONTINUE TO render the existing layout unchanged

3.2 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the New Estimate screen THEN the system SHALL CONTINUE TO render the existing layout with proper date-field alignment and currency formatting

3.3 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the Buy Orders (PO List) screen THEN the system SHALL CONTINUE TO render the AppBar title and empty state in their current desktop layout

3.4 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the New Purchase Order screen THEN the system SHALL CONTINUE TO render the two-column layout with vendor details panel and items panel side-by-side

3.5 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the Catalogue screen THEN the system SHALL CONTINUE TO render the existing Share Catalogue layout unchanged

3.6 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the Funds Flow dashboard THEN the system SHALL CONTINUE TO render dashboard data cards and cashflow visualizations in their current layout

3.7 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the Payment Reminders screen THEN the system SHALL CONTINUE TO render the existing layout with full AppBar title

3.8 WHEN the Payment Gateway Settings API call succeeds with valid authentication THEN the system SHALL CONTINUE TO render gateway configuration data exactly as before

3.9 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens the Storage Management screen THEN the system SHALL CONTINUE TO render usage cards in their current desktop layout

3.10 WHEN the user interacts with any business logic on any screen at any screen size THEN the system SHALL CONTINUE TO process all data operations (stock entry, purchase orders, estimates, returns, payments, fund flows) correctly with identical behavior

3.11 WHEN the screen width is 600px or greater AND screens that are already fixed (StockEntryScreen, StockReversalScreen, BuyFlowDashboard) are rendered THEN the system SHALL CONTINUE TO display their current responsive layouts without regression

3.12 WHEN screens are validated across all target viewports (360×640, 393×851, 412×915, 768×1024, 1024×1366, 1920×1080) THEN the system SHALL CONTINUE TO render correctly on all platforms: Android phone, Android tablet, iPhone, iPad, Windows, macOS, Linux

---

## Bug Condition (Formal)

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type ScreenRenderInput { screenWidth: double, screenName: string, apiState: AuthState }
  OUTPUT: boolean
  
  // Layout responsiveness bug condition
  layoutBug := X.screenWidth < 600 
    AND X.screenName IN {
      "ProcessReturnScreen",
      "NewEstimateScreen", 
      "BuyOrdersListScreen",
      "NewPurchaseOrderScreen",
      "CatalogueScreen",
      "FundsFlowDashboard",
      "PaymentRemindersScreen",
      "StorageManagementScreen"
    }
  
  // API error handling bug condition
  apiBug := X.screenName = "PaymentGatewaySettingsScreen"
    AND X.apiState = AuthState.EXPIRED_OR_INVALID
  
  RETURN layoutBug OR apiBug
END FUNCTION
```

```pascal
// Property: Fix Checking — Mobile layouts render correctly
FOR ALL X WHERE isBugCondition(X) AND X.screenWidth < 600 DO
  renderedLayout ← renderScreen'(X)
  
  // Screens with vertical text rendering (CRITICAL)
  IF X.screenName IN {"NewPurchaseOrderScreen", "StorageManagementScreen"} THEN
    ASSERT renderedLayout.noVerticalTextRendering = true
    ASSERT renderedLayout.containerMinWidth >= 200
    ASSERT renderedLayout.useSingleColumnLayout = true
  END IF
  
  // Screens with AppBar overflow
  IF X.screenName IN {"BuyOrdersListScreen", "PaymentRemindersScreen"} THEN
    ASSERT renderedLayout.appBarTitleFitsOnSingleLine = true
  END IF
  
  // Screens with content overflow/clipping
  IF X.screenName IN {"ProcessReturnScreen", "NewEstimateScreen", "CatalogueScreen"} THEN
    ASSERT renderedLayout.hasNoHorizontalOverflow = true
    ASSERT renderedLayout.allTextReadable = true
    ASSERT renderedLayout.noTextClipping = true
  END IF
  
  // Screens with empty/missing data rendering
  IF X.screenName = "FundsFlowDashboard" THEN
    ASSERT renderedLayout.dataCardsVisible = true
    ASSERT renderedLayout.cashflowAreaRendered = true
  END IF
  
  // Unicode/encoding fix
  IF X.screenName = "NewEstimateScreen" THEN
    ASSERT renderedLayout.currencySymbolsRenderedCorrectly = true
  END IF
  
  // All mobile screens: no overflow
  ASSERT renderedLayout.hasNoRenderFlexOverflow = true
END FOR
```

```pascal
// Property: Fix Checking — API error handling
FOR ALL X WHERE X.screenName = "PaymentGatewaySettingsScreen" 
  AND X.apiState = AuthState.EXPIRED_OR_INVALID DO
  renderedUI ← renderScreen'(X)
  ASSERT renderedUI.showsUserFriendlyError = true
  ASSERT renderedUI.hasRetryButton = true
  ASSERT renderedUI.noRawExceptionVisible = true
  ASSERT renderedUI.attemptedTokenRefresh = true
END FOR
```

```pascal
// Property: Preservation Checking — Desktop/tablet layouts unchanged
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT renderScreen(X) = renderScreen'(X)
END FOR
```

```pascal
// Property: Global Audit — Zero layout issues across codebase
FOR ALL screens IN DukanxCodebase DO
  FOR ALL viewport IN {360x640, 393x851, 412x915, 768x1024, 1024x1366, 1920x1080} DO
    rendered ← renderScreen'(screen, viewport)
    ASSERT rendered.hasNoRenderFlexOverflow = true
    ASSERT rendered.hasNoConstraintExceptions = true
    ASSERT rendered.hasNoInfiniteHeightWidth = true
    ASSERT rendered.hasNoTextOverflowOrClipping = true
    ASSERT rendered.hasNoVerticalTextRendering = true
    ASSERT rendered.usesResponsiveLayoutForViewport = true
  END FOR
END FOR
```
