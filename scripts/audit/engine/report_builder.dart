/// ReportBuilder — generates the per-Business_Type Audit Report as Markdown.
///
/// Writes `audit-reports/business-types/audit-<type>.md` (kebab-case) with all
/// required sections in order: Business Type Header, Screen Inventory table,
/// Findings table, Fix Log, Test Log, Shared/Core Impact Notes,
/// Platform_Verification_Matrix, Blocked & Deferred section, and Sign_Off.
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 7.7
library;

import 'dart:io';

import '../models/audit_engine_models.dart';
import 'prioritizer.dart';

/// The structured audit report output.
class AuditReport {
  /// The file path the report was written to.
  final String outputPath;

  /// The full Markdown content of the report.
  final String content;

  const AuditReport({required this.outputPath, required this.content});

  @override
  String toString() => 'AuditReport($outputPath)';
}

/// Builds and writes the per-Business_Type Audit Report.
///
/// Uses [Prioritizer] for Fix Log severity ordering.
class ReportBuilder {
  final Prioritizer _prioritizer;

  ReportBuilder({Prioritizer? prioritizer})
    : _prioritizer = prioritizer ?? Prioritizer();

  /// Builds the audit report from the given [state] and writes it to disk.
  ///
  /// Returns the [AuditReport] containing the output path and content.
  ///
  /// Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 7.7
  AuditReport build(CycleState state) {
    final content = _generateContent(state);
    final outputPath = _writeReport(state.businessType, content);
    return AuditReport(outputPath: outputPath, content: content);
  }

  /// Generates the full Markdown content without writing to disk.
  ///
  /// Useful for testing or preview without file I/O.
  String generateContent(CycleState state) => _generateContent(state);

  String _generateContent(CycleState state) {
    final buffer = StringBuffer();

    _writeHeader(buffer, state);
    _writeScreenInventory(buffer, state);
    _writeFindings(buffer, state);
    _writeFixLog(buffer, state);
    _writeTestLog(buffer, state);
    _writeSharedImpactNotes(buffer, state);
    _writePlatformMatrix(buffer, state);
    _writeBlockedAndDeferred(buffer, state);
    _writeSignOff(buffer, state);

    return buffer.toString();
  }

  /// Section 1: Business Type Header (Req 6.1)
  void _writeHeader(StringBuffer buffer, CycleState state) {
    buffer.writeln('# UI/UX Audit Report: ${state.businessType.displayName}');
    buffer.writeln();
  }

  /// Section 2: Screen Inventory table (Req 6.2)
  void _writeScreenInventory(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Screen Inventory');
    buffer.writeln();

    if (state.inventory.screens.isEmpty) {
      buffer.writeln('No screens discovered for this business type.');
      buffer.writeln();
      return;
    }

    buffer.writeln('| Screen Name | Route | File Path |');
    buffer.writeln('|---|---|---|');

    for (final screen in state.inventory.screens) {
      buffer.writeln(
        '| ${_escapeCell(screen.name)} '
        '| ${_escapeCell(screen.route)} '
        '| ${_escapeCell(screen.filePath)} |',
      );
    }

    buffer.writeln();
  }

  /// Section 3: Findings table (Req 6.3)
  void _writeFindings(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Findings');
    buffer.writeln();

    if (state.findings.isEmpty) {
      buffer.writeln('No findings recorded.');
      buffer.writeln();
      return;
    }

    buffer.writeln(
      '| Screen | Category | Severity | Description | File:Line |',
    );
    buffer.writeln('|---|---|---|---|---|');

    for (final finding in state.findings) {
      buffer.writeln(
        '| ${_escapeCell(finding.screen.name)} '
        '| ${_formatCategory(finding.category)} '
        '| ${_formatSeverity(finding.severity)} '
        '| ${_escapeCell(finding.description)} '
        '| ${_escapeCell(finding.fileLine)} |',
      );
    }

    buffer.writeln();
  }

