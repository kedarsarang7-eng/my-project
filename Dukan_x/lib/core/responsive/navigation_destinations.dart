// ============================================================================
// NAVIGATION DESTINATIONS — Pure Helpers
// ============================================================================
// Pure, side-effect-free helpers for navigation destination handling. They are
// intentionally free of any widget tree or Riverpod dependency so destination
// parity and resolution outcomes can be unit/property tested in isolation.
//
//   - reachableDestinationIds : derives the flat set of destination ids from a
//     list of sidebar sections (the single source of reachable destinations).
//   - DestinationResolver     : maps a destination id to a concrete AppScreen
//     and a resolution outcome (resolved / unavailable).
//
// See design.md (Property 5: Destination parity, Property 6: Destination
// resolution) and Requirements 3.4, 3.6, 9.4, 9.6.
// ============================================================================

import '../navigation/app_screens.dart';
import '../../widgets/desktop/sidebar_configuration.dart';

/// Outcome of resolving a navigation destination id to a screen.
///
/// - [resolved]: the id maps to a known screen that is navigable.
/// - [unavailable]: the id is unknown ([AppScreen.unknown]) or the resolved
///   screen is not part of the navigable set for the active business context.
enum DestinationResolution { resolved, unavailable }

/// Derives the flat set of reachable destination ids from [sections].
///
/// Because every navigation surface (mobile drawer, tablet drawer, desktop
/// sidebar) derives its reachable destinations from the same
/// `sidebarSectionsProvider` output through this single function, their
/// reachable sets are equal by construction (Req 3.3, 9.4).
Set<String> reachableDestinationIds(List<SidebarSection> sections) =>
    sections.expand((s) => s.items).map((i) => i.id).toSet();

/// Pure resolver mapping a destination id to a screen and an outcome.
///
/// This makes destination resolution testable without a widget tree.
class DestinationResolver {
  const DestinationResolver._();

  /// Resolves [id] against the [navigable] screen set for the active business
  /// context.
  ///
  /// Returns:
  /// - `(DestinationResolution.unavailable, AppScreen.unknown)` when
  ///   [AppScreen.fromId] returns [AppScreen.unknown];
  /// - `(DestinationResolution.unavailable, screen)` when the resolved screen
  ///   is not contained in [navigable];
  /// - `(DestinationResolution.resolved, screen)` otherwise.
  ///
  /// The two outcomes are mutually exclusive and total over all ids
  /// (Req 3.4, 3.6, 9.6).
  static (DestinationResolution, AppScreen) resolve(
    String id,
    Set<AppScreen> navigable,
  ) {
    final screen = AppScreen.fromId(id);
    if (screen == AppScreen.unknown || !navigable.contains(screen)) {
      return (DestinationResolution.unavailable, screen);
    }
    return (DestinationResolution.resolved, screen);
  }
}
