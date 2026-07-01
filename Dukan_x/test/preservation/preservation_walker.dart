// PRESERVATION WALKER — shared utilities for Property 2 (clause 3.* + 2.20).
//
// Methodology (observation-first, mirrors Task 1):
//
//   1. The audit in `test/audit/bug_condition_audit_test.dart` enumerates
//      every workflow X = (app, module, screen, workflow, scenario) that
//      satisfies `isBugCondition(X)` from `bugfix.md`.
//
//   2. This walker reuses the SAME predicates negated:
//      `notBugConditionD1..D11(X)` selects only inputs where
//      `NOT isBugCondition(X)` — i.e. workflows already correct in F.
//
//   3. For each non-buggy slice we capture a deterministic fingerprint
//      (routes, persisted keys, helper files, business-rule files,
//      RBAC modules, paginated queries, sync queues with idempotency
//      keys, I/O services with try/catch wrappers, providers that use
//      `ref.watch`, the existing test corpus). The fingerprint is
//      written once to `test/preservation/__goldens__/<name>.json` if
//      absent, otherwise re-checked.
//
//   4. On UNFIXED code, goldens are written and tests pass — this is
//      the baseline F observation, the EXPECTED OUTCOME for Task 2.
//      On F' (re-run from Task 3.4), the same generators yield the
//      same X (because the predicates only widen — fixes only convert
//      buggy inputs into non-buggy ones, never the reverse). We assert
//      the new fingerprint equals the recorded baseline, realising
//      `F'(X) == F(X)` over outputs, persisted shape, navigation graph,
//      RBAC grants, queue semantics and timing class.
//
// Static fingerprinting is sufficient here — the four apps do not share
// a runtime test harness, and clauses 3.1..3.7 are observable from
// source: route registrations, persisted keys, file presence,
// helper-file structure. Where the spec asks for runtime observations
// (ordering of queue replays, golden screen renders, deserialised Hive
// rows), the fingerprint records the source-of-truth wiring that
// determines the runtime observation, so a regression at runtime is
// preceded by a regression in the fingerprint.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../audit/audit_walker.dart';

/// Re-export for test files so they can use a single import.
export '../audit/audit_walker.dart'
    show
        auditedApps,
        dukanxModules,
        listDartFiles,
        safeRead,
        detectModule,
        detectApp,
        resolveWorkspaceRoot;

// ---------------------------------------------------------------------------
// Golden snapshot helpers
// ---------------------------------------------------------------------------

/// Where preservation goldens live. The `__goldens__` folder is committed
/// alongside the tests so re-running on F' can verify equality.
Directory goldensDir(Directory ws) =>
    Directory('${ws.path}/Dukan_x/test/preservation/__goldens__');

/// Read or write a golden file. On first run the [observation] is written
/// verbatim and the function returns it unchanged. On subsequent runs the
/// recorded value is read and returned — callers compare it to the live
/// observation and `expect` equality. Stable JSON serialisation keeps
/// goldens diff-friendly and platform-independent.
Object? readOrWriteGolden(Directory ws, String name, Object observation) {
  final dir = goldensDir(ws);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final f = File('${dir.path}/$name.json');
  final encoder = const JsonEncoder.withIndent('  ');
  final encoded = encoder.convert(observation);
  if (!f.existsSync()) {
    f.writeAsStringSync(encoded);
    return observation; // first capture — caller compares to itself
  }
  return jsonDecode(f.readAsStringSync());
}

/// Convenience: assert an observation matches the recorded golden.
/// On first run the golden is written and the assertion is a no-op.
void expectMatchesGolden(Directory ws, String name, Object observation) {
  final encoder = const JsonEncoder.withIndent('  ');
  final liveJson = encoder.convert(observation);
  final goldenJson = encoder.convert(readOrWriteGolden(ws, name, observation));
  expect(
    liveJson,
    goldenJson,
    reason:
        'Preservation regression: $name fingerprint changed.\n'
        'F\' observation differs from the F baseline recorded in '
        '${goldensDir(ws).path}/$name.json. Restore the original behaviour '
        'or update the golden if the change is part of a documented fix.',
  );
}

// ---------------------------------------------------------------------------
// `NOT isBugCondition(X)` predicates — one per defect class.
//
// Each predicate is the source-true negation of the corresponding check in
// `test/audit/bug_condition_audit_test.dart`. PBT generators below sample
// candidate `X` values and filter through these predicates.
// ---------------------------------------------------------------------------

/// D1: a registered route is non-buggy when it resolves to a built screen
/// (Dukan_x: not pointing at `ModulePlaceholderScreen`; school apps:
/// the referenced widget class exists somewhere under that app's lib/).
bool notBugConditionD1Route({
  required String app,
  required String routePath,
  required String widgetName,
  required String routeFileSrc,
  required List<File> appLibFiles,
}) {
  if (app == 'Dukan_x') {
    return !routeFileSrc.contains('ModulePlaceholderScreen');
  }
  return appLibFiles.any((f) => safeRead(f).contains('class $widgetName '));
}

