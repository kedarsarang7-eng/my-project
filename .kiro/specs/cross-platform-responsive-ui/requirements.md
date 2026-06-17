# Requirements Document

## Introduction

Dukan_x is a multi-business-type POS and business management Flutter application that targets Android phones and tablets, iPhones and iPads, Windows desktop, and Web. The application currently contains two overlapping responsive utility systems, a compile-blocking broken reference to a missing `MobileDrawer`, and a large number of business-type feature modules whose screens were authored primarily for the fixed desktop layout. As a result, the same feature can render inconsistently, overflow, clip, or break when shown on smaller form factors or under orientation changes, keyboard insets, and accessibility font scaling.

This feature defines a single, centralized responsive architecture and a stability initiative so that every feature works consistently across all business-type screens and supported platforms from a single implementation. Mobile and tablet screens must adapt dynamically to available space and orientation, while the existing desktop layout (fixed left sidebar, top navigation bar, centered content host) must remain unchanged. The initiative also covers eliminating layout-break classes of bugs, guaranteeing crash-free and freeze-free operation, optimizing per-platform performance, consolidating the duplicate responsive utilities, repairing the broken `MobileDrawer` reference, and establishing testability for responsive and stability regressions.

The scope is intentionally limited to UI responsiveness, layout stability, navigation adaptation, per-platform performance, and the supporting architecture and tests. Business logic, data models, and backend behavior are out of scope except where required to surface graceful error handling in the UI.

## Glossary

- **Application**: The Dukan_x Flutter application across all supported platforms.
- **Supported_Platform**: Any of Android phone, Android tablet, iPhone, iPad, Windows desktop, or Web.
- **Form_Factor**: A device class derived from screen width and platform, classified as Mobile, Tablet, or Desktop.
- **Responsive_System**: The single, centralized responsive architecture (breakpoints, context extensions, adaptive widgets, and value selectors) that all screens consume. This is the consolidation of the current `lib/core/responsive/responsive_layout.dart` and `lib/core/theme/responsive_layout.dart` into one authoritative source.
- **Breakpoint_Strategy**: The defined width thresholds that classify a `Form_Factor` (Mobile below 600 logical pixels, Tablet from 600 to below 1100 logical pixels, Desktop at 1100 logical pixels and above).
- **Adaptive_Shell**: The widget at `lib/core/responsive/adaptive_shell.dart` that selects the correct shell for the current `Form_Factor`.
- **Desktop_Shell**: The existing desktop layout rooted at `lib/widgets/desktop/desktop_root_shell.dart`, consisting of a fixed left sidebar, a top navigation bar, and a centered content host.
- **Mobile_Shell**: The mobile layout consisting of an app bar, a bottom navigation bar, and a navigation drawer.
- **Tablet_Shell**: The tablet layout, which uses a compact sidebar in landscape and an app bar with bottom navigation in portrait.
- **Mobile_Drawer**: The navigation drawer widget referenced by `Adaptive_Shell` for mobile and tablet shells, currently missing and causing a compile error.
- **Business_Screen**: Any screen under `lib/features/` belonging to a business-type module (for example academic_coaching, auto_parts, billing, clothing, computer_shop, customers, decoration_catering, clinic, jewellery, hardware, purchase, and all other feature modules).
- **Responsive_Component**: Any reusable UI element subject to responsive behavior, including dialogs, bottom sheets, drawers, navigation menus, forms, tables, cards, lists, and charts.
- **Overflow_Error**: A Flutter render-time layout failure, including RenderFlex overflow, pixel overflow warnings, clipped content, and unbounded-constraint exceptions.
- **Accessibility_Font_Scaling**: The system text scale factor reported by the platform, used to enlarge or reduce text for accessibility.
- **Safe_Area**: The screen region free of notches, status bars, system gesture areas, and home indicators.
- **Responsive_Audit**: The codebase-wide review that identifies every file, component, layout, and configuration that must change for responsiveness and stability.
- **Developer**: A maintainer of the Dukan_x codebase.
- **End_User**: A person using the Application on any `Supported_Platform`.

