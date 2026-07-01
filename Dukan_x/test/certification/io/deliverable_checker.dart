/// DeliverableChecker — verifies all required deliverables exist and are non-empty.
///
/// Checks each required artifact produced by the Certification_System. If any
/// deliverable is absent or empty, records a Defect and marks certification as
/// incomplete. The required deliverables are:
///
/// 1. `inventory/system-map.md` — System map from the Inventory_Scanner
/// 2. `reports/business-type-<name>.md` × 19 — One certification report per business type
/// 3. `defects/` — Defects directory (may be empty if no defects)
/// 4. `traceability-matrix.md` — The traceability matrix
/// 5. `benchmark/industry-standards.md` — Industry benchmark document
/// 6. `production-readiness-checklist.md` — Final go/no-go checklist
///
/// Requirements: 16.1, 16.2
library;

import 'dart:io';

import '../core/defect.dart';
import '../core/domain.dart';

/// Result of checking a single deliverable.
class DeliverableCheck {
  /// Relative path of the deliverable (from the base path).
  final String path;

  /// Whether the deliverable exists on disk.
  final bool exists;

  /// Whether the deliverable is non-empty (has content).
  /// For directories, this is true if the directory exists (even if empty).
  final bool nonEmpty;

  /// Non-null if the deliverable is missing or empty — the ID of the recorded defect.
  final String? defectId;

  const DeliverableCheck({
    required this.path,
    required this.exists,
    required this.nonEmpty,
    this.defectId,
  });
}

/// Aggregate result of checking all required deliverables.
class DeliverableCheckResult {
  /// Individual check results for each required deliverable.
  final List<DeliverableCheck> checks;

  /// False if any deliverable is missing or empty — certification is incomplete.
  final bool certificationComplete;

  /// Defects recorded for missing/empty deliverables.
  final List<Defect> defects;

  const DeliverableCheckResult({
    required this.checks,
    required this.certificationComplete,
    required this.defects,
  });
}

/// Verifies all required deliverables exist and are non-empty.
///
/// Records a defect for each missing/empty deliverable and marks certification
/// incomplete if any are absent. Iterates all 19 [BusinessType] enum values to
/// verify business-type reports exist.
class DeliverableChecker {
  /// Counter for generating unique defect IDs within a check run.
  int _defectCounter = 0;

  /// Verify all required deliverables exist and are non-empty.
  ///
  /// [basePath] is the root directory where deliverables are expected
  /// (e.g., the certification output directory).
  ///
  /// Returns [DeliverableCheckResult] with per-deliverable results, the overall
  /// certification completeness flag, and any defects recorded.
  Future<DeliverableCheckResult> check(String basePath) async {
    _defectCounter = 0;
    final checks = <DeliverableCheck>[];
    final defects = <Defect>[];

    // 1. System map
    await _checkFile(
      basePath: basePath,
      relativePath: 'inventory/system-map.md',
      description: 'System map from the Inventory_Scanner',
      checks: checks,
      defects: defects,
    );

    // 2. One certification report per business type (19 total)
    for (final type in BusinessType.values) {
      await _checkFile(
        basePath: basePath,
        relativePath: 'reports/business-type-${type.name}.md',
        description: 'Certification report for business type "${type.name}"',
        checks: checks,
        defects: defects,
      );
    }

    // 3. Defects directory (must exist; may be empty if no defects)
    await _checkDirectory(
      basePath: basePath,
      relativePath: 'defects',
      description: 'Defects directory',
      checks: checks,
      defects: defects,
    );

    // 4. Traceability matrix
    await _checkFile(
      basePath: basePath,
      relativePath: 'traceability-matrix.md',
      description: 'Traceability matrix',
      checks: checks,
      defects: defects,
    );

    // 5. Industry benchmark document
    await _checkFile(
      basePath: basePath,
      relativePath: 'benchmark/industry-standards.md',
      description: 'Industry benchmark document',
      checks: checks,
      defects: defects,
    );

    // 6. Production readiness checklist
    await _checkFile(
      basePath: basePath,
      relativePath: 'production-readiness-checklist.md',
      description: 'Production readiness checklist',
      checks: checks,
      defects: defects,
    );

    // Certification is complete only if all checks passed (no defects).
    final certificationComplete = defects.isEmpty;

    return DeliverableCheckResult(
      checks: checks,
      certificationComplete: certificationComplete,
      defects: defects,
    );
  }

  /// Checks a single file deliverable for existence and non-empty content.
  Future<void> _checkFile({
    required String basePath,
    required String relativePath,
    required String description,
    required List<DeliverableCheck> checks,
    required List<Defect> defects,
  }) async {
    final fullPath = '$basePath/$relativePath';
    final file = File(fullPath);
    final fileExists = await file.exists();

    bool nonEmpty = false;
    if (fileExists) {
      final length = await file.length();
      nonEmpty = length > 0;
    }

    String? defectId;
    if (!fileExists || !nonEmpty) {
      defectId = _recordDefect(
        relativePath: relativePath,
        description: description,
        exists: fileExists,
        defects: defects,
      );
    }

    checks.add(
      DeliverableCheck(
        path: relativePath,
        exists: fileExists,
        nonEmpty: nonEmpty,
        defectId: defectId,
      ),
    );
  }

  /// Checks a directory deliverable for existence.
  ///
  /// Directories only need to exist; they may be empty (e.g., defects/ when
  /// no defects have been recorded). However, if the directory doesn't exist,
  /// a defect is recorded.
  Future<void> _checkDirectory({
    required String basePath,
    required String relativePath,
    required String description,
    required List<DeliverableCheck> checks,
    required List<Defect> defects,
  }) async {
    final fullPath = '$basePath/$relativePath';
    final dir = Directory(fullPath);
    final dirExists = await dir.exists();

    String? defectId;
    if (!dirExists) {
      defectId = _recordDefect(
        relativePath: relativePath,
        description: description,
        exists: false,
        defects: defects,
      );
    }

    checks.add(
      DeliverableCheck(
        path: relativePath,
        exists: dirExists,
        // Directories are considered non-empty if they exist (even if empty).
        nonEmpty: dirExists,
        defectId: defectId,
      ),
    );
  }

  /// Records a defect for a missing or empty deliverable and returns the defect ID.
  String _recordDefect({
    required String relativePath,
    required String description,
    required bool exists,
    required List<Defect> defects,
  }) {
    _defectCounter++;
    final defectId = 'DEF-DLVR-${_defectCounter.toString().padLeft(4, '0')}';

    final issue = exists ? 'is empty' : 'is missing';
    final defect = Defect(
      id: defectId,
      severity: Severity.high,
      reproSteps: [
        'Run certification pipeline to completion',
        'Check deliverable "$relativePath": $description $issue',
      ],
      status: ResolutionStatus.open,
      category: GapCategory.missingRequirement,
    );

    defects.add(defect);
    return defectId;
  }
}
