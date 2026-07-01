// AUDIT_SYSTEM — ITERATION RUNNER / DRIVER (Task 21.1)
//
// The cohesive driver that connects the Audit_System's already-implemented,
// pure governance components into ONE Identify → Audit → Fix → Verify →
// Report-and-Advance loop (design "Iteration Execution Flow"). It is the single
// place the workflow phases are sequenced and the phase order (Req 2.1) and the
// "advance only when done" gate (Req 2.4, via the Advance Guard) are enforced.
//
// It wires together:
//   * ScreenEnumerator        — builds the selectable (Business_Type, Screen)
//                               universe (callers usually pass a prebuilt one).
//   * TargetSelector          — IDENTIFY: validate a single Iteration_Target;
//                               also owns the AdvanceDecision.
//   * IterationStateMachine   — forward-only status + strict phase ordering.
//   * AuditCategoryEvaluator  — AUDIT: 13-category coverage / phase status.
//   * GapRegistry             — admits the audit's Gaps (association contract).
//   * NavMappingAuditor       — optional sidebar→destination audit feeding the
//                               navigation Definition_Of_Done item.
//   * FixVerifyController      — FIX/VERIFY: bounded (≤3) fix-verify cycles.
//   * DefinitionOfDone        — evaluate the 10 DoD items.
//   * IterationReportStore    — persist the read-only Iteration_Report.
//   * CompletedRegistry       — running record of done Screens (each once).
//   * AdvanceGuard            — REPORT-AND-ADVANCE: permit advancement iff the
//                               Screen is genuinely done, else retain target.
//   * FinalChecklistEvaluator — cross-cutting readiness once everything is done.
//
// PURITY / TESTABILITY: the per-screen audit FINDINGS (which categories were
// evaluated, which Gaps exist, the runtime responsive/parity/license/sync/
// backend verification outcomes, and the fix→verify behaviour) are RUNTIME
// inputs produced by the reused verification harnesses — NOT re-implemented
// here. The driver accepts them as injected inputs ([IterationAudit]) and as a
// [VerifyFn] callback, so the loop stays deterministic and unit-testable. The
// only impure dependency is the [IterationReportStore] (JSON persistence),
// which is itself injectable for tests.
//
// Depends only on the Audit_System barrel — no Flutter, `dart:io`/`dart:convert`
// only transitively through the store — so it composes with the rest of the
// governance core exactly like `tool/responsive_audit.dart`.
//
// Part of: per-screen-business-type-audit-remediation (Task 21.1)
// _Requirements: 2.1, 2.4, 2.6, 2.8_

import 'audit_system.dart';

/// Optional sidebar/navigation audit inputs for an iteration.
///
/// When supplied, the driver runs [NavMappingAuditor.auditEntries] and derives
/// the navigation Definition_Of_Done item from the per-entry results (every
/// entry must pass). A navigation result explicitly provided in
/// [IterationAudit.runtimeDodResults] always takes precedence.
class NavAuditInput {
  const NavAuditInput({required this.entries, required this.registry});

  /// The Business_Type's Sidebar_Entries to audit.
  final List<SidebarEntry> entries;

  /// The active Route_Registry the entries resolve against.
  final RouteRegistry registry;
}

/// The injected per-Screen audit findings + verification inputs for one
/// iteration. These come from the audit work and the reused runtime
/// verification harnesses; the driver does NOT compute them itself.
class IterationAudit {
  const IterationAudit({
    required this.categoryResults,
    this.gaps = const <Gap>[],
    VerifyFn? verify,
    this.runtimeDodResults = const <DodItem, DodResult>{},
    this.nav,
  }) : verify = verify ?? _noFixVerify;

  /// The 13-category audit outcomes recorded for the Screen (Req 3.1, 3.2).
  final List<CategoryResult> categoryResults;

  /// The Gaps found during the Audit phase, each to be admitted to the
  /// [GapRegistry] before fix-verify (Req 3.3, 3.4).
  final List<Gap> gaps;

  /// The fix→verify callback driven by [FixVerifyController] (Req 2.5, 2.7).
  /// Defaults to a no-op that leaves every outstanding Gap unresolved, so a
  /// caller that supplies Gaps but no fixer correctly blocks advancement.
  final VerifyFn verify;

  /// The RUNTIME Definition_Of_Done results for items (c)..(j) — responsive,
  /// navigation, parity, license activation, sync/conflict, gating, backend,
  /// security/validation. Items (a) categories and (b) gaps are DERIVED by the
  /// driver from [categoryResults] + the post-fix Gaps (Req 14.4) and always
  /// override any value supplied here for those two items.
  final Map<DodItem, DodResult> runtimeDodResults;

