# Implementation Plan: Mobile Text-Scale & Responsive Hardening

## Overview

This plan hardens DukanX against text-scale-driven and viewport-driven layout failures while freezing the Windows desktop render path. Implementation is in Dart/Flutter, matching the existing codebase and the design document.

The work proceeds in dependency order: first establish the single clamped text-scale pipeline and remove the dead double-scaling path, then build the shared `ResponsiveTestHarness` and overflow-safe primitives, then harden the safe-area-aware header, then apply the five per-defect screen fixes, and finally wire the app-wide matrix coverage and the structural/preservation tests that act as the regression gate.

Property tests use the repo-standard `dartproptest ^0.2.1` library (≥100 iterations) and reuse the `FlutterError.onError` overflow-capture pattern from `test/widget/widget_test_harness.dart`. Each property test is tagged:
`// Feature: mobile-text-scale-responsive-hardening, Property {n}: {property text}`

## Tasks

- [x] 1. Establish the single, clamped text-scale pipeline
  - [x] 1.1 Extract pure clamp arithmetic and adapter in `lib/app/app.dart`
    - Add pure, platform-parameterized `double clampTextScaleFactor(double requested, {required bool isWindows})` returning `requested` on Windows and `requested.clamp(1.0, kMaxTextScaleFactor)` otherwise
    - Refactor the existing `_applyTextScaleClamp` into a thin adapter `MediaQueryData applyTextScaleClamp(MediaQueryData data, {bool? isWindowsOverride})` that derives `data.textScaler.scale(1.0)`, calls `clampTextScaleFactor`, and only rebuilds `MediaQueryData` (via `TextScaler.linear`) when the factor changes
    - Keep `kMaxTextScaleFactor = 1.3` unchanged; keep the production `!kIsWeb && Platform.isWindows` check (test-only `isWindowsOverride`)
    - Ensure `MaterialApp.builder` remains the only site that overrides `MediaQuery.textScaler`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 11.1, 11.2_

  - [x]* 1.2 Write property tests for the clamp arithmetic
    - **Property 1: Non-Windows clamp invariant** — _Validates: Requirements 1.2, 1.3, 1.4_
    - **Property 2: Windows pass-through** — _Validates: Requirements 11.1_
    - **Property 3: Clamp idempotence (single application)** — _Validates: Requirements 1.1, 1.5, 2.2_
    - Use `dartproptest` `forAll` over requested doubles (including <1.0, =1.3, >>1.3) × platform flag

  - [x] 1.3 Remove the dead double-scaling path in `lib/core/theme/accessibility_theme.dart`
    - Delete `AccessibilityThemeBuilder` and its private `_applyTextScale`/`_applyBoldText`/`_applyHighContrast` helpers (the only double-scaling site)
    - Leave inert `AccessibilitySettings`/`AccessibilityNotifier`/`AccessibilityPreferences`/`AccessibilitySettingsScreen` in place (no new wiring); add a doc comment recording the integration contract: any future in-app scale must be injected upstream of `applyTextScaleClamp` via `MediaQuery.textScaler`, never `textTheme.fontSizeFactor`
    - _Requirements: 1.5, 2.1, 2.2, 2.3, 2.4_

  - [x]* 1.4 Write architecture test for single scale source
    - Source-scan asserting `AccessibilityThemeBuilder` no longer exists and `app.dart` has exactly one `MediaQuery.textScaler` override site (reuse the scanning pattern from `responsive_audit_totality_property_test.dart`)
    - _Requirements: 1.1, 1.5, 2.1, 2.3_

- [x] 2. Build the shared Responsive Test Harness
  - [x] 2.1 Implement `test/responsive/responsive_test_harness.dart`
    - Define matrix constants: `kRequiredViewports` (360x640, 393x851, 412x915), `kRequiredScales` (1.0, 1.3 cap, 2.6 above-cap), `kBaselineScale`, `kCapScale`, `kAboveCapScale`
    - Implement `pumpResponsiveMatrix(tester, {builder, viewports, scales, theme})` that sets `tester.view.physicalSize`/`devicePixelRatio` per viewport with `addTearDown` resets, routes the requested scale through the real `applyTextScaleClamp(isWindowsOverride: false)`, captures overflow via a scoped `FlutterError.onError` (filtering `overflowed`) restored in a `finally`, fails naming the offending viewport+scale, and asserts the full exercised pair-set equals the required matrix
    - Implement `wrapWithPipeline(child, {requestedScale, theme})` and `assertCasesCovered(requiredCases, registeredCases)` for the five named cases
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.6_

  - [x]* 2.2 Write property test for harness matrix totality
    - **Property 12: Harness matrix totality** — _Validates: Requirements 10.2, 10.3, 10.6_
    - `forAll` over subsets of the required matrix (some omitting pairs); incomplete coverage fails

  - [x]* 2.3 Write property test for harness overflow detection
    - **Property 13: Harness fails on overflow** — _Validates: Requirements 10.4_
    - `forAll` mix of safe vs deliberately-overflowing widgets; failure iff overflow occurs, with viewport+scale named

  - [x]* 2.4 Write meta-test for harness capability
    - Verify pumping at a given viewport/scale sets `MediaQuery.size` and effective `textScaler` accordingly
    - _Requirements: 10.1_

