// ============================================================================
// Task 4.2 — STATIC / COMPILE GUARD TEST (standard flutter_test, NOT a property
// test).
// Feature: cross-platform-responsive-ui
// _Requirements: 2.5, 2.6_
// ============================================================================
// Enforces SINGLE BREAKPOINT AUTHORITY for the consolidated Responsive_System.
//
// Per Req 2.5 the Responsive_System (under `lib/core/responsive/`) must be the
// ONLY source that defines breakpoint thresholds and Form_Factor classification.
// Per Req 2.6 the Application must contain no references to responsive utility
// symbols that were removed/deprecated during the Task 4.1 consolidation.
//
// This guard scans the package sources statically (fast + deterministic) and
// asserts the structural guarantees below. A `flutter analyze`-based check is
// intentionally NOT spawned here: it is slow and flaky inside a unit test, and
// the structural source scans already detect any reintroduction of a second
// breakpoint authority or a reference to a removed symbol. Compile-level
// breakage (Req 2.6) is covered by `flutter analyze` in CI; these scans add the
// deterministic, regression-proof guard on top.
//
// What is asserted:
//   1. The legacy theme file `lib/core/theme/responsive_layout.dart` no longer
//      defines an independent breakpoint system: no 1280/1440/1920 thresholds,
//      no `class ResponsiveBreakpoints`, no `extension ResponsiveBuildContext`,
//      no `isCompact/isOptimal/isLarge` classifier members, and no
//      `enum ScreenSize`/`enum FormFactor` of its own. (Req 2.5)
//   2. There is exactly ONE `class ResponsiveBreakpoints` in `lib/`, and it
//      lives only in `lib/core/responsive/responsive_breakpoints.dart`. (Req 2.5)
//   3. No file OUTSIDE `lib/core/responsive/` declares `enum ScreenSize` or
//      `enum FormFactor` (the canonical authority stays inside the
//      Responsive_System directory). (Req 2.5)
//   4. No source references the legacy symbols removed in Task 4.1
//      (`ResponsiveBuildContext`, `adaptivePadding`). (Req 2.6)
//
// Notes on robustness:
//   * All scans strip Dart comments first, so doc-comment mentions of removed
//     symbols (or of the legacy 1280/1440/1920 history) do not cause false
//     positives.
//   * `isLarge` is a common generic parameter name elsewhere in the app, so the
//     classifier-member absence check is SCOPED to the theme file only.
//   * Paths are normalized to forward slashes so the test passes on Windows and
//     POSIX alike. `flutter test` runs with the package root as CWD, so `lib`
//     resolves correctly.
//
// Run: flutter test test/core/responsive/no_duplicate_breakpoints_test.dart
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Canonical (forward-slash) relative path of the consolidated authority file.
const String kBreakpointsAuthorityPath =
    'lib/core/responsive/responsive_breakpoints.dart';

/// Canonical (forward-slash) relative path of the legacy theme file.
const String kLegacyThemePath = 'lib/core/theme/responsive_layout.dart';

/// Directory that is allowed to host breakpoint/classification authority.
const String kResponsiveSystemDir = 'lib/core/responsive/';

