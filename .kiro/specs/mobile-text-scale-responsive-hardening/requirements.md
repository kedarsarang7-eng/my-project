# Requirements Document

## Introduction

DukanX is a multi-business Flutter application (retail, restaurant, jewellery, computer shop, clinic, academic coaching, pharmacy, and more) that runs on Android phones, tablets, and Windows desktop. On Android devices where the system or in-app font size is raised above the default (1.0x) for accessibility, many screens overflow, clip, overlap, or wrap awkwardly — even though two prior specs (`cross-platform-mobile-responsiveness-fix` and `device-settings-gst-reports-mobile-ui-fix`) were marked 100% complete. The prior work regressed silently because its widget tests rendered only at the default text scale (1.0), so text-scale-driven overflow was never exercised.

This feature hardens the entire app against text-scale-driven and viewport-driven layout failures. It establishes exactly one coherent, clamped text-scale source, removes the conflicting/dead double-scaling path, applies consistent overflow-safe responsive principles across all feature screens and all business types, and — critically — requires that every correctness criterion be validated by tests that render at elevated text scales (1.0, 1.3, and an above-cap value) and across representative mobile viewport widths. The Windows desktop render path must remain unchanged (platform-freeze constraint).

This is a hardening/quality feature: it changes layout robustness and the text-scale pipeline. It does not add new business functionality.

## Glossary

- **DukanX_App**: The Flutter application root defined in `lib/app/app.dart`, which hosts the `MaterialApp` and its `builder`.
- **Text_Scale_Pipeline**: The single, coherent mechanism that determines the effective `TextScaler` applied to the widget tree, sourced from system/app font settings and clamped to a maximum.
- **Text_Scale_Cap**: The maximum effective linear text-scale factor applied on non-Windows platforms. Current value is `kMaxTextScaleFactor = 1.3`.
- **Above_Cap_Scale**: Any requested text-scale value strictly greater than the Text_Scale_Cap (for example, 2.0 or 2.6), used to prove the cap holds.
- **Accessibility_Theme_Builder**: The `AccessibilityThemeBuilder` widget in `lib/core/theme/accessibility_theme.dart` that currently applies text scaling twice (via `textTheme.fontSizeFactor` and a nested `MediaQuery.textScaler`) and is not mounted in the widget tree.
- **Overflow_Safe_Widget**: A text or layout widget configured so its content degrades gracefully under elevated text scale and narrow viewports — using mechanisms such as `Flexible`/`Expanded`, `FittedBox`, `maxLines` with `TextOverflow.ellipsis`, `Wrap`, `SingleChildScrollView`, or constrained/`Flexible` containers — instead of overflowing, clipping, or overlapping.
- **Mobile_Viewport**: A logical screen size representative of common Android phones. The reference viewports are 360x640, 393x851, and 412x915 logical pixels.
- **Elevated_Text_Scale**: A text-scale factor greater than 1.0. The reference values are 1.0 (baseline), 1.3 (at cap), and an Above_Cap_Scale.
- **Responsive_Test_Harness**: The shared test utilities that render a screen or widget under a chosen Mobile_Viewport and Elevated_Text_Scale and assert the absence of overflow.
- **Overflow_Failure**: Any Flutter render-time overflow (e.g., a `RenderFlex overflowed` error), clipped text that hides meaningful content, or visual overlap between distinct text/value elements.
- **Feature_Screen**: Any user-facing screen under `lib/features/**` belonging to any business type.
- **Windows_Render_Path**: The layout and text-scale behavior of DukanX_App when running on Windows, which must remain unchanged.
- **Totals_Card**: The Subtotal/Discount/Total summary component on the New Estimate screen.
- **PO_Info_Banner**: The informational banner on the New Purchase Order screen ("Purchase Orders are created as PENDING. You can convert…").
- **GST_Reports_Screen**: The GST Reports screen containing the "Period:" header and the GSTR-1/GSTR-3B/HSN segmented control.
- **App_Bar_Header**: A screen app bar that displays a title and an optional subtitle (e.g., "Device Settings / Configure device-specific preferences").

## Requirements

### Requirement 1: Single coherent text-scale source

**User Story:** As a DukanX user who raises the system font size, I want the app to apply font scaling exactly once through one predictable path, so that text is not double-scaled, inconsistent, or unexpectedly enormous.

#### Acceptance Criteria