  /// Section 4: Fix Log (Req 6.4, 6.5)
  void _writeFixLog(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Fix Log');
    buffer.writeln();

    if (state.fixLog.isEmpty) {
      // Req 6.5: explicit statement when no fixes applied
      buffer.writeln('No fixes were applied during this cycle.');
      buffer.writeln();
      return;
    }

    // Order by severity descending, stable (Req 7.6)
    final orderedFindings = _prioritizer.orderForFixLog(
      state.fixLog.map((e) => e.finding).toList(),
    );

    // Map findings to their fix log entries for ordered output
    final findingToFix = <String, FixLogEntry>{};
    for (final fix in state.fixLog) {
      findingToFix[fix.finding.id] = fix;
    }

    for (final finding in orderedFindings) {
      final fix = findingToFix[finding.id];
      if (fix == null) continue;

      buffer.writeln(
        '### ${_formatSeverity(fix.finding.severity)}: ${_escapeCell(fix.finding.description)}',
      );
      buffer.writeln();
      buffer.writeln('- **What Changed:** ${fix.whatChanged}');
      buffer.writeln('- **Why:** ${fix.whyChanged}');
      buffer.writeln('- **Before:** ${fix.beforeBehavior}');
      buffer.writeln('- **After:** ${fix.afterBehavior}');

      if (fix.impactedCallSites.isNotEmpty) {
        buffer.writeln('- **Impacted Call Sites:**');
        for (final site in fix.impactedCallSites) {
          buffer.writeln('  - $site');
        }
      }

      buffer.writeln();
    }
  }

  /// Section 5: Test Log (Req 6.6)
  void _writeTestLog(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Test Log');
    buffer.writeln();

    if (state.testLog.isEmpty) {
      buffer.writeln('No tests recorded.');
      buffer.writeln();
      return;
    }

    buffer.writeln('| Test ID | Result |');
    buffer.writeln('|---|---|');

    for (final test in state.testLog) {
      buffer.writeln(
        '| ${_escapeCell(test.testId)} | ${test.passed ? 'Pass' : 'Fail'} |',
      );
    }

    buffer.writeln();
  }

  /// Section 6: Shared/Core Impact Notes (Req 6.7)
  void _writeSharedImpactNotes(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Shared/Core Impact Notes');
    buffer.writeln();

    if (state.sharedImpact.isEmpty) {
      buffer.writeln('No shared/core widget changes during this cycle.');
      buffer.writeln();
      return;
    }

    for (final note in state.sharedImpact) {
      buffer.writeln('### ${_escapeCell(note.widgetPath)}');
      buffer.writeln();
      buffer.writeln('| Consumer Business Type | Verification Result |');
      buffer.writeln('|---|---|');

      for (final entry in note.consumerVerification.entries) {
        buffer.writeln(
          '| ${entry.key.displayName} | ${entry.value ? 'Pass' : 'Fail'} |',
        );
      }

      buffer.writeln();
    }
  }

  /// Section 7: Platform Verification Matrix (Req 6.8)
  void _writePlatformMatrix(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Platform Verification Matrix');
    buffer.writeln();

    if (state.matrix.isEmpty) {
      buffer.writeln('No platform verification performed.');
      buffer.writeln();
      return;
    }

    buffer.writeln(
      '| Platform | Light | Dark | Portrait | Landscape | Result |',
    );
    buffer.writeln('|---|---|---|---|---|---|');

    for (final row in state.matrix) {
      buffer.writeln(
        '| ${row.platform.label} '
        '| ${_formatMatrixCell(row.light)} '
        '| ${_formatMatrixCell(row.dark)} '
        '| ${_formatMatrixCell(row.portrait)} '
        '| ${_formatMatrixCell(row.landscape)} '
        '| ${row.resultPass ? 'Pass' : 'Fail'} |',
      );
    }

    buffer.writeln();
  }

  /// Section 8: Blocked & Deferred (Req 7.7)
  ///
  /// MUST NOT contain any completed fixes — only blocked and deferred items.
  void _writeBlockedAndDeferred(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Blocked & Deferred');
    buffer.writeln();

    final hasBlocked = state.blocked.isNotEmpty;
    final hasDeferred = state.deferred.isNotEmpty;

    if (!hasBlocked && !hasDeferred) {
      buffer.writeln('No blocked or deferred items.');
      buffer.writeln();
      return;
    }

    if (hasBlocked) {
      buffer.writeln('### Blocked Items');
      buffer.writeln();
      buffer.writeln(
        '| Finding | Blocking Reason | Missing Artifact | Action to Unblock |',
      );
      buffer.writeln('|---|---|---|---|');

      for (final item in state.blocked) {
        buffer.writeln(
          '| ${_escapeCell(item.finding.description)} '
          '| ${_escapeCell(item.blockingReason)} '
          '| ${_escapeCell(item.missingArtifact)} '
          '| ${_escapeCell(item.actionToUnblock)} |',
        );
      }

      buffer.writeln();
    }

    if (hasDeferred) {
      buffer.writeln('### Deferred Items');
      buffer.writeln();
      buffer.writeln('| Finding | Reason |');
      buffer.writeln('|---|---|');

      for (final item in state.deferred) {
        buffer.writeln(
          '| ${_escapeCell(item.finding.description)} '
          '| ${_escapeCell(item.reason)} |',
        );
      }

      buffer.writeln();
    }
  }

