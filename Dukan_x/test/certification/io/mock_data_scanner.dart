/// Mock Data Scanner for the Certification_System.
///
/// Scans 100% of a Release_Build's source modules, bundled assets, and
/// configuration files within a 300-second timeout. Classifies hardcoded
/// samples, stubbed responses, in-memory fakes, fixtures, and placeholder
/// credentials as Mock_Data. Creates one release-blocking defect per
/// occurrence. Scan failure results in a no-go decision.
///
/// The scanner does NOT flag the test tree — only the build's source modules,
/// assets, and config are scanned.
///
/// Requirements: 15.1, 15.2, 15.5, 15.6
library;

import 'dart:io';

import '../core/defect.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// Classification of mock data found in a Release_Build.
enum MockDataKind {
  /// Hardcoded sample records (e.g., hardcoded product lists, demo data).
  hardcodedSample,

  /// Stubbed service responses (e.g., canned API responses).
  stubbedResponse,

  /// In-memory fake repositories or services.
  inMemoryFake,

  /// Fixture datasets embedded in non-test code.
  fixture,

  /// Placeholder credentials (e.g., password123, test@test.com, api_key_xxx).
  placeholderCredential,
}

/// A single occurrence of mock data detected in the build.
class MockDataOccurrence {
  /// Path to the source file where mock data was detected.
  final String sourcePath;

  /// The classification of the detected mock data.
  final MockDataKind kind;

  /// The matched text or pattern that triggered detection.
  final String indicator;

  /// The line number where the occurrence was found (1-based).
  final int lineNumber;

  const MockDataOccurrence({
    required this.sourcePath,
    required this.kind,
    required this.indicator,
    required this.lineNumber,
  });
}

/// Result of scanning a Release_Build for mock data.
class MockScanResult {
  /// True if zero mock data occurrences were found.
  final bool clean;

  /// All detected mock data occurrences.
  final List<MockDataOccurrence> occurrences;

  /// One release-blocking defect per occurrence.
  final List<Defect> defects;

  /// How long the scan took.
  final Duration scanDuration;

  /// False if the scan failed or timed out (Req 15.6).
  final bool scanCompleted;

  /// Error message if scanCompleted is false; null otherwise.
  final String? errorMessage;

  const MockScanResult({
    required this.clean,
    required this.occurrences,
    required this.defects,
    required this.scanDuration,
    required this.scanCompleted,
    this.errorMessage,
  });

  /// Convenience factory for a scan failure result.
  factory MockScanResult.failure({
    required Duration scanDuration,
    required String errorMessage,
  }) {
    return MockScanResult(
      clean: false,
      occurrences: const [],
      defects: [
        Defect(
          id: 'DEF-MOCK-SCAN-FAILURE',
          severity: Severity.critical,
          reproSteps: ['Run mock data scan on Release_Build', errorMessage],
          status: ResolutionStatus.open,
          category: GapCategory.dataIntegrity,
        ),
      ],
      scanDuration: scanDuration,
      scanCompleted: false,
      errorMessage: errorMessage,
    );
  }
}

/// Describes a Release_Build to be scanned.
class BuildArtifact {
  /// Root path of the Release_Build.
  final String rootPath;

  /// Paths to source modules to scan (relative to rootPath).
  final List<String> sourceModules;

  /// Paths to bundled assets to scan (relative to rootPath).
  final List<String> assets;

  /// Paths to configuration files to scan (relative to rootPath).
  final List<String> configFiles;

  const BuildArtifact({
    required this.rootPath,
    required this.sourceModules,
    required this.assets,
    required this.configFiles,
  });

  /// Returns all scannable paths (source modules + assets + config).
  List<String> get allPaths => [...sourceModules, ...assets, ...configFiles];
}

// ---------------------------------------------------------------------------
// Detection patterns
// ---------------------------------------------------------------------------

/// A detection rule matching a specific kind of mock data.
class _DetectionRule {
  final MockDataKind kind;
  final RegExp pattern;
  final String description;

  const _DetectionRule({
    required this.kind,
    required this.pattern,
    required this.description,
  });
}

// ---------------------------------------------------------------------------
// MockDataScanner implementation
// ---------------------------------------------------------------------------

