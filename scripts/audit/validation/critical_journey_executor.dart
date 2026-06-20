/// Critical Journey Executor for Vertical-Specific Validation.
///
/// Executes the critical user journey (create → list → edit → report → export)
/// for each vertical's primary entity, running all 14 verticals independently
/// with isolated test data.
///
/// Requirements: 12.4, 12.5, 12.6
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Configuration for a single business vertical.
class VerticalConfig {
  /// Unique identifier for the vertical (e.g., "restaurant").
  final String id;

  /// Display name (e.g., "Restaurant").
  final String name;

  /// Feature folder under lib/features/.
  final String featureFolder;

  /// Business type label used in the registry.
  final String businessType;

  /// Primary entity for the critical journey (e.g., "menu_item").
  final String primaryEntity;

  /// Ordered list of journey steps to execute.
  final List<String> criticalJourney;

  /// Domain-specific screens for this vertical.
  final List<String> domainScreens;

  /// Dashboard route entry point.
  final String dashboardRoute;

  const VerticalConfig({
    required this.id,
    required this.name,
    required this.featureFolder,
    required this.businessType,
    required this.primaryEntity,
    required this.criticalJourney,
    required this.domainScreens,
    required this.dashboardRoute,
  });

  /// Parses a VerticalConfig from a JSON map.
  factory VerticalConfig.fromJson(Map<String, dynamic> json) {
    return VerticalConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      featureFolder: json['featureFolder'] as String,
      businessType: json['businessType'] as String,
      primaryEntity: json['primaryEntity'] as String,
      criticalJourney: List<String>.from(json['criticalJourney'] as List),
      domainScreens: List<String>.from(json['domainScreens'] as List),
      dashboardRoute: json['dashboardRoute'] as String,
    );
  }

  /// Converts this config to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'featureFolder': featureFolder,
    'businessType': businessType,
    'primaryEntity': primaryEntity,
    'criticalJourney': criticalJourney,
    'domainScreens': domainScreens,
    'dashboardRoute': dashboardRoute,
  };

  @override
  String toString() => 'VerticalConfig($id: $name, entity: $primaryEntity)';
}

/// Result of executing a single journey step.
class JourneyStepResult {
  /// Step name: 'create', 'list', 'edit', 'report', or 'export'.
  final String stepName;

  /// Whether this step passed validation.
  final bool passed;

  /// Error message if the step failed, null otherwise.
  final String? errorMessage;

  /// Duration the step took to execute.
  final Duration duration;

  const JourneyStepResult({
    required this.stepName,
    required this.passed,
    this.errorMessage,
    required this.duration,
  });

  /// Creates a successful step result.
  factory JourneyStepResult.success(String stepName, Duration duration) {
    return JourneyStepResult(
      stepName: stepName,
      passed: true,
      duration: duration,
    );
  }