1. THE DukanX_App SHALL apply exactly one Text_Scale_Pipeline to the widget tree as the single source of effective text scaling.
2. WHERE the platform is not Windows, THE Text_Scale_Pipeline SHALL clamp the effective linear text-scale factor to a maximum of the Text_Scale_Cap (1.3).
3. IF a requested text-scale factor is an Above_Cap_Scale, THEN THE Text_Scale_Pipeline SHALL apply the Text_Scale_Cap value instead of the requested value on non-Windows platforms.
4. WHERE a requested text-scale factor is at or below the Text_Scale_Cap, THE Text_Scale_Pipeline SHALL apply the requested factor unchanged on non-Windows platforms.
5. THE DukanX_App SHALL NOT apply both `textTheme.fontSizeFactor` scaling and a separate `MediaQuery.textScaler` scaling to the same widget subtree.

### Requirement 2: Reconcile the dead/conflicting accessibility scaling code

**User Story:** As a developer maintaining DukanX, I want the conflicting Accessibility_Theme_Builder code reconciled, so that there is no dead or double-scaling code that can silently reintroduce overflow bugs.

#### Acceptance Criteria

1. THE DukanX_App SHALL either mount the Accessibility_Theme_Builder so that it feeds the single Text_Scale_Pipeline, or remove the Accessibility_Theme_Builder, so that no unmounted double-scaling widget remains in the codebase.
2. WHERE the Accessibility_Theme_Builder is retained, THE Accessibility_Theme_Builder SHALL contribute to text scaling through the single Text_Scale_Pipeline and SHALL produce an effective text-scale factor clamped to the Text_Scale_Cap on non-Windows platforms.
3. WHERE the Accessibility_Theme_Builder is retained, THE Accessibility_Theme_Builder SHALL apply text scaling through a single mechanism rather than combining `textTheme.fontSizeFactor` with a nested `MediaQuery.textScaler`.
4. WHEN accessibility text-scale settings are changed by the user, THE Text_Scale_Pipeline SHALL reflect the resulting effective factor clamped to the Text_Scale_Cap on non-Windows platforms.

### Requirement 3: App-wide overflow-safe text and layout

**User Story:** As an Android phone user across any business type, I want every screen to remain readable and non-overlapping when fonts are large, so that I can use the app without text colliding, clipping, or pushing content off-screen.

#### Acceptance Criteria

1. WHEN a Feature_Screen is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE Feature_Screen SHALL render without an Overflow_Failure.
2. WHEN a Feature_Screen is rendered at an Above_Cap_Scale on any Mobile_Viewport, THE Feature_Screen SHALL render without an Overflow_Failure.
3. WHERE a text element is placed inside a width-constrained or fixed-size container, THE text element SHALL be configured as an Overflow_Safe_Widget with bounded line count and ellipsis or shrink-to-fit behavior.
4. WHERE a label and its associated value are displayed on one row, THE row SHALL keep the label and value visually separated without overlap at every Elevated_Text_Scale up to the Text_Scale_Cap.
5. THE DukanX_App SHALL NOT use unbounded hardcoded font sizes inside narrow or fixed containers that lack an Overflow_Safe_Widget mechanism.

### Requirement 4: New Estimate Totals card

**User Story:** As a user creating an estimate on a phone with large fonts, I want the Subtotal, Discount, and Total rows to stay aligned and readable, so that I can verify amounts without labels overlapping the values.

#### Acceptance Criteria

1. WHEN the Totals_Card is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE Totals_Card SHALL display each label (Subtotal, Discount, Total) without overlapping its corresponding amount value.
2. WHEN the Totals_Card is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE Totals_Card SHALL render without an Overflow_Failure.
3. WHERE a Totals_Card amount value cannot fit on its row, THE amount value SHALL shrink-to-fit or truncate with ellipsis while remaining on a single visible row with its label.
4. WHERE a Totals_Card amount value fits on its row, THE amount value SHALL remain on a single visible row together with its label.

### Requirement 5: New Purchase Order info banner

**User Story:** As a user creating a purchase order on a phone with large fonts, I want the informational banner to wrap naturally, so that the message is readable instead of breaking into one word per line.

#### Acceptance Criteria

1. WHEN the PO_Info_Banner is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE PO_Info_Banner SHALL wrap its text across the available banner width rather than rendering one word per line.
2. WHEN the PO_Info_Banner is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE PO_Info_Banner SHALL render without an Overflow_Failure.
3. THE PO_Info_Banner text SHALL be bounded by the available banner content width so that it has a defined width constraint for wrapping.

### Requirement 6: GST Reports header and segmented control

**User Story:** As a user viewing GST Reports on a phone with large fonts, I want the period header and report-type selector to stay within the screen, so that I can read the period and switch report types without clipping.

#### Acceptance Criteria

1. WHEN the GST_Reports_Screen is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE "Period:" header SHALL remain within the horizontal screen bounds without clipping off the right edge.
2. WHEN the GST_Reports_Screen segmented control (GSTR-1/GSTR-3B/HSN) is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE segmented control SHALL display its options without clipping their labels.
3. WHEN the GST_Reports_Screen is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE GST_Reports_Screen SHALL render without an Overflow_Failure.

