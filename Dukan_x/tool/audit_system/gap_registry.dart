// AUDIT_SYSTEM — GAP REGISTRY (Task 5.1)
//
// A Gap is a deviation from the production-readiness bar found during the Audit
// phase of an Iteration. Every Gap is bound to exactly one Screen, exactly one
// Business_Type, and at least one of the 13 Audit_Categories (Req 3.3). The
// GapRegistry is the single admission boundary that enforces that contract:
// well-formed Gaps are admitted; malformed Gaps are rejected with NO partial
// record retained and a precise report of the missing association (Req 3.4).
//
// This file is PURE, dependency-light Dart (only `dart:core` + the
// AuditCategory enum), so it imports cleanly into `flutter_test` +
// `dartproptest` VM suites, mirroring the rest of the Audit_System core.
//
// NOTE ON SCOPE: This file intentionally hosts ONLY the Gap model + admission
// boundary. The Placeholder Scanner (Task 5.3) and the Secret/Config scanners
// (Task 5.5) are appended to this same file later — see the design section
// "5. Gap Registry + Placeholder Scanner". The structure here (top-level types,
// no shared mutable singletons) leaves room for those scanners to be added
// without touching the admission logic.
//
// Part of: per-screen-business-type-audit-remediation (Task 5.1)
// _Requirements: 3.3, 3.4_

import 'audit_categories.dart' show AuditCategory;

/// Lifecycle status of a Gap across an Iteration.
///
/// * [open]       — recorded during Audit, not yet resolved.
/// * [resolved]   — a fix was applied and verified (Req 4-series).
/// * [unresolved] — still failing after the Fix-Verify cycles (Req 2.7).
enum GapStatus { open, resolved, unresolved }

/// A deviation from the production-readiness bar found during audit.
///
/// Invariants enforced by [GapRegistry.admit] (Req 3.3):
///   * exactly one Screen identifier ([screenPath], non-empty)
///   * exactly one Business_Type identifier ([businessType], non-empty)
///   * at least one [AuditCategory] in [categories]
///
/// The constructor itself does NOT validate — admission is the single guard so
/// callers cannot accidentally bypass it by constructing directly. Construct
/// freely, then submit to [GapRegistry.admit].
class Gap {
  Gap({
    required this.id,
    required this.screenPath,
    required this.businessType,
    required List<AuditCategory> categories,
    required this.status,
    required this.description,
    this.fileLocation,
  }) : categories = List<AuditCategory>.unmodifiable(categories);

  /// Stable identifier for this Gap within an Iteration_Report.
  final String id;

  /// Forward-slash, package-relative `.dart` path of the single Screen the Gap
  /// is bound to. Exactly one (Req 3.3).
  final String screenPath;

  /// Module folder name under `lib/modules/` (never `_template`). Exactly one
  /// (Req 3.3).
  final String businessType;

  /// The Audit_Categories this Gap is classified under. At least one (Req 3.3).
  /// Stored as an unmodifiable list.
  final List<AuditCategory> categories;

  /// Lifecycle status: open | resolved | unresolved.
  final GapStatus status;

  /// Human-readable description of the deviation.
  final String description;

  /// Optional `file:line` location for placeholder/secret findings (Req 4.1).
  final String? fileLocation;

  @override
  String toString() =>
      'Gap($id, $businessType, $screenPath, $categories, $status)';
}

/// The three association fields a Gap MUST carry. Used to report precisely
/// which association(s) were missing when a Gap is rejected (Req 3.4).
enum GapAssociation { screen, businessType, category }

/// The outcome of submitting a [Gap] to [GapRegistry.admit].
///
/// On success [admitted] is true and [gap] is the admitted record. On rejection
/// [admitted] is false, [gap] is null (NO partial record retained — Req 3.4),
/// and [missing] lists exactly which associations were absent, with [error]
/// providing a human-readable indication.
class GapAdmission {
  const GapAdmission._({
    required this.admitted,
    this.gap,
    this.missing = const <GapAssociation>[],
    this.error,
  });

  /// Build an acceptance result wrapping the admitted [gap].
  factory GapAdmission.accepted(Gap gap) =>
      GapAdmission._(admitted: true, gap: gap);

  /// Build a rejection result reporting the [missing] associations.
  factory GapAdmission.rejected(List<GapAssociation> missing) {
    final sorted = [...missing]..sort((a, b) => a.index.compareTo(b.index));
    final names = sorted.map(_associationLabel).join(', ');
    return GapAdmission._(
      admitted: false,
      gap: null,
      missing: List<GapAssociation>.unmodifiable(sorted),
      error: 'Gap rejected: missing required association(s): $names',
    );
  }

