/// UI Consistency Auditor — detects violations of the DukanX design system
/// across all screens in the Flutter codebase.
///
/// Detection patterns:
/// 1. Hardcoded Color literals (Color(0x...), Colors.xxx, Color.fromRGBO(...))
/// 2. Hardcoded TextStyle literals not using theme references
/// 3. Hardcoded padding/margin (numeric EdgeInsets)
/// 4. Missing responsive layout (no ResponsiveLayout/AdaptiveScaffold/LayoutBuilder)
/// 5. Wrong sidebar (custom sidebar instead of EnterpriseDesktopSidebar/MobileDrawer)
/// 6. Missing semantic labels on interactive widgets
/// 7. Small touch targets (< 48dp)
///
/// Requirements: 10.1, 10.2, 10.3, 10.4, 10.5
library;

import 'dart:io';

/// A single UI consistency violation found during audit.
class UiViolation {
  /// The screen/file name where the violation was detected.
  final String screenName;

  /// The checklist item key (e.g., "hardcoded_color", "missing_semantic_label").
  final String checklistItem;

  /// Specific widget or line reference describing the violation.
  final String widgetRef;

  /// Full file path where the violation was found.
  final String filePath;

  /// Line number (1-based) of the violation.
  final int lineNumber;

  const UiViolation({
    required this.screenName,
    required this.checklistItem,
    required this.widgetRef,
    required this.filePath,
    required this.lineNumber,
  });

  @override
  String toString() =>
      'UiViolation($screenName:$lineNumber - $checklistItem: $widgetRef)';
}

/// Audits Flutter Dart files for UI design system consistency violations.
class UiAuditor {
  // ─── Regex patterns for detection ─────────────────────────────────────────

  // 1. Hardcoded color patterns
  static final _colorHexPattern = RegExp(r'Color\s*\(\s*0x[0-9a-fA-F]+\s*\)');
  static final _colorFromRGBOPattern = RegExp(r'Color\.fromRGBO\s*\(');
  static final _colorFromARGBPattern = RegExp(r'Color\.fromARGB\s*\(');
  static final _colorsConstPattern = RegExp(r'Colors\.\w+');

  // Theme reference patterns (these make a color usage acceptable)
  static final _themeColorRef = RegExp(
    r'Theme\.of\s*\(\s*\w+\s*\)\.colorScheme',
  );
  static final _colorSchemeOfRef = RegExp(r'ColorScheme\.of\s*\(\s*\w+\s*\)');

  // 2. Hardcoded TextStyle patterns
  static final _textStyleLiteralPattern = RegExp(r'TextStyle\s*\(');
  static final _themeTextRef = RegExp(r'Theme\.of\s*\(\s*\w+\s*\)\.textTheme');

  // 3. Hardcoded padding/margin patterns
  static final _edgeInsetsAllPattern = RegExp(
    r'EdgeInsets\.all\s*\(\s*[\d.]+\s*\)',
  );
  static final _edgeInsetsSymmetricPattern = RegExp(
    r'EdgeInsets\.symmetric\s*\(',
  );
  static final _edgeInsetsOnlyPattern = RegExp(r'EdgeInsets\.only\s*\(');
  static final _edgeInsetsFromLTRBPattern = RegExp(
    r'EdgeInsets\.fromLTRB\s*\(',
  );

  // 4. Responsive layout indicators
  static final _responsiveLayoutPattern = RegExp(
    r'ResponsiveLayout|AdaptiveScaffold|LayoutBuilder|ResponsiveBreakpoints',
  );

  // 5. Sidebar patterns
  static final _enterpriseSidebarPattern = RegExp(r'EnterpriseDesktopSidebar');
  static final _mobileDrawerPattern = RegExp(r'MobileDrawer');
  static final _customSidebarPattern = RegExp(
    r'Drawer\s*\(|NavigationRail\s*\(|NavigationDrawer\s*\(',
  );

  // 6. Interactive widget patterns for semantic label checks
  static final _iconButtonPattern = RegExp(r'IconButton\s*\(');
  static final _elevatedButtonPattern = RegExp(r'ElevatedButton\s*\(');
  static final _outlinedButtonPattern = RegExp(r'OutlinedButton\s*\(');
  static final _textButtonPattern = RegExp(r'TextButton\s*\(');
  static final _floatingActionButtonPattern = RegExp(
    r'FloatingActionButton\s*\(',
  );
  static final _inkWellPattern = RegExp(r'InkWell\s*\(');
  static final _gestureDetectorPattern = RegExp(r'GestureDetector\s*\(');

  // Semantic label indicators
  static final _semanticsLabelPattern = RegExp(
    r'semanticsLabel\s*:|Semantics\s*\(|tooltip\s*:',
  );

