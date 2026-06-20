/// Mock Data Eliminator — maps detected mock data usages to real API endpoints
/// or local database queries, flags unresolved occurrences, verifies empty-state
/// widgets, and provides CI assertions for mock-data-free enforcement.
///
/// Requirements: 6.2, 6.3, 6.4, 6.5
library;

import 'dart:io';

/// Represents a mapping between a mock data usage and its real data source.
class MockMapping {
  /// The detected mock data pattern (e.g., hardcoded array, inline literal).
  final String mockUsage;

  /// The real API endpoint or local DB query that should replace the mock.
  /// Null if no real source could be identified.
  final String? realEndpoint;

  /// Whether this mock usage was successfully mapped to a real source.
  final bool resolved;

  /// The screen file where the mock data was detected.
  final String screenFile;

  /// The line number where the mock data occurs.
  final int lineNumber;

  /// Optional description of why mapping failed (for unresolved items).
  final String? unresolvedReason;

  const MockMapping({
    required this.mockUsage,
    this.realEndpoint,
    required this.resolved,
    required this.screenFile,
    required this.lineNumber,
    this.unresolvedReason,
  });

  @override
  String toString() => resolved
      ? 'MockMapping($screenFile:$lineNumber → $realEndpoint)'
      : 'MockMapping($screenFile:$lineNumber → UNRESOLVED: $unresolvedReason)';
}

/// Result from verifying empty-state widget rendering.
class EmptyStateResult {
  /// Whether the screen has a proper empty-state widget.
  final bool hasEmptyState;

  /// The empty-state message found (if any).
  final String? message;

  /// Details about the verification.
  final String details;

  const EmptyStateResult({
    required this.hasEmptyState,
    this.message,
    required this.details,
  });
}

/// Result from CI mock pattern detection.
class CiMockViolation {
  /// File path where the violation was found.
  final String filePath;

  /// Line number of the violation.
  final int lineNumber;

  /// The pattern that was detected.
  final String pattern;

  /// Description of the violation.
  final String description;

  const CiMockViolation({
    required this.filePath,
    required this.lineNumber,
    required this.pattern,
    required this.description,
  });

  @override
  String toString() => '$filePath:$lineNumber — $description ($pattern)';
}

/// Engine that eliminates mock data by mapping usages to real data sources.
class MockEliminator {
  /// Directories excluded from CI mock checks (test directories).
  static const List<String> _excludedDirectories = [
    'test',
    'test_driver',
    'integration_test',
    'mocks',
  ];

  /// File suffixes excluded from CI mock checks.
  static const List<String> _excludedSuffixes = [
    '_test.dart',
    '_mock.dart',
    '_fake.dart',
  ];

  /// Maps each detected mock data usage in a screen file to the corresponding
  /// real API endpoint or local database query.
  ///
  /// For each mock pattern found in [content], attempts to identify the
  /// matching endpoint from [availableEndpoints] based on the screen's
  /// entity type (derived from file path and variable names).
  ///
  /// Requirements: 6.2
  List<MockMapping> mapMockToRealSource(
    String screenPath,
    String content,
    List<String> availableEndpoints,
  ) {
    final mappings = <MockMapping>[];
    final lines = content.split('\n');
    final entityType = _deriveEntityType(screenPath, content);

    // Detect all mock patterns with their line numbers
    final mockOccurrences = _findMockOccurrences(lines);

    for (final occurrence in mockOccurrences) {
      final endpoint = _findMatchingEndpoint(
        entityType,
        occurrence.pattern,
        availableEndpoints,
        content,
      );

      if (endpoint != null) {
        mappings.add(
          MockMapping(
            mockUsage: occurrence.pattern,
            realEndpoint: endpoint,
            resolved: true,
            screenFile: screenPath,
            lineNumber: occurrence.lineNumber,
          ),
        );
      } else {
        mappings.add(
          MockMapping(
            mockUsage: occurrence.pattern,
            realEndpoint: null,
            resolved: false,
            screenFile: screenPath,
            lineNumber: occurrence.lineNumber,
            unresolvedReason:
                'No matching endpoint found for entity type "$entityType"',
          ),
        );
      }
    }

    return mappings;
  }