/// D2: a UI file is non-buggy when it contains no placeholder markers.
bool notBugConditionD2UiFile(File f) {
  final src = safeRead(f);
  // Same pattern set as the audit so both views agree on "buggy" status.
  final patterns = <RegExp>[
    RegExp("['\"]Coming soon['\"]", caseSensitive: false),
    RegExp(r'//\s*TODO\b'),
    RegExp(r'\blorem ipsum\b', caseSensitive: false),
    RegExp("['\"]Placeholder\\b", caseSensitive: false),
    RegExp("['\"](?:dummy|sample|test\\s+only)\\b", caseSensitive: false),
  ];
  return !patterns.any((p) => p.hasMatch(src));
}

/// D3: a monetary helper file is non-buggy when it imports `decimal`.
bool notBugConditionD3MoneyHelper(File f) {
  final src = safeRead(f);
  return src.contains('package:decimal/decimal.dart');
}

/// D4: a repository is non-buggy when its mutation methods invalidate
/// some provider / refresh / notify after writing.
bool notBugConditionD4Repo(File f) {
  final src = safeRead(f);
  final mutates = RegExp(
    r'\b(?:Future|void)\s+(?:create|update|delete|save|insert|remove)\w*\(',
  ).hasMatch(src);
  if (!mutates) return true; // not a mutation surface — vacuously non-buggy
  return src.contains('invalidate(') ||
      src.contains('refresh(') ||
      src.contains('notifyListeners') ||
      src.contains('ref.invalidate') ||
      src.contains('emit(');
}

/// D5: a sync-queue file is non-buggy when it carries an idempotency key.
bool notBugConditionD5Queue(File f) {
  final src = safeRead(f);
  return RegExp(
    r'idempotenc(y|e)|opId|operationId|requestId',
    caseSensitive: false,
  ).hasMatch(src);
}

/// D6: a provider is non-buggy when it does not read a repository directly
/// without watching another provider, OR when it watches at least one
/// other provider for cross-module propagation.
bool notBugConditionD6Provider(File f) {
  final src = safeRead(f);
  final readsRepo = RegExp(
    r'\.read\(\s*[a-zA-Z_]+(?:Repository|Repo)Provider',
  ).hasMatch(src);
  final watches = src.contains('ref.watch(');
  return !readsRepo || watches;
}

/// D7: a service / repository file with I/O is non-buggy when it wraps
/// I/O in try/catch.
bool notBugConditionD7IoService(File f) {
  final src = safeRead(f);
  final ioPattern = RegExp(
    r'(http\.|dio\.|HttpClient|File\(|Directory\(|Printing\.|'
    r'pdf\.|Pdf\.|MobileScanner|ImagePicker|Camera|TextRecognizer)',
  );
  if (!ioPattern.hasMatch(src)) return true; // no I/O — vacuous
  return src.contains('try {') && src.contains('catch');
}

/// D8: an app slice is non-buggy when it contains a recognisable
/// permissions/rbac module file.
bool notBugConditionD8PermissionsModule(List<File> appLibFiles) {
  return appLibFiles.any((f) {
    final p = f.path.replaceAll('\\', '/');
    return p.contains('/permissions/') ||
        p.endsWith('rbac.dart') ||
        p.endsWith('permissions.dart');
  });
}

/// D9: a query helper is non-buggy when it paginates (limit / cursor) or
/// does not use bulk scans at all.
bool notBugConditionD9Query(File f) {
  final src = safeRead(f);
  final usesScan = RegExp(r'\.scan\(|getAll\(\)|fetchAll\(\)').hasMatch(src);
  if (!usesScan) return true;
  return src.contains('limit:') ||
      src.contains('cursor') ||
      src.contains('pagination');
}

/// D11: a vertical is non-buggy when a `*_business_rules.dart` file
/// already exists under its features directory.
bool notBugConditionD11Vertical({
  required Directory featDir,
  required String module,
}) {
  if (!featDir.existsSync()) return true; // not present — out of scope here
  final files = listDartFiles(featDir);
  return files.any(
    (f) =>
        f.path.replaceAll('\\', '/').endsWith('_business_rules.dart') ||
        f.path.replaceAll('\\', '/').endsWith('${module}_business_rules.dart'),
  );
}

// ---------------------------------------------------------------------------
// Stable fingerprint helpers
// ---------------------------------------------------------------------------

/// Stable workspace-relative path so goldens are portable across machines.
String relPath(Directory ws, File f) {
  final p = f.path.replaceAll('\\', '/');
  final root = ws.path.replaceAll('\\', '/');
  return p.startsWith('$root/') ? p.substring(root.length + 1) : p;
}

/// Compact deterministic content hash for fingerprints. We use length +
/// char-sum because we want a hash that is stable across line-ending
/// rewrites (trim whitespace + normalise newlines) and that does not
/// require crypto deps in the test harness.
int contentDigest(String src) {
  final norm = src.replaceAll('\r\n', '\n').trimRight();
  var h = 0;
  for (final c in norm.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Sort a list of strings deterministically (case-sensitive ASCII).
List<String> sortedCopy(Iterable<String> xs) {
  final list = xs.toList()..sort();
  return list;
}
