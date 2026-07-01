import 'package:flutter/material.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/futuristic_colors.dart';

/// Desktop Content Container
///
/// A standardized wrapper for all screen content that provides:
/// - Max-width constraint for desktop readability
/// - Consistent padding and spacing
/// - Optional header with title and actions
/// - Proper scroll behavior
///
/// Usage:
/// ```dart
/// return DesktopContentContainer(
///   title: 'Inventory',
///   actions: [AddButton(), FilterButton()],
///   child: YourContent(),
/// );
/// ```
class DesktopContentContainer extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets? padding;
  final bool showScrollbar;
  final ScrollController? scrollController;

  /// When true (default), a Back button is auto-injected into the header
  /// if the Navigator stack has depth (canPop). Set to false for root screens.
  final bool showBackButton;

  const DesktopContentContainer({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions,
    this.maxWidth = 1400,
    this.padding,
    this.showScrollbar = true,
    this.scrollController,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // Wrap in scrollable if needed
    if (showScrollbar) {
      content = Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: padding ?? const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      );
    } else {
      content = Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      );
    }

    // If no title, return just the content
    if (title == null) {
      return content;
    }

    // Build header + content layout.
    // Paint the active theme's scaffold background behind the header + content
    // so light/dark regions match consistently (R9.5).
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeader(context),

          // Content
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return SafeArea(
      // Zero insets on desktop (Windows render path unchanged); on mobile this
      // keeps the title/subtitle clear of the status bar and notch (R7.3, R11.3).
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.5),
          border: Border(
            bottom: BorderSide(
              color: isDark ? primaryColor.withOpacity(0.2) : theme.dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Auto-injected Back Button
            if (showBackButton && Navigator.of(context).canPop()) ...[
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
                tooltip: 'Go Back',
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
              const SizedBox(width: 8),
            ],
            // Title Section
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.isMobile ? 16 : 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: theme.hintColor),
                    ),
                  ],
                ],
              ),
            ),

            // Actions — wrap in Flexible on mobile to prevent overflow
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: 16),
              Flexible(
                child: context.isMobile
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: actions!,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!
                            .map(
                              (action) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: action,
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Premium Action Button for use in DesktopContentContainer actions
class DesktopActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color? color;

  const DesktopActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.color,
  });

  @override
  State<DesktopActionButton> createState() => _DesktopActionButtonState();
}

class _DesktopActionButtonState extends State<DesktopActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = widget.onPressed == null;
    final buttonColor = isDisabled
        ? theme.hintColor.withOpacity(0.5)
        : (widget.color ?? theme.colorScheme.primary);
    final isMobile = context.isMobile;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Tooltip(
          message: isMobile ? widget.label : '',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: widget.isPrimary && !isDisabled
                  ? buttonColor.withOpacity(_isHovered ? 1.0 : 0.9)
                  : buttonColor.withOpacity(
                      isDisabled ? 0.05 : (_isHovered ? 0.15 : 0.1),
                    ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: buttonColor.withOpacity(
                  isDisabled ? 0.1 : (widget.isPrimary ? 0.5 : 0.3),
                ),
                width: 1,
              ),
              boxShadow: widget.isPrimary && _isHovered && !isDisabled
                  ? [
                      BoxShadow(
                        color: buttonColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isPrimary && !isDisabled
                      ? theme.colorScheme.onPrimary
                      : buttonColor,
                ),
                // On mobile: icon-only to save space; on desktop: show label
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.isPrimary && !isDisabled
                          ? theme.colorScheme.onPrimary
                          : buttonColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only action button for compact toolbars
class DesktopIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const DesktopIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  State<DesktopIconButton> createState() => _DesktopIconButtonState();
}

class _DesktopIconButtonState extends State<DesktopIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = widget.onPressed == null;
    final iconColor = isDisabled
        ? theme.hintColor.withOpacity(0.3)
        : (widget.color ?? theme.hintColor);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _isHovered && !isDisabled
                  ? theme.colorScheme.primary.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: _isHovered && !isDisabled
                  ? theme.colorScheme.primary
                  : iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