/// Scans 100% of a Release_Build's source modules, assets, and config
/// within 300s timeout for mock data indicators.
///
/// Classification covers:
/// - Hardcoded samples (mock/stub/fake keywords in non-test code)
/// - Stubbed responses (canned API response patterns)
/// - In-memory fakes (fake repository/service class patterns)
/// - Fixtures (fixture dataset patterns)
/// - Placeholder credentials (password123, test@test.com, etc.)
///
/// One release-blocking defect is created per occurrence.
/// Scan failure → no-go (scanCompleted = false).
class MockDataScanner {
  /// Detection rules applied to each file.
  static final List<_DetectionRule> _rules = [
    // Hardcoded sample patterns
    _DetectionRule(
      kind: MockDataKind.hardcodedSample,
      pattern: RegExp(
        r'''(?:sample_data|sampleData|demo_data|demoData|hardcoded|HARDCODED|dummy_data|dummyData)''',
        caseSensitive: false,
      ),
      description: 'Hardcoded/sample/demo/dummy data keyword',
    ),
    // Stubbed response patterns
    _DetectionRule(
      kind: MockDataKind.stubbedResponse,
      pattern: RegExp(
        r'''(?:stubbed[_\s]?response|mock[_\s]?response|MockResponse|StubResponse|canned[_\s]?response|fakeResponse|fake[_\s]?response)''',
        caseSensitive: false,
      ),
      description: 'Stubbed/mock/canned/fake response pattern',
    ),
    // In-memory fake patterns (class-level fakes in production code)
    _DetectionRule(
      kind: MockDataKind.inMemoryFake,
      pattern: RegExp(
        r'''(?:class\s+(?:Fake|Mock|Stub)\w+|(?:fake|mock|stub)(?:Repository|Service|Client|Provider|DataSource|Api|Store)\b)''',
        caseSensitive: false,
      ),
      description: 'In-memory fake/mock/stub class or variable',
    ),
    // Fixture patterns
    _DetectionRule(
      kind: MockDataKind.fixture,
      pattern: RegExp(
        r'''(?:fixture[_\s]?data|fixtureData|test[_\s]?fixture|testFixture|seed[_\s]?data|seedData|fixture_records|fixtureRecords)''',
        caseSensitive: false,
      ),
      description: 'Fixture/seed data pattern',
    ),
    // Placeholder credentials
    _DetectionRule(
      kind: MockDataKind.placeholderCredential,
      pattern: RegExp(
        r'''(?:password123|Password123|pass1234|admin123|test@test\.com|test@example\.com|user@test\.com|api_key_test|sk_test_|pk_test_|FAKE_API_KEY|dummy_token|placeholder_secret|test_secret|000000|111111|abc123|qwerty123)''',
        caseSensitive: false,
      ),
      description: 'Placeholder credential or test secret',
    ),
    // Mock/Stub/Fake keyword usage in production context
    _DetectionRule(
      kind: MockDataKind.hardcodedSample,
      pattern: RegExp(
        r'''\b(?:TODO:\s*replace|FIXME:\s*mock|HACK:\s*fake|TEMP:\s*stub)\b''',
        caseSensitive: false,
      ),
      description: 'TODO/FIXME/HACK/TEMP marker indicating mock data',
    ),
    // Hardcoded API response bodies
    _DetectionRule(
      kind: MockDataKind.stubbedResponse,
      pattern: RegExp(
        r'''(?:hardcoded[_\s]?api|mock[_\s]?api[_\s]?response|stubApi|fakeApi|inMemoryApi)''',
        caseSensitive: false,
      ),
      description: 'Hardcoded/mock API response',
    ),
  ];

  /// Counter for generating unique defect IDs per scan.
  int _defectCounter = 0;

