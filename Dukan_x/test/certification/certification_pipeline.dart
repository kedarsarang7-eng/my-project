/// Certification Pipeline — top-level orchestration for the Certification_System.
///
/// Connects the scan → plan → test → gate → trace → decide pipeline into a
/// single entry point that produces the `production-readiness-checklist.md`
/// deliverable.
///
/// Pipeline stages:
/// 1. **Scan**: InventoryScanner → SystemMap + system-map.md
/// 2. **Plan**: TestFileClassifier classifies discovered test files
/// 3. **Test**: References the four layer suites (unit, widget, integration, e2e)
/// 4. **Gate**: GateStatusReducer (performance/security), RegressionReducer,
///    ReconciliationChecker (data integrity)
/// 5. **Trace**: TraceabilityMatrix linking requirements → tests → results → defects
/// 6. **Decide**: ProductionReadinessDecider → go/no-go with evidence
///
/// Also integrates:
/// - BenchmarkValidator for industry benchmark document validation
/// - MockDataScanner for Release_Build mock-data detection
/// - DefectStore for defect persistence
/// - CertificationPass.runAll() for per-type certification
///
/// Requirements: 14.1, 12.1, 12.4
library;

import 'dart:io';

import 'io/inventory_scanner.dart';
import 'io/certification_pass.dart';
import 'io/defect_store.dart';
import 'io/artifact_store.dart';
import 'io/mock_data_scanner.dart';
import 'core/gate_reducer.dart';
import 'core/regression_reducer.dart';
import 'core/reconciliation.dart';
import 'core/readiness_decider.dart';
import 'core/benchmark.dart';
import 'core/traceability_matrix.dart';
import 'core/test_classifier.dart';
import 'core/coverage_gap.dart';
import 'core/domain.dart';
import 'core/defect.dart';

// ---------------------------------------------------------------------------
// Pipeline configuration
// ---------------------------------------------------------------------------

/// Configuration for the certification pipeline run.
class PipelineConfig {
  /// Workspace root path (parent of Dukan_x/).
  final String workspacePath;

  /// Base output path for artifacts (system-map.md, reports/, defects/, etc.).
  final String outputPath;

  /// Path to the Release_Build to scan for mock data.
  final String? releaseBuildPath;

  /// Performance thresholds (tunable). Uses defaults if not provided.
  final PerfThresholds perfThresholds;

  /// Benchmark document to validate (optional — skip if null).
  final BenchmarkDocument? benchmarkDocument;

  /// Pre-collected performance measurements (from a separate perf probe run).
  /// If null, the performance gate is marked as not-evaluated.
  final List<PerfMeasurement>? performanceMeasurements;

  /// Pre-collected security case results (from a separate security probe run).
  /// If null, the security gate is marked as not-evaluated.
  final List<SecurityCaseResult>? securityCaseResults;

  /// Pre-collected regression test results (from a full test suite run).
  /// If null, the regression gate is marked as not-evaluated.
  final List<TestCaseResult>? regressionResults;

  /// Pre-collected record sets for data-integrity reconciliation.
  /// If null, the data-integrity gate is marked as not-evaluated.
  final RecordSet? recordSet;

  /// Post-sync record set for reconciliation difference check.
  final RecordSet? afterSyncRecordSet;

  /// Whether debug flags are absent from the Release_Build.
  final bool debugFlagsAbsent;

  /// Whether the environment matches approved production configuration.
  final bool envMatchesProduction;

  /// Whether the certification run was crash-free.
  final bool crashFree;

  const PipelineConfig({
    required this.workspacePath,
    required this.outputPath,
    this.releaseBuildPath,
    this.perfThresholds = const PerfThresholds(),
    this.benchmarkDocument,
    this.performanceMeasurements,
    this.securityCaseResults,
    this.regressionResults,
    this.recordSet,
    this.afterSyncRecordSet,
    this.debugFlagsAbsent = true,
    this.envMatchesProduction = true,
    this.crashFree = true,
  });
}

// ---------------------------------------------------------------------------
// Pipeline result
// ---------------------------------------------------------------------------

/// The complete output of a certification pipeline run.
class PipelineResult {
  /// The SystemMap produced by the scan stage.
  final SystemMap systemMap;

  /// Test file classifications from the plan stage.
  final List<ClassificationResult> testClassifications;

