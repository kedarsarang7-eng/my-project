// ============================================================================
// Task 1.4 — ARCHITECTURE (source-scanning) TEST
// Feature: mobile-text-scale-responsive-hardening
// Single scale source: there is exactly ONE text-scale override site and the
// dead double-scaling `AccessibilityThemeBuilder` no longer exists in source.
//
// **Validates: Requirements 1.1, 1.5, 2.1, 2.3**
// ============================================================================
//
// WHY AN ARCHITECTURE TEST (not a property test)?
//   "There is exactly one scale source" and "the double-scaling widget no
//   longer exists" are STRUCTURAL facts about the source tree, not input-varying
//   runtime behaviors. They are best proven by scanning `lib/` source directly
//   (the design's Testing Strategy calls for an architecture/source-scan test
//   here, mirroring `test/tool/responsive_audit_totality_property_test.dart`,
//   which also reads files via `dart:io` with CWD = package root).
//
// WHAT EACH CHECK PROVES
//   1. (R1.5, R2.1, R2.3) `AccessibilityThemeBuilder` — the removed widget that
//      double-scaled via `textTheme.fontSizeFactor` + a nested
//      `MediaQuery.textScaler` — appears ZERO times in *code* anywhere under
//      `lib/`. We strip comments first, because `accessibility_theme.dart`
//      intentionally documents the removal in a comment (that mention must NOT
//      count as the class still existing).
//   2. (R1.1) `lib/app/app.dart` contains EXACTLY ONE `MediaQuery.textScaler`
//      override site — i.e. exactly one place that assigns the `textScaler:`
//      named argument (the `MaterialApp.builder` clamp adapter). Read-only uses
//      such as `data.textScaler.scale(1.0)` use member access (`.textScaler.`)
//      and are deliberately NOT counted as override sites.
//
// MATCHING CHOICE (documented per task):
//   * Override site = the `textScaler:` NAMED ARGUMENT assignment. In Flutter
//     the only ways to override the tree's scaler are `MediaQueryData.copyWith(
//     textScaler: ...)` or `MediaQuery(data: ...textScaler...)`; both surface as
//     a `textScaler:` named argument. The regex `textScaler\s*:` matches that
//     assignment form while NOT matching the member-access READ form
//     `data.textScaler.scale(...)` (which is `.textScaler.`, no colon).
//   * We strip Dart `//` line and `/* ... */` block comments before counting so
//     documentation mentions never inflate either count.
//
// Run: flutter test test/responsive/single_scale_source_architecture_test.dart
//   (flutter test runs with CWD = package root, so `lib/` resolves).
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Removes Dart comments from [source] so that documentation mentions of a
/// symbol are not mistaken for live code. Strips `/* ... */` block comments
/// (including across line boundaries) first, then trims each line from any `//`
/// to its end. This is a deliberately simple, defensible strip: neither target
/// token (`AccessibilityThemeBuilder`, `textScaler:`) ever appears inside a
/// string literal or URL in the scanned files, so naive `//` trimming is safe
/// here and is the same spirit of source-scanning used by the existing
/// responsive audit test.
String stripDartComments(String source) {
  // Remove block comments /* ... */ (non-greedy, dotAll for multi-line).
  final withoutBlocks = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  // Remove line comments: from `//` to end-of-line, per line.
  return withoutBlocks
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx == -1 ? line : line.substring(0, idx);
      })
      .join('\n');
}

/// Resolves the package `lib/` directory. `flutter test` runs with CWD = the
/// package root, so a relative `lib` path resolves correctly.
Directory resolveLibDir() => Directory('lib');

void main() {
  group('Feature: mobile-text-scale-responsive-hardening — single scale source '
      '(architecture / source-scan)', () {
    test('AccessibilityThemeBuilder no longer exists anywhere in lib/ source '
        '(R1.5, R2.1, R2.3)', () {
      final libDir = resolveLibDir();
      expect(
        libDir.existsSync(),
        isTrue,
        reason:
            'lib/ must resolve when run from the package root via '
            'flutter test.',
      );

      final offenders = <String>[];
      int scanned = 0;

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        scanned++;
        final code = stripDartComments(entity.readAsStringSync());
        if (code.contains('AccessibilityThemeBuilder')) {
          offenders.add(entity.path);
        }
      }

      // Sanity: we actually walked a real, non-trivial source tree.
      expect(
        scanned,
        greaterThan(0),
        reason: 'Expected to scan at least one .dart file under lib/.',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'AccessibilityThemeBuilder (the removed double-scaling widget) '
            'must not appear in code in any lib/ file. Found in: '
            '${offenders.join(', ')}',
      );
    });

    test('lib/app/app.dart has exactly ONE MediaQuery.textScaler override site '
        '(R1.1)', () {
      final appFile = File('lib/app/app.dart');
      expect(
        appFile.existsSync(),
        isTrue,
        reason: 'lib/app/app.dart must exist.',
      );

      final code = stripDartComments(appFile.readAsStringSync());

      // Count `textScaler:` named-argument assignments (the override form).
      // The member-access READ form `data.textScaler.scale(1.0)` is NOT
      // matched because it has no `:` after `textScaler`.
      final overrideSites = RegExp(r'textScaler\s*:').allMatches(code).length;

      expect(
        overrideSites,
        equals(1),
        reason:
            'MaterialApp.builder must be the ONLY site that overrides '
            'MediaQuery.textScaler. Found $overrideSites override '
            'assignment(s) (expected exactly 1).',
      );
    });
  });
}
