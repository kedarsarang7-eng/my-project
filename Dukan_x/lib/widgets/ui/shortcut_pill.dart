/// Shortcut Pill - Inline keyboard hint widget
///
/// Shows keyboard shortcuts on buttons like:
/// - Save (Ctrl+S)
/// - Print (Ctrl+P)
/// - Cancel (ESC)
library;

import 'package:flutter/material.dart';

import '../../core/theme/futuristic_colors.dart';

/// Shortcut Pill - Shows keyboard hint inline with button text
class ShortcutPill extends StatelessWidget {
  final String shortcut;
  final Color? color;
  final double fontSize;

  const ShortcutPill({
    super.key,
    required this.shortcut,
    this.color,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? FuturisticColors.textSecondary).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (color ?? FuturisticColors.textSecondary).withOpacity(0.3),
        ),
      ),
      child: Text(
        shortcut,
        style: TextStyle(
          color: color ?? FuturisticColors.textSecondary,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Button with integrated shortcut hint
class ShortcutButton extends StatelessWidget {
  final String label;
  final String shortcut;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isPrimary;

  const ShortcutButton({
    super.key,
    required this.label,
    required this.shortcut,
    this.onPressed,
    this.icon,
    this.color,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor =
        color ??
        (isPrimary ? FuturisticColors.primary : FuturisticColors.surface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: buttonColor.withOpacity(isPrimary ? 1.0 : 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: buttonColor.withOpacity(isPrimary ? 0.5 : 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary ? Colors.white : buttonColor,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : buttonColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              ShortcutPill(
                shortcut: shortcut,
                color: isPrimary
                    ? Colors.white.withOpacity(0.7)
                    : buttonColor.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon button with shortcut tooltip
class ShortcutIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String shortcut;
  final VoidCallback? onPressed;
  final Color? color;

  const ShortcutIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.shortcut,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$tooltip ($shortcut)',
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color ?? FuturisticColors.textSecondary),
        splashRadius: 20,
      ),
    );
  }
}

/// Action bar with multiple shortcut buttons
class ShortcutActionBar extends StatelessWidget {
  final List<ShortcutButtonConfig> buttons;
  final MainAxisAlignment alignment;

  const ShortcutActionBar({
    super.key,
    required this.buttons,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: alignment,
        children:
            buttons
                .expand(
                  (config) => [
                    ShortcutButton(
                      label: config.label,
                      shortcut: config.shortcut,
                      icon: config.icon,
                      onPressed: config.onPressed,
                      isPrimary: config.isPrimary,
                      color: config.color,
                    ),
                    const SizedBox(width: 12),
                  ],
                )
                .toList()
              ..removeLast(), // Remove last spacer
      ),
    );
  }
}

/// Configuration for ShortcutButton
class ShortcutButtonConfig {
  final String label;
  final String shortcut;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color? color;

  const ShortcutButtonConfig({
    required this.label,
    required this.shortcut,
    this.icon,
    this.onPressed,
    this.isPrimary = false,
    this.color,
  });
}

/// Standard Tally-style action bar for forms
class TallyActionBar extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onPrint;
  final VoidCallback? onDelete;
  final bool showDelete;
  final bool showPrint;

  const TallyActionBar({
    super.key,
    this.onSave,
    this.onCancel,
    this.onPrint,
    this.onDelete,
    this.showDelete = false,
    this.showPrint = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShortcutActionBar(
      buttons: [
        if (showDelete)
          ShortcutButtonConfig(
            label: 'Delete',
            shortcut: 'Ctrl+D',
            icon: Icons.delete_outline,
            onPressed: onDelete,
            color: FuturisticColors.error,
          ),
        if (showPrint)
          ShortcutButtonConfig(
            label: 'Print',
            shortcut: 'Ctrl+P',
            icon: Icons.print_outlined,
            onPressed: onPrint,
          ),
        ShortcutButtonConfig(
          label: 'Cancel',
          shortcut: 'ESC',
          icon: Icons.close,
          onPressed: onCancel,
        ),
        ShortcutButtonConfig(
          label: 'Save',
          shortcut: 'Ctrl+S',
          icon: Icons.save_outlined,
          onPressed: onSave,
          isPrimary: true,
        ),
      ],
    );
  }
}