  /// Returns all unresolved mappings that could not be matched to a real source.
  ///
  /// These require manual specification of a real data source before
  /// replacement can proceed.
  ///
  /// Requirements: 6.3
  List<String> findUnresolved(List<MockMapping> mappings) {
    return mappings
        .where((m) => !m.resolved)
        .map(
          (m) =>
              '${m.screenFile}:${m.lineNumber} — ${m.mockUsage} '
              '(${m.unresolvedReason ?? "no real source identified"})',
        )
        .toList();
  }

  /// Verifies that a screen renders an empty-state widget with a
  /// "no data available" message when the real data source returns zero records.
  ///
  /// Checks for common empty-state patterns:
  /// - Widget with "no data" / "empty" / "no records" text
  /// - Conditional rendering based on empty list/null check
  /// - EmptyStateWidget or similar named widgets
  ///
  /// Requirements: 6.4
  bool verifyEmptyState(String content) {
    return _checkEmptyState(content).hasEmptyState;
  }

  /// Extended empty-state verification returning detailed result.
  EmptyStateResult verifyEmptyStateDetailed(String content) {
    return _checkEmptyState(content);
  }

  /// Detects new mock data patterns in non-test code files.
  ///
  /// Used by CI pipeline to fail builds when mock data is introduced
  /// in production code. Only checks files NOT in excluded directories
  /// (test, test_*, mocks) and NOT matching excluded suffixes (_test.dart).
  ///
  /// Requirements: 6.5
  List<String> detectNewMockPatterns(String filePath, String content) {
    // Skip excluded files
    if (_isExcludedFromCi(filePath)) {
      return [];
    }

    final violations = <String>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      // Check hardcoded arrays with 2+ literal entries
      if (_isHardcodedArray(line, lines, i)) {
        violations.add(
          '$filePath:$lineNumber — Hardcoded data array detected '
          '(use API endpoint or database query instead)',
        );
      }

      // Check TODO/placeholder comments indicating fake data
      if (_isTodoPlaceholder(line)) {
        violations.add(
          '$filePath:$lineNumber — TODO/placeholder comment '
          'indicating mock data: "${line.trim()}"',
        );
      }

      // Check imports from mock/dummy/fake/sample paths
      if (_isMockImport(line)) {
        violations.add(
          '$filePath:$lineNumber — Import from mock/dummy/fake/sample path '
          'in production code: "${line.trim()}"',
        );
      }

      // Check inline literal data returns
      if (_isInlineLiteralReturn(line)) {
        violations.add(
          '$filePath:$lineNumber — Inline literal data return detected '
          '(should use repository/API call)',
        );
      }
    }