- [x] 3. Implement shared overflow-safe primitives
  - [x] 3.1 Implement `OverflowSafeLabelValueRow` in `lib/widgets/responsive/overflow_safe.dart`
    - Row of `Flexible(Text label, maxLines:1, ellipsis)` + `SizedBox(minGap default 12)` + `Flexible(valueOverride ?? FittedBox(scaleDown, centerRight, Text value maxLines:1 softWrap:false))`
    - Both children `Flexible` so the row can never overflow; value shrinks/truncates rather than clipping and stays whole when it fits; accept empty strings without throwing
    - _Requirements: 3.4, 4.1, 4.3, 4.4_

  - [-]* 3.2 Write property test for label/value non-overlap
    - **Property 5: Label/value rows never overlap** — _Validates: Requirements 3.4, 4.1_
    - `forAll` generated label/value strings × required matrix; assert painted bounds do not intersect and no overflow

  - [-]* 3.3 Write property test for value single-row behavior
    - **Property 6: Value stays on a single visible row** — _Validates: Requirements 4.3, 4.4_
    - `forAll` generated amounts (including very large) shrink-to-fit/truncate on one row with label

  - [x] 3.4 Implement `OverflowSafeInfoBanner` in `lib/widgets/responsive/overflow_safe.dart`
    - `Container(width: double.infinity)` → `Row(crossAxisStart, [Icon, SizedBox(12), Expanded(Text message, softWrap:true)])` giving the text a bounded width to wrap across; accept empty message without throwing
    - _Requirements: 5.1, 5.2, 5.3_

  - [-]* 3.5 Write property test for banner wrapping
    - **Property 7: Info banner wraps across available width** — _Validates: Requirements 5.1, 5.2, 5.3_
    - `forAll` multi-word messages × matrix; rendered line count ≤ word count, uses available width, no overflow

- [x] 4. Harden the safe-area-aware header in `lib/widgets/desktop/desktop_content_container.dart`
  - [x] 4.1 Wrap header in SafeArea and bound title/subtitle
    - Wrap `_buildHeader` `Container` in `SafeArea(bottom: false)` (zero insets on desktop → Windows unchanged)
    - Keep title `maxLines:1`+ellipsis and subtitle `maxLines:2`+ellipsis; set the title/subtitle `Column` to `mainAxisSize: min` inside the existing `Expanded` so they never overlap actions or each other
    - Ensure the scaffold background uses the active theme's `scaffoldBackgroundColor` for consistent light/dark regions
    - _Requirements: 7.1, 7.2, 7.3, 9.5, 11.3_

  - [-]* 4.2 Write property test for title/subtitle non-overlap
    - **Property 9: App-bar title and subtitle do not overlap** — _Validates: Requirements 7.1, 7.2_
    - `forAll` title/subtitle strings × matrix; title painted bounds entirely above subtitle bounds

  - [-]* 4.3 Write property test for safe-area insets
    - **Property 10: App-bar header respects safe-area insets** — _Validates: Requirements 7.3_
    - `forAll` simulated top inset × matrix; header content top offset ≥ inset