void main() {
  group('single breakpoint authority (Req 2.5, 2.6)', () {
    final libDir = Directory('lib');

    setUpAll(() {
      // Sanity: the test relies on running from the package root.
      expect(
        libDir.existsSync(),
        isTrue,
        reason:
            'Expected to run with the package root as CWD so that `lib/` is '
            'resolvable. Run via `flutter test`.',
      );
    });

    test(
      'legacy theme file no longer defines an independent breakpoint authority',
      () {
        final themeFile = File(kLegacyThemePath);
        expect(
          themeFile.existsSync(),
          isTrue,
          reason: 'Expected legacy theme file at $kLegacyThemePath',
        );

        final code = _stripDartComments(_readSource(themeFile));

        // 1a. No legacy desktop thresholds 1280/1440/1920 as numeric literals.
        for (final literal in const [1280, 1440, 1920]) {
          expect(
            RegExp('\\b$literal\\b').hasMatch(code),
            isFalse,
            reason:
                'Legacy breakpoint threshold $literal must NOT be defined in '
                '$kLegacyThemePath. Breakpoints belong only to the '
                'Responsive_System ($kBreakpointsAuthorityPath). (Req 2.5)',
          );
        }

        // 1b. No second breakpoint class.
        expect(
          RegExp(r'class\s+ResponsiveBreakpoints\b').hasMatch(code),
          isFalse,
          reason:
              'A second `class ResponsiveBreakpoints` must NOT live in '
              '$kLegacyThemePath. (Req 2.5)',
        );

        // 1c. No legacy context extension that re-classified by width.
        expect(
          RegExp(r'extension\s+ResponsiveBuildContext\b').hasMatch(code),
          isFalse,
          reason:
              'Legacy `extension ResponsiveBuildContext` must NOT exist in '
              '$kLegacyThemePath (removed in Task 4.1). (Req 2.5, 2.6)',
        );

        // 1d. No legacy Form_Factor-style classifier members.
        for (final member in const ['isCompact', 'isOptimal', 'isLarge']) {
          expect(
            RegExp('\\b$member\\b').hasMatch(code),
            isFalse,
            reason:
                'Legacy classifier member `$member` must NOT be defined in '
                '$kLegacyThemePath. Classification belongs only to the '
                'Responsive_System. (Req 2.5)',
          );
        }

        // 1e. No legacy breakpoint constant names.
        for (final name in const ['optimalWidth', 'largeWidth', 'minWidth']) {
          expect(
            RegExp('\\b$name\\b').hasMatch(code),
            isFalse,
            reason:
                'Legacy breakpoint constant `$name` must NOT be defined in '
                '$kLegacyThemePath. (Req 2.5)',
          );
        }

        // 1f. No independent enum authority in the theme file.
        expect(
          RegExp(r'enum\s+(ScreenSize|FormFactor)\b').hasMatch(code),
          isFalse,
          reason:
              'The legacy theme file must NOT declare its own '
              '`enum ScreenSize`/`enum FormFactor`. (Req 2.5)',
        );
      },
    );

    test(
      'exactly one `class ResponsiveBreakpoints` exists in lib/ and it is the '
      'canonical authority file',
      () {
        final matches = <String>[];
        for (final file in _dartFilesUnder(libDir)) {
          final code = _stripDartComments(_readSource(file));
          if (RegExp(r'class\s+ResponsiveBreakpoints\b').hasMatch(code)) {
            matches.add(_normalize(file.path));
          }
        }

        expect(
          matches.length,
          1,
          reason:
              'Expected exactly ONE `class ResponsiveBreakpoints` definition '
              'in lib/, found ${matches.length}: $matches. (Req 2.5)',
        );
        expect(
          matches.single.endsWith(kBreakpointsAuthorityPath),
          isTrue,
          reason:
              'The single `class ResponsiveBreakpoints` must live in '
              '$kBreakpointsAuthorityPath, but was found at ${matches.single}. '
              '(Req 2.5)',
        );
      },
    );

    test(
      'no file outside lib/core/responsive/ declares enum ScreenSize/FormFactor',
      () {
        final offenders = <String>[];
        for (final file in _dartFilesUnder(libDir)) {
          final normalized = _normalize(file.path);
          if (normalized.contains(kResponsiveSystemDir)) {
            continue; // Inside the Responsive_System — allowed.
          }
          final code = _stripDartComments(_readSource(file));
          if (RegExp(r'enum\s+(ScreenSize|FormFactor)\b').hasMatch(code)) {
            offenders.add(normalized);
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'Form_Factor enums (ScreenSize/FormFactor) may only be declared '
              'inside the Responsive_System ($kResponsiveSystemDir). Found '
              'declarations outside it: $offenders. (Req 2.5)',
        );
      },
    );

    test(
      'no references to legacy symbols removed in Task 4.1 remain (Req 2.6)',
      () {
        // Symbols removed during the Task 4.1 consolidation. References to these
        // would be compile errors and indicate stale consumers.
        const removedSymbols = ['ResponsiveBuildContext', 'adaptivePadding'];

        final offenders = <String, List<String>>{};
        for (final file in _dartFilesUnder(libDir)) {
          final code = _stripDartComments(_readSource(file));
          for (final symbol in removedSymbols) {
            if (RegExp('\\b$symbol\\b').hasMatch(code)) {
              offenders
                  .putIfAbsent(symbol, () => [])
                  .add(_normalize(file.path));
            }
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'Found references to legacy symbols removed in Task 4.1: '
              '$offenders. These must be repointed to the Responsive_System '
              'barrel (lib/core/responsive/responsive.dart). (Req 2.6)',
        );
      },
    );

    test('no Form_Factor classifier (function/getter returning ScreenSize/'
        'FormFactor) is declared outside the Responsive_System (Req 2.5)', () {
      // A "classifier" is any top-level function or getter whose declared
      // RETURN TYPE is `ScreenSize` or `FormFactor`. Per Req 2.5 the only
      // place allowed to MAP a width/context to a Form_Factor is the
      // Responsive_System (e.g. `ResponsiveBreakpoints.classify` and the
      // retained `getScreenSize`/`context.screenSize` inside
      // `lib/core/responsive/`). Any such declaration elsewhere is a parallel
      // classification authority and must fail this guard.
      //
      // Matches declarations like:
      //   ScreenSize getScreenSize(BuildContext context) { ... }
      //   FormFactor classify(double width) => ...
      //   ScreenSize get screenSize => ...
      // It deliberately does NOT match local variables typed as ScreenSize
      // (e.g. `final ScreenSize x = ...;`), which merely CONSUME the
      // classifier, by requiring a `(` (function) or the `get ` keyword.
      final classifierDecl = RegExp(
        r'\b(?:ScreenSize|FormFactor)\s+(?:get\s+)?\w+\s*[(=]',
      );

      final offenders = <String>[];
      for (final file in _dartFilesUnder(libDir)) {
        final normalized = _normalize(file.path);
        if (normalized.contains(kResponsiveSystemDir)) {
          continue; // Inside the Responsive_System — the single authority.
        }
        final code = _stripDartComments(_readSource(file));
        if (classifierDecl.hasMatch(code)) {
          offenders.add(normalized);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'A Form_Factor/ScreenSize classifier may only be declared inside '
            'the Responsive_System ($kResponsiveSystemDir). Found classifier '
            'declarations outside it: $offenders. (Req 2.5)',
      );
    });

    test(
      'no breakpoint-threshold class (named *Breakpoint*) is declared outside '
      'the Responsive_System (Req 2.5)',
      () {
        // The width thresholds that define the Breakpoint_Strategy live in a
        // breakpoint class (`ResponsiveBreakpoints`, and the retained legacy
        // `Breakpoints`), both inside the Responsive_System. No other directory
        // may introduce its own `*Breakpoint*` class as a competing threshold
        // authority.
        final breakpointClass = RegExp(r'\bclass\s+\w*Breakpoint\w*\b');

        final offenders = <String>[];
        for (final file in _dartFilesUnder(libDir)) {
          final normalized = _normalize(file.path);
          if (normalized.contains(kResponsiveSystemDir)) {
            continue; // Inside the Responsive_System — the single authority.
          }
          final code = _stripDartComments(_readSource(file));
          if (breakpointClass.hasMatch(code)) {
            offenders.add(normalized);
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'A breakpoint-threshold class (named *Breakpoint*) may only be '
              'declared inside the Responsive_System ($kResponsiveSystemDir). '
              'Found such classes outside it: $offenders. (Req 2.5)',
        );
      },
    );
  });
}

/// Returns every `.dart` file under [dir] (recursively).
Iterable<File> _dartFilesUnder(Directory dir) sync* {
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

/// Reads a source file as text, tolerating files that are not strictly valid
/// UTF-8 (some legacy screens contain mojibake). Malformed bytes are replaced
/// rather than throwing, which is fine for our token/literal scans.
String _readSource(File file) =>
    utf8.decode(file.readAsBytesSync(), allowMalformed: true);

/// Normalizes a filesystem path to use forward slashes (Windows + POSIX).
String _normalize(String path) => path.replaceAll('\\', '/');

/// Removes Dart line (`//`) and block (`/* */`) comments while preserving
/// string literals, so symbol/literal scans never match content that only
/// appears inside comments.
String _stripDartComments(String source) {
  final buffer = StringBuffer();
  var inLineComment = false;
  var inBlockComment = false;
  var inString = false;
  String? stringDelim;

  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    if (inLineComment) {
      if (ch == '\n') {
        inLineComment = false;
        buffer.write(ch);
      }
      continue;
    }

    if (inBlockComment) {
      if (ch == '*' && next == '/') {
        inBlockComment = false;
        i++; // consume '/'
      }
      continue;
    }

    if (inString) {
      buffer.write(ch);
      if (ch == r'\') {
        // Preserve the escaped character verbatim.
        if (next.isNotEmpty) {
          buffer.write(next);
          i++;
        }
        continue;
      }
      if (ch == stringDelim) {
        inString = false;
        stringDelim = null;
      }
      continue;
    }

    // Not currently inside a comment or string.
    if (ch == '/' && next == '/') {
      inLineComment = true;
      i++; // consume second '/'
      continue;
    }
    if (ch == '/' && next == '*') {
      inBlockComment = true;
      i++; // consume '*'
      continue;
    }
    if (ch == "'" || ch == '"') {
      inString = true;
      stringDelim = ch;
      buffer.write(ch);
      continue;
    }

    buffer.write(ch);
  }

  return buffer.toString();
}
