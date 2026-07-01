import 'package:flutter/material.dart';
import 'futuristic_colors.dart';

/// Design Token System for DukanX Enterprise
///
/// Single source of truth for all spacing, shadows, radii, dimensions,
/// and animation parameters. NO hardcoded magic values elsewhere.
///
/// Usage:
/// ```dart
/// padding: EdgeInsets.all(DesignTokens.space4),
/// borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
/// boxShadow: DesignTokens.shadowSm,
/// duration: DesignTokens.durationNormal,
/// ```
class DesignTokens {
  DesignTokens._();

  // ══════════════════════════════════════════════════════════════════════════
  // SPACING SCALE (4px base)
  // ══════════════════════════════════════════════════════════════════════════
  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;
  static const double space20 = 80;

  // ══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS SCALE
  // ══════════════════════════════════════════════════════════════════════════
  static const double radiusXs = 4;
  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusXxl = 20;
  static const double radiusFull = 999;

  // ══════════════════════════════════════════════════════════════════════════
  // LAYOUT DIMENSIONS (Desktop)
  // ══════════════════════════════════════════════════════════════════════════
  static const double topbarHeight = 64;
  static const double sidebarExpandedWidth = 280;
  static const double sidebarCollapsedWidth = 72;
  static const double sidebarHeaderHeight = 72;
  static const double maxContentWidth = 1400;
  static const double rightPanelWidth = 320;

  // ══════════════════════════════════════════════════════════════════════════
  // LAYOUT DIMENSIONS (Mobile / Tablet)
  // ══════════════════════════════════════════════════════════════════════════
  static const double mobileAppBarHeight = 56;
  static const double bottomNavHeight = 64;
  static const double mobileMaxContentWidth = 600;
  static const double tabletMaxContentWidth = 900;
  static const double mobileDrawerWidth = 280;
  static const double tabletSidebarWidth = 72; // Icon-only on tablet
  static const double minTouchTarget = 44; // Minimum tap target for accessibility


  // ══════════════════════════════════════════════════════════════════════════
  // BREAKPOINTS (for desktop window resizing)
  // ══════════════════════════════════════════════════════════════════════════
  static const double breakpointCompact = 800;
  static const double breakpointMedium = 1024;
  static const double breakpointWide = 1440;

  // ══════════════════════════════════════════════════════════════════════════
  // ICON SIZES
  // ══════════════════════════════════════════════════════════════════════════
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double iconXxl = 48;

  // ══════════════════════════════════════════════════════════════════════════
  // ANIMATION DURATIONS
  // ══════════════════════════════════════════════════════════════════════════
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 200);
  static const Duration durationSlow = Duration(milliseconds: 300);
  static const Duration durationExpand = Duration(milliseconds: 250);

  // ══════════════════════════════════════════════════════════════════════════
  // EASING CURVES
  // ══════════════════════════════════════════════════════════════════════════
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveExpand = Curves.easeInOutCubic;
  static const Curve curveBounce = Curves.easeOutBack;

  // ══════════════════════════════════════════════════════════════════════════
  // SHADOW SCALE
  // ══════════════════════════════════════════════════════════════════════════

  /// Subtle shadow — cards, panels
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Medium shadow — dropdowns, popovers
  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Large shadow — modals, dialogs
  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Glow shadow — accent-colored glow effect
  static List<BoxShadow> shadowGlow(Color color, {double intensity = 0.3}) => [
        BoxShadow(
          color: color.withValues(alpha: intensity),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  /// Premium card shadow — blue glow + depth
  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: FuturisticColors.premiumBlue.withValues(alpha: 0.08),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Sidebar shadow
  static List<BoxShadow> get shadowSidebar => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(4, 0),
        ),
      ];

  // ══════════════════════════════════════════════════════════════════════════
  // FOCUS RING
  // ══════════════════════════════════════════════════════════════════════════

  /// Standard focus ring decoration
  static BoxDecoration focusRing({Color? color}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(
          color: color ?? FuturisticColors.premiumBlue,
          width: 2,
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // COMMON PADDINGS
  // ══════════════════════════════════════════════════════════════════════════

  static const EdgeInsets paddingPage = EdgeInsets.all(space6);
  static const EdgeInsets paddingCard = EdgeInsets.all(space4);
  static const EdgeInsets paddingCardCompact = EdgeInsets.all(space3);
  static const EdgeInsets paddingSection = EdgeInsets.symmetric(
    horizontal: space6,
    vertical: space4,
  );
  static const EdgeInsets paddingInput = EdgeInsets.symmetric(
    horizontal: space4,
    vertical: space3,
  );
}