  /// Creates a failed step result.
  factory JourneyStepResult.failure(
    String stepName,
    String errorMessage,
    Duration duration,
  ) {
    return JourneyStepResult(
      stepName: stepName,
      passed: false,
      errorMessage: errorMessage,
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() => {
    'stepName': stepName,
    'passed': passed,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'durationMs': duration.inMilliseconds,
  };

  @override
  String toString() =>
      'JourneyStepResult($stepName: ${passed ? "PASSED" : "FAILED"}, '
      '${duration.inMilliseconds}ms)';
}

/// Result of executing the full critical journey for a single vertical.
class JourneyResult {
  /// The vertical identifier this result belongs to.
  final String verticalId;

  /// Whether the entire journey passed (all steps succeeded).
  final bool passed;

  /// Results for each journey step in execution order.
  final List<JourneyStepResult> steps;

  /// The first step that failed, or null if all passed.
  final String? failingStep;

  const JourneyResult({
    required this.verticalId,
    required this.passed,
    required this.steps,
    this.failingStep,
  });

  /// Creates a JourneyResult from completed step results.
  factory JourneyResult.fromSteps(
    String verticalId,
    List<JourneyStepResult> steps,
  ) {
    final failingStep = steps
        .where((s) => !s.passed)
        .map((s) => s.stepName)
        .firstOrNull;

    return JourneyResult(
      verticalId: verticalId,
      passed: failingStep == null,
      steps: steps,
      failingStep: failingStep,
    );
  }

  /// Total duration across all steps.
  Duration get totalDuration =>
      steps.fold(Duration.zero, (total, step) => total + step.duration);

  /// Number of steps that passed.
  int get passedCount => steps.where((s) => s.passed).length;

  /// Number of steps that failed.
  int get failedCount => steps.where((s) => !s.passed).length;

  Map<String, dynamic> toJson() => {
    'verticalId': verticalId,
    'passed': passed,
    'steps': steps.map((s) => s.toJson()).toList(),
    if (failingStep != null) 'failingStep': failingStep,
    'totalDurationMs': totalDuration.inMilliseconds,
    'passedCount': passedCount,
    'failedCount': failedCount,
  };

  @override
  String toString() =>
      'JourneyResult($verticalId: ${passed ? "PASSED" : "FAILED"}, '
      'steps: ${passedCount}/${steps.length})';
}

/// Isolated test data context for a single vertical's journey execution.
///
/// Ensures each vertical runs with its own test data that does not
/// interfere with other verticals.
class IsolatedTestData {
  /// The vertical this test data belongs to.
  final String verticalId;

  /// The primary entity type being tested.
  final String entityType;

  /// Generated test entity ID (used across create/edit/report steps).
  final String testEntityId;

  /// Test data payload for the create step.
  final Map<String, dynamic> createPayload;

  /// Test data payload for the edit step.
  final Map<String, dynamic> editPayload;

  const IsolatedTestData({
    required this.verticalId,
    required this.entityType,
    required this.testEntityId,
    required this.createPayload,
    required this.editPayload,
  });

  /// Generates isolated test data for a given vertical config.
  factory IsolatedTestData.generate(VerticalConfig config) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testId = 'test_${config.id}_$timestamp';

    return IsolatedTestData(
      verticalId: config.id,
      entityType: config.primaryEntity,
      testEntityId: testId,
      createPayload: _generateCreatePayload(config, testId),
      editPayload: _generateEditPayload(config, testId),
    );
  }

  static Map<String, dynamic> _generateCreatePayload(
    VerticalConfig config,
    String testId,
  ) {
    return {
      'id': testId,
      'entityType': config.primaryEntity,
      'verticalId': config.id,
      'name': 'Test ${config.primaryEntity} for ${config.name}',
      'createdAt': DateTime.now().toIso8601String(),
      'isTestData': true,
    };
  }

  static Map<String, dynamic> _generateEditPayload(
    VerticalConfig config,
    String testId,
  ) {
    return {
      'id': testId,
      'entityType': config.primaryEntity,
      'verticalId': config.id,
      'name': 'Updated ${config.primaryEntity} for ${config.name}',
      'updatedAt': DateTime.now().toIso8601String(),
      'isTestData': true,
    };
  }
}

/// Callback type for individual journey step execution.
///
/// Implementations should perform the actual step validation
/// (e.g., checking if a screen exists, if CRUD operations work, etc.)
typedef JourneyStepExecutor =
    Future<JourneyStepResult> Function(
      VerticalConfig vertical,
      IsolatedTestData testData,
      String stepName,
    );

/// Executes critical user journeys across all verticals.
///
/// For each vertical, the executor runs the journey sequence:
/// create → list → edit → report → export/print
///
/// Each vertical runs independently with isolated test data.
/// On step failure, the vertical is marked as failed with the failing step
/// recorded, and execution continues to remaining verticals.
class CriticalJourneyExecutor {
  /// Per-step timeout. Steps exceeding this are marked as failed.
  static const Duration stepTimeout = Duration(seconds: 30);

  /// Custom step executors, keyed by step name.
  /// If not provided, the default file-system-based validators are used.
  final Map<String, JourneyStepExecutor>? customExecutors;

  /// Project root path for file-based validations.
  final String projectRoot;

  const CriticalJourneyExecutor({
    required this.projectRoot,
    this.customExecutors,
  });

