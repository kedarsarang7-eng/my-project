/// Bug Condition Exploration Test - Property 1
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**
///
/// This test runs `flutter analyze` scoped to Dukan_x only, parses the output,
/// filters to in-scope diagnostics (excluding generated files and ignored codes),
/// and asserts the in-scope diagnostic count is zero.
///
/// On UNFIXED code this test is EXPECTED TO FAIL — the failure confirms the bug
/// exists. The counterexample set IS the categorized baseline of diagnostics.
///
/// Property: For all source files F in Dukan_x where isBugCondition(F) is true,
/// the fixed tree SHALL cause flutter analyze to report zero in-scope diagnostics.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Represents a single diagnostic from flutter analyze output.
class AnalyzeDiagnostic {
  final String severity; // error, warning, info
  final String code; // diagnostic code / lint rule
  final String file; // relative file path (forward slashes)
  final int line;
  final int column;
  final String message;

  AnalyzeDiagnostic({
    required this.severity,
    required this.code,
    required this.file,
    required this.line,
    required this.column,
    required this.message,
  });

  /// Extract vertical name from file path (e.g., "academic_coaching" from
  /// "lib/features/academic_coaching/presentation/screens/foo.dart")
  String? get vertical {
    final match = RegExp(r'lib/features/([^/]+)').firstMatch(file);
    return match?.group(1);
  }

  @override
  String toString() => '[$severity] $file:$line:$column • $code • $message';
}

/// Globs from analysis_options.yaml analyzer.exclude
const List<String> excludePatterns = [
  r'**/*.g.dart',
  r'**/*.freezed.dart',
  r'**/*.mocks.dart',
  r'build/**',
  r'.dart_tool/**',
  r'scripts/**',
  r'tool/**',
  r'test/**',
  r'backend/**',
  r'functions/**',
  r'integration_test/**',
  r'_archive/**',
];

/// Codes mapped to `ignore` in analysis_options.yaml analyzer.errors
const Set<String> ignoredCodes = {
  'use_build_context_synchronously',
  'deprecated_member_use',
  'deprecated_member_use_from_same_package',
  'unawaited_futures',
  'unused_import',
  'unused_field',
  'unused_local_variable',
  'unused_element',
  'unnecessary_cast',
  'unnecessary_underscores',
  'dead_null_aware_expression',
  'curly_braces_in_flow_control_structures',
  'const_eval_method_invocation',
};

