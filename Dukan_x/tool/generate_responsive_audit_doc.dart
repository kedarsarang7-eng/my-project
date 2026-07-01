// RESPONSIVE AUDIT DOC GENERATOR — Task 6.2 of the cross-platform-responsive-ui spec.
//
// Transforms the machine-readable seed produced by `tool/responsive_audit.dart`
// (`tool/responsive_audit_report.json`) into the checked-in, human-readable
// inventory document `docs/responsive-audit.md` (Requirements 12.1, 12.5, 12.6).
//
// Keeping the doc generated (rather than hand-authored) means it can be
// refreshed any time the codebase changes, so the audit never drifts out of
// date and regressions stay visible. Per AGENTS.md: simple, clear, no deps.
//
// Run from the Dukan_x package root, AFTER running the scanner:
//
//     dart run tool/responsive_audit.dart            # 1. regenerate the JSON seed
//     dart run tool/generate_responsive_audit_doc.dart  # 2. regenerate the doc
//
// Part of: cross-platform-responsive-ui

import 'dart:convert';
import 'dart:io';

/// Human-readable heading for each scanner category, in document order.
const Map<String, String> _categoryHeadings = <String, String>{
  'business_screen': 'Business_Screens',
  'shared_component': 'Shared layout components',
  'responsive_component': 'Responsive_Components',
};

/// One-line description of each scanner category for the summary table.
const Map<String, String> _categoryBlurb = <String, String>{
  'business_screen': 'Screens under `lib/features/**` (`*_screen.dart`).',
  'shared_component':
      'Reusable widgets under `lib/features/shared/**` and `lib/widgets/**`.',
  'responsive_component':
      'The Responsive_System itself under `lib/core/responsive/**`.',
};

/// Maps each scanner-flagged static condition to the runtime conditions it
/// implies (Req 12.5: Form_Factor / orientation / Accessibility_Font_Scaling).
const Map<String, String> _conditionLegend = <String, String>{
  'notAdaptiveBody':
      'Screen body is not wrapped in an adaptive body primitive '
      '(`AdaptiveScaffold`/`AdaptiveScroll`/etc.). **Runtime risk:** '
      'Overflow_Error across **all Form_Factors** (Mobile and Tablet '
      'especially), under **portrait and landscape** orientation changes, and '
      'under **Accessibility_Font_Scaling from 100% up to the platform '
      'maximum** — because nothing guarantees the content wraps, truncates, or '
      'scrolls when it exceeds the available space.',
  'handRolledBreakpoint':
      'Defines breakpoints with a hand-rolled `MediaQuery...size.width` '
      'comparison **outside** the Responsive_System. **Runtime risk:** '
      'inconsistent Form_Factor classification across Mobile / Tablet / Desktop '
      '(thresholds may disagree with the canonical 600 / 1100 boundaries), so '
      'the screen can pick the wrong layout at a given width and orientation.',
  'legacyImport':
      'Imports the legacy `core/theme/responsive_layout.dart` breakpoint API. '
      '**Runtime risk:** duplicate breakpoint authority — the screen may '
      'classify Form_Factors using the legacy 1280 / 1440 / 1920 desktop tiers '
      'instead of the canonical Responsive_System boundaries, producing '
      'inconsistent layout decisions across Form_Factors.',
};

/// Stable display order for conditions in the legend and per-item lists.
const List<String> _conditionOrder = <String>[
  'notAdaptiveBody',
  'handRolledBreakpoint',
  'legacyImport',
];

String _conditionTitle(String json) {
  switch (json) {
    case 'notAdaptiveBody':
      return '`notAdaptiveBody`';
    case 'handRolledBreakpoint':
      return '`handRolledBreakpoint`';
    case 'legacyImport':
      return '`legacyImport`';
    default:
      return '`$json`';
  }
}

