/// CycleOrchestrator — drives exactly one Cycle per Business_Type and enforces
/// the "close-out before next" rule (at most one active Cycle at a time).
///
/// Executes the full pipeline per cycle:
///   inventory → analysis → prioritize → fix (via guard) → test → matrix →
///   sign-off → report
///
/// Requirements: 1.1, 1.7
library;

import '../models/audit_engine_models.dart';
import 'checklist_evaluator.dart';
import 'edit_scope_guard.dart';
import 'file_ownership_map.dart';
import 'finding_recorder.dart';
import 'fix_applier.dart';
import 'platform_matrix_builder.dart';
import 'prioritizer.dart';
import 'report_builder.dart';
import 'screen_inventory_builder.dart';
import 'sign_off_evaluator.dart';
import 'test_coordinator.dart';

// ---------------------------------------------------------------------------
// CycleConfig — per-cycle configuration bundle
// ---------------------------------------------------------------------------

/// Bundles per-cycle configuration that components need for a specific run.
///
/// Injected into [CycleOrchestrator] at construction time; provides the
/// [FixStrategy] callback and any run-specific overrides.
class CycleConfig {
  /// The fix strategy callback used by [FixApplier] to produce proposed fixes.
  final FixStrategy fixStrategy;

  /// Optional verification callback for shared-core widget changes.
  /// Defaults to optimistic (always-pass) when null.
  final bool Function(String widgetPath, BusinessType consumer)?
  verificationCallback;

  const CycleConfig({required this.fixStrategy, this.verificationCallback});
}

// ---------------------------------------------------------------------------
// CycleResult — wraps a completed cycle's output
// ---------------------------------------------------------------------------

/// The output of a completed [CycleOrchestrator.runCycle] invocation.
///
/// Wraps the full [CycleState] with accumulated data, the [SignOff] result,
/// and the [AuditReport] output.
class CycleResult {
  /// The full state accumulated during the cycle.
  final CycleState state;

  /// The sign-off evaluation result.
  final SignOff signOff;

  /// The audit report produced at the end of the cycle.
  final AuditReport report;

  const CycleResult({
    required this.state,
    required this.signOff,
    required this.report,
  });

  @override
  String toString() =>
      'CycleResult(${state.businessType.displayName}, '
      'signOff: ${signOff.isComplete})';
}

// ---------------------------------------------------------------------------
// CycleOrchestrator
// ---------------------------------------------------------------------------

/// Drives exactly one Cycle per Business_Type, enforcing sequential isolation.
///
/// Invariant: at most one active Cycle at a time (Req 1.1).
/// Progression: `canAdvance(r)` returns true only when `r.signOff.isComplete`
/// (Req 1.7), refusing to begin the next Business_Type until the current
/// cycle is done.
class CycleOrchestrator {
  // ─── Dependencies (constructor-injected for testability) ─────────────────

  final ScreenInventoryBuilder _inventoryBuilder;
  final EditScopeGuard _editScopeGuard;
  final ChecklistEvaluator _checklistEvaluator;
  final FindingRecorder _findingRecorder;
  final Prioritizer _prioritizer;
  final FixApplier _fixApplier;
  final TestCoordinator _testCoordinator;
  final PlatformMatrixBuilder _platformMatrixBuilder;
  final SignOffEvaluator _signOffEvaluator;
  final ReportBuilder _reportBuilder;
  final FileOwnershipMap _fileOwnershipMap;
  final CycleConfig _config;

  // ─── Internal state ──────────────────────────────────────────────────────

  /// Tracks the currently active cycle's Business_Type, or null if idle.
  BusinessType? _activeCycle;

  /// Creates a [CycleOrchestrator] with all required dependencies injected.
  CycleOrchestrator({
    required ScreenInventoryBuilder inventoryBuilder,
    required EditScopeGuard editScopeGuard,
    required ChecklistEvaluator checklistEvaluator,
    required FindingRecorder findingRecorder,
    required Prioritizer prioritizer,
    required FixApplier fixApplier,
    required TestCoordinator testCoordinator,
    required PlatformMatrixBuilder platformMatrixBuilder,
    required SignOffEvaluator signOffEvaluator,
    required ReportBuilder reportBuilder,
    required FileOwnershipMap fileOwnershipMap,
    required CycleConfig config,
  }) : _inventoryBuilder = inventoryBuilder,
       _editScopeGuard = editScopeGuard,
       _checklistEvaluator = checklistEvaluator,
       _findingRecorder = findingRecorder,
       _prioritizer = prioritizer,
       _fixApplier = fixApplier,
       _testCoordinator = testCoordinator,
       _platformMatrixBuilder = platformMatrixBuilder,
       _signOffEvaluator = signOffEvaluator,
       _reportBuilder = reportBuilder,
       _fileOwnershipMap = fileOwnershipMap,
       _config = config;