  /// Optional sidebar/navigation audit inputs feeding the navigation DoD item.
  final NavAuditInput? nav;

  /// Default [VerifyFn]: applies no fix, so all outstanding Gaps remain.
  static List<Gap> _noFixVerify(List<Gap> outstanding, int cycle) =>
      outstanding;
}

/// The outcome of a single [AuditRunner.runIteration] call.
///
/// Carries the full trace of the one iteration: the Identify result, the
/// per-phase outcomes, the Definition_Of_Done classification, and — when the
/// Screen reached `done` and the report persisted — the persisted
/// [IterationReport] and the [AdvanceDecision] for the next move (Req 2.6, 2.8).
class IterationRunResult {
  IterationRunResult({
    required this.accepted,
    this.rejectionReason,
    this.target,
    required this.finalStatus,
    required this.phaseOrderValid,
    this.categoryResults = const <CategoryResult>[],
    this.auditPhaseStatus = AuditPhaseStatus.incomplete,
    this.gapAdmissions = const <GapAdmission>[],
    this.admittedGaps = const <Gap>[],
    this.fixVerifyOutcome,
    this.finalGaps = const <Gap>[],
    this.navResults = const <EntryAuditResult>[],
    this.doneClassification,
    this.guardDecision,
    this.report,
    this.persistResult,
    this.advanceDecision,
  });

  /// A short-circuit result for a rejected Identify (invalid target proposal).
  factory IterationRunResult.rejected(String reason) => IterationRunResult(
    accepted: false,
    rejectionReason: reason,
    finalStatus: IterationStatus.notStarted,
    phaseOrderValid: true,
  );

  /// True iff the proposed Iteration_Target was a valid single target and the
  /// iteration ran (Req 1.1, 1.3, 1.5).
  final bool accepted;

  /// Why Identify rejected the proposal; present iff not [accepted].
  final String? rejectionReason;

  /// The validated single Iteration_Target; present iff [accepted].
  final IterationTarget? target;

  /// The Iteration_Target status after the iteration. `done` only when every
  /// Definition_Of_Done item is satisfied (Req 14.1).
  final IterationStatus finalStatus;

  /// True iff the executed phase sequence honoured the strict workflow order
  /// Identify → Audit → Fix → Verify → Report-and-Advance (Req 2.1).
  final bool phaseOrderValid;

  /// The recorded per-category audit results.
  final List<CategoryResult> categoryResults;

  /// Whether all 13 Audit_Categories were covered (Req 3.6).
  final AuditPhaseStatus auditPhaseStatus;

  /// The admission outcome for every proposed Gap (Req 3.4).
  final List<GapAdmission> gapAdmissions;

  /// The Gaps that passed admission and entered fix-verify.
  final List<Gap> admittedGaps;

  /// The bounded Fix-Verify outcome (null when there were no admitted Gaps).
  final FixVerifyOutcome? fixVerifyOutcome;

  /// The admitted Gaps with their terminal status after fix-verify.
  final List<Gap> finalGaps;

  /// Per-entry navigation audit results (empty when no nav input supplied).
  final List<EntryAuditResult> navResults;

  /// The Definition_Of_Done classification for the Screen (Req 14.1, 14.2).
  final DoneClassification? doneClassification;

  /// The Advance Guard's decision: permitted (with [advanceDecision]) or
  /// blocked with the retained target + blocking items (Req 1.6, 1.7, 2.4).
  final AdvanceGuardDecision? guardDecision;

  /// The persisted, read-only Iteration_Report; present iff the Screen reached
  /// `done` and persistence succeeded (Req 2.6, 15.2).
  final IterationReport? report;

  /// The persistence outcome; present iff a report was produced (Req 2.9, 15.5).
  final PersistResult? persistResult;

  /// The next move once advancement is permitted AND the report persisted;
  /// null when advancement is blocked or persistence failed (Req 2.8, 15.3).
  final AdvanceDecision? advanceDecision;

  /// True iff the Screen was classified `done` this iteration.
  bool get done => doneClassification?.done ?? false;

  /// True iff the Screen is `done` AND its report persisted, so the
  /// Completed-Screens record was committed and the loop may advance.
  bool get committedDone => done && (persistResult?.succeeded ?? false);

  /// True iff advancement to the next Iteration_Target is blocked (Req 1.7).
  bool get advancementBlocked => !committedDone;

  @override
  String toString() {
    if (!accepted) return 'IterationRunResult.rejected($rejectionReason)';
    return 'IterationRunResult($target, status: $finalStatus, '
        'done: $done, committed: $committedDone)';
  }
}