  /// Section 9: Sign-Off (Req 6.9)
  void _writeSignOff(StringBuffer buffer, CycleState state) {
    buffer.writeln('## Sign-Off');
    buffer.writeln();

    // Compute sign-off from state
    final signOff = _evaluateSignOff(state);

    if (signOff.isComplete) {
      buffer.writeln(
        '**Sign-Off: COMPLETE** — All findings for '
        '${state.businessType.displayName} are resolved or explicitly '
        'recorded as blocked/deferred, all tests pass, and all shared '
        'widget verifications are satisfied.',
      );
    } else {
      buffer.writeln('**Sign-Off: WITHHELD**');
      buffer.writeln();
      buffer.writeln('The following conditions prevent sign-off:');
      buffer.writeln();
      for (final condition in signOff.withholdingConditions) {
        buffer.writeln('- $condition');
      }
    }

    buffer.writeln();
  }

  // ---------------------------------------------------------------------------
  // File I/O
  // ---------------------------------------------------------------------------

  /// Writes the report content to disk, creating directories as needed.
  String _writeReport(BusinessType businessType, String content) {
    final kebabName = _toKebabCase(businessType.displayName);
    final outputPath = 'audit-reports/business-types/audit-$kebabName.md';

    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);

    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts a display name to kebab-case.
  ///
  /// e.g. "Petrol Pump" → "petrol-pump", "Grocery" → "grocery",
  /// "Decoration & Catering" → "decoration-catering"
  String _toKebabCase(String displayName) {
    return displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // remove non-alphanumeric
        .trim()
        .replaceAll(RegExp(r'\s+'), '-'); // spaces to hyphens
  }

  /// Escapes pipe characters in Markdown table cells.
  String _escapeCell(String value) => value.replaceAll('|', '\\|');

  /// Formats a ChecklistCategory for display.
  String _formatCategory(ChecklistCategory category) => switch (category) {
    ChecklistCategory.layoutAndOverflow => 'Layout & Overflow',
    ChecklistCategory.hardcodedValues => 'Hardcoded Values',
    ChecklistCategory.responsivenessAndPlatformCoverage =>
      'Responsiveness & Platform Coverage',
    ChecklistCategory.uiUxCorrectness => 'UI/UX Correctness',
    ChecklistCategory.performance => 'Performance',
  };

  /// Formats a Severity for display.
  String _formatSeverity(Severity severity) => switch (severity) {
    Severity.critical => 'Critical',
    Severity.high => 'High',
    Severity.medium => 'Medium',
    Severity.low => 'Low',
  };

  /// Formats a MatrixCell as Pass, Fail, or N/A with reason.
  String _formatMatrixCell(MatrixCell cell) => switch (cell.status) {
    CategoryStatus.pass => 'Pass',
    CategoryStatus.fail => 'Fail',
    CategoryStatus.na => 'N/A${cell.reason != null ? ' (${cell.reason})' : ''}',
  };

  /// Evaluates the sign-off predicate for the given state.
  ///
  /// Inline implementation matching SignOffEvaluator logic so ReportBuilder
  /// can produce the sign-off section independently.
  SignOff _evaluateSignOff(CycleState state) {
    final conditions = <String>[];

    // Sub-condition 1: All Findings addressed (no open findings remain).
    final openFindings = state.findings
        .where((f) => f.state == FindingState.open)
        .toList();
    if (openFindings.isNotEmpty) {
      conditions.add(
        '${openFindings.length} open finding(s) remain unresolved',
      );
    }

    // Sub-condition 2: Zero test failures.
    final failingTests = state.testLog.where((t) => !t.passed).toList();
    if (failingTests.isNotEmpty) {
      conditions.add('${failingTests.length} test(s) failing');
    }

    // Sub-condition 3: Shared-core verifications complete and passing.
    final sharedFailures = <String>[];
    for (final impact in state.sharedImpact) {
      for (final entry in impact.consumerVerification.entries) {
        if (entry.value == false) {
          sharedFailures.add('${impact.widgetPath} → ${entry.key.displayName}');
        }
      }
    }
    if (sharedFailures.isNotEmpty) {
      conditions.add(
        'Shared widget verification failed: ${sharedFailures.join(', ')}',
      );
    }

    return SignOff(
      isComplete: conditions.isEmpty,
      withholdingConditions: conditions,
    );
  }
}
