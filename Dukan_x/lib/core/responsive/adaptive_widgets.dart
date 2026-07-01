// Adaptive primitives — reusable widgets that make responsive safety
// structural for the consolidated Responsive_System.
//
// These primitives convert whole classes of Flutter render-time failures
// (RenderFlex overflow, clipped content, unbounded-constraint exceptions, and
// text overflow) into safe, scrollable, bounded layouts. Screens built on top
// of them are overflow-safe by construction across Form_Factors, orientations,
// keyboard insets, and accessibility font scaling.
//
// This file intentionally imports ONLY the new `responsive_context.dart`
// extension (and the breakpoint source of truth) and NOT the legacy
// `responsive_layout.dart`, which also declares a `ResponsiveContext`
// extension. Importing both would create ambiguous-extension errors.
//
// Layout of this file:
//   1. Core adaptive primitives:
//        AdaptiveScaffold, AdaptiveScroll, AdaptiveText, BoundedBox
//   2. Component adaptive primitives:
//        AdaptiveDialog, AdaptiveSheet, AdaptiveForm, AdaptiveTable,
//        AdaptiveGrid, AdaptiveChartBox
//
// Part of: cross-platform-responsive-ui

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'responsive_context.dart';
import 'responsive_value.dart';

// =============================================================================
// SECTION 1 — Core adaptive primitives
// =============================================================================

/// A [Scaffold] wrapper that adapts its chrome to the current Form_Factor.
///
/// Responsibilities (Req 6.4, 9.1):
///   * Attaches the navigation [drawer] only on Mobile and Tablet Form_Factors,
///     never on Desktop (where the persistent sidebar shell is used instead).
///   * Wraps the [body] in a [SafeArea] so interactive content is never clipped
///     by notches, status bars, or home indicators.
///
/// The [drawer] is intentionally typed as a plain `Widget?` so callers can pass
/// any drawer implementation. The real `MobileDrawer` is wired in later; until
/// then this primitive simply hosts whatever drawer it is given.
class AdaptiveScaffold extends StatelessWidget {
  /// Optional app bar shown at the top of the scaffold.
  final PreferredSizeWidget? appBar;

  /// The primary content of the scaffold. Wrapped in a [SafeArea] when
  /// [useSafeArea] is true.
  final Widget body;

  /// Navigation drawer, attached only on Mobile and Tablet Form_Factors.
  ///
  /// On Desktop the drawer is omitted so the persistent sidebar shell remains
  /// the single navigation surface.
  final Widget? drawer;

  /// Optional end (right-side) drawer, also restricted to Mobile and Tablet.
  final Widget? endDrawer;

  /// Optional bottom navigation bar (e.g. the mobile bottom nav).
  final Widget? bottomNavigationBar;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Placement of [floatingActionButton].
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Scaffold background color.
  final Color? backgroundColor;

  /// Whether to wrap [body] in a [SafeArea]. Defaults to true so content stays
  /// within the Safe_Area by default (Req 6.4).
  final bool useSafeArea;

  /// When true, the body extends behind the app bar (transparent app bars).
  final bool extendBodyBehindAppBar;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.useSafeArea = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    // Drawers belong to Mobile/Tablet navigation only; Desktop uses its own
    // persistent shell, so we drop the drawer there (Req 9.1).
    final bool showDrawers = !context.isDesktop;

    final Widget content = useSafeArea ? SafeArea(child: body) : body;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      drawer: showDrawers ? drawer : null,
      endDrawer: showDrawers ? endDrawer : null,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: content,
    );
  }
}

/// The default scrollable container for screen bodies.
///
/// Wraps [child] in a vertically scrolling view whose content is constrained to
/// at least the viewport height. This guarantees two things at once (Req 4.4,
/// 6.3, 6.7, 7.2):
///   * When content is taller than the viewport, it scrolls instead of
///     producing an Overflow_Error.
///   * When content is shorter than the viewport, the `minHeight` constraint
///     lets layouts that expect to fill the screen (e.g. a [Column] with a
///     trailing [Spacer], or `Align`/`Center`) still occupy the full height.
///
/// Set [useIntrinsicHeight] to true when [child] is a [Column] that uses
/// [Expanded]/[Spacer]; [IntrinsicHeight] gives those flexible children a
/// finite height to divide even inside the unbounded scroll axis.
class AdaptiveScroll extends StatelessWidget {
  /// The scrollable content.
  final Widget child;

  /// Padding applied inside the scroll view, around [child].
  final EdgeInsetsGeometry? padding;

  /// Scroll physics. Defaults to [AlwaysScrollableScrollPhysics] so content is
  /// always reachable via scrolling, even when it nearly fits.
  final ScrollPhysics? physics;

  /// Optional external scroll controller.
  final ScrollController? controller;

