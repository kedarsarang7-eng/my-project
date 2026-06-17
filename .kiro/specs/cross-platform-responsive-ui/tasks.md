# Implementation Plan: Cross-Platform Responsive UI

## Overview

This plan converts the design into incremental Dart/Flutter coding steps for Dukan_x. It builds the consolidated `Responsive_System` first (breakpoints, context helpers, value selector, adaptive primitives), then reconciles the duplicate utilities, produces the `Responsive_Audit`, repairs the missing `Mobile_Drawer`, wires the `Adaptive_Shell`/`Mobile_Shell`/`Tablet_Shell` with navigation parity, preserves the frozen `Desktop_Shell` (adding only the full-screen toggle), adds stability scaffolding, migrates `Business_Screen`s onto adaptive bodies, and finishes with the property-based and widget test harness.

Property-based tests use the project's established library `dartproptest ^0.2.1` with the convention `kNumRuns = 200` and the `forAll((args) => bool, [Gen...], numRuns: kNumRuns)` API. Each property test implements exactly one design property and is tagged `Feature: cross-platform-responsive-ui, Property {n}: {text}`. Test sub-tasks are marked optional with `*`; core implementation sub-tasks are never optional.

## Tasks

- [x] 1. Establish the consolidated Responsive_System foundation (breakpoints and classification)
  - [x] 1.1 Implement `lib/core/responsive/responsive_breakpoints.dart`
    - Define `enum FormFactor { mobile, tablet, desktop }` as the canonical type and retain `ScreenSize` as a synonym for migration
    - Implement `ResponsiveBreakpoints` with `mobileMax = 600`, `tabletMax = 1100`, `maxContentWidth = 1200`, and a pure `classify(double width)` as the single source of truth
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.3, 2.5_

  - [x]* 1.2 Write property test for Form_Factor classification
    - **Property 1: Form_Factor classification is correct at every width**
    - Generate widths including the exact boundaries 599, 600, 1099, 1100; assert `classify` returns Mobile iff `w < 600`, Tablet iff `600 <= w < 1100`, Desktop iff `w >= 1100`
    - File: `test/core/responsive/classification_property_test.dart`
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.8, 2.3, 2.4**

  - [x]* 1.3 Write property test for consolidation classification equivalence
    - **Property 2: Consolidation preserves classification (model-based)**
    - For any width, assert the consolidated `classify` returns the same `Form_Factor` as the pre-consolidation core classifier (`Breakpoints.mobile = 600`, `Breakpoints.tablet = 1100`)
    - File: `test/core/responsive/consolidation_equivalence_property_test.dart`
    - **Validates: Requirements 2.2**

- [x] 2. Implement context helpers and the responsive value selector
  - [x] 2.1 Implement `lib/core/responsive/responsive_context.dart`
    - Add `extension ResponsiveContext on BuildContext` exposing `formFactor`, `isMobile/isTablet/isDesktop`, `orientation`, `isPortrait/isLandscape`, `isKeyboardVisible`, `keyboardHeight`, `safeAreaPadding`, `textScale`, `screenWidth/screenHeight`, all derived from `MediaQuery` so boundary crossings trigger rebuilds and re-classification
    - _Requirements: 1.6, 1.8_

  - [x]* 2.2 Write widget test for context helpers
    - Pump a probe widget under controlled `MediaQuery` values and assert each helper reports the expected Form_Factor, orientation, keyboard visibility, safe-area insets, and text scale
    - File: `test/core/responsive/responsive_context_test.dart`
    - _Requirements: 1.6_

  - [x] 2.3 Implement `lib/core/responsive/responsive_value.dart`
    - Implement `T responsiveValue<T>(BuildContext, {T? mobile, T? tablet, T? desktop})` with the deterministic "current factor, else next-smaller defined, else smallest defined" fallback and an assertion that at least one value is provided (never returns null)
    - _Requirements: 1.5, 1.7_

  - [x]* 2.4 Write property test for responsive value selection and fallback
    - **Property 3: Responsive value selection and fallback**
    - Generate partial specs over `{mobile, tablet, desktop}` (at least one defined) and a current Form_Factor; assert the documented resolution order and non-null result
    - File: `test/core/responsive/responsive_value_property_test.dart`
    - **Validates: Requirements 1.5, 1.7**