## Requirements

### Requirement 1: Centralized Responsive Architecture and Breakpoint Strategy

**User Story:** As a Developer, I want a single centralized responsive system with one breakpoint strategy, so that every screen adapts consistently and responsive behavior is maintainable.

#### Acceptance Criteria

1. THE Responsive_System SHALL expose exactly one authoritative source for breakpoints, Form_Factor classification, context extensions, adaptive widgets, and responsive value selectors.
2. WHILE screen width is below 600 logical pixels, THE Responsive_System SHALL classify the Form_Factor as Mobile.
3. WHILE screen width is from 600 logical pixels to below 1100 logical pixels, THE Responsive_System SHALL classify the Form_Factor as Tablet.
4. WHILE screen width is 1100 logical pixels or above, THE Responsive_System SHALL classify the Form_Factor as Desktop.
5. WHEN a Developer requests a value that varies by Form_Factor and a value is defined for the current Form_Factor, THE Responsive_System SHALL return the value defined for the current Form_Factor.
6. THE Responsive_System SHALL provide context helpers for Form_Factor, orientation, keyboard visibility, Safe_Area insets, and Accessibility_Font_Scaling.
7. IF a Developer requests a value that varies by Form_Factor and no value is defined for the current Form_Factor, THEN THE Responsive_System SHALL return the value defined for the next-smaller Form_Factor that has a defined value, or the value of the smallest Form_Factor that has a defined value when no smaller value exists.
8. WHEN screen width changes such that it crosses a Breakpoint_Strategy boundary, THE Responsive_System SHALL re-classify the Form_Factor and update the values returned by responsive value selectors to match the newly classified Form_Factor.

### Requirement 2: Consolidation of Duplicate Responsive Utilities

**User Story:** As a Developer, I want the duplicate and conflicting responsive utilities reconciled into one system, so that there is no ambiguity about which breakpoints and helpers to use.

#### Acceptance Criteria

1. THE Responsive_System SHALL consolidate the responsive utilities currently defined in `lib/core/responsive/responsive_layout.dart` and `lib/core/theme/responsive_layout.dart` into a single authoritative source located under `lib/core/responsive/`, such that exactly one definition remains for each breakpoint, Form_Factor classifier, context extension, adaptive widget, and responsive value selector.
2. WHERE a screen previously consumed the legacy utilities in `lib/core/theme/responsive_layout.dart`, THE Application SHALL produce through the consolidated Responsive_System the same Form_Factor classification and the same responsive values that the legacy utilities produced for identical screen width, orientation, and input values.
3. THE Responsive_System SHALL define exactly one set of breakpoint thresholds for Form_Factor classification, matching the Breakpoint_Strategy defined in Requirement 1 (Mobile below 600 logical pixels, Tablet from 600 logical pixels to below 1100 logical pixels, Desktop at 1100 logical pixels and above).
4. IF two responsive utilities define conflicting breakpoint thresholds, THEN THE Responsive_System SHALL resolve the conflict to the single Breakpoint_Strategy defined in Requirement 1.
5. THE Responsive_System SHALL be the only source in the codebase that defines breakpoint thresholds and Form_Factor classification logic, and the legacy utilities at `lib/core/theme/responsive_layout.dart` SHALL NOT define breakpoint thresholds or Form_Factor classification independently of the Responsive_System.
6. THE Application SHALL compile without errors and SHALL contain no references to responsive utility symbols that have been removed or deprecated during the consolidation.

### Requirement 3: Repair of the Broken Mobile Drawer Reference

**User Story:** As a Developer, I want the missing Mobile_Drawer implemented so that the application compiles and mobile and tablet navigation works.

#### Acceptance Criteria