  /// Wraps [child] in an [IntrinsicHeight] so flexible children (Expanded,
  /// Spacer) can size within the min-height constraint. Off by default because
  /// [IntrinsicHeight] is comparatively expensive.
  final bool useIntrinsicHeight;

  const AdaptiveScroll({
    super.key,
    required this.child,
    this.padding,
    this.physics,
    this.controller,
    this.useIntrinsicHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The viewport height available to the scroll view. When the enclosing
        // constraints are unbounded (infinite), there is no meaningful minimum
        // to enforce, so fall back to 0.
        final double viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0;

        // Subtract vertical padding so `minHeight` matches the space actually
        // available to the child; otherwise content + padding would always
        // slightly exceed the viewport.
        final double verticalPadding =
            padding?.resolve(Directionality.of(context)).vertical ?? 0;
        final double minHeight = (viewportHeight - verticalPadding).clamp(
          0,
          double.infinity,
        );

        Widget content = ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: child,
        );

        if (useIntrinsicHeight) {
          content = IntrinsicHeight(child: content);
        }

        return SingleChildScrollView(
          controller: controller,
          physics: physics ?? const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: content,
        );
      },
    );
  }
}

/// A [Text] that never produces an Overflow_Error by default.
///
/// Defaults [softWrap] to true and [overflow] to [TextOverflow.ellipsis], so
/// text wraps within its available width and, when constrained to a fixed
/// number of lines, truncates with a trailing ellipsis rather than overflowing
/// (Req 7.7). All common [Text] parameters are exposed as pass-throughs so this
/// can be a drop-in replacement.
class AdaptiveText extends StatelessWidget {
  /// The string to display.
  final String data;

  /// Text style.
  final TextStyle? style;

  /// Horizontal alignment of the text.
  final TextAlign? textAlign;

  /// Maximum number of lines before truncation. Null allows unlimited wrapping.
  final int? maxLines;

  /// How visual overflow is handled. Defaults to [TextOverflow.ellipsis].
  final TextOverflow overflow;

  /// Whether the text should wrap at soft line breaks. Defaults to true.
  final bool softWrap;

  /// Optional per-widget text scaler override.
  final TextScaler? textScaler;

  /// Optional semantics label for accessibility.
  final String? semanticsLabel;

  const AdaptiveText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
    this.textScaler,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textScaler: textScaler,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// Supplies bounded constraints, derived from the enclosing parent, to a child
/// that would otherwise be laid out with unbounded width or height.
///
/// Some widgets (e.g. an unconstrained [ListView] or a chart inside a [Column])
/// throw "unbounded constraints" exceptions when the parent does not provide a
/// finite size on an axis. [BoundedBox] uses a [LayoutBuilder] to read the
/// parent's available space and applies it as a maximum bound. When an axis is
/// unbounded (infinite), it falls back to the corresponding screen dimension so
/// the child always receives a finite bound (Req 7.3, 7.4, 7.5).
///
/// Optional [maxWidth]/[maxHeight] overrides cap the bound further (the smaller
/// of the override and the parent-derived value wins).
class BoundedBox extends StatelessWidget {
  /// The child to constrain.
  final Widget child;

  /// Optional explicit maximum width. When provided, the effective bound is the
  /// smaller of this value and the parent-derived width.
  final double? maxWidth;

  /// Optional explicit maximum height. When provided, the effective bound is the
  /// smaller of this value and the parent-derived height.
  final double? maxHeight;

  /// Optional alignment of [child] within the bounded area.
  final AlignmentGeometry? alignment;

  const BoundedBox({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxHeight,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size screen = MediaQuery.sizeOf(context);

        // Start from the parent's available space; fall back to the screen
        // dimension whenever the parent leaves an axis unbounded.
        double effectiveMaxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screen.width;
        double effectiveMaxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screen.height;

        // Apply caller-provided caps, keeping the tighter (smaller) bound.
        if (maxWidth != null) {
          effectiveMaxWidth = effectiveMaxWidth < maxWidth!
              ? effectiveMaxWidth
              : maxWidth!;
        }
        if (maxHeight != null) {
          effectiveMaxHeight = effectiveMaxHeight < maxHeight!
              ? effectiveMaxHeight
              : maxHeight!;
        }

        Widget bounded = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: effectiveMaxWidth,
            maxHeight: effectiveMaxHeight,
          ),
          child: child,
        );

        if (alignment != null) {
          bounded = Align(alignment: alignment!, child: bounded);
        }

        return bounded;
      },
    );
  }
}

// =============================================================================
// SECTION 2 — Component adaptive primitives
// =============================================================================

