import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';

enum ButtonType { primary, secondary, outline, danger }

class PrimaryButton extends ConsumerWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonType type;
  final bool isFullWidth;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.type = ButtonType.primary,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeStateProvider);
    final palette = themeProvider.palette;

    Color getBgColor() {
      switch (type) {
        case ButtonType.primary:
          return palette.leafGreen;
        case ButtonType.secondary:
          return palette.sunYellow;
        case ButtonType.danger:
          return palette.tomatoRed;
        case ButtonType.outline:
          return Colors.transparent;
      }
    }

    Color getTextColor() {
      switch (type) {
        case ButtonType.primary:
        case ButtonType.danger:
          return Colors.white;
        case ButtonType.secondary:
          return Colors.black87;
        case ButtonType.outline:
          return palette.leafGreen;
      }
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: getBgColor(),
      foregroundColor: getTextColor(),
      elevation: type == ButtonType.outline ? 0 : 0, // Flat premium look
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: type == ButtonType.outline
            ? BorderSide(color: palette.leafGreen, width: 2)
            : BorderSide.none,
      ),
    );

    final childWidget = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(getTextColor()),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    final button = ElevatedButton(
      onPressed: isLoading
          ? null
          : () {
              if (onPressed != null) {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            },
      style: buttonStyle,
      child: childWidget,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