- [x] 3. Implement adaptive primitives and the barrel export
  - [x] 3.1 Implement core adaptive primitives in `lib/core/responsive/adaptive_widgets.dart`
    - Add `AdaptiveScaffold` (drawer on mobile/tablet + safe area), `AdaptiveScroll` (scroll view with `ConstrainedBox(minHeight: viewport)`), `AdaptiveText` (softWrap/ellipsis defaults), and `BoundedBox` (`LayoutBuilder`-derived bounded constraints)
    - _Requirements: 4.4, 6.3, 6.4, 6.7, 7.2, 7.3, 7.4, 7.5, 7.7, 9.1_

  - [x] 3.2 Implement component adaptive primitives in `lib/core/responsive/adaptive_widgets.dart`
    - Add `AdaptiveDialog`, `AdaptiveSheet` (cap 90% safe-area height), `AdaptiveForm`, `AdaptiveTable` (horizontal scroll or card reflow), `AdaptiveGrid` (column count from `responsiveValue`), and `AdaptiveChartBox`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9_

  - [x] 3.3 Create the barrel `lib/core/responsive/responsive.dart`
    - Re-export breakpoints, context, value selector, all adaptive primitives, and the retained pre-existing widgets so call sites use one import
    - _Requirements: 1.1, 2.1_

  - [x]* 3.4 Write property test for per-component constraint invariants
    - **Property 10: Per-component constraint invariants**
    - Pump each component primitive under generated Form_Factor + content and assert dialog/sheet/table/grid/chart constraints hold
    - File: `test/core/responsive/component_invariants_property_test.dart`
    - **Validates: Requirements 8.1, 8.3, 8.7, 8.8, 8.9**

- [x] 4. Consolidate legacy utilities and remove duplicate breakpoint authority
  - [x] 4.1 Migrate consumers off `lib/core/theme/responsive_layout.dart` and remove its independent breakpoint/classification definitions
    - Repoint every consumer of the legacy 1280/1440/1920 API to the consolidated `Responsive_System` barrel; reduce the theme file so it no longer defines breakpoints or Form_Factor classification, keeping only desktop window-comfort helpers that defer to `ResponsiveBreakpoints`
    - _Requirements: 2.1, 2.4, 2.5, 2.6_

  - [-]* 4.2 Write static/compile guard test for single breakpoint authority
    - Assert `flutter analyze` has no missing/removed-symbol references and that no breakpoint thresholds or classifier are defined outside `Responsive_System`
    - File: `test/core/responsive/no_duplicate_breakpoints_test.dart`
    - _Requirements: 2.5, 2.6_

- [~] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Build the Responsive_Audit
  - [x] 6.1 Implement the audit scanner `tool/responsive_audit.dart`
    - Statically flag files importing the legacy `core/theme/responsive_layout.dart` breakpoint API, hand-rolled `MediaQuery...size.width` breakpoint comparisons defined outside `Responsive_System`, and screens not wrapped in an adaptive body; emit a machine-readable inventory seed
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [x] 6.2 Produce the inventory document `docs/responsive-audit.md`
    - Classify every `Business_Screen` under `lib/features/`, every shared layout component, and every `Responsive_Component` as `compliant` or `non-compliant`, recording per item the failing conditions (Form_Factor, orientation, font scale)
    - _Requirements: 12.1, 12.5, 12.6_

  - [-]* 6.3 Write property test for audit classification totality
    - **Property 11: Audit classification is total and disjoint**
    - Over the enumerated scanned universe, assert each item receives exactly one classification (none unclassified, none classified twice)
    - File: `test/tool/responsive_audit_totality_property_test.dart`
    - **Validates: Requirements 12.6**

- [x] 7. Repair the Mobile_Drawer and destination resolution
  - [x] 7.1 Implement pure navigation helpers in `lib/core/responsive/navigation_destinations.dart`
    - Add `reachableDestinationIds(List<SidebarSection>)` and `DestinationResolver.resolve(id, navigable)` returning `(DestinationResolution, AppScreen)` with `unavailable` when `AppScreen.fromId` is `unknown` or the screen is not navigable
    - _Requirements: 3.4, 3.6, 9.4, 9.6_

  - [x]* 7.2 Write property test for destination resolution outcome
    - **Property 6: Destination resolution outcome**
    - Generate valid and invalid ids plus a navigable set; assert resolution is `resolved` (navigates) or `unavailable` (retains current screen), mutually exclusive and total
    - File: `test/core/responsive/destination_resolution_property_test.dart`
    - **Validates: Requirements 3.4, 3.6, 9.6**

  - [x]* 7.3 Write property test for destination parity across Form_Factors
    - **Property 5: Destination parity across Form_Factors**
    - Generate `SidebarSection` lists; assert the reachable id set derived for the mobile drawer equals the tablet drawer equals the desktop sidebar
    - File: `test/core/responsive/destination_parity_property_test.dart`
    - **Validates: Requirements 3.3, 9.4**

  - [x] 7.4 Implement `lib/core/responsive/mobile_drawer.dart`
    - Implement `MobileDrawer` (ConsumerWidget) consuming `sidebarSectionsProvider`, rendering sections/items as a scrollable, safe-area `ExpansionTile`/`ListTile` list highlighting the active destination; on tap use `DestinationResolver` to navigate and close on success, or keep open and show an inline error on `unavailable`. Satisfies the broken import in `adaptive_shell.dart`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 6.4_

  - [x]* 7.5 Write widget test for Mobile_Drawer behavior
    - Assert the drawer displays enabled destinations, closes after a resolvable selection, and stays open with an error indication on an unresolvable selection while retaining the current screen
    - File: `test/core/responsive/mobile_drawer_test.dart`
    - _Requirements: 3.3, 3.5, 3.6_

