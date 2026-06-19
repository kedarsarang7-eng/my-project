/// Screen Discovery Engine — scans the Flutter codebase to catalog all
/// screen/page widgets into the Discovery Registry.
///
/// Implements: scan(), classifyFile(), deriveVertical(), detectMockData(),
/// assignPriority().
///
/// Requirements: 1.1, 1.2, 1.6
library;

import 'dart:io';

import '../models/screen_entry.dart';

/// Engine that discovers and classifies screen widgets in a Flutter project.
class ScreenDiscoveryEngine {
  /// Log of skipped false-positive files (match naming but lack valid widget).
  final List<String> skippedFalsePositives = [];

  /// Scans all Dart files under [projectRoot]/lib/ and returns classified
  /// screen entries.
  Future<List<ScreenEntry>> scan(String projectRoot) async {
    final libDir = Directory('$projectRoot/lib');
    if (!await libDir.exists()) {
      return [];
    }

    final entries = <ScreenEntry>[];

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final filePath = entity.path.replaceAll('\\', '/');
      final content = await entity.readAsString();
      final classification = classifyFile(filePath, content);

      if (classification.isFalsePositive) {
        skippedFalsePositives.add(filePath);
        continue;
      }

      if (!classification.isScreen) continue;

      // Build relative path from project root
      final normalizedRoot = projectRoot.replaceAll('\\', '/');
      final relativePath = filePath.startsWith(normalizedRoot)
          ? filePath.substring(normalizedRoot.length + 1)
          : filePath;

      final vertical = deriveVertical(relativePath);
      final fileName = filePath.split('/').last;
      final mockResult = detectMockData(content);

      final entry = ScreenEntry(
        project: 'Dukan_x',
        feature: vertical,
        fileName: fileName,
        relativePath: relativePath,
        businessTypes: vertical,
        mockData: mockResult.hasMockData,
        mockReasons: mockResult.mockReasons,
        apiConnected: false, // Determined by API mapper in later phase
        offlineReady: false, // Determined by offline auditor in later phase
        uiConsistent: false, // Determined by UI auditor in later phase
        navWired: false, // Determined by navigation graph in later phase
        priority: Priority.low, // Will be assigned after all data collected
      );

      entries.add(entry);
    }