  /// True iff the Gap satisfied all association invariants and was stored.
  final bool admitted;

  /// The admitted Gap, or null when [admitted] is false.
  final Gap? gap;

  /// The associations that were missing on rejection; empty on acceptance.
  final List<GapAssociation> missing;

  /// Human-readable error indication on rejection; null on acceptance.
  final String? error;

  /// Convenience inverse of [admitted].
  bool get rejected => !admitted;

  static String _associationLabel(GapAssociation a) {
    switch (a) {
      case GapAssociation.screen:
        return 'Screen identifier';
      case GapAssociation.businessType:
        return 'Business_Type identifier';
      case GapAssociation.category:
        return 'Audit_Category';
    }
  }

  @override
  String toString() => admitted
      ? 'GapAdmission.accepted(${gap?.id})'
      : 'GapAdmission.rejected($missing)';
}

/// The admission boundary for Gaps.
///
/// [admit] is the ONLY way a Gap enters the registry. It enforces the Req 3.3
/// association contract and, on failure, retains no partial record while
/// reporting the missing association(s) (Req 3.4).
class GapRegistry {
  final List<Gap> _gaps = <Gap>[];

  /// Accept [gap] iff it has a non-empty Screen identifier, a non-empty
  /// Business_Type identifier, and at least one Audit_Category. Otherwise
  /// reject it, store NOTHING, and report which association(s) were missing.
  /// (Req 3.3, 3.4)
  GapAdmission admit(Gap gap) {
    final missing = <GapAssociation>[];
    if (gap.screenPath.trim().isEmpty) {
      missing.add(GapAssociation.screen);
    }
    if (gap.businessType.trim().isEmpty) {
      missing.add(GapAssociation.businessType);
    }
    if (gap.categories.isEmpty) {
      missing.add(GapAssociation.category);
    }

    if (missing.isNotEmpty) {
      // Reject: retain NO partial record (Req 3.4). _gaps is left untouched.
      return GapAdmission.rejected(missing);
    }

    _gaps.add(gap);
    return GapAdmission.accepted(gap);
  }

  /// All admitted Gaps, in admission order. Unmodifiable view.
  List<Gap> get gaps => List<Gap>.unmodifiable(_gaps);

  /// Number of admitted Gaps.
  int get count => _gaps.length;

  /// True iff no Gaps have been admitted.
  bool get isEmpty => _gaps.isEmpty;
}

// =============================================================================
// PLACEHOLDER SCANNER (Task 5.3)
//
// A PURE, regex-based scanner that flags placeholder / mock / stub / TODO logic
// in a single source file's content, mirroring `scanContent` in
// `tool/responsive_audit.dart` (simple line scanning, no full Dart parser, per
// the AGENTS.md "simple and clear" guidance).
//
// It reports EVERY occurrence (not a de-duplicated set), each carrying the
// file path and 1-based line number, so the Audit phase can record an exact
// `file:line` location for each finding (Req 4.1) and the post-fix re-scan can
// confirm zero remaining occurrences (Req 4.3).
//
// Patterns detected (Req 4.1):
//   * hardcoded sample/dummy/mock/fake-named data arrays
//   * "Coming soon" / not-yet-implemented screens (incl. UnimplementedError)
//   * TODO / FIXME markers
//   * mock / dummy / fake / sample imports (or exports)
//   * `LegacyRouteRedirect` stand-ins
//
// _Requirements: 4.1, 4.3_
// =============================================================================

/// The kind of placeholder/mock/stub/TODO occurrence a [PlaceholderFinding]
/// represents. Mirrors the five pattern families in Req 4.1.
enum PlaceholderKind {
  /// A hardcoded sample/dummy/mock/fake-named list/array literal.
  hardcodedSampleArray('hardcoded_sample_array'),

  /// A "Coming soon" / not-yet-implemented screen marker.
  comingSoon('coming_soon'),

  /// A `TODO` or `FIXME` marker.
  todoFixme('todo_fixme'),

  /// An import/export of a mock/dummy/fake/sample source.
  mockImport('mock_import'),

  /// A `LegacyRouteRedirect` stand-in reference.
  legacyRouteRedirect('legacy_route_redirect');

  const PlaceholderKind(this.json);

  /// Stable snake_case name for reports.
  final String json;
}

