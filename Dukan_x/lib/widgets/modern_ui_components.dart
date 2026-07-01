import 'package:flutter/material.dart';
import '../core/theme/futuristic_colors.dart';
// Export Desktop Components
export 'desktop/enterprise_table.dart';
export 'desktop/enterprise_dialog.dart';
export 'desktop/modern_tab_bar.dart';
export 'desktop/enterprise_button.dart';
export 'desktop/smart_form.dart';
export 'desktop/status_badge.dart';
export 'desktop/permission_wrapper.dart';
export 'desktop/empty_state.dart';
// Export Premium UI Widgets
export 'ui/premium_floating_button.dart';
export 'ui/premium_toggle.dart';
export 'ui/premium_chip.dart';
export 'ui/futuristic_button.dart';
export 'ui/button_hierarchy.dart';

// ============================================================================
// THEME CONSTANTS AND COLORS
// ============================================================================

/// @deprecated Use [FuturisticColors] instead for consistent theming.
/// This class is kept for backward compatibility only.
/// Futuristic Premium Color Palette
/// Supports both light and dark mode with vibrant, modern colors
@Deprecated(
  'Use FuturisticColors from core/theme/futuristic_colors.dart instead',
)
class AppColors {
  // Primary - Futuristic Teal
  static const Color primary = Color(0xFF00D9A5);
  static const Color primaryLight = Color(0xFF5DFFC4);
  static const Color primaryDark = Color(0xFF00A67E);

  // Secondary - Electric Purple
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color secondaryLight = Color(0xFFB388FF);
  static const Color secondaryDark = Color(0xFF5E35B1);

  // Accent - Coral Pink
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF9E9E);
  static const Color accentDark = Color(0xFFE53935);

  // Semantic Colors
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF40C4FF);

  // Light Mode Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Dark Mode Surfaces
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkSurfaceElevated = Color(0xFF475569);

  // Text Colors - Light Mode
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);

  // Text Colors - Dark Mode
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextHint = Color(0xFF94A3B8);

  // Utility Colors
  static const Color divider = Color(0xFFE2E8F0);
  static const Color darkDivider = Color(0xFF475569);
  static const Color shadow = Color(0x1A000000);
  static const Color glow = Color(0x4000D9A5);

  // Glass Effect Colors
  static const Color glassLight = Color(0x1AFFFFFF);
  static const Color glassDark = Color(0x1A000000);
  static const Color glassBorder = Color(0x33FFFFFF);
}

/// Premium Typography System
/// Based on Inter font family for modern, clean readability
class AppTypography {
  static const String fontFamily = 'Inter';

  // Display Styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.25,
  );

  // Headline Styles
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    height: 1.35,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );
}

/// Premium Shadow System
/// Provides consistent depth and elevation across the app
class AppShadows {
  // Card Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  // Elevated Shadows (for modals, FABs)
  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 32,
      spreadRadius: -8,
      offset: const Offset(0, 16),
    ),
  ];

  // Glow Shadows (for buttons, interactive elements)
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 16,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 32,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  // Soft Inner Shadow (for neumorphism)
  static List<BoxShadow> innerShadow = [
    const BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 8,
      spreadRadius: -2,
      offset: Offset(2, 2),
    ),
    const BoxShadow(
      color: Color(0x40FFFFFF),
      blurRadius: 8,
      spreadRadius: -2,
      offset: Offset(-2, -2),
    ),
  ];
}

/// Premium Gradient System
/// Consistent gradients for backgrounds, buttons, and overlays
class AppGradients {
  // Primary Gradient (Teal to Purple)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D9A5), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Secondary Gradient (Purple to Pink)
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Accent Gradient (Pink to Orange)
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFD600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glass Gradient (for glassmorphism)
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Glass Gradient
  static const LinearGradient darkGlassGradient = LinearGradient(
    colors: [Color(0x1A1E293B), Color(0x0D1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shimmer Gradient (for loading states)
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [Color(0x00FFFFFF), Color(0x33FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.5),
    end: Alignment(1.0, 0.5),
  );

  // Card Background Gradient (subtle)
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Dark Card Background Gradient
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Animation Constants
/// Consistent timing and curves for smooth interactions
class AppAnimations {
  // Durations
  static const Duration instant = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 800);

  // Curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve sharpCurve = Curves.easeOutExpo;
  static const Curve smoothCurve = Curves.easeInOutCubic;

  // Scale Values
  static const double pressedScale = 0.96;
  static const double hoverScale = 1.02;
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppBorderRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double xxl = 24.0;
}

// ============================================================================
// MODERN CARD WIDGET - Premium Animated with Glow and Gradient Effects
// ============================================================================

class ModernCard extends StatefulWidget {
  final Widget child;
  final double elevation;
  final Color backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool animated;
  final Gradient? gradient;
  final Gradient? borderGradient;
  final bool showGlow;
  final Color? glowColor;
  final bool useGlass;

  const ModernCard({
    super.key,
    required this.child,
    this.elevation = 2.0,
    this.backgroundColor = FuturisticColors.surface,
    this.borderRadius,
    this.padding,
    this.onTap,
    this.animated = true,
    this.gradient,
    this.borderGradient,
    this.showGlow = false,
    this.glowColor,
    this.useGlass = false,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: AppAnimations.pressedScale)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.animated) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.animated) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.animated) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(AppBorderRadius.xl);

    // Build glow shadows
    final glowShadows = widget.showGlow && _isPressed
        ? AppShadows.glowShadow(widget.glowColor ?? FuturisticColors.primary)
        : <BoxShadow>[];

    // Build card content
    Widget cardContent = Container(
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.gradient == null ? widget.backgroundColor : null,
        gradient: widget.gradient,
        borderRadius: effectiveBorderRadius,
        border: widget.borderGradient == null
            ? Border.all(
                color: isDark
                    ? FuturisticColors.darkDivider.withOpacity(0.3)
                    : FuturisticColors.divider,
                width: 1,
              )
            : null,
        boxShadow: [...AppShadows.cardShadow, ...glowShadows],
      ),
      child: widget.child,
    );

