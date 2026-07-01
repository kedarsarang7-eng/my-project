import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/responsive/desktop_chrome_provider.dart';
import '../../core/routing/route_paths.dart';
import '../../core/routing/sidebar_dispatch.dart';
import '../../core/theme/futuristic_colors.dart';
import 'enterprise_sidebar.dart';
import 'content_host.dart';
import 'premium_content_wrapper.dart';
// Reuse existing top bar from original shell or extract it.
// For now, I'll reimplement/extract the structure to ensure clean decoupling.
import 'enterprise_desktop_shell.dart';

/// The Root Shell for the Desktop Application.
/// This widget is CONST (ideally) and never rebuilds its structure.
/// Updates are handled by leaf widgets listening to [NavigationController].
class DesktopRootShell extends ConsumerWidget {
  const DesktopRootShell({super.key, this.routedChild});

  /// The go_router-routed screen body to render inside the content area.
  ///
  /// Supplied by the `ShellRoute` builder via [AdaptiveShell]. When non-null it
  /// REPLACES the fallback [DesktopContentHost] in the content region, so a
  /// sidebar tap that called `context.go(...)` shows the routed screen. When
  /// `null` (e.g. the `/app` shell base) the shell renders [DesktopContentHost]
  /// as a fallback. Everything else (sidebar, topbar, layout) is identical.
  final Widget? routedChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to navigation state ONLY for the sidebar selection ID
    // We use select to only rebuild if the screen ID changes, though
    // the sidebar itself handles internal state well too.
    final currentScreen = ref.watch(
      navigationControllerProvider.select((s) => s.currentScreen),
    );

    // Which sidebar item to HIGHLIGHT as selected. go_router is the sole
    // navigation path (Task 9.3), so the highlight is derived from the CURRENT
    // routed location. The ShellRoute rebuilds this widget on every navigation,
    // so `GoRouterState.of(context).uri` is always fresh. When the shell is not
    // mounted under a GoRouter (e.g. isolated widget tests), fall back to the
    // NavigationController selection so the highlight is never empty.
    String selectedItemId = currentScreen.id;
    if (GoRouter.maybeOf(context) != null) {
      final location = GoRouterState.of(context).uri.toString();
      final mappedItemId = RoutePaths.itemIdForPath(location);
      if (mappedItemId != null) selectedItemId = mappedItemId;
    }

    // Distraction-free / full-screen toggle (Req 5.6, 5.7).
    // When false, the sidebar + top bar are hidden while DesktopContentHost
    // stays mounted, so the selected destination is retained on exit.
    final chromeVisible = ref.watch(desktopChromeVisibleProvider);
    final chromeController = ref.read(desktopChromeVisibleProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Row(
            children: [
              // 1. SIDEBAR (Static placement, updates via props)
              // RepaintBoundary prevents rebuild propagation from content area.
              // Hidden in distraction-free mode (Req 5.6); restored on exit (Req 5.7).
              // FIXED: use Visibility(maintainState: true) instead of conditional
              // rendering so the sidebar widget remains in the tree, preserving
              // its internal state and guaranteeing it can always be restored
              // when chrome is toggled back on (sidebar-reopen bug fix).
              Visibility(
                visible: chromeVisible,
                maintainState: true,
                maintainAnimation: true,
                child: RepaintBoundary(
                  child: EnterpriseDesktopSidebar(
                    selectedItemId: selectedItemId,
                    onItemSelected: (itemId, _) {
                      // Task 3.4 / 9.3 — go_router dispatch (single seam):
                      // navigates via `context.go(...)` to the routed screen.
                      dispatchSidebarItem(context, itemId);
                    },
                  ),
                ),
              ),

              // 2. MAIN AREA
              Expanded(
                child: Column(
                  children: [
                    // TOP BAR — hidden in distraction-free mode (Req 5.6),
                    // restored on exit (Req 5.7).
                    // FIXED: kept mounted via Visibility for the same reason
                    // as the sidebar above.
                    Visibility(
                      visible: chromeVisible,
                      maintainState: true,
                      maintainAnimation: true,
                      child: const EnterpriseTopBar(),
                    ),

                    // CONTENT HOST (always mounted so the selected destination
                    // survives the full-screen toggle — Req 5.7).
                    //
                    // Task 3.4 / 9.3: the ShellRoute supplies `routedChild`,
                    // which renders here. When null (e.g. the `/app` shell
                    // base) the [DesktopContentHost] is used as a fallback.
                    Expanded(
                      child: PremiumContentWrapper(
                        showStarField: false,
                        showGradientOverlay: false,
                        child: routedChild ?? const DesktopContentHost(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Full-screen toggle affordance, reachable in BOTH states so the
          // user can always enter or exit distraction-free mode without
          // depending on the (possibly hidden) top bar. When chrome is visible
          // it sits just below the 64px top bar to avoid overlapping its
          // controls; when hidden it tucks into the top-right corner.
          Positioned(
            top: chromeVisible ? 76 : 12,
            right: 12,
            child: _FullScreenToggleButton(
              chromeVisible: chromeVisible,
              onPressed: chromeController.toggle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small overlay button to enter/exit the desktop distraction-free view.
///
/// Rendered in both states (chrome visible and hidden) so the user always has
/// a way to restore the chrome after entering full-screen mode (Req 5.6, 5.7).
class _FullScreenToggleButton extends StatelessWidget {
  const _FullScreenToggleButton({
    required this.chromeVisible,
    required this.onPressed,
  });

  final bool chromeVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: chromeVisible ? 'Enter full screen' : 'Exit full screen',
      child: Material(
        color: Colors.black.withOpacity(0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            chromeVisible
                ? Icons.fullscreen_rounded
                : Icons.fullscreen_exit_rounded,
            color: Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}