  /// Certification reports (one per business type) from the test stage.
  final List<CertificationReport> certificationReports;

  /// Gate statuses from the gate stage.
  final Map<String, GateStatus> gateStatuses;

  /// The traceability matrix snapshot.
  final TraceabilityMatrix traceabilityMatrix;

  /// The final production-readiness decision.
  final ReadinessDecision readinessDecision;

  /// Benchmark validation result (null if no document provided).
  final BenchmarkValidation? benchmarkValidation;

  /// Mock data scan result (null if no build path provided).
  final MockScanResult? mockScanResult;

  /// Path to the production-readiness-checklist.md output.
  final String checklistPath;

  const PipelineResult({
    required this.systemMap,
    required this.testClassifications,
    required this.certificationReports,
    required this.gateStatuses,
    required this.traceabilityMatrix,
    required this.readinessDecision,
    required this.checklistPath,
    this.benchmarkValidation,
    this.mockScanResult,
  });
}

// ---------------------------------------------------------------------------
// CertificationPipeline — the main orchestrator
// ---------------------------------------------------------------------------

/// Top-level orchestration connecting all certification components into the
/// scan → plan → test → gate → trace → decide pipeline.
///
/// Produces `production-readiness-checklist.md` containing the decision and
/// all evidence.
class CertificationPipeline {
  /// Inventory scanner for the scan stage.
  final InventoryScanner _scanner;

  /// Test file classifier for the plan stage.
  final TestFileClassifier _classifier;

  /// Certification pass orchestrator for the test stage.
  final CertificationPass _certificationPass;

  /// Defect store for persisting defects across stages.
  final DefectStore _defectStore;

  /// Gate status reducer for performance and security.
  final GateStatusReducer _gateReducer;

  /// Regression reducer for test-suite conjunction.
  final RegressionReducer _regressionReducer;

  /// Reconciliation checker for data-integrity gate.
  final ReconciliationChecker _reconciliationChecker;

  /// Traceability matrix for linking requirements to evidence.
  final TraceabilityMatrix _traceabilityMatrix;

  /// Benchmark validator for industry standards document.
  final BenchmarkValidator _benchmarkValidator;

  /// Mock data scanner for Release_Build scanning.
  final MockDataScanner _mockDataScanner;

  /// Production readiness decider for the final go/no-go.
  final ProductionReadinessDecider _readinessDecider;

  /// Artifact store for atomic writes.
  final ArtifactStore _artifactStore;

  CertificationPipeline({
    InventoryScanner? scanner,
    TestFileClassifier? classifier,
    CertificationPass? certificationPass,
    DefectStore? defectStore,
    GateStatusReducer? gateReducer,
    RegressionReducer? regressionReducer,
    ReconciliationChecker? reconciliationChecker,
    TraceabilityMatrix? traceabilityMatrix,
    BenchmarkValidator? benchmarkValidator,
    MockDataScanner? mockDataScanner,
    ProductionReadinessDecider? readinessDecider,
    ArtifactStore? artifactStore,
  }) : _scanner = scanner ?? InventoryScanner(),
       _classifier = classifier ?? const TestFileClassifier(),
       _certificationPass = certificationPass ?? _defaultCertificationPass(),
       _defectStore = defectStore ?? _defaultDefectStore(),
       _gateReducer = gateReducer ?? const GateStatusReducer(),
       _regressionReducer = regressionReducer ?? const RegressionReducer(),
       _reconciliationChecker =
           reconciliationChecker ?? ReconciliationChecker(),
       _traceabilityMatrix = traceabilityMatrix ?? TraceabilityMatrix(),
       _benchmarkValidator = benchmarkValidator ?? const BenchmarkValidator(),
       _mockDataScanner = mockDataScanner ?? MockDataScanner(),
       _readinessDecider =
           readinessDecider ?? const ProductionReadinessDecider(),
       _artifactStore = artifactStore ?? const ArtifactStore();

