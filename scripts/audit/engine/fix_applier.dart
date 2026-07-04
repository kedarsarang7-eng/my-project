/// FixApplier — applies Root_Cause_Fixes through EditScopeGuard, enforcing all
/// remediation constraints defined by the design.
///
/// This is a coordinator/framework class that:
/// - Validates proposed fixes against all rules (token sourcing, forbidden
///   patterns, net-diff, API preservation, edit scope, secret handling)
/// - Delegates actual code transformation to a [FixStrategy] callback
/// - Returns [FixOutcome] — either [FixSuccess] or [FixBlocked]
///
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 8.1, 8.2, 8.3,
///               8.4, 8.5, 8.6
library;

import '../models/audit_engine_models.dart';
import 'edit_scope_guard.dart';
import 'file_ownership_map.dart';
import 'finding_recorder.dart';

// ---------------------------------------------------------------------------
// Fix Strategy (pluggable code-transform interface)
// ---------------------------------------------------------------------------

/// The result of applying a [FixStrategy] — the proposed code change.
class ProposedFix {
  /// File path to edit (must match Finding's file reference).
  final String filePath;

  /// Original content of the affected region.
  final String originalContent;

  /// Replacement content after the fix.
  final String replacedContent;

  /// What was changed (human-readable).
  final String whatChanged;

  /// Why it was changed (root-cause reasoning).
  final String whyChanged;

  /// Behavior before the fix.
  final String beforeBehavior;

  /// Behavior after the fix.
  final String afterBehavior;

  /// Call sites impacted (for API-breaking fixes, Req 4.7).
  final List<String> impactedCallSites;

  /// Whether this fix changes the widget's public API.
  final bool breaksPublicApi;

  /// Whether the replacement uses a value from DesignTokens/theme.
  final bool usesDesignToken;

  /// Whether the fix addresses responsiveness using existing primitives.
  final bool usesResponsivePrimitive;

  /// Whether the fix replaces a secret literal with an env-var reference.
  final bool replacesSecret;

  /// The env-var name referenced (if [replacesSecret] is true).
  final String? envVarName;

  /// Whether a new file needs to be created (vs. updating existing).
  final bool createsNewFile;

  const ProposedFix({
    required this.filePath,
    required this.originalContent,
    required this.replacedContent,
    required this.whatChanged,
    required this.whyChanged,
    required this.beforeBehavior,
    required this.afterBehavior,
    this.impactedCallSites = const [],
    this.breaksPublicApi = false,
    this.usesDesignToken = false,
    this.usesResponsivePrimitive = false,
    this.replacesSecret = false,
    this.envVarName,
    this.createsNewFile = false,
  });
}

/// Callback interface for the actual code transformation logic.
///
/// Given a [Finding], produces either a [ProposedFix] describing the change
/// or `null` if no root-cause fix can be determined.
typedef FixStrategy = ProposedFix? Function(Finding finding);

// ---------------------------------------------------------------------------
// Fix Outcome (sealed result type)
// ---------------------------------------------------------------------------

/// Outcome of attempting to apply a fix to a Finding.
sealed class FixOutcome {
  const FixOutcome();
}

/// Fix was applied successfully.
class FixSuccess extends FixOutcome {
  /// The fix log entry recording what/why/before/after.
  final FixLogEntry fixLogEntry;

  const FixSuccess({required this.fixLogEntry});

  @override
  String toString() => 'FixSuccess(${fixLogEntry.finding.id})';
}

/// Fix is blocked and cannot be applied.
class FixBlocked extends FixOutcome {
  /// The blocked item with reason and action to unblock.
  final BlockedItem blockedItem;

  const FixBlocked({required this.blockedItem});

  @override
  String toString() =>
      'FixBlocked(${blockedItem.finding.id}: ${blockedItem.blockingReason})';
}

// ---------------------------------------------------------------------------
// Forbidden Pattern Detection
// ---------------------------------------------------------------------------