### Requirement 7: App bar title and subtitle

**User Story:** As a user navigating any screen on a phone with large fonts, I want app bar titles and subtitles to stay clear of the status bar and notch and not collide with each other, so that headers remain readable.

#### Acceptance Criteria

1. WHEN an App_Bar_Header is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE App_Bar_Header title and subtitle SHALL each be Overflow_Safe_Widgets with bounded line count and ellipsis.
2. WHEN an App_Bar_Header is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE App_Bar_Header SHALL render its title and subtitle without overlapping each other.
3. WHEN an App_Bar_Header is rendered on a Mobile_Viewport, THE App_Bar_Header content SHALL respect the device safe-area insets so that text does not collide with the status bar or notch.
4. WHEN an App_Bar_Header is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE App_Bar_Header SHALL render without an Overflow_Failure.
5. WHEN an App_Bar_Header is rendered at an Above_Cap_Scale on any Mobile_Viewport, THE App_Bar_Header title and subtitle SHALL retain Overflow_Safe_Widget protection so that text truncates rather than producing an Overflow_Failure.

### Requirement 8: Process Return search field

**User Story:** As a user processing a return on a phone with large fonts, I want the search field hint text to remain readable, so that I understand what to type without the hint being clipped.

#### Acceptance Criteria

1. WHEN the Process Return search field is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE search field hint SHALL be an Overflow_Safe_Widget that truncates with ellipsis rather than being cut off mid-glyph.
2. WHEN the Process Return search field is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE Process Return search field SHALL render without an Overflow_Failure.

### Requirement 9: Consistent responsive structure across the app

**User Story:** As a user of any business type, I want shared layout regions (KPI cards, navigation, sidebar/top-bar, content area, forms, tables, dialogs) to be responsive, so that the whole app behaves consistently across Android resolutions and font sizes.

#### Acceptance Criteria

1. WHEN a KPI card is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE KPI card SHALL size and position its title and value without an Overflow_Failure.
2. THE DukanX_App SHALL present back navigation consistently so that every Feature_Screen reachable by forward navigation, including modal dialogs and onboarding flows, provides a back or dismiss affordance.
3. WHEN a form field, data table, or dialog is rendered at any Elevated_Text_Scale up to the Text_Scale_Cap on any Mobile_Viewport, THE form field, data table, or dialog SHALL render its content without an Overflow_Failure.
4. WHERE content exceeds the available vertical space on a Mobile_Viewport at an Elevated_Text_Scale, THE Feature_Screen SHALL make the overflowing content scrollable rather than clipped.
5. THE DukanX_App SHALL apply theme background colors consistently so that a screen's background matches the active light or dark theme without mismatched regions.

### Requirement 10: Elevated-scale and multi-viewport test coverage

**User Story:** As a developer and as the product owner, I want every correctness criterion validated at elevated text scales and across mobile viewports, so that this class of regression can never again pass as "complete" while broken on-device.

#### Acceptance Criteria

1. THE Responsive_Test_Harness SHALL render a target screen or widget under a specified Mobile_Viewport and a specified Elevated_Text_Scale.
2. WHEN a hardening test executes, THE Responsive_Test_Harness SHALL exercise text-scale values of 1.0, the Text_Scale_Cap (1.3), and an Above_Cap_Scale.
3. WHEN a hardening test executes, THE Responsive_Test_Harness SHALL exercise the Mobile_Viewport widths 360x640, 393x851, and 412x915.
4. IF a target screen or widget produces an Overflow_Failure under any tested Elevated_Text_Scale and Mobile_Viewport combination, THEN THE hardening test SHALL fail.
5. THE hardening tests SHALL cover the Totals_Card, the PO_Info_Banner, the GST_Reports_Screen, the App_Bar_Header pattern, and the Process Return search field as explicit cases.
6. IF a hardening test does not exercise all required Elevated_Text_Scale values (1.0, the Text_Scale_Cap, and an Above_Cap_Scale) and all required Mobile_Viewport widths (360x640, 393x851, 412x915), THEN THE hardening test SHALL fail.

### Requirement 11: Windows platform-freeze

**User Story:** As a Windows desktop user of DukanX, I want my layout and behavior to remain exactly as before, so that the mobile hardening work does not regress the desktop experience.

#### Acceptance Criteria

1. WHERE the platform is Windows, THE Text_Scale_Pipeline SHALL pass the system text-scale factor through without applying the Text_Scale_Cap.
2. WHERE the platform is Windows, THE DukanX_App SHALL preserve the existing user-visible Windows_Render_Path layout and behavior, while internal refactors that do not change user-visible behavior are permitted.
3. WHEN a hardening change is applied to a Feature_Screen, THE change SHALL preserve the Windows_Render_Path behavior for that screen.
