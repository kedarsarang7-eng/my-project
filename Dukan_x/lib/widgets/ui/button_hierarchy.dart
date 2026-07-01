// ============================================================================
// BUTTON HIERARCHY SYSTEM - DukanX Premium UI
// ============================================================================
// Consistent button styles following the design system
// Primary: Main actions (Save, Submit, Create)
// Secondary: Alternative actions (Cancel, Back)
// Tertiary: Subtle actions (Learn more, View details)
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// Spacing and sizing constants for buttons
class ButtonSizes {
  ButtonSizes._();

  static const double heightLarge = 56.0;
  static const double heightMedium = 48.0;
  static const double heightSmall = 40.0;

  static const double borderRadius = 12.0;
  static const double iconSize = 20.0;

  static const EdgeInsets paddingLarge = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 16,
  );
  static const EdgeInsets paddingMedium = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 12,
  );
  static const EdgeInsets paddingSmall = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );
}

/// Primary Button - High emphasis, main action
/// Use for: Save, Submit, Create, Confirm, Pay
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final ButtonSize size;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.size = ButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final height = size == ButtonSize.large
        ? ButtonSizes.heightLarge
        : size == ButtonSize.small
        ? ButtonSizes.heightSmall
        : ButtonSizes.heightMedium;

    final padding = size == ButtonSize.large
        ? ButtonSizes.paddingLarge
        : size == ButtonSize.small
        ? ButtonSizes.paddingSmall
        : ButtonSizes.paddingMedium;

    Widget button = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? FuturisticColors.primaryGradient
            : LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade500],
              ),
        borderRadius: BorderRadius.circular(ButtonSizes.borderRadius),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: FuturisticColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(ButtonSizes.borderRadius),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (icon != null && !isLoading) ...[
                  Icon(icon, color: Colors.white, size: ButtonSizes.iconSize),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Secondary Button - Medium emphasis, alternative action
/// Use for: Cancel, Back, Edit, Skip
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isExpanded;
  final ButtonSize size;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isExpanded = false,
    this.size = ButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = size == ButtonSize.large
        ? ButtonSizes.heightLarge
        : size == ButtonSize.small
        ? ButtonSizes.heightSmall
        : ButtonSizes.heightMedium;

    final padding = size == ButtonSize.large
        ? ButtonSizes.paddingLarge
        : size == ButtonSize.small
        ? ButtonSizes.paddingSmall
        : ButtonSizes.paddingMedium;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.2)
        : FuturisticColors.primary.withOpacity(0.3);
    final textColor = isDark ? Colors.white : FuturisticColors.primary;

    Widget button = Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ButtonSizes.borderRadius),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(ButtonSizes.borderRadius),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: textColor, size: ButtonSizes.iconSize),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Tertiary Button - Low emphasis, subtle action
/// Use for: Learn more, View details, Read more, Help
class TertiaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool underline;

  const TertiaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? FuturisticColors.accent1
        : FuturisticColors.primary;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Danger Button - For destructive actions
/// Use for: Delete, Remove, Clear, Cancel Order
class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final ButtonSize size;

  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.size = ButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final height = size == ButtonSize.medium
        ? ButtonSizes.heightMedium
        : ButtonSizes.heightSmall;

    Widget button = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? FuturisticColors.errorGradient
            : LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade500],
              ),
        borderRadius: BorderRadius.circular(ButtonSizes.borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(ButtonSizes.borderRadius),
          child: Padding(
            padding: ButtonSizes.paddingMedium,
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (icon != null && !isLoading) ...[
                  Icon(icon, color: Colors.white, size: ButtonSizes.iconSize),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Icon Button with consistent styling
class PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const PremiumIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        backgroundColor ??
        (isDark
            ? Colors.white.withOpacity(0.1)
            : FuturisticColors.primary.withOpacity(0.1));
    final fgColor = iconColor ?? FuturisticColors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(icon, color: fgColor, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

/// Button size enum
enum ButtonSize { small, medium, large }