/// The outcome of [AuditRunner.runUntilComplete]: every iteration that ran, the
/// final advance decision, and — when every Screen is done — the
/// Final_Validation_Checklist result (Req 16.*).
class RunUntilResult {
  RunUntilResult({
    required List<IterationRunResult> iterations,
    required this.finalDecision,
    this.finalValidation,
    required this.stalled,
  }) : iterations = List<IterationRunResult>.unmodifiable(iterations);

  /// Every iteration executed, in order.
  final List<IterationRunResult> iterations;

  /// The advance decision after the loop stopped: `noTargetsRemain` when the
  /// universe is fully remediated, otherwise the next outstanding target
  /// (present when the loop stalled on a blocked Screen).
  final AdvanceDecision finalDecision;

  /// The Final_Validation_Checklist result, present iff every Screen is done
  /// (Req 16.1). Null while any Screen is still outstanding.
  final FinalValidationResult? finalValidation;

  /// True iff the loop stopped because a Screen could not be completed
  /// (advancement blocked) rather than because no targets remain.
  final bool stalled;

  @override
  String toString() =>
      'RunUntilResult(${iterations.length} iteration(s), '
      'remaining: ${finalDecision.noTargetsRemain ? 'none' : finalDecision.nextTarget}, '
      'stalled: $stalled)';
}

/// Drives the single-target audit-and-remediation loop end to end.
///
/// Holds the two pieces of mutable governance STATE — the Completed-Screens
/// registry and the Iteration_Report store — and reuses the stateless, pure
/// components for every decision. Construct once and call [runIteration] per
/// target, or [runUntilComplete] to process the whole universe.
class AuditRunner {
  AuditRunner({
    CompletedRegistry? completedRegistry,
    IterationReportStore? reportStore,
    this.selector = const TargetSelector(),
    this.stateMachine = const IterationStateMachine(),
    this.definitionOfDone = const DefinitionOfDone(),
    this.navAuditor = const NavMappingAuditor(),
    this.advanceGuard = const AdvanceGuard(),
    this.finalChecklist = const FinalChecklistEvaluator(),
    FixVerifyController? fixVerifyController,
  }) : completedRegistry = completedRegistry ?? CompletedRegistry(),
       reportStore = reportStore ?? IterationReportStore(),
       fixVerify = fixVerifyController ?? FixVerifyController();

  /// The running record of done Screens (each Screen at most once per type).
  final CompletedRegistry completedRegistry;

  /// Persists each `done` iteration's read-only Iteration_Report.
  final IterationReportStore reportStore;

  final TargetSelector selector;
  final IterationStateMachine stateMachine;
  final DefinitionOfDone definitionOfDone;
  final NavMappingAuditor navAuditor;
  final AdvanceGuard advanceGuard;
  final FinalChecklistEvaluator finalChecklist;
  final FixVerifyController fixVerify;

