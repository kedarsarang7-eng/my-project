// Universal Responsive Layout System
// Three-tier breakpoint system: Mobile, Tablet, Desktop
// Prevents overflow errors and adapts to all screen sizes
//
// Created: 2024-12-25
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

/// Breakpoint enum for the three-tier system
enum ScreenSize { mobile, tablet, desktop }

/// Screen breakpoints
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1100;

  // Max content width for desktop (prevents weird stretching)
  static const double maxContentWidth = 1200;

  // Sidebar widths
  static const double sidebarCollapsed = 72;
  static const double sidebarExpanded = 280;

  // Grid items per row
  static const int mobileGridItems = 1;
  static const int tabletGridItems = 2;
  static const int desktopGridItems = 3;
}

/// Get current screen size based on width
ScreenSize getScreenSize(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < Breakpoints.mobile) return ScreenSize.mobile;
  if (width < Breakpoints.tablet) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

/// Check if current platform uses hover (Web/Desktop)
bool usesHover() {
  return kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Extension on BuildContext for easy responsive checks
extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => getScreenSize(this);
  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
  bool get isNotMobile => !isMobile;
  bool get usesHoverEffects => usesHover();

  /// True for small phones (< 400px width)
  bool get isPhone => screenWidth < 400;

  /// True for large tablets in landscape (≥ 900px but < 1100px)
  bool get isLargeTablet => screenWidth >= 900 && screenWidth < Breakpoints.tablet;

  /// True for mobile or tablet (anything that is NOT desktop)
  bool get isMobileOrTablet => !isDesktop;

  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Current orientation
  Orientation get orientation => MediaQuery.of(this).orientation;
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isLandscape => orientation == Orientation.landscape;

  /// Whether the soft keyboard is currently visible
  bool get isKeyboardVisible => MediaQuery.of(this).viewInsets.bottom > 0;

  /// Bottom view inset (keyboard height when visible)
  double get keyboardHeight => MediaQuery.of(this).viewInsets.bottom;

  /// Device pixel ratio
  double get devicePixelRatio => MediaQuery.of(this).devicePixelRatio;

  /// Text scale factor from system accessibility settings
  double get textScale => MediaQuery.textScalerOf(this).scale(1.0);

  /// Safe area padding (for notches, status bars, home indicators)
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;

  // Responsive padding
  EdgeInsets get responsivePadding {
    switch (screenSize) {
      case ScreenSize.mobile:
        return const EdgeInsets.all(12);
      case ScreenSize.tablet:
        return const EdgeInsets.all(20);
      case ScreenSize.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Responsive horizontal padding (no vertical)
  EdgeInsets get responsiveHorizontalPadding {
    switch (screenSize) {
      case ScreenSize.mobile:
        return const EdgeInsets.symmetric(horizontal: 12);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(horizontal: 20);
      case ScreenSize.desktop:
        return const EdgeInsets.symmetric(horizontal: 32);
    }
  }

  // Responsive grid cross axis count
  int get gridCrossAxisCount {
    switch (screenSize) {
      case ScreenSize.mobile:
        return Breakpoints.mobileGridItems;
      case ScreenSize.tablet:
        return Breakpoints.tabletGridItems;
      case ScreenSize.desktop:
        return Breakpoints.desktopGridItems;
    }
  }

  /// Responsive font size helper
  /// Returns scaled font size based on screen size
  double responsiveFontSize(double base, {double? mobile, double? tablet, double? desktop}) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile ?? (base * 0.85);
      case ScreenSize.tablet:
        return tablet ?? (base * 0.92);
      case ScreenSize.desktop:
        return desktop ?? base;
    }
  }

  /// Optimal dialog width based on screen size
  /// Mobile: full width minus padding, Tablet: 560px, Desktop: 680px
  double get responsiveDialogWidth {
    switch (screenSize) {
      case ScreenSize.mobile:
        return screenWidth - 32;
      case ScreenSize.tablet:
        return 560;
      case ScreenSize.desktop:
        return 680;
    }
  }

  /// Optimal bottom sheet max height (% of screen)
  double get responsiveBottomSheetMaxHeight {
    switch (screenSize) {
      case ScreenSize.mobile:
        return screenHeight * 0.9;
      case ScreenSize.tablet:
        return screenHeight * 0.75;
      case ScreenSize.desktop:
        return screenHeight * 0.6;
    }
  }
}

