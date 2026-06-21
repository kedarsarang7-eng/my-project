# Implementation Plan

## Overview

This plan fixes mobile-only (viewport width < 600px) layout/overflow defects on two Flutter screens — `DeviceSettingsScreen` and `GstReportsScreen` — following the bug condition methodology. First an exploration test surfaces the overflow/clipping counterexamples on the unfixed code, then preservation property tests capture the unchanged non-mobile (>= 600px) layouts and all business logic, then the fix is applied gated behind `context.isMobile`, and finally both test sets are re-run to confirm the bug is fixed with no regressions.

## Tasks

- [x] 1. Write bug condition exploration test (widget overflow at mobile widths)
  - **Property 1: Bug Condition** - Mobile Layout Fits Without Overflow Or Clipping
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Scoped PBT Approach**: Generate/iterate over the concrete failing mobile widths (360, 393, 412) so failures are deterministic and reproducible; the bug condition is `(screen == DeviceSettingsScreen OR screen == GstReportsScreen) AND width < 600 AND layoutOverflowsOrClips(screen, width)` (from `isBugCondition` in design)
  - Pump `DeviceSettingsScreen` and `GstReportsScreen` inside a `MediaQuery` forcing narrow widths and capture any RenderFlex overflow `FlutterError`
  - Test assertions match Expected Behavior (Property 1): no RenderFlex overflow, key `Text` widgets bounded (single line + ellipsis where required), segmented control labels visible without clipping, GST period header within bounds, tax-rate badge/slider fit
  - Concrete cases to encode (from Examples in design):
    - Device Settings "Default Tax Rate (GST)" row at 360px → expect overflow on unfixed code
    - Device Settings switch-tile subtitle at 360px → expect awkward/unbounded wrap on unfixed code
    - GST Reports period header `Text('Period: …')` at 393px → expect right-edge overflow on unfixed code
    - GST Reports `SegmentedButton` (GSTR-1 / GSTR-3B / HSN) at 360px → expect label clipping on unfixed code
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g. "A RenderFlex overflowed by N pixels on the right" when pumping at narrow widths) to understand the root cause
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Mobile Layout And Business Logic Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-bug-condition inputs (cases where `isBugCondition` returns false): width >= 600 on both screens, the exact 600px boundary, any business-logic interaction at any width
  - Observe and record on unfixed code:
    - Both screens rendered at 768/1024/1920px (capture widget tree / golden as the baseline non-mobile layout)
    - Both screens at exactly 600px use the non-mobile layout
    - Device Settings: toggles, backup-frequency selection, tax-rate slider (0–28%, 28 divisions) persist their values identically at all widths
    - GST Reports: report-type selection (gstr1/gstr3b/hsn), quick-date chips (Month/Last Month/Quarter), report generation, and JSON/CSV export (with clipboard fallback) behave identically at all widths
  - Write property-based tests capturing observed behavior patterns from the Preservation Requirements: generate random widths in 600..2000 and assert the non-mobile layout/output is unchanged; assert business-logic outcomes are width-independent
  - Property-based testing generates many test cases for stronger guarantees and catches the 600px boundary
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 3. Fix mobile layout overflow/clipping on Device Settings and GST Reports screens

  - [x] 3.1 Fix Device Settings mobile layout
    - File: `lib/features/settings/presentation/screens/device_settings_screen.dart`
    - Tax-rate header: wrap the inner title `Row` (icon + title) in `Expanded`/`Flexible`, add `maxLines: 1, overflow: TextOverflow.ellipsis` to the title `Text`; when `context.isMobile`, render the title and "18%" badge as a vertical `Column` stack instead of a `spaceBetween` `Row` so neither overflows and the slider stays usable (Req 2.4)
    - Switch/menu tiles: add `maxLines: 1, overflow: TextOverflow.ellipsis` to titles and `maxLines: 2, overflow: TextOverflow.ellipsis` to subtitles for overflow safety (Req 2.1, 2.2, 2.5)
    - Section header (`_buildSectionHeader`): add `maxLines: 1, overflow: TextOverflow.ellipsis` for safety; keep existing non-mobile style/letterSpacing (Req 2.3)
    - All adjustments gated behind `context.isMobile` (width < 600) so the non-mobile widget tree is bit-identical; no `setState` handlers, slider min/max/divisions, or backup-frequency dialog logic changes
    - _Bug_Condition: isBugCondition(input) where input.screen == DeviceSettingsScreen AND input.width < 600_
    - _Expected_Behavior: expectedBehavior(result) from design — Property 1 (no overflow, bounded text, badge/slider fit)_
    - _Preservation: Preservation Requirements from design (non-mobile layout + settings logic unchanged)_
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.4_

  - [x] 3.2 Fix GST Reports mobile layout
    - File: `lib/features/gst/screens/gst_reports_screen.dart`
    - Period header: in the existing mobile `Column` branch, wrap `Text('Period: …')` in `Expanded` inside its `Row` and add `overflow: TextOverflow.ellipsis`, mirroring the non-mobile `Row` branch (Req 2.6)
    - Segmented control: when `context.isMobile`, stretch the `SegmentedButton` to full available width (e.g. `SizedBox(width: double.infinity)` / constrain the container) so all three labels fit without clipping; keep intrinsic sizing for non-mobile (Req 2.7)
    - Quick-date chips: confirm/keep `Wrap(spacing: 8, runSpacing: 8)` on mobile so chips wrap with proper spacing (Req 2.8)
    - Header: ensure the body does not assume a wide header; rely on the unchanged shared `DesktopContentContainer` (16px title + wrapped actions on mobile) and verify subtitle does not force overflow (Req 2.9)
    - All adjustments gated behind `context.isMobile`; `_generateReport`, `_pickDate`, quick-date setters, `_exportJson`, `_exportCsv`, and report rendering are untouched
    - _Bug_Condition: isBugCondition(input) where input.screen == GstReportsScreen AND input.width < 600_
    - _Expected_Behavior: expectedBehavior(result) from design — Property 1 (period header fits, segmented labels visible, chips spaced)_
    - _Preservation: Preservation Requirements from design (non-mobile layout + GST logic unchanged; shared DesktopContentContainer not modified)_
    - _Requirements: 2.6, 2.7, 2.8, 2.9, 3.2, 3.5_

  - [x] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Mobile Layout Fits Without Overflow Or Clipping
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied (no overflow, bounded text, segmented labels visible, period header within bounds)
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_

  - [x] 3.4 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Mobile Layout And Business Logic Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions on width >= 600, the 600px boundary, other screens, and all business logic)
    - Confirm all tests still pass after fix (no regressions)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run the full relevant test suite for both screens (mobile fix-checking tests and non-mobile preservation tests)
  - Ensure all tests pass; ask the user if questions arise
  - _Requirements: 1.1, 2.1, 3.1_

