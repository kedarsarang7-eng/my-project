// ============================================================================
// Task 6.3 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 11: Audit classification is
// total and disjoint
// **Validates: Requirements 12.6**
// ============================================================================
// Property 11 (design.md): Over the enumerated scanned universe, every item
//   receives EXACTLY ONE classification — none is left unclassified and none is
//   classified into two buckets.
//
// Requirement 12.6: "THE Responsive_Audit SHALL classify every Business_Screen
//   under lib/features/, every shared layout component, and every
//   Responsive_Component as either compliant or non-compliant ... so that no
//   screen or shared component is left unclassified."
//
// HOW THIS TEST PROVES TOTAL + DISJOINT
//   * Total      — for every file in the scanned universe, `classifyPath`
//                  returns a NON-NULL `AuditCategory`, and `runAudit` emits
//                  exactly one `AuditItem` per scanned file (no file missing).
//   * Disjoint   — `classifyPath`'s return type is `AuditCategory?`, so a path
//                  can map to at most one bucket; we additionally assert the
//                  result equals an INDEPENDENTLY computed expected category for
//                  every generated path (membership rules hold) and that the
//                  emitted item paths are unique (no file classified twice).
//   * Exactly-one-or-out — for any path, the result is `null` XOR a single
//                  `AuditCategory`; in-universe paths are non-null, out-of-
//                  universe paths are null. There is no third state.
//
// Two complementary checks are used:
//   (a) A REAL run over the actual `lib/` directory via `runAudit`, asserting
//       the universe is non-empty, every item carries one of the three enum
//       categories, paths are unique, the compliant/non-compliant counts add
//       up, and each item's `compliant` flag equals `conditions.isEmpty`.
//   (b) A `dartproptest` `forAll` (kNumRuns = 200) over GENERATED path strings
//       asserting classification is deterministic and total/disjoint on a
//       synthetic universe spanning every bucket plus out-of-universe paths.
//
// Unit under test: the PURE functions `classifyPath`, `scanContent`,
//   `runAudit`, and `resolveLibDir` from `tool/responsive_audit.dart`. Because
//   `tool/` is not part of the package `lib/`, it is imported with a RELATIVE
//   import (the scanner depends only on `dart:io`/`dart:convert`, so it is
//   importable from a VM test).
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/tool/responsive_audit_totality_property_test.dart
//   (flutter test runs with CWD = package root, so `lib/` resolves).
// ============================================================================

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/responsive_audit.dart';

