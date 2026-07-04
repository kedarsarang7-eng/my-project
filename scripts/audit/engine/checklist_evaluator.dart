/// ChecklistEvaluator — evaluates a screen source file against the five
/// Analysis Checklist categories across four Screen_States.
///
/// Categories:
/// 1. Layout & Overflow (Req 3.1)
/// 2. Hardcoded Values (Req 3.2)
/// 3. Responsiveness & Platform Coverage (Req 3.3)
/// 4. UI/UX Correctness (Req 3.4)
/// 5. Performance (Req 3.5)
///
/// Recording rules:
/// - PASS when no defect found (Req 3.6)
/// - FAIL when ≥1 defect found, emitting ≥1 Finding (Req 3.8)
/// - N/A when checks don't apply, with a stated reason (Req 3.7)
///
/// If the screen source file cannot be read → blocked (Req 2.4, 2.8).
///
/// Requirements: 2.4, 2.8, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8
library;

import 'dart:io';

import '../models/audit_engine_models.dart';
import 'finding_recorder.dart';

/// Reads a screen source file for analysis.
///
/// Abstracted to allow test injection (e.g. in-memory file system).
abstract class SourceFileReader {
  /// Reads the file at [filePath] and returns its content.
  /// Throws if the file cannot be read.
  String readFile(String filePath);
}

/// Default [SourceFileReader] that reads from the real file system.
class DiskSourceFileReader implements SourceFileReader {
  const DiskSourceFileReader();

  @override
  String readFile(String filePath) {
    // Normalize path separators for cross-platform support.
    final normalized = filePath.replaceAll('/', Platform.pathSeparator);
    final file = File(normalized);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', normalized);
    }
    return file.readAsStringSync();
  }
}

/// Evaluates a [ScreenRef] against the five-category Analysis Checklist
/// across four Screen_States, recording findings via a [FindingRecorder].
///
/// Static analysis is regex-based; rendering-dependent checks (actual overflow,
/// contrast, tap-target sizing) are deferred to Flutter widget/golden tests.
class ChecklistEvaluator {
  /// Recorder used to emit findings for FAIL results.
  final FindingRecorder _recorder;

  /// File reader abstraction (defaults to disk).
  final SourceFileReader _fileReader;

  ChecklistEvaluator({
    required FindingRecorder recorder,
    SourceFileReader? fileReader,
  }) : _recorder = recorder,
       _fileReader = fileReader ?? const DiskSourceFileReader();

  /// Analyzes a screen against all five categories across four states.
  ///
  /// Returns [ScreenAnalysis.blocked] if the file cannot be read (Req 2.8).
  /// Otherwise returns results per [ScreenState] (Req 3.6).
  ScreenAnalysis analyze(ScreenRef screen) {
    // Req 2.4: open and read the screen source file.
    final String content;
    try {
      content = _fileReader.readFile(screen.filePath);
    } catch (e) {
      // Req 2.8: blocked with a stated reason.
      return ScreenAnalysis.blocked(
        screen: screen,
        reason: 'Cannot read file: $e',
      );
    }

    final results = <ScreenState, List<CategoryResult>>{};

    for (final state in ScreenState.values) {
      final categoryResults = <CategoryResult>[];

      for (final category in ChecklistCategory.values) {
        final result = _evaluateCategory(
          screen: screen,
          content: content,
          state: state,
          category: category,
        );
        categoryResults.add(result);
      }

      results[state] = categoryResults;
    }

    return ScreenAnalysis(screen: screen, blocked: false, results: results);
  }

  /// Evaluates a single category for a given screen state.
  ///
  /// Dispatches to the appropriate pattern-matching method per category.
  CategoryResult _evaluateCategory({
    required ScreenRef screen,
    required String content,
    required ScreenState state,
    required ChecklistCategory category,
  }) {
    return switch (category) {
      ChecklistCategory.layoutAndOverflow => _evaluateLayoutAndOverflow(
        screen,
        content,
        state,
      ),
      ChecklistCategory.hardcodedValues => _evaluateHardcodedValues(
        screen,
        content,
        state,
      ),
      ChecklistCategory.responsivenessAndPlatformCoverage =>
        _evaluateResponsiveness(screen, content, state),
      ChecklistCategory.uiUxCorrectness => _evaluateUiUxCorrectness(
        screen,
        content,
        state,
      ),
      ChecklistCategory.performance => _evaluatePerformance(
        screen,
        content,
        state,
      ),
    };
  }

  // ─── Category 1: Layout & Overflow (Req 3.1) ───────────────────────────

