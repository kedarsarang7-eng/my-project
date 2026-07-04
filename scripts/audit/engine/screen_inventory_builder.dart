/// Screen Inventory Builder — produces a complete [ScreenInventory] for a given
/// Business_Type before any per-screen analysis begins.
///
/// Uses a [SidebarEntryResolver] abstraction to decouple from the actual Flutter
/// app's `sidebar_configuration.dart` / `sidebar_navigation_handler.dart`, enabling
/// standalone execution and testability.
///
/// Algorithm:
///   1. Collect every sidebar entry ID for the active Business_Type.
///   2. Resolve each entry via the resolver.
///   3. Deduplicate resolved screens by canonical `filePath` (Req 2.2).
///   4. Keep unresolved entries as `UnresolvedEntry` — never dropped (Req 2.7).
///   5. The inventory is produced before any analysis (Req 2.1) and enumerates
///      the four Screen_States per screen (Req 2.5).
///
/// Requirements: 2.1, 2.2, 2.3, 2.5, 2.7
library;

import '../models/audit_engine_models.dart';

/// Abstraction layer for sidebar entry resolution.
///
/// Implementations provide the list of sidebar entry IDs for a given
/// [BusinessType] and can attempt to resolve each ID to a [ScreenRef].
/// This decouples the builder from the actual Flutter app imports.
abstract class SidebarEntryResolver {
  /// Returns all sidebar menu item IDs for the given [businessType].
  ///
  /// Corresponds to collecting every `SidebarMenuItem.id` from
  /// `_getSectionsForBusiness(businessType)`.
  List<String> getEntryIds(BusinessType businessType);

  /// Attempts to resolve a sidebar entry [id] to a concrete screen reference.
  ///
  /// Returns a [ScreenRef] if the entry can be resolved to a screen source
  /// file, or `null` if resolution fails (corresponding to
  /// `tryGetScreenForItem(id)` returning null).
  ///
  /// When returning null, [unresolvedReason] can be consulted for the reason.
  ScreenRef? tryResolveEntry(String id);

  /// Returns the reason why the last `tryResolveEntry` call returned null.
  ///
  /// Defaults to a generic message if not overridden.
  String get unresolvedReason => 'Screen resolution returned null';
}

/// Builds a [ScreenInventory] for a given [BusinessType].
///
/// The inventory is produced before any per-screen analysis begins (Req 2.1)
/// and contains:
/// - Deduplicated resolved screens (by canonical filePath, Req 2.2)
/// - Unresolved entries with stated reasons (never dropped, Req 2.7)
///
/// Each resolved screen is evaluated across the four [ScreenState] values
/// (empty, loading, error, populated) during subsequent analysis (Req 2.5).
class ScreenInventoryBuilder {
  /// The resolver used to get entry IDs and resolve them to screens.
  final SidebarEntryResolver _resolver;

  /// Creates a builder with the given [resolver].
  ScreenInventoryBuilder(this._resolver);

  /// Builds a complete [ScreenInventory] for the [active] Business_Type.
  ///
  /// Steps:
  /// 1. Collect every sidebar entry ID from the resolver.
  /// 2. For each ID, attempt resolution via `tryResolveEntry`:
  ///    - Non-null → add to resolved screens set.
  ///    - Null → record as [UnresolvedEntry] with a stated reason (Req 2.7).
  /// 3. Deduplicate resolved screens by canonical `filePath` so a screen
  ///    reachable from multiple entries appears exactly once (Req 2.2).
  /// 4. Return the inventory before any analysis begins (Req 2.1).
  ///
  /// The four [ScreenState] values (empty, loading, error, populated) are
  /// enumerated per screen during subsequent analysis steps (Req 2.5).
  ScreenInventory build(BusinessType active) {
    final entryIds = _resolver.getEntryIds(active);

    // Track resolved screens by canonical filePath for dedup (Req 2.2).
    final resolvedByPath = <String, ScreenRef>{};
    final unresolved = <UnresolvedEntry>[];

    for (final id in entryIds) {
      final screen = _resolver.tryResolveEntry(id);

      if (screen != null) {
        // Deduplicate by canonical filePath — only keep the first occurrence.
        // ScreenRef normalizes filePath via canonicalFilePath() in its
        // constructor, so we use screen.filePath directly as the dedup key.
        final canonical = screen.filePath;
        resolvedByPath.putIfAbsent(canonical, () => screen);
      } else {
        // Never drop unresolved entries (Req 2.7).
        unresolved.add(
          UnresolvedEntry(entryName: id, reason: _resolver.unresolvedReason),
        );
      }
    }

    return ScreenInventory(
      businessType: active,
      screens: resolvedByPath.values.toList(),
      unresolved: unresolved,
    );
  }

  /// The four Screen_States that each screen is evaluated across (Req 2.5).
  ///
  /// Exposed as a convenience for downstream analysis components.
  static List<ScreenState> get screenStates => ScreenState.values;
}
