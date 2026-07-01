// ============================================================================
// Task 8.1 — STATIC AUDIT TEST (non-PBT, structural)
// Feature: mobile-text-scale-responsive-hardening
// **Validates: Requirement 3.5** — "THE DukanX_App SHALL NOT use unbounded
//   hardcoded font sizes inside narrow or fixed containers that lack an
//   Overflow_Safe_Widget mechanism."
// ============================================================================
//
// WHAT THIS TEST DOES
//   It statically scans the files TOUCHED by this spec plus the shared
//   overflow-safe primitives, and asserts that none of them introduces an
//   "unbounded hardcoded font offender": a `Text` carrying a hardcoded numeric
//   `fontSize:` literal that lives inside a *fixed-width / narrow* container
//   (`SizedBox(width: <N>)`, `Container(... width: <N> ...)`, or
//   `ConstrainedBox(... maxWidth: <N> ...)`) whose subtree contains NO
//   Overflow_Safe_Widget mechanism.
//
//   This is the exact regression that R3.5 forbids: a fixed-width box with a
//   hardcoded font and no `maxLines`/`overflow`/`FittedBox`/`softWrap`/`Flexible`
//   /`Expanded`/`responsiveValue`/`OverflowSafe*` escape hatch WILL clip or
//   overflow once the system text scale is raised on a narrow phone viewport.
//
// WHY A HEURISTIC (and its documented limitations)
//   A perfectly precise check would require a full Dart AST + widget-tree
//   analysis (resolving which container actually constrains which Text). That
//   is heavy and brittle. Instead we use a PRAGMATIC, brace-/paren-aware string
//   scan that is deliberately tuned to:
//     * CATCH the clear regression pattern (fixed-width box + hardcoded font +
//       no overflow-safe token anywhere in that box's subtree), and
//     * ERR TOWARD FALSE NEGATIVES rather than false positives — i.e. if ANY
//       recognised overflow-safe token is present in the enclosing fixed box's
//       subtree, the font is treated as protected. This keeps the audit stable
//       in CI (it will not fail on a legitimately-guarded layout) while still
//       failing loudly the moment an unguarded fixed-width hardcoded-font Text
//       is added.
//
//   Known limitations (acceptable for a heuristic gate):
//     - A fixed-width box that legitimately guards Text A but also contains an
//       unrelated unguarded Text B would be treated as safe (the token is
//       present somewhere in the subtree). This is the chosen conservative
//       trade-off; precise per-Text attribution needs an AST.
//     - Containers whose width is a non-literal expression (a variable) are NOT
//       treated as fixed, because we cannot statically know they are narrow.
//     - `width: double.infinity` containers (e.g. full-width banners) are NOT
//       fixed/narrow and are excluded.
//
// HONESTY CONTRACT
//   If the scan finds a genuine offender it FAILS and prints the file, line,
//   and snippet so it is REPORTED rather than masked. If the touched files are
//   already compliant the test passes. Two embedded self-tests prove the
//   detector actually fires on a synthetic offender and does NOT fire on a
//   synthetic guarded layout, so the passing case is meaningful (not trivial).
//
// CONVENTIONS
//   Mirrors the source-scanning style of
//   `test/tool/responsive_audit_totality_property_test.dart`: pure `dart:io`,
//   CWD = package root (so `lib/...` resolves under `flutter test`).
//
// Run: flutter test test/responsive/unbounded_font_audit_test.dart -r expanded
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files in scope for this audit: every file touched by this spec plus the
/// shared overflow-safe primitives. Paths are relative to the package root
/// (CWD under `flutter test`).
const List<String> kInScopeFiles = <String>[
  'lib/widgets/responsive/overflow_safe.dart',
  'lib/widgets/desktop/desktop_content_container.dart',
  'lib/features/revenue/screens/proforma_screen.dart',
  'lib/features/buy_flow/screens/buy_orders_screen.dart',
  'lib/features/gst/screens/gst_reports_screen.dart',
  'lib/features/revenue/screens/return_inwards_screen.dart',
];

/// Constructors treated as "fixed-width / narrow" containers, mapped to the
/// argument key whose numeric literal pins a fixed width.
const Map<String, String> kFixedWidthContainers = <String, String>{
  'SizedBox': 'width',
  'Container': 'width',
  'ConstrainedBox': 'maxWidth',
};