  /// Whether a cycle is currently active.
  bool get hasActiveCycle => _activeCycle != null;

  /// The currently active Business_Type, or null if idle.
  BusinessType? get activeCycle => _activeCycle;

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Returns `BusinessType.values` in declaration order (grocery → other).
  ///
  /// This is the deterministic traversal order for cycles.
  Iterable<BusinessType> cycleOrder() => BusinessType.values;

  /// Executes the full cycle pipeline for the given [active] Business_Type.
  ///
  /// Pipeline phases:
  ///   1. Screen Inventory (Req 2.1)
  ///   2. Per-Screen Analysis (checklist evaluation)
  ///   3. Prioritize findings by severity
  ///   4. Fix via FixApplier (through EditScopeGuard)
  ///   5. Test via TestCoordinator
  ///   6. Platform Matrix
  ///   7. Sign-Off evaluation
  ///   8. Report generation
  ///
  /// Throws [StateError] if another cycle is already active (Req 1.1).
  CycleResult runCycle(BusinessType active) {
    // ─── Enforce at most one active cycle (Req 1.1) ────────────────────────
    if (_activeCycle != null) {
      throw StateError(
        'Cannot start cycle for ${active.displayName}: '
        'a cycle for ${_activeCycle!.displayName} is already active. '
        'Complete the current cycle before starting a new one.',
      );
    }

    _activeCycle = active;

    try {
      // Reset per-cycle state in stateful components
      _findingRecorder.reset();
      _editScopeGuard.reset();
      _platformMatrixBuilder.reset();

      // ─── Phase 1: Screen Inventory (Req 2.1) ────────────────────────────
      final inventory = _inventoryBuilder.build(active);

      // ─── Phase 2: Per-Screen Analysis ───────────────────────────────────
      final analyses = <ScreenAnalysis>[];
      for (final screen in inventory.screens) {
        final analysis = _checklistEvaluator.analyze(screen);
        analyses.add(analysis);

        // Record findings from failed categories
        if (!analysis.blocked) {
          for (final stateEntry in analysis.results.entries) {
            for (final result in stateEntry.value) {
              if (result.status == CategoryStatus.fail) {
                _findingRecorder.record(
                  screen: screen,
                  category: result.category,
                  severity: _deriveSeverity(result.category),
                  description:
                      '${result.category.name} failure in '
                      '${stateEntry.key.name} state',
                  fileLine: '${screen.filePath}:0',
                );
              }
            }
          }
        }
      }

      // ─── Phase 3: Prioritize (Req 7.5, 7.6) ────────────────────────────
      final allFindings = _findingRecorder.findings;
      final prioritized = _prioritizer.orderForFixLog(allFindings);

      // ─── Phase 4: Fix via EditScopeGuard (Req 4.x) ─────────────────────
      final fixLog = <FixLogEntry>[];
      final blocked = <BlockedItem>[];
      final deferred = <DeferredItem>[];
      final sharedImpact = <SharedImpactNote>[];

      for (final finding in prioritized) {
        // Check edit scope before applying fix
        final scope = _editScopeGuard.classify(
          finding.fileLine.split(':').first,
          active,
          _fileOwnershipMap,
        );

        switch (scope) {
          case FileScope.activeVertical:
            // Allowed — apply fix
            final outcome = _fixApplier.apply(
              finding,
              strategy: _config.fixStrategy,
            );
            switch (outcome) {
              case FixSuccess(:final fixLogEntry):
                fixLog.add(fixLogEntry);
                finding.state = FindingState.resolved;
              case FixBlocked(:final blockedItem):
                blocked.add(blockedItem);
                finding.state = FindingState.blocked;
            }

          case FileScope.sharedCore:
            // Allowed with impact note — apply fix then verify consumers
            final outcome = _fixApplier.apply(
              finding,
              strategy: _config.fixStrategy,
            );
            switch (outcome) {
              case FixSuccess(:final fixLogEntry):
                fixLog.add(fixLogEntry);
                finding.state = FindingState.resolved;
                // Verify shared-core widget against consumers
                final filePath = finding.fileLine.split(':').first;
                final consumers = _fileOwnershipMap.getConsumers(filePath);
                final otherConsumers = consumers
                    .where((bt) => bt != active)
                    .toList();
                if (otherConsumers.isNotEmpty) {
                  final note = _editScopeGuard.verifyShared(
                    filePath,
                    otherConsumers,
                    verify: _config.verificationCallback,
                  );
                  sharedImpact.add(note);
                }
              case FixBlocked(:final blockedItem):
                blocked.add(blockedItem);
                finding.state = FindingState.blocked;
            }

          case FileScope.otherVerticalExclusive:
            // Rejected — defer to owning vertical's cycle
            final consumers = _fileOwnershipMap.getConsumers(
              finding.fileLine.split(':').first,
            );
            final targetBt = consumers.isNotEmpty ? consumers.first : null;
            blocked.add(
              BlockedItem(
                finding: finding,
                blockingReason: 'external-dependency',
                missingArtifact: finding.fileLine.split(':').first,
                actionToUnblock:
                    'Defer to the '
                    '${targetBt?.displayName ?? "owning"} '
                    "vertical's Cycle.",
                targetBusinessType: targetBt,
              ),
            );
            finding.state = FindingState.blocked;
        }
      }

      // Collect any additional blocked items from the guard
      for (final guardBlocked in _editScopeGuard.blockedItems) {
        if (!blocked.contains(guardBlocked)) {
          blocked.add(guardBlocked);
        }
      }

      // Collect shared impact notes from the guard
      for (final guardNote in _editScopeGuard.sharedImpactNotes) {
        if (!sharedImpact.contains(guardNote)) {
          sharedImpact.add(guardNote);
        }
      }

      // ─── Phase 5: Test via TestCoordinator (Req 5.7) ───────────────────
      final suiteRun = _testCoordinator.runSuite(active);
      final testLog = suiteRun.results;

      // ─── Phase 6: Platform Matrix (Req 6.8) ────────────────────────────
      final matrix = _platformMatrixBuilder.build();

      // ─── Assemble CycleState ────────────────────────────────────────────
      final cycleState = CycleState(
        businessType: active,
        inventory: inventory,
        findings: allFindings,
        fixLog: fixLog,
        testLog: testLog,
        sharedImpact: sharedImpact,
        matrix: matrix,
        blocked: blocked,
        deferred: deferred,
      );

      // ─── Phase 7: Sign-Off (Req 6.10, 1.7) ────────────────────────────
      final signOff = _signOffEvaluator.evaluate(cycleState);

      // ─── Phase 8: Report (Req 6.1–6.9) ────────────────────────────────
      final report = _reportBuilder.build(cycleState);

      return CycleResult(state: cycleState, signOff: signOff, report: report);
    } finally {
      // Always clear the active cycle flag so subsequent cycles can run.
      _activeCycle = null;
    }
  }

  /// Returns `true` only when [r.signOff.isComplete] (Req 1.7).
  ///
  /// The orchestrator refuses to begin the next Business_Type until the
  /// current cycle's sign-off is complete.
  bool canAdvance(CycleResult r) => r.signOff.isComplete;

  // ─── Private helpers ─────────────────────────────────────────────────────────

  /// Derives a default severity for a failed category result.
  ///
  /// This is a heuristic mapping; real severity is determined by
  /// the [ChecklistEvaluator]'s analysis and recorded via [FindingRecorder].
  Severity _deriveSeverity(ChecklistCategory category) {
    return switch (category) {
      ChecklistCategory.layoutAndOverflow => Severity.high,
      ChecklistCategory.hardcodedValues => Severity.medium,
      ChecklistCategory.responsivenessAndPlatformCoverage => Severity.high,
      ChecklistCategory.uiUxCorrectness => Severity.medium,
      ChecklistCategory.performance => Severity.low,
    };
  }
}
