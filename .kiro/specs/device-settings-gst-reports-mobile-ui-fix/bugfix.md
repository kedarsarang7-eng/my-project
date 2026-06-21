# Bugfix Requirements Document

## Introduction

The mobile (Android phone, viewport width < 600px) rendering of two screens in the Dukanx Flutter application — the **Device Settings** screen and the **GST Reports** screen — has UI/UX layout, responsiveness, and rendering defects. Section labels and titles render with broken/excessive letter-spacing (appearing to wrap or render character-by-character), card content and headers overflow off the screen edge, segmented controls and selector chips clip or wrap awkwardly, and AppBar titles/subtitles compete for space with action icons.

The desktop/Windows version of both screens renders correctly and MUST remain unchanged. The fix must be conditional on the mobile breakpoint (width < 600px) only, and must not alter tablet (600–1024px) or desktop (>1024px) layouts, nor any business logic.

This spec is scoped to **only** the Device Settings and GST Reports screens. A sibling spec (`cross-platform-mobile-responsiveness-fix`) already covers Process Return, New Estimate, New Purchase Order, Buy Orders, Catalogue, Funds Flow, Payment Reminders, Payment Gateway Settings, and Storage Management. Those screens are explicitly out of scope here to avoid overlap.

**Bug Condition:** The defect manifests when the screen width is less than 600px AND the active screen is `DeviceSettingsScreen` or `GstReportsScreen`.

**Target mobile viewports (where the bug appears):** 360×640, 393×851, 412×915.
**Preserved viewports (must be unchanged):** 768×1024, 1024×1366, 1920×1080.

## Bug Analysis

### Current Behavior (Defect)

What currently happens when either screen is rendered at a viewport width < 600px.

**Device Settings screen**

1.1 WHEN the Device Settings screen renders at width < 600px THEN the system displays section labels and card titles ("Push Notifications", "Auto Sync", "Cloud Backup", "Backup Frequency", "Default Tax Rate (GST)") with broken/excessive letter-spacing that wraps or renders character-by-character

1.2 WHEN the Device Settings screen renders at width < 600px THEN the system displays toggle subtitles ("Receive alerts and reminders", "Sync data automatically when online", "Auto-sync data to cloud storage") with awkward wrapping and spacing

1.3 WHEN the Device Settings screen renders at width < 600px THEN the system displays section headers ("GENERAL PREFERENCES", "DATA & BACKUP", "BILLING DEFAULTS") with spacing and alignment problems

1.4 WHEN the Device Settings screen renders at width < 600px THEN the system risks overflow of the "Default Tax Rate (GST)" row, where the "18%" badge/value and the percentage slider (0%–28%) do not reliably fit within the narrow viewport

1.5 WHEN a toggle row (icon + title + subtitle + switch) renders at width < 600px THEN the system risks RenderFlex overflow because the horizontal content exceeds the available width

**GST Reports screen**

1.6 WHEN the GST Reports screen renders at width < 600px THEN the system displays the "Period: 2..." card header text overflowing beyond the right edge of the screen, clipping the content at the screen boundary

1.7 WHEN the GST Reports screen renders at width < 600px THEN the system displays the segmented control (GSTR-1 / GSTR-3B / HSN) with labels that clip or wrap because the control is not sized for the narrow viewport

1.8 WHEN the GST Reports screen renders at width < 600px THEN the system displays the period selector chips (Month, Last Month, Quarter) wrapping without proper spacing

1.9 WHEN the GST Reports screen renders at width < 600px THEN the system displays the AppBar title "GST Reports", the subtitle "Generate GSTR-1, GSTR-3...", and the action icons (calendar, refresh) competing for space, with the subtitle truncated

### Expected Behavior (Correct)

What should happen instead when either screen is rendered at a viewport width < 600px. Each clause corresponds to the defect with the same trailing condition.

**Device Settings screen**

2.1 WHEN the Device Settings screen renders at width < 600px THEN the system SHALL render section labels and card titles with normal letter-spacing on a single line, using ellipsis or a responsive font size so text never renders character-by-character or vertically

2.2 WHEN the Device Settings screen renders at width < 600px THEN the system SHALL render toggle subtitles with normal spacing, wrapping cleanly to at most two lines with ellipsis as needed

2.3 WHEN the Device Settings screen renders at width < 600px THEN the system SHALL render section headers with correct spacing and alignment consistent with a mobile-first layout

2.4 WHEN the Device Settings screen renders at width < 600px THEN the system SHALL lay out the "Default Tax Rate (GST)" row so the "18%" badge/value and the percentage slider (0%–28%) fit fully within the viewport and remain usable, stacking vertically if needed

2.5 WHEN a toggle row (icon + title + subtitle + switch) renders at width < 600px THEN the system SHALL render the row without RenderFlex overflow, keeping the icon, title, subtitle, and switch all visible and within bounds

**GST Reports screen**

2.6 WHEN the GST Reports screen renders at width < 600px THEN the system SHALL render the period card header text fully within the screen bounds with no horizontal overflow, using wrapping or ellipsis as appropriate

2.7 WHEN the GST Reports screen renders at width < 600px THEN the system SHALL size the segmented control (GSTR-1 / GSTR-3B / HSN) responsively so all labels are readable without clipping

2.8 WHEN the GST Reports screen renders at width < 600px THEN the system SHALL lay out the period selector chips (Month, Last Month, Quarter) with proper spacing, wrapping cleanly when needed

2.9 WHEN the GST Reports screen renders at width < 600px THEN the system SHALL fit the AppBar title, subtitle, and action icons within the available width, with the title on a single line and the subtitle handled responsively (ellipsis or hidden) so content does not overflow

### Unchanged Behavior (Regression Prevention)

Existing behavior that MUST be preserved. These cover non-buggy inputs (width ≥ 600px) and all business logic.

3.1 WHEN the Device Settings screen renders at width ≥ 600px (tablet 600–1024px or desktop >1024px) THEN the system SHALL CONTINUE TO render the existing desktop/tablet layout unchanged

3.2 WHEN the GST Reports screen renders at width ≥ 600px (tablet 600–1024px or desktop >1024px) THEN the system SHALL CONTINUE TO render the existing desktop/tablet layout unchanged

3.3 WHEN either screen renders at the preserved viewports 768×1024, 1024×1366, or 1920×1080 THEN the system SHALL CONTINUE TO render exactly as it did before the fix

3.4 WHEN a user interacts with Device Settings controls (toggles, backup frequency selection, tax rate slider) at any viewport width THEN the system SHALL CONTINUE TO apply and persist the same settings values and behavior as before

3.5 WHEN a user interacts with GST Reports controls (report type selection, period selection, calendar, refresh) at any viewport width THEN the system SHALL CONTINUE TO generate and display the same report data and behavior as before

3.6 WHEN any other screen in the application renders at any viewport width THEN the system SHALL CONTINUE TO render unchanged, since this fix is scoped only to Device Settings and GST Reports

3.7 WHEN screens covered by the sibling `cross-platform-mobile-responsiveness-fix` spec render at any viewport width THEN the system SHALL CONTINUE TO behave as defined by that spec, with no interference from this fix