    return violations;
  }

  /// Runs CI assertion across all Dart files in a project directory.
  /// Returns a list of violations that should fail the pipeline.
  Future<List<CiMockViolation>> runCiAssertion(String projectRoot) async {
    final violations = <CiMockViolation>[];
    final libDir = Directory('$projectRoot/lib');

    if (!await libDir.exists()) {
      return violations;
    }

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final filePath = entity.path.replaceAll('\\', '/');

      if (_isExcludedFromCi(filePath)) continue;

      final content = await entity.readAsString();
      final fileViolations = _detectViolationsDetailed(filePath, content);
      violations.addAll(fileViolations);
    }

    return violations;
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  /// Derives the entity type from the screen path and content.
  ///
  /// Examines:
  /// 1. File name pattern (e.g., "student_list_screen" → "student")
  /// 2. Feature folder name (e.g., "features/restaurant/" → "restaurant")
  /// 3. Class/variable names in content for entity clues
  String _deriveEntityType(String screenPath, String content) {
    final normalized = screenPath.replaceAll('\\', '/');
    final fileName = normalized.split('/').last.replaceAll('.dart', '');

    // Remove common suffixes to get entity
    final entityFromFile = fileName
        .replaceAll('_screen', '')
        .replaceAll('_page', '')
        .replaceAll('_list', '')
        .replaceAll('_detail', '')
        .replaceAll('_management', '')
        .replaceAll('_creation', '')
        .replaceAll('_edit', '');

    // Try to extract from feature folder
    final featurePattern = RegExp(r'features/([^/]+)/');
    final featureMatch = featurePattern.firstMatch(normalized);
    final featureFolder = featureMatch?.group(1);

    // Look for repository/model references in content
    final repoPattern = RegExp(r'(\w+)Repository');
    final repoMatch = repoPattern.firstMatch(content);
    final repoEntity = repoMatch?.group(1)?.toLowerCase();

    // Priority: repo reference > file name > feature folder
    if (repoEntity != null && repoEntity.isNotEmpty) {
      return repoEntity;
    }

    if (entityFromFile.isNotEmpty && entityFromFile != fileName) {
      return entityFromFile;
    }

    return featureFolder ?? 'unknown';
  }

  /// Finds all mock data occurrences in file lines with their line numbers.
  List<_MockOccurrence> _findMockOccurrences(List<String> lines) {
    final occurrences = <_MockOccurrence>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      // Hardcoded arrays
      if (_isHardcodedArray(line, lines, i)) {
        occurrences.add(
          _MockOccurrence(pattern: 'hardcoded_array', lineNumber: lineNumber),
        );
      }

      // TODO/placeholder comments
      if (_isTodoPlaceholder(line)) {
        occurrences.add(
          _MockOccurrence(pattern: 'todo_placeholder', lineNumber: lineNumber),
        );
      }

      // Mock imports
      if (_isMockImport(line)) {
        occurrences.add(
          _MockOccurrence(pattern: 'mock_import', lineNumber: lineNumber),
        );
      }

      // Inline literal returns
      if (_isInlineLiteralReturn(line)) {
        occurrences.add(
          _MockOccurrence(pattern: 'inline_literal', lineNumber: lineNumber),
        );
      }
    }

    return occurrences;
  }

  /// Attempts to find a matching endpoint for a given entity type.
  ///
  /// Matching strategy:
  /// 1. Exact entity match in endpoint path (e.g., "/students" for entity "student")
  /// 2. Pluralized entity match (e.g., "/menu_items" for entity "menu_item")
  /// 3. Feature-prefixed match (e.g., "/ac/students" for "student" in AC feature)
  String? _findMatchingEndpoint(
    String entityType,
    String pattern,
    List<String> availableEndpoints,
    String content,
  ) {
    if (availableEndpoints.isEmpty) return null;

    final entityLower = entityType.toLowerCase();
    final entityPlural = _pluralize(entityLower);

    // Strategy 1: Direct entity match in endpoint path
    for (final endpoint in availableEndpoints) {
      final endpointLower = endpoint.toLowerCase();
      if (endpointLower.contains('/$entityLower') ||
          endpointLower.contains('/$entityPlural') ||
          endpointLower.endsWith('/$entityLower') ||
          endpointLower.endsWith('/$entityPlural')) {
        return endpoint;
      }
    }

    // Strategy 2: Partial match — entity name appears anywhere in endpoint
    for (final endpoint in availableEndpoints) {
      final endpointLower = endpoint.toLowerCase();
      if (endpointLower.contains(entityLower)) {
        return endpoint;
      }
    }

    // Strategy 3: Look for API paths referenced in the same file
    final apiCallPattern = RegExp(r'''['"](/[a-zA-Z0-9/_-]+)['"]''');
    final matches = apiCallPattern.allMatches(content);
    for (final match in matches) {
      final path = match.group(1)!;
      if (availableEndpoints.contains(path)) {
        return path;
      }
    }

    return null;
  }

  /// Simple English pluralization for entity matching.
  String _pluralize(String word) {
    if (word.endsWith('y') && !word.endsWith('ay') && !word.endsWith('ey')) {
      return '${word.substring(0, word.length - 1)}ies';
    }
    if (word.endsWith('s') ||
        word.endsWith('sh') ||
        word.endsWith('ch') ||
        word.endsWith('x')) {
      return '${word}es';
    }
    return '${word}s';
  }

  /// Checks if a line starts a hardcoded data array with 2+ entries.
  bool _isHardcodedArray(String line, List<String> lines, int index) {
    final patterns = [
      RegExp(r'\[\s*\{[^}]+\}\s*,\s*\{'),
      RegExp(r"\[\s*'[^']+',\s*'[^']+'"),
      RegExp(r'\[\s*"[^"]+",\s*"[^"]+"'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(line)) return true;
    }

    // Check multi-line arrays: opening bracket on one line, items on next
    if (line.trimRight().endsWith('[') && index + 2 < lines.length) {
      final nextTwo = '${lines[index + 1]}${lines[index + 2]}';
      for (final pattern in patterns) {
        if (pattern.hasMatch('[$nextTwo')) return true;
      }
    }

    return false;
  }

  /// Checks if a line is a TODO/placeholder comment indicating fake data.
  bool _isTodoPlaceholder(String line) {
    final patterns = [
      RegExp(
        r'//\s*TODO.*(?:fake|mock|dummy|placeholder|sample|hardcode)',
        caseSensitive: false,
      ),
      RegExp(
        r'//\s*FIXME.*(?:fake|mock|dummy|placeholder|sample|hardcode)',
        caseSensitive: false,
      ),
      RegExp(
        r'//\s*HACK.*(?:fake|mock|dummy|placeholder|sample)',
        caseSensitive: false,
      ),
      RegExp(r'//\s*placeholder', caseSensitive: false),
      RegExp(r'//\s*dummy data', caseSensitive: false),
      RegExp(r'//\s*sample data', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  /// Checks if a line imports from a mock/dummy/fake/sample path.
  bool _isMockImport(String line) {
    final patterns = [
      RegExp(r'''import\s+['"].*(?:mock|dummy|fake|sample).*['"]'''),
      RegExp(r'''import\s+['"].*\/mocks\/.*['"]'''),
      RegExp(r'''import\s+['"].*\/mock_.*['"]'''),
      RegExp(r'''import\s+['"].*\/fake_.*['"]'''),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  /// Checks if a line returns inline literal data (static data without API).
  bool _isInlineLiteralReturn(String line) {
    final patterns = [
      RegExp(r'return\s+\[\s*\{'),
      RegExp(r"return\s+\[\s*'"),
      RegExp(r'return\s+\[\s*"'),
      RegExp(r'final\s+\w+\s*=\s*\[\s*\{[^}]+\}\s*,\s*\{'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  /// Checks if a file should be excluded from CI mock assertions.
  bool _isExcludedFromCi(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');

    // Check excluded directories
    for (final dir in _excludedDirectories) {
      if (normalized.contains('/$dir/') || normalized.startsWith('$dir/')) {
        return true;
      }
      // Handle glob patterns like test_*
      if (dir.endsWith('*')) {
        final prefix = dir.substring(0, dir.length - 1);
        final segments = normalized.split('/');
        for (final segment in segments) {
          if (segment.startsWith(prefix)) return true;
        }
      }
    }

    // Check excluded file suffixes
    for (final suffix in _excludedSuffixes) {
      if (normalized.endsWith(suffix)) return true;
    }

    return false;
  }

  /// Verifies empty-state widget presence in screen content.
  EmptyStateResult _checkEmptyState(String content) {
    // Pattern 1: Explicit empty state widgets
    final emptyWidgetPatterns = [
      RegExp(r'EmptyState\w*\(', caseSensitive: false),
      RegExp(r'NoData\w*\(', caseSensitive: false),
      RegExp(r'EmptyView\w*\(', caseSensitive: false),
      RegExp(r'EmptyList\w*\(', caseSensitive: false),
    ];

    for (final pattern in emptyWidgetPatterns) {
      if (pattern.hasMatch(content)) {
        return const EmptyStateResult(
          hasEmptyState: true,
          message: 'Named empty-state widget found',
          details: 'Screen uses a dedicated empty-state widget class',
        );
      }
    }

    // Pattern 2: Text containing "no data" variants
    final noDataTextPatterns = [
      RegExp(r'''['"].*no\s+data\s+available.*['"]''', caseSensitive: false),
      RegExp(r'''['"].*no\s+data.*['"]''', caseSensitive: false),
      RegExp(r'''['"].*no\s+records.*['"]''', caseSensitive: false),
      RegExp(r'''['"].*nothing\s+to\s+show.*['"]''', caseSensitive: false),
      RegExp(r'''['"].*empty.*['"]''', caseSensitive: false),
      RegExp(r'''['"].*no\s+\w+\s+found.*['"]''', caseSensitive: false),
    ];

    // Pattern 3: Conditional rendering on empty list
    final emptyCheckPatterns = [
      RegExp(r'if\s*\(\s*\w+\.isEmpty\s*\)'),
      RegExp(r'\w+\.isEmpty\s*\?\s*'),
      RegExp(r'if\s*\(\s*\w+\s*==\s*null\s*\|\|\s*\w+\.isEmpty\s*\)'),
      RegExp(r'\w+\s*==\s*null\s*\|\|\s*\w+!\.isEmpty'),
      RegExp(r'data\s*==\s*null'),
      RegExp(r'items\s*==\s*null'),
      RegExp(r'\.length\s*==\s*0'),
    ];

    bool hasEmptyCheck = false;
    bool hasNoDataText = false;

    for (final pattern in emptyCheckPatterns) {
      if (pattern.hasMatch(content)) {
        hasEmptyCheck = true;
        break;
      }
    }

    for (final pattern in noDataTextPatterns) {
      if (pattern.hasMatch(content)) {
        hasNoDataText = true;
        break;
      }
    }

    if (hasEmptyCheck && hasNoDataText) {
      return const EmptyStateResult(
        hasEmptyState: true,
        message: 'Conditional empty-state with message found',
        details:
            'Screen checks for empty/null data and displays appropriate message',
      );
    }

    if (hasEmptyCheck) {
      return const EmptyStateResult(
        hasEmptyState: true,
        message: 'Empty check without explicit message text',
        details:
            'Screen checks for empty/null data (message may use widget rather than literal string)',
      );
    }

    if (hasNoDataText) {
      return const EmptyStateResult(
        hasEmptyState: true,
        message: 'No-data text found',
        details:
            'Screen contains empty-state text but explicit empty check not detected',
      );
    }

    return const EmptyStateResult(
      hasEmptyState: false,
      details:
          'No empty-state widget, empty check, or "no data available" message found',
    );
  }

  /// Detects mock violations with detailed reporting for CI.
  List<CiMockViolation> _detectViolationsDetailed(
    String filePath,
    String content,
  ) {
    final violations = <CiMockViolation>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      if (_isHardcodedArray(line, lines, i)) {
        violations.add(
          CiMockViolation(
            filePath: filePath,
            lineNumber: lineNumber,
            pattern: 'hardcoded_array',
            description:
                'Hardcoded data array detected — use API endpoint or database query',
          ),
        );
      }

      if (_isTodoPlaceholder(line)) {
        violations.add(
          CiMockViolation(
            filePath: filePath,
            lineNumber: lineNumber,
            pattern: 'todo_placeholder',
            description: 'TODO/placeholder comment indicating mock data',
          ),
        );
      }

      if (_isMockImport(line)) {
        violations.add(
          CiMockViolation(
            filePath: filePath,
            lineNumber: lineNumber,
            pattern: 'mock_import',
            description:
                'Import from mock/dummy/fake/sample path in production code',
          ),
        );
      }

      if (_isInlineLiteralReturn(line)) {
        violations.add(
          CiMockViolation(
            filePath: filePath,
            lineNumber: lineNumber,
            pattern: 'inline_literal',
            description:
                'Inline literal data return — should use repository/API call',
          ),
        );
      }
    }

    return violations;
  }
}

/// Internal model for a detected mock occurrence with position info.
class _MockOccurrence {
  final String pattern;
  final int lineNumber;

  const _MockOccurrence({required this.pattern, required this.lineNumber});
}