void main(List<String> args) {
  final seedFile = File('tool/responsive_audit_report.json');
  if (!seedFile.existsSync()) {
    stderr.writeln(
      'ERROR: ${seedFile.path} not found. Run the scanner first:\n'
      '  dart run tool/responsive_audit.dart',
    );
    exitCode = 1;
    return;
  }

  final report =
      jsonDecode(seedFile.readAsStringSync()) as Map<String, Object?>;
  final summary = report['summary'] as Map<String, Object?>;
  final items = (report['items'] as List<Object?>).cast<Map<String, Object?>>();

  // Group items by category, preserving the path-sorted order from the seed.
  final byCategory = <String, List<Map<String, Object?>>>{};
  for (final item in items) {
    final cat = item['category'] as String;
    byCategory.putIfAbsent(cat, () => <Map<String, Object?>>[]).add(item);
  }

  final total = summary['totalScanned'] as int;
  final compliant = summary['compliant'] as int;
  final nonCompliant = summary['nonCompliant'] as int;
  final catCounts = (summary['byCategory'] as Map<String, Object?>).map(
    (k, v) => MapEntry(k, v as int),
  );
  final condCounts = (summary['byCondition'] as Map<String, Object?>).map(
    (k, v) => MapEntry(k, v as int),
  );

  final b = StringBuffer();

  // ---- Header ---------------------------------------------------------------
  b.writeln('# Responsive Audit Inventory');
  b.writeln();
  b.writeln('**Feature:** cross-platform-responsive-ui  ');
  b.writeln(
    '**Requirements covered:** 12.1 (Business_Screen coverage), '
    '12.5 (failing conditions), 12.6 (every item classified exactly once)  ',
  );
  b.writeln(
    '**Generated by:** `tool/responsive_audit.dart` → '
    '`tool/responsive_audit_report.json` → `tool/generate_responsive_audit_doc.dart`',
  );
  b.writeln();
  b.writeln(
    '> This document is **generated**. Do not edit it by hand. To refresh it '
    'after code changes (so the audit never drifts and regressions stay '
    'visible), re-run the two commands in [How to regenerate]'
    '(#how-to-regenerate) below.',
  );
  b.writeln();

  // ---- Overview / summary ---------------------------------------------------
  b.writeln('## Overview');
  b.writeln();
  b.writeln(
    'Every `Business_Screen` under `lib/features/`, every shared layout '
    'component, and every `Responsive_Component` is classified below as '
    '**compliant** or **non-compliant** with the Responsive_System. Each item '
    'is classified exactly once — no item is left unclassified and none is '
    'classified twice (Req 12.6).',
  );
  b.writeln();
  b.writeln('| Metric | Count |');
  b.writeln('| --- | ---: |');
  b.writeln('| **Total items scanned** | $total |');
  b.writeln('| Compliant | $compliant |');
  b.writeln('| Non-compliant | $nonCompliant |');
  b.writeln();

  // Per-category split.
  b.writeln('### By category');
  b.writeln();
  b.writeln('| Category | Total | Compliant | Non-compliant |');
  b.writeln('| --- | ---: | ---: | ---: |');
  for (final cat in _categoryHeadings.keys) {
    final list = byCategory[cat] ?? const <Map<String, Object?>>[];
    final c = list.where((i) => i['compliant'] == true).length;
    final n = list.length - c;
    final label = _categoryHeadings[cat]!;
    b.writeln('| $label | ${catCounts[cat] ?? list.length} | $c | $n |');
  }
  b.writeln('| **All** | $total | $compliant | $nonCompliant |');
  b.writeln();

  // Per-condition split.
  b.writeln('### By failing condition');
  b.writeln();
  b.writeln(
    'A single item may be flagged by more than one condition, so these counts '
    'are per-flag and may sum to more than the non-compliant total.',
  );
  b.writeln();
  b.writeln('| Condition | Items flagged |');
  b.writeln('| --- | ---: |');
  for (final cond in _conditionOrder) {
    if (condCounts.containsKey(cond)) {
      b.writeln('| ${_conditionTitle(cond)} | ${condCounts[cond]} |');
    }
  }
  // Include any conditions not in the known order (future-proofing).
  for (final entry in condCounts.entries) {
    if (!_conditionOrder.contains(entry.key)) {
      b.writeln('| ${_conditionTitle(entry.key)} | ${entry.value} |');
    }
  }
  b.writeln();

  // ---- Legend: condition -> runtime conditions ------------------------------
  b.writeln('## Failing-conditions legend (convention)');
  b.writeln();
  b.writeln(
    'The scanner flags **static** heuristics. Each maps to the **runtime** '
    'conditions it puts at risk, covering the Mobile / Tablet / Desktop '
    'Form_Factors, portrait / landscape orientation, and '
    'Accessibility_Font_Scaling from 100% up to the platform maximum '
    '(Req 12.5). This legend is applied to every flagged item below, so the '
    'per-item lists only name the flagged condition(s) — the runtime-condition '
    'coverage is implied here.',
  );
  b.writeln();
  for (final cond in _conditionOrder) {
    if (!condCounts.containsKey(cond) && !_conditionLegend.containsKey(cond)) {
      continue;
    }
    b.writeln('- **${_conditionTitle(cond)}** — ${_conditionLegend[cond]}');
  }
  b.writeln();
  b.writeln(
    'A **compliant** item is one the scanner did not flag with any condition: '
    'a screen wrapped in an adaptive body, no hand-rolled breakpoints, and no '
    'legacy breakpoint import.',
  );
  b.writeln();

  // ---- Per-category inventories ---------------------------------------------
  b.writeln('## Inventory');
  b.writeln();
  for (final cat in _categoryHeadings.keys) {
    final list = byCategory[cat] ?? const <Map<String, Object?>>[];
    final heading = _categoryHeadings[cat]!;
    final c = list.where((i) => i['compliant'] == true).length;
    final n = list.length - c;

    b.writeln('### $heading');
    b.writeln();
    b.writeln('${_categoryBlurb[cat] ?? ''}');
    b.writeln();
    b.writeln('**${list.length}** items — $c compliant, $n non-compliant.');
    b.writeln();
    b.writeln('| # | Status | Path | Flagged conditions |');
    b.writeln('| ---: | --- | --- | --- |');
    var idx = 0;
    for (final item in list) {
      idx++;
      final isCompliant = item['compliant'] == true;
      final status = isCompliant ? 'compliant' : 'non-compliant';
      final conds = (item['conditions'] as List<Object?>).cast<String>();
      final condCell = conds.isEmpty
          ? '—'
          : conds.map(_conditionTitle).join(', ');
      b.writeln('| $idx | $status | `${item['path']}` | $condCell |');
    }
    b.writeln();
  }

  // ---- How to regenerate ----------------------------------------------------
  b.writeln('## How to regenerate');
  b.writeln();
  b.writeln(
    'Run both commands from the Dukan_x package root. The scanner rewrites the '
    'JSON seed; the generator rewrites this document from that seed:',
  );
  b.writeln();
  b.writeln('```bash');
  b.writeln('dart run tool/responsive_audit.dart');
  b.writeln('dart run tool/generate_responsive_audit_doc.dart');
  b.writeln('```');
  b.writeln();
  b.writeln(
    'The totality property test (task 6.3, '
    '`test/tool/responsive_audit_totality_property_test.dart`) asserts that '
    'every scanned item receives exactly one classification, guarding Req 12.6.',
  );
  b.writeln();

  final outFile = File('docs/responsive-audit.md');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(b.toString());

  stdout.writeln('Wrote ${outFile.path}');
  stdout.writeln(
    '  total=$total compliant=$compliant nonCompliant=$nonCompliant',
  );
}