  /// Run the full certification pipeline: scan → plan → test → gate → trace → decide.
  ///
  /// Writes `production-readiness-checklist.md` at [config.outputPath] and
  /// returns the complete [PipelineResult] with all evidence.
  Future<PipelineResult> run(PipelineConfig config) async {
    // ─── Stage 1: SCAN ──────────────────────────────────────────────────
    final systemMap = await _scan(config);

    // ─── Stage 2: PLAN ──────────────────────────────────────────────────
    final classifications = _plan(config, systemMap);

    // ─── Stage 3: TEST ──────────────────────────────────────────────────
    final certReports = await _test(config);

    // ─── Stage 4: GATE ──────────────────────────────────────────────────
    final gateStatuses = await _gate(config);

    // ─── Stage 5: TRACE ─────────────────────────────────────────────────
    await _trace(config, certReports, gateStatuses);

    // ─── Stage 6: DECIDE ────────────────────────────────────────────────
    final benchmarkValidation = _validateBenchmark(config);
    final mockScanResult = await _scanMockData(config);
    final decision = _decide(config, gateStatuses, mockScanResult);

    // ─── Write production-readiness-checklist.md ─────────────────────────
    final checklistPath =
        '${config.outputPath}/production-readiness-checklist.md';
    await _writeChecklist(
      checklistPath,
      decision,
      gateStatuses,
      systemMap,
      certReports,
      mockScanResult,
      benchmarkValidation,
      config,
    );

    return PipelineResult(
      systemMap: systemMap,
      testClassifications: classifications,
      certificationReports: certReports,
      gateStatuses: gateStatuses,
      traceabilityMatrix: _traceabilityMatrix,
      readinessDecision: decision,
      checklistPath: checklistPath,
      benchmarkValidation: benchmarkValidation,
      mockScanResult: mockScanResult,
    );
  }

  // ─── Stage 1: SCAN ─────────────────────────────────────────────────────

  /// Runs the InventoryScanner to produce a SystemMap and writes system-map.md.
  Future<SystemMap> _scan(PipelineConfig config) async {
    final systemMap = await _scanner.scan(workspacePath: config.workspacePath);

    // Write system-map.md (Req 1.7)
    final systemMapPath = '${config.outputPath}/inventory/system-map.md';
    _scanner.writeSystemMap(systemMap, systemMapPath);

    return systemMap;
  }

  // ─── Stage 2: PLAN ─────────────────────────────────────────────────────

  /// Classifies discovered test files under the four layer roots.
  List<ClassificationResult> _plan(PipelineConfig config, SystemMap systemMap) {
    final classifications = <ClassificationResult>[];
    final testRoots = [
      '${config.workspacePath}/Dukan_x/test/unit',
      '${config.workspacePath}/Dukan_x/test/widget',
      '${config.workspacePath}/Dukan_x/integration_test',
      '${config.workspacePath}/Dukan_x/e2e',
    ];

    for (final root in testRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      final testFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'));

      for (final file in testFiles) {
        final result = _classifier.classify(file.path);
        classifications.add(result);

        // Record defects for unassignable test files (Req 16.4)
        if (result is ClassificationError) {
          final defect = _classifier.createUnassignableDefect(result);
          _defectStore.upsert(defect);
        }
      }
    }

    return classifications;
  }

  // ─── Stage 3: TEST ─────────────────────────────────────────────────────

  /// Runs CertificationPass.runAll() for all 19 business types.
  Future<List<CertificationReport>> _test(PipelineConfig config) async {
    return _certificationPass.runAll();
  }

  // ─── Stage 4: GATE ─────────────────────────────────────────────────────

  /// Evaluates all quality gates and returns their statuses.
  Future<Map<String, GateStatus>> _gate(PipelineConfig config) async {
    final gateStatuses = <String, GateStatus>{};

    // Performance gate
    if (config.performanceMeasurements != null) {
      gateStatuses['performance'] = _gateReducer.reducePerformance(
        config.performanceMeasurements!,
      );
    } else {
      gateStatuses['performance'] = GateStatus.notGreen;
    }

    // Security gate
    if (config.securityCaseResults != null) {
      gateStatuses['security'] = _gateReducer.reduceSecurity(
        config.securityCaseResults!,
      );
    } else {
      gateStatuses['security'] = GateStatus.notGreen;
    }

    // Regression gate
    if (config.regressionResults != null) {
      final regressionResult = _regressionReducer.reduce(
        config.regressionResults!,
      );
      gateStatuses['regression'] = regressionResult.releaseBlocked
          ? GateStatus.notGreen
          : GateStatus.green;
    } else {
      gateStatuses['regression'] = GateStatus.notGreen;
    }

    // Data integrity gate
    if (config.recordSet != null) {
      final reconciliationResult = _reconciliationChecker.check(
        config.recordSet!,
        config.afterSyncRecordSet,
      );
      gateStatuses['dataIntegrity'] = reconciliationResult.passed
          ? GateStatus.green
          : GateStatus.notGreen;
    } else {
      gateStatuses['dataIntegrity'] = GateStatus.notGreen;
    }

    return gateStatuses;
  }