/// Main Responsive Layout Wrapper
/// Use this as the root widget for any screen that needs responsiveness
class ResponsiveLayout extends StatelessWidget {
  /// Builder for mobile layout (< 600px)
  final Widget Function(BuildContext context, BoxConstraints constraints)?
  mobileBuilder;

  /// Builder for tablet layout (600-1100px)
  final Widget Function(BuildContext context, BoxConstraints constraints)?
  tabletBuilder;

  /// Builder for desktop layout (> 1100px)
  final Widget Function(BuildContext context, BoxConstraints constraints)?
  desktopBuilder;

  /// Fallback builder if specific builders are not provided
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    ScreenSize screenSize,
  )?
  builder;

  /// Simple child (if you don't need different layouts per screen size)
  final Widget? child;

  /// Whether to wrap content in a scroll view (prevents overflow)
  final bool enableScrolling;

  /// Scroll physics
  final ScrollPhysics? scrollPhysics;

  /// Whether to center content on large screens
  final bool centerContent;

  /// Maximum content width on desktop (prevents weird stretching)
  final double maxWidth;

  /// Background color
  final Color? backgroundColor;

  const ResponsiveLayout({
    super.key,
    this.mobileBuilder,
    this.tabletBuilder,
    this.desktopBuilder,
    this.builder,
    this.child,
    this.enableScrolling = true,
    this.scrollPhysics,
    this.centerContent = true,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.backgroundColor,
  }) : assert(
         mobileBuilder != null ||
             tabletBuilder != null ||
             desktopBuilder != null ||
             builder != null ||
             child != null,
         'At least one builder or child must be provided',
       );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = getScreenSize(context);

        // Build content based on screen size
        Widget content = _buildContent(context, constraints, screenSize);

        // Wrap in scroll view if enabled (prevents overflow on resize)
        if (enableScrolling) {
          content = SingleChildScrollView(
            physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        }

        // Center content on large screens with max width
        if (centerContent && screenSize == ScreenSize.desktop) {
          content = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: content,
            ),
          );
        }

        // Apply background color if provided
        if (backgroundColor != null) {
          content = ColoredBox(color: backgroundColor!, child: content);
        }

        return content;
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    BoxConstraints constraints,
    ScreenSize screenSize,
  ) {
    // Try specific builders first
    switch (screenSize) {
      case ScreenSize.mobile:
        if (mobileBuilder != null) {
          return mobileBuilder!(context, constraints);
        }
        break;
      case ScreenSize.tablet:
        if (tabletBuilder != null) {
          return tabletBuilder!(context, constraints);
        }
        break;
      case ScreenSize.desktop:
        if (desktopBuilder != null) {
          return desktopBuilder!(context, constraints);
        }
        break;
    }

    // Fall back to generic builder
    if (builder != null) {
      return builder!(context, constraints, screenSize);
    }

    // Fall back to child
    return child ?? const SizedBox.shrink();
  }
}

/// Responsive Scaffold with optional sidebar
/// Automatically shows drawer on mobile, sidebar on desktop
class ResponsiveScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? actions;
  final Widget? drawer;
  final Widget? sidebar;
  final bool showSidebar;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final bool extendBodyBehindAppBar;

  const ResponsiveScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.actions,
    this.drawer,
    this.sidebar,
    this.showSidebar = true,
    this.backgroundColor,
    this.appBar,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = context.screenSize;
    final showSidebarNow = showSidebar && sidebar != null && context.isDesktop;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar:
          appBar ??
          (title != null || titleWidget != null
              ? AppBar(
                  title: titleWidget ?? Text(title!),
                  actions: actions,
                  // Hide drawer icon on desktop when sidebar is shown
                  automaticallyImplyLeading: !showSidebarNow,
                )
              : null),
      // Show drawer on mobile/tablet only
      drawer: screenSize != ScreenSize.desktop ? drawer : null,
      body: showSidebarNow
          ? Row(
              children: [
                // Sidebar on desktop
                sidebar!,
                // Divider
                const VerticalDivider(width: 1, thickness: 1),
                // Main content
                Expanded(child: body),
              ],
            )
          : body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

