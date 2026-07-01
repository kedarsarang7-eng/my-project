// Responsive_System barrel — the single import for the consolidated
// cross-platform responsive architecture.
//
// Call sites should depend on this one file:
//
//     import 'package:dukanx/core/responsive/responsive.dart';
//
// rather than importing the individual parts. It re-exports the authoritative
// Responsive_System public surface (Req 1.1, 2.1):
//
//   * responsive_breakpoints.dart  — FormFactor, ScreenSize (synonym),
//                                     ResponsiveBreakpoints (single source of
//                                     truth for classification)
//   * responsive_context.dart      — ResponsiveContext extension on BuildContext
//   * responsive_value.dart        — responsiveValue, resolveResponsiveValue
//   * adaptive_widgets.dart        — AdaptiveScaffold, AdaptiveScroll,
//                                     AdaptiveText, BoundedBox, AdaptiveDialog,
//                                     AdaptiveSheet, AdaptiveForm, AdaptiveTable,
//                                     AdaptiveGrid, AdaptiveChartBox
//   * navigation_destinations.dart — reachableDestinationIds, DestinationResolver,
//                                     DestinationResolution
//
// NAME-COLLISION NOTE (full consolidation happens in Task 4.1):
// The legacy `responsive_layout.dart` still declares symbols that COLLIDE with
// the consolidated files above — `enum ScreenSize`, `extension ResponsiveContext`,
// `class Breakpoints`, and the `responsiveValue` function — plus the duplicate
// classifier helpers `getScreenSize`/`usesHover`. Exporting those alongside the
// new files would produce ambiguous-export errors. Until the legacy file is
// folded in during Task 4.1, this barrel re-exports ONLY the legacy layout
// WIDGETS that do not collide, via an explicit `show` clause. The colliding /
// duplicate-authority symbols are intentionally omitted so the new consolidated
// definitions remain the single authoritative source.
//
// Part of: cross-platform-responsive-ui

// --- Consolidated Responsive_System (authoritative source) ------------------
export 'responsive_breakpoints.dart';
export 'responsive_context.dart';
export 'responsive_value.dart';
export 'adaptive_widgets.dart';
export 'navigation_destinations.dart';

// --- Retained pre-existing layout widgets (non-colliding subset) ------------
// Excludes ScreenSize, ResponsiveContext, Breakpoints, responsiveValue,
// getScreenSize, and usesHover, which are provided by (or superseded by) the
// consolidated files above. These remaining widgets will be folded into the
// consolidated surface during the Task 4.1 consolidation.
export 'responsive_layout.dart'
    show
        ResponsiveLayout,
        ResponsiveScaffold,
        ResponsiveGrid,
        ResponsiveRowColumn,
        AdaptiveButton,
        ResponsiveContainer,
        ResponsiveSpacing,
        ResponsiveSafeArea;
