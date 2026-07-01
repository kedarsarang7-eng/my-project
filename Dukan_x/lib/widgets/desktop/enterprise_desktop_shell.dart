import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/futuristic_colors.dart';
import 'enterprise_sidebar.dart';
import 'sidebar_configuration.dart'; // IMPORT ADDED
import 'premium_content_wrapper.dart';
import '../../core/sync/engine/sync_engine.dart'; // UPDATED
import '../../core/sync/models/sync_types.dart'; // UPDATED

/// Selected sidebar item state
class SelectedSidebarItemState {
  final String itemId;
  const SelectedSidebarItemState({this.itemId = 'executive_dashboard'});
  SelectedSidebarItemState copyWith({String? itemId}) =>
      SelectedSidebarItemState(itemId: itemId ?? this.itemId);
}

/// Selected sidebar item notifier
class SelectedSidebarItemNotifier extends Notifier<SelectedSidebarItemState> {
  @override
  SelectedSidebarItemState build() => const SelectedSidebarItemState();

  void setItem(String itemId) {
    state = state.copyWith(itemId: itemId);
  }
}

/// Provider for selected sidebar item
final selectedSidebarItemProvider =
    NotifierProvider<SelectedSidebarItemNotifier, SelectedSidebarItemState>(
      SelectedSidebarItemNotifier.new,
    );

/// Enterprise Desktop Shell - Main layout container with enterprise sidebar
class EnterpriseDesktopShell extends ConsumerStatefulWidget {
  final Widget child;
  final Widget? rightPanel;
  final String? currentItemId;
  final Function(String itemId)? onNavigate;

  const EnterpriseDesktopShell({
    super.key,
    required this.child,
    this.rightPanel,
    this.currentItemId,
    this.onNavigate,
  });

  @override
  ConsumerState<EnterpriseDesktopShell> createState() =>
      _EnterpriseDesktopShellState();
}