  /// Executes critical journeys for all provided verticals.
  ///
  /// Each vertical is executed independently with isolated test data.
  /// Failures in one vertical do not abort execution of remaining verticals.
  ///
  /// Returns a list of [JourneyResult] in the same order as input verticals.
  Future<List<JourneyResult>> executeAll(List<VerticalConfig> verticals) async {
    final results = <JourneyResult>[];

    for (final vertical in verticals) {
      final result = await executeJourney(vertical);
      results.add(result);
    }

    return results;
  }

  /// Executes the critical journey for a single vertical.
  ///
  /// Generates isolated test data, then runs each step in the vertical's
  /// criticalJourney sequence. On step failure, records the failing step
  /// and continues executing remaining steps.
  Future<JourneyResult> executeJourney(VerticalConfig vertical) async {
    final testData = IsolatedTestData.generate(vertical);
    final stepResults = <JourneyStepResult>[];

    for (final stepName in vertical.criticalJourney) {
      final result = await _executeStep(vertical, testData, stepName);
      stepResults.add(result);
    }

    return JourneyResult.fromSteps(vertical.id, stepResults);
  }

  /// Executes a single journey step with timeout handling.
  Future<JourneyStepResult> _executeStep(
    VerticalConfig vertical,
    IsolatedTestData testData,
    String stepName,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Use custom executor if provided, otherwise default validation.
      final executor = customExecutors?[stepName];
      if (executor != null) {
        final result = await executor(
          vertical,
          testData,
          stepName,
        ).timeout(stepTimeout);
        stopwatch.stop();
        return result;
      }

      // Default file-system-based validation for each step.
      final result = await _defaultStepValidation(
        vertical,
        testData,
        stepName,
      ).timeout(stepTimeout);
      stopwatch.stop();
      return result;
    } on TimeoutException {
      stopwatch.stop();
      return JourneyStepResult.failure(
        stepName,
        'Step timed out after ${stepTimeout.inSeconds}s',
        stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return JourneyStepResult.failure(
        stepName,
        'Unexpected error: $e',
        stopwatch.elapsed,
      );
    }
  }

  /// Default validation logic for each journey step.
  ///
  /// Validates that the vertical has the infrastructure to support
  /// the journey step (screens, routes, API endpoints exist).
  Future<JourneyStepResult> _defaultStepValidation(
    VerticalConfig vertical,
    IsolatedTestData testData,
    String stepName,
  ) async {
    final stopwatch = Stopwatch()..start();

    switch (stepName) {
      case 'create':
        return _validateCreateStep(vertical, testData, stopwatch);
      case 'list':
        return _validateListStep(vertical, testData, stopwatch);
      case 'edit':
        return _validateEditStep(vertical, testData, stopwatch);
      case 'report':
        return _validateReportStep(vertical, testData, stopwatch);
      case 'export':
        return _validateExportStep(vertical, testData, stopwatch);
      default:
        stopwatch.stop();
        return JourneyStepResult.failure(
          stepName,
          'Unknown journey step: $stepName',
          stopwatch.elapsed,
        );
    }
  }

  /// Validates the 'create' step: checks that a create screen or form
  /// exists for the vertical's primary entity.
  Future<JourneyStepResult> _validateCreateStep(
    VerticalConfig vertical,
    IsolatedTestData testData,
    Stopwatch stopwatch,
  ) async {
    final featurePath = '$projectRoot/lib/features/${vertical.featureFolder}';
    final dir = Directory(featurePath);

    if (!await dir.exists()) {
      stopwatch.stop();
      return JourneyStepResult.failure(
        'create',
        'Feature directory not found: ${vertical.featureFolder}',
        stopwatch.elapsed,
      );
    }

    // Look for create/add/new screens or forms for the primary entity.
    final createPatterns = [
      'create_${vertical.primaryEntity}',
      'add_${vertical.primaryEntity}',
      'new_${vertical.primaryEntity}',
      '${vertical.primaryEntity}_form',
      '${vertical.primaryEntity}_creation',
    ];

    final found = await _findScreenMatchingPatterns(
      featurePath,
      createPatterns,
      vertical.primaryEntity,
    );

    stopwatch.stop();
    if (found) {
      return JourneyStepResult.success('create', stopwatch.elapsed);
    }

    return JourneyStepResult.failure(
      'create',
      'No create/add screen found for entity: ${vertical.primaryEntity}',
      stopwatch.elapsed,
    );
  }