/// A single placeholder/mock/stub/TODO occurrence found by [PlaceholderScanner].
///
/// Carries the [filePath] and 1-based [line] so the Audit phase can record the
/// exact `file:line` of the deviation (Req 4.1). [matchedText] is the trimmed
/// source snippet that triggered the finding, for human-readable reporting.
class PlaceholderFinding {
  const PlaceholderFinding({
    required this.filePath,
    required this.line,
    required this.kind,
    required this.matchedText,
  });

  /// Forward-slash, package-relative path of the scanned file.
  final String filePath;

  /// 1-based line number of the occurrence within the file.
  final int line;

  /// Which pattern family this occurrence belongs to.
  final PlaceholderKind kind;

  /// The trimmed source text that matched the pattern.
  final String matchedText;

  /// `file:line` location string, e.g. `lib/.../foo_screen.dart:42`.
  String get fileLocation => '$filePath:$line';

  @override
  String toString() =>
      'PlaceholderFinding(${kind.json}, $fileLocation, "$matchedText")';
}

/// Detects placeholder/mock/stub/TODO logic in source content (Req 4.1). PURE
/// and regex-based, mirroring `scanContent` in `tool/responsive_audit.dart`.
///
/// [scan] depends only on its arguments — no I/O, no shared mutable state — so
/// it imports cleanly into `flutter_test` + `dartproptest` VM suites.
class PlaceholderScanner {
  const PlaceholderScanner();

  /// A sample/dummy/mock/fake-named identifier assigned a list/array literal,
  /// e.g. `final sampleProducts = [`, `dummyData = const [`,
  /// `mockItems = <Product>[`. Case-insensitive on the identifier.
  static final RegExp _sampleArrayRe = RegExp(
    r'\b\w*(?:sample|dummy|mock|fake)\w*\s*=\s*(?:const\s+)?(?:<[^>]*>\s*)?\[',
    caseSensitive: false,
  );

  /// "Coming soon" / not-(yet-)implemented markers, including the standard
  /// `UnimplementedError`. Case-insensitive except the exact error type.
  static final RegExp _comingSoonRe = RegExp(
    r'coming\s+soon'
    r'|not[\s-]*yet[\s-]*implemented'
    r'|not[\s-]*implemented'
    r'|UnimplementedError',
    caseSensitive: false,
  );

  /// `TODO` / `FIXME` markers (word-boundary, case-insensitive).
  static final RegExp _todoFixmeRe = RegExp(
    r'\b(?:TODO|FIXME)\b',
    caseSensitive: false,
  );

  /// An import/export directive whose path contains mock/dummy/fake/sample.
  static final RegExp _mockImportRe = RegExp(
    r'''^\s*(?:import|export)\s+['"][^'"]*(?:mock|dummy|fake|sample)[^'"]*['"]''',
    caseSensitive: false,
  );

  /// A `LegacyRouteRedirect` stand-in reference (word-boundary).
  static final RegExp _legacyRedirectRe = RegExp(r'\bLegacyRouteRedirect\b');

  /// Ordered (kind, pattern) pairs applied to each line. Order fixes the
  /// per-line emission order when multiple kinds match the same line.
  static final List<MapEntry<PlaceholderKind, RegExp>> _patterns =
      <MapEntry<PlaceholderKind, RegExp>>[
        MapEntry(PlaceholderKind.mockImport, _mockImportRe),
        MapEntry(PlaceholderKind.hardcodedSampleArray, _sampleArrayRe),
        MapEntry(PlaceholderKind.comingSoon, _comingSoonRe),
        MapEntry(PlaceholderKind.todoFixme, _todoFixmeRe),
        MapEntry(PlaceholderKind.legacyRouteRedirect, _legacyRedirectRe),
      ];