  // 7. Touch target size patterns
  static final _sizedBoxPattern = RegExp(r'SizedBox\s*\(');
  static final _constrainedBoxPattern = RegExp(r'ConstrainedBox\s*\(');

  /// Audit a single file for UI consistency violations.
  ///
  /// [filePath] is used for reporting; [content] is the file's Dart source.
  /// Returns a list of detected violations.
  List<UiViolation> auditFile(String filePath, String content) {
    final violations = <UiViolation>[];
    final lines = content.split('\n');
    final screenName = _extractScreenName(filePath);

    // Track whether the file uses theme references (file-level context)
    final hasThemeColorRef =
        _themeColorRef.hasMatch(content) || _colorSchemeOfRef.hasMatch(content);
    final hasThemeTextRef = _themeTextRef.hasMatch(content);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      // Skip comments and imports
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

      // 1. Hardcoded colors
      _checkHardcodedColors(
        line,
        lineNumber,
        screenName,
        filePath,
        hasThemeColorRef,
        violations,
      );

      // 2. Hardcoded text styles
      _checkHardcodedTextStyles(
        line,
        lineNumber,
        screenName,
        filePath,
        hasThemeTextRef,
        lines,
        i,
        violations,
      );

      // 3. Hardcoded padding/margin
      _checkHardcodedPadding(
        line,
        lineNumber,
        screenName,
        filePath,
        violations,
      );

      // 6. Missing semantic labels on interactive widgets
      _checkSemanticLabels(
        line,
        lineNumber,
        screenName,
        filePath,
        lines,
        i,
        violations,
      );

      // 7. Small touch targets
      _checkTouchTargets(
        line,
        lineNumber,
        screenName,
        filePath,
        lines,
        i,
        violations,
      );
    }

    // 4. Missing responsive layout (file-level check)
    _checkResponsiveLayout(content, screenName, filePath, violations);

    // 5. Wrong sidebar usage (file-level check)
    _checkSidebarUsage(content, screenName, filePath, lines, violations);