/// Returns the Safe_Area-bounded available [Size] for the current screen, i.e.
/// the screen size minus the Safe_Area insets (notches, status bars, home
/// indicators). Both dimensions are clamped to be non-negative.
///
/// Component primitives size themselves relative to this so that their width
/// and height never exceed the space actually usable by content (Req 8.1, 8.3,
/// 8.9, Property 10).
Size _availableSafeArea(BuildContext context) {
  final Size screen = MediaQuery.sizeOf(context);
  final EdgeInsets safe = context.safeAreaPadding;
  final double width = math.max(0.0, screen.width - safe.horizontal);
  final double height = math.max(0.0, screen.height - safe.vertical);
  return Size(width, height);
}

/// A dialog whose size is bounded by the available Safe_Area and whose content
/// scrolls when it overflows (Req 8.1, 8.2, Property 10).
///
/// The dialog width is a Form_Factor-dependent fraction of the available
/// Safe_Area width (wider on Mobile, narrower on larger screens) and never
/// exceeds it. The height is capped at the available Safe_Area height. The
/// [content] is placed in a scroll view, so a tall body scrolls instead of
/// overflowing while the [title] and [actions] stay pinned.
class AdaptiveDialog extends StatelessWidget {
  /// Optional title shown above the content.
  final Widget? title;

  /// The main dialog body. Scrolls when taller than the available height.
  final Widget content;

  /// Optional action buttons shown below the content. Laid out with an
  /// [OverflowBar] so they wrap instead of overflowing on narrow widths.
  final List<Widget>? actions;

  /// Padding around the [content]. Defaults to 24 logical pixels.
  final EdgeInsetsGeometry contentPadding;

  /// Optional explicit cap on the dialog width. The effective width is the
  /// smaller of this value and the Form_Factor-derived width.
  final double? maxWidth;

  const AdaptiveDialog({
    super.key,
    required this.content,
    this.title,
    this.actions,
    this.contentPadding = const EdgeInsets.all(24),
    this.maxWidth,
  });

  /// Shows an [AdaptiveDialog] via [showDialog].
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget content,
    Widget? title,
    List<Widget>? actions,
    bool barrierDismissible = true,
    double? maxWidth,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AdaptiveDialog(
        title: title,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size available = _availableSafeArea(context);

    // Pick a width fraction by Form_Factor: a Mobile dialog fills most of the
    // width, while Tablet/Desktop dialogs stay comfortably narrower.
    final double fraction = responsiveValue<double>(
      context,
      mobile: 0.92,
      tablet: 0.7,
      desktop: 0.5,
    );

    double width = available.width * fraction;
    if (maxWidth != null) {
      width = math.min(width, maxWidth!);
    }
    // Never exceed the available Safe_Area dimensions (Property 10).
    width = math.min(width, available.width);
    final double maxHeight = available.height;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.titleLarge,
                  child: title!,
                ),
              ),
            // The body is the only flexible child, so it absorbs the height
            // pressure and scrolls when the content is taller than the dialog.
            Flexible(
              child: SingleChildScrollView(
                padding: contentPadding,
                child: content,
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A bottom-sheet body capped at 90% of the available Safe_Area height whose
/// content scrolls when it overflows (Req 8.3, 8.4, Property 10).
///
/// Use [AdaptiveSheet.show] to present it modally; the modal route is
/// scroll-controlled so the sheet can grow up to the 90% cap and then scroll.
class AdaptiveSheet extends StatelessWidget {
  /// The sheet content. Scrolls when taller than the 90% height cap.
  final Widget child;

  /// Padding around [child]. Defaults to 16 logical pixels.
  final EdgeInsetsGeometry padding;

  const AdaptiveSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  /// Shows an [AdaptiveSheet] via [showModalBottomSheet].
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool useSafeArea = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      useSafeArea: useSafeArea,
      builder: (_) => AdaptiveSheet(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size available = _availableSafeArea(context);
    // Cap the sheet at 90% of the available Safe_Area height (Req 8.3).
    final double maxHeight = available.height * 0.9;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(padding: padding, child: child),
      ),
    );
  }
}

/// A [Form] laid out within the available Safe_Area width and made scrollable so
/// that every field is reachable (Req 8.5, 8.6).
///
/// Fields are stacked in a [Column] constrained to the Safe_Area width (so they
/// never overflow horizontally) and wrapped in an [AdaptiveScroll] (so they
/// never overflow vertically). An optional [maxWidth] keeps forms from
/// stretching uncomfortably wide on large screens.
class AdaptiveForm extends StatelessWidget {
  /// The form fields, stacked vertically.
  final List<Widget> children;

  /// Optional key used to validate/save the underlying [Form].
  final GlobalKey<FormState>? formKey;

  /// Padding applied inside the scroll view, around the fields.
  final EdgeInsetsGeometry padding;

  /// Horizontal alignment of the fields within the constrained column.
  final CrossAxisAlignment crossAxisAlignment;