  /// Validates the 'list' step: checks that a list/management screen
  /// exists for the vertical's primary entity.
  Future<JourneyStepResult> _validateListStep(
    VerticalConfig vertical,
    IsolatedTestData testData,
    Stopwatch stopwatch,
  ) async {
    final featurePath = '$projectRoot/lib/features/${vertical.featureFolder}';

    final listPatterns = [
      '${vertical.primaryEntity}_list',
      '${vertical.primaryEntity}_management',
      '${vertical.primaryEntity}s_screen',
      '${vertical.primaryEntity}_screen',
    ];

    final found = await _findScreenMatchingPatterns(
      featurePath,
      listPatterns,
      vertical.primaryEntity,
    );

    stopwatch.stop();
    if (found) {
      return JourneyStepResult.success('list', stopwatch.elapsed);
    }

    return JourneyStepResult.failure(
      'list',
      'No list/management screen found for entity: ${vertical.primaryEntity}',
      stopwatch.elapsed,
    );
  }

  /// Validates the 'edit' step: checks that edit functionality exists
  /// for the vertical's primary entity (often shares create screen).
  Future<JourneyStepResult> _validateEditStep(
    VerticalConfig vertical,
    IsolatedTestData testData,
    Stopwatch stopwatch,
  ) async {
    final featurePath = '$projectRoot/lib/features/${vertical.featureFolder}';

    final editPatterns = [
      'edit_${vertical.primaryEntity}',
      '${vertical.primaryEntity}_edit',
      '${vertical.primaryEntity}_detail',
      '${vertical.primaryEntity}_form',
      'create_${vertical.primaryEntity}', // Often reused for edit
    ];

    final found = await _findScreenMatchingPatterns(
      featurePath,
      editPatterns,
      vertical.primaryEntity,
    );

    stopwatch.stop();
    if (found) {
      return JourneyStepResult.success('edit', stopwatch.elapsed);
    }

    return JourneyStepResult.failure(
      'edit',
      'No edit/detail screen found for entity: ${vertical.primaryEntity}',
      stopwatch.elapsed,
    );
  }

  /// Validates the 'report' step: checks that a report screen or
  /// report generation capability exists for the vertical.
  Future<JourneyStepResult> _validateReportStep(
    VerticalConfig vertical,
    IsolatedTestData testData,
    Stopwatch stopwatch,
  ) async {
    final featurePath = '$projectRoot/lib/features/${vertical.featureFolder}';

    final reportPatterns = [
      'report',
      '${vertical.primaryEntity}_report',
      'analytics',
      'summary',
      'dashboard',
    ];

    final found = await _findScreenMatchingPatterns(
      featurePath,
      reportPatterns,
      null, // Broader search for report screens
    );

    stopwatch.stop();
    if (found) {
      return JourneyStepResult.success('report', stopwatch.elapsed);
    }

    return JourneyStepResult.failure(
      'report',
      'No report/analytics screen found for vertical: ${vertical.name}',
      stopwatch.elapsed,
    );
  }

  /// Validates the 'export' step: checks that export or print
  /// functionality exists for the vertical.
  Future<JourneyStepResult> _validateExportStep(
    VerticalConfig vertical,
    IsolatedTestData testData,
    Stopwatch stopwatch,
  ) async {
    final featurePath = '$projectRoot/lib/features/${vertical.featureFolder}';

    final exportPatterns = ['export', 'print', 'pdf', 'share', 'download'];

    final found = await _findScreenMatchingPatterns(
      featurePath,
      exportPatterns,
      null, // Broader search for export functionality
    );

    stopwatch.stop();
    if (found) {
      return JourneyStepResult.success('export', stopwatch.elapsed);
    }

    return JourneyStepResult.failure(
      'export',
      'No export/print functionality found for vertical: ${vertical.name}',
      stopwatch.elapsed,
    );
  }

