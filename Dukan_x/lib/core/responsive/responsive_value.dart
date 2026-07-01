// Responsive value selector — the testable core of Req 1.5 and 1.7.
//
// `responsiveValue` returns the value that varies by Form_Factor for the
// current Form_Factor, with a deterministic fallback when the current factor
// has no defined value: prefer the nearest *smaller* defined value, and when
// none smaller is defined, use the smallest defined value overall.
//
// Fallback order per query (matches design.md "resolve(spec, factor)"):
//   desktop : desktop ?? tablet  ?? mobile
//   tablet  : tablet  ?? mobile  ?? desktop
//   mobile  : mobile  ?? tablet  ?? desktop
//
// The function is total over the three Form_Factors as long as at least one
// value is provided (enforced by an assertion); it never returns null.
//
// Form_Factor classification defers entirely to the single source of truth in
// `responsive_breakpoints.dart` (`ResponsiveBreakpoints.classify`); this file
// never defines breakpoint thresholds of its own. Because classification reads
// the width from `MediaQuery.sizeOf`, a width change that crosses a breakpoint
// boundary rebuilds dependents and re-runs the selector (Req 1.8).
//
// Part of: cross-platform-responsive-ui

import 'package:flutter/widgets.dart';

import 'responsive_breakpoints.dart';

/// Returns the value defined for the current [FormFactor], falling back to the
/// next-smaller defined value, else the smallest defined value (Req 1.5, 1.7).
///
/// At least one of [mobile], [tablet], or [desktop] must be provided. Given
/// that, the result is total over the three Form_Factors and is never null.
///
/// Fallback order by current Form_Factor:
///   * Desktop: [desktop] ?? [tablet] ?? [mobile]
///   * Tablet : [tablet] ?? [mobile] ?? [desktop]
///   * Mobile : [mobile] ?? [tablet] ?? [desktop]
///
/// Example: a value defined only for `tablet` is returned for desktop queries
/// (desktop -> tablet) and for mobile queries (mobile -> tablet), since tablet
/// is the only — and therefore smallest — defined value.
T responsiveValue<T>(BuildContext context, {T? mobile, T? tablet, T? desktop}) {
  assert(
    mobile != null || tablet != null || desktop != null,
    'responsiveValue requires at least one of mobile, tablet, or desktop.',
  );

  final width = MediaQuery.sizeOf(context).width;
  final factor = ResponsiveBreakpoints.classify(width);

  return resolveResponsiveValue<T>(
    factor,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );
}

/// Pure resolution of a partial per-Form_Factor value specification.
///
/// This is the side-effect-free core of [responsiveValue], separated so the
/// fallback logic can be exercised without a [BuildContext]. It applies the
/// "current factor, else next-smaller defined, else smallest defined" rule:
///   * Desktop: [desktop] ?? [tablet] ?? [mobile]
///   * Tablet : [tablet] ?? [mobile] ?? [desktop]
///   * Mobile : [mobile] ?? [tablet] ?? [desktop]
///
/// At least one value must be non-null; the result is never null.
T resolveResponsiveValue<T>(
  FormFactor factor, {
  T? mobile,
  T? tablet,
  T? desktop,
}) {
  assert(
    mobile != null || tablet != null || desktop != null,
    'resolveResponsiveValue requires at least one of mobile, tablet, or desktop.',
  );

  final T? resolved = switch (factor) {
    FormFactor.desktop => desktop ?? tablet ?? mobile,
    FormFactor.tablet => tablet ?? mobile ?? desktop,
    FormFactor.mobile => mobile ?? tablet ?? desktop,
  };

  // Safe by the assertion above: at least one value is non-null, and each
  // branch above lists all three values, so a non-null result always exists.
  return resolved as T;
}
