/// Semantics/accessibility test helpers for Flutter UI audit per-fix tests.
///
/// Provides reusable utilities to assert semantic labels, traversal order,
/// and minimum tap-target sizes. Used by `TestCoordinator`-authored tests
/// to validate Requirement 5.6.
///
/// Usage:
/// ```dart
/// import 'package:dukanx/test/audit_helpers/audit_test_helpers.dart';
///
/// testWidgets('accessibility labels present', (tester) async {
///   await tester.pumpWidget(wrapWithTheme(MyWidget()));
///   await tester.pumpAndSettle();
///   assertSemanticLabels(tester, ['Add item', 'Remove item']);
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts that all [expectedLabels] are present in the semantics tree.
///
/// Searches the rendered semantics for nodes whose `label` matches each
/// expected string. The order does not matter for this assertion — use
/// [assertTraversalOrder] if order is significant.
void assertSemanticLabels(WidgetTester tester, List<String> expectedLabels) {
  final SemanticsOwner owner = tester.binding.pipelineOwner.semanticsOwner!;
  final Set<String> foundLabels = _collectLabels(owner.rootSemanticsNode!);

  for (final label in expectedLabels) {
    expect(
      foundLabels,
      contains(label),
      reason:
          'Semantic label "$label" not found in tree.\n'
          '  Found labels: ${foundLabels.toList()}',
    );
  }
}

/// Asserts that semantic labels appear in the exact traversal order given by
/// [expectedOrder].
///
/// Walks the semantics tree in depth-first traversal order, collects labels
/// of nodes that have non-empty labels, and asserts that the subsequence of
/// labels matching [expectedOrder] appears in that exact sequence.
void assertTraversalOrder(WidgetTester tester, List<String> expectedOrder) {
  final SemanticsOwner owner = tester.binding.pipelineOwner.semanticsOwner!;
  final List<String> orderedLabels = _collectOrderedLabels(
    owner.rootSemanticsNode!,
  );

  // Filter to only the labels we expect, preserving their relative order.
  final List<String> actualOrder = orderedLabels
      .where((label) => expectedOrder.contains(label))
      .toList();

  expect(
    actualOrder,
    equals(expectedOrder),
    reason:
        'Traversal order mismatch:\n'
        '  Expected: $expectedOrder\n'
        '  Actual:   $actualOrder',
  );
}

/// Asserts that every element found by [finder] has a rendered size of at
/// least [minSize] x [minSize] logical pixels (default 48.0).
///
/// This validates the WCAG / Material tap-target minimum (48dp).
void assertMinTapTargetSize(
  WidgetTester tester,
  Finder finder, {
  double minSize = 48.0,
}) {
  final elements = finder.evaluate();
  expect(
    elements,
    isNotEmpty,
    reason: 'No elements found by finder for tap-target assertion',
  );

  for (final element in elements) {
    final RenderBox box = element.renderObject! as RenderBox;
    final Size size = box.size;

    expect(
      size.width,
      greaterThanOrEqualTo(minSize),
      reason:
          'Tap target width ${size.width} is below minimum $minSize '
          'for ${element.widget.runtimeType}',
    );
    expect(
      size.height,
      greaterThanOrEqualTo(minSize),
      reason:
          'Tap target height ${size.height} is below minimum $minSize '
          'for ${element.widget.runtimeType}',
    );
  }
}

/// Asserts that all interactive elements (buttons, tappable areas) found in
/// the widget tree meet the minimum tap-target size.
///
/// Searches for common interactive widget types.
void assertAllInteractiveTapTargets(
  WidgetTester tester, {
  double minSize = 48.0,
}) {
  final interactiveFinders = [
    find.byType(ElevatedButton),
    find.byType(TextButton),
    find.byType(OutlinedButton),
    find.byType(IconButton),
    find.byType(InkWell),
    find.byType(GestureDetector),
  ];

  for (final finder in interactiveFinders) {
    if (finder.evaluate().isNotEmpty) {
      assertMinTapTargetSize(tester, finder, minSize: minSize);
    }
  }
}

// -- Private helpers --

/// Recursively collects all non-empty labels from the semantics tree.
Set<String> _collectLabels(SemanticsNode node) {
  final Set<String> labels = {};
  final data = node.getSemanticsData();
  if (data.label.isNotEmpty) {
    labels.add(data.label);
  }
  node.visitChildren((child) {
    labels.addAll(_collectLabels(child));
    return true;
  });
  return labels;
}

/// Recursively collects labels in depth-first traversal order.
List<String> _collectOrderedLabels(SemanticsNode node) {
  final List<String> labels = [];
  final data = node.getSemanticsData();
  if (data.label.isNotEmpty) {
    labels.add(data.label);
  }
  node.visitChildren((child) {
    labels.addAll(_collectOrderedLabels(child));
    return true;
  });
  return labels;
}
