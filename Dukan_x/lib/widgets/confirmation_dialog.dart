import 'package:flutter/material.dart';
import '../core/theme/futuristic_colors.dart';
import 'glass_morphism.dart';
import 'modern_ui_components.dart';

/// Production-grade confirmation dialog for destructive actions
/// Prevents accidental deletes and provides clear user feedback
/// Now with FUTURISTIC GLASS AESTHETIC
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;
  final IconData? icon;
  final bool isDangerous;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor,
    this.icon,
    this.isDangerous = false,
  });

  /// Show a delete confirmation dialog
  static Future<bool> showDelete(
    BuildContext context, {
    required String itemName,
    String? customMessage,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmationDialog(
        title: 'Delete $itemName?',
        message:
            customMessage ??
            'This action cannot be undone. Are you sure you want to delete this $itemName?',
        confirmText: 'Delete',
        confirmColor: FuturisticColors.error,
        icon: Icons.delete_forever,
        isDangerous: true,
      ),
    );
    return result ?? false;
  }

  /// Show a generic confirmation dialog
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isDangerous,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        icon: icon,
        isDangerous: isDangerous,
      ),
    );
    return result ?? false;
  }

  /// Show logout confirmation
  static Future<bool> showLogout(BuildContext context) async {
    return await show(
      context,
      title: 'Log Out?',
      message: 'You will need to sign in again to access your account.',
      confirmText: 'Log Out',
      icon: Icons.logout,
      confirmColor: FuturisticColors.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveConfirmColor =
        confirmColor ??
        (isDangerous ? FuturisticColors.error : FuturisticColors.primary);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: TweenAnimationBuilder<double>(
        duration: AppAnimations.fast,
        tween: Tween(begin: 0.8, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: GlassContainer(
          borderRadius: 24,
          blur: 20,
          opacity: isDark ? 0.2 : 0.6,
          color: isDark ? FuturisticColors.darkSurface : Colors.white,
          borderGradient: LinearGradient(
            colors: isDangerous
                ? [
                    effectiveConfirmColor.withOpacity(0.5),
                    effectiveConfirmColor.withOpacity(0.1),
                  ]
                : [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.1),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          showGlow: isDangerous, // Subtle glow for dangerous warnings
          glowColor: effectiveConfirmColor,
          glowIntensity: 0.2,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with Glow
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: effectiveConfirmColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: effectiveConfirmColor.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: effectiveConfirmColor, size: 32),
                ),
                const SizedBox(height: 20),
              ],

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  color: isDark
                      ? FuturisticColors.darkTextPrimary
                      : FuturisticColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: isDark
                      ? FuturisticColors.darkTextSecondary
                      : FuturisticColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextMuted
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassButton(
                      label: confirmText,
                      onPressed: () => Navigator.of(context).pop(true),
                      gradient: isDangerous
                          ? FuturisticColors.errorGradient
                          : FuturisticColors.primaryGradient,
                      borderRadius: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
