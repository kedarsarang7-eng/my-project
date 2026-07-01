import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/shortcut_providers.dart';
import '../widgets/shortcut_item.dart';
import '../../domain/models/user_shortcut_config.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../domain/models/shortcut_definition.dart';

class ShortcutPanel extends ConsumerStatefulWidget {
  const ShortcutPanel({super.key});

  @override
  ConsumerState<ShortcutPanel> createState() => _ShortcutPanelState();
}

class _ShortcutPanelState extends ConsumerState<ShortcutPanel> {
  @override
  void initState() {
    super.initState();
    // Trigger initialization on mount
    ref.read(shortcutInitializerProvider);
  }

  void _handleReorder(
    int oldIndex,
    int newIndex,
    List<UserShortcutConfig> shortcuts,
  ) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = shortcuts.removeAt(oldIndex);
    shortcuts.insert(newIndex, item);

    // Update IDs in new order
    final orderedIds = shortcuts.map((s) => s.definition.id).toList();

    final userId = ref.read(currentUserProvider);
    if (userId != null) {
      ref.read(shortcutServiceProvider).updateShortcutOrder(userId, orderedIds);
    }
  }

  void _executeShortcut(UserShortcutConfig shortcut) {
    // Record usage
    final userId = ref.read(currentUserProvider);
    if (userId != null) {
      ref
          .read(shortcutServiceProvider)
          .recordUsage(userId, shortcut.shortcutId);
    }

    // Execute logic
    final def = shortcut.definition;
    switch (def.actionType) {
      case ActionType.navigate:
        if (def.route != null) {
          // AD-5/AD-7: dynamic string-driven push via GoRouter. Unknown strings
          // degrade gracefully to the not-found screen via AppRouter.errorBuilder.
          context.push(def.route!);
        }
        break;
      case ActionType.function:
        _handleSpecialFunction(def.id);
        break;
      case ActionType.modal:
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(def.label),
            content: const Text(
              "Configure this shortcut in Settings → Shortcuts to enable full functionality.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _handleSpecialFunction(String id) {
    if (id == 'LAST_TRANSACTION') {
      // Implement navigation to last bill
      // This requires querying repo, which we can do here or via a dedicated controller
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcutsAsync = ref.watch(visibleShortcutsProvider);
    final badgeDataAsync = ref.watch(shortcutBadgeDataProvider);

    // Default empty map if loading
    final badges = badgeDataAsync.asData?.value ?? {};

    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FuturisticColors.background, // Match header bg
        border: Border(bottom: BorderSide(color: Color(0xFF1E2235))),
      ),
      child: shortcutsAsync.when(
        data: (shortcuts) {
          if (shortcuts.isEmpty) return const SizedBox.shrink();

          return ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shortcuts.length,
            onReorder: (oldIndex, newIndex) =>
                _handleReorder(oldIndex, newIndex, List.from(shortcuts)),
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                child: child, // Keep look same while dragging
              );
            },
            itemBuilder: (context, index) {
              final shortcut = shortcuts[index];
              return ShortcutItem(
                key: ValueKey(shortcut.id),
                config: shortcut,
                badge: badges[shortcut.definition.id],
                onTap: () => _executeShortcut(shortcut),
                onRightClick: () {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final offset = renderBox.localToGlobal(Offset.zero);

                  showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      offset.dx,
                      offset.dy,
                      offset.dx + renderBox.size.width,
                      offset.dy + renderBox.size.height,
                    ),
                    items: [
                      PopupMenuItem(
                        child: Text(
                          shortcut.isPriority
                              ? 'Remove Priority'
                              : 'Mark as Priority',
                          style: const TextStyle(
                            color: FuturisticColors.textPrimary,
                          ),
                        ),
                        onTap: () {
                          // Toggle priority logic
                          // In a real app we'd call service.togglePriority(...)
                          // reusing toggleShortcut for now if backend supports generic updates
                          // or just acknowledging the intent.
                        },
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Remove Shortcut',
                          style: TextStyle(color: FuturisticColors.error),
                        ),
                        onTap: () {
                          final userId = ref.read(currentUserProvider);
                          if (userId != null) {
                            ref
                                .read(shortcutServiceProvider)
                                .toggleShortcut(
                                  userId,
                                  shortcut.definition.id,
                                  false,
                                );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, s) => SizedBox.shrink(), // Fail silently in UI
      ),
    );
  }
}