  /// Run ONE full iteration over a single proposed target.
  ///
  /// Phases run strictly in order (Req 2.1):
  ///   1. IDENTIFY  — validate the [proposal] to exactly one Iteration_Target;
  ///      a rejected proposal short-circuits with the reason and changes
  ///      nothing (Req 1.1, 1.3, 1.5).
  ///   2. AUDIT     — record the 13-category coverage and admit the Gaps.
  ///   3. FIX/VERIFY— run ≤3 bounded fix-verify cycles over the admitted Gaps.
  ///   4. VERIFY    — derive DoD items (a)/(b) and merge the runtime DoD
  ///      results, then classify against the Definition_Of_Done.
  ///   5. REPORT-AND-ADVANCE — when `done`, persist the Iteration_Report,
  ///      commit the Completed-Screens record, and compute the AdvanceDecision
  ///      through the Advance Guard; when not done, advancement is blocked and
  ///      the current target is retained (Req 1.6, 1.7, 2.4, 2.6, 2.8).
  IterationRunResult runIteration({
    required TargetProposal proposal,
    required ScreenUniverse universe,
    required IterationAudit audit,
    required String iterationId,
    DateTime? timestamp,
  }) {
    // --- PHASE 1: IDENTIFY ---------------------------------------------------
    final selection = selector.select(proposal, universe);
    if (!selection.accepted) {
      // Leave everything unchanged; require a valid single target (Req 1.3, 1.5).
      return IterationRunResult.rejected(selection.rejectionReason!);
    }
    final target = selection.target!;
    final executedPhases = <WorkflowPhase>[WorkflowPhase.identify];

    // --- PHASE 2: AUDIT ------------------------------------------------------
    var status = _advance(IterationStatus.notStarted, IterationStatus.inAudit);
    executedPhases.add(WorkflowPhase.audit);

    final auditPhaseStatus = AuditCategoryEvaluator.phaseStatus(
      audit.categoryResults,
    );

    // Admit each proposed Gap through the registry's association boundary.
    final registry = GapRegistry();
    final admissions = <GapAdmission>[];
    final admittedGaps = <Gap>[];
    for (final gap in audit.gaps) {
      final admission = registry.admit(gap);
      admissions.add(admission);
      if (admission.admitted) admittedGaps.add(admission.gap!);
    }

    // Optional sidebar/navigation audit (Req 6.1, 6.2, 6.4).
    final navResults = audit.nav == null
        ? const <EntryAuditResult>[]
        : navAuditor.auditEntries(audit.nav!.entries, audit.nav!.registry);

    // --- PHASE 3: FIX / VERIFY ----------------------------------------------
    status = _advance(status, IterationStatus.inFix);
    executedPhases.add(WorkflowPhase.fix);

    final fixOutcome = admittedGaps.isEmpty
        ? null
        : fixVerify.run(admittedGaps, audit.verify);
    final finalGaps = fixOutcome?.finalGaps ?? const <Gap>[];

    status = _advance(status, IterationStatus.inVerification);
    executedPhases.add(WorkflowPhase.verify);

    // --- PHASE 4: DEFINITION-OF-DONE ----------------------------------------
    // Items (a) categories + (b) gaps are derived from the evidence (Req 14.4);
    // items (c)..(j) come from the injected runtime verification results; a
    // navigation result is derived from the nav audit unless the caller set one.
    final derivedAB = definitionOfDone.deriveAB(
      audit.categoryResults,
      finalGaps,
    );
    final navDerived = <DodItem, DodResult>{};
    if (audit.nav != null) {
      final navPass = navResults.every((r) => r.passed);
      navDerived[DodItem.navigation] = navPass
          ? DodResult.pass
          : DodResult.unmet;
    }
    final mergedResults = <DodItem, DodResult>{
      ...navDerived,
      ...audit.runtimeDodResults,
      ...derivedAB, // (a)/(b) always win — derived from the audit evidence.
    };

    final classification = definitionOfDone.classify(mergedResults);

    // Record each DoD result with an ISO-8601 timestamp (Req 14.3).
    final ts = (timestamp ?? DateTime.now()).toUtc().toIso8601String();
    final dodRecords = <DodItem, DodResultRecord>{
      for (final entry in mergedResults.entries)
        entry.key: DodResultRecord(result: entry.value, timestamp: ts),
    };

    // Move to `done` only when the Definition_Of_Done is fully satisfied.
    if (classification.done) {
      status = _advance(status, IterationStatus.done);
    }
    executedPhases.add(WorkflowPhase.reportAndAdvance);
    final phaseOrderValid = stateMachine.phaseOrderValid(executedPhases);

    // --- PHASE 5: REPORT AND ADVANCE ----------------------------------------
    if (!classification.done) {
      // Not done: advancement is blocked and the current target is retained as
      // active (Req 1.7, 2.4). No report is persisted.
      final guard = advanceGuard.evaluate(
        currentStatus: status,
        dod: classification,
        currentTarget: target,
      );
      return IterationRunResult(
        accepted: true,
        target: target,
        finalStatus: status,
        phaseOrderValid: phaseOrderValid,
        categoryResults: audit.categoryResults,
        auditPhaseStatus: auditPhaseStatus,
        gapAdmissions: admissions,
        admittedGaps: admittedGaps,
        fixVerifyOutcome: fixOutcome,
        finalGaps: finalGaps,
        navResults: navResults,
        doneClassification: classification,
        guardDecision: guard,
      );
    }

    // Done: compute the advance decision on a CLONE of the registry that treats
    // this Screen as done, so a persistence failure leaves the real
    // Completed-Screens record untouched (Req 2.9, 15.5).
    final projected = CompletedRegistry.fromJson(completedRegistry.toJson());
    projected.recordDone(target.businessType, target.screenPath);
    final guard = advanceGuard.evaluateAdvance(
      currentStatus: status,
      dod: classification,
      currentTarget: target,
      registry: projected,
      universe: universe,
      selector: selector,
    );
    final projectedAdvance = guard.advance!; // permitted ⇒ non-null.

    // Build fix records: each admitted Gap with its verification outcome
    // (Req 15.1) — resolved ⇒ pass, unresolved ⇒ fail.
    final fixes = finalGaps
        .map(
          (g) => AppliedFix(
            gapId: g.id,
            verification: g.status == GapStatus.resolved ? 'pass' : 'fail',
          ),
        )
        .toList(growable: false);

    final report = IterationReport(
      iterationId: iterationId,
      businessType: target.businessType,
      screenPath: target.screenPath,
      categoryResults: audit.categoryResults,
      gaps: finalGaps,
      dodResults: dodRecords,
      fixes: fixes,
      advanceDecision: projectedAdvance,
    );

    // Persist the read-only record (Req 2.6, 15.2).
    final persist = reportStore.persist(report);

    if (!persist.succeeded) {
      // Persistence failed: do NOT advance, retain the target active, and leave
      // the Completed-Screens record unchanged (Req 2.9, 15.5).
      return IterationRunResult(
        accepted: true,
        target: target,
        finalStatus: status,
        phaseOrderValid: phaseOrderValid,
        categoryResults: audit.categoryResults,
        auditPhaseStatus: auditPhaseStatus,
        gapAdmissions: admissions,
        admittedGaps: admittedGaps,
        fixVerifyOutcome: fixOutcome,
        finalGaps: finalGaps,
        navResults: navResults,
        doneClassification: classification,
        guardDecision: guard,
        report: report,
        persistResult: persist,
      );
    }

    // Persisted: commit the done Screen to the real Completed-Screens record
    // (Req 15.4) and report the advance decision (Req 2.8, 15.3).
    completedRegistry.recordDone(target.businessType, target.screenPath);

    return IterationRunResult(
      accepted: true,
      target: target,
      finalStatus: status,
      phaseOrderValid: phaseOrderValid,
      categoryResults: audit.categoryResults,
      auditPhaseStatus: auditPhaseStatus,
      gapAdmissions: admissions,
      admittedGaps: admittedGaps,
      fixVerifyOutcome: fixOutcome,
      finalGaps: finalGaps,
      navResults: navResults,
      doneClassification: classification,
      guardDecision: guard,
      report: report,
      persistResult: persist,
      advanceDecision: projectedAdvance,
    );
  }