    return violations;
  }

  /// Audit all Dart screen files in a project.
  ///
  /// Scans `lib/` recursively and audits files whose name contains
  /// "screen" or "page" (consistent with screen discovery logic).
  List<UiViolation> auditProject(String projectRoot) {
    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) return [];

    final violations = <UiViolation>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final fileName = entity.path
          .split(Platform.pathSeparator)
          .last
          .toLowerCase();
      if (!fileName.contains('screen') && !fileName.contains('page')) continue;

      final filePath = entity.path.replaceAll('\\', '/');
      final content = entity.readAsStringSync();
      violations.addAll(auditFile(filePath, content));
    }

    return violations;
  }

  // ─── Private detection methods ────────────────────────────────────────────

  /// Check for hardcoded color literals on a line.
  void _checkHardcodedColors(
    String line,
    int lineNumber,
    String screenName,
    String filePath,
    bool fileHasThemeColorRef,
    List<UiViolation> violations,
  ) {
    // Skip lines that reference theme colors directly
    if (_themeColorRef.hasMatch(line) || _colorSchemeOfRef.hasMatch(line)) {
      return;
    }

    // Check Color(0x...)
    if (_colorHexPattern.hasMatch(line)) {
      final match = _colorHexPattern.firstMatch(line)!;
      violations.add(
        UiViolation(
          screenName: screenName,
          checklistItem: 'hardcoded_color',
          widgetRef:
              'Inline ${match.group(0)} — use Theme.of(context).colorScheme instead',
          filePath: filePath,
          lineNumber: lineNumber,
        ),
      );
    }

    // Check Color.fromRGBO(...)
    if (_colorFromRGBOPattern.hasMatch(line)) {
      violations.add(
        UiViolation(
          screenName: screenName,
          checklistItem: 'hardcoded_color',
          widgetRef:
              'Color.fromRGBO() — use Theme.of(context).colorScheme instead',
          filePath: filePath,
          lineNumber: lineNumber,
        ),
      );
    }

    // Check Color.fromARGB(...)
    if (_colorFromARGBPattern.hasMatch(line)) {
      violations.add(
        UiViolation(
          screenName: screenName,
          checklistItem: 'hardcoded_color',
          widgetRef:
              'Color.fromARGB() — use Theme.of(context).colorScheme instead',
          filePath: filePath,
          lineNumber: lineNumber,
        ),
      );
    }

    // Check Colors.xxx (e.g., Colors.red, Colors.blue)
    if (_colorsConstPattern.hasMatch(line)) {
      // Allow Colors.transparent and Colors.white/black as common non-theme usage
      final match = _colorsConstPattern.firstMatch(line)!;
      final colorName = match.group(0)!;
      if (!_isAllowedColorConstant(colorName)) {
        violations.add(
          UiViolation(
            screenName: screenName,
            checklistItem: 'hardcoded_color',
            widgetRef: '$colorName — use Theme.of(context).colorScheme instead',
            filePath: filePath,
            lineNumber: lineNumber,
          ),
        );
      }
    }
  }

  /// Check for hardcoded TextStyle literals not using theme textTheme.
  void _checkHardcodedTextStyles(
    String line,
    int lineNumber,
    String screenName,
    String filePath,
    bool fileHasThemeTextRef,
    List<String> lines,
    int lineIndex,
    List<UiViolation> violations,
  ) {
    if (!_textStyleLiteralPattern.hasMatch(line)) return;

    // Check surrounding context (current line + next 3 lines) for theme reference
    final contextEnd = (lineIndex + 4).clamp(0, lines.length);
    final contextWindow = lines.sublist(lineIndex, contextEnd).join('\n');

    // If the TextStyle is part of a theme definition (e.g., in a ThemeData), skip
    if (contextWindow.contains('textTheme') ||
        contextWindow.contains('ThemeData') ||
        contextWindow.contains('copyWith')) {
      return;
    }

    // Skip if line is assigning to a theme
    if (line.contains('Theme.of') || line.contains('.textTheme')) return;

    violations.add(
      UiViolation(
        screenName: screenName,
        checklistItem: 'hardcoded_textstyle',
        widgetRef: 'Inline TextStyle — use Theme.of(context).textTheme instead',
        filePath: filePath,
        lineNumber: lineNumber,
      ),
    );
  }

  /// Check for hardcoded padding/margin with numeric EdgeInsets.
  void _checkHardcodedPadding(
    String line,
    int lineNumber,
    String screenName,
    String filePath,
    List<UiViolation> violations,
  ) {
    String? edgeInsetsType;

    if (_edgeInsetsAllPattern.hasMatch(line)) {
      edgeInsetsType = _edgeInsetsAllPattern.firstMatch(line)!.group(0);
    } else if (_edgeInsetsSymmetricPattern.hasMatch(line)) {
      edgeInsetsType = 'EdgeInsets.symmetric(...)';
    } else if (_edgeInsetsOnlyPattern.hasMatch(line)) {
      edgeInsetsType = 'EdgeInsets.only(...)';
    } else if (_edgeInsetsFromLTRBPattern.hasMatch(line)) {
      edgeInsetsType = 'EdgeInsets.fromLTRB(...)';
    }

    if (edgeInsetsType != null) {
      violations.add(
        UiViolation(
          screenName: screenName,
          checklistItem: 'hardcoded_padding',
          widgetRef: '$edgeInsetsType — consider using theme spacing constants',
          filePath: filePath,
          lineNumber: lineNumber,
        ),
      );
    }
  }

  /// Check if a screen file uses a responsive layout mechanism.
  void _checkResponsiveLayout(
    String content,
    String screenName,
    String filePath,
    List<UiViolation> violations,
  ) {
    // Only flag screen files that have a build method (actual screen widgets)
    if (!content.contains('Widget build(')) return;

    if (!_responsiveLayoutPattern.hasMatch(content)) {
      violations.add(
        UiViolation(
          screenName: screenName,
          checklistItem: 'missing_responsive_layout',
          widgetRef:
              'Screen does not use ResponsiveLayout, AdaptiveScaffold, or LayoutBuilder '
              '— breakpoints: mobile <600px, tablet 600–1100px, desktop ≥1100px',
          filePath: filePath,
          lineNumber: 1,
        ),
      );
    }
  }

  /// Check sidebar usage: should use EnterpriseDesktopSidebar / MobileDrawer
  /// instead of raw Drawer/NavigationRail/NavigationDrawer.
  void _checkSidebarUsage(
    String content,
    String screenName,
    String filePath,
    List<String> lines,
    List<UiViolation> violations,
  ) {
    if (!_customSidebarPattern.hasMatch(content)) return;

    // If the file already uses the proper shared widgets, skip
    if (_enterpriseSidebarPattern.hasMatch(content) ||
        _mobileDrawerPattern.hasMatch(content)) {
      return;
    }

    // Find the line with the custom sidebar
    for (var i = 0; i < lines.length; i++) {
      if (_customSidebarPattern.hasMatch(lines[i])) {
        violations.add(
          UiViolation(
            screenName: screenName,
            checklistItem: 'wrong_sidebar',
            widgetRef:
                'Custom sidebar widget — use EnterpriseDesktopSidebar (desktop) '
                'or MobileDrawer (mobile) instead',
            filePath: filePath,
            lineNumber: i + 1,
          ),
        );
        break; // Report once per file
      }
    }
  }

  /// Check for missing semantic labels on interactive widgets.
  void _checkSemanticLabels(
    String line,
    int lineNumber,
    String screenName,
    String filePath,
    List<String> lines,
    int lineIndex,
    List<UiViolation> violations,
  ) {
    // Determine if this line has an interactive widget
    String? widgetName;

    if (_iconButtonPattern.hasMatch(line)) {
      widgetName = 'IconButton';
    } else if (_elevatedButtonPattern.hasMatch(line)) {
      widgetName = 'ElevatedButton';
    } else if (_outlinedButtonPattern.hasMatch(line)) {
      widgetName = 'OutlinedButton';
    } else if (_textButtonPattern.hasMatch(line)) {
      widgetName = 'TextButton';
    } else if (_floatingActionButtonPattern.hasMatch(line)) {
      widgetName = 'FloatingActionButton';
    } else if (_inkWellPattern.hasMatch(line)) {
      widgetName = 'InkWell';
    } else if (_gestureDetectorPattern.hasMatch(line)) {
      widgetName = 'GestureDetector';
    }

    if (widgetName == null) return;

    // Check surrounding lines (widget constructor span) for semantic label
    final contextEnd = (lineIndex + 10).clamp(0, lines.length);
    final contextWindow = lines.sublist(lineIndex, contextEnd).join('\n');

    // Look for closing of the widget constructor to limit search scope
    if (!_semanticsLabelPattern.hasMatch(contextWindow)) {
      violations.add(
        UiViolation(
          screenName: screenName,
          checklistItem: 'missing_semantic_label',
          widgetRef:
              '$widgetName without semanticsLabel, tooltip, or Semantics wrapper',
          filePath: filePath,
          lineNumber: lineNumber,
        ),
      );
    }
  }

  /// Check for touch targets smaller than 48x48dp.
  void _checkTouchTargets(
    String line,
    int lineNumber,
    String screenName,
    String filePath,
    List<String> lines,
    int lineIndex,
    List<UiViolation> violations,
  ) {
    if (!_sizedBoxPattern.hasMatch(line) &&
        !_constrainedBoxPattern.hasMatch(line)) {
      return;
    }

    // Look at the widget constructor context for width/height values
    final contextEnd = (lineIndex + 5).clamp(0, lines.length);
    final contextWindow = lines.sublist(lineIndex, contextEnd).join('\n');

    // Check if this is constraining an interactive widget
    // Look for interactive widgets in the next few lines after the SizedBox
    final hasInteractiveChild =
        _iconButtonPattern.hasMatch(contextWindow) ||
        _inkWellPattern.hasMatch(contextWindow) ||
        _gestureDetectorPattern.hasMatch(contextWindow) ||
        _elevatedButtonPattern.hasMatch(contextWindow) ||
        _floatingActionButtonPattern.hasMatch(contextWindow);

    if (!hasInteractiveChild) return;

    // Extract width and height values
    final widthMatch = RegExp(
      r'width\s*:\s*([\d.]+)',
    ).firstMatch(contextWindow);
    final heightMatch = RegExp(
      r'height\s*:\s*([\d.]+)',
    ).firstMatch(contextWindow);

    if (widthMatch != null) {
      final width = double.tryParse(widthMatch.group(1)!) ?? 48;
      if (width < 48) {
        violations.add(
          UiViolation(
            screenName: screenName,
            checklistItem: 'small_touch_target',
            widgetRef: 'Touch target width ${width}dp is below minimum 48dp',
            filePath: filePath,
            lineNumber: lineNumber,
          ),
        );
        return;
      }
    }

    if (heightMatch != null) {
      final height = double.tryParse(heightMatch.group(1)!) ?? 48;
      if (height < 48) {
        violations.add(
          UiViolation(
            screenName: screenName,
            checklistItem: 'small_touch_target',
            widgetRef: 'Touch target height ${height}dp is below minimum 48dp',
            filePath: filePath,
            lineNumber: lineNumber,
          ),
        );
      }
    }
  }

  // ─── Utility helpers ──────────────────────────────────────────────────────

  /// Extract a human-readable screen name from a file path.
  String _extractScreenName(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    return fileName.replaceAll('.dart', '');
  }

  /// Check if a Colors.xxx constant is commonly allowed (not a theme violation).
  ///
  /// Colors.transparent, Colors.white, and Colors.black are common utility
  /// colors that don't typically duplicate theme values.
  bool _isAllowedColorConstant(String colorRef) {
    const allowed = {'Colors.transparent', 'Colors.white', 'Colors.black'};
    return allowed.contains(colorRef);
  }
}
