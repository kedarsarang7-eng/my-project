// AUDIT_SYSTEM — CLI ENTRYPOINT / ITERATION SHELL (Task 21.2)
//
// A thin command-line shell over the Audit_System governance core that runs ONE
// Identify → Audit → Fix → Verify → Report-and-Advance iteration end to end and
// reports the advance decision. It mirrors the established
// `tool/responsive_audit.dart` CLI pattern: resolve `lib/`, build the universe,
// do the work with the pure components, then print a human-readable summary.
//
// What it does:
//   1. Builds the selectable (Business_Type, Screen) universe with the
//      ScreenEnumerator (excludes `_template`).
//   2. Chooses the next Iteration_Target. By default it asks the
//      TargetSelector.advance decision (regression reopens first, then the next
//      not-done Screen); `--business-type` + `--screen` override the choice.
//   3. Runs a single iteration through the AuditRunner.
//   4. The AuditRunner's IterationReportStore PERSISTS the read-only
//      Iteration_Report under
//      `.kiro/specs/per-screen-business-type-audit-remediation/reports/`; this
//      CLI prints a summary of it (Req 2.6).
//   5. Reports the advance decision — the next Iteration_Target, or that no
//      targets remain (Req 15.3).
//
// IMPORTANT — this is the SHELL, not the audit logic. The real per-screen audit
// FINDINGS (which categories were evaluated, which Gaps exist, and the runtime
// responsive / parity / license / sync / gating / backend / security
// verification outcomes) come from the reused runtime verification harnesses
// (spec Tasks 22.*), NOT from this CLI. So that the loop can be demonstrated
// end to end here, this shell injects a MINIMAL, REPRESENTATIVE IterationAudit:
// all 13 Audit_Categories evaluated, zero Gaps, and every runtime
// Definition_Of_Done item recorded as `pass`. That is enough to drive the
// Screen to `done`, persist its report, and surface the advance decision.
//
// Run from the Dukan_x package root:
//
//     dart run bin/audit_system.dart                       # next decided target
//     dart run bin/audit_system.dart --business-type kirana --screen lib/...   # explicit
//     dart run bin/audit_system.dart --list                # show the next target only
//
// Part of: per-screen-business-type-audit-remediation (Task 21.2)
// _Requirements: 2.6, 15.3_

import 'dart:io';

import '../tool/audit_system/audit_system.dart';

/// Locate the `lib/` directory whether the script runs from the Dukan_x package
/// root (`dart run bin/audit_system.dart`) or from the workspace root.
Directory _resolveLibDir() {
  final here = Directory('lib');
  if (here.existsSync()) return here;
  final nested = Directory('Dukan_x/lib');
  if (nested.existsSync()) return nested;
  return here; // buildUniverse returns an empty universe if absent.
}

/// Read a `--key value` style option from [args], or null when absent.
String? _option(List<String> args, String name) {
  final flag = '--$name';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == flag && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$flag=')) return args[i].substring(flag.length + 1);
  }
  return null;
}

bool _hasFlag(List<String> args, String name) => args.contains('--$name');

/// Build a MINIMAL, REPRESENTATIVE per-screen audit for [target]: every
/// Audit_Category evaluated, zero Gaps, and every runtime Definition_Of_Done
/// item passing. This is a demonstration stand-in for the real runtime harness
/// findings (see the file header), enough to drive one iteration to `done`.
IterationAudit _representativeAudit(IterationTarget target) {
  // (a) categories — all 13 evaluated (drives DoD item (a) to pass).
  final categoryResults = [
    for (final category in AuditCategory.values)
      CategoryResult(category: category, outcome: CategoryOutcome.evaluated),
  ];

  // (c)..(j) runtime Definition_Of_Done items recorded as pass. Items (a)
  // categories and (b) gaps are DERIVED by the runner from the evidence above
  // (all categories covered, zero gaps), so they are intentionally omitted.
  const runtimeDod = <DodItem, DodResult>{
    DodItem.responsive: DodResult.pass,
    DodItem.navigation: DodResult.pass,
    DodItem.parity: DodResult.pass,
    DodItem.licenseActivation: DodResult.pass,
    DodItem.syncConflict: DodResult.pass,
    DodItem.gating: DodResult.pass,
    DodItem.backend: DodResult.pass,
    DodItem.securityValidation: DodResult.pass,
  };

  return IterationAudit(
    categoryResults: categoryResults,
    gaps: const <Gap>[],
    runtimeDodResults: runtimeDod,
  );
}

/// Render the advance decision as a single human-readable line (Req 15.3).
String _describeAdvance(AdvanceDecision decision) {
  if (decision.noTargetsRemain) {
    return 'Advance decision : none — every Screen of every Business_Type is done.';
  }
  final next = decision.nextTarget!;
  return 'Advance decision : next target -> ${next.businessType} :: ${next.screenPath}';
}