  /// Searches the feature directory for Dart files matching any of
  /// the given patterns (in file names or file content).
  ///
  /// [entityHint] is used for broader content-based matching when set.
  Future<bool> _findScreenMatchingPatterns(
    String featurePath,
    List<String> patterns,
    String? entityHint,
  ) async {
    final dir = Directory(featurePath);
    if (!await dir.exists()) return false;

    final dartFiles = await dir
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.dart'))
        .cast<File>()
        .toList();

    for (final file in dartFiles) {
      final fileName = file.path
          .replaceAll('\\', '/')
          .split('/')
          .last
          .toLowerCase();

      // Check if file name matches any pattern.
      for (final pattern in patterns) {
        if (fileName.contains(pattern.toLowerCase())) {
          return true;
        }
      }
    }

    // If entity hint provided, search file contents for CRUD indicators.
    if (entityHint != null) {
      for (final file in dartFiles) {
        try {
          final content = await file.readAsString();
          final contentLower = content.toLowerCase();
          if (contentLower.contains(entityHint.toLowerCase()) &&
              _hasFormOrCrudIndicators(contentLower)) {
            return true;
          }
        } catch (_) {
          // Skip files that can't be read.
          continue;
        }
      }
    }

    return false;
  }

  /// Checks if content has indicators of CRUD form functionality.
  bool _hasFormOrCrudIndicators(String contentLower) {
    const indicators = [
      'textformfield',
      'formfield',
      'textfield',
      'controller',
      'save',
      'submit',
      'create',
      'update',
    ];
    return indicators.any(contentLower.contains);
  }

  /// Loads vertical configurations from the standard JSON config file.
  static Future<List<VerticalConfig>> loadVerticals(String configPath) async {
    final file = File(configPath);
    if (!await file.exists()) {
      throw FileSystemException('Verticals config file not found', configPath);
    }

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final verticals = json['verticals'] as List;

    return verticals
        .map((v) => VerticalConfig.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Generates a summary report from journey results.
  static JourneyExecutionSummary summarize(List<JourneyResult> results) {
    return JourneyExecutionSummary(results: results);
  }
}

/// Summary of a full critical journey execution run across verticals.
class JourneyExecutionSummary {
  /// All journey results from the run.
  final List<JourneyResult> results;

  const JourneyExecutionSummary({required this.results});

  /// Number of verticals that passed all steps.
  int get passedVerticals => results.where((r) => r.passed).length;

  /// Number of verticals with at least one failing step.
  int get failedVerticals => results.where((r) => !r.passed).length;

  /// Total number of verticals executed.
  int get totalVerticals => results.length;

  /// List of vertical IDs that failed.
  List<String> get failedVerticalIds =>
      results.where((r) => !r.passed).map((r) => r.verticalId).toList();

  /// Map of vertical ID to its first failing step name.
  Map<String, String> get failureMap => {
    for (final r in results.where((r) => !r.passed))
      r.verticalId: r.failingStep ?? 'unknown',
  };

  /// Overall pass rate as a percentage (0-100).
  double get passRate =>
      totalVerticals == 0 ? 0 : (passedVerticals / totalVerticals) * 100;

  Map<String, dynamic> toJson() => {
    'totalVerticals': totalVerticals,
    'passedVerticals': passedVerticals,
    'failedVerticals': failedVerticals,
    'passRate': passRate,
    'failedVerticalIds': failedVerticalIds,
    'failureMap': failureMap,
    'results': results.map((r) => r.toJson()).toList(),
  };

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('=== Critical Journey Execution Summary ===')
      ..writeln(
        'Total: $totalVerticals | '
        'Passed: $passedVerticals | '
        'Failed: $failedVerticals | '
        'Rate: ${passRate.toStringAsFixed(1)}%',
      )
      ..writeln('');

    for (final result in results) {
      final status = result.passed ? '✓' : '✗';
      buffer.write('  $status ${result.verticalId}');
      if (!result.passed) {
        buffer.write(' (failed at: ${result.failingStep})');
      }
      buffer.writeln(' [${result.totalDuration.inMilliseconds}ms]');
    }

    if (failedVerticals > 0) {
      buffer
        ..writeln('')
        ..writeln('Failed verticals:');
      for (final entry in failureMap.entries) {
        buffer.writeln('  - ${entry.key}: failed at "${entry.value}" step');
      }
    }

    return buffer.toString();
  }
}