/// Tokens that indicate an Overflow_Safe_Widget mechanism is present in a
/// subtree. The presence of ANY of these inside a fixed-width container's
/// subtree clears the hardcoded font of being an "unbounded" offender.
const List<String> kOverflowSafeTokens = <String>[
  'maxLines',
  'overflow:',
  'TextOverflow',
  'FittedBox',
  'Flexible',
  'Expanded',
  'softWrap',
  'responsiveValue',
  'OverflowSafeLabelValueRow',
  'OverflowSafeInfoBanner',
  'AutoSizeText',
];

/// A located offender, for human-readable failure reporting.
class _Offender {
  _Offender(this.file, this.line, this.snippet);
  final String file;
  final int line;
  final String snippet;

  @override
  String toString() => '$file:$line  ->  $snippet';
}

void main() {
  group('Feature: mobile-text-scale-responsive-hardening, Requirement 3.5: '
      'no unbounded hardcoded fonts in narrow/fixed containers', () {
    test('self-test: detector FIRES on a synthetic unguarded fixed-width '
        'hardcoded-font Text (proves the audit is non-trivial)', () {
      const offending = '''
Widget build(BuildContext context) {
  return SizedBox(
    width: 80,
    child: Text('₹12,34,567', style: TextStyle(fontSize: 18)),
  );
}
''';
      final offenders = findUnboundedFontOffenders('synthetic.dart', offending);
      expect(
        offenders,
        isNotEmpty,
        reason:
            'A fixed-width SizedBox holding a hardcoded-font Text with no '
            'overflow-safe mechanism MUST be flagged.',
      );
    });

    test('self-test: detector does NOT fire when an overflow-safe mechanism '
        'is present (no false positive)', () {
      const guarded = '''
Widget build(BuildContext context) {
  return SizedBox(
    width: 80,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('₹12,34,567',
          style: TextStyle(fontSize: 18), maxLines: 1),
    ),
  );
}
''';
      final offenders = findUnboundedFontOffenders('synthetic.dart', guarded);
      expect(
        offenders,
        isEmpty,
        reason: 'A FittedBox + maxLines guard MUST clear the hardcoded font.',
      );
    });

    test('self-test: a content-sized container (no fixed width) is not in '
        'scope even with a hardcoded font', () {
      // Chips/buttons size to their content and cannot clip — not "fixed".
      const chip = '''
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  child: const Text('Month', style: TextStyle(fontSize: 12)),
)
''';
      expect(findUnboundedFontOffenders('synthetic.dart', chip), isEmpty);
    });

    test(
      'self-test: width: double.infinity is not a narrow/fixed container',
      () {
        const fullWidth = '''
Container(
  width: double.infinity,
  child: const Text('PENDING banner text', style: TextStyle(fontSize: 14)),
)
''';
        expect(
          findUnboundedFontOffenders('synthetic.dart', fullWidth),
          isEmpty,
        );
      },
    );

    test('in-scope files contain no unbounded hardcoded-font offenders '
        '(R3.5)', () {
      final List<_Offender> allOffenders = <_Offender>[];

      for (final relativePath in kInScopeFiles) {
        final file = File(relativePath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'In-scope file must resolve from the package root '
              '(CWD under flutter test): $relativePath',
        );
        final content = file.readAsStringSync();
        allOffenders.addAll(findUnboundedFontOffenders(relativePath, content));
      }

      expect(
        allOffenders,
        isEmpty,
        reason:
            'Unbounded hardcoded font(s) found inside narrow/fixed '
            'containers lacking an Overflow_Safe_Widget mechanism '
            '(violates Requirement 3.5):\n'
            '${allOffenders.map((o) => '  - $o').join('\n')}',
      );
    });
  });
}

// ============================================================================
// Pure scanning logic (exported for the self-tests above)
// ============================================================================