- [x] 8. Wire the Adaptive_Shell, shell selection, and active-destination reflection
  - [x] 8.1 Update `lib/core/responsive/adaptive_shell.dart`
    - Replace the broken `MobileDrawer` reference with the real implementation, host `DesktopContentHost` in the Mobile/Tablet shell bodies, select shells via a pure selection function (Desktop delegate unchanged, Tablet by orientation, Mobile bottom nav + drawer), re-rendering on rotation
    - _Requirements: 5.1, 9.1, 9.2, 9.3, 9.8_

  - [-]* 8.2 Write property test for shell selection
    - **Property 4: Shell selection is a total function of Form_Factor**
    - Generate widths and orientations; assert Desktop iff `w >= 1100`, Tablet iff `600 <= w < 1100` (orientation variant), Mobile iff `w < 600`, and Tablet never on Mobile/Desktop
    - File: `test/core/responsive/shell_selection_property_test.dart`
    - **Validates: Requirements 5.1, 9.1, 9.2, 9.3, 13.4**

  - [x] 8.3 Implement active-destination reflection across navigation surfaces
    - Map `currentScreen` to the drawer highlight and `MobileBottomNav` selected index (and confirm desktop sidebar selection), updating each surface when `currentScreen` changes
    - _Requirements: 9.7, 5.4_

  - [-]* 8.4 Write property test for active destination reflecting the current screen
    - **Property 7: Active destination reflects the current screen**
    - For any `currentScreen`, assert each surface's reported active selection corresponds under its id/index mapping and updates on change
    - File: `test/core/responsive/active_destination_property_test.dart`
    - **Validates: Requirements 9.7, 5.4**

- [x] 9. Preserve the Desktop_Shell and add the full-screen toggle
  - [x] 9.1 Add `desktopChromeVisibleProvider` and wire the distraction-free toggle
    - Introduce the bool provider in a new file and have the desktop layout hide/show the sidebar and `EnterpriseTopBar` while keeping `DesktopContentHost` mounted so the selected destination survives the toggle; do not add/remove destinations or alter `desktop_root_shell.dart` structure
    - _Requirements: 5.6, 5.7_

  - [-]* 9.2 Write widget tests for desktop preservation
    - Assert sidebar + top bar + content render together, the active marker is set on selection, the destination set equals the frozen baseline snapshot, and the full-screen hide/restore round-trip retains the prior destination
    - File: `test/widgets/desktop/desktop_preservation_test.dart`
    - _Requirements: 5.2, 5.4, 5.5, 5.6, 5.7_

- [~] 10. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Add stability scaffolding for crash-free, freeze-free operation
  - [x] 11.1 Wire error isolation and async feedback patterns
    - Ensure every screen in `DesktopContentHost` is wrapped by `FeatureErrorBoundary` (recoverable error UI + Retry, others stay navigable), route operation failures through a consistent dismissible error channel, show a progress indicator for operations over ~1s, and show `AppLoadingIndicator` when a target screen is not ready within the latency budget
    - _Requirements: 10.3, 10.4, 10.5, 11.7_

  - [-]* 11.2 Write widget tests for stability behaviors
    - Inject a throwing screen and assert recovery UI shows while other destinations stay navigable; assert an operation failure shows a message and the app stays usable; assert a long operation shows progress and a delayed screen shows a loading indicator
    - File: `test/widgets/stability_test.dart`
    - _Requirements: 10.3, 10.4, 10.5, 11.7_

