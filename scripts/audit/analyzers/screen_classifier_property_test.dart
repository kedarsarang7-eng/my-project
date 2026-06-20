/// Property-Based Test: Screen Classifier Correctness (Property 1)
///
/// For any Dart file content and file path, the screen classifier SHALL include
/// the file if and only if: (a) the path/class contains "screen" or "page"
/// (case-insensitive), AND (b) the file contains a class extending
/// StatelessWidget or StatefulWidget.
///
/// **Validates: Requirements 1.1, 1.6**
library;

import 'dart:math';

import 'screen_discovery.dart';

void main() {
  print('=== Property 1: Screen Classifier Correctness ===\n');

  final engine = ScreenDiscoveryEngine();
  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final testCase = _generateTestCase(random);
    final result = engine.classifyFile(testCase.filePath, testCase.content);

    final pathOrClassHasKeyword =
        testCase.pathHasKeyword || testCase.classHasKeyword;
    final hasWidgetClass = testCase.hasWidgetClass;

    // Property: isScreen == true IFF (path/class has screen/page) AND (has widget class)
    final expectedIsScreen = pathOrClassHasKeyword && hasWidgetClass;

    // When file name matches but no widget class → should be false positive
    final expectedFalsePositive = testCase.pathHasKeyword && !hasWidgetClass;

    if (expectedIsScreen) {
      assert(
        result.isScreen,
        'Iteration $i: Expected isScreen=true for path="${testCase.filePath}" '
        'pathHasKeyword=${testCase.pathHasKeyword}, classHasKeyword=${testCase.classHasKeyword}, '
        'hasWidgetClass=${testCase.hasWidgetClass}',
      );
    } else {
      assert(
        !result.isScreen,
        'Iteration $i: Expected isScreen=false for path="${testCase.filePath}" '
        'pathHasKeyword=${testCase.pathHasKeyword}, classHasKeyword=${testCase.classHasKeyword}, '
        'hasWidgetClass=${testCase.hasWidgetClass}',
      );
    }

    if (expectedFalsePositive) {
      assert(
        result.isFalsePositive,
        'Iteration $i: Expected isFalsePositive=true when path matches but no widget class',
      );
    }

    passed++;
  }

  print(
    '✓ Property 1: Screen Classifier Correctness — $passed/$iterations iterations passed',
  );
}

// ─── Test case generation ──────────────────────────────────────────────────

class _TestInput {
  final String filePath;
  final String content;
  final bool pathHasKeyword;
  final bool classHasKeyword;
  final bool hasWidgetClass;

  const _TestInput({
    required this.filePath,
    required this.content,
    required this.pathHasKeyword,
    required this.classHasKeyword,
    required this.hasWidgetClass,
  });
}

_TestInput _generateTestCase(Random random) {
  // Decide properties independently
  final pathHasKeyword = random.nextBool();
  final hasWidgetClass = random.nextBool();
  final classHasKeyword = hasWidgetClass ? random.nextBool() : false;

  // Generate file path
  final folderSegments = [
    'lib',
    'features',
    _randomFolder(random),
    'presentation',
    'screens',
  ];
  final fileName = _generateFileName(random, pathHasKeyword);
  final filePath = '${folderSegments.join("/")}/$fileName';

  // Generate file content
  final content = _generateFileContent(random, hasWidgetClass, classHasKeyword);

  return _TestInput(
    filePath: filePath,
    content: content,
    pathHasKeyword: pathHasKeyword,
    classHasKeyword: classHasKeyword,
    hasWidgetClass: hasWidgetClass,
  );
}

String _generateFileName(Random random, bool includeKeyword) {
  final prefix = _randomIdentifier(random);
  if (includeKeyword) {
    final keyword = random.nextBool() ? 'screen' : 'page';
    return '${prefix}_$keyword.dart';
  }
  return '${prefix}_widget.dart';
}

String _generateFileContent(
  Random random,
  bool hasWidgetClass,
  bool classHasKeyword,
) {
  final buffer = StringBuffer();
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln();

  if (hasWidgetClass) {
    final className = _generateClassName(random, classHasKeyword);
    final widgetType = random.nextBool() ? 'StatelessWidget' : 'StatefulWidget';
    buffer.writeln('class $className extends $widgetType {');
    buffer.writeln('  const $className({super.key});');
    buffer.writeln();
    if (widgetType == 'StatelessWidget') {
      buffer.writeln('  @override');
      buffer.writeln('  Widget build(BuildContext context) {');
      buffer.writeln('    return const SizedBox();');
      buffer.writeln('  }');
    } else {
      buffer.writeln('  @override');
      buffer.writeln(
        '  State<$className> createState() => _${className}State();',
      );
    }
    buffer.writeln('}');
  } else {
    // Generate a non-widget class or just utility code
    final className = _randomPascalCase(random);
    buffer.writeln('class ${className}Helper {');
    buffer.writeln('  static String format(String input) => input.trim();');
    buffer.writeln('}');
  }

  return buffer.toString();
}

String _generateClassName(Random random, bool includeKeyword) {
  final base = _randomPascalCase(random);
  if (includeKeyword) {
    final keyword = random.nextBool() ? 'Screen' : 'Page';
    return '$base$keyword';
  }
  return '${base}Widget';
}

String _randomFolder(Random random) {
  const folders = [
    'restaurant',
    'billing',
    'pharmacy',
    'jewellery',
    'clinic',
    'hardware',
  ];
  return folders[random.nextInt(folders.length)];
}

String _randomIdentifier(Random random) {
  const words = [
    'home',
    'order',
    'menu',
    'item',
    'list',
    'detail',
    'form',
    'edit',
    'new',
    'manage',
  ];
  return words[random.nextInt(words.length)];
}

String _randomPascalCase(Random random) {
  const words = [
    'Order',
    'Menu',
    'Item',
    'Detail',
    'Form',
    'Settings',
    'Profile',
    'Dashboard',
    'Report',
    'Analytics',
  ];
  final word1 = words[random.nextInt(words.length)];
  final word2 = words[random.nextInt(words.length)];
  return '$word1$word2';
}
