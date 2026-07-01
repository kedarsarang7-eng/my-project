/// CertificationPass — per-business-type certification orchestrator.
///
/// Runs the six certification checks for a single Business_Type (via [run]),
/// and orchestrates all 19 types with report generation (via [runAll]).
///
/// The six checks (Req 6.1):
/// 1. Authentication & Onboarding
/// 2. Modules in workflow order
/// 3. Route reachability
/// 4. Role permission enforcement
/// 5. Report & analytics accuracy (mismatch when |diff| > 0.01)
/// 6. Billing & inventory persistence
///
/// Reports are written to `reports/business-type-<name>.md` per type (Req 6.6),
/// with per-check PASS/FAIL, defect IDs, overall result, and service-only
/// omissions (Req 16.5). Exactly 19 reports are produced (Req 6.8).
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 16.5
library;

import 'dart:io';

import '../core/domain.dart';
import '../core/defect.dart';
import '../core/test_classifier.dart';
import 'artifact_store.dart';
import 'defect_store.dart';

// ---------------------------------------------------------------------------
// Check names and result types
// ---------------------------------------------------------------------------

/// The six certification checks run per business type (Req 6.1).
enum CheckName {
  authAndOnboarding,
  modulesInWorkflowOrder,
  routeReachability,
  rolePermissionEnforcement,
  reportAndAnalyticsAccuracy,
  billingInventoryPersistence,
}

/// Result of a single certification check.
class CheckResult {
  /// Which check this result belongs to.
  final CheckName name;

  /// Whether the check passed (no defects recorded).
  final bool passed;

  /// Defect IDs associated with this check's failures.
  final List<String> defectIds;

  const CheckResult({
    required this.name,
    required this.passed,
    required this.defectIds,
  });
}

/// Full certification report for one business type.
class CertificationReport {
  /// The business type this report covers.
  final String businessType;

  /// One result per CheckName (Req 6.1).
  final List<CheckResult> checks;

  /// FAIL if any check has ≥1 defect; PASS otherwise (Req 6.7).
  final bool overallPass;

  /// Service-only omissions with rationale (Req 16.5).
  final List<String> omittedTests;

  const CertificationReport({
    required this.businessType,
    required this.checks,
    required this.overallPass,
    required this.omittedTests,
  });
}

// ---------------------------------------------------------------------------
// Check runners — pluggable interfaces for the six checks.
// ---------------------------------------------------------------------------

/// Interface for running a single certification check.
///
/// Implementations perform the real work (network calls, DB queries, route
/// navigation, etc.). The default implementations return PASS with no defects
/// — they serve as stubs until the real Layer 3/4 test infrastructure is wired.
abstract class CertificationCheckRunner {
  /// Run the check for [businessType] and return any defect IDs.
  ///
  /// Returns an empty list if the check passes.
  Future<List<String>> run(BusinessType businessType);
}

/// Default pass-through check runner (returns no defects).
///
/// Used when the real check infrastructure is not yet wired. Each check
/// can be replaced with a real implementation by passing custom runners
/// to [CertificationPass].
class DefaultCheckRunner implements CertificationCheckRunner {
  const DefaultCheckRunner();

  @override
  Future<List<String>> run(BusinessType businessType) async => [];
}

// ---------------------------------------------------------------------------
// CertificationPass orchestrator
// ---------------------------------------------------------------------------

/// Per-business-type certification pass orchestrator.
///
/// Runs all six checks for one type via [run], or all 19 types via [runAll].
/// Records defects for failures and writes certification report markdown files.
class CertificationPass {
  /// Base path for output artifacts (reports, defects, etc.).
  final String basePath;

  /// Defect store for recording check failures.
  final DefectStore defectStore;

  /// Artifact store for atomic report writes.
  final ArtifactStore artifactStore;

  /// Test file classifier for service-only omissions.
  final TestFileClassifier testClassifier;

  /// Per-check runners. Keyed by [CheckName].
  final Map<CheckName, CertificationCheckRunner> _checkRunners;

  CertificationPass({
    required this.basePath,
    required this.defectStore,
    ArtifactStore? artifactStore,
    TestFileClassifier? testClassifier,
    Map<CheckName, CertificationCheckRunner>? checkRunners,
  }) : artifactStore = artifactStore ?? const ArtifactStore(),
       testClassifier = testClassifier ?? const TestFileClassifier(),
       _checkRunners =
           checkRunners ??
           {
             for (final check in CheckName.values)
               check: const DefaultCheckRunner(),
           };