    // Assign priorities after all entries are collected
    return entries.map((e) => _withPriority(e)).toList();
  }

  /// Classifies a Dart file as a screen widget or not.
  ///
  /// A file is classified as a screen if:
  /// - The file path or a class name contains "screen" or "page"
  ///   (case-insensitive), AND
  /// - The file contains a class extending StatelessWidget or StatefulWidget.
  ///
  /// Files whose name matches the pattern but lack a valid widget class are
  /// marked as false positives.
  ScreenClassification classifyFile(String filePath, String fileContent) {
    final fileNameLower = filePath.split('/').last.toLowerCase();
    final nameMatchesPattern =
        fileNameLower.contains('screen') || fileNameLower.contains('page');

    // Regex to find class declarations extending StatelessWidget or
    // StatefulWidget
    final classPattern = RegExp(
      r'class\s+(\w+)\s+extends\s+(StatelessWidget|StatefulWidget)',
    );

    final matches = classPattern.allMatches(fileContent).toList();

    if (matches.isEmpty) {
      // No widget class found
      if (nameMatchesPattern) {
        // File name matches but no valid widget — false positive
        return const ScreenClassification(
          isScreen: false,
          isFalsePositive: true,
        );
      }
      return const ScreenClassification(
        isScreen: false,
        isFalsePositive: false,
      );
    }

    // Check if any class name or the filename matches the screen/page pattern
    for (final match in matches) {
      final className = match.group(1)!;
      final widgetType = match.group(2)!;
      final classNameLower = className.toLowerCase();

      if (nameMatchesPattern ||
          classNameLower.contains('screen') ||
          classNameLower.contains('page')) {
        return ScreenClassification(
          isScreen: true,
          className: className,
          widgetType: widgetType,
          isFalsePositive: false,
        );
      }
    }

    // Widget classes exist but none match screen/page naming
    if (nameMatchesPattern) {
      // File name matches pattern but no class names do — still valid if
      // it has widget classes (the file IS named as a screen)
      final firstMatch = matches.first;
      return ScreenClassification(
        isScreen: true,
        className: firstMatch.group(1)!,
        widgetType: firstMatch.group(2)!,
        isFalsePositive: false,
      );
    }

    return const ScreenClassification(isScreen: false, isFalsePositive: false);
  }

  /// Derives the vertical (feature/business type) from a relative file path.
  ///
  /// For paths matching `lib/features/<folder>/...`, returns `<folder>`.
  /// For all other paths, returns "core/general".
  String deriveVertical(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');

    // Match lib/features/<folder>/...
    final pattern = RegExp(r'lib/features/([^/]+)/');
    final match = pattern.firstMatch(normalized);

    if (match != null) {
      return match.group(1)!;
    }

    return 'core/general';
  }

  /// Detects mock data patterns in file content.
  ///
  /// Checks for:
  /// 1. Hardcoded sample data arrays with 2+ literal entries
  /// 2. TODO/placeholder comments indicating fake data
  /// 3. Imports from paths containing "mock"/"dummy"/"fake"/"sample"
  /// 4. Conditional logic returning inline literal data without API calls
  MockDetectionResult detectMockData(String fileContent) {
    final detectedPatterns = <String>[];

    // 1. Hardcoded sample data arrays with 2+ literal entries
    final hardcodedArrayPatterns = [
      RegExp(r'\[\s*\{[^}]+\}\s*,\s*\{'), // [{...}, {
      RegExp(r"\[\s*'[^']+',\s*'[^']+'"), // ['...', '...'
      RegExp(r'\[\s*"[^"]+",\s*"[^"]+"'), // ["...", "..."
    ];
    for (final pattern in hardcodedArrayPatterns) {
      if (pattern.hasMatch(fileContent)) {
        detectedPatterns.add('hardcoded_array');
        break;
      }
    }

    // 2. TODO/placeholder comments indicating fake data
    final todoPatterns = [
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
    for (final pattern in todoPatterns) {
      if (pattern.hasMatch(fileContent)) {
        detectedPatterns.add('todo_placeholder');
        break;
      }
    }

    // 3. Imports from paths containing "mock"/"dummy"/"fake"/"sample"
    final mockImportPatterns = [
      RegExp(r'''import\s+['"].*(?:mock|dummy|fake|sample).*['"]'''),
      RegExp(r'''import\s+['"].*\/mocks\/.*['"]'''),
      RegExp(r'''import\s+['"].*\/mock_.*['"]'''),
      RegExp(r'''import\s+['"].*\/fake_.*['"]'''),
    ];
    for (final pattern in mockImportPatterns) {
      if (pattern.hasMatch(fileContent)) {
        detectedPatterns.add('mock_import');
        break;
      }
    }

    // 4. Inline literal data returns (conditional logic returning static data)
    final inlineLiteralPatterns = [
      RegExp(r'return\s+\[\s*\{'),
      RegExp(r"return\s+\[\s*'"),
      RegExp(r'return\s+\[\s*"'),
      RegExp(r'final\s+\w+\s*=\s*\[\s*\{[^}]+\}\s*,\s*\{'),
    ];
    for (final pattern in inlineLiteralPatterns) {
      if (pattern.hasMatch(fileContent)) {
        detectedPatterns.add('inline_literal');
        break;
      }
    }

    if (detectedPatterns.isEmpty) {
      return MockDetectionResult.none;
    }

    return MockDetectionResult(
      hasMockData: true,
      mockReasons: detectedPatterns.join(','),
    );
  }

  /// Assigns priority based on screen characteristics.
  ///
  /// - High: Dashboard or entry-point screens (name contains "dashboard",
  ///   "home", or "main").
  /// - Medium: Standard feature screens with navigation wired.
  /// - Low: Secondary/utility screens or screens lacking navigation.
  Priority assignPriority(ScreenEntry entry) {
    final fileNameLower = entry.fileName.toLowerCase();

    // High priority: dashboards and entry-points
    if (fileNameLower.contains('dashboard') ||
        fileNameLower.contains('home') ||
        fileNameLower.contains('main')) {
      return Priority.high;
    }

    // Medium priority: standard feature screens with navigation wired
    if (entry.navWired) {
      return Priority.medium;
    }

    // Low priority: everything else
    return Priority.low;
  }

  /// Returns a copy of [entry] with priority assigned.
  ScreenEntry _withPriority(ScreenEntry entry) {
    final priority = assignPriority(entry);
    return ScreenEntry(
      project: entry.project,
      feature: entry.feature,
      fileName: entry.fileName,
      relativePath: entry.relativePath,
      businessTypes: entry.businessTypes,
      mockData: entry.mockData,
      mockReasons: entry.mockReasons,
      apiConnected: entry.apiConnected,
      offlineReady: entry.offlineReady,
      uiConsistent: entry.uiConsistent,
      navWired: entry.navWired,
      priority: priority,
    );
  }
}
