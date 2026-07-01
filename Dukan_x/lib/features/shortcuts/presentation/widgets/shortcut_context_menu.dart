import 'package:flutter/material.dart';
import '../../domain/models/user_shortcut_config.dart';

class ShortcutContextMenu extends StatelessWidget {
  final UserShortcutConfig config;
  final VoidCallback onRemove;
  final VoidCallback onTogglePriority;

  const ShortcutContextMenu({
    super.key,
    required this.config,
    required this.onRemove,
    required this.onTogglePriority,
  });

  @override
  Widget build(BuildContext context) {
    // In a real desktop app, we might use a sophisticated    
    // For now, this logic is embedded in the UI via showMenu or similar.
    // This file keeps architecture clean for future expansion.
    return const SizedBox.shrink();
  }
}
