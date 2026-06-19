/// Shared Dart models for the Flutter-side screen discovery audit tools.
///
/// Contains: Priority enum, ScreenEntry, ScreenClassification, MockDetectionResult.
/// Referenced by: screen_discovery.dart, mock_eliminator.dart, registry tools.
library;

/// Priority level assigned to a screen based on its role in the application.
///
/// - [high]: Dashboard or entry-point screens.
/// - [medium]: Standard feature screens with navigation wired.
/// - [low]: Secondary/utility screens or screens lacking navigation.
enum Priority {
  high,
  medium,
  low;

  /// Returns the CSV-friendly label (capitalized).
  String get label => switch (this) {
    Priority.high => 'High',
    Priority.medium => 'Medium',
    Priority.low => 'Low',
  };

  /// Parses a priority from its CSV label (case-insensitive).
  static Priority fromLabel(String label) => switch (label.toLowerCase()) {
    'high' => Priority.high,
    'medium' => Priority.medium,
    'low' => Priority.low,
    _ => Priority.low,
  };
}

/// A single screen entry in the Discovery Registry.
///
/// Each field maps to a column in the `audit_results.csv` output.
class ScreenEntry {
  /// Project name (always "Dukan_x").
  final String project;

  /// Feature folder name or "core/general".
  final String feature;

  /// Dart file name (e.g., `home_screen.dart`).
  final String fileName;

  /// Full relative path from project root.
  final String relativePath;

  /// Vertical / business type name (e.g., "Restaurant", "Pharmacy").
  final String businessTypes;

  /// Whether mock data was detected in this screen.
  final bool mockData;

  /// Comma-separated list of detected mock indicators, or empty string.
  final String mockReasons;

  /// Whether the screen calls a real API endpoint.
  final bool apiConnected;

  /// Whether offline caching is implemented for this screen.
  final bool offlineReady;

  /// Whether the screen passes the UI consistency checklist.
  final bool uiConsistent;

  /// Whether the screen is reachable in the navigation graph.
  final bool navWired;

  /// Assigned priority level.
  final Priority priority;

  const ScreenEntry({
    required this.project,
    required this.feature,
    required this.fileName,
    required this.relativePath,
    required this.businessTypes,
    required this.mockData,
    required this.mockReasons,
    required this.apiConnected,
    required this.offlineReady,
    required this.uiConsistent,
    required this.navWired,
    required this.priority,
  });

  /// Serializes this entry to a CSV row (list of field values).
  List<String> toCsvRow() => [
    project,
    feature,
    fileName,
    relativePath,
    businessTypes,
    mockData.toString(),
    mockReasons,
    apiConnected.toString(),
    offlineReady.toString(),
    uiConsistent.toString(),
    navWired.toString(),
    priority.label,
  ];

  /// CSV header row matching the Discovery Registry schema.
  static const List<String> csvHeaders = [
    'Project',
    'Feature',
    'FileName',
    'RelativePath',
    'BusinessTypes',
    'MockData',
    'MockReasons',
    'ApiConnected',
    'OfflineReady',
    'UiConsistent',
    'NavWired',
    'Priority',
  ];

  /// Parses a ScreenEntry from a CSV row (list of field values).
  factory ScreenEntry.fromCsvRow(List<String> row) {
    if (row.length < 12) {
      throw ArgumentError(
        'CSV row must have at least 12 columns, got ${row.length}',
      );
    }
    return ScreenEntry(
      project: row[0],
      feature: row[1],
      fileName: row[2],
      relativePath: row[3],
      businessTypes: row[4],
      mockData: row[5].toLowerCase() == 'true',
      mockReasons: row[6],
      apiConnected: row[7].toLowerCase() == 'true',
      offlineReady: row[8].toLowerCase() == 'true',
      uiConsistent: row[9].toLowerCase() == 'true',
      navWired: row[10].toLowerCase() == 'true',
      priority: Priority.fromLabel(row[11]),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenEntry &&
          project == other.project &&
          feature == other.feature &&
          fileName == other.fileName &&
          relativePath == other.relativePath &&
          businessTypes == other.businessTypes &&
          mockData == other.mockData &&
          mockReasons == other.mockReasons &&
          apiConnected == other.apiConnected &&
          offlineReady == other.offlineReady &&
          uiConsistent == other.uiConsistent &&
          navWired == other.navWired &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(
    project,
    feature,
    fileName,
    relativePath,
    businessTypes,
    mockData,
    mockReasons,
    apiConnected,
    offlineReady,
    uiConsistent,
    navWired,
    priority,
  );

  @override
  String toString() =>
      'ScreenEntry($fileName, vertical: $businessTypes, priority: ${priority.label})';
}

/// Result of classifying whether a Dart file contains a valid screen widget.
class ScreenClassification {
  /// Whether the file contains a valid screen widget.
  final bool isScreen;

  /// The widget class name, if found.
  final String? className;

  /// The widget supertype: 'StatelessWidget' or 'StatefulWidget'.
  final String? widgetType;

  /// True if file name matches screen/page pattern but has no valid widget class.
  final bool isFalsePositive;

  const ScreenClassification({
    required this.isScreen,
    this.className,
    this.widgetType,
    required this.isFalsePositive,
  });

  @override
  String toString() =>
      'ScreenClassification(isScreen: $isScreen, class: $className, type: $widgetType, falsePositive: $isFalsePositive)';
}

/// Result of detecting mock data patterns in a Dart file.
class MockDetectionResult {
  /// Whether any mock data pattern was detected.
  final bool hasMockData;

  /// Comma-separated list of detected patterns (e.g., "hardcoded_array,todo_placeholder").
  final String mockReasons;

  const MockDetectionResult({
    required this.hasMockData,
    required this.mockReasons,
  });

  /// No mock data detected.
  static const MockDetectionResult none = MockDetectionResult(
    hasMockData: false,
    mockReasons: '',
  );

  @override
  String toString() =>
      'MockDetectionResult(hasMock: $hasMockData, reasons: $mockReasons)';
}
