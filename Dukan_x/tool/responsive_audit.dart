// RESPONSIVE AUDIT SCANNER — Task 6.1 of the cross-platform-responsive-ui spec.
//
// A standalone, dependency-free Dart CLI that statically scans `lib/` and
// flags responsiveness debt. It is intentionally a *best-effort heuristic*
// scanner (simple regex/line scanning, no full Dart parser) per the
// AGENTS.md "simple and clear" guidance.
//
// What it flags (Requirements 12.1, 12.2, 12.3, 12.4):
//   1. legacyImport         — files importing the LEGACY breakpoint API
//                             `core/theme/responsive_layout.dart` (Req 12.4).
//   2. handRolledBreakpoint — hand-rolled `MediaQuery...size.width` breakpoint
//                             comparisons defined OUTSIDE the Responsive_System
//                             (`lib/core/responsive/`) (Req 12.2, 12.4).
//   3. notAdaptiveBody      — `*_screen.dart` Business_Screens whose source does
//                             not reference any adaptive body primitive (Req 12.1).
//
// What it emits:
//   A machine-readable JSON inventory seed written to
//   `tool/responsive_audit_report.json` AND a short human summary on stdout.
//   This seed is consumed by task 6.2 (docs/responsive-audit.md) and the
//   totality property test (task 6.3).
//
// Run from the Dukan_x package root:
//
//     dart run tool/responsive_audit.dart
//
// The core scan logic below is exposed as PURE, importable functions
// (`classifyPath`, `scanContent`, `runAudit`, `listScannableFiles`) so the
// task 6.3 property test can call the classification directly via a relative
// import: `import '../../tool/responsive_audit.dart';`.
//
// Part of: cross-platform-responsive-ui

import 'dart:convert';
import 'dart:io';

// =============================================================================
// Data model
// =============================================================================

/// The disjoint classification buckets for the scanned universe.
///
/// Every item in the audit universe maps to EXACTLY ONE of these, which is the
/// invariant the totality/disjointness property test (6.3) relies on.
enum AuditCategory {
  businessScreen('business_screen'),
  sharedComponent('shared_component'),
  responsiveComponent('responsive_component');

  const AuditCategory(this.json);

  /// Stable snake_case name used in the JSON seed.
  final String json;
}

/// A single flagged condition found on a scanned item.
enum AuditCondition {
  legacyImport('legacyImport'),
  handRolledBreakpoint('handRolledBreakpoint'),
  notAdaptiveBody('notAdaptiveBody');

  const AuditCondition(this.json);

  final String json;
}

/// One row of the inventory seed: a scanned item, its single classification,
/// and the conditions flagged against it. `compliant` is true when no
/// condition was flagged.
class AuditItem {
  AuditItem({
    required this.path,
    required this.category,
    required this.conditions,
  });

  /// Forward-slash path relative to the package root, e.g.
  /// `lib/features/billing/presentation/screens/bill_creation_screen_v2.dart`.
  final String path;

  /// The single classification bucket for this item.
  final AuditCategory category;

  /// Sorted, de-duplicated conditions flagged against this item.
  final List<AuditCondition> conditions;

  bool get compliant => conditions.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'category': category.json,
    'conditions': conditions.map((c) => c.json).toList(),
    'compliant': compliant,
  };
}

// =============================================================================
// Classification (pure) — single source of truth for category assignment
// =============================================================================

/// Adaptive body primitives. A `*_screen.dart` that references ANY of these is
/// treated as wrapped in an adaptive body (not flagged `notAdaptiveBody`).
const List<String> kAdaptiveMarkers = <String>[
  'AdaptiveScaffold',
  'AdaptiveScroll',
  'AdaptiveShell',
  'AdaptiveDialog',
  'AdaptiveSheet',
  'AdaptiveForm',
  'AdaptiveTable',
  'AdaptiveGrid',
  'AdaptiveChartBox',
  'AdaptiveText',
  'AdaptiveButton',
  'BoundedBox',
  'ResponsiveScaffold',
  'ResponsiveLayout',
  'ResponsiveSafeArea',
  'ResponsiveContainer',
  'ResponsiveGrid',
  'ResponsiveRowColumn',
];

/// Normalize a filesystem path to forward slashes for stable matching/output.
String normalizePath(String path) => path.replaceAll('\\', '/');

