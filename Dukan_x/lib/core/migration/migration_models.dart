// ============================================================================
// Migration Engine — Shared Models
// ============================================================================

/// Eight migration steps. Progress is emitted in this order.
enum MigrationStep {
  preFlight,       // Step 1 — parallel health checks
  warningGate,     // Step 2 — user confirmation (UI-only, engine waits)
  dataAudit,       // Step 3 — count local records + files
  identityMigrate, // Step 4 — provision cloud user accounts
  databaseMigrate, // Step 5 — export Drift → Lambda/DynamoDB
  fileMigrate,     // Step 6 — upload local blobs → S3
  verification,    // Step 7 — count + checksum verification
  cutover,         // Step 8 — license conversion + atomic config write
}

extension MigrationStepX on MigrationStep {
  String get label => switch (this) {
        MigrationStep.preFlight => 'Pre-flight check',
        MigrationStep.warningGate => 'Confirmation',
        MigrationStep.dataAudit => 'Data audit',
        MigrationStep.identityMigrate => 'Identity migration',
        MigrationStep.databaseMigrate => 'Database migration',
        MigrationStep.fileMigrate => 'File migration',
        MigrationStep.verification => 'Verification',
        MigrationStep.cutover => 'Cutover',
      };

  int get index => MigrationStep.values.indexOf(this);
}

enum MigrationStatus { idle, running, waitingForUser, completed, failed, rolledBack }

class MigrationProgress {
  final MigrationStep step;
  final MigrationStatus status;
  final String message;
  final double stepProgress; // 0.0–1.0 within current step
  final Map<String, dynamic> metadata;

  const MigrationProgress({
    required this.step,
    required this.status,
    required this.message,
    this.stepProgress = 0,
    this.metadata = const {},
  });

  double get overallProgress =>
      (step.index + stepProgress) / MigrationStep.values.length;
}

class AuditReport {
  final Map<String, int> tableCounts;   // table name → row count
  final int fileCount;
  final int fileSizeBytes;
  final int userCount;
  final int conflictCount;
  final Duration estimatedMigrationTime;

  const AuditReport({
    required this.tableCounts,
    required this.fileCount,
    required this.fileSizeBytes,
    required this.userCount,
    this.conflictCount = 0,
    required this.estimatedMigrationTime,
  });
}

class PreFlightCheck {
  final String name;
  final bool passed;
  final String? failureReason;
  const PreFlightCheck(this.name, {required this.passed, this.failureReason});
}

class PreFlightResult {
  final List<PreFlightCheck> checks;
  bool get allPassed => checks.every((c) => c.passed);
  List<PreFlightCheck> get failures => checks.where((c) => !c.passed).toList();
  const PreFlightResult(this.checks);
}

class MigrationResult {
  final bool success;
  final String? errorMessage;
  final MigrationStep? failedAtStep;
  final bool wasRolledBack;

  const MigrationResult({
    required this.success,
    this.errorMessage,
    this.failedAtStep,
    this.wasRolledBack = false,
  });

  factory MigrationResult.success() => const MigrationResult(success: true);
  factory MigrationResult.failure(
    MigrationStep step,
    String message, {
    bool rolledBack = false,
  }) => MigrationResult(
        success: false,
        errorMessage: message,
        failedAtStep: step,
        wasRolledBack: rolledBack,
      );
}

class MigrationException implements Exception {
  final MigrationStep step;
  final String message;
  const MigrationException(this.step, this.message);
  @override
  String toString() => 'MigrationException(${step.label}): $message';
}