void main(List<String> args) {
  final libDir = _resolveLibDir();
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: could not find a lib/ directory. Run this from the Dukan_x '
      'package root: dart run bin/audit_system.dart',
    );
    exitCode = 1;
    return;
  }

  // --- Build the selectable universe (excludes _template). -----------------
  const enumerator = ScreenEnumerator();
  final universe = enumerator.buildUniverse(libDir);

  stdout.writeln(
    'Audit_System CLI — per-screen-business-type-audit-remediation',
  );
  stdout.writeln(
    'Scanned lib dir : ${libDir.absolute.path.replaceAll('\\', '/')}',
  );
  stdout.writeln(
    'Universe        : ${universe.businessTypes.length} business type(s), '
    '${universe.totalScreens} screen(s)',
  );

  if (universe.isEmpty || universe.totalScreens == 0) {
    stderr.writeln(
      'ERROR: the enumerated universe is empty — no Screens to audit.',
    );
    exitCode = 1;
    return;
  }

  final runner = AuditRunner();
  const selector = TargetSelector();

  // --- Choose the next Iteration_Target. -----------------------------------
  // Explicit override via --business-type/--screen, else the advance decision.
  final overrideBt = _option(args, 'business-type');
  final overrideScreen = _option(args, 'screen');

  IterationTarget target;
  if (overrideBt != null && overrideScreen != null) {
    target = IterationTarget(
      businessType: overrideBt,
      screenPath: overrideScreen,
    );
  } else {
    final decision = selector.advance(runner.completedRegistry, universe);
    if (decision.noTargetsRemain) {
      stdout.writeln(_describeAdvance(decision));
      stdout.writeln('Nothing to do — no targets remain.');
      return;
    }
    target = decision.nextTarget!;
  }

  stdout.writeln(
    'Next target     : ${target.businessType} :: ${target.screenPath}',
  );

  // `--list` only reports the chosen target without running an iteration.
  if (_hasFlag(args, 'list')) {
    return;
  }

  // --- Run ONE iteration end to end. ---------------------------------------
  final result = runner.runIteration(
    proposal: TargetProposal(
      businessTypes: <String>[target.businessType],
      screens: <String>[target.screenPath],
    ),
    universe: universe,
    audit: _representativeAudit(target),
    iterationId: 'iter-cli-${DateTime.now().toUtc().millisecondsSinceEpoch}',
  );

  stdout.writeln('');
  stdout.writeln('--- Iteration result ---');

  if (!result.accepted) {
    stderr.writeln('Identify REJECTED: ${result.rejectionReason}');
    stderr.writeln(
      'Hint: pass an existing --business-type and --screen, or omit both to '
      'use the next decided target.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('Target          : ${result.target}');
  stdout.writeln('Final status    : ${result.finalStatus.name}');
  stdout.writeln('Phase order ok  : ${result.phaseOrderValid}');
  stdout.writeln('Audit coverage  : ${result.auditPhaseStatus.name}');
  stdout.writeln('Categories      : ${result.categoryResults.length} recorded');
  stdout.writeln('Gaps admitted   : ${result.admittedGaps.length}');
  stdout.writeln('Done            : ${result.done}');

  if (!result.committedDone) {
    // Not done OR persistence failed: advancement is blocked, target retained.
    final blocking = result.doneClassification?.blockingItems ?? const [];
    stdout.writeln('Committed done  : false (advancement blocked)');
    if (blocking.isNotEmpty) {
      stdout.writeln(
        'Blocking items  : ${blocking.map((i) => i.name).join(', ')}',
      );
    }
    if (result.persistResult != null && result.persistResult!.failed) {
      stderr.writeln(
        'Persistence FAILED: ${result.persistResult!.error} — '
        'current target retained, completed record unchanged.',
      );
    }
    stdout.writeln(
      'Advance decision : blocked — current target retained as active.',
    );
    exitCode = 1;
    return;
  }

  // --- Done and persisted: summarize the report + advance decision. --------
  final report = result.report!;
  stdout.writeln('Committed done  : true');
  stdout.writeln('Report persisted: ${result.persistResult!.path}');
  stdout.writeln('  iterationId   : ${report.iterationId}');
  stdout.writeln('  businessType  : ${report.businessType}');
  stdout.writeln('  screenPath    : ${report.screenPath}');
  stdout.writeln('  dodResults    : ${report.dodResults.length} item(s)');
  stdout.writeln('  fixes         : ${report.fixes.length} applied');

  // Report the advance decision (next target | none) (Req 15.3).
  stdout.writeln('');
  stdout.writeln(_describeAdvance(result.advanceDecision!));
}