  /// Optional auto-validation mode forwarded to the [Form].
  final AutovalidateMode? autovalidateMode;

  /// Optional cap on the field column width. The effective width is the smaller
  /// of this value and the available Safe_Area width.
  final double? maxWidth;

  const AdaptiveForm({
    super.key,
    required this.children,
    this.formKey,
    this.padding = const EdgeInsets.all(16),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.autovalidateMode,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final double available = _availableSafeArea(context).width;
    final double width = maxWidth != null
        ? math.min(maxWidth!, available)
        : available;

    return Form(
      key: formKey,
      autovalidateMode: autovalidateMode,
      child: AdaptiveScroll(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// A table that fits the available width either by horizontal scrolling or by
/// reflowing into cards on narrow (Mobile) screens (Req 8.7, Property 10).
///
/// On Mobile, when a [cardBuilder] is supplied, the table reflows into that
/// card layout so the content fits the width without horizontal scrolling.
/// Otherwise the [DataTable] is wrapped in a horizontal scroll view, so its
/// rendered viewport width equals the available width and wide tables scroll
/// instead of overflowing.
class AdaptiveTable extends StatelessWidget {
  /// Table columns for the [DataTable] form.
  final List<DataColumn> columns;

  /// Table rows for the [DataTable] form.
  final List<DataRow> rows;

  /// Optional Mobile reflow layout (typically a column of cards). When provided,
  /// it is used instead of the table on the Mobile Form_Factor.
  final WidgetBuilder? cardBuilder;

  const AdaptiveTable({
    super.key,
    required this.columns,
    required this.rows,
    this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Narrow screens reflow to cards when a card layout is available.
    if (context.isMobile && cardBuilder != null) {
      return cardBuilder!(context);
    }

    // Otherwise scroll the table horizontally so its width never exceeds the
    // available width (the scroll viewport is bounded; the table scrolls).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(columns: columns, rows: rows),
    );
  }
}

/// A grid whose column count is selected per Form_Factor via [responsiveValue]
/// (Req 8.8, Property 10).
///
/// The column count is `responsiveValue(mobile, tablet, desktop)` for the
/// current Form_Factor, defaulting to 1/2/4 columns respectively. Children are
/// arranged with [GridView.count] so the grid renders without overflow at any
/// width.
class AdaptiveGrid extends StatelessWidget {
  /// The grid items.
  final List<Widget> children;

  /// Column count on Mobile. Defaults to 1.
  final int mobileColumns;

  /// Column count on Tablet. Defaults to 2.
  final int tabletColumns;

  /// Column count on Desktop. Defaults to 4.
  final int desktopColumns;

  /// Horizontal gap between columns.
  final double spacing;

  /// Vertical gap between rows.
  final double runSpacing;

  /// Width-to-height ratio of each grid cell.
  final double childAspectRatio;

  /// Padding around the grid.
  final EdgeInsetsGeometry? padding;

  /// Whether the grid sizes itself to its content (use when nested inside
  /// another scroll view).
  final bool shrinkWrap;

  /// Scroll physics for the grid.
  final ScrollPhysics? physics;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
    this.spacing = 12,
    this.runSpacing = 12,
    this.childAspectRatio = 1,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final int columns = responsiveValue<int>(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      childAspectRatio: childAspectRatio,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: children,
    );
  }
}

/// Constrains a chart (or any size-hungry visualization) so its width and
/// height never exceed the available Safe_Area dimensions (Req 8.9, Property
/// 10).
///
/// Provide an [aspectRatio] to keep the chart proportional within the bound, or
/// explicit [maxWidth]/[maxHeight] caps (each capped further by the available
/// Safe_Area dimension).
class AdaptiveChartBox extends StatelessWidget {
  /// The chart widget to constrain.
  final Widget child;

  /// Optional width-to-height ratio enforced via [AspectRatio].
  final double? aspectRatio;

  /// Optional explicit max width. The effective bound is the smaller of this
  /// and the available Safe_Area width.
  final double? maxWidth;

  /// Optional explicit max height. The effective bound is the smaller of this
  /// and the available Safe_Area height.
  final double? maxHeight;

  const AdaptiveChartBox({
    super.key,
    required this.child,
    this.aspectRatio,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final Size available = _availableSafeArea(context);

    final double boundedWidth = maxWidth != null
        ? math.min(maxWidth!, available.width)
        : available.width;
    final double boundedHeight = maxHeight != null
        ? math.min(maxHeight!, available.height)
        : available.height;

    Widget chart = child;
    if (aspectRatio != null) {
      chart = AspectRatio(aspectRatio: aspectRatio!, child: chart);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: boundedWidth,
        maxHeight: boundedHeight,
      ),
      child: chart,
    );
  }
}