1. THE Application SHALL provide a Mobile_Drawer implementation that satisfies the import referenced by `lib/core/responsive/adaptive_shell.dart`.
2. THE Application SHALL compile without the error caused by the missing `mobile_drawer.dart` reference.
3. WHILE the Form_Factor is Mobile or Tablet, WHEN the End_User opens the navigation drawer, THE Mobile_Drawer SHALL display every navigation destination enabled for the active business context.
4. WHEN the End_User selects a destination in the Mobile_Drawer, THE Application SHALL navigate to the screen associated with the selected destination.
5. WHEN the Application completes navigation to the selected screen, THE Mobile_Drawer SHALL close.
6. IF the End_User selects a destination whose associated screen cannot be resolved, THEN THE Application SHALL retain the current screen, keep the Mobile_Drawer open, and present an error indication that the selected destination is unavailable.

### Requirement 4: Single-Implementation Adaptive Screens Across Form Factors

**User Story:** As a Developer, I want each feature built once and adapt automatically, so that I do not maintain separate screen implementations per form factor.

#### Acceptance Criteria

1. WHEN a Business_Screen is displayed on any Supported_Platform, THE Application SHALL render that screen from a single screen implementation that applies the layout defined by the Responsive_System for the current Form_Factor, without using a separate per-Form_Factor implementation.
2. WHEN the Form_Factor changes at runtime, THE Application SHALL reflow the displayed Business_Screen to the layout defined for the new Form_Factor through the Responsive_System without an Overflow_Error and without loading a separate screen implementation.
3. WHERE a new Business_Screen is added, THE Application SHALL render that screen across Mobile, Tablet, and Desktop Form_Factors through the Responsive_System from a single implementation without a separate per-Form_Factor screen.
4. WHILE the Form_Factor is Mobile or Tablet, WHEN the content of a displayed Business_Screen exceeds the available height, THE Application SHALL make the content vertically scrollable so that all content is reachable without an Overflow_Error.
5. IF a displayed Business_Screen does not define an adaptive layout for the current Form_Factor, THEN THE Application SHALL render the screen using the Responsive_System default layout for that Form_Factor without an Overflow_Error.

### Requirement 5: Preservation of the Existing Desktop Layout and Navigation

**User Story:** As an End_User on Windows desktop, I want the current desktop layout and navigation preserved, so that my established workflow does not change.

#### Acceptance Criteria

1. WHERE the Form_Factor is Desktop, THE Adaptive_Shell SHALL render the Desktop_Shell as the active layout.
2. WHILE the Desktop_Shell is the active layout, THE Desktop_Shell SHALL display the fixed left sidebar, the top navigation bar, and the centered content host simultaneously.
3. WHEN the End_User selects a navigation destination on Desktop, THE Desktop_Shell SHALL open the corresponding screen within the centered content host within 1 second.
4. WHEN the End_User selects a navigation destination on Desktop, THE Desktop_Shell SHALL mark that destination as the active selection.
5. THE Application SHALL retain the existing set of Desktop_Shell navigation destinations without adding or removing any destination.
6. WHEN the End_User activates a full-screen or distraction-free view on Desktop, THE Desktop_Shell SHALL hide the left sidebar and the top navigation bar while keeping the centered content host visible.
7. WHEN the End_User exits the full-screen or distraction-free view, THE Desktop_Shell SHALL restore the left sidebar and the top navigation bar to their pre-hidden arrangement and SHALL retain the navigation destination that was selected before the view was activated.

### Requirement 6: Orientation, Keyboard, Safe Area, and Accessibility Font Scaling

**User Story:** As an End_User on a mobile or tablet device, I want screens to handle rotation, the on-screen keyboard, device cutouts, and enlarged fonts, so that content stays accessible and uncut.

#### Acceptance Criteria

