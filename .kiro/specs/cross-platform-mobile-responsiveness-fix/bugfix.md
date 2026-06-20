# Bugfix Requirements Document

## Introduction

Multiple screens in the BuyFlow module render desktop-style side-by-side layouts on mobile devices (screen width < 600px), causing severe UI/UX issues: text rendering vertically letter-by-letter, content overflow/clipping, truncated widgets, and buttons being cut off. The responsive system (`context.isMobile`, `responsiveValue()`) exists and works correctly — but these screens simply do not use mobile checks in their layout logic, unconditionally rendering `Row(children: [Expanded(flex:4), Expanded(flex:6)])` regardless of screen width.

**Affected screens:**
- `StockEntryScreen` — uses `DesktopContentContainer` + hardcoded side-by-side `Row` layout with no mobile fallback
- `StockReversalScreen` — uses `DesktopContentContainer` + hardcoded side-by-side `Row` layout with no mobile fallback
- `BuyFlowDashboard` — forces 4 KPI summary cards in a single `Row` regardless of screen width, each card getting ~80px on mobile and truncating all text to single characters

**Not affected (already fixed):**
- `AddPurchaseScreen` — already uses `context.isMobile` to switch between Column (mobile) and Row (desktop/tablet)

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the screen width is less than 600px (mobile) AND the user opens StockEntryScreen THEN the system renders a side-by-side Row layout with Expanded(flex:4) and Expanded(flex:6) columns, causing vendor details to be unreadably narrow (~160px), text to render vertically, and the "Add Item" button to overflow/clip

1.2 WHEN the screen width is less than 600px (mobile) AND the user opens StockReversalScreen THEN the system renders a side-by-side Row layout with Expanded(flex:4) and Expanded(flex:6) columns, causing vendor details to be unreadably narrow, the "Return Item" button to overflow/clip, and the "Items to Return" header to be truncated

1.3 WHEN the screen width is less than 600px (mobile) AND the user views the BuyFlowDashboard THEN the system renders 4 KPI summary cards in a single Row, each card receiving approximately 80px width, causing card titles to truncate to single characters ("T...", "P...", "A...", "R...") and values to be unreadable

1.4 WHEN the screen width is less than 600px (mobile) AND the user views BuyFlowDashboard summary cards THEN the system displays card content with font size 24 for values and fixed 20px padding, which overflows the available card width on mobile

### Expected Behavior (Correct)

2.1 WHEN the screen width is less than 600px (mobile) AND the user opens StockEntryScreen THEN the system SHALL render a single-column stacked layout (Column) with vendor details section on top followed by the stock items section below, with no horizontal overflow and all text fully readable

2.2 WHEN the screen width is less than 600px (mobile) AND the user opens StockReversalScreen THEN the system SHALL render a single-column stacked layout (Column) with vendor details section on top followed by the items-to-return section below, with no horizontal overflow and all buttons fully visible

2.3 WHEN the screen width is less than 600px (mobile) AND the user views the BuyFlowDashboard THEN the system SHALL render KPI summary cards in a 2-column grid (2 per row) so that each card has sufficient width (~160px minimum) for readable text and values

2.4 WHEN the screen width is less than 600px (mobile) AND the user views BuyFlowDashboard summary cards THEN the system SHALL use responsive font sizes and padding that fit within the available card width without overflow or truncation

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens StockEntryScreen THEN the system SHALL CONTINUE TO render the side-by-side Row layout with Expanded(flex:4) for vendor details and Expanded(flex:6) for stock items

3.2 WHEN the screen width is 600px or greater (tablet/desktop) AND the user opens StockReversalScreen THEN the system SHALL CONTINUE TO render the side-by-side Row layout with Expanded(flex:4) for vendor details and Expanded(flex:6) for items to return

3.3 WHEN the screen width is 1100px or greater (desktop) AND the user views the BuyFlowDashboard THEN the system SHALL CONTINUE TO render 4 KPI summary cards in a single Row with each card taking equal width

3.4 WHEN the screen width is between 600px and 1099px (tablet) AND the user views the BuyFlowDashboard THEN the system SHALL CONTINUE TO render KPI summary cards in a 2x2 grid or adapt similarly to desktop (no single-column forced)

3.5 WHEN the user interacts with StockEntryScreen on any screen size THEN the system SHALL CONTINUE TO save stock entries correctly with identical business logic

3.6 WHEN the user interacts with StockReversalScreen on any screen size THEN the system SHALL CONTINUE TO process stock reversals correctly with identical business logic

3.7 WHEN the screen width is 600px or greater AND the user views BuyFlowDashboard THEN the system SHALL CONTINUE TO use the existing font sizes (24px values, 13px titles) and padding (20px) for summary cards

---

## Bug Condition (Formal)

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type ScreenRenderInput { screenWidth: double, screenName: string }
  OUTPUT: boolean
  
  // Returns true when mobile width AND affected screen
  RETURN X.screenWidth < 600 
    AND X.screenName IN {"StockEntryScreen", "StockReversalScreen", "BuyFlowDashboard"}
END FUNCTION
```

```pascal
// Property: Fix Checking — Mobile layouts render correctly
FOR ALL X WHERE isBugCondition(X) DO
  renderedLayout ← renderScreen'(X)
  IF X.screenName = "StockEntryScreen" OR X.screenName = "StockReversalScreen" THEN
    ASSERT renderedLayout.topLevelAxis = Axis.vertical
    ASSERT renderedLayout.hasNoHorizontalOverflow = true
    ASSERT renderedLayout.allTextReadable = true
  END IF
  IF X.screenName = "BuyFlowDashboard" THEN
    ASSERT renderedLayout.kpiCardsPerRow <= 2
    ASSERT renderedLayout.kpiCardMinWidth >= 140
    ASSERT renderedLayout.allTextReadable = true
  END IF
END FOR
```

```pascal
// Property: Preservation Checking — Desktop/tablet layouts unchanged
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT renderScreen(X) = renderScreen'(X)
END FOR
```
