// AUDIT_SYSTEM — SCREEN ENUMERATOR (Task 2.1)
//
// Enumerates the selectable universe of `(Business_Type, Screen)` pairs that
// the single-target Iteration loop draws from. It is a PURE, importable static
// scanner mirroring `tool/responsive_audit.dart`: classification depends only
// on path + content strings, and the filesystem walk reuses the established
// helpers from `test/audit/audit_walker.dart` (DRY — AGENTS.md "avoid
// duplication / respect current architecture").
//
// What it produces:
//   * businessTypes(libDir) — every module under `lib/modules/` EXCEPT
//     `_template` (Req 1.4), sorted.
//   * screensFor(bt, libDir) — the `*_screen.dart` / `*_page.dart` route
//     destination widgets in the module plus the shared-feature screens under
//     `lib/features/` surfaced for that Business_Type.
//   * isScreen(path, content) — the PURE classifier: true iff the path denotes
//     a Flutter route-destination widget. This is the unit the Property 1
//     selection test (Task 2.3) leans on to build a screen universe.
//
// Run from the Dukan_x package root:
//
//     dart run tool/audit_system/screen_enumerator.dart
//
// Depends only on `dart:io` / `dart:convert` (+ the dart:io-only audit walker),
// so it imports cleanly into `flutter_test` + `dartproptest` VM suites.
//
// Part of: per-screen-business-type-audit-remediation
// _Requirements: 1.4, 2.2, 2.8_

import 'dart:convert';
import 'dart:io';

// Reuse the established enumeration helpers (DRY). audit_walker.dart depends
// only on `dart:io`, so it composes cleanly here.
import '../../test/audit/audit_walker.dart'
    show dukanxModules, listDartFiles, detectModule, resolveWorkspaceRoot;
import 'types.dart';

/// Normalize a filesystem path to forward slashes for stable matching/output.
String _normalize(String path) => path.replaceAll('\\', '/');

/// Convert an absolute (or relative) file path into a package-relative,
/// forward-slash path starting at `lib/`, so enumeration output is stable
/// regardless of the working directory.
String toLibRelativePath(String rawPath) {
  final p = _normalize(rawPath);
  final idx = p.indexOf('lib/');
  return idx >= 0 ? p.substring(idx) : p;
}

/// Matches a class that extends a Flutter widget base commonly used for route
/// destinations (plain Flutter + Riverpod + flutter_hooks variants).
final RegExp _widgetClassRe = RegExp(
  r'class\s+\w+\s+extends\s+'
  r'(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget'
  r'|HookWidget|HookConsumerWidget)\b',
);

/// A strong secondary signal that a file builds UI: a `build(BuildContext ...)`
/// method. Used so a screen authored via an uncommon base class is still
/// recognised.
final RegExp _buildMethodRe = RegExp(r'\bWidget\s+build\s*\(\s*BuildContext\b');

/// Enumerates the selectable `(Business_Type, Screen)` universe.
class ScreenEnumerator {
  const ScreenEnumerator();

  /// All non-`_template` modules under `lib/modules/`, sorted (Req 1.4).
  ///
  /// The on-disk `lib/modules/` directory is the source of truth; when it is
  /// unavailable the canonical [dukanxModules] list is used as a fallback so
  /// the enumerator degrades gracefully. `_template` is excluded in both paths.
  List<String> businessTypes(Directory libDir) {
    final modulesDir = Directory('${libDir.path}/modules');
    final names = <String>{};
    if (modulesDir.existsSync()) {
      for (final entity in modulesDir.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = _normalize(entity.path).split('/').last;
        if (name.isEmpty) continue;
        if (name == kTemplateModule) continue; // Req 1.4 boundary exclusion.
        if (name.startsWith('.')) continue;
        names.add(name);
      }
    } else {
      names.addAll(dukanxModules.where((m) => m != kTemplateModule));
    }
    final out = names.toList()..sort();
    return out;
  }