  /// Runs all checks for a single [businessType], records defects for failures,
  /// and writes `reports/business-type-<name>.md` (Req 6.6).
  ///
  /// Returns a [CertificationReport] with per-check PASS/FAIL, defect IDs,
  /// overall result, and service-only omissions.
  Future<CertificationReport> run(BusinessType businessType) async {
    final checks = <CheckResult>[];

    for (final checkName in CheckName.values) {
      // For service-only types, skip billing/inventory persistence check
      // (they have no product or inventory scope — Req 16.5).
      if (kServiceOnlyTypes.contains(businessType) &&
          checkName == CheckName.billingInventoryPersistence) {
        checks.add(CheckResult(name: checkName, passed: true, defectIds: []));
        continue;
      }

      final runner = _checkRunners[checkName] ?? const DefaultCheckRunner();
      final defectIds = await runner.run(businessType);

      checks.add(
        CheckResult(
          name: checkName,
          passed: defectIds.isEmpty,
          defectIds: defectIds,
        ),
      );
    }

    // Overall: FAIL if any check has ≥1 defect (Req 6.7).
    final overallPass = checks.every((c) => c.passed);

    // Compute service-only omissions (Req 16.5).
    final omissions = _buildServiceOnlyOmissions(businessType);

    final report = CertificationReport(
      businessType: businessType.name,
      checks: checks,
      overallPass: overallPass,
      omittedTests: omissions,
    );

    // Write the certification report markdown (Req 6.6).
    await _writeReport(report);

    return report;
  }

  /// Runs all 19 business types → exactly 19 reports (Req 6.8).
  ///
  /// Iterates all [BusinessType] values, calls [run] for each, writes a
  /// certification report per type, and returns exactly 19 [CertificationReport]
  /// objects.
  Future<List<CertificationReport>> runAll() async {
    final reports = <CertificationReport>[];

    for (final businessType in BusinessType.values) {
      final report = await run(businessType);
      reports.add(report);
    }

    // Verify exactly 19 reports produced (Req 6.8).
    assert(reports.length == 19);
    return reports;
  }

  // ─── Report Accuracy Mismatch ─────────────────────────────────────────────

  /// Returns `true` if the absolute difference between [expected] and [actual]
  /// is greater than 0.01 (the report-accuracy mismatch threshold — Req 6.4).
  ///
  /// A mismatch triggers a Defect for the report/analytics check.
  static bool isMismatch(double expected, double actual) {
    return (actual - expected).abs() > 0.01;
  }

  // ─── Report Writer ──────────────────────────────────────────────────────

  /// Writes a certification report to `reports/business-type-<name>.md`.
  ///
  /// Format (Req 6.6):
  /// ```markdown
  /// # Certification Report: <business_type>
  ///
  /// ## Overall Result: PASS/FAIL
  ///
  /// ## Checks
  ///
  /// | Check | Result | Defect IDs |
  /// |-------|--------|------------|
  /// | Auth & Onboarding | PASS/FAIL | DEF-001, DEF-002 |
  /// ...
  ///
  /// ## Service-Only Omissions (if applicable)
  /// - <omitted test> — <rationale>
  /// ```
  Future<void> _writeReport(CertificationReport report) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('# Certification Report: ${report.businessType}');
    buffer.writeln();

    // Overall result
    buffer.writeln(
      '## Overall Result: ${report.overallPass ? 'PASS' : 'FAIL'}',
    );
    buffer.writeln();

    // Checks table
    buffer.writeln('## Checks');
    buffer.writeln();
    buffer.writeln('| Check | Result | Defect IDs |');
    buffer.writeln('|-------|--------|------------|');

    for (final check in report.checks) {
      final checkLabel = _checkNameToLabel(check.name);
      final result = check.passed ? 'PASS' : 'FAIL';
      final defects = check.defectIds.isNotEmpty
          ? check.defectIds.join(', ')
          : '—';
      buffer.writeln('| $checkLabel | $result | $defects |');
    }

    // Service-only omissions (if applicable, Req 16.5)
    if (report.omittedTests.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Service-Only Omissions');
      buffer.writeln();
      for (final omission in report.omittedTests) {
        buffer.writeln('- $omission');
      }
    }

    // Write the report file atomically.
    final reportPath =
        '$basePath/reports/business-type-${report.businessType}.md';
    await artifactStore.write(reportPath, buffer.toString(), append: false);
  }

  /// Converts a [CheckName] enum value to a human-readable label for reports.
  String _checkNameToLabel(CheckName name) {
    return switch (name) {
      CheckName.authAndOnboarding => 'Auth & Onboarding',
      CheckName.modulesInWorkflowOrder => 'Modules in Workflow Order',
      CheckName.routeReachability => 'Route Reachability',
      CheckName.rolePermissionEnforcement => 'Role Permission Enforcement',
      CheckName.reportAndAnalyticsAccuracy => 'Report & Analytics Accuracy',
      CheckName.billingInventoryPersistence =>
        'Billing & Inventory Persistence',
    };
  }

  // ─── Service-Only Omission Builder ──────────────────────────────────────

  /// Builds the list of service-only omission strings for a business type.
  ///
  /// For service-only types (service, clinic, schoolErp, decorationCatering),
  /// returns a list of omitted test descriptions with rationale.
  /// For non-service-only types, returns an empty list.
  List<String> _buildServiceOnlyOmissions(BusinessType businessType) {
    if (!kServiceOnlyTypes.contains(businessType)) {
      return [];
    }

    // Service-only types omit product and inventory tests (Req 16.5).
    return [
      'Inventory Tracking tests — ${businessType.name} is a Service_Only_Type with no product or inventory scope',
      'Supplier Management tests — ${businessType.name} is a Service_Only_Type with no product or inventory scope',
      'Billing & Inventory Persistence check (product assertions) — ${businessType.name} has no product/inventory capabilities',
    ];
  }
}