  /// Run iterations until no targets remain or the loop stalls on a Screen that
  /// cannot be completed.
  ///
  /// Targets are chosen by the [TargetSelector.advance] decision (regression
  /// reopens first, then the next not-done Screen in the universe's
  /// deterministic order). For each target the [auditProvider] supplies that
  /// Screen's injected audit findings + verification inputs. The loop stops when
  /// the advance decision reports no targets remain, when [maxIterations] is hit,
  /// or when an iteration leaves a Screen not-done (it would otherwise reselect
  /// the same target forever).
  ///
  /// When every Screen is done, the Final_Validation_Checklist is evaluated over
  /// all persisted reports (Req 16.1) and returned in [RunUntilResult].
  RunUntilResult runUntilComplete({
    required ScreenUniverse universe,
    required IterationAudit Function(IterationTarget target) auditProvider,
    int maxIterations = 1000,
    DateTime Function()? clock,
  }) {
    final results = <IterationRunResult>[];
    var counter = 0;
    var stalled = false;

    while (results.length < maxIterations) {
      final decision = selector.advance(completedRegistry, universe);
      if (decision.noTargetsRemain) break;

      final target = decision.nextTarget!;
      counter++;
      final id = 'iter-${counter.toString().padLeft(4, '0')}';
      final audit = auditProvider(target);

      final run = runIteration(
        proposal: TargetProposal(
          businessTypes: <String>[target.businessType],
          screens: <String>[target.screenPath],
        ),
        universe: universe,
        audit: audit,
        iterationId: id,
        timestamp: clock?.call(),
      );
      results.add(run);

      // A Screen that did not commit `done` will be reselected next loop — stop
      // to avoid an infinite loop and surface the stall (Req 2.4 advance-gate).
      if (!run.committedDone) {
        stalled = true;
        break;
      }
    }

    final allDone = completedRegistry.allDone(universe);
    final finalValidation = allDone
        ? finalChecklist.evaluate(reportStore.findBy(), universe)
        : null;

    return RunUntilResult(
      iterations: results,
      finalDecision: selector.advance(completedRegistry, universe),
      finalValidation: finalValidation,
      stalled: stalled,
    );
  }

  /// Apply a forward status transition, throwing if the state machine rejects
  /// it. The driver only ever requests legal one-step-forward transitions, so a
  /// rejection here signals a programming error rather than a workflow state.
  IterationStatus _advance(IterationStatus from, IterationStatus to) {
    final result = stateMachine.transition(from, to);
    if (!result.permitted) {
      throw StateError(
        'Illegal iteration transition $from -> $to: ${result.rejectionReason}',
      );
    }
    return result.status;
  }
}