/// Responsive Grid that adapts item count based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsets? padding;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double? childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.childAspectRatio,
    this.shrinkWrap = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = context.screenSize;

    int crossAxisCount;
    switch (screenSize) {
      case ScreenSize.mobile:
        crossAxisCount = mobileColumns ?? Breakpoints.mobileGridItems;
        break;
      case ScreenSize.tablet:
        crossAxisCount = tabletColumns ?? Breakpoints.tabletGridItems;
        break;
      case ScreenSize.desktop:
        crossAxisCount = desktopColumns ?? Breakpoints.desktopGridItems;
        break;
    }

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding ?? context.responsivePadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: childAspectRatio ?? 1.0,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Responsive Row/Column that switches based on screen size
/// Shows as Row on desktop, Column on mobile
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;
  final bool reverseOnMobile;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing = 16,
    this.reverseOnMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final items = reverseOnMobile && isMobile
        ? children.reversed.toList()
        : children;

    // Add spacing between children
    final spacedChildren = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      spacedChildren.add(items[i]);
      if (i < items.length - 1) {
        spacedChildren.add(
          SizedBox(
            width: isMobile ? 0 : spacing,
            height: isMobile ? spacing : 0,
          ),
        );
      }
    }

    if (isMobile) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: spacedChildren,
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spacedChildren,
    );
  }
}

/// Adaptive Button with hover effects on desktop/web
class AdaptiveButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? hoverColor;
  final double? elevation;
  final double? hoverElevation;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.backgroundColor,
    this.foregroundColor,
    this.hoverColor,
    this.elevation,
    this.hoverElevation,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
  });

  @override
  State<AdaptiveButton> createState() => _AdaptiveButtonState();
}

class _AdaptiveButtonState extends State<AdaptiveButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasHover = context.usesHoverEffects;

    Widget button = ElevatedButton(
      onPressed: widget.onPressed,
      style:
          widget.style ??
          ElevatedButton.styleFrom(
            backgroundColor: _isHovered && hasHover
                ? (widget.hoverColor ??
                      widget.backgroundColor?.withOpacity(0.9))
                : widget.backgroundColor,
            foregroundColor: widget.foregroundColor,
            elevation: _isHovered && hasHover
                ? (widget.hoverElevation ?? (widget.elevation ?? 2) + 4)
                : widget.elevation,
            shape: RoundedRectangleBorder(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            ),
            padding: widget.padding,
          ),
      child: widget.child,
    );

    // Only add hover listener on platforms that support it
    if (hasHover) {
      button = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: button,
        ),
      );
    }

    // Apply size constraints
    if (widget.width != null || widget.height != null) {
      button = SizedBox(
        width: widget.width,
        height: widget.height,
        child: button,
      );
    }

    return button;
  }
}

/// Responsive Container with max width constraint
/// Prevents content from stretching on large screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final BoxDecoration? decoration;
  final AlignmentGeometry alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          width: double.infinity,
          padding: padding,
          margin: margin,
          decoration: decoration,
          color: decoration == null ? color : null,
          child: child,
        ),
      ),
    );
  }
}

/// Responsive value selector
/// Returns different values based on screen size
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  switch (context.screenSize) {
    case ScreenSize.mobile:
      return mobile;
    case ScreenSize.tablet:
      return tablet ?? mobile;
    case ScreenSize.desktop:
      return desktop ?? tablet ?? mobile;
  }
}

/// Responsive spacing helper
class ResponsiveSpacing extends StatelessWidget {
  final double mobile;
  final double? tablet;
  final double? desktop;
  final bool horizontal;

  const ResponsiveSpacing({
    super.key,
    this.mobile = 16,
    this.tablet,
    this.desktop,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );

    return SizedBox(
      width: horizontal ? size : 0,
      height: horizontal ? 0 : size,
    );
  }
}

/// Safe Area with responsive padding
class ResponsiveSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final EdgeInsets? additionalPadding;

  const ResponsiveSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.additionalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Padding(
        padding: additionalPadding ?? context.responsivePadding,
        child: child,
      ),
    );
  }
}
