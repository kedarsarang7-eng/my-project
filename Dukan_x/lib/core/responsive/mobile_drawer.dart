// ============================================================================
// MOBILE DRAWER — Cross-Platform Navigation Drawer
// ============================================================================
// The navigation drawer used by the Mobile and Tablet shells (see
// adaptive_shell.dart). It satisfies the previously-broken `mobile_drawer.dart`
// import and provides full navigation parity with the desktop sidebar.
//
// Behavior (Requirements 3.1–3.6, 6.4):
//   - Consumes the SAME `sidebarSectionsProvider` as the desktop sidebar, so it
//     displays exactly the destinations enabled for the active business
//     context (Req 3.1, 3.3).
//   - Renders sections as a scrollable, safe-area list of `ExpansionTile`s, each
//     containing one `ListTile` per menu item, highlighting the tile whose
//     mapped `AppScreen` equals the current screen (Req 6.4).
//   - On tap, resolves the destination via the pure `DestinationResolver`:
//       * resolved   -> navigate, then close the drawer (Req 3.4, 3.5)
//       * unavailable -> keep the drawer open, retain the current screen, and
//                        show an inline error (Req 3.6)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_screens.dart';
import '../navigation/navigation_controller.dart';
import '../../widgets/desktop/sidebar_configuration.dart';
import 'navigation_destinations.dart';
// PHASE 3: Show the active business type at the top of the drawer. Reads from
// the same single source of truth established in Phase 2 (no ad-hoc data path).
import '../../providers/app_state_providers.dart';
import '../../core/billing/business_type_config.dart';

/// Navigation drawer for the Mobile and Tablet shells.
///
/// It is a [ConsumerWidget] so it can watch the same `sidebarSectionsProvider`
/// that drives the desktop sidebar, guaranteeing destination parity across
/// form factors (Req 3.3, 9.4).
class MobileDrawer extends ConsumerWidget {
  const MobileDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same source as the desktop sidebar — already filtered by business
    // capability and session permissions (Req 3.1, 3.3).
    final sections = ref.watch(sidebarSectionsProvider);

    // Watch only the current screen so the drawer rebuilds its highlight when
    // navigation changes, without rebuilding on unrelated state (Req 9.7).
    final current = ref.watch(
      navigationControllerProvider.select((s) => s.currentScreen),
    );

    // Build the set of navigable screens from the reachable destination ids.
    // This is exactly the `navigable` argument expected by DestinationResolver:
    // known screens reachable for the active business context (unknown excluded).
    final navigable = reachableDestinationIds(sections)
        .map(AppScreen.fromId)
        .where((screen) => screen != AppScreen.unknown)
        .toSet();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, ref),
            // Scrollable so long destination lists never overflow (Req 6.4).
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final section in sections)
                    _buildSection(context, ref, section, current, navigable),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Drawer header showing the active business type prominently.
  ///
  /// PHASE 3: Reads from `businessTypeProvider` (the Phase 2 single source of
  /// truth), so the label updates instantly when the user switches business
  /// type — no navigation/restart required. Degrades gracefully: while the
  /// provider is still rehydrating on boot (state.type == BusinessType.other
  /// before _loadFromPrefs completes), we show a neutral placeholder rather
  /// than a blank/broken header.
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final businessState = ref.watch(businessTypeProvider);
    final type = businessState.type;
    // `_initialized` is private to the notifier; we treat `BusinessType.other`
    // as the "not yet known" sentinel because it's the build() default before
    // _loadFromPrefs resolves. Custom-name takes precedence when present.
    final isPlaceholder =
        type == BusinessType.other && businessState.customName == null;
    final displayName = businessState.customName?.isNotEmpty == true
        ? businessState.customName!
        : _titleCase(type.name);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Menu',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: type.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: type.primaryColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isPlaceholder ? 'Business type loading…' : displayName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: type.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Title-case a snake_case enum name for display (e.g. "petrol_pump" → "Petrol Pump").
  String _titleCase(String name) {
    return name
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Builds an [ExpansionTile] for a sidebar section, expanded by default when
  /// it contains the active destination so the highlight is immediately visible.
  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    SidebarSection section,
    AppScreen current,
    Set<AppScreen> navigable,
  ) {
    final containsCurrent = section.items.any(
      (item) => AppScreen.fromId(item.id) == current,
    );

    return ExpansionTile(
      leading: Icon(section.icon, color: section.accentColor),
      title: Text(
        section.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      initiallyExpanded: containsCurrent,
      childrenPadding: const EdgeInsets.only(left: 8),
      children: [
        for (final item in section.items)
          _buildItem(context, ref, item, current, navigable),
      ],
    );
  }

  /// Builds a [ListTile] for a single menu item, highlighting it when its mapped
  /// [AppScreen] equals the current screen.
  Widget _buildItem(
    BuildContext context,
    WidgetRef ref,
    SidebarMenuItem item,
    AppScreen current,
    Set<AppScreen> navigable,
  ) {
    final itemScreen = AppScreen.fromId(item.id);
    final isSelected = itemScreen != AppScreen.unknown && itemScreen == current;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(item.icon),
      title: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      selected: isSelected,
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      onTap: () => _onItemTap(context, ref, item, navigable),
    );
  }

  /// Resolves the tapped destination and acts on the outcome.
  ///
  /// - resolved   -> navigate to the screen, then close the drawer (Req 3.4, 3.5)
  /// - unavailable -> keep the drawer open, do not navigate, show an inline
  ///   error indicating the destination is unavailable (Req 3.6)
  void _onItemTap(
    BuildContext context,
    WidgetRef ref,
    SidebarMenuItem item,
    Set<AppScreen> navigable,
  ) {
    final (resolution, screen) = DestinationResolver.resolve(
      item.id,
      navigable,
    );

    switch (resolution) {
      case DestinationResolution.resolved:
        ref.read(navigationControllerProvider.notifier).navigateTo(screen);
        // Close the drawer once navigation has been scheduled (Req 3.5).
        Navigator.of(context).pop();
      case DestinationResolution.unavailable:
        // Retain the current screen and keep the drawer open (Req 3.6).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${item.label}" is unavailable'),
              behavior: SnackBarBehavior.floating,
            ),
          );
    }
  }
}