  /// Scan [content] and return a [PlaceholderFinding] for EVERY occurrence of a
  /// placeholder/mock/stub/TODO pattern, each with [filePath] and a 1-based
  /// line number (Req 4.1). Findings are emitted in ascending line order; when
  /// a line matches several kinds they are emitted in the [_patterns] order,
  /// and each individual match on a line yields its own finding.
  ///
  /// Returns an empty list for content containing none of the patterns
  /// (Property 9 / Req 4.3 zero-remaining re-scan).
  ///
  /// PURE: depends only on [filePath] and [content].
  List<PlaceholderFinding> scan(String filePath, String content) {
    final findings = <PlaceholderFinding>[];
    if (content.isEmpty) return findings;

    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNo = i + 1; // 1-based
      for (final entry in _patterns) {
        for (final match in entry.value.allMatches(line)) {
          findings.add(
            PlaceholderFinding(
              filePath: filePath,
              line: lineNo,
              kind: entry.key,
              matchedText: match.group(0)!.trim(),
            ),
          );
        }
      }
    }
    return findings;
  }

  // ---------------------------------------------------------------------------
  // SECRET SCANNER (Task 5.5) — Req 4.4, 12.6
  //
  // Flags LITERAL endpoint URLs, credentials, and secrets baked into source.
  // Values sourced from environment-provided configuration (e.g.
  // `String.fromEnvironment`, `Platform.environment`, `dotenv.env[...]`) are
  // references — NOT literals — so they never match these patterns and are not
  // flagged (Property 10). This realises design principle 6: endpoints/secrets
  // come from environment config, never hardcoded.
  // ---------------------------------------------------------------------------

  /// A literal endpoint URL with an `http(s)`/`ws(s)` scheme appearing anywhere
  /// in the source. Bare scheme detection (no surrounding quotes required) so a
  /// URL embedded in a comment, a string literal, or a default value is all
  /// caught (Req 4.4 "zero literal endpoint URLs ... in the source files").
  /// Package/dart import URIs (`package:`, `dart:`) have no `//` authority and
  /// so never match.
  static final RegExp _endpointUrlRe = RegExp(
    r'''(?:https?|wss?)://[^\s'"<>)\]]+''',
    caseSensitive: false,
  );

  /// A credential-like identifier assigned a NON-EMPTY string literal, e.g.
  /// `password: 'hunter2'`, `apiKey = "abc"`, `client_secret: '...'`. The value
  /// must be a quoted literal; references like `apiKey: dotenv.env['X']` do not
  /// match because no quote immediately follows the `:`/`=`. An empty literal
  /// (`''`) is not a secret and is not flagged.
  static final RegExp _credentialRe = RegExp(
    r'''(?:password|passwd|pwd|secret|api[_-]?key|apikey|access[_-]?key'''
    r'''|access[_-]?token|auth[_-]?token|client[_-]?secret|bearer)'''
    r'''\s*[:=]\s*['"][^'"]+['"]''',
    caseSensitive: false,
  );

  /// High-confidence literal secret material: AWS access-key IDs and PEM private
  /// key headers. Kept narrow on purpose to avoid false positives on ordinary
  /// high-entropy strings.
  static final RegExp _secretMaterialRe = RegExp(
    r'AKIA[0-9A-Z]{16}'
    r'|-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----',
  );

  /// Ordered (kind, pattern) pairs applied to each line, mirroring [scan].
  static final List<MapEntry<SecretKind, RegExp>> _secretPatterns =
      <MapEntry<SecretKind, RegExp>>[
        MapEntry(SecretKind.endpointUrl, _endpointUrlRe),
        MapEntry(SecretKind.credential, _credentialRe),
        MapEntry(SecretKind.secret, _secretMaterialRe),
      ];

  /// Scan [content] and return a [SecretFinding] for EVERY literal endpoint
  /// URL, credential, or secret occurrence, each with [filePath] and a 1-based
  /// line number (Req 4.4, 12.6). Returns an empty list when the content holds
  /// no literals — including content that sources all such values from
  /// environment-provided configuration (Property 10).
  ///
  /// PURE: depends only on [filePath] and [content].
  List<SecretFinding> scanSecrets(String filePath, String content) {
    final findings = <SecretFinding>[];
    if (content.isEmpty) return findings;

    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNo = i + 1; // 1-based
      for (final entry in _secretPatterns) {
        for (final match in entry.value.allMatches(line)) {
          findings.add(
            SecretFinding(
              filePath: filePath,
              line: lineNo,
              kind: entry.key,
              matchedText: match.group(0)!.trim(),
            ),
          );
        }
      }
    }
    return findings;
  }
}

// =============================================================================
// SECRET FINDINGS (Task 5.5)
//
// The value object emitted by [PlaceholderScanner.scanSecrets]. Mirrors
// [PlaceholderFinding]: carries a `file:line` location so the Audit phase can
// flag the exact site of a literal endpoint/credential/secret (Req 4.4, 12.6).
// =============================================================================

/// The kind of literal secret material a [SecretFinding] represents. Mirrors
/// the three families called out in Req 4.4: endpoints, credentials, secrets.
enum SecretKind {
  /// A literal endpoint URL (`http(s)`/`ws(s)` scheme) baked into source.
  endpointUrl('endpoint_url'),

