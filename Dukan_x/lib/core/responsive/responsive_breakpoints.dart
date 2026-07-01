// Responsive Breakpoints — single source of truth for Form_Factor classification.
//
// This is the authoritative definition of the breakpoint thresholds and the
// width-to-Form_Factor classifier for the consolidated Responsive_System.
// It is pure Dart (no Flutter dependency) so the classification logic is
// trivially testable and free of side effects.
//
// Width ranges (logical pixels):
//   Mobile  : width < 600
//   Tablet  : 600 <= width < 1100
//   Desktop : width >= 1100
//
// Part of: cross-platform-responsive-ui

/// The canonical device class derived from logical screen width.
///
/// This is the single canonical type for responsive classification. The
/// legacy [ScreenSize] name is retained as a synonym (see below) so existing
/// call sites that use `ScreenSize` keep compiling during migration.
enum FormFactor { mobile, tablet, desktop }

/// Migration synonym for [FormFactor].
///
/// Existing code refers to the device class as `ScreenSize`. Aliasing it to
/// [FormFactor] lets both names refer to the exact same type, so call sites can
/// migrate incrementally without churn. New code should prefer [FormFactor].
typedef ScreenSize = FormFactor;

/// Breakpoint thresholds and the Form_Factor classifier.
///
/// This class is the single source of truth: no other part of the codebase
/// should define breakpoint thresholds or Form_Factor classification logic.
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  /// Upper bound (exclusive) for the Mobile band. `width < mobileMax` => Mobile.
  static const double mobileMax = 600;

  /// Upper bound (exclusive) for the Tablet band.
  /// `mobileMax <= width < tabletMax` => Tablet, `width >= tabletMax` => Desktop.
  static const double tabletMax = 1100;

  /// Maximum content width used to keep desktop content from stretching.
  static const double maxContentWidth = 1200;

  /// Classifies a logical [width] into a [FormFactor].
  ///
  /// Pure and side-effect-free — the single source of truth for classification:
  ///   * Mobile  when `width < 600`
  ///   * Tablet  when `600 <= width < 1100`
  ///   * Desktop when `width >= 1100`
  static FormFactor classify(double width) {
    if (width < mobileMax) return FormFactor.mobile;
    if (width < tabletMax) return FormFactor.tablet;
    return FormFactor.desktop;
  }
}