/// Classify a `.dart` file path into exactly one [AuditCategory], or `null`
/// when the file is OUTSIDE the audit universe (e.g. a repository, model, or
/// service). The checks are ordered so the result is deterministic and the
/// buckets stay disjoint.
///
/// Pure: depends only on the path string. Accepts absolute or relative paths.
AuditCategory? classifyPath(String rawPath) {
  final p = normalizePath(rawPath);

  if (!p.endsWith('.dart')) return null;
  // Skip generated sources — they are never authored screens/components.
  if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return null;

  // 1. The Responsive_System itself.
  if (p.contains('lib/core/responsive/')) {
    return AuditCategory.responsiveComponent;
  }
  // 2. Shared feature components live under lib/features/shared/ — classify
  //    them as shared BEFORE the generic screen check so a shared *_screen
  //    is counted as a shared component, not a business screen.
  if (p.contains('lib/features/shared/')) {
    return AuditCategory.sharedComponent;
  }
  // 3. Business_Screens: *_screen.dart anywhere under lib/features/.
  if (p.contains('lib/features/') && p.endsWith('_screen.dart')) {
    return AuditCategory.businessScreen;
  }
  // 4. App-wide shared widgets.
  if (p.contains('lib/widgets/')) {
    return AuditCategory.sharedComponent;
  }

  // Everything else is outside the audit universe.
  return null;
}

// =============================================================================
// Condition detection (pure)
// =============================================================================

/// Matches an import/export directive that pulls in the LEGACY breakpoint API
/// at `core/theme/responsive_layout.dart`. Works for both package and relative
/// imports because both contain the `theme/responsive_layout.dart` suffix.
final RegExp _legacyImportRe = RegExp(
  r'''^\s*(?:import|export)\s+['"][^'"]*theme/responsive_layout\.dart['"]''',
  multiLine: true,
);

/// Matches a direct hand-rolled breakpoint comparison, in either direction:
///   MediaQuery.of(context).size.width < 600
///   MediaQuery.sizeOf(context).width >= 1100
///   600 > MediaQuery.of(context).size.width
final RegExp _directBreakpointRe = RegExp(
  r'MediaQuery\s*\.\s*(?:of\s*\(\s*context\s*\)\s*\.\s*size|sizeOf\s*\(\s*context\s*\))'
  r'\s*\.\s*width\s*(?:<=|>=|<|>)\s*\d',
);
final RegExp _directBreakpointReversedRe = RegExp(
  r'\d\s*(?:<=|>=|<|>)\s*MediaQuery\s*\.\s*(?:of\s*\(\s*context\s*\)\s*\.\s*size'
  r'|sizeOf\s*\(\s*context\s*\))\s*\.\s*width',
);

/// Matches a width captured into a local variable from MediaQuery, e.g.
///   final width = MediaQuery.of(context).size.width;
///   final w = MediaQuery.sizeOf(context).width;
/// Capture group 1 is the variable name.
final RegExp _widthCaptureRe = RegExp(
  r'(\w+)\s*=\s*MediaQuery\s*\.\s*(?:of\s*\(\s*context\s*\)\s*\.\s*size'
  r'|sizeOf\s*\(\s*context\s*\))\s*\.\s*width',
);

/// True when [content] re-defines breakpoints via a hand-rolled
/// `MediaQuery...size.width` numeric comparison.
bool hasHandRolledBreakpoint(String content) {
  if (_directBreakpointRe.hasMatch(content) ||
      _directBreakpointReversedRe.hasMatch(content)) {
    return true;
  }
  // Variable-captured form: capture width into a var, then compare that var
  // to a numeric literal somewhere else in the file.
  for (final m in _widthCaptureRe.allMatches(content)) {
    final varName = m.group(1)!;
    final escaped = RegExp.escape(varName);
    final compareRe = RegExp(r'\b' + escaped + r'\b\s*(?:<=|>=|<|>)\s*\d');
    final reversedRe = RegExp(r'\d\s*(?:<=|>=|<|>)\s*\b' + escaped + r'\b');
    if (compareRe.hasMatch(content) || reversedRe.hasMatch(content)) {
      return true;
    }
  }
  return false;
}

/// True when none of the [kAdaptiveMarkers] appear in [content] (word-boundary
/// match to avoid partial hits).
bool lacksAdaptiveBody(String content) {
  for (final marker in kAdaptiveMarkers) {
    final re = RegExp(r'\b' + RegExp.escape(marker) + r'\b');
    if (re.hasMatch(content)) return false;
  }
  return true;
}

/// Scan a single file's [content] and return the sorted, de-duplicated set of
/// conditions flagged against it. The applicable rules depend on the file's
/// [classifyPath] category:
///   * legacyImport          — any category.
///   * handRolledBreakpoint  — any category EXCEPT responsive_component (the
///                             Responsive_System is the legitimate home).
///   * notAdaptiveBody       — business_screen only.
///
/// Pure: depends only on the path string and the content.
List<AuditCondition> scanContent(String rawPath, String content) {
  final category = classifyPath(rawPath);
  if (category == null) return const <AuditCondition>[];

  final found = <AuditCondition>{};

  if (_legacyImportRe.hasMatch(content)) {
    found.add(AuditCondition.legacyImport);
  }
  if (category != AuditCategory.responsiveComponent &&
      hasHandRolledBreakpoint(content)) {
    found.add(AuditCondition.handRolledBreakpoint);
  }
  if (category == AuditCategory.businessScreen && lacksAdaptiveBody(content)) {
    found.add(AuditCondition.notAdaptiveBody);
  }

  final list = found.toList()..sort((a, b) => a.json.compareTo(b.json));
  return list;
}