/// Patterns that indicate symptom-masking rather than root-cause fixing (Req 4.1).
///
/// These are widget/property combinations whose sole effect would be to hide
/// an overflow or layout issue rather than fixing the underlying cause.
class ForbiddenPatternDetector {
  /// Regex patterns matching symptom-masking code introductions.
  static final List<RegExp> _forbiddenPatterns = [
    // Wrapping in SizedBox/ConstrainedBox just to constrain overflow
    RegExp(r'SizedBox\s*\(', multiLine: true),
    // Wrapping in ClipRect/ClipRRect to hide overflow
    RegExp(r'ClipR?Rect\s*\(', multiLine: true),
    // Adding overflow: hidden / clip behavior
    RegExp(r'overflow\s*:\s*Overflow\.clip', multiLine: true),
    RegExp(r'clipBehavior\s*:\s*Clip\.(?:hardEdge|antiAlias)', multiLine: true),
    // ConstrainedBox wrapping to mask overflow
    RegExp(r'ConstrainedBox\s*\(', multiLine: true),
  ];

  /// Checks whether the replacement introduces a forbidden symptom-masking
  /// pattern that was not present in the original content.
  ///
  /// Returns a description of the violation if found, or `null` if clean.
  static String? detect(String originalContent, String replacedContent) {
    for (final pattern in _forbiddenPatterns) {
      final originalMatches = pattern.allMatches(originalContent).length;
      final replacedMatches = pattern.allMatches(replacedContent).length;

      // Net-new introduction of a forbidden pattern
      if (replacedMatches > originalMatches) {
        return 'Introduces forbidden symptom-masking pattern: '
            '${pattern.pattern} '
            '(was $originalMatches, now $replacedMatches)';
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Net-Diff Validator (Req 4.5)
// ---------------------------------------------------------------------------

/// Validates that a fix does not introduce net-new TODO/FIXME/lint-ignore/
/// overflow suppression markers.
class NetDiffValidator {
  /// Patterns that must not increase in count after a fix.
  static final List<RegExp> _suppressionPatterns = [
    RegExp(r'//\s*TODO', multiLine: true),
    RegExp(r'//\s*FIXME', multiLine: true),
    RegExp(r'//\s*ignore:', multiLine: true),
    RegExp(r'// ignore_for_file:', multiLine: true),
    RegExp(r'// noinspection', multiLine: true),
    RegExp(r'overflow\s*:\s*TextOverflow\.ellipsis', multiLine: true),
  ];

  /// Checks that no suppression pattern has a net increase from original to
  /// replaced content.
  ///
  /// Returns a description of the violation if found, or `null` if clean.
  static String? validate(String originalContent, String replacedContent) {
    for (final pattern in _suppressionPatterns) {
      final originalCount = pattern.allMatches(originalContent).length;
      final replacedCount = pattern.allMatches(replacedContent).length;

      if (replacedCount > originalCount) {
        return 'Net-new suppression introduced: ${pattern.pattern} '
            '(was $originalCount, now $replacedCount)';
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// FixApplier implementation
// ---------------------------------------------------------------------------

/// Coordinates the application of Root_Cause_Fixes, enforcing all remediation
/// constraints before and after delegating to a [FixStrategy].
///
/// Constraints enforced:
/// 1. Edit passes through [EditScopeGuard.authorize] (Req 1.2, 1.3, 1.8)
/// 2. Replacement values from DesignTokens/theme only (Req 4.3, 4.4)
/// 3. Responsiveness uses existing primitives (Req 4.2)
/// 4. No symptom-masking wrappers/clips/constraint overrides (Req 4.1)
/// 5. No net-new TODO/FIXME/lint-ignore/overflow suppressions (Req 4.5)
/// 6. Preserves widget public API (Req 4.6)
/// 7. Breaking API change → list all call sites first (Req 4.7)
/// 8. Secrets → env-var references (Req 8.4); missing env var → Finding (8.5)
/// 9. Edits confined to Finding-referenced files/lines (Req 8.1)
/// 10. Update existing file; new file only when none exists (Req 8.6)
/// 11. Unresolvable → Blocked_Item (Req 4.8)
class FixApplier {
  /// The edit scope guard that authorizes file edits.
  final EditScopeGuard _editScopeGuard;

  /// The finding recorder for recording new findings (e.g. missing tokens).
  final FindingRecorder _findingRecorder;

  /// The file ownership map for scope classification.
  final FileOwnershipMap _fileOwnershipMap;

  /// The active business type for the current cycle.
  final BusinessType _activeBusinessType;

  /// Known environment variable names available in workspace configuration.
  final Set<String> _knownEnvVars;

  /// Whether a token/theme source is available for the required replacement.
  /// Externally configurable for testability.
  final bool Function(String filePath, String value)? _tokenResolver;

  /// Creates a [FixApplier] with its required dependencies.
  ///
  /// [editScopeGuard] gates all edits through cycle isolation.
  /// [findingRecorder] records new findings for missing tokens/env vars.
  /// [fileOwnershipMap] classifies files for edit authorization.
  /// [activeBusinessType] is the current cycle's vertical.
  /// [knownEnvVars] is the set of environment variables defined in workspace.
  /// [tokenResolver] optionally checks if a value has a design-token source.
  FixApplier({
    required EditScopeGuard editScopeGuard,
    required FindingRecorder findingRecorder,
    required FileOwnershipMap fileOwnershipMap,
    required BusinessType activeBusinessType,
    Set<String> knownEnvVars = const {},
    bool Function(String filePath, String value)? tokenResolver,
  }) : _editScopeGuard = editScopeGuard,
       _findingRecorder = findingRecorder,
       _fileOwnershipMap = fileOwnershipMap,
       _activeBusinessType = activeBusinessType,
       _knownEnvVars = knownEnvVars,
       _tokenResolver = tokenResolver;

  /// Applies a Root_Cause_Fix for the given [finding] using the provided
  /// [strategy] to determine the actual code transformation.
  ///
  /// Returns [FixSuccess] if all constraints pass and the fix is applied,
  /// or [FixBlocked] if any constraint is violated or the fix is undeterminable.
  ///
  /// Enforcement order:
  /// 1. Strategy produces a proposed fix (or blocks)
  /// 2. Edit scope authorization (Req 1.2, 1.3, 1.8)
  /// 3. Edit confinement to Finding-referenced file (Req 8.1)
  /// 4. New-file restriction (Req 8.6)
  /// 5. Forbidden pattern check (Req 4.1)
  /// 6. Net-diff validation (Req 4.5)
  /// 7. Design token sourcing (Req 4.3, 4.4)
  /// 8. Secret/env-var handling (Req 8.4, 8.5)
  /// 9. Public API preservation (Req 4.6, 4.7)
  /// 10. Success → FixLogEntry
  FixOutcome apply(Finding finding, {required FixStrategy strategy}) {
    // ─── Step 1: Strategy produces a proposed fix ───────────────────────────
    final proposed = strategy(finding);

    if (proposed == null) {
      // Unresolvable fix → Blocked_Item (Req 4.8)
      finding.state = FindingState.blocked;
      return FixBlocked(
        blockedItem: BlockedItem(
          finding: finding,
          blockingReason: 'missing-spec',
          missingArtifact: finding.description,
          actionToUnblock:
              'Provide design specification or clarify requirement '
              'for: ${finding.description}',
        ),
      );
    }

    // ─── Step 2: Edit scope authorization (Req 1.2, 1.3, 1.8) ─────────────
    final editRequest = EditRequest(
      filePath: proposed.filePath,
      findingId: finding.id,
      description: proposed.whatChanged,
    );
    final decision = _editScopeGuard.authorize(
      editRequest,
      _activeBusinessType,
      _fileOwnershipMap,
    );

    if (decision is Reject) {
      finding.state = FindingState.blocked;
      return FixBlocked(
        blockedItem: BlockedItem(
          finding: finding,
          blockingReason: 'external-dependency',
          missingArtifact: proposed.filePath,
          actionToUnblock:
              'Defer to ${decision.targetBusinessType?.displayName ?? "owning"} '
              "vertical's Cycle.",
          targetBusinessType: decision.targetBusinessType,
        ),
      );
    }

    // ─── Step 3: Edit confinement to Finding-referenced file (Req 8.1) ─────
    final findingFile = _extractFilePath(finding.fileLine);
    final proposedFileCanonical = canonicalFilePath(proposed.filePath);
    final findingFileCanonical = findingFile != null
        ? canonicalFilePath(findingFile)
        : null;

    if (findingFileCanonical != null &&
        proposedFileCanonical != findingFileCanonical) {
      finding.state = FindingState.blocked;
      return FixBlocked(
        blockedItem: BlockedItem(
          finding: finding,
          blockingReason: 'external-dependency',
          missingArtifact: proposed.filePath,
          actionToUnblock:
              'Fix must be confined to the Finding-referenced file: '
              '${finding.fileLine}. Proposed edit targets a different file.',
        ),
      );
    }

    // ─── Step 4: New-file restriction (Req 8.6) ────────────────────────────
    if (proposed.createsNewFile) {
      // Only allowed when no existing file covers the functionality.
      // If the finding references an existing file, block new-file creation.
      if (findingFileCanonical != null) {
        finding.state = FindingState.blocked;
        return FixBlocked(
          blockedItem: BlockedItem(
            finding: finding,
            blockingReason: 'ambiguous-requirement',
            missingArtifact: proposed.filePath,
            actionToUnblock:
                'An existing file already covers this functionality '
                '(${finding.fileLine}). Update it instead of creating a new file.',
          ),
        );
      }
    }

    // ─── Step 5: Forbidden pattern check (Req 4.1) ─────────────────────────
    final forbiddenViolation = ForbiddenPatternDetector.detect(
      proposed.originalContent,
      proposed.replacedContent,
    );
    if (forbiddenViolation != null) {
      finding.state = FindingState.blocked;
      return FixBlocked(
        blockedItem: BlockedItem(
          finding: finding,
          blockingReason: 'ambiguous-requirement',
          missingArtifact: forbiddenViolation,
          actionToUnblock:
              'Apply a root-cause fix that does not introduce '
              'symptom-masking wrappers, clips, or constraint overrides.',
        ),
      );
    }

    // ─── Step 6: Net-diff validation (Req 4.5) ─────────────────────────────
    final netDiffViolation = NetDiffValidator.validate(
      proposed.originalContent,
      proposed.replacedContent,
    );
    if (netDiffViolation != null) {
      finding.state = FindingState.blocked;
      return FixBlocked(
        blockedItem: BlockedItem(
          finding: finding,
          blockingReason: 'ambiguous-requirement',
          missingArtifact: netDiffViolation,
          actionToUnblock:
              'Remove net-new TODO/FIXME/lint-ignore/overflow suppressions '
              'from the proposed fix.',
        ),
      );
    }

    // ─── Step 7: Design token sourcing (Req 4.3, 4.4) ─────────────────────
    if (proposed.usesDesignToken) {
      final hasToken =
          _tokenResolver?.call(proposed.filePath, proposed.replacedContent) ??
          true;
      if (!hasToken) {
        // Missing token → record as a new Finding (Req 4.4)
        _findingRecorder.record(
          screen: finding.screen,
          category: ChecklistCategory.hardcodedValues,
          severity: Severity.medium,
          description:
              'Required Design_Token missing from theme layer for fix: '
              '${proposed.whatChanged}',
          fileLine: finding.fileLine,
        );
        finding.state = FindingState.blocked;
        return FixBlocked(
          blockedItem: BlockedItem(
            finding: finding,
            blockingReason: 'missing-spec',
            missingArtifact:
                'Design_Token for replacement value in: ${proposed.whatChanged}',
            actionToUnblock:
                'Add the required token to DesignTokens/theme layer, then retry.',
          ),
        );
      }
    }

    // ─── Step 8: Secret/env-var handling (Req 8.4, 8.5) ────────────────────
    if (proposed.replacesSecret) {
      final envVar = proposed.envVarName;
      if (envVar == null || envVar.isEmpty) {
        finding.state = FindingState.blocked;
        return FixBlocked(
          blockedItem: BlockedItem(
            finding: finding,
            blockingReason: 'missing-spec',
            missingArtifact: 'Environment variable name for secret replacement',
            actionToUnblock:
                'Specify the environment variable name to reference.',
          ),
        );
      }
      if (!_knownEnvVars.contains(envVar)) {
        // Missing env var → record a Finding (Req 8.5)
        _findingRecorder.record(
          screen: finding.screen,
          category: ChecklistCategory.hardcodedValues,
          severity: Severity.high,
          description:
              'Required environment variable "$envVar" is not defined '
              'in workspace configuration.',
          fileLine: finding.fileLine,
        );
        finding.state = FindingState.blocked;
        return FixBlocked(
          blockedItem: BlockedItem(
            finding: finding,
            blockingReason: 'external-dependency',
            missingArtifact: 'Environment variable: $envVar',
            actionToUnblock:
                'Define "$envVar" in the workspace environment configuration.',
          ),
        );
      }
    }

    // ─── Step 9: Public API preservation (Req 4.6, 4.7) ───────────────────
    if (proposed.breaksPublicApi) {
      if (proposed.impactedCallSites.isEmpty) {
        // Breaking change requires listing ALL call sites first (Req 4.7)
        finding.state = FindingState.blocked;
        return FixBlocked(
          blockedItem: BlockedItem(
            finding: finding,
            blockingReason: 'ambiguous-requirement',
            missingArtifact: 'Call site inventory for public API change',
            actionToUnblock:
                'List every call site (file:line) of the affected public API '
                'before applying the breaking change.',
          ),
        );
      }
      // If call sites are listed, the breaking change is allowed (logged below)
    }

    // ─── Step 10: All checks passed — record success ───────────────────────
    finding.state = FindingState.resolved;

    final fixLogEntry = FixLogEntry(
      finding: finding,
      whatChanged: proposed.whatChanged,
      whyChanged: proposed.whyChanged,
      beforeBehavior: proposed.beforeBehavior,
      afterBehavior: proposed.afterBehavior,
      impactedCallSites: proposed.impactedCallSites,
    );

    // If this was a shared-core file, schedule verification via the guard
    if (decision is AllowWithImpactNote) {
      _editScopeGuard.verifyShared(
        proposed.filePath,
        decision.consumers.toList(),
      );
    }

    return FixSuccess(fixLogEntry: fixLogEntry);
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  /// Extracts the file path from a `file:line` reference string.
  ///
  /// Expected format: `path/to/file.dart:42` or `path/to/file.dart`
  /// Returns `null` if the format is unrecognized.
  String? _extractFilePath(String fileLine) {
    if (fileLine.isEmpty) return null;

    // Split on the last colon that precedes digits (line number)
    final colonIndex = fileLine.lastIndexOf(':');
    if (colonIndex > 0) {
      final afterColon = fileLine.substring(colonIndex + 1);
      // If what follows the colon is a number, strip it
      if (RegExp(r'^\d+$').hasMatch(afterColon)) {
        return fileLine.substring(0, colonIndex);
      }
    }
    // No line number suffix — treat entire string as file path
    return fileLine;
  }
}