  // ─── Stage 5: TRACE ────────────────────────────────────────────────────

  /// Updates the traceability matrix with certification results and persists it.
  Future<void> _trace(
    PipelineConfig config,
    List<CertificationReport> reports,
    Map<String, GateStatus> gateStatuses,
  ) async {
    // Link certification check results to requirements in the matrix
    for (final report in reports) {
      for (final check in report.checks) {
        final requirementId = _checkNameToRequirementId(check.name);

        // Link defects from failed checks
        for (final defectId in check.defectIds) {
          _traceabilityMatrix.applyChange(
            LinkDefect(requirementId: requirementId, defectId: defectId),
          );
        }

        // Update test results
        _traceabilityMatrix.applyChange(
          UpdateTestResult(
            requirementId: requirementId,
            result: TestResult(
              testCaseId: '${report.businessType}_${check.name.name}',
              passed: check.passed,
              runAt: DateTime.now(),
            ),
          ),
        );
      }
    }

    // Persist the traceability matrix
    final matrixPath = '${config.outputPath}/traceability-matrix.md';
    await _traceabilityMatrix.persist(matrixPath);
  }

  // ─── Stage 6: DECIDE ───────────────────────────────────────────────────

  /// Validates the benchmark document if provided.
  BenchmarkValidation? _validateBenchmark(PipelineConfig config) {
    if (config.benchmarkDocument == null) return null;
    return _benchmarkValidator.validate(config.benchmarkDocument!);
  }

  /// Scans the Release_Build for mock data if a build path is provided.
  Future<MockScanResult?> _scanMockData(PipelineConfig config) async {
    if (config.releaseBuildPath == null) return null;

    final buildArtifact = _buildArtifactFromPath(config.releaseBuildPath!);
    return _mockDataScanner.scan(buildArtifact);
  }

  /// Runs the ProductionReadinessDecider with all gathered evidence.
  ReadinessDecision _decide(
    PipelineConfig config,
    Map<String, GateStatus> gateStatuses,
    MockScanResult? mockScanResult,
  ) {
    // Determine mock-data absence
    final mockDataAbsent = mockScanResult?.clean ?? false;

    // Gather unresolved defects (we'll check synchronously from cert reports)
    final unresolvedDefects = <Defect>[];

    // Determine unevaluatable items
    final unevaluatable = <String>{};
    if (config.performanceMeasurements == null) {
      unevaluatable.add('performance measurements');
    }
    if (config.securityCaseResults == null) {
      unevaluatable.add('security test cases');
    }
    if (config.regressionResults == null) {
      unevaluatable.add('regression test suite');
    }
    if (config.recordSet == null) {
      unevaluatable.add('data integrity records');
    }
    if (config.releaseBuildPath == null) {
      unevaluatable.add('mock data scan (no build path)');
    }

    final inputs = ReadinessInputs(
      mockDataAbsent: mockDataAbsent,
      debugFlagsAbsent: config.debugFlagsAbsent,
      envMatchesProduction: config.envMatchesProduction,
      crashFree: config.crashFree,
      gateStatuses: gateStatuses,
      unresolvedDefects: unresolvedDefects,
      unevaluatableItems: unevaluatable,
    );

    return _readinessDecider.decide(inputs);
  }

  // ─── Checklist Writer ──────────────────────────────────────────────────

  /// Writes the production-readiness-checklist.md deliverable.
  Future<void> _writeChecklist(
    String path,
    ReadinessDecision decision,
    Map<String, GateStatus> gateStatuses,
    SystemMap systemMap,
    List<CertificationReport> certReports,
    MockScanResult? mockScanResult,
    BenchmarkValidation? benchmarkValidation,
    PipelineConfig config,
  ) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('# Production Readiness Checklist');
    buffer.writeln();
    buffer.writeln(
      '> Auto-generated by CertificationPipeline on '
      '${DateTime.now().toIso8601String()}',
    );
    buffer.writeln();

