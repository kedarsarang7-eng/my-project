// AUDIT WALKER — shared scanning utilities for the end-to-end audit.
//
// This is a STATIC source-tree walker. It produces deterministic counter-
// examples that satisfy `isBugCondition(X)` from `bugfix.md`. The audit is
// EXPECTED TO FAIL on unfixed code: each failure row is an inventory entry
// in the clause-2.18 schema:
//
//   defect-id | app | module | screen/workflow | defect-class
//   severity  | repro-steps | observed | expected | proposed-fix-scope
//
// We use static analysis (file existence, content patterns) rather than
// runtime widget pumping because:
//   1. The four apps do not share a test runner / build environment.
//   2. The defect set is heterogeneous and many classes (D1 dead routes,
//      D2 placeholder strings, D7 swallowed errors, D8 missing RBAC layer,
//      D11 missing per-vertical business-rule files) are detectable from
//      source alone.
//   3. The output must be deterministic so that Task 3.1 can lift findings
//      into `audit/defect-inventory.md` verbatim.

import 'dart:io';

/// One row of the defect inventory (clause 2.18 schema).
class Finding {
  Finding({
    required this.defectId,
    required this.app,
    required this.module,
    required this.workflow,
    required this.defectClass,
    required this.severity,
    required this.repro,
    required this.observed,
    required this.expected,
    required this.fixScope,
  });

  final String defectId;
  final String app;
  final String module;
  final String workflow;
  final String defectClass; // D1..D11
  final String severity; // blocker | critical | major | minor
  final String repro;
  final String observed;
  final String expected;
  final String fixScope;

  String toRow() {
    return '| $defectId | $app | $module | $workflow | $defectClass | '
        '$severity | $repro | $observed | $expected | $fixScope |';
  }
}

/// Render a list of findings as a Markdown table that can be pasted into
/// `audit/defect-inventory.md` unmodified.
String renderInventory(String defectClass, List<Finding> findings) {
  if (findings.isEmpty) {
    return '($defectClass) no findings';
  }
  final buf = StringBuffer()
    ..writeln()
    ..writeln(
      '### Defect inventory rows for $defectClass '
      '(${findings.length} entries)',
    )
    ..writeln()
    ..writeln(
      '| defect-id | app | module | screen/workflow | defect-class '
      '| severity | repro | observed | expected | proposed-fix-scope |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final f in findings) {
    buf.writeln(f.toRow());
  }
  return buf.toString();
}

/// Resolve the workspace root from the current directory. Tests run with
/// cwd at the Flutter package root (e.g. `Dukan_x/`), so the workspace
/// root is one level up.
Directory resolveWorkspaceRoot() {
  var d = Directory.current;
  for (var i = 0; i < 5; i++) {
    final hasDukanx = Directory('${d.path}/Dukan_x').existsSync();
    final hasAdmin = Directory('${d.path}/school_admin_app').existsSync();
    if (hasDukanx && hasAdmin) return d;
    final parent = d.parent;
    if (parent.path == d.path) break;
    d = parent;
  }
  throw StateError(
    'Could not locate workspace root from ${Directory.current.path}; '
    'expected to find Dukan_x/ and school_admin_app/ siblings.',
  );
}

/// The four apps in scope (clause 1.* "across all four Flutter apps").
const auditedApps = <String>[
  'Dukan_x',
  'school_admin_app',
  'school_teacher_app',
  'school_student_app',
];

/// Modules in Dukan_x — clause 1.16 / design-doc Glossary.
const dukanxModules = <String>[
  'auto_parts',
  'book_store',
  'clinic',
  'clothing',
  'computer_shop',
  'decoration_catering',
  'grocery',
  'hardware',
  'jewellery',
  'mobile_shop',
  'petrol_pump',
  'pharmacy',
  'restaurant',
  'school_erp',
  'vegetables_broker',
  'wholesale',
];

/// Recursively list all `.dart` files under [root], skipping generated
/// files and build artifacts.
List<File> listDartFiles(Directory root) {
  if (!root.existsSync()) return const <File>[];
  final out = <File>[];
  for (final e in root.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final p = e.path.replaceAll('\\', '/');
    if (!p.endsWith('.dart')) continue;
    if (p.contains('/.dart_tool/')) continue;
    if (p.contains('/build/')) continue;
    if (p.contains('/generated/')) continue;
    if (p.endsWith('.g.dart')) continue;
    if (p.endsWith('.freezed.dart')) continue;
    out.add(e);
  }
  return out;
}

/// Count occurrences of [needle] across [files], capping per-file scan
/// for safety.
int countOccurrences(List<File> files, RegExp needle) {
  var n = 0;
  for (final f in files) {
    final s = _safeRead(f);
    n += needle.allMatches(s).length;
  }
  return n;
}

String _safeRead(File f) {
  try {
    return f.readAsStringSync();
  } catch (_) {
    return '';
  }
}

/// Read a file as a string, returning '' on failure.
String safeRead(File f) => _safeRead(f);

/// Module of [file] inside `Dukan_x/lib/features/<m>/...` or
/// `lib/modules/<m>/...`; empty string if not under a recognised module.
String detectModule(File f) {
  final p = f.path.replaceAll('\\', '/');
  final mFeat = RegExp(r'/lib/features/([^/]+)/').firstMatch(p);
  if (mFeat != null) return mFeat.group(1)!;
  final mMod = RegExp(r'/lib/modules/([^/]+)/').firstMatch(p);
  if (mMod != null) return mMod.group(1)!;
  return '';
}

/// Detect the app slice the file belongs to by inspecting the path prefix.
String detectApp(File f) {
  final p = f.path.replaceAll('\\', '/');
  for (final app in auditedApps) {
    if (p.contains('/$app/')) return app;
  }
  return '';
}