  // Patterns indicating overflow risks.
  static final _expandedWithoutBounds = RegExp(r'Expanded\s*\(');
  static final _fixedWidthLiteral = RegExp(r'width\s*:\s*(\d+\.?\d*)');
  static final _overflowHandling = RegExp(
    r'overflow\s*:|TextOverflow\.|clipBehavior\s*:',
  );
  static final _ellipsisOrMaxLines = RegExp(
    r'maxLines\s*:|overflow\s*:\s*TextOverflow\.ellipsis',
  );
  static final _textWidgetPattern = RegExp(r'Text\s*\(');
  static final _singleChildScrollView = RegExp(
    r'SingleChildScrollView|CustomScrollView|ListView|ScrollView',
  );

  /// Checks for layout/overflow risks via static patterns.
  ///
  /// Detects: Expanded without bounds, fixed widths that may exceed
  /// constraints, text without overflow handling, missing scroll wrappers.
  /// Rendering-dependent overflow detection is deferred to Flutter tests.
  CategoryResult _evaluateLayoutAndOverflow(
    ScreenRef screen,
    String content,
    ScreenState state,
  ) {
    // If the file has no build method, layout checks are N/A.
    if (!content.contains('Widget build(')) {
      return const CategoryResult(
        category: ChecklistCategory.layoutAndOverflow,
        status: CategoryStatus.na,
        reason: 'File does not contain a build method',
      );
    }

    final lines = content.split('\n');
    final findings = <_DetectedIssue>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;
      final trimmed = line.trimLeft();

      // Skip comments and imports.
      if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

      // Detect Expanded without parent constraints (heuristic: Expanded in a
      // Row/Column without Flexible or bounded container).
      if (_expandedWithoutBounds.hasMatch(line)) {
        // Check surrounding context for proper bounding.
        final contextStart = (i - 5).clamp(0, lines.length);
        final contextEnd = (i + 5).clamp(0, lines.length);
        final context = lines.sublist(contextStart, contextEnd).join('\n');
        if (!context.contains('Flexible') &&
            !context.contains('ConstrainedBox') &&
            !context.contains('SizedBox')) {
          findings.add(
            _DetectedIssue(
              lineNumber: lineNumber,
              description:
                  'Expanded widget without visible bounded constraint — '
                  'potential overflow risk',
            ),
          );
        }
      }

      // Detect large fixed width literals (>400) that may overflow on mobile.
      final widthMatch = _fixedWidthLiteral.firstMatch(line);
      if (widthMatch != null) {
        final width = double.tryParse(widthMatch.group(1)!) ?? 0;
        if (width > 400) {
          findings.add(
            _DetectedIssue(
              lineNumber: lineNumber,
              description:
                  'Fixed width ${width}dp may exceed constraints on smaller '
                  'screens',
            ),
          );
        }
      }

      // Detect Text widgets without overflow/maxLines handling.
      if (_textWidgetPattern.hasMatch(line)) {
        final contextEnd = (i + 8).clamp(0, lines.length);
        final context = lines.sublist(i, contextEnd).join('\n');
        if (!_ellipsisOrMaxLines.hasMatch(context) &&
            !_overflowHandling.hasMatch(context)) {
          // Only flag if the text appears to contain a long or dynamic value.
          if (context.contains(r'$') ||
              context.contains('toString') ||
              context.contains('.name') ||
              context.contains('.title') ||
              context.contains('.description')) {
            findings.add(
              _DetectedIssue(
                lineNumber: lineNumber,
                description:
                    'Text widget with dynamic content lacks overflow '
                    'handling (maxLines/ellipsis)',
              ),
            );
          }
        }
      }
    }

    // No scrollable wrapper in a screen with a build method is a risk.
    if (!_singleChildScrollView.hasMatch(content) &&
        content.contains('Column(')) {
      findings.add(
        _DetectedIssue(
          lineNumber: 1,
          description:
              'Column without scroll wrapper — may overflow on smaller '
              'screens or with larger content',
        ),
      );
    }

