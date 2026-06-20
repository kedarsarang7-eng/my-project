/// Property-Based Test: UI Compliance Detection (Property 15)
///
/// For any Dart widget code containing inline Color literals, TextStyle literals,
/// or numeric padding/margin that duplicate theme-available values, the UI auditor
/// SHALL flag them as violations. Code using theme references SHALL NOT be flagged.
///
/// **Validates: Requirements 10.3**
library;

import 'dart:math';

import 'ui_auditor.dart';

void main() {
  print(
    '=== Property 15: UI Compliance Detection — Hardcoded Style Values ===\n',
  );

  final auditor = UiAuditor();
  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final testCase = _generateTestCase(random);
    final violations = auditor.auditFile(testCase.filePath, testCase.content);

    // Property: Inline style values are flagged
    if (testCase.hasInlineColor) {
      final hasColorViolation = violations.any(
        (v) => v.checklistItem == 'hardcoded_color',
      );
      assert(
        hasColorViolation,
        'Iteration $i: Expected hardcoded_color violation for inline Color literal',
      );
    }

    if (testCase.hasInlineTextStyle) {
      final hasTextStyleViolation = violations.any(
        (v) => v.checklistItem == 'hardcoded_textstyle',
      );
      assert(
        hasTextStyleViolation,
        'Iteration $i: Expected hardcoded_textstyle violation for inline TextStyle',
      );
    }

    if (testCase.hasInlinePadding) {
      final hasPaddingViolation = violations.any(
        (v) => v.checklistItem == 'hardcoded_padding',
      );
      assert(
        hasPaddingViolation,
        'Iteration $i: Expected hardcoded_padding violation for numeric EdgeInsets',
      );
    }

    // Property: Theme references are NOT flagged for those specific categories
    if (testCase.usesThemeColors && !testCase.hasInlineColor) {
      final hasColorViolation = violations.any(
        (v) => v.checklistItem == 'hardcoded_color',
      );
      assert(
        !hasColorViolation,
        'Iteration $i: Theme color reference should not trigger hardcoded_color violation',
      );
    }

    if (testCase.usesThemeText && !testCase.hasInlineTextStyle) {
      final hasTextStyleViolation = violations.any(
        (v) => v.checklistItem == 'hardcoded_textstyle',
      );
      assert(
        !hasTextStyleViolation,
        'Iteration $i: Theme text reference should not trigger hardcoded_textstyle violation',
      );
    }

    passed++;
  }

  print(
    '✓ Property 15: UI Compliance Detection — $passed/$iterations iterations passed',
  );
}

// ─── Test case generation ──────────────────────────────────────────────────

class _TestInput {
  final String filePath;
  final String content;
  final bool hasInlineColor;
  final bool hasInlineTextStyle;
  final bool hasInlinePadding;
  final bool usesThemeColors;
  final bool usesThemeText;

  const _TestInput({
    required this.filePath,
    required this.content,
    required this.hasInlineColor,
    required this.hasInlineTextStyle,
    required this.hasInlinePadding,
    required this.usesThemeColors,
    required this.usesThemeText,
  });
}

_TestInput _generateTestCase(Random random) {
  final hasInlineColor = random.nextBool();
  final hasInlineTextStyle = random.nextBool();
  final hasInlinePadding = random.nextBool();
  final usesThemeColors = !hasInlineColor && random.nextBool();
  final usesThemeText = !hasInlineTextStyle && random.nextBool();

  final buffer = StringBuffer();
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln();
  buffer.writeln('class TestScreen extends StatelessWidget {');
  buffer.writeln('  const TestScreen({super.key});');
  buffer.writeln();
  buffer.writeln('  @override');
  buffer.writeln('  Widget build(BuildContext context) {');

  if (usesThemeColors) {
    buffer.writeln('    final colorScheme = Theme.of(context).colorScheme;');
    buffer.writeln('    final primary = colorScheme.primary;');
  }

  if (usesThemeText) {
    buffer.writeln('    final textTheme = Theme.of(context).textTheme;');
    buffer.writeln('    final headline = textTheme.headlineMedium;');
  }

  buffer.writeln('    return Column(');
  buffer.writeln('      children: [');

  if (hasInlineColor) {
    final colorType = random.nextInt(3);
    switch (colorType) {
      case 0:
        buffer.writeln(
          '        Container(color: Color(0xFF${_randomHex(random)})),',
        );
        break;
      case 1:
        buffer.writeln(
          '        Container(color: Color.fromRGBO(${random.nextInt(256)}, ${random.nextInt(256)}, ${random.nextInt(256)}, 1.0)),',
        );
        break;
      case 2:
        buffer.writeln('        Container(color: Colors.red),');
        break;
    }
  }

  if (hasInlineTextStyle) {
    buffer.writeln(
      '        Text("Hello", style: TextStyle(fontSize: ${random.nextInt(24) + 12}.0, fontWeight: FontWeight.bold)),',
    );
  }

  if (hasInlinePadding) {
    final paddingType = random.nextInt(4);
    switch (paddingType) {
      case 0:
        buffer.writeln(
          '        Padding(padding: EdgeInsets.all(${random.nextInt(32) + 4}.0)),',
        );
        break;
      case 1:
        buffer.writeln(
          '        Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0)),',
        );
        break;
      case 2:
        buffer.writeln(
          '        Padding(padding: EdgeInsets.only(left: 12.0)),',
        );
        break;
      case 3:
        buffer.writeln(
          '        Padding(padding: EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0)),',
        );
        break;
    }
  }

  // Add clean widgets if no inline styles
  if (!hasInlineColor && !hasInlineTextStyle && !hasInlinePadding) {
    if (usesThemeColors) {
      buffer.writeln(
        '        Container(color: Theme.of(context).colorScheme.surface),',
      );
    }
    if (usesThemeText) {
      buffer.writeln(
        '        Text("Hello", style: Theme.of(context).textTheme.bodyMedium),',
      );
    }
    if (!usesThemeColors && !usesThemeText) {
      buffer.writeln('        const SizedBox(height: 16),');
    }
  }

  buffer.writeln('      ],');
  buffer.writeln('    );');
  buffer.writeln('  }');
  buffer.writeln('}');

  return _TestInput(
    filePath: 'lib/features/test/presentation/screens/test_screen.dart',
    content: buffer.toString(),
    hasInlineColor: hasInlineColor,
    hasInlineTextStyle: hasInlineTextStyle,
    hasInlinePadding: hasInlinePadding,
    usesThemeColors: usesThemeColors,
    usesThemeText: usesThemeText,
  );
}

String _randomHex(Random random) {
  return random
      .nextInt(0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();
}
