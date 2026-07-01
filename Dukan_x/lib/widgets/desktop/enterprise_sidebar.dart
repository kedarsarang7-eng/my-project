import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../core/theme/futuristic_colors.dart';
// import '../../models/business_type.dart';
import 'sidebar_menu_item_widget.dart'; // Safe isolated widget
import 'sidebar_configuration.dart'; // New Configuration Provider & Models
// PHASE 3: Show the active business type in the sidebar header. Reads from
// the Phase 2 single source of truth — no ad-hoc data path for this label.
import '../../providers/app_state_providers.dart';
import '../../core/billing/business_type_config.dart';

/// Sidebar mode state
class SidebarModeState {
  final SidebarMode mode;
  const SidebarModeState({this.mode = SidebarMode.expanded});
  SidebarModeState copyWith({SidebarMode? mode}) =>
      SidebarModeState(mode: mode ?? this.mode);
}

/// Sidebar mode notifier
class SidebarModeNotifier extends Notifier<SidebarModeState> {
  @override
  SidebarModeState build() => const SidebarModeState();

  void setMode(SidebarMode mode) {
    state = state.copyWith(mode: mode);
  }

  void toggle() {
    switch (state.mode) {
      case SidebarMode.expanded:
        state = state.copyWith(mode: SidebarMode.collapsed);
        break;
      case SidebarMode.collapsed:
        state = state.copyWith(mode: SidebarMode.mini);
        break;
      case SidebarMode.mini:
        state = state.copyWith(mode: SidebarMode.expanded);
        break;
    }
  }
}

/// Provider for sidebar mode state
final sidebarModeProvider =
    NotifierProvider<SidebarModeNotifier, SidebarModeState>(
      SidebarModeNotifier.new,
    );

/// Expanded sections state
class ExpandedSectionsState {
  final Set<int> sections;
  const ExpandedSectionsState({this.sections = const {0, 1, 2}});
  ExpandedSectionsState copyWith({Set<int>? sections}) =>
      ExpandedSectionsState(sections: sections ?? this.sections);
}

/// Expanded sections notifier
class ExpandedSectionsNotifier extends Notifier<ExpandedSectionsState> {
  @override
  ExpandedSectionsState build() => const ExpandedSectionsState();

  void toggle(int index) {
    final newSet = Set<int>.from(state.sections);
    if (newSet.contains(index)) {
      newSet.remove(index);
    } else {
      newSet.add(index);
    }
    state = state.copyWith(sections: newSet);
  }

  void expand(int index) {
    final newSet = Set<int>.from(state.sections);
    newSet.add(index);
    state = state.copyWith(sections: newSet);
  }
}

/// Provider for expanded sections
final expandedSectionsProvider =
    NotifierProvider<ExpandedSectionsNotifier, ExpandedSectionsState>(
      ExpandedSectionsNotifier.new,
    );

/// Enterprise Desktop Sidebar - Complete collapsible navigation
class EnterpriseDesktopSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final String? selectedItemId;
  final Function(String itemId, int sectionIndex)? onItemSelected;

  const EnterpriseDesktopSidebar({
    super.key,
    this.selectedIndex = 0,
    this.selectedItemId,
    this.onItemSelected,
  });

  @override
  ConsumerState<EnterpriseDesktopSidebar> createState() =>
      _EnterpriseDesktopSidebarState();
}