    return _buildResult(
      screen: screen,
      category: ChecklistCategory.layoutAndOverflow,
      state: state,
      findings: findings,
    );
  }

  // ─── Category 2: Hardcoded Values (Req 3.2) ────────────────────────────

  static final _hardcodedColorHex = RegExp(r'Color\s*\(\s*0x[0-9a-fA-F]+\s*\)');
  static final _hardcodedColorFromRGBO = RegExp(r'Color\.fromRGBO\s*\(');
  static final _hardcodedColorFromARGB = RegExp(r'Color\.fromARGB\s*\(');
  static final _hardcodedColorsConst = RegExp(r'Colors\.\w+');
  static final _themeColorRef = RegExp(
    r'Theme\.of\s*\(\s*\w+\s*\)\.colorScheme|ColorScheme\.of\s*\(',
  );
  static final _edgeInsetsLiteral = RegExp(
    r'EdgeInsets\.(all|symmetric|only|fromLTRB)\s*\(',
  );
  static final _fontSizeLiteral = RegExp(r'fontSize\s*:\s*[\d.]+');
  static final _themeTextRef = RegExp(
    r'Theme\.of\s*\(\s*\w+\s*\)\.textTheme|\.textTheme\.',
  );
  static final _stringLiteralInText = RegExp(
    r"""Text\s*\(\s*['"][^'"]{2,}['"]""",
  );
  // Allowed Colors constants that don't violate theme usage.
  static const _allowedColors = {
    'Colors.transparent',
    'Colors.white',
    'Colors.black',
  };

  CategoryResult _evaluateHardcodedValues(
    ScreenRef screen,
    String content,
    ScreenState state,
  ) {
    if (!content.contains('Widget build(')) {
      return const CategoryResult(
        category: ChecklistCategory.hardcodedValues,
        status: CategoryStatus.na,
        reason: 'File does not contain a build method',
      );
    }

    final lines = content.split('\n');
    final findings = <_DetectedIssue>[];
    // Theme references at file level are tracked for context but individual
    // line checks already skip lines with direct theme refs.

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;
      final trimmed = line.trimLeft();

      // Skip comments and imports.
      if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;
      // Skip lines that reference theme directly.
      if (_themeColorRef.hasMatch(line)) continue;

      // Hardcoded color: Color(0x...)
      if (_hardcodedColorHex.hasMatch(line)) {
        findings.add(
          _DetectedIssue(
            lineNumber: lineNumber,
            description:
                'Hardcoded color literal ${_hardcodedColorHex.firstMatch(line)!.group(0)} '
                '— use Theme.of(context).colorScheme',
          ),
        );
      }

      // Hardcoded color: Color.fromRGBO/fromARGB
      if (_hardcodedColorFromRGBO.hasMatch(line)) {
        findings.add(
          _DetectedIssue(
            lineNumber: lineNumber,
            description: 'Hardcoded Color.fromRGBO() — use theme colorScheme',
          ),
        );
      }
      if (_hardcodedColorFromARGB.hasMatch(line)) {
        findings.add(
          _DetectedIssue(
            lineNumber: lineNumber,
            description: 'Hardcoded Color.fromARGB() — use theme colorScheme',
          ),
        );
      }

      // Hardcoded color: Colors.xxx (excluding allowed ones)
      if (_hardcodedColorsConst.hasMatch(line)) {
        final match = _hardcodedColorsConst.firstMatch(line)!.group(0)!;
        if (!_allowedColors.contains(match)) {
          findings.add(
            _DetectedIssue(
              lineNumber: lineNumber,
              description: 'Hardcoded $match — use theme colorScheme',
            ),
          );
        }
      }

      // Hardcoded padding/margin literals
      if (_edgeInsetsLiteral.hasMatch(line)) {
        findings.add(
          _DetectedIssue(
            lineNumber: lineNumber,
            description:
                'Hardcoded EdgeInsets literal — use DesignTokens spacing',
          ),
        );
      }

      // Hardcoded font size
      if (_fontSizeLiteral.hasMatch(line) && !_themeTextRef.hasMatch(line)) {
        findings.add(
          _DetectedIssue(
            lineNumber: lineNumber,
            description: 'Hardcoded fontSize — use Theme.of(context).textTheme',
          ),
        );
      }

      // User-facing string literals in Text widgets
      if (_stringLiteralInText.hasMatch(line)) {
        findings.add(
          _DetectedIssue(
            lineNumber: lineNumber,
            description:
                'Hardcoded user-facing string literal in Text widget '
                '— consider localization/constants',
          ),
        );
      }
    }

    return _buildResult(
      screen: screen,
      category: ChecklistCategory.hardcodedValues,
      state: state,
      findings: findings,
    );
  }

  // ─── Category 3: Responsiveness & Platform Coverage (Req 3.3) ──────────

  static final _responsivePrimitives = RegExp(
    r'ResponsiveLayout|AdaptiveScaffold|LayoutBuilder|'
    r'ResponsiveBreakpoints|ResponsiveContext|responsiveValue|'
    r'context\.isMobile|context\.isTablet|context\.isDesktop|'
    r'MediaQuery\.of|MediaQuery\.sizeOf|DesktopContentContainer',
  );
  static final _platformCheck = RegExp(
    r'Platform\.(isAndroid|isIOS|isWindows|isLinux|isMacOS)|'
    r'kIsWeb|defaultTargetPlatform',
  );

  CategoryResult _evaluateResponsiveness(
    ScreenRef screen,
    String content,
    ScreenState state,
  ) {
    if (!content.contains('Widget build(')) {
      return const CategoryResult(
        category: ChecklistCategory.responsivenessAndPlatformCoverage,
        status: CategoryStatus.na,
        reason: 'File does not contain a build method',
      );
    }

    final findings = <_DetectedIssue>[];

    // Check for absence of responsive primitives.
    if (!_responsivePrimitives.hasMatch(content)) {
      findings.add(
        _DetectedIssue(
          lineNumber: 1,
          description:
              'Screen does not use any responsive primitive '
              '(ResponsiveLayout, LayoutBuilder, MediaQuery, etc.) — '
              'may not adapt across phone/tablet/desktop',
        ),
      );
    }

    // Check for absence of platform-adaptive patterns.
    if (!_platformCheck.hasMatch(content) &&
        !_responsivePrimitives.hasMatch(content)) {
      findings.add(
        _DetectedIssue(
          lineNumber: 1,
          description:
              'No platform-adaptive layout detected — screen may not '
              'handle different Target_Platforms correctly',
        ),
      );
    }

    return _buildResult(
      screen: screen,
      category: ChecklistCategory.responsivenessAndPlatformCoverage,
      state: state,
      findings: findings,
    );
  }

  // ─── Category 4: UI/UX Correctness (Req 3.4) ──────────────────────────

  static final _interactiveWidgets = RegExp(
    r'IconButton\s*\(|ElevatedButton\s*\(|OutlinedButton\s*\(|'
    r'TextButton\s*\(|FloatingActionButton\s*\(|'
    r'InkWell\s*\(|GestureDetector\s*\(',
  );
  static final _semanticsPattern = RegExp(
    r'semanticsLabel\s*:|Semantics\s*\(|tooltip\s*:',
  );
  // Navigator pattern detection — actual dead-nav and back-stack correctness
  // is verified by Flutter navigation tests at runtime, not static analysis.

  CategoryResult _evaluateUiUxCorrectness(
    ScreenRef screen,
    String content,
    ScreenState state,
  ) {
    if (!content.contains('Widget build(')) {
      return const CategoryResult(
        category: ChecklistCategory.uiUxCorrectness,
        status: CategoryStatus.na,
        reason: 'File does not contain a build method',
      );
    }

    final lines = content.split('\n');
    final findings = <_DetectedIssue>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

      // Check interactive widgets for missing semantics/accessibility.
      if (_interactiveWidgets.hasMatch(line)) {
        final contextEnd = (i + 10).clamp(0, lines.length);
        final context = lines.sublist(i, contextEnd).join('\n');
        if (!_semanticsPattern.hasMatch(context)) {
          final widgetMatch = _interactiveWidgets.firstMatch(line);
          final widgetName = widgetMatch != null
              ? widgetMatch.group(0)!.replaceAll(RegExp(r'\s*\($'), '')
              : 'Interactive widget';
          findings.add(
            _DetectedIssue(
              lineNumber: lineNumber,
              description:
                  '$widgetName without semanticsLabel, tooltip, or '
                  'Semantics wrapper — accessibility issue',
            ),
          );
        }
      }
    }

    // File-level: check for navigation patterns (dead nav detection is
    // rendering-dependent but absence of nav patterns in a screen is notable).
    // This is informational — actual nav correctness is tested at runtime.

    return _buildResult(
      screen: screen,
      category: ChecklistCategory.uiUxCorrectness,
      state: state,
      findings: findings,
    );
  }

  // ─── Category 5: Performance (Req 3.5) ─────────────────────────────────

  static final _missingConst = RegExp(
    r'(?<!const\s)(EdgeInsets\.|BorderRadius\.|TextStyle\(|BoxDecoration\()',
  );
  static final _nestedListView = RegExp(
    r'ListView\s*\(|ListView\.builder\s*\(|ListView\.separated\s*\(',
  );
  static final _shrinkWrapPattern = RegExp(r'shrinkWrap\s*:\s*true');
  static final _consumerScopingPattern = RegExp(
    r'Consumer\s*\(|Selector\s*<|context\.select|context\.watch',
  );
  static final _contextReadWatch = RegExp(
    r'context\.read|context\.watch|Provider\.of',
  );

  CategoryResult _evaluatePerformance(
    ScreenRef screen,
    String content,
    ScreenState state,
  ) {
    if (!content.contains('Widget build(')) {
      return const CategoryResult(
        category: ChecklistCategory.performance,
        status: CategoryStatus.na,
        reason: 'File does not contain a build method',
      );
    }

    final lines = content.split('\n');
    final findings = <_DetectedIssue>[];

    // Track nested ListViews.
    int listViewDepth = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

      // Detect missing const on common immutable constructors.
      if (_missingConst.hasMatch(line) && !line.contains('const ')) {
        findings.add(
          _DetectedIssue(
            lineNumber: lineNumber,
            description:
                'Potentially missing const constructor — may cause '
                'unnecessary rebuilds',
          ),
        );
      }

      // Detect nested ListViews (ListView inside another scrollable).
      if (_nestedListView.hasMatch(line)) {
        listViewDepth++;
        if (listViewDepth > 1 && !_shrinkWrapPattern.hasMatch(line)) {
          final contextEnd = (i + 5).clamp(0, lines.length);
          final context = lines.sublist(i, contextEnd).join('\n');
          if (!_shrinkWrapPattern.hasMatch(context)) {
            findings.add(
              _DetectedIssue(
                lineNumber: lineNumber,
                description:
                    'Nested ListView without shrinkWrap — unbounded '
                    'scroll extent may cause errors',
              ),
            );
          }
        }
      }
    }

    // Detect broad Provider.of / context.watch usage without scoping.
    if (_contextReadWatch.hasMatch(content) &&
        !_consumerScopingPattern.hasMatch(content)) {
      findings.add(
        _DetectedIssue(
          lineNumber: 1,
          description:
              'Provider/context.watch used without Consumer/Selector '
              'scoping — may cause unnecessary widget rebuilds',
        ),
      );
    }

    return _buildResult(
      screen: screen,
      category: ChecklistCategory.performance,
      state: state,
      findings: findings,
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────

  /// Converts detected issues into a [CategoryResult], emitting findings
  /// for FAIL and recording PASS when no issues are found.
  ///
  /// Invariants enforced:
  /// - FAIL → ≥1 Finding emitted (Req 3.8)
  /// - N/A → reason present (Req 3.7) — handled at call site
  /// - PASS → no findings for this category+state
  CategoryResult _buildResult({
    required ScreenRef screen,
    required ChecklistCategory category,
    required ScreenState state,
    required List<_DetectedIssue> findings,
  }) {
    if (findings.isEmpty) {
      return CategoryResult(category: category, status: CategoryStatus.pass);
    }

    // FAIL: emit ≥1 Finding per Req 3.8.
    for (final issue in findings) {
      _recorder.record(
        screen: screen,
        category: category,
        severity: _classifySeverity(category, issue),
        description: '[${state.name}] ${issue.description}',
        fileLine: '${screen.filePath}:${issue.lineNumber}',
      );
    }

    return CategoryResult(category: category, status: CategoryStatus.fail);
  }

  /// Assigns a default severity based on category and issue type.
  ///
  /// Maps to existing `audit_rules.json` priority ladder:
  /// - Layout/overflow → High (P1) — can break UX
  /// - Hardcoded values → Medium (P2) — maintainability
  /// - Responsiveness → High (P1) — affects usability per platform
  /// - UI/UX correctness → Medium (P2) to High (P1) for accessibility
  /// - Performance → Low (P3) to Medium (P2) for nested ListViews
  Severity _classifySeverity(ChecklistCategory category, _DetectedIssue issue) {
    return switch (category) {
      ChecklistCategory.layoutAndOverflow => Severity.high,
      ChecklistCategory.hardcodedValues => Severity.medium,
      ChecklistCategory.responsivenessAndPlatformCoverage => Severity.high,
      ChecklistCategory.uiUxCorrectness =>
        issue.description.contains('accessibility')
            ? Severity.high
            : Severity.medium,
      ChecklistCategory.performance =>
        issue.description.contains('Nested ListView')
            ? Severity.medium
            : Severity.low,
    };
  }
}

/// Internal representation of a detected issue before it becomes a Finding.
class _DetectedIssue {
  /// Line number where the issue was detected (1-based).
  final int lineNumber;

  /// Human-readable description of the issue.
  final String description;

  const _DetectedIssue({required this.lineNumber, required this.description});
}
