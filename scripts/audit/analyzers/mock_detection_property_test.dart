/// Property-Based Test: Mock Data Pattern Detection (Property 8)
///
/// For any Dart file content, the mock data detector SHALL identify a mock
/// pattern if and only if the content contains: hardcoded sample data arrays
/// with 2+ literal entries, TODO/placeholder comments indicating fake data,
/// imports from paths containing "mock"/"dummy"/"fake"/"sample", or conditional
/// logic returning inline literal data when no API call is present.
///
/// **Validates: Requirements 6.1**
library;

import 'dart:math';

import 'screen_discovery.dart';

void main() {
  print('=== Property 8: Mock Data Pattern Detection ===\n');

  final engine = ScreenDiscoveryEngine();
  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final testCase = _generateTestCase(random);
    final result = engine.detectMockData(testCase.content);

    // Check that detection aligns with inserted patterns
    if (testCase.hasHardcodedArray) {
      assert(
        result.hasMockData && result.mockReasons.contains('hardcoded_array'),
        'Iteration $i: Expected hardcoded_array detection for content with array pattern',
      );
    }

    if (testCase.hasTodoPlaceholder) {
      assert(
        result.hasMockData && result.mockReasons.contains('todo_placeholder'),
        'Iteration $i: Expected todo_placeholder detection for content with TODO mock comment',
      );
    }

    if (testCase.hasMockImport) {
      assert(
        result.hasMockData && result.mockReasons.contains('mock_import'),
        'Iteration $i: Expected mock_import detection for content with mock import',
      );
    }

    if (testCase.hasInlineLiteral) {
      assert(
        result.hasMockData && result.mockReasons.contains('inline_literal'),
        'Iteration $i: Expected inline_literal detection for content with return [...] pattern',
      );
    }

    // If no patterns were inserted, detection should be negative
    if (!testCase.hasAnyPattern) {
      assert(
        !result.hasMockData,
        'Iteration $i: Expected no mock detection for clean content, '
        'but got: ${result.mockReasons}',
      );
    }

    passed++;
  }

  print(
    '✓ Property 8: Mock Data Pattern Detection — $passed/$iterations iterations passed',
  );
}

// ─── Test case generation ──────────────────────────────────────────────────

class _TestInput {
  final String content;
  final bool hasHardcodedArray;
  final bool hasTodoPlaceholder;
  final bool hasMockImport;
  final bool hasInlineLiteral;

  bool get hasAnyPattern =>
      hasHardcodedArray ||
      hasTodoPlaceholder ||
      hasMockImport ||
      hasInlineLiteral;

  const _TestInput({
    required this.content,
    required this.hasHardcodedArray,
    required this.hasTodoPlaceholder,
    required this.hasMockImport,
    required this.hasInlineLiteral,
  });
}

_TestInput _generateTestCase(Random random) {
  final hasHardcodedArray = random.nextBool();
  final hasTodoPlaceholder = random.nextBool();
  final hasMockImport = random.nextBool();
  final hasInlineLiteral = random.nextBool();

  final buffer = StringBuffer();

  // Base imports
  buffer.writeln("import 'package:flutter/material.dart';");

  // Category 3: Mock imports
  if (hasMockImport) {
    final importType = random.nextInt(4);
    switch (importType) {
      case 0:
        buffer.writeln("import 'package:app/mock_data.dart';");
        break;
      case 1:
        buffer.writeln("import 'package:app/dummy_service.dart';");
        break;
      case 2:
        buffer.writeln("import '../fake_repository.dart';");
        break;
      case 3:
        buffer.writeln("import 'data/sample_items.dart';");
        break;
    }
  }

  buffer.writeln();
  buffer.writeln('class TestWidget extends StatelessWidget {');
  buffer.writeln('  const TestWidget({super.key});');
  buffer.writeln();

  // Category 2: TODO/placeholder comments
  if (hasTodoPlaceholder) {
    final commentType = random.nextInt(4);
    switch (commentType) {
      case 0:
        buffer.writeln('  // TODO: Replace fake data with real API call');
        break;
      case 1:
        buffer.writeln('  // FIXME: Remove mock data before release');
        break;
      case 2:
        buffer.writeln('  // placeholder data until API ready');
        break;
      case 3:
        buffer.writeln('  // dummy data for testing');
        break;
    }
  }

  // Category 1: Hardcoded data arrays
  if (hasHardcodedArray) {
    final arrayType = random.nextInt(3);
    switch (arrayType) {
      case 0:
        buffer.writeln(
          "  final items = [{'name': 'Item 1', 'price': 10}, {'name': 'Item 2', 'price': 20}];",
        );
        break;
      case 1:
        buffer.writeln(
          "  final labels = ['Label One', 'Label Two', 'Label Three'];",
        );
        break;
      case 2:
        buffer.writeln(
          '  final data = [{"id": "1", "value": "test"}, {"id": "2", "value": "test2"}];',
        );
        break;
    }
  }

  // Category 4: Inline literal returns
  if (hasInlineLiteral) {
    final returnType = random.nextInt(3);
    switch (returnType) {
      case 0:
        buffer.writeln("  List<Map> getData() { return [{'name': 'Test'}]; }");
        break;
      case 1:
        buffer.writeln(
          "  List<String> getNames() { return ['Alice', 'Bob']; }",
        );
        break;
      case 2:
        buffer.writeln(
          '  final cached = [{"x": 1, "y": 2}, {"x": 3, "y": 4}];',
        );
        break;
    }
  }

  // Clean code padding (when no patterns)
  if (!hasHardcodedArray && !hasTodoPlaceholder && !hasInlineLiteral) {
    buffer.writeln('  final controller = TextEditingController();');
    buffer.writeln('  void dispose() { controller.dispose(); }');
  }

  buffer.writeln();
  buffer.writeln('  @override');
  buffer.writeln('  Widget build(BuildContext context) {');
  buffer.writeln('    return const SizedBox();');
  buffer.writeln('  }');
  buffer.writeln('}');

  return _TestInput(
    content: buffer.toString(),
    hasHardcodedArray: hasHardcodedArray,
    hasTodoPlaceholder: hasTodoPlaceholder,
    hasMockImport: hasMockImport,
    hasInlineLiteral: hasInlineLiteral,
  );
}