class _EnterpriseDesktopShellState
    extends ConsumerState<EnterpriseDesktopShell> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle Ctrl+\ for sidebar toggle
      if (event.logicalKey == LogicalKeyboardKey.backslash &&
          HardwareKeyboard.instance.isControlPressed) {
        _toggleSidebar();
        return;
      }

      // Handle Ctrl+1 to Ctrl+0 for section navigation
      if (HardwareKeyboard.instance.isControlPressed) {
        int? sectionIndex;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.digit1:
            sectionIndex = 0;
            break;
          case LogicalKeyboardKey.digit2:
            sectionIndex = 1;
            break;
          case LogicalKeyboardKey.digit3:
            sectionIndex = 2;
            break;
          case LogicalKeyboardKey.digit4:
            sectionIndex = 3;
            break;
          case LogicalKeyboardKey.digit5:
            sectionIndex = 4;
            break;
          case LogicalKeyboardKey.digit6:
            sectionIndex = 5;
            break;
          case LogicalKeyboardKey.digit7:
            sectionIndex = 6;
            break;
          case LogicalKeyboardKey.digit8:
            sectionIndex = 7;
            break;
          case LogicalKeyboardKey.digit9:
            sectionIndex = 8;
            break;
          case LogicalKeyboardKey.digit0:
            sectionIndex = 9;
            break;
        }

        if (sectionIndex != null) {
          _expandAndNavigateToSection(sectionIndex);
        }
      }
    }
  }

  void _toggleSidebar() {
    final currentMode = ref.read(sidebarModeProvider).mode;
    SidebarMode nextMode = SidebarMode.expanded;

    switch (currentMode) {
      case SidebarMode.expanded:
        nextMode = SidebarMode.collapsed;
        break;
      case SidebarMode.collapsed:
        nextMode = SidebarMode.expanded;
        break;
      case SidebarMode.mini:
        nextMode = SidebarMode.expanded;
        break;
    }

    ref.read(sidebarModeProvider.notifier).setMode(nextMode);
  }

  void _expandAndNavigateToSection(int sectionIndex) {
    // Expand the section
    ref.read(expandedSectionsProvider.notifier).expand(sectionIndex);

    // Ensure sidebar is expanded
    ref.read(sidebarModeProvider.notifier).setMode(SidebarMode.expanded);
  }

  void _handleItemSelected(String itemId, int sectionIndex) {
    ref.read(selectedSidebarItemProvider.notifier).setItem(itemId);
    widget.onNavigate?.call(itemId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = ref.watch(selectedSidebarItemProvider).itemId;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            // Enterprise Sidebar
            EnterpriseDesktopSidebar(
              selectedItemId: widget.currentItemId ?? selectedItem,
              onItemSelected: _handleItemSelected,
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Bar
                  EnterpriseTopBar(),

                  // Route Content with Premium Star Background
                  Expanded(
                    child: PremiumContentWrapper(
                      showStarField: true,
                      showGradientOverlay: true,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),

            // Optional Right Panel
            if (widget.rightPanel != null)
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(left: BorderSide(color: theme.dividerColor)),
                ),
                child: widget.rightPanel!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Enterprise Top Bar - Futuristic command bar
class EnterpriseTopBar extends ConsumerWidget {
  const EnterpriseTopBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // final colorScheme = theme.colorScheme;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color:
            theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
        boxShadow: [
          // Premium blue glow effect
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Breadcrumb / Page Title
          const _BreadcrumbNav(),

          const Spacer(),

          // Global Search
          _buildSearchBar(context),

          const SizedBox(width: 24),

          // Sync Status Indicator (Real Data)
          const _TopBarSyncIndicator(),

          const SizedBox(width: 16),

          // User Profile
          _buildUserProfile(),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320, minWidth: 150),
        height: 40,
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search_rounded,
              color: theme.hintColor.withOpacity(0.6),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search anything... (Ctrl+K)',
                  hintStyle: TextStyle(
                    color: theme.hintColor.withOpacity(0.5),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Ctrl+K',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.hintColor.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: FuturisticColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: FuturisticColors.accent1.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ), // End Container
      ],
    ); // End Row
  }
}

/// Real Sync Status Indicator for Top Bar
class _TopBarSyncIndicator extends StatefulWidget {
  const _TopBarSyncIndicator();

  @override
  State<_TopBarSyncIndicator> createState() => _TopBarSyncIndicatorState();
}

class _TopBarSyncIndicatorState extends State<_TopBarSyncIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStats>(
      stream: SyncEngine.instance.statsStream, // Listen to Real Stream
      builder: (context, snapshot) {
        final stats = snapshot.data;

        // Default state (Loading or Init)
        if (stats == null) {
          return _TopBarIconButton(
            icon: Icons.cloud_off_rounded,
            tooltip: 'Checking Sync Status...',
            accentColor: Colors.grey,
            onTap: () => context.push('/sync-status'),
          );
        }

        // Determine State
        bool isSyncing = stats.inProgressCount > 0;
        bool hasError = stats.failedCount > 0;
        bool isPending = stats.pendingCount > 0;

        if (isSyncing) {
          _spinController.repeat();
          return RotationTransition(
            turns: _spinController,
            child: _TopBarIconButton(
              icon: Icons.sync,
              tooltip: 'Syncing ${stats.pendingCount} items...',
              accentColor: Colors.blue,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync in progress...')),
                );
                context.push('/sync-status');
              },
            ),
          );
        } else {
          _spinController.stop();
        }

        if (hasError) {
          return _TopBarIconButton(
            icon: Icons.cloud_off,
            tooltip: 'Sync Error! ${stats.failedCount} items failed.',
            accentColor: Theme.of(context).colorScheme.error,
            onTap: () => context.push('/sync-status'),
          );
        }

        if (isPending) {
          return _TopBarIconButton(
            icon: Icons.cloud_upload_outlined,
            tooltip: '${stats.pendingCount} Pending Uploads',
            accentColor: Colors.orange,
            onTap: () {
              // Trigger sync on click
              SyncEngine.instance.triggerSync();
              context.push('/sync-status');
            },
          );
        }

        // All Synced (Green)
        return _TopBarIconButton(
          icon: Icons.cloud_done_rounded,
          tooltip: 'All Data Synced',
          accentColor: const Color(0xFF22C55E), // Green 500
          onTap: () => context.push('/sync-status'),
        );
      },
    );
  }
}

/// Breadcrumb Navigation
class _BreadcrumbNav extends StatelessWidget {
  const _BreadcrumbNav();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).hintColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: Theme.of(context).hintColor.withOpacity(0.5),
          ),
        ),
        Text(
          'Executive Dashboard',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Top Bar Icon Button - Optimized for Desktop with ValueNotifier
class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? accentColor;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Isolated hover state using ValueNotifier
    // This prevents the parent (TopBar) from rebuilding on every mouse movement
    final ValueNotifier<bool> isHoveredNotifier = ValueNotifier(false);

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        onEnter: (_) => isHoveredNotifier.value = true,
        onExit: (_) => isHoveredNotifier.value = false,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ValueListenableBuilder<bool>(
            valueListenable: isHoveredNotifier,
            builder: (context, isHovered, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isHovered
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      icon,
                      color: accentColor ?? Theme.of(context).hintColor,
                      size: 22,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