  /// A credential-like identifier assigned a non-empty string literal.
  credential('credential'),

  /// Literal secret material (AWS access-key ID, PEM private key header).
  secret('secret');

  const SecretKind(this.json);

  /// Stable snake_case name for reports.
  final String json;
}

/// A single literal endpoint/credential/secret occurrence found by
/// [PlaceholderScanner.scanSecrets].
///
/// Carries the [filePath] and 1-based [line] so the Audit phase can record the
/// exact `file:line` of the deviation (Req 4.4). [matchedText] is the trimmed
/// source snippet that triggered the finding, for human-readable reporting.
class SecretFinding {
  const SecretFinding({
    required this.filePath,
    required this.line,
    required this.kind,
    required this.matchedText,
  });

  /// Forward-slash, package-relative path of the scanned file.
  final String filePath;

  /// 1-based line number of the occurrence within the file.
  final int line;

  /// Which secret family this occurrence belongs to.
  final SecretKind kind;

  /// The trimmed source text that matched the pattern.
  final String matchedText;

  /// `file:line` location string, e.g. `lib/.../foo_screen.dart:42`.
  String get fileLocation => '$filePath:$line';

  @override
  String toString() =>
      'SecretFinding(${kind.json}, $fileLocation, "$matchedText")';
}

// =============================================================================
// CONFIG-REFERENCE CHECKER (Task 5.5)
//
// Enforces design principle 6 / Req 4.5: a referenced configuration value that
// is absent or empty becomes a recorded missing-key Gap; the system NEVER
// substitutes a hardcoded fallback. This is the model behind Property 11.
//
// PURE: every method depends only on its arguments — no I/O, no shared mutable
// state — so it imports cleanly into `flutter_test` + `dartproptest` suites.
// =============================================================================

/// Resolves and validates referenced configuration keys against a config map,
/// producing a missing-key [Gap] for any key that is absent or empty WITHOUT
/// ever substituting a fallback value (Req 4.5).
class ConfigReferenceChecker {
  const ConfigReferenceChecker();

  /// True iff [value] is a present, non-empty configuration value. A null,
  /// empty, or whitespace-only value counts as missing (Req 4.5).
  static bool isPresent(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// Returns the configured value for [key], or `null` when the key is absent
  /// or its value is empty/whitespace. NEVER substitutes a hardcoded fallback
  /// (Req 4.5): callers that need a value must handle `null` explicitly.
  static String? resolve(Map<String, String?> config, String key) {
    final value = config[key];
    return isPresent(value) ? value : null;
  }

  /// The referenced keys that are absent or empty in [config], in the order
  /// they appear in [referencedKeys] (duplicates collapsed, first occurrence
  /// wins). These are exactly the keys that yield a missing-key Gap.
  List<String> missingKeys(
    Map<String, String?> config,
    Iterable<String> referencedKeys,
  ) {
    final seen = <String>{};
    final missing = <String>[];
    for (final key in referencedKeys) {
      if (!seen.add(key)) continue; // collapse duplicate references
      if (!isPresent(config[key])) {
        missing.add(key);
      }
    }
    return missing;
  }

  /// Produce a missing-key [Gap] for every referenced key that is absent or
  /// empty in [config] (Req 4.5 / Property 11).
  ///
  /// Each Gap is bound to the single [screenPath] and [businessType] and is
  /// classified under [AuditCategory.backendIntegration] (endpoints/secrets are
  /// a backend-integration concern; override via [category] if needed). Every
  /// Gap is [GapStatus.open] and names the missing configuration key in its
  /// description; NO fallback value is ever produced. Returns an empty list
  /// when all referenced keys are present and non-empty.
  ///
  /// PURE: depends only on its arguments.
  List<Gap> missingKeyGaps({
    required Map<String, String?> config,
    required Iterable<String> referencedKeys,
    required String screenPath,
    required String businessType,
    AuditCategory category = AuditCategory.backendIntegration,
  }) {
    final gaps = <Gap>[];
    for (final key in missingKeys(config, referencedKeys)) {
      gaps.add(
        Gap(
          id: 'missing-config:$businessType:$screenPath:$key',
          screenPath: screenPath,
          businessType: businessType,
          categories: <AuditCategory>[category],
          status: GapStatus.open,
          description:
              'Missing required configuration key "$key": value is absent or '
              'empty. Source it from environment-provided configuration; do '
              'NOT substitute a hardcoded fallback (Req 4.5).',
        ),
      );
    }
    return gaps;
  }
}