1. WHEN the device orientation changes, THE Application SHALL reflow the displayed screen to fit the new orientation within 1 second without an Overflow_Error.
2. WHEN the on-screen keyboard becomes visible, THE Application SHALL keep the entire focused input field visible above the keyboard.
3. WHEN the on-screen keyboard becomes visible, THE Application SHALL adjust the displayed layout to the reduced available height without an Overflow_Error.
4. THE Application SHALL render all interactive content within the Safe_Area on devices with notches, status bars, or home indicators so that no interactive control is clipped or overlapped by system insets.
5. WHEN Accessibility_Font_Scaling is increased to any level from 100% up to the platform maximum, THE Application SHALL display all text without an Overflow_Error by wrapping, truncating with an ellipsis, or scrolling.
6. WHILE Accessibility_Font_Scaling is active, THE Application SHALL keep all interactive controls reachable through scrolling and operable with a minimum touch target of 44 by 44 logical pixels.
7. IF displayed content cannot fit the available viewport after a reflow, THEN THE Application SHALL provide scrolling so that all content remains reachable without data loss.

### Requirement 7: Elimination of Overflow, Clipping, and Unbounded-Constraint Bugs

**User Story:** As an End_User, I want screens to render without overflow or clipping, so that I can read and use all content on any device size.

#### Acceptance Criteria

1. WHEN any Business_Screen or Responsive_Component is displayed at any screen width from 320 logical pixels to 3840 logical pixels, THE Application SHALL render it without an Overflow_Error.
2. IF a layout would exceed its bounded constraints, THEN THE Application SHALL constrain, wrap, or scroll the content so that all content remains fully visible within its bounds and no Overflow_Error is produced.
3. WHERE a widget unexpectedly requires bounds that are not provided, THE Application SHALL apply bounded constraints derived from the available space of the enclosing parent and SHALL continue rendering without an unbounded height or width exception.
4. THE Application SHALL provide bounded constraints to widgets that require them so that unbounded height or width exceptions do not occur.
5. WHEN flexible layout widgets are used within a constrained axis, THE Application SHALL size their children within the available space without an Overflow_Error.
6. WHEN nested scrollable regions are present and the End_User performs a scroll gesture, THE Application SHALL direct the scroll to the innermost scrollable region located under the scroll gesture so that this region responds to the scrolling.
7. WHEN text exceeds its available width, THE Application SHALL wrap the text within the available width or truncate the text with a trailing ellipsis so that the text does not produce an Overflow_Error.

### Requirement 8: Per-Component Responsiveness

**User Story:** As an End_User, I want dialogs, sheets, drawers, menus, forms, tables, cards, lists, and charts to fit my screen, so that every interaction is usable across devices.

#### Acceptance Criteria

1. WHEN a dialog is displayed, THE Application SHALL size the dialog so that its width does not exceed the available Safe_Area width and its height does not exceed the available Safe_Area height for the current Form_Factor, and SHALL render the dialog without an Overflow_Error.
2. IF the content of a displayed dialog exceeds the available height, THEN THE Application SHALL make the dialog content scrollable so that every part of the content is reachable without an Overflow_Error.
3. WHEN a bottom sheet is displayed, THE Application SHALL constrain the bottom sheet height to no more than 90 percent of the available Safe_Area height for the current Form_Factor and SHALL render the bottom sheet without an Overflow_Error.
4. IF the content of a displayed bottom sheet exceeds its constrained height, THEN THE Application SHALL make the bottom sheet content scrollable so that every part of the content is reachable without an Overflow_Error.
5. WHEN a form is displayed, THE Application SHALL arrange the form fields within the available Safe_Area width for the current Form_Factor and SHALL render the form without an Overflow_Error.
6. IF the form fields exceed the available height, THEN THE Application SHALL make the form scrollable so that every form field is reachable without an Overflow_Error.
7. WHEN a table's content width exceeds the available width, THE Application SHALL either enable horizontal scrolling of the table or reflow the table into a layout whose width does not exceed the available width, and SHALL render the table without an Overflow_Error.
8. WHEN cards or lists are displayed, THE Application SHALL set the column count or item layout to the value defined for the current Form_Factor and SHALL render the cards or lists without an Overflow_Error.
9. WHEN a chart is displayed, THE Application SHALL size the chart so that its width and height do not exceed the available Safe_Area dimensions for the current Form_Factor and SHALL render the chart without an Overflow_Error.