  /// Scans 100% of a Release_Build within the specified timeout.
  ///
  /// Classifies mock data indicators and creates one release-blocking
  /// defect per occurrence. Scan failure → no-go (scanCompleted = false).
  ///
  /// [build] describes the Release_Build to scan.
  /// [timeout] is the maximum scan duration (defaults to 300s per Req 15.1).
  Future<MockScanResult> scan(
    BuildArtifact build, {
    Duration timeout = const Duration(seconds: 300),
  }) async {
    _defectCounter = 0;
    final stopwatch = Stopwatch()..start();

    try {
      final rootDir = Directory(build.rootPath);
      if (!rootDir.existsSync()) {
        stopwatch.stop();
        return MockScanResult.failure(
          scanDuration: stopwatch.elapsed,
          errorMessage: 'Build root path does not exist: ${build.rootPath}',
        );
      }

      final occurrences = <MockDataOccurrence>[];
      final defects = <Defect>[];
      final allPaths = build.allPaths;

      // Scan each file in the build artifact.
      for (final relativePath in allPaths) {
        // Check timeout before processing each file.
        if (stopwatch.elapsed >= timeout) {
          stopwatch.stop();
          return MockScanResult.failure(
            scanDuration: stopwatch.elapsed,
            errorMessage:
                'Scan timed out after ${timeout.inSeconds}s '
                '(processed ${allPaths.indexOf(relativePath)} '
                'of ${allPaths.length} files)',
          );
        }

        final fullPath = _resolvePath(build.rootPath, relativePath);
        final file = File(fullPath);

        if (!file.existsSync()) {
          // Record a scan failure defect for inaccessible files (Req 15.6).
          defects.add(
            _createScanFailureDefect(
              relativePath,
              'File not accessible: $relativePath',
            ),
          );
          continue;
        }

        try {
          final content = file.readAsStringSync();
          final lines = content.split('\n');

          // Apply detection rules to each line.
          for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
            final line = lines[lineIndex];

            // Skip comment-only lines that reference test documentation
            // (not actual mock data usage).
            if (_isDocumentationComment(line)) continue;

            for (final rule in _rules) {
              final matches = rule.pattern.allMatches(line);
              for (final match in matches) {
                final occurrence = MockDataOccurrence(
                  sourcePath: relativePath,
                  kind: rule.kind,
                  indicator: match.group(0)!,
                  lineNumber: lineIndex + 1,
                );
                occurrences.add(occurrence);
                defects.add(_createOccurrenceDefect(occurrence));
              }
            }
          }
        } catch (e) {
          // Req 15.6: scan failure for unreadable file.
          defects.add(
            _createScanFailureDefect(
              relativePath,
              'Failed to read file: $relativePath ($e)',
            ),
          );
        }
      }

      stopwatch.stop();
      return MockScanResult(
        clean: occurrences.isEmpty,
        occurrences: occurrences,
        defects: defects,
        scanDuration: stopwatch.elapsed,
        scanCompleted: true,
      );
    } catch (e) {
      // Catch-all for unexpected scan failures (Req 15.6).
      stopwatch.stop();
      return MockScanResult.failure(
        scanDuration: stopwatch.elapsed,
        errorMessage: 'Unexpected scan failure: $e',
      );
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────

  /// Resolves a relative path against the build root.
  String _resolvePath(String rootPath, String relativePath) {
    // Normalize separators.
    final normalizedRoot = rootPath.replaceAll('\\', '/');
    final normalizedRelative = relativePath.replaceAll('\\', '/');

    if (normalizedRelative.startsWith('/') ||
        normalizedRelative.contains(':')) {
      // Already absolute.
      return normalizedRelative;
    }
    return '$normalizedRoot/$normalizedRelative';
  }

  /// Determines if a line is purely a documentation comment (not code).
  ///
  /// Lines that are just `///` or `//` doc comments referencing testing
  /// methodology are not flagged — only actual mock data usage in code.
  bool _isDocumentationComment(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('///') || trimmed.startsWith('//');
  }

  /// Creates a release-blocking defect for a single mock data occurrence.
  Defect _createOccurrenceDefect(MockDataOccurrence occurrence) {
    _defectCounter++;
    return Defect(
      id: 'DEF-MOCK-${_defectCounter.toString().padLeft(4, '0')}',
      severity: Severity.critical,
      reproSteps: [
        'Scan Release_Build for mock data',
        'Found ${occurrence.kind.name} at '
            '${occurrence.sourcePath}:${occurrence.lineNumber}',
        'Indicator: "${occurrence.indicator}"',
      ],
      status: ResolutionStatus.open,
      category: GapCategory.dataIntegrity,
    );
  }

  /// Creates a release-blocking defect for a scan failure on a file.
  Defect _createScanFailureDefect(String path, String reason) {
    _defectCounter++;
    return Defect(
      id: 'DEF-MOCK-FAIL-${_defectCounter.toString().padLeft(4, '0')}',
      severity: Severity.critical,
      reproSteps: ['Attempt to scan file in Release_Build', reason],
      status: ResolutionStatus.open,
      category: GapCategory.dataIntegrity,
    );
  }
}