## Task Dependency Graph

```json
{
  "waves": [
    {
      "name": "Wave 1: Bug Exploration",
      "tasks": ["1"],
      "description": "Write exploration test that FAILS on unfixed code to confirm the mobile overflow/clipping bug exists"
    },
    {
      "name": "Wave 2: Preservation Baseline",
      "tasks": ["2"],
      "description": "Write preservation property tests that PASS on unfixed code to capture non-mobile layout and business-logic baseline"
    },
    {
      "name": "Wave 3: Implementation (Parallel)",
      "tasks": ["3.1", "3.2"],
      "description": "Fix Device Settings and GST Reports mobile layouts independently, gated behind context.isMobile"
    },
    {
      "name": "Wave 4: Verification",
      "tasks": ["3.3", "3.4"],
      "description": "Verify exploration test now PASSES (bug fixed) and preservation tests still PASS (no regressions)"
    },
    {
      "name": "Wave 5: Final Checkpoint",
      "tasks": ["4"],
      "description": "Run the full relevant test suite and confirm all tests pass"
    }
  ]
}
```

**Execution order**: 1 → 2 → (3.1 ∥ 3.2) → (3.3 ∥ 3.4) → 4

- Tasks 1 and 2 must both complete (tests written and run on unfixed code) BEFORE any fix.
- Tasks 3.1 and 3.2 are independent and can be executed in parallel.
- Tasks 3.3 and 3.4 require both fixes to be applied.
- Task 4 requires 3.3 and 3.4 to pass.

## Notes

- All layout changes MUST be gated behind `context.isMobile` (width < 600) so the non-mobile widget tree is bit-identical to today.
- The shared `DesktopContentContainer` is out of scope and MUST NOT be modified (preserves requirements 3.6/3.7).
- No business logic (settings persistence, report generation, date selection, JSON/CSV export) changes at any width.
- The exact 600px boundary is tablet (non-mobile) and belongs to preservation, not the fix.
- Exploration test (Property 1) must FAIL on unfixed code; preservation tests (Property 2) must PASS on unfixed code. After the fix, both must PASS.