/// Check if a file path matches any of the exclude glob patterns.
bool isExcludedFile(String relativePath) {
  // Normalize path separators to forward slashes
  final normalized = relativePath.replaceAll(r'\', '/');

  for (final pattern in excludePatterns) {
    if (_matchGlob(pattern, normalized)) return true;
  }
  return false;
}

/// Simple glob matcher supporting ** and * patterns.
bool _matchGlob(String pattern, String path) {
  // Handle **/*.ext patterns (match anywhere in path)
  if (pattern.startsWith('**/')) {
    final suffix = pattern.substring(3); // e.g., "*.g.dart"
    if (suffix.startsWith('*')) {
      // Pattern like **/*.g.dart — match file ending
      final ext = suffix.substring(1); // e.g., ".g.dart"
      return path.endsWith(ext);
    }
    // Pattern like **/something — match path segment
    return path.contains(suffix) || path.endsWith(suffix);
  }

  // Handle dir/** patterns (match everything under directory)
  if (pattern.endsWith('/**')) {
    final prefix = pattern.substring(0, pattern.length - 3);
    return path.startsWith('$prefix/') || path == prefix;
  }

  // Direct match
  return path == pattern;
}

/// Parse flutter analyze output into diagnostics.
///
/// Flutter analyze outputs lines in the format:
///   severity - message - file:line:column - code
///
/// Example:
///   error - The method 'foo' isn't defined... - lib\core\file.dart:40:18 - undefined_method
///   warning - Close instances of 'Sink' - lib\services\s.dart:12:5 - close_sinks
///   info - Avoid unnecessary containers - lib\widgets\w.dart:8:3 - avoid_unnecessary_containers
List<AnalyzeDiagnostic> parseAnalyzeOutput(String output) {
  final diagnostics = <AnalyzeDiagnostic>[];
  final lines = const LineSplitter().convert(output);

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // Split on " - " separator. The format is:
    //   severity - message - file:line:column - code
    // Message can itself contain " - ", so we parse from both ends.
    final parts = trimmed.split(' - ');
    if (parts.length < 4) continue;

    final severity = parts[0].trim().toLowerCase();
    if (severity != 'error' && severity != 'warning' && severity != 'info') {
      continue;
    }

    // Last part is the diagnostic code
    final code = parts.last.trim();
    // Second-to-last is file:line:column
    final fileLocator = parts[parts.length - 2].trim();
    // Everything between first and second-to-last is the message
    final message = parts.sublist(1, parts.length - 2).join(' - ').trim();

    // Parse file:line:column — Windows uses backslashes in paths
    final locMatch = RegExp(r'^(.+):(\d+):(\d+)$').firstMatch(fileLocator);
    if (locMatch == null) continue;

    diagnostics.add(
      AnalyzeDiagnostic(
        severity: severity,
        message: message,
        file: locMatch.group(1)!.replaceAll(r'\', '/'),
        line: int.parse(locMatch.group(2)!),
        column: int.parse(locMatch.group(3)!),
        code: code,
      ),
    );
  }

  return diagnostics;
}

/// Filter diagnostics to only in-scope ones (not excluded, not ignored).
List<AnalyzeDiagnostic> filterInScope(List<AnalyzeDiagnostic> diagnostics) {
  return diagnostics.where((d) {
    // Exclude files matching analyzer.exclude globs
    if (isExcludedFile(d.file)) return false;
    // Exclude codes mapped to ignore
    if (ignoredCodes.contains(d.code)) return false;
    return true;
  }).toList();
}

/// Generate a categorized summary report.
String generateReport(List<AnalyzeDiagnostic> inScope) {
  final buffer = StringBuffer();
  buffer.writeln('=' * 80);
  buffer.writeln(
    'FLUTTER ANALYZE BUG CONDITION EXPLORATION — CATEGORIZED BASELINE',
  );
  buffer.writeln('=' * 80);
  buffer.writeln();

  // --- Total count ---
  buffer.writeln('TOTAL IN-SCOPE DIAGNOSTICS: ${inScope.length}');
  buffer.writeln();

  // --- Severity distribution ---
  final bySeverity = <String, List<AnalyzeDiagnostic>>{};
  for (final d in inScope) {
    bySeverity.putIfAbsent(d.severity, () => []).add(d);
  }
  buffer.writeln('SEVERITY DISTRIBUTION:');
  for (final sev in ['error', 'warning', 'info']) {
    final count = bySeverity[sev]?.length ?? 0;
    buffer.writeln('  $sev: $count');
  }
  buffer.writeln();

  // --- By diagnostic code / lint rule ---
  final byCode = <String, int>{};
  for (final d in inScope) {
    byCode[d.code] = (byCode[d.code] ?? 0) + 1;
  }
  final sortedCodes = byCode.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  buffer.writeln('TOP DIAGNOSTIC CODES (sorted by count):');
  for (final entry in sortedCodes.take(30)) {
    final sev = inScope.firstWhere((d) => d.code == entry.key).severity;
    buffer.writeln('  ${entry.key} [$sev]: ${entry.value}');
  }
  if (sortedCodes.length > 30) {
    buffer.writeln('  ... and ${sortedCodes.length - 30} more codes');
  }
  buffer.writeln();

  // --- Per-vertical hot-spots ---
  final byVertical = <String, int>{};
  for (final d in inScope) {
    final v = d.vertical ?? '_other';
    byVertical[v] = (byVertical[v] ?? 0) + 1;
  }
  final sortedVerticals = byVertical.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  buffer.writeln('PER-VERTICAL HOT-SPOTS (sorted by count):');
  for (final entry in sortedVerticals.take(25)) {
    buffer.writeln('  ${entry.key}: ${entry.value}');
  }
  if (sortedVerticals.length > 25) {
    buffer.writeln('  ... and ${sortedVerticals.length - 25} more verticals');
  }
  buffer.writeln();

  // --- Per-file counts (top offenders) ---
  final byFile = <String, int>{};
  for (final d in inScope) {
    byFile[d.file] = (byFile[d.file] ?? 0) + 1;
  }
  final sortedFiles = byFile.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  buffer.writeln('TOP 20 FILES BY DIAGNOSTIC COUNT:');
  for (final entry in sortedFiles.take(20)) {
    buffer.writeln('  ${entry.key}: ${entry.value}');
  }
  buffer.writeln();

  // --- Prioritized worklist ---
  buffer.writeln('PRIORITIZED WORKLIST (errors → warnings → info):');
  buffer.writeln('  1. ERRORS (${bySeverity['error']?.length ?? 0} issues):');
  final errorCodes = <String, int>{};
  for (final d in bySeverity['error'] ?? <AnalyzeDiagnostic>[]) {
    errorCodes[d.code] = (errorCodes[d.code] ?? 0) + 1;
  }
  for (final e
      in (errorCodes.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(10)) {
    buffer.writeln('     ${e.key}: ${e.value}');
  }

  buffer.writeln(
    '  2. WARNINGS (${bySeverity['warning']?.length ?? 0} issues):',
  );
  final warnCodes = <String, int>{};
  for (final d in bySeverity['warning'] ?? <AnalyzeDiagnostic>[]) {
    warnCodes[d.code] = (warnCodes[d.code] ?? 0) + 1;
  }
  for (final e
      in (warnCodes.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(10)) {
    buffer.writeln('     ${e.key}: ${e.value}');
  }

  buffer.writeln('  3. INFO (${bySeverity['info']?.length ?? 0} issues):');
  final infoCodes = <String, int>{};
  for (final d in bySeverity['info'] ?? <AnalyzeDiagnostic>[]) {
    infoCodes[d.code] = (infoCodes[d.code] ?? 0) + 1;
  }
  for (final e
      in (infoCodes.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(10)) {
    buffer.writeln('     ${e.key}: ${e.value}');
  }

  buffer.writeln();
  buffer.writeln('=' * 80);
  return buffer.toString();
}

void main() {
  group('Bug Condition Exploration - Property 1', () {
    test(
      'In-scope diagnostics are eliminated (isBugCondition(F) is false for all F)',
      () async {
        // Run flutter analyze scoped to Dukan_x only (cwd is Dukan_x)
        final result = await Process.run(
          'flutter',
          ['analyze', '--no-fatal-infos', '--no-fatal-warnings'],
          workingDirectory: Directory.current.path,
          runInShell: true,
        );

        final output = '${result.stdout}\n${result.stderr}';

        // Parse all diagnostics from the output
        final allDiagnostics = parseAnalyzeOutput(output);

        // Filter to in-scope diagnostics only
        final inScope = filterInScope(allDiagnostics);

        // Generate and print the categorized report
        final report = generateReport(inScope);
        // ignore: avoid_print
        print(report);

        // Save baseline report to a file for reference
        final baselineFile = File('test/bug_condition/baseline_report.txt');
        await baselineFile.writeAsString(report);

        // THE PROPERTY ASSERTION:
        // In-scope diagnostic count MUST be zero.
        // On unfixed code this WILL FAIL — that failure IS the counterexample
        // proving the bug exists.
        expect(
          inScope.length,
          equals(0),
          reason:
              'Bug Condition Property: Expected zero in-scope diagnostics '
              'from flutter analyze, but found ${inScope.length}. '
              'This confirms isBugCondition(F) is true for at least one file. '
              'See baseline_report.txt for the categorized counterexample set.',
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