### Requirement 9: Navigation Consistency Across Form Factors

**User Story:** As an End_User, I want navigation to behave consistently regardless of device, so that I can reach the same features on any platform.

#### Acceptance Criteria

1. WHERE the Form_Factor is Mobile, THE Adaptive_Shell SHALL render the Mobile_Shell with a bottom navigation bar and a navigation drawer.
2. WHERE the Form_Factor is Tablet, THE Adaptive_Shell SHALL render the Tablet_Shell using the layout defined for the current device orientation, presenting the portrait layout while the device is in portrait orientation and the landscape layout while the device is in landscape orientation.
3. THE Adaptive_Shell SHALL render the Tablet_Shell only when the Form_Factor is Tablet and SHALL NOT render the Tablet_Shell on Mobile or Desktop Form_Factors.
4. THE Application SHALL expose an identical set of reachable destinations across Mobile, Tablet, and Desktop Form_Factors for a given business context, such that every destination reachable on one Form_Factor is reachable on the other two.
5. WHEN the End_User selects a destination on any Form_Factor, THE Application SHALL navigate to the screen corresponding to that destination within 1 second.
6. IF navigation to a selected destination cannot proceed due to insufficient permissions or an unavailable dependency, THEN THE Application SHALL block the navigation, SHALL keep the End_User on the current screen, and SHALL display an error message indicating the reason the destination is unavailable.
7. WHEN the current screen changes, THE Application SHALL reflect the active destination in the navigation surface for the current Form_Factor within 500 milliseconds.
8. WHERE the Form_Factor is Tablet, WHEN the device orientation changes between portrait and landscape, THE Adaptive_Shell SHALL re-render the Tablet_Shell to the layout for the new orientation within 500 milliseconds.

### Requirement 10: Crash-Free and Freeze-Free Stability

**User Story:** As an End_User, I want the application to stay responsive and never crash or freeze, so that I can complete my work without interruption.

#### Acceptance Criteria

1. WHEN the End_User navigates between screens on any Supported_Platform, THE Application SHALL complete the navigation without terminating unexpectedly.
2. WHILE the End_User performs operations on any screen on any Supported_Platform, THE Application SHALL provide visible feedback to each user input within 100 milliseconds.
3. IF a screen encounters a runtime error during rendering, THEN THE Application SHALL display a recoverable error state on the affected screen and SHALL keep all other screens navigable and operable.
4. IF an operation fails, THEN THE Application SHALL display an error message indicating the cause of the failure and SHALL keep the Application usable without requiring a restart.
5. WHEN an operation that takes longer than 1 second to complete begins, THE Application SHALL display a progress indicator and SHALL keep the progress indicator visible until the operation completes.
6. THE Application SHALL execute operations on any Supported_Platform without blocking its main UI thread for more than 5 consecutive seconds.

### Requirement 11: Per-Platform Performance and Optimization

**User Story:** As an End_User, I want fast and efficient performance on my platform, so that the application feels smooth and consistent.

#### Acceptance Criteria

