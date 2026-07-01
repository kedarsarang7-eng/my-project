// ============================================================================
// ACADEMIC COACHING — KEYBOARD SHORTCUTS MANAGER
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts for Academic Coaching module
class AcKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  const AcKeyboardShortcuts({
    super.key,
    required this.child,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}

/// Common AC shortcuts
class AcShortcuts {
  // Navigation
  static const saveRecord = SingleActivator(LogicalKeyboardKey.keyS, control: true);
  static const printDocument = SingleActivator(LogicalKeyboardKey.keyP, control: true);
  static const search = SingleActivator(LogicalKeyboardKey.keyF, control: true);
  static const refresh = SingleActivator(LogicalKeyboardKey.keyR, control: true);
  static const newRecord = SingleActivator(LogicalKeyboardKey.keyN, control: true);
  static const closeDialog = SingleActivator(LogicalKeyboardKey.escape);
  static const submitForm = SingleActivator(LogicalKeyboardKey.enter);
  
  // Quick actions
  static const quickBill = SingleActivator(LogicalKeyboardKey.keyB, control: true);
  static const studentSearch = SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true);
  static const attendanceMark = SingleActivator(LogicalKeyboardKey.keyA, control: true);
  static const feeCollection = SingleActivator(LogicalKeyboardKey.keyF, control: true, alt: true);

  /// Get all shortcut descriptions
  static Map<String, String> getShortcutHelp() => {
    'Ctrl+S': 'Save record',
    'Ctrl+P': 'Print',
    'Ctrl+F': 'Search',
    'Ctrl+R': 'Refresh',
    'Ctrl+N': 'New record',
    'Esc': 'Close dialog',
    'Ctrl+Shift+F': 'Student search',
    'Ctrl+A': 'Mark attendance',
    'Ctrl+Alt+F': 'Fee collection',
  };
}

/// Shortcut help dialog
class AcShortcutHelpDialog extends StatelessWidget {
  const AcShortcutHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final shortcuts = AcShortcuts.getShortcutHelp();
    
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard, color: Color(0xFF4F46E5)),
          SizedBox(width: 12),
          Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: shortcuts.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Shortcut indicator widget
class AcShortcutIndicator extends StatelessWidget {
  final String shortcut;
  final String label;

  const AcShortcutIndicator({
    super.key,
    required this.shortcut,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Shortcut: $shortcut',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