- [ ] 12. Migrate Business_Screens onto single-implementation adaptive bodies
  - [~] 12.1 Migrate representative high-traffic Business_Screens through the Responsive_System
    - Wrap bodies in `AdaptiveScroll`/`AdaptiveScaffold`, replace fixed-width layouts with `responsiveValue`/adaptive primitives, and apply the default layout when a screen defines no specific Form_Factor layout — single implementation reflowing across Mobile/Tablet/Desktop
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [~] 12.2 Migrate the remaining Business_Screens flagged non-compliant by the audit
    - Apply the same adaptive-body pattern to the screens listed in `docs/responsive-audit.md`, keeping one implementation per screen
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [ ]* 12.3 Write widget test for default-layout fallback and reflow
    - Assert a screen lacking a specific Form_Factor layout renders via the default layout, and that runtime Form_Factor changes reflow without an Overflow_Error
    - File: `test/core/responsive/adaptive_screen_fallback_test.dart`
    - _Requirements: 4.2, 4.5_

- [ ] 13. Build the responsive and stability test harness
  - [~] 13.1 Implement the harness scaffolding
    - Add `OverflowProbe` model and a pump helper that renders a target under a generated `MediaQuery` (width, orientation, text scale, keyboard inset) inside the test binding and captures `tester.takeException()` and render geometry; build the representative screen/component registry covering each `lib/features/` module
    - File: `test/responsive/responsive_harness.dart`
    - _Requirements: 13.1, 13.5, 13.6, 13.7_

  - [ ]* 13.2 Write property test for overflow-free rendering
    - **Property 8: Overflow-free rendering across all render conditions**
    - Generate width `[320, 3840]`, either orientation, text scale `[1.0, platformMax]`, optional keyboard inset; assert no `Overflow_Error` and no render-time exception for each representative screen/component
    - File: `test/responsive/overflow_free_property_test.dart`
    - **Validates: Requirements 4.2, 4.4, 4.5, 6.1, 6.3, 6.5, 6.7, 7.1, 7.2, 7.3, 7.4, 7.5, 7.7, 8.2, 8.4, 8.5, 8.6, 13.1, 13.2, 13.3, 13.5**

  - [ ]* 13.3 Write property test for safe-area containment and reachability
    - **Property 9: Safe-area containment and reachability**
    - Over generated conditions and insets, assert every interactive control lies within the `Safe_Area`, is reachable directly or via scrolling, and has a touch target of at least 44 by 44 logical pixels
    - File: `test/responsive/safe_area_property_test.dart`
    - **Validates: Requirements 6.4, 6.6, 13.7**

  - [ ]* 13.4 Write widget tests for font scaling, orientation, keyboard, and suite reporting
    - Assert no Overflow_Error under font scaling up to platform max, portrait/landscape, and keyboard inset; assert the suite reports failures for overflow, safe-area/off-viewport/render-exception violations, and an unfinished run
    - File: `test/responsive/responsive_conditions_test.dart`
    - _Requirements: 13.2, 13.3, 13.5, 13.6, 13.7_

- [~] 14. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP; core implementation sub-tasks are never optional.
- Each task references specific requirement clauses (not just user stories) for traceability.
- Property tests use `dartproptest ^0.2.1`, `kNumRuns = 200`, and the `forAll`/`Gen` API, with one property per test tagged `Feature: cross-platform-responsive-ui, Property {n}`.
- The `Desktop_Shell` (`lib/widgets/desktop/desktop_root_shell.dart`) and its destination set stay frozen; only the chrome-visibility toggle is added around it.
- Structural/one-time guarantees (single-source consolidation, compile success, no per-Form_Factor duplicate screens) are enforced by the audit (Task 6) and the static/compile guard (Task 4.2) rather than as runtime properties.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "7.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.1", "2.3", "7.2", "7.3"] },
    { "id": 2, "tasks": ["2.2", "2.4", "3.1"] },
    { "id": 3, "tasks": ["3.2"] },
    { "id": 4, "tasks": ["3.3", "7.4"] },
    { "id": 5, "tasks": ["3.4", "4.1", "6.1", "7.5", "8.1"] },
    { "id": 6, "tasks": ["4.2", "6.2", "8.2", "8.3", "9.1", "11.1"] },
    { "id": 7, "tasks": ["6.3", "8.4", "9.2", "11.2", "12.1"] },
    { "id": 8, "tasks": ["12.2", "13.1"] },
    { "id": 9, "tasks": ["12.3", "13.2", "13.3", "13.4"] }
  ]
}
```