1. WHEN the End_User triggers a navigation between screens, THE Application SHALL display the target screen within 300 milliseconds, with an allowed tolerance of up to 320 milliseconds measured from the navigation trigger, on supported reference hardware.
2. WHILE the End_User is scrolling a list, table, or grid and no data load is in progress, THE Application SHALL maintain a frame rate of at least 60 frames per second on supported reference hardware.
3. WHEN the Form_Factor changes at runtime, THE Application SHALL complete the layout reflow within 300 milliseconds, with an allowed tolerance of up to 320 milliseconds, on supported reference hardware.
4. WHILE a screen's hide transition is in progress, THE Application SHALL retain that screen's resources until the screen is completely hidden and the hide transition is finished.
5. WHILE a data load is in progress during scrolling of a list, table, or grid, THE Application SHALL keep any drop below 60 frames per second to a continuous duration of no more than 500 milliseconds and SHALL then return to at least 60 frames per second on supported reference hardware.
6. WHEN a screen is completely hidden and its hide transition is finished, THE Application SHALL release that screen's resources within 300 milliseconds on supported reference hardware.
7. IF the target screen cannot be displayed within 320 milliseconds of the navigation trigger, THEN THE Application SHALL display a loading indicator until the target screen is displayed.

### Requirement 12: Responsive Audit Coverage

**User Story:** As a Developer, I want a complete audit of files and components needing responsive changes, so that no screen or shared component is missed.

#### Acceptance Criteria

1. THE Responsive_Audit SHALL identify every Business_Screen under `lib/features/` that, on the Mobile, Tablet, or Desktop Form_Factor, produces an Overflow_Error, clips content, or fails to apply a layout through the Responsive_System.
2. THE Responsive_Audit SHALL identify every shared layout component and Responsive_Component that is consumed by two or more Business_Screens and that produces an Overflow_Error or fails to adapt through the Responsive_System.
3. THE Responsive_Audit SHALL identify every navigation structure that exposes a different set of reachable destinations or a different selection behavior across the Mobile, Tablet, and Desktop Form_Factors.
4. THE Responsive_Audit SHALL identify every responsive configuration, theme, or layout utility that defines breakpoints, Form_Factor classification, or responsive values outside the Responsive_System.
5. THE Responsive_Audit SHALL record, for each identified item, the conditions under which the item fails, covering the Mobile, Tablet, and Desktop Form_Factors, portrait and landscape orientation, and Accessibility_Font_Scaling from 100% up to the platform maximum.
6. THE Responsive_Audit SHALL classify every Business_Screen under `lib/features/`, every shared layout component, and every Responsive_Component as either compliant or non-compliant with the Responsive_System so that no screen or shared component is left unclassified.

### Requirement 13: Responsive and Stability Testability

**User Story:** As a Developer, I want automated tests for responsive layout and stability, so that regressions are caught before deployment.

#### Acceptance Criteria

1. THE Application SHALL provide automated tests that render at least one representative Business_Screen for each feature module under `lib/features/` and each Responsive_Component type at a Mobile width below 600 logical pixels, a Tablet width from 600 to below 1100 logical pixels, and a Desktop width of 1100 logical pixels or above, and that assert no Overflow_Error is produced at each width.
2. THE Application SHALL provide automated tests that render representative screens under Accessibility_Font_Scaling from the platform default up to the platform maximum and that assert no Overflow_Error is produced at each tested scale.
3. THE Application SHALL provide automated tests that render representative screens in portrait orientation, in landscape orientation, and with a keyboard inset applied, and that assert no Overflow_Error is produced under each condition.
4. THE Application SHALL provide automated tests that, for a width within each of the Mobile, Tablet, and Desktop Form_Factor bands, verify the Adaptive_Shell selects the Mobile_Shell, Tablet_Shell, or Desktop_Shell that corresponds to that Form_Factor.
5. WHEN the automated responsive test suite runs, THE Application SHALL report a failure for any screen that produces an Overflow_Error during the test.
6. IF the automated responsive test suite does not run to completion, THEN THE Application SHALL report a test failure indicating that the suite did not finish.
7. WHEN an automated responsive test detects a violation other than an Overflow_Error, including content rendered outside the Safe_Area, an interactive control that is unreachable or positioned outside the viewport, or a render-time exception, THE Application SHALL report a test failure for that violation even when no Overflow_Error is detected.