  /// Screens reachable for [businessType]: the route-destination widgets inside
  /// `lib/modules/<businessType>/` plus the shared-feature screens under
  /// `lib/features/` surfaced for the module. Returns sorted, de-duplicated
  /// [ScreenRef]s. The `_template` module yields an empty list (Req 1.4).
  List<ScreenRef> screensFor(String businessType, Directory libDir) {
    if (businessType == kTemplateModule) return const <ScreenRef>[];

    final refs = <ScreenRef>{};

    // 1. Module-local screens under lib/modules/<businessType>/. detectModule
    //    re-confirms the file truly belongs to this module before it is added,
    //    guarding against symlinked/nested stray paths.
    final moduleDir = Directory('${libDir.path}/modules/$businessType');
    for (final file in listDartFiles(moduleDir)) {
      final detected = detectModule(file);
      if (detected.isNotEmpty && detected != businessType) continue;
      final rel = toLibRelativePath(file.path);
      if (isScreen(rel, _safeRead(file))) {
        refs.add(ScreenRef(businessType: businessType, screenPath: rel));
      }
    }

    // 2. Shared-feature screens under lib/features/ surfaced for the module.
    final featuresDir = Directory('${libDir.path}/features');
    for (final file in listDartFiles(featuresDir)) {
      final rel = toLibRelativePath(file.path);
      if (isScreen(rel, _safeRead(file))) {
        refs.add(ScreenRef(businessType: businessType, screenPath: rel));
      }
    }

    final out = refs.toList()..sort();
    return out;
  }

  /// True iff [filePath] denotes a Flutter route-destination widget.
  ///
  /// Pure: depends only on the path + content strings (no I/O). A screen is a
  /// `*_screen.dart` or `*_page.dart` source file (excluding generated sources)
  /// whose content declares a widget subclass or a `build(BuildContext)`
  /// method. (Req 2.2 — Screen identified by file path.)
  bool isScreen(String filePath, String fileContent) {
    final p = _normalize(filePath);
    if (!p.endsWith('.dart')) return false;
    if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return false;

    final name = p.split('/').last;
    final isScreenFile =
        name.endsWith('_screen.dart') || name.endsWith('_page.dart');
    if (!isScreenFile) return false;

    // Must actually declare a route-destination widget, not merely be named so.
    return _widgetClassRe.hasMatch(fileContent) ||
        _buildMethodRe.hasMatch(fileContent);
  }

  /// Build the full [ScreenUniverse] over [libDir], excluding `_template`.
  /// Convenience for callers/tests that need the whole selectable space.
  ScreenUniverse buildUniverse(Directory libDir) {
    final byType = <String, List<ScreenRef>>{};
    for (final bt in businessTypes(libDir)) {
      byType[bt] = screensFor(bt, libDir);
    }
    return ScreenUniverse(byType);
  }
}

String _safeRead(File f) {
  try {
    return f.readAsStringSync();
  } catch (_) {
    return '';
  }
}

// =============================================================================
// CLI entry point — mirrors tool/responsive_audit.dart's shell.
// =============================================================================

/// Locate the `lib/` directory whether the script runs from the Dukan_x
/// package root (`dart run tool/audit_system/screen_enumerator.dart`) or from
/// the workspace root.
Directory resolveLibDir() {
  final here = Directory('lib');
  if (here.existsSync()) return here;
  final nested = Directory('Dukan_x/lib');
  if (nested.existsSync()) return nested;
  // Last resort: derive from the workspace root locator in the audit walker.
  try {
    final root = resolveWorkspaceRoot();
    return Directory('${root.path}/Dukan_x/lib');
  } catch (_) {
    return here; // buildUniverse returns an empty universe if absent.
  }
}

void main(List<String> args) {
  final libDir = resolveLibDir();
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: could not find a lib/ directory. Run this from the Dukan_x '
      'package root: dart run tool/audit_system/screen_enumerator.dart',
    );
    exitCode = 1;
    return;
  }

  const enumerator = ScreenEnumerator();
  final universe = enumerator.buildUniverse(libDir);

  final report = <String, Object?>{
    'generatedBy': 'tool/audit_system/screen_enumerator.dart',
    'feature': 'per-screen-business-type-audit-remediation',
    'libDir': _normalize(libDir.absolute.path),
    'businessTypeCount': universe.businessTypes.length,
    'totalScreens': universe.totalScreens,
    'businessTypes': <String, Object?>{
      for (final bt in universe.businessTypes)
        bt: universe.screensFor(bt).map((s) => s.screenPath).toList(),
    },
  };

  stdout.writeln(
    'Screen Enumerator — per-screen-business-type-audit-remediation',
  );
  stdout.writeln('Scanned lib dir : ${_normalize(libDir.absolute.path)}');
  stdout.writeln(
    'Business types  : ${universe.businessTypes.length} '
    '(excludes $kTemplateModule)',
  );
  stdout.writeln('Total screens   : ${universe.totalScreens}');
  for (final bt in universe.businessTypes) {
    stdout.writeln('  $bt : ${universe.screensFor(bt).length} screen(s)');
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(report['businessTypes']),
  );
}