/// Scans [content] (the source of [file]) and returns every unbounded
/// hardcoded-font offender per the documented heuristic.
List<_Offender> findUnboundedFontOffenders(String file, String content) {
  final stripped = _stripCommentsAndStrings(content);
  final offenders = <_Offender>[];
  final reportedLines = <int>{};

  // Find each fixed-width container constructor and analyse its subtree.
  final ctorPattern = RegExp(
    r'\b(' + kFixedWidthContainers.keys.join('|') + r')\s*\(',
  );

  for (final match in ctorPattern.allMatches(stripped)) {
    final ctorName = match.group(1)!;
    final openParen = match.end - 1; // index of '('
    final closeParen = _matchingParen(stripped, openParen);
    if (closeParen < 0) continue; // unbalanced; skip defensively

    final inner = stripped.substring(openParen + 1, closeParen);

    // 1) Does THIS container declare a fixed numeric width?
    final widthKey = kFixedWidthContainers[ctorName]!;
    if (!_declaresFixedWidth(inner, widthKey)) continue;

    // 2) Does its subtree contain a hardcoded numeric fontSize on a Text?
    if (!inner.contains('Text(')) continue;
    final fontMatch = RegExp(r'fontSize:\s*\d').firstMatch(inner);
    if (fontMatch == null) continue;

    // 3) Is the subtree missing every overflow-safe mechanism?
    final hasGuard = kOverflowSafeTokens.any((token) => inner.contains(token));
    if (hasGuard) continue;

    // Offender. Report the line of the first hardcoded fontSize, mapped back
    // to the ORIGINAL content for an accurate line number + readable snippet.
    final absoluteIndex = openParen + 1 + fontMatch.start;
    final line = _lineNumberAt(content, absoluteIndex);
    if (reportedLines.add(line)) {
      offenders.add(_Offender(file, line, _lineSnippet(content, line)));
    }
  }

  return offenders;
}

/// Returns true when [inner] (a constructor's argument content) declares a
/// fixed *numeric* width via [key] at this constructor's own argument depth
/// (depth 0 of [inner]), excluding `double.infinity`.
bool _declaresFixedWidth(String inner, String key) {
  final keyPattern = RegExp(r'\b' + key + r':\s*');
  var depth = 0;
  for (var i = 0; i < inner.length; i++) {
    final c = inner[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (depth == 0) {
      final m = keyPattern.matchAsPrefix(inner, i);
      if (m != null) {
        final rest = inner.substring(m.end);
        // Fixed only when the value begins with a digit and is NOT infinity.
        if (RegExp(r'^\d').hasMatch(rest)) return true;
        // `double.infinity` / variables => not a known-narrow fixed width.
      }
    }
  }
  return false;
}

/// Finds the index of the parenthesis matching the '(' at [openIndex].
/// Returns -1 if unbalanced. Operates on comment-/string-stripped text so
/// parentheses inside literals never affect the count.
int _matchingParen(String text, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < text.length; i++) {
    final c = text[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Replaces the body of string literals and comments with spaces (preserving
/// overall length and newlines) so structural scanning is not confused by
/// parentheses, braces, or keywords appearing inside literals/comments.
String _stripCommentsAndStrings(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';

    // Line comment.
    if (c == '/' && next == '/') {
      while (i < n && src[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    // Block comment.
    if (c == '/' && next == '*') {
      out.write('  ');
      i += 2;
      while (i < n && !(src[i] == '*' && i + 1 < n && src[i + 1] == '/')) {
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < n) {
        out.write('  ');
        i += 2;
      }
      continue;
    }
    // String literals (single or double quote, with escapes). Triple-quoted
    // strings are handled naturally by the single-char loop closing on the
    // first matching quote run; for our scanning purposes blanking their
    // contents is sufficient.
    if (c == '\'' || c == '"') {
      final quote = c;
      out.write(' ');
      i++;
      while (i < n) {
        if (src[i] == '\\') {
          out.write('  ');
          i += 2;
          continue;
        }
        if (src[i] == quote) {
          out.write(' ');
          i++;
          break;
        }
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }

    out.write(c);
    i++;
  }
  return out.toString();
}

/// 1-based line number of [index] within [content].
int _lineNumberAt(String content, int index) {
  var line = 1;
  for (var i = 0; i < index && i < content.length; i++) {
    if (content[i] == '\n') line++;
  }
  return line;
}

/// The trimmed text of [line] (1-based) in [content], for failure reporting.
String _lineSnippet(String content, int line) {
  final lines = content.split('\n');
  if (line < 1 || line > lines.length) return '';
  return lines[line - 1].trim();
}
