/// MobileShop Responsive Layout — Viewport-Adaptive Helpers (Dart)
///
/// Provides [ResponsiveLayout] widget and [ResponsiveValue] helper for
/// adapting mobile shop screens across phone, tablet, and desktop viewports
/// without clipped actions, inaccessible fields, horizontal overflow, or
/// pointer-only dependency.
///
/// Requirements: 11.1, 11.2
library;

import 'package:flutter/material.dart';

import 'mobile_shop_theme.dart';

// ─── Responsive Value ────────────────────────────────────────────────────────

/// Selects a value based on the current viewport breakpoint.
///
/// Usage:
/// ```dart
/// final columns = ResponsiveValue(context, phone: 1, tablet: 2, desktop: 3);
/// ```
class ResponsiveValue<T> {
  final T phone;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({required this.phone, this.tablet, this.desktop});

  /// Resolves the value for the given [context] width.
  T resolve(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bp = MobileShopBreakpoint.fromWidth(width);
    return switch (bp) {
      MobileShopBreakpoint.desktop => desktop ?? tablet ?? phone,
      MobileShopBreakpoint.tablet => tablet ?? phone,
      MobileShopBreakpoint.phone => phone,
    };
  }
}

// ─── Responsive Layout Widget ────────────────────────────────────────────────

/// A responsive layout builder that provides the current breakpoint and
/// constrained content area for mobile shop screens.
///
/// Adapts:
/// - Padding (phone: 16dp, tablet: 24dp, desktop: 32dp)
/// - Maximum content width (phone: unconstrained, tablet: 720dp, desktop: 960dp)
/// - Grid columns via [breakpoint] callback
///
/// Prevents horizontal overflow by constraining content width and
/// avoids pointer-only dependency by maintaining accessible scrolling.
class ResponsiveLayout extends StatelessWidget {
  /// Builder that receives the resolved breakpoint.
  final Widget Function(BuildContext context, MobileShopBreakpoint breakpoint)
  builder;

  /// Optional maximum content width override.
  final double? maxContentWidth;

  /// Whether to center the content on wider viewports.
  final bool centerContent;

  const ResponsiveLayout({
    super.key,
    required this.builder,
    this.maxContentWidth,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bp = MobileShopBreakpoint.fromWidth(width);

    final padding = switch (bp) {
      MobileShopBreakpoint.phone => MobileShopSpacing.lg,
      MobileShopBreakpoint.tablet => MobileShopSpacing.xl,
      MobileShopBreakpoint.desktop => MobileShopSpacing.xxl,
    };

    final maxWidth =
        maxContentWidth ??
        switch (bp) {
          MobileShopBreakpoint.phone => double.infinity,
          MobileShopBreakpoint.tablet => 720.0,
          MobileShopBreakpoint.desktop => 960.0,
        };

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: builder(context, bp),
    );

    if (maxWidth.isFinite && centerContent) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ─── Responsive Grid ─────────────────────────────────────────────────────────

/// A responsive grid that lays out children in adaptive columns.
///
/// - Phone: [phoneCols] columns (default 1)
/// - Tablet: [tabletCols] columns (default 2)
/// - Desktop: [desktopCols] columns (default 3)
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int phoneCols;
  final int tabletCols;
  final int desktopCols;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.phoneCols = 1,
    this.tabletCols = 2,
    this.desktopCols = 3,
    this.spacing = MobileShopSpacing.md,
    this.runSpacing = MobileShopSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bp = MobileShopBreakpoint.fromWidth(width);

    final cols = switch (bp) {
      MobileShopBreakpoint.phone => phoneCols,
      MobileShopBreakpoint.tablet => tabletCols,
      MobileShopBreakpoint.desktop => desktopCols,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final totalSpacing = spacing * (cols - 1);
        final itemWidth = (availableWidth - totalSpacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(width: itemWidth, child: child);
          }).toList(),
        );
      },
    );
  }
}

// ─── Responsive Scaffold ─────────────────────────────────────────────────────

/// A scaffold wrapper that adapts its body layout for the current viewport.
///
/// On tablet/desktop, the body gets constrained width and centered alignment.
/// On phone, the body fills the available width.
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: ResponsiveLayout(builder: (context, bp) => body)),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
