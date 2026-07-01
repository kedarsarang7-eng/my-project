import 'package:flutter/material.dart';
import '../core/theme/futuristic_colors.dart';
import 'glass_morphism.dart';

/// specialized bottom sheet with glass aesthetics
class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final bool showDragHandle;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.showDragHandle = true,
    this.height,
    this.padding,
  });

  /// Helper to show the sheet
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    IconData? icon,
    bool isScrollControlled = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassBottomSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: height ?? (MediaQuery.of(context).size.height * 0.85),
      ),
      child: Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: GlassContainer(
        borderRadius: 24,
        blur: 30,
        opacity: isDark ? 0.3 : 0.8,
        color: isDark ? FuturisticColors.darkSurface : Colors.white,
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.6),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        child: Column(
          children: [
            // Drag Handle
            if (showDragHandle)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Header
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: FuturisticColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: FuturisticColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: TextStyle(
                              fontSize: 24, // 2026-ready huge type
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: isDark
                                  ? FuturisticColors.darkTextPrimary
                                  : FuturisticColors.textPrimary,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? FuturisticColors.darkTextSecondary
                                    : FuturisticColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Close Button
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: isDark ? Colors.white54 : Colors.black54,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
