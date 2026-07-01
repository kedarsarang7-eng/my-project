import '../../../../features/shortcuts/domain/models/user_shortcut_config.dart';

class KeyboardShortcutManager {
  // Reserved OS/System shortcuts that we shouldn't override
  final Set<String> _reservedShortcuts = {
    'Ctrl+C', 'Ctrl+V', 'Ctrl+X', 'Ctrl+Z', 'Ctrl+Y', // Edit
    'Ctrl+A', 'Ctrl+S', 'Ctrl+W', 'Ctrl+Q', // File
    'Alt+Tab', 'Alt+F4', // Window
  };

  /// Check if a key binding conflicts with reserved shortcuts
  bool hasSystemConflict(String keyBinding) {
    return _reservedShortcuts.contains(keyBinding); // Case sensitive check
  }

  /// Check if a key binding is already used by another shortcut
  bool hasDuplicateConflict(
    String keyBinding,
    List<UserShortcutConfig> existingShortcuts,
    String currentId,
  ) {
    return existingShortcuts.any(
      (s) =>
          s.id != currentId && s.keyboardBinding == keyBinding && s.isEnabled,
    );
  }

  /// Get active bindings map for quick lookup
  Map<String, String> getActiveBindings(List<UserShortcutConfig> shortcuts) {
    return {
      for (final s in shortcuts)
        if (s.keyboardBinding != null && s.isEnabled)
          s.keyboardBinding!: s
              .shortcutId, // Map binding -> Definition ID (e.g. 'Ctrl+N' -> 'NEW_BILL')
    };
  }
}
