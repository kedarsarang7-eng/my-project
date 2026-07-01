import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// DESKTOP CHROME VISIBILITY CONTROLLER
// ============================================================================
// Backs the Desktop full-screen / distraction-free toggle (Req 5.6, 5.7).
//
// The desktop layout reads [desktopChromeVisibleProvider] to decide whether to
// render the left sidebar and the `EnterpriseTopBar`. When chrome is hidden the
// centered content host stays mounted, so the selected navigation destination
// survives the toggle and is retained when chrome is restored.
//
// Default: chrome VISIBLE (true).
//
// Part of: cross-platform-responsive-ui
// ============================================================================

/// Controls whether the Desktop_Shell "chrome" (left sidebar + `EnterpriseTopBar`)
/// is visible.
///
/// Uses the Riverpod `Notifier` pattern (Riverpod 3.x), matching the
/// `NavigationController` convention used elsewhere in the app.
///
/// - `true`  → chrome visible (normal layout)
/// - `false` → chrome hidden (full-screen / distraction-free view)
class DesktopChromeController extends Notifier<bool> {
  /// Chrome starts visible.
  @override
  bool build() => true;

  /// Toggle chrome visibility between visible and hidden.
  void toggle() => state = !state;

  /// Explicitly set chrome visibility.
  void set(bool visible) {
    if (state == visible) return;
    state = visible;
  }

  /// Show the chrome (exit full-screen / distraction-free view).
  void show() => set(true);

  /// Hide the chrome (enter full-screen / distraction-free view).
  void hide() => set(false);

  /// Convenience getter for the current visibility.
  bool get isVisible => state;
}

/// Riverpod provider exposing desktop chrome visibility as a `bool`.
///
/// Read by the desktop layout to hide/show the sidebar + `EnterpriseTopBar`
/// while keeping `DesktopContentHost` mounted (Req 5.6, 5.7).
final desktopChromeVisibleProvider =
    NotifierProvider<DesktopChromeController, bool>(
      DesktopChromeController.new,
    );