class _EnterpriseDesktopSidebarState
    extends ConsumerState<EnterpriseDesktopSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  // ignore: unused_field - Reserved for future animation interpolation
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnimation = Tween<double>(begin: 280, end: 72).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    final currentMode = ref.read(sidebarModeProvider).mode;
    SidebarMode nextMode = SidebarMode.expanded;

    switch (currentMode) {
      case SidebarMode.expanded:
        nextMode = SidebarMode.collapsed;
        _animationController.forward();
        break;
      case SidebarMode.collapsed:
        nextMode = SidebarMode.mini;
        break;
      case SidebarMode.mini:
        nextMode = SidebarMode.expanded;
        _animationController.reverse();
        break;
    }

    ref.read(sidebarModeProvider.notifier).setMode(nextMode);
  }

  void _toggleSection(int index) {
    ref.read(expandedSectionsProvider.notifier).toggle(index);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(sidebarModeProvider).mode;
    final expandedSections = ref.watch(expandedSectionsProvider).sections;

    // Optimized: Watch the memoized provider. Rebuilds ONLY when configuration changes.
    final sections = ref.watch(sidebarSectionsProvider);

    // Calculate sidebar width based on mode
    double sidebarWidth = 280;
    switch (mode) {
      case SidebarMode.expanded:
        sidebarWidth = 280;
        break;
      case SidebarMode.collapsed:
        sidebarWidth = 72;
        break;
      case SidebarMode.mini:
        sidebarWidth = 48;
        break;
    }

    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Logo Header with toggle
              _buildHeader(mode),

              // Scrollable Sections
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: mode == SidebarMode.mini ? 4 : 8,
                    vertical: 12,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    return _buildSection(
                      sections[index],
                      mode,
                      expandedSections.contains(index),
                    );
                  },
                ),
              ),

              // Footer with mode toggle hint
              _buildFooter(mode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SidebarMode mode) {
    final isExpanded = mode == SidebarMode.expanded;

    // PHASE 3: Watch the single source of truth so the header label updates
    // instantly when the user switches business type. `BusinessType.other` is
    // the notifier's pre-rehydration default, so we render a neutral
    // placeholder until _loadFromPrefs resolves (graceful degradation, no
    // blank/broken header).
    final businessState = ref.watch(businessTypeProvider);
    final type = businessState.type;
    final isPlaceholder =
        type == BusinessType.other && businessState.customName == null;
    final displayName = businessState.customName?.isNotEmpty == true
        ? businessState.customName!
        : _titleCase(type.name);

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 20 : 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo Icon — emoji badge replaces plain store icon when a real
          // business type is known, so even collapsed/mini mode surfaces it.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: FuturisticColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: FuturisticColors.accent1.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: isPlaceholder
                  ? const Icon(Icons.store_rounded, color: Colors.white, size: 22)
                  : Text(type.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),

          if (isExpanded) ...[
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIXED: use theme-aware text color instead of hardcoded white
                  Text(
                    'DukanX',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // PHASE 3: subtitle now shows the live business type (was a
                  // static "Enterprise Suite" string). Uses the type's brand
                  // color to stay consistent with the rest of the app.
                  Text(
                    isPlaceholder ? 'Loading…' : displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isPlaceholder
                          ? Theme.of(context).hintColor
                          : type.primaryColor,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Toggle Button
          if (mode != SidebarMode.mini) _buildToggleButton(),
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

  Widget _buildToggleButton() {
    final modeState = ref.watch(sidebarModeProvider);
    final isExpanded = modeState.mode == SidebarMode.expanded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleMode,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Icon(
            isExpanded
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            // FIXED: theme-aware toggle icon color
            color: Theme.of(context).hintColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    SidebarSection section,
    SidebarMode mode,
    bool isExpanded,
  ) {
    final isFullMode = mode == SidebarMode.expanded;
    final isMiniMode = mode == SidebarMode.mini;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleSection(section.index),
            borderRadius: BorderRadius.circular(10),
            // FIXED: theme-aware hover color
            hoverColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isMiniMode ? 2 : 8,
                vertical: 4,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMiniMode ? 6 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: isExpanded
                    ? LinearGradient(
                        colors: [
                          section.accentColor!.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(10),
                border: isExpanded
                    ? Border.all(
                        color: section.accentColor!.withOpacity(0.2),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Section Icon with premium glow
                  Container(
                    width: isMiniMode ? 28 : 32,
                    height: isMiniMode ? 28 : 32,
                    decoration: BoxDecoration(
                      color: section.accentColor!.withOpacity(
                        isExpanded ? 0.2 : 0.15,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isExpanded
                          ? [
                              BoxShadow(
                                color: FuturisticColors.premiumBlue.withOpacity(
                                  0.3,
                                ),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      section.icon,
                      color: section.accentColor,
                      size: isMiniMode ? 16 : 18,
                    ),
                  ),

                  if (isFullMode) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // FIXED: theme-aware section title color
                          Text(
                            section.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (section.shortcutHint != null)
                            Text(
                              section.shortcutHint!,
                              style: TextStyle(
                                fontSize: 10,
                                // FIXED: theme-aware shortcut hint color
                                color: Theme.of(context).hintColor.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      // FIXED: theme-aware chevron color
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).hintColor,
                        size: 18,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Section Items (Animated)
        AnimatedCrossFade(
          firstChild: Column(
            children: section.items.map((item) {
              return _buildMenuItem(item, section, mode);
            }).toList(),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded && isFullMode
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMenuItem(
    SidebarMenuItem item,
    SidebarSection section,
    SidebarMode mode,
  ) {
    return SidebarMenuItemWidget(
      key: ValueKey('${section.index}_${item.id}'), // STABLE KEY is critical
      item: item,
      section: section,
      mode: mode,
      isSelected: widget.selectedItemId == item.id,
      onTap: () => widget.onItemSelected?.call(item.id, section.index),
    );
  }

  Widget _buildFooter(SidebarMode mode) {
    final isFullMode = mode == SidebarMode.expanded;

    return Container(
      padding: EdgeInsets.all(isFullMode ? 16 : 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: isFullMode
          ? Row(
              children: [
                Icon(
                  Icons.keyboard_alt_outlined,
                   size: 14,
                   // FIXED: theme-aware footer icon
                   color: Theme.of(context).hintColor.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                 Text(
                   'Ctrl + \\ to toggle',
                   style: TextStyle(
                     fontSize: 11,
                     // FIXED: theme-aware footer text
                     color: Theme.of(context).hintColor.withOpacity(0.6),
                   ),
                 ),
              ],
            )
          : Icon(
              Icons.keyboard_alt_outlined,
              size: 16,
              // FIXED: theme-aware mini footer icon
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
    );
  }
}
