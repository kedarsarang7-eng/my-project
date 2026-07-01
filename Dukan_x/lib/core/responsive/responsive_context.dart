// Responsive context helpers — BuildContext extension for the consolidated
// Responsive_System.
//
// This extension exposes the context helpers required by Req 1.6 (Form_Factor,
// orientation, keyboard visibility, Safe_Area insets, and Accessibility font
// scaling) plus convenient screen-dimension accessors. Every value is derived
// from `MediaQuery` via the aspect-specific lookups (`MediaQuery.sizeOf`,
// `MediaQuery.orientationOf`, ...). Using these aspect lookups registers a
// dependency on the relevant MediaQuery aspect, so when the screen width
// changes such that it crosses a Breakpoint_Strategy boundary, dependents
// rebuild and `formFactor` is re-classified (Req 1.8).
//
// Form_Factor classification defers entirely to the single source of truth in
// `responsive_breakpoints.dart` (`ResponsiveBreakpoints.classify`); this file
// never defines breakpoint thresholds of its own.
//
// Part of: cross-platform-responsive-ui

import 'package:flutter/widgets.dart';

import 'responsive_breakpoints.dart';

/// Responsive helpers on [BuildContext] for the consolidated Responsive_System.
///
/// All getters read from `MediaQuery` so that the widget that uses them rebuilds
/// when the relevant MediaQuery aspect changes. In particular, [formFactor] is
/// derived from the current width and re-classifies automatically when a width
/// change crosses a breakpoint boundary (Req 1.8).
extension ResponsiveContext on BuildContext {
  /// The current [FormFactor], classified from the logical screen width using
  /// the single source of truth [ResponsiveBreakpoints.classify].
  FormFactor get formFactor => ResponsiveBreakpoints.classify(screenWidth);

  /// True when the current [FormFactor] is [FormFactor.mobile] (width < 600).
  bool get isMobile => formFactor == FormFactor.mobile;

  /// True when the current [FormFactor] is [FormFactor.tablet] (600..<1100).
  bool get isTablet => formFactor == FormFactor.tablet;

  /// True when the current [FormFactor] is [FormFactor.desktop] (width >= 1100).
  bool get isDesktop => formFactor == FormFactor.desktop;

  /// The current device [Orientation] (portrait or landscape).
  Orientation get orientation => MediaQuery.orientationOf(this);

  /// True while the device is in portrait orientation.
  bool get isPortrait => orientation == Orientation.portrait;

  /// True while the device is in landscape orientation.
  bool get isLandscape => orientation == Orientation.landscape;

  /// True while the on-screen keyboard is visible (bottom view inset > 0).
  bool get isKeyboardVisible => keyboardHeight > 0;

  /// The bottom view inset, i.e. the on-screen keyboard height when visible
  /// (0 when the keyboard is hidden).
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;

  /// The Safe_Area padding (notches, status bars, home indicators).
  EdgeInsets get safeAreaPadding => MediaQuery.paddingOf(this);

  /// The Accessibility font scale, i.e. the factor applied to a 1.0 logical
  /// font size by the platform text scaler.
  double get textScale => MediaQuery.textScalerOf(this).scale(1.0);

  /// The logical screen width.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// The logical screen height.
  double get screenHeight => MediaQuery.sizeOf(this).height;
}