    // Decision
    buffer.writeln('## Final Decision: ${decision.go ? 'GO ✅' : 'NO-GO ❌'}');
    buffer.writeln();

    if (!decision.go) {
      buffer.writeln('### Reasons for No-Go');
      buffer.writeln();
      for (final reason in decision.reasons) {
        buffer.writeln('- $reason');
      }
      buffer.writeln();
    }

    // Quality Gates
    buffer.writeln('## Quality Gates');
    buffer.writeln();
    buffer.writeln('| Gate | Status |');
    buffer.writeln('|------|--------|');
    for (final entry in gateStatuses.entries) {
      final status = entry.value == GateStatus.green
          ? '✅ Green'
          : '❌ Not Green';
      buffer.writeln('| ${entry.key} | $status |');
    }
    buffer.writeln();

    // Performance measurements
    if (config.performanceMeasurements != null) {
      buffer.writeln('## Performance Measurements');
      buffer.writeln();
      buffer.writeln(
        '| Metric | Measured | Threshold | Source | Dataset Records | Status |',
      );
      buffer.writeln(
        '|--------|----------|-----------|--------|-----------------|--------|',
      );
      for (final m in config.performanceMeasurements!) {
        final measuredStr = m.measured?.toString() ?? 'not measured';
        final thresholdStr = m.metric == 'fps'
            ? '>= ${m.threshold}'
            : '<= ${m.threshold}';
        final status = m.isWithinThreshold ? '✅' : '❌';
        buffer.writeln(
          '| ${m.metric} | $measuredStr | $thresholdStr | ${m.source.name} | ${m.datasetRecords} | $status |',
        );
      }
      buffer.writeln();
    }

    // Inventory scan summary
    buffer.writeln('## Inventory Scan Summary');
    buffer.writeln();
    buffer.writeln(
      '- Business Types detected: ${systemMap.businessTypes.length}',
    );
    buffer.writeln('- Screens mapped: ${systemMap.screens.length}');
    buffer.writeln('- Routes cataloged: ${systemMap.routes.length}');
    buffer.writeln('- Modules cataloged: ${systemMap.modules.length}');
    buffer.writeln(
      '- Backend calls detected: ${systemMap.backendCalls.length}',
    );
    buffer.writeln(
      '- DB access points detected: ${systemMap.dbAccessPoints.length}',
    );
    buffer.writeln(
      '- Mock data occurrences: ${systemMap.detectedMockData.length}',
    );
    buffer.writeln('- Coverage gaps: ${systemMap.coverageGaps.length}');
    buffer.writeln();

    // Coverage gaps
    if (systemMap.coverageGaps.isNotEmpty) {
      buffer.writeln('### Coverage Gaps');
      buffer.writeln();
      buffer.writeln('| Kind | Expected | Actual | Shortfall | Reason |');
      buffer.writeln('|------|----------|--------|-----------|--------|');
      for (final gap in systemMap.coverageGaps) {
        buffer.writeln(
          '| ${gap.kind} | ${gap.expected} | ${gap.actual} | ${gap.shortfall} | ${gap.reason ?? '—'} |',
        );
      }
      buffer.writeln();
    }

    // Certification reports summary
    buffer.writeln('## Certification Reports');
    buffer.writeln();
    buffer.writeln('| Business Type | Overall | Failed Checks |');
    buffer.writeln('|---------------|---------|---------------|');
    for (final report in certReports) {
      final overall = report.overallPass ? 'PASS ✅' : 'FAIL ❌';
      final failedChecks = report.checks
          .where((c) => !c.passed)
          .map((c) => c.name.name)
          .join(', ');
      buffer.writeln(
        '| ${report.businessType} | $overall | ${failedChecks.isEmpty ? '—' : failedChecks} |',
      );
    }
    buffer.writeln();

    // Mock data scan
    if (mockScanResult != null) {
      buffer.writeln('## Mock Data Scan');
      buffer.writeln();
      buffer.writeln('- Scan completed: ${mockScanResult.scanCompleted}');
      buffer.writeln(
        '- Result: ${mockScanResult.clean ? 'Clean ✅' : 'Mock data detected ❌'}',
      );
      buffer.writeln('- Occurrences: ${mockScanResult.occurrences.length}');
      buffer.writeln(
        '- Scan duration: ${mockScanResult.scanDuration.inMilliseconds}ms',
      );
      if (mockScanResult.errorMessage != null) {
        buffer.writeln('- Error: ${mockScanResult.errorMessage}');
      }
      buffer.writeln();
    }

