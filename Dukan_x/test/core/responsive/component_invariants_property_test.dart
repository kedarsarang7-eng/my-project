// ============================================================================
// Task 3.4 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 10: Per-component constraint
// invariants
// **Validates: Requirements 8.1, 8.3, 8.7, 8.8, 8.9**
// ============================================================================
// Property 10 (design.md): For any current Form_Factor and content:
//   * an AdaptiveDialog's width does not exceed the available Safe_Area width
//     and its height does not exceed the available Safe_Area height;
//   * an AdaptiveSheet's height does not exceed 90% of the available Safe_Area
//     height;
//   * an AdaptiveTable's rendered width does not exceed the available width
//     (achieved by horizontal scrolling or by reflow);
//   * an AdaptiveGrid's column count equals
//     responsiveValue(mobile, tablet, desktop) for the current Form_Factor;
//   * an AdaptiveChartBox's width and height do not exceed the available
//     Safe_Area dimensions.
//
// Units under test (package:dukanx/core/responsive/responsive.dart barrel):
//   AdaptiveDialog, AdaptiveSheet, AdaptiveTable, AdaptiveGrid, AdaptiveChartBox
//   plus the pure resolveResponsiveValue selector that drives the grid column
//   count. The available Safe_Area is the screen size minus the Safe_Area
//   insets, matching the private `_availableSafeArea` helper in
//   `adaptive_widgets.dart` (`screen - safeAreaPadding`, clamped >= 0).
//
// Testing approach:
//   * The PURE grid-column-count invariant is exercised with dartproptest's
//     `forAll` at kNumRuns = 200, honoring the repo PBT convention: for any
//     generated width + (mobile, tablet, desktop) column spec, the column count
//     the grid selects (`resolveResponsiveValue(classify(width), ...)`) equals
//     the value defined for the current Form_Factor and is a valid (>= 1)
//     count.
//   * The DIMENSION invariants (dialog/sheet/table/chart/grid render) require
//     pumping real widgets, which is async, so they are verified by looping a
//     representative grid of render conditions (widths spanning Mobile/Tablet/
//     Desktop x heights x with/without Safe_Area insets) inside `testWidgets`.
//     For each condition the expected bound is computed from the SAME inputs
//     (`available = size - insets`) the implementation uses, the primitive is
//     pumped, and its resolved geometry is asserted to stay within the bound
//     (with a 1px epsilon for rounding). Each pump also asserts
//     `tester.takeException()` is null, i.e. the component renders without an
//     Overflow_Error.
//
//   To make the component constraints (rather than the test surface) the
//   binding limit, the test surface is set large (4000x4000) and the primitive
//   is given LOOSE constraints via an `Align`, so each primitive's internal
//   ConstrainedBox cap is what decides the size.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   kNumRuns (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/component_invariants_property_test.dart
// ============================================================================

