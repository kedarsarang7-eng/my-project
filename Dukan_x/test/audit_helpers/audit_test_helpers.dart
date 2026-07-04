/// Barrel file for Flutter UI audit per-fix test helpers.
///
/// Import this single file to access all reusable test utilities:
///
/// ```dart
/// import 'audit_helpers/audit_test_helpers.dart';
/// ```
///
/// Provides:
/// - **Layout** — width-constrained pumping at phone/tablet/desktop widths.
/// - **Golden** — light/dark theme golden comparison.
/// - **Overflow** — `takeException()` assertion for overflow detection.
/// - **Navigation** — route/back-stack assertions.
/// - **Accessibility** — semantics label, traversal order, and tap-target checks.
///
/// These helpers satisfy Requirements 5.1–5.6 and keep per-fix tests DRY.
library;

export 'layout_test_helpers.dart';
export 'golden_test_helpers.dart';
export 'overflow_test_helpers.dart';
export 'navigation_test_helpers.dart';
export 'accessibility_test_helpers.dart';