    // Benchmark validation
    if (benchmarkValidation != null) {
      buffer.writeln('## Benchmark Validation');
      buffer.writeln();
      buffer.writeln(
        '- Status: ${benchmarkValidation.accepted ? 'Accepted ✅' : 'Rejected ❌'}',
      );
      if (!benchmarkValidation.accepted) {
        buffer.writeln('- Unmapped categories:');
        for (final cat in benchmarkValidation.unmappedCategories) {
          buffer.writeln('  - ${cat.name}');
        }
      }
      buffer.writeln();
    }

    // Environment checks
    buffer.writeln('## Environment Checks');
    buffer.writeln();
    buffer.writeln('| Check | Status |');
    buffer.writeln('|-------|--------|');
    buffer.writeln(
      '| Mock data absent | ${mockScanResult?.clean == true ? '✅' : '❌'} |',
    );
    buffer.writeln(
      '| Debug flags absent | ${config.debugFlagsAbsent ? '✅' : '❌'} |',
    );
    buffer.writeln(
      '| Environment matches production | ${config.envMatchesProduction ? '✅' : '❌'} |',
    );
    buffer.writeln(
      '| Crash-free operation | ${config.crashFree ? '✅' : '❌'} |',
    );
    buffer.writeln();

    // Write the file atomically
    await _artifactStore.write(path, buffer.toString(), append: false);
  }

  // ─── Private Helpers ───────────────────────────────────────────────────

  /// Maps a CheckName to a requirement ID for traceability linking.
  String _checkNameToRequirementId(CheckName name) {
    return switch (name) {
      CheckName.authAndOnboarding => '6.1.auth',
      CheckName.modulesInWorkflowOrder => '6.1.modules',
      CheckName.routeReachability => '6.2',
      CheckName.rolePermissionEnforcement => '6.3',
      CheckName.reportAndAnalyticsAccuracy => '6.4',
      CheckName.billingInventoryPersistence => '6.5',
    };
  }

  /// Constructs a BuildArtifact from a path by discovering source modules,
  /// assets, and config files.
  BuildArtifact _buildArtifactFromPath(String buildPath) {
    final rootDir = Directory(buildPath);
    final sourceModules = <String>[];
    final assets = <String>[];
    final configFiles = <String>[];

    if (!rootDir.existsSync()) {
      return BuildArtifact(
        rootPath: buildPath,
        sourceModules: sourceModules,
        assets: assets,
        configFiles: configFiles,
      );
    }

    // Walk the build directory to discover files
    for (final entity in rootDir.listSync(recursive: true)) {
      if (entity is! File) continue;

      final relativePath = entity.path
          .replaceAll('\\', '/')
          .replaceFirst(buildPath.replaceAll('\\', '/'), '')
          .replaceFirst(RegExp(r'^/'), '');

      // Skip test directories
      if (relativePath.contains('test/') ||
          relativePath.contains('_test.dart')) {
        continue;
      }

      if (relativePath.endsWith('.dart')) {
        sourceModules.add(relativePath);
      } else if (relativePath.startsWith('assets/') ||
          relativePath.endsWith('.json') ||
          relativePath.endsWith('.png') ||
          relativePath.endsWith('.svg')) {
        assets.add(relativePath);
      } else if (relativePath.endsWith('.yaml') ||
          relativePath.endsWith('.yml') ||
          relativePath.endsWith('.env') ||
          relativePath.endsWith('.properties')) {
        configFiles.add(relativePath);
      }
    }

    return BuildArtifact(
      rootPath: buildPath,
      sourceModules: sourceModules,
      assets: assets,
      configFiles: configFiles,
    );
  }

  /// Creates a default CertificationPass with a temporary base path.
  static CertificationPass _defaultCertificationPass() {
    return CertificationPass(
      basePath: Directory.current.path,
      defectStore: _defaultDefectStore(),
    );
  }

  /// Creates a default DefectStore with the current directory as base.
  static DefectStore _defaultDefectStore() {
    return DefectStore(basePath: Directory.current.path);
  }
}
