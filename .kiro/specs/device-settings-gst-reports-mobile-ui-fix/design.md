# Device Settings & GST Reports Mobile UI Fix — Bugfix Design

## Overview

On mobile viewports (logical width < 600px) two Flutter screens render with layout/overflow
defects: `DeviceSettingsScreen` (`lib/features/settings/presentation/screens/device_settings_screen.dart`)
and `GstReportsScreen` (`lib/features/gst/screens/gst_reports_screen.dart`).

The fix strategy is **conditional, mobile-only layout adjustments** gated on the existing
breakpoint helper `context.isMobile` (true when width < 600, per
`ResponsiveBreakpoints.mobileMax = 600`). At width >= 600 (tablet/desktop) both screens must
render byte-for-byte the same widget tree as before, and no business logic (settings persistence,
report generation, export) changes at any width.

Grounding observations from reading the code:

- `DeviceSettingsScreen` has **no** mobile branch today. It builds a fixed desktop-oriented
  layout for all widths. The "Default Tax Rate (GST)" header is a `Row` with
  `MainAxisAlignment.spaceBetween` whose inner title `Row` (icon + `Text('Default Tax Rate (GST)')`)
  is **not** wrapped in `Flexible`/`Expanded` and the title `Text` has no `overflow` handling. When
  squeezed under 600px this is the classic source of RenderFlex overflow and text that visually
  collapses (each word/char wrapping awkwardly). The switch-tile titles are inside `Expanded`, so
  they are lower risk, but their subtitles also lack explicit `maxLines`/`overflow`.
- `GstReportsScreen` **already** has partial mobile branches via `context.isMobile`
  (the period card switches to a `Column`, the `SegmentedButton` drops icons on mobile, and the
  quick-date chips use a `Wrap`). However, inside the mobile `Column` branch the
  `Text('Period: … - …')` sits in a `Row` **without** `Flexible`/`Expanded` and **without**
  `overflow: TextOverflow.ellipsis`, so the period header still overflows the right edge on narrow
  screens (bug 1.6). The `SegmentedButton` can still clip its three labels on the narrowest
  viewports (bug 1.7). The header (title/subtitle/actions) is rendered by `DesktopContentContainer`,
  which already shrinks the title to 16px and wraps actions on mobile, but the subtitle still
  competes for space (bug 1.9).

The shared header component `DesktopContentContainer` (`lib/widgets/desktop/desktop_content_container.dart`)
is used by many screens. It already has mobile handling, so this fix touches the **two screen
bodies only** and does not modify the shared container (modifying it would break the
regression-prevention scope in requirements 3.6/3.7).

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — the active screen is
  `DeviceSettingsScreen` or `GstReportsScreen` AND the logical viewport width is < 600px.
- **Property (P)**: The desired layout behavior when C holds — labels render with normal spacing
  on a single line (ellipsis when needed), rows/headers/controls fit within the viewport with no
  RenderFlex overflow, and selector chips/segmented controls wrap or size cleanly.
- **Preservation**: Existing tablet/desktop (width >= 600px) layouts, and all business logic
  (settings toggle/slider/backup-frequency persistence, GST report generation, date selection,
  JSON/CSV export) at every width, which must remain unchanged.
- **context.isMobile**: `BuildContext` extension getter from
  `lib/core/responsive/responsive_context.dart`; returns true when
  `ResponsiveBreakpoints.classify(width) == FormFactor.mobile`, i.e. width < 600. This is the
  single source of truth for the mobile breakpoint and exactly matches the bug condition boundary.
- **responsiveValue<T>(context, mobile:, tablet:, desktop:)**: helper from
  `lib/core/responsive/responsive_value.dart` for picking per-form-factor values (already used in
  `DeviceSettingsScreen` for padding).
- **DeviceSettingsScreen**: settings screen with toggle rows, backup-frequency menu, and the
  "Default Tax Rate (GST)" slider row.
- **GstReportsScreen**: GST reports screen with the report-type `SegmentedButton`, the period card,
  the quick-date chips, and report result cards.
- **DesktopContentContainer**: shared header+content wrapper providing the AppBar-equivalent
  title/subtitle/actions; already mobile-aware and out of scope to modify.

## Bug Details

### Bug Condition