- [x] 5. Apply per-defect screen fixes
  - [x] 5.1 Fix New Estimate Totals card in `lib/features/revenue/screens/proforma_screen.dart`
    - Replace Subtotal/Total bare `Row`s in `_buildSummaryCard` with `OverflowSafeLabelValueRow`; Discount uses `valueOverride` wrapping the existing 100px `TextFormField` in `Flexible`; preserve bold/`responsiveValue` styling on Total
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 11.3_

  - [x] 5.2 Fix New Purchase Order info banner in `lib/features/buy_flow/screens/buy_orders_screen.dart`
    - Replace the hand-rolled PENDING banner with `OverflowSafeInfoBanner(icon: Icons.info, message: '...', color: Colors.blue)`
    - _Requirements: 5.1, 5.2, 5.3, 11.3_

  - [x] 5.3 Fix GST Reports header and segmented control in `lib/features/gst/screens/gst_reports_screen.dart`
    - Ensure both branches of the "Period:" header use `maxLines:1`+`TextOverflow.ellipsis` so it cannot clip off the right edge
    - Wrap each segment label (GSTR-1/GSTR-3B/HSN) in `maxLines:1` + `FittedBox(scaleDown)` so labels shrink rather than clip while keeping all three on one row
    - _Requirements: 6.1, 6.2, 6.3, 11.3_

  - [ ]* 5.4 Write property test for segmented-control labels
    - **Property 8: Segmented-control labels remain visible** — _Validates: Requirements 6.2_
    - Matrix sweep asserting all three labels are findable and shrink-to-fit without clipping, no overflow

  - [x] 5.5 Fix Process Return search hint in `lib/features/revenue/screens/return_inwards_screen.dart`
    - Set `InputDecoration.hintMaxLines: 1` and a `hintStyle` with `overflow: TextOverflow.ellipsis`; ensure the input uses `Expanded` for a bounded width
    - _Requirements: 8.1, 8.2, 11.3_

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Wire app-wide matrix and scrollability coverage
  - [ ]* 7.1 Write property test for matrix overflow-freedom across all targets
    - **Property 4: Matrix overflow-freedom across targets** — _Validates: Requirements 3.1, 3.2, 4.2, 5.2, 6.1, 6.3, 7.4, 7.5, 8.2, 9.1, 9.3_
    - Register all targets via `pumpResponsiveMatrix`: Totals_Card, PO_Info_Banner, GST_Reports_Screen, App_Bar_Header pattern, Process Return search field, plus a KPI card and representative form/table/dialog
    - Call `assertCasesCovered` so the five explicitly named cases (R10.5) are all present, failing the suite if any is missing
    - _Requirements: 10.5_

  - [ ]* 7.2 Write property test for scrollable (not clipped) overflow
    - **Property 11: Overflowing content is scrollable, not clipped** — _Validates: Requirements 9.4_
    - `forAll` content heights exceeding the viewport; assert a scrollable region with scroll extent > 0

- [ ] 8. Add structural and Windows-preservation tests (non-PBT criteria)
  - [ ]* 8.1 Write static audit for unbounded hardcoded fonts
    - Audit the touched files and shared primitives for unbounded hardcoded font sizes inside narrow/fixed containers lacking an overflow-safe mechanism
    - _Requirements: 3.5_

  - [ ]* 8.2 Write back/dismiss affordance enumeration test
    - Enumerate forward-reachable surfaces (screens, modal dialogs, onboarding) asserting each exposes a back/close affordance; `DesktopContentContainer` provides it automatically when `canPop()`
    - _Requirements: 9.2_

  - [ ]* 8.3 Write theme background consistency test
    - Golden/example assertion that the scaffold background equals the active light/dark theme background
    - _Requirements: 9.5_

  - [ ]* 8.4 Write Windows preservation golden tests
    - Golden preservation of the touched screens at a desktop viewport (following `test/bug_condition/*_preservation_test.dart` convention), relying on Property 2 and zero `SafeArea` insets on desktop
    - _Requirements: 11.2, 11.3_

- [x] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test tasks and can be skipped for a faster MVP; core implementation tasks are never optional.
- Each task references specific requirements (granular sub-clauses) for traceability.
- Property tests validate the 13 universal correctness properties from the design; example/architecture/golden tests cover structural and platform-freeze criteria that are not universal properties.
- Checkpoints provide incremental validation breaks.
- All implementation is in Dart/Flutter against the existing repo; the Windows render path is preserved by the platform-parameterized clamp and zero-inset `SafeArea` on desktop.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3", "3.1", "4.1", "5.3", "5.5"] },
    { "id": 1, "tasks": ["1.2", "1.4", "2.1", "3.4", "5.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4", "3.2", "3.3", "3.5", "4.2", "4.3", "5.2", "5.4", "8.2", "8.3"] },
    { "id": 3, "tasks": ["7.1", "7.2", "8.1", "8.4"] }
  ]
}
```