/// A single generated classification scenario: a constructed [path] paired with
/// the category it MUST classify into ([expected] is `null` when the path lies
/// outside the audit universe).
class _PathCase {
  const _PathCase(this.path, this.expected);
  final String path;
  final AuditCategory? expected;
}

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // Safe path segments: plain alphabetic tokens that NEVER contain any of the
  // substrings the classifier keys on ('responsive', 'shared', 'features',
  // 'widgets', 'core', '_screen', 'lib', '.', '/'). Using a constrained pool
  // keeps every generated path's expected category unambiguous.
  const List<String> kSafeWords = <String>[
    'foo',
    'bar',
    'baz',
    'alpha',
    'beta',
    'gamma',
    'util',
    'data',
    'model',
    'panel',
    'card',
    'grid',
  ];

  // Real feature module names, deliberately EXCLUDING 'shared' so a generated
  // business-screen path is never accidentally a shared component.
  const List<String> kModules = <String>[
    'billing',
    'clothing',
    'jewellery',
    'hardware',
    'clinic',
    'customers',
    'purchase',
    'auto_parts',
  ];

  // A fixed file body containing both a legacy import and a hand-rolled
  // MediaQuery breakpoint, so `scanContent` can fire conditions for in-universe
  // paths while staying empty for out-of-universe paths.
  const String kSampleContent = '''
import 'package:dukanx/core/theme/responsive_layout.dart';
Widget build(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w < 600) return const SizedBox();
  return const SizedBox();
}
''';

  // --- Generator -----------------------------------------------------------
  //
  // Produces a `_PathCase` spanning all seven path kinds: the three in-universe
  // buckets (via several shapes each), plus out-of-universe `.dart`, non-dart,
  // and generated (`.g.dart`/`.freezed.dart`) files. ~half of cases are emitted
  // with Windows backslashes to also exercise path normalization.
  final Generator<_PathCase> caseGen =
      Gen.tuple([
        Gen.interval(0, 6), // 0: path kind
        Gen.elementOf<String>(kSafeWords), // 1: segment a
        Gen.elementOf<String>(kSafeWords), // 2: segment b
        Gen.elementOf<String>(kModules), // 3: feature module
        Gen.interval(0, 1), // 4: shape variant
        Gen.interval(0, 1), // 5: 1 => use backslashes
      ]).map((parts) {
        final int kind = parts[0] as int;
        final String a = parts[1] as String;
        final String b = parts[2] as String;
        final String module = parts[3] as String;
        final int variant = parts[4] as int;
        final bool backslash = (parts[5] as int) == 1;

        String path;
        AuditCategory? expected;

        switch (kind) {
          case 0: // Responsive_System file — even a *_screen here is responsive
            final suffix = variant == 0 ? '$a.dart' : '${a}_screen.dart';
            path = 'lib/core/responsive/$b/$suffix';
            expected = AuditCategory.responsiveComponent;
            break;
          case 1: // shared via lib/features/shared/ (wins over screen check)
            final suffix = variant == 0 ? '$a.dart' : '${a}_screen.dart';
            path = 'lib/features/shared/$b/$suffix';
            expected = AuditCategory.sharedComponent;
            break;
          case 2: // Business_Screen: *_screen.dart under a real feature module
            path = 'lib/features/$module/presentation/screens/${a}_screen.dart';
            expected = AuditCategory.businessScreen;
            break;
          case 3: // app-wide shared widget under lib/widgets/
            final suffix = variant == 0 ? '$a.dart' : '${a}_screen.dart';
            path = 'lib/widgets/$b/$suffix';
            expected = AuditCategory.sharedComponent;
            break;
          case 4: // out-of-universe .dart (not a screen, not shared/responsive)
            path = variant == 0
                ? 'lib/core/$b/$a.dart'
                : 'lib/features/$module/data/$a.dart';
            expected = null;
            break;
          case 5: // non-dart asset — outside the universe
            final ext = variant == 0 ? 'png' : 'json';
            path = 'lib/features/$module/$a.$ext';
            expected = null;
            break;
          default: // case 6: generated source — outside the universe
            final suffix = variant == 0 ? '.g.dart' : '.freezed.dart';
            path = 'lib/features/$module/$a$suffix';
            expected = null;
            break;
        }

        if (backslash) path = path.replaceAll('/', r'\');
        return _PathCase(path, expected);
      });

  group(
    'Feature: cross-platform-responsive-ui, Property 11: Audit classification '
    'is total and disjoint',
    () {
      // -- (a) REAL run over the actual lib/ directory ----------------------
      test('Property 11 (real run): runAudit over lib/ classifies every scanned '
          'file into exactly one category, with unique paths and consistent '
          'compliant flags/counts', () {
        // flutter test runs with CWD = package root, so this resolves lib/.
        final Directory libDir = resolveLibDir();
        expect(
          libDir.existsSync(),
          isTrue,
          reason:
              'lib/ must resolve when run from the package root via '
              'flutter test.',
        );

        final items = runAudit(libDir);

        // The scanned universe is non-empty (there are many Business_Screens).
        expect(items, isNotEmpty);

        // Total + disjoint over the real universe:
        final paths = items.map((i) => i.path).toList();
        // No file classified twice — one item per path.
        expect(
          paths.toSet().length,
          paths.length,
          reason: 'every scanned file appears exactly once (disjoint)',
        );

        for (final item in items) {
          // Each item carries exactly one of the three enum categories.
          expect(AuditCategory.values.contains(item.category), isTrue);
          // Re-classifying the emitted path is non-null (total) and agrees
          // with the recorded category (disjoint / single bucket).
          expect(classifyPath(item.path), isNotNull);
          expect(classifyPath(item.path), item.category);
          // The compliant flag is exactly "no conditions flagged".
          expect(item.compliant, item.conditions.isEmpty);
        }

        // Compliant + non-compliant partitions the universe with no overlap
        // and no gap.
        final compliant = items.where((i) => i.compliant).length;
        final nonCompliant = items.where((i) => !i.compliant).length;
        expect(compliant + nonCompliant, items.length);
      });

      // -- (b) Property over the synthetic generated universe ---------------
      test('Property 11 (synthetic): classifyPath is deterministic and assigns '
          'exactly one category (or null when out-of-universe) for every '
          'generated path; membership rules hold', () {
        final held = forAll(
          (_PathCase c) {
            // Determinism: classifying the same path twice agrees.
            final r1 = classifyPath(c.path);
            final r2 = classifyPath(c.path);
            final bool deterministic = r1 == r2;

            // Total + disjoint: the result equals the INDEPENDENTLY computed
            // expected category (membership rules), and is null XOR a single
            // AuditCategory — never a third state.
            final bool matchesExpected = r1 == c.expected;
            final bool exactlyOneOrOut = c.expected == null
                ? r1 == null
                : (r1 != null && AuditCategory.values.contains(r1));

            // scanContent mirrors classifyPath's universe: out-of-universe
            // paths flag NO conditions, and scanning is deterministic (so
            // runAudit emits stable items).
            final sc1 = scanContent(c.path, kSampleContent);
            final sc2 = scanContent(c.path, kSampleContent);
            final bool scanDeterministic = listEquals(sc1, sc2);
            final bool outOfUniverseEmpty = c.expected == null
                ? sc1.isEmpty
                : true;

            return deterministic &&
                matchesExpected &&
                exactlyOneOrOut &&
                scanDeterministic &&
                outOfUniverseEmpty;
          },
          [caseGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // -- Deterministic membership examples (guaranteed edge coverage) -----
      // Pin the exact ordering-sensitive rules so the buckets stay disjoint
      // even independent of the generator's sampling.
      test('Property 11: ordering-sensitive membership rules classify into a '
          'single, correct bucket', () {
        // Business_Screen: *_screen.dart under a feature module.
        expect(
          classifyPath(
            'lib/features/billing/presentation/screens/foo_screen.dart',
          ),
          AuditCategory.businessScreen,
        );
        // shared wins over the generic screen check.
        expect(
          classifyPath('lib/features/shared/widgets/foo_screen.dart'),
          AuditCategory.sharedComponent,
        );
        // Responsive_System wins over everything else.
        expect(
          classifyPath('lib/core/responsive/adaptive_widgets.dart'),
          AuditCategory.responsiveComponent,
        );
        // App-wide widget.
        expect(
          classifyPath('lib/widgets/desktop/desktop_root_shell.dart'),
          AuditCategory.sharedComponent,
        );
        // Out-of-universe: legacy theme util, a repository, an asset, generated.
        expect(classifyPath('lib/core/theme/responsive_layout.dart'), isNull);
        expect(
          classifyPath('lib/features/billing/data/billing_repository.dart'),
          isNull,
        );
        expect(classifyPath('lib/features/billing/assets/logo.png'), isNull);
        expect(classifyPath('lib/features/billing/model.g.dart'), isNull);

        // Determinism on a representative path.
        const p =
            'lib/features/clinic/presentation/screens/patient_screen.dart';
        expect(classifyPath(p), classifyPath(p));

        // Out-of-universe paths flag no conditions regardless of content.
        expect(
          scanContent('lib/core/theme/responsive_layout.dart', kSampleContent),
          isEmpty,
        );
      });
    },
  );
}