import 'dart:math' as math;

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // Rounding tolerance (logical pixels) for geometry comparisons.
  const double kEpsilon = 1.0;

  // A large test surface so that the component primitives' own ConstrainedBox
  // caps — not the physical window — are the binding limit on their size.
  const Size kSurface = Size(4000, 4000);

  // ---- Representative render conditions ------------------------------------
  // Widths chosen to land in each Form_Factor band (Mobile < 600, 600 <= Tablet
  // < 1100, Desktop >= 1100). Heights and Safe_Area inset variants exercise the
  // `size - insets` Safe_Area math both with and without insets.
  const List<double> kWidths = <double>[360, 800, 1400];
  const List<double> kHeights = <double>[720, 1000];
  final List<EdgeInsets> kPaddings = <EdgeInsets>[
    EdgeInsets.zero,
    const EdgeInsets.fromLTRB(16, 44, 16, 34), // notch + side + home indicator
  ];

  final List<_RenderCondition> conditions = <_RenderCondition>[
    for (final double w in kWidths)
      for (final double h in kHeights)
        for (final EdgeInsets p in kPaddings) _RenderCondition(w, h, p),
  ];

  // Mirrors `_availableSafeArea` in adaptive_widgets.dart: screen size minus the
  // Safe_Area insets, clamped to be non-negative on each axis.
  Size availableOf(_RenderCondition c) {
    final double w = math.max(0.0, c.width - c.padding.horizontal);
    final double h = math.max(0.0, c.height - c.padding.vertical);
    return Size(w, h);
  }

  // Pumps [child] under a controlled MediaQuery (size + Safe_Area insets) on a
  // large surface, giving the child LOOSE constraints via an Align so each
  // primitive's internal cap decides its size.
  Future<void> pumpUnder(
    WidgetTester tester,
    _RenderCondition c,
    Widget child,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = kSurface;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(c.width, c.height),
            padding: c.padding,
            viewPadding: c.padding,
          ),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }

  // Tall content that forces height pressure so the height caps actually bind.
  Widget tallContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int i = 0; i < 40; i++)
        SizedBox(height: 48, child: Center(child: Text('Item $i'))),
    ],
  );

  group('Feature: cross-platform-responsive-ui, Property 10: Per-component '
      'constraint invariants', () {
    // ====================================================================
    // PURE PROPERTY (forAll, kNumRuns = 200): AdaptiveGrid column count
    // ====================================================================
    // AdaptiveGrid derives its column count from
    // `responsiveValue(context, mobile:, tablet:, desktop:)`, which classifies
    // the width and delegates to the pure `resolveResponsiveValue`. With all
    // three columns defined, the resolved count is exactly the value for the
    // current Form_Factor. This property verifies that selection rule across
    // generated widths and column specs.
    final Generator<List<dynamic>> gridGen = Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 3840), // width (logical px across the supported range)
      Gen.interval(1, 6), // mobile columns  (>= 1)
      Gen.interval(1, 6), // tablet columns  (>= 1)
      Gen.interval(1, 6), // desktop columns (>= 1)
    ]);

    test('Property 10 (grid): AdaptiveGrid column count == '
        'resolveResponsiveValue(current Form_Factor, mobile, tablet, desktop) '
        'and is a valid (>= 1) count', () {
      final bool held = forAll(
        (List<dynamic> spec) {
          final double w = (spec[0] as int).toDouble();
          final int mobile = spec[1] as int;
          final int tablet = spec[2] as int;
          final int desktop = spec[3] as int;

          final FormFactor factor = ResponsiveBreakpoints.classify(w);

          // The column count AdaptiveGrid selects for this width.
          final int selected = resolveResponsiveValue<int>(
            factor,
            mobile: mobile,
            tablet: tablet,
            desktop: desktop,
          );

          // Independently re-derived expectation: with all three values
          // defined, the current Form_Factor's value is chosen.
          final int expected = switch (factor) {
            FormFactor.mobile => mobile,
            FormFactor.tablet => tablet,
            FormFactor.desktop => desktop,
          };

          return selected == expected && selected >= 1;
        },
        <Generator<dynamic>>[gridGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ====================================================================
    // DIMENSION INVARIANTS (representative pumped render conditions)
    // ====================================================================

    // -- AdaptiveDialog: width <= available width, height <= available height
    testWidgets(
      'Property 10 (dialog): AdaptiveDialog width/height do not exceed the '
      'available Safe_Area dimensions (Req 8.1)',
      (WidgetTester tester) async {
        for (final _RenderCondition c in conditions) {
          final Size available = availableOf(c);

          await pumpUnder(
            tester,
            c,
            AdaptiveDialog(
              title: const Text('Title'),
              content: tallContent(),
              actions: <Widget>[
                TextButton(onPressed: () {}, child: const Text('OK')),
              ],
            ),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'AdaptiveDialog overflowed for $c',
          );

          // The outermost Column built by AdaptiveDialog spans the dialog's
          // resolved content box (stretched to the dialog width, capped at the
          // available height by the scrolling Flexible body).
          final Size box = tester.getSize(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Column),
                )
                .first,
          );

          expect(
            box.width,
            lessThanOrEqualTo(available.width + kEpsilon),
            reason:
                'dialog width ${box.width} > available ${available.width} '
                'for $c',
          );
          expect(
            box.height,
            lessThanOrEqualTo(available.height + kEpsilon),
            reason:
                'dialog height ${box.height} > available ${available.height} '
                'for $c',
          );
        }
      },
    );

    // -- AdaptiveSheet: height <= 90% of available Safe_Area height
    testWidgets(
      'Property 10 (sheet): AdaptiveSheet height does not exceed 90% of the '
      'available Safe_Area height (Req 8.3)',
      (WidgetTester tester) async {
        for (final _RenderCondition c in conditions) {
          final Size available = availableOf(c);
          final double cap = available.height * 0.9;

          await pumpUnder(tester, c, AdaptiveSheet(child: tallContent()));

          expect(
            tester.takeException(),
            isNull,
            reason: 'AdaptiveSheet overflowed for $c',
          );

          final Size box = tester.getSize(
            find
                .descendant(
                  of: find.byType(AdaptiveSheet),
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          );

          expect(
            box.height,
            lessThanOrEqualTo(cap + kEpsilon),
            reason:
                'sheet height ${box.height} > 90% cap $cap (available '
                '${available.height}) for $c',
          );
        }
      },
    );

    // -- AdaptiveTable: rendered width <= available width
    testWidgets(
      'Property 10 (table): AdaptiveTable rendered width does not exceed the '
      'available width via horizontal scroll or reflow (Req 8.7)',
      (WidgetTester tester) async {
        // Many wide columns so the DataTable is wider than the region on
        // Tablet/Desktop (forcing horizontal scroll), plus a card reflow for
        // Mobile.
        final List<DataColumn> columns = <DataColumn>[
          for (int i = 0; i < 8; i++)
            DataColumn(label: Text('A long column header $i')),
        ];
        final List<DataRow> rows = <DataRow>[
          for (int r = 0; r < 5; r++)
            DataRow(
              cells: <DataCell>[
                for (int i = 0; i < 8; i++)
                  DataCell(Text('cell value r$r c$i')),
              ],
            ),
        ];

        for (final _RenderCondition c in conditions) {
          final double availableWidth = availableOf(c).width;

          await pumpUnder(
            tester,
            c,
            SizedBox(
              width: availableWidth,
              child: AdaptiveTable(
                columns: columns,
                rows: rows,
                cardBuilder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int r = 0; r < 5; r++)
                      Card(child: ListTile(title: Text('Row $r'))),
                  ],
                ),
              ),
            ),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'AdaptiveTable overflowed for $c',
          );

          // The AdaptiveTable's rendered root (horizontal scroll viewport on
          // Tablet/Desktop, or the reflowed card column on Mobile) fits within
          // the available width.
          final double renderedWidth = tester
              .getSize(find.byType(AdaptiveTable))
              .width;

          expect(
            renderedWidth,
            lessThanOrEqualTo(availableWidth + kEpsilon),
            reason:
                'table width $renderedWidth > available $availableWidth '
                'for $c',
          );
        }
      },
    );

    // -- AdaptiveChartBox: width/height <= available Safe_Area dimensions
    testWidgets(
      'Property 10 (chart): AdaptiveChartBox width/height do not exceed the '
      'available Safe_Area dimensions (Req 8.9)',
      (WidgetTester tester) async {
        for (final _RenderCondition c in conditions) {
          final Size available = availableOf(c);

          await pumpUnder(
            tester,
            c,
            const AdaptiveChartBox(
              // A child that wants to be enormous, so the chart box's caps
              // (not the child) decide the size.
              child: SizedBox(width: 100000, height: 100000),
            ),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'AdaptiveChartBox overflowed for $c',
          );

          final Size box = tester.getSize(
            find
                .descendant(
                  of: find.byType(AdaptiveChartBox),
                  matching: find.byType(ConstrainedBox),
                )
                .first,
          );

          expect(
            box.width,
            lessThanOrEqualTo(available.width + kEpsilon),
            reason:
                'chart width ${box.width} > available ${available.width} '
                'for $c',
          );
          expect(
            box.height,
            lessThanOrEqualTo(available.height + kEpsilon),
            reason:
                'chart height ${box.height} > available ${available.height} '
                'for $c',
          );
        }
      },
    );

    // -- AdaptiveGrid (pumped): rendered crossAxisCount matches the selector
    testWidgets(
      'Property 10 (grid, pumped): rendered GridView crossAxisCount equals '
      'resolveResponsiveValue for the current Form_Factor (Req 8.8)',
      (WidgetTester tester) async {
        const int mobileColumns = 1;
        const int tabletColumns = 3;
        const int desktopColumns = 5;

        for (final _RenderCondition c in conditions) {
          final Size available = availableOf(c);
          final FormFactor factor = ResponsiveBreakpoints.classify(c.width);
          final int expected = resolveResponsiveValue<int>(
            factor,
            mobile: mobileColumns,
            tablet: tabletColumns,
            desktop: desktopColumns,
          );

          await pumpUnder(
            tester,
            c,
            SizedBox(
              width: available.width,
              height: available.height,
              child: AdaptiveGrid(
                mobileColumns: mobileColumns,
                tabletColumns: tabletColumns,
                desktopColumns: desktopColumns,
                children: <Widget>[
                  for (int i = 0; i < 12; i++)
                    ColoredBox(
                      color: Colors.blue,
                      child: Center(child: Text('$i')),
                    ),
                ],
              ),
            ),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'AdaptiveGrid overflowed for $c',
          );

          final GridView grid = tester.widget<GridView>(find.byType(GridView));
          final SliverGridDelegateWithFixedCrossAxisCount delegate =
              grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

          expect(
            delegate.crossAxisCount,
            expected,
            reason:
                'grid crossAxisCount ${delegate.crossAxisCount} != expected '
                '$expected for ${factor.name} ($c)',
          );
        }
      },
    );
  });
}

/// A single representative render condition: a screen [width] x [height] with
/// the given Safe_Area [padding] (insets).
class _RenderCondition {
  final double width;
  final double height;
  final EdgeInsets padding;

  const _RenderCondition(this.width, this.height, this.padding);

  @override
  String toString() =>
      'w=$width, h=$height, insets=(${padding.left},${padding.top},'
      '${padding.right},${padding.bottom})';
}