// =============================================================================
// Filesystem walk
// =============================================================================

/// Recursively list `.dart` files under [libDir] that fall within the audit
/// universe (i.e. `classifyPath` returns non-null), skipping build artifacts
/// and generated sources. Results are sorted by path for determinism.
List<File> listScannableFiles(Directory libDir) {
  if (!libDir.existsSync()) return const <File>[];
  final out = <File>[];
  for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final p = normalizePath(entity.path);
    if (p.contains('/.dart_tool/') || p.contains('/build/')) continue;
    if (classifyPath(p) == null) continue;
    out.add(entity);
  }
  out.sort((a, b) => normalizePath(a.path).compareTo(normalizePath(b.path)));
  return out;
}

/// Convert an absolute file path into a package-relative, forward-slash path
/// starting at `lib/` so the report is stable regardless of where it runs.
String toRelativeLibPath(String rawPath) {
  final p = normalizePath(rawPath);
  final idx = p.indexOf('lib/');
  return idx >= 0 ? p.substring(idx) : p;
}

/// Run the full audit over [libDir] and return one [AuditItem] per scanned
/// file, sorted by path. Each item appears EXACTLY ONCE with a single
/// category — the invariant the totality property test (6.3) checks.
List<AuditItem> runAudit(Directory libDir) {
  final items = <AuditItem>[];
  for (final file in listScannableFiles(libDir)) {
    final relPath = toRelativeLibPath(file.path);
    final category = classifyPath(relPath)!;
    String content;
    try {
      content = file.readAsStringSync();
    } catch (_) {
      content = '';
    }
    items.add(
      AuditItem(
        path: relPath,
        category: category,
        conditions: scanContent(relPath, content),
      ),
    );
  }
  // Already sorted via listScannableFiles, but keep the guarantee explicit.
  items.sort((a, b) => a.path.compareTo(b.path));
  return items;
}

// =============================================================================
// Report rendering + CLI entry point
// =============================================================================

/// Build the machine-readable inventory seed as a JSON-encodable map.
Map<String, Object?> buildReport(List<AuditItem> items) {
  final byCategory = <String, int>{};
  final byCondition = <String, int>{};
  var compliant = 0;
  for (final item in items) {
    byCategory.update(item.category.json, (v) => v + 1, ifAbsent: () => 1);
    if (item.compliant) {
      compliant++;
    } else {
      for (final c in item.conditions) {
        byCondition.update(c.json, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }
  return <String, Object?>{
    'generatedBy': 'tool/responsive_audit.dart',
    'feature': 'cross-platform-responsive-ui',
    'summary': <String, Object?>{
      'totalScanned': items.length,
      'compliant': compliant,
      'nonCompliant': items.length - compliant,
      'byCategory': byCategory,
      'byCondition': byCondition,
    },
    'items': items.map((i) => i.toJson()).toList(),
  };
}

/// Locate the `lib/` directory whether the script runs from the Dukan_x
/// package root (`dart run tool/responsive_audit.dart`) or from the workspace
/// root (`Dukan_x/lib`).
Directory resolveLibDir() {
  final here = Directory('lib');
  if (here.existsSync()) return here;
  final nested = Directory('Dukan_x/lib');
  if (nested.existsSync()) return nested;
  return here; // listScannableFiles returns empty if it does not exist.
}

void main(List<String> args) {
  final libDir = resolveLibDir();
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: could not find a lib/ directory. Run this from the Dukan_x '
      'package root: dart run tool/responsive_audit.dart',
    );
    exitCode = 1;
    return;
  }

  final items = runAudit(libDir);
  final report = buildReport(items);

  // Write the machine-readable seed next to this script.
  final reportFile = File('tool/responsive_audit_report.json');
  reportFile.parent.createSync(recursive: true);
  reportFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );

  // Human-readable summary on stdout.
  final summary = report['summary'] as Map<String, Object?>;
  stdout.writeln('Responsive Audit — cross-platform-responsive-ui');
  stdout.writeln('Scanned lib dir: ${normalizePath(libDir.absolute.path)}');
  stdout.writeln('Total scanned items : ${summary['totalScanned']}');
  stdout.writeln('  compliant          : ${summary['compliant']}');
  stdout.writeln('  non-compliant      : ${summary['nonCompliant']}');
  stdout.writeln('By category:');
  (summary['byCategory'] as Map<String, Object?>).forEach((k, v) {
    stdout.writeln('  $k : $v');
  });
  stdout.writeln('By flagged condition:');
  final byCondition = summary['byCondition'] as Map<String, Object?>;
  if (byCondition.isEmpty) {
    stdout.writeln('  (none)');
  } else {
    byCondition.forEach((k, v) {
      stdout.writeln('  $k : $v');
    });
  }
  stdout.writeln('Wrote seed: ${normalizePath(reportFile.absolute.path)}');
}