    // Wrap with gradient border if needed
    if (widget.borderGradient != null) {
      cardContent = Container(
        decoration: BoxDecoration(
          borderRadius: effectiveBorderRadius,
          gradient: widget.borderGradient,
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(
              (effectiveBorderRadius.topLeft.x) - 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              (effectiveBorderRadius.topLeft.x) - 1.5,
            ),
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(AppSpacing.md),
              child: widget.child,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: cardContent,
          );
        },
      ),
    );
  }
}

// ============================================================================
// ANIMATED MENU CARD - For Dashboard Navigation
// ============================================================================

class AnimatedMenuCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool showBadge;
  final String? badgeLabel;

  const AnimatedMenuCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.showBadge = false,
    this.badgeLabel,
  });

  @override
  State<AnimatedMenuCard> createState() => _AnimatedMenuCardState();
}

class _AnimatedMenuCardState extends State<AnimatedMenuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ModernCard(
          onTap: widget.onTap,
          backgroundColor:
              widget.backgroundColor ??
              FuturisticColors.primary.withOpacity(0.1),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 48,
                    color: widget.iconColor ?? FuturisticColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.showBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: FuturisticColors.error,
                      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                    ),
                    child: Text(
                      widget.badgeLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STATISTIC WIDGET - For Dashboard Metrics
// ============================================================================

class StatisticWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatisticWidget({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: onTap,
      backgroundColor: backgroundColor ?? FuturisticColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FuturisticColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: FuturisticColors.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (iconColor ?? FuturisticColors.primary).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? FuturisticColors.primary,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED BUTTON WITH RIPPLE EFFECT
// ============================================================================

// ModernButton moved to desktop/modern_button.dart

// ============================================================================
// EMPTY STATE WIDGET
// ============================================================================

// EmptyStateWidget moved to desktop/empty_state.dart

// ============================================================================
// LIST TILE WITH MODERN DESIGN
// ============================================================================

class ModernListTile extends StatelessWidget {
  final IconData? leadingIcon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showDivider;

  const ModernListTile({
    super.key,
    this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: (iconColor ?? FuturisticColors.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(
                      leadingIcon,
                      color: iconColor ?? FuturisticColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: FuturisticColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: FuturisticColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: FuturisticColors.divider),
          ),
      ],
    );
  }
}

// ============================================================================
// ANIMATED LOADING WIDGET
// ============================================================================

class AnimatedLoadingWidget extends StatefulWidget {
  final String? message;

  const AnimatedLoadingWidget({super.key, this.message});

  @override
  State<AnimatedLoadingWidget> createState() => _AnimatedLoadingWidgetState();
}

class _AnimatedLoadingWidgetState extends State<AnimatedLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: FuturisticColors.primary.withOpacity(0.2),
                  width: 4,
                ),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  FuturisticColors.primary,
                ),
              ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FuturisticColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED TAB BAR
// ============================================================================

class AnimatedTabBar extends StatefulWidget {
  final List<String> tabs;
  final int initialIndex;
  final Function(int) onTabChanged;

  const AnimatedTabBar({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    required this.onTabChanged,
  });

  @override
  State<AnimatedTabBar> createState() => _AnimatedTabBarState();
}

class _AnimatedTabBarState extends State<AnimatedTabBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        border: Border(
          bottom: BorderSide(color: FuturisticColors.divider, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(widget.tabs.length, (index) {
            final isSelected = _selectedIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = index);
                widget.onTabChanged(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? FuturisticColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  widget.tabs[index],
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? FuturisticColors.primary
                        : FuturisticColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