The bug manifests when the rendered screen is `DeviceSettingsScreen` or `GstReportsScreen` AND the
logical viewport width is below the 600px mobile breakpoint. In that band the screen bodies place
horizontally-laid-out text and controls (titles, badges, sliders, segmented controls, period text)
into `Row`s that are not width-constrained for narrow viewports, causing RenderFlex overflow,
clipped/wrapped controls, and text that renders character-by-character.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type RenderInput { screen: ScreenId, width: double }
  OUTPUT: boolean

  RETURN (input.screen == DeviceSettingsScreen OR input.screen == GstReportsScreen)
         AND input.width < 600   // ResponsiveBreakpoints.mobileMax
         AND layoutOverflowsOrClips(input.screen, input.width)
END FUNCTION
```

Here `layoutOverflowsOrClips` is true when any of: a `Text` collapses to character-by-character
rendering, a `Row` reports RenderFlex overflow, a control (SegmentedButton/chips) clips or wraps
without spacing, or content extends past the right screen edge.

### Examples

- At 360×640, Device Settings "Default Tax Rate (GST)" row: title `Row` + "18%" badge exceed the
  available width → RenderFlex overflow / title text squeezed. Expected: title and badge fit (or
  the badge stacks under the title) with the slider fully usable.
- At 360×640, Device Settings switch tile subtitle "Sync data automatically when online" wraps
  awkwardly with no `maxLines` cap. Expected: clean wrap to at most two lines with ellipsis.
- At 393×851, GST Reports period card: `Text('Period: 01/01/2026 - 31/01/2026')` overflows the
  right edge because it is not in a `Flexible` with ellipsis. Expected: text fits, ellipsizing or
  wrapping within bounds.
- At 360×640, GST Reports `SegmentedButton` (GSTR-1 / GSTR-3B / HSN) labels clip. Expected: all
  three labels readable (segmented control sized full-width or labels shrink) without clipping.
- Edge case — width exactly 600px: this is **tablet** (`width < 600` is false), so the screen MUST
  use the existing non-mobile layout unchanged (boundary belongs to preservation).

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Tablet (600–1024px) and desktop (>1024px) layouts of both screens render exactly as before.
- All Device Settings interactions persist the same values: push notifications, auto sync, cloud
  backup toggles; backup-frequency selection; default tax-rate slider (0–28%, divisions 28).
- All GST Reports interactions behave identically: report-type selection (gstr1/gstr3b/hsn), date
  range picking, quick-date chips (Month/Last Month/Quarter), report generation, and JSON/CSV
  export with the same fallback-to-clipboard behavior.
- The shared `DesktopContentContainer` is not modified, so every other screen using it is
  unaffected.

**Scope:**
All inputs where the bug condition does NOT hold must be completely unaffected by this fix.
This includes:
- Any render of either screen at width >= 600px (tablet/desktop), including the preserved
  viewports 768×1024, 1024×1366, 1920×1080.
- Any other screen in the application at any width.
- Screens owned by the sibling `cross-platform-mobile-responsiveness-fix` spec.
- All user interactions / business logic on both screens at any width.

_The expected correct mobile behavior is defined in the Correctness Properties section
(Property 1)._

## Hypothesized Root Cause

Based on the bug description and the code read, the most likely issues are:

1. **Missing mobile branch in Device Settings**: `DeviceSettingsScreen` has no `context.isMobile`
   handling at all; the "Default Tax Rate (GST)" header is a `spaceBetween` `Row` whose inner title
   `Row` is not `Flexible` and whose title `Text` has no `overflow`, so on narrow widths it
   overflows / collapses character-by-character (covers 1.1, 1.4).

2. **Unbounded `Text` widgets inside `Row`s**: Switch-tile subtitles and the tax-rate title lack
   `maxLines`/`overflow: TextOverflow.ellipsis`, allowing awkward wraps and RenderFlex overflow on
   narrow viewports (covers 1.2, 1.5).

3. **Section header spacing on mobile**: `_buildSectionHeader` uses fixed `letterSpacing: 0.5` with
   `toUpperCase()`; combined with no width handling this contributes to the misaligned/odd-spacing
   appearance on mobile (covers 1.3).

4. **GST period text not flexible**: Inside the existing mobile `Column` branch of the period card,
   `Text('Period: …')` is a bare child of a `Row` (no `Flexible`/`Expanded`, no ellipsis), so it
   overflows the right edge (covers 1.6).

5. **Segmented control not sized for narrow widths**: The `SegmentedButton` keeps intrinsic sizing
   on mobile; with three labels it can clip on the narrowest viewports (covers 1.7). The quick-date
   chips already use a `Wrap` but spacing/run-spacing should be confirmed (covers 1.8).

6. **Header subtitle competing for space**: Although `DesktopContentContainer` already shrinks the
   title and wraps actions on mobile, the subtitle still occupies vertical space and competes with
   actions; the screen-level fix should ensure the body does not assume a wide header (covers 1.9).

## Correctness Properties

Property 1: Bug Condition - Mobile Layout Fits Without Overflow Or Clipping

_For any_ render input where the bug condition holds (`isBugCondition` returns true — the screen is
`DeviceSettingsScreen` or `GstReportsScreen` and width < 600), the fixed screen SHALL lay out all
labels, titles, badges, sliders, segmented controls, period text, and selector chips fully within
the viewport with no RenderFlex overflow and no character-by-character text rendering: section
labels and card titles render with normal letter-spacing on a single line (ellipsis when needed),
toggle subtitles wrap to at most two lines with ellipsis, the "Default Tax Rate (GST)" badge and
slider fit (stacking vertically if needed), the GST period header fits within bounds, the segmented
control shows all three labels without clipping, and the quick-date chips wrap with proper spacing.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9**

Property 2: Preservation - Non-Mobile Layout And Business Logic Unchanged

_For any_ render input where the bug condition does NOT hold (`isBugCondition` returns false —
width >= 600 on these screens, any other screen, or any user interaction / business logic at any
width), the fixed code SHALL produce exactly the same result as the original code, preserving the
existing tablet/desktop layouts, the unchanged shared `DesktopContentContainer`, and all settings
persistence, report generation, date selection, and export behavior.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct, all changes are gated behind `context.isMobile`
(width < 600) so the non-mobile widget tree is bit-identical to today.

**File 1**: `lib/features/settings/presentation/screens/device_settings_screen.dart`

**Targets**: the "Default Tax Rate (GST)" header `Row`, `_buildSwitchTile`, `_buildMenuTile`,
`_buildSectionHeader`.

**Specific Changes**:
1. **Tax-rate header responsiveness**: Wrap the inner title `Row` (icon + title) in
   `Expanded`/`Flexible` and add `overflow: TextOverflow.ellipsis` + `maxLines: 1` to the title
   `Text`. When `context.isMobile`, render the title and the "18%" badge as a vertical stack
   (`Column`) instead of a `spaceBetween` `Row` so neither overflows; keep the `Row` layout for
   non-mobile (Requirement 2.4).
2. **Switch/menu tile text safety**: Add `maxLines: 2, overflow: TextOverflow.ellipsis` to tile
   subtitles and `maxLines: 1, overflow: TextOverflow.ellipsis` to tile titles. Titles are already
   inside `Expanded`; this only adds overflow safety and does not change non-mobile rendering since
   the desktop widths never trigger the ellipsis (Requirements 2.1, 2.2, 2.5).
3. **Section header on mobile**: Keep the existing style for non-mobile; the header `Text` already
   fits, so add `maxLines: 1, overflow: TextOverflow.ellipsis` for safety (Requirement 2.3). No
   letterSpacing change for non-mobile.
4. **No logic changes**: `setState` handlers, slider min/max/divisions, and backup-frequency dialog
   are untouched (Requirement 3.4).

**File 2**: `lib/features/gst/screens/gst_reports_screen.dart`

**Targets**: the mobile `Column` branch of the period card, the `SegmentedButton` container, the
quick-date chip `Wrap`.

**Specific Changes**:
1. **Period header fits on mobile**: In the mobile `Column` branch, wrap the `Text('Period: …')` in
   `Expanded` (inside its `Row`) and add `overflow: TextOverflow.ellipsis`, mirroring what the
   non-mobile `Row` branch already does with `Flexible` (Requirement 2.6).
2. **Segmented control sizing on mobile**: When `context.isMobile`, make the `SegmentedButton`
   stretch to full available width (e.g. wrap in `SizedBox(width: double.infinity)` /
   constrain via the container) so the three labels share the row without clipping; keep intrinsic
   sizing for non-mobile (Requirement 2.7).
3. **Quick-date chip spacing**: Confirm/keep the existing `Wrap(spacing: 8, runSpacing: 8)` on
   mobile so chips wrap with proper spacing (Requirement 2.8).
4. **Header on mobile**: No screen-level change needed beyond ensuring the body doesn't assume a
   wide header; the shared `DesktopContentContainer` already shrinks the title (16px on mobile) and
   wraps actions. Verify subtitle does not force overflow (Requirement 2.9).
5. **No logic changes**: `_generateReport`, `_pickDate`, quick-date setters, `_exportJson`,
   `_exportCsv`, and report rendering are untouched (Requirement 3.5).

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate
the bug on the unfixed code (using narrow-viewport widget tests that assert no overflow/clipping),
then verify the fix works correctly for mobile widths and preserves the non-mobile layouts and all
business logic.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or
refute the root-cause hypotheses. If refuted, re-hypothesize.

**Test Plan**: Pump each screen inside a `MediaQuery` forcing narrow widths (360, 393, 412) and
assert there is no RenderFlex overflow (capture `FlutterError`/exception from the overflow), that
key `Text` widgets are bounded, and that the segmented control and period text fit. Run on the
UNFIXED code to observe failures.

**Test Cases**:
1. **Device Settings Tax-Rate Overflow** (360 width): pump `DeviceSettingsScreen`, expect overflow
   error from the "Default Tax Rate (GST)" row (will fail on unfixed code).
2. **Device Settings Switch Tile** (360 width): assert subtitle does not overflow its tile
   (may fail on unfixed code).
3. **GST Period Header Overflow** (393 width): pump `GstReportsScreen`, expect the mobile period
   `Text('Period: …')` to overflow because it is not `Flexible` (will fail on unfixed code).
4. **GST Segmented Control Clip** (360 width): assert all three labels (GSTR-1/GSTR-3B/HSN) render
   without clipping (may fail on unfixed code).

**Expected Counterexamples**:
- "A RenderFlex overflowed by N pixels on the right" thrown when pumping at narrow widths.
- Possible causes: non-`Flexible` `Text` in a `Row`, `spaceBetween` `Row` with intrinsic-width
  children, segmented control with intrinsic sizing under 600px.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed screen produces the
expected behavior (no overflow/clipping, bounded text).

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := renderScreen_fixed(input.screen, input.width)
  ASSERT noRenderFlexOverflow(result)
        AND allTextBounded(result)        // single line + ellipsis where required
        AND segmentedControlLabelsVisible(result)
        AND periodHeaderWithinBounds(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed screen
produces the same result as the original.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT renderScreen_original(input.screen, input.width)
       = renderScreen_fixed(input.screen, input.width)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many widths across the input domain (e.g. 600..2000px) automatically.
- It catches boundary cases (exactly 600px) that manual tests might miss.
- It provides strong guarantees the non-mobile widget tree and logic are unchanged.

**Test Plan**: Observe behavior on UNFIXED code first at width >= 600 and for interaction logic,
then write tests capturing that behavior so any regression is caught after the fix.

**Test Cases**:
1. **Tablet/Desktop Layout Preservation**: Render both screens at 768/1024/1920px and assert the
   widget tree / golden matches the pre-fix output (mobile branch not taken).
2. **600px Boundary Preservation**: At exactly 600px, assert the non-mobile layout is used.
3. **Settings Logic Preservation**: Toggle switches, pick backup frequency, move the tax slider;
   assert state values persist identically at all widths.
4. **GST Logic Preservation**: Select each report type, use quick-date chips, generate a report,
   and export JSON/CSV; assert identical behavior and clipboard fallback at all widths.

### Unit Tests

- Mobile-width layout of the Device Settings tax-rate row and switch tiles (no overflow).
- Mobile-width layout of the GST period card and segmented control (no clip/overflow).
- Edge cases: exactly 600px (non-mobile), very narrow 320px, large text scale.

### Property-Based Tests

- Generate random widths < 600 and assert no overflow on either screen (fix checking).
- Generate random widths >= 600 and assert the non-mobile layout is preserved (preservation).
- Generate random interaction sequences (toggles, report-type/date selections) and assert state
  outcomes are width-independent and unchanged.

### Integration Tests

- Full Device Settings flow on a phone-sized surface: open screen, toggle settings, change backup
  frequency, adjust tax rate — no overflow and values persist.
- Full GST Reports flow on a phone-sized surface: switch report types, pick quarter, generate, and
  export — no clipping/overflow and reports generate correctly.
- Switch viewport from mobile to tablet to desktop and back; verify each form factor renders its
  intended layout and no state is lost.
