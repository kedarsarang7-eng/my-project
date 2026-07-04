/// Edit-Scope Guard — enforces cycle isolation by classifying proposed edits
/// and authorizing or rejecting them based on file ownership relative to the
/// active Business_Type.
///
/// Classification delegates to [FileOwnershipMap.classifyFile].
/// Authorization logic:
///   - activeVertical → Allow
///   - sharedCore → AllowWithImpactNote(consumers)
///   - otherVerticalExclusive → Reject (file unchanged, out-of-scope indication,
///     Blocked_Item recorded when Finding-driven)
///
/// Shared-core verification:
///   - [verifyShared] records exactly one pass/fail per consuming Business_Type
///   - Any fail records a [BlockedItem] and withholds Sign_Off
///
/// Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.8
library;

import '../models/audit_engine_models.dart';
import 'file_ownership_map.dart';

// ---------------------------------------------------------------------------
// Edit Request / Decision types
// ---------------------------------------------------------------------------

/// A proposed source-file edit submitted to the guard for authorization.
class EditRequest {
  /// The target file path to edit.
  final String filePath;

  /// Optional Finding ID; present when the edit is driven by a Finding.
  /// Triggers [BlockedItem] recording on reject.
  final String? findingId;

  /// Description of what the edit intends to do.
  final String description;

  const EditRequest({
    required this.filePath,
    this.findingId,
    required this.description,
  });

  /// Whether this edit is driven by a Finding (triggers Blocked_Item on reject).
  bool get isFindingDriven => findingId != null;

  @override
  String toString() =>
      'EditRequest($filePath, finding: $findingId, desc: $description)';
}

/// Base class for edit authorization decisions.
sealed class EditDecision {
  const EditDecision();
}

/// The file belongs to the active vertical — proceed with the edit.
class Allow extends EditDecision {
  const Allow();

  @override
  String toString() => 'Allow';
}

/// The file is a Shared_Core_Widget — proceed but record an impact note
/// listing all consumers.
class AllowWithImpactNote extends EditDecision {
  /// All Business_Types that consume this shared file (excluding the active one).
  final Set<BusinessType> consumers;

  const AllowWithImpactNote({required this.consumers});

  @override
  String toString() => 'AllowWithImpactNote(consumers: $consumers)';
}

/// The file belongs exclusively to another vertical — reject the edit.
/// The target file is left unchanged.
class Reject extends EditDecision {
  /// Human-readable reason for rejection.
  final String reason;

  /// The Business_Type that owns the target file (for cross-vertical deferral).
  final BusinessType? targetBusinessType;

  const Reject({required this.reason, this.targetBusinessType});

  @override
  String toString() => 'Reject(reason: $reason, target: $targetBusinessType)';
}

// ---------------------------------------------------------------------------
// Verification callback
// ---------------------------------------------------------------------------

/// Callback that verifies a shared-widget change against a specific consumer.
///
/// Returns `true` if the change is compatible with [consumer], `false` otherwise.
/// Externally supplied to allow testing with mocks and to decouple actual
/// verification logic from the guard.
typedef VerificationCallback =
    bool Function(String widgetPath, BusinessType consumer);

/// Default verification callback that always returns `true` (optimistic).
/// In production this should be replaced with real cross-vertical checks.
bool _defaultVerify(String widgetPath, BusinessType consumer) => true;

// ---------------------------------------------------------------------------
// Edit-Scope Guard implementation
// ---------------------------------------------------------------------------

/// Enforces cycle isolation by gating every proposed edit through file-ownership
/// classification.
///
/// Tracks all rejected edits (in [rejectionLog]) and records [BlockedItem]s
/// for Finding-driven rejects (in [blockedItems]).
///
/// Tracks shared-core verification results (in [sharedImpactNotes]) via
/// [verifyShared]; any fail records a [BlockedItem] and withholds Sign_Off.
class EditScopeGuard {
  /// Internal log of rejected edit indications (file path + reason).
  final List<String> _rejectionLog = [];

  /// Blocked items recorded when a Finding-driven edit is rejected or a
  /// shared-core verification fails.
  final List<BlockedItem> _blockedItems = [];

  /// Shared/Core Impact Notes accumulated during shared-widget verifications.
  final List<SharedImpactNote> _sharedImpactNotes = [];

  /// All rejection indications emitted during this guard's lifetime.
  List<String> get rejectionLog => List.unmodifiable(_rejectionLog);

  /// All blocked items recorded from Finding-driven rejections or shared
  /// verification failures.
  List<BlockedItem> get blockedItems => List.unmodifiable(_blockedItems);

  /// All shared/core impact notes recorded via [verifyShared].
  List<SharedImpactNote> get sharedImpactNotes =>
      List.unmodifiable(_sharedImpactNotes);

  /// Classifies a file into one of three scopes relative to the active
  /// Business_Type, delegating to [FileOwnershipMap.classifyFile].
  FileScope classify(
    String filePath,
    BusinessType active,
    FileOwnershipMap map,
  ) {
    return map.classifyFile(filePath, active);
  }

  /// Authorizes or rejects an edit request based on file-ownership
  /// classification.
  ///
  /// Returns:
  /// - [Allow] when the file is classified as [FileScope.activeVertical].
  /// - [AllowWithImpactNote] when classified as [FileScope.sharedCore],
  ///   populating [consumers] with all other Business_Types that use the file.
  /// - [Reject] when classified as [FileScope.otherVerticalExclusive];
  ///   the target file is left unchanged, an out-of-scope indication is
  ///   emitted, and — when the edit is Finding-driven — a [BlockedItem] is
  ///   recorded with the [targetBusinessType].
  EditDecision authorize(
    EditRequest req,
    BusinessType active,
    FileOwnershipMap map,
  ) {
    final scope = classify(req.filePath, active, map);

    switch (scope) {
      case FileScope.activeVertical:
        return const Allow();

      case FileScope.sharedCore:
        // Get all consumers of this shared file, excluding the active vertical.
        final allConsumers = map.getConsumers(req.filePath);
        final otherConsumers = allConsumers.where((bt) => bt != active).toSet();
        return AllowWithImpactNote(consumers: otherConsumers);

      case FileScope.otherVerticalExclusive:
        // Determine the owning vertical from the consumer set.
        final consumers = map.getConsumers(req.filePath);
        final targetBt = consumers.isNotEmpty ? consumers.first : null;

        final reason =
            'File "${req.filePath}" is exclusive to '
            '${targetBt?.displayName ?? "another vertical"} '
            'and out of scope for the active ${active.displayName} cycle.';

        // Emit out-of-scope indication.
        _rejectionLog.add('OUT-OF-SCOPE: ${req.filePath} — $reason');

        // Record Blocked_Item when the edit was Finding-driven.
        if (req.isFindingDriven) {
          _blockedItems.add(
            BlockedItem(
              finding: _createPlaceholderFinding(req),
              blockingReason: 'external-dependency',
              missingArtifact: req.filePath,
              actionToUnblock:
                  'Defer to the ${targetBt?.displayName ?? "owning"} '
                  "vertical's Cycle.",
              targetBusinessType: targetBt,
            ),
          );
        }

        return Reject(reason: reason, targetBusinessType: targetBt);
    }
  }

  /// Resets internal state (useful for testing or between cycles).
  void reset() {
    _rejectionLog.clear();
    _blockedItems.clear();
    _sharedImpactNotes.clear();
  }

  /// Verifies a shared-core widget change against every consuming Business_Type
  /// and records exactly one pass/fail verification result per consumer.
  ///
  /// [widgetPath] is the path of the Shared_Core_Widget that was edited.
  /// [consumers] is the list of other Business_Types consuming this widget
  /// (excluding the active vertical).
  /// [verify] is the external callback that performs the actual compatibility
  /// check; defaults to an optimistic always-pass callback.
  ///
  /// Returns a [SharedImpactNote] with the verification map.
  ///
  /// Any consumer that fails verification:
  /// - Records a [BlockedItem] identifying the affected Business_Type
  /// - This withholds Sign_Off (checked by [SignOffEvaluator])
  ///
  /// Requirements: 1.4, 1.5, 1.6
  SharedImpactNote verifyShared(
    String widgetPath,
    List<BusinessType> consumers, {
    VerificationCallback? verify,
  }) {
    final verifyFn = verify ?? _defaultVerify;

    // Record exactly one pass/fail result per consumer (Req 1.5).
    // Deduplicate consumers to ensure each appears exactly once.
    final uniqueConsumers = consumers.toSet();
    final consumerVerification = <BusinessType, bool>{};

    for (final consumer in uniqueConsumers) {
      final passed = verifyFn(widgetPath, consumer);
      consumerVerification[consumer] = passed;

      // Any fail → Blocked_Item identifying the affected Business_Type (Req 1.6)
      if (!passed) {
        _blockedItems.add(
          BlockedItem(
            finding: Finding(
              id: 'shared-verify-fail-${consumer.name}-${widgetPath.hashCode}',
              screen: ScreenRef(
                name: 'shared',
                route: 'n/a',
                filePath: widgetPath,
              ),
              category: ChecklistCategory.layoutAndOverflow,
              severity: Severity.high,
              description:
                  'Shared widget "$widgetPath" failed verification for '
                  '${consumer.displayName}.',
              fileLine: '$widgetPath:0',
            ),
            blockingReason: 'external-dependency',
            missingArtifact: widgetPath,
            actionToUnblock:
                'Resolve shared-widget incompatibility with '
                '${consumer.displayName} before Sign_Off.',
            targetBusinessType: consumer,
          ),
        );
      }
    }

    final note = SharedImpactNote(
      widgetPath: widgetPath,
      consumerVerification: consumerVerification,
    );
    _sharedImpactNotes.add(note);

    return note;
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  /// Creates a minimal placeholder Finding for Blocked_Item recording when
  /// only the EditRequest context is available.
  ///
  /// The actual Finding should be looked up from the FindingRecorder in a
  /// production flow; this placeholder ensures the BlockedItem contract is met
  /// when the guard operates in isolation.
  Finding _createPlaceholderFinding(EditRequest req) {
    return Finding(
      id: req.findingId ?? 'unknown',
      screen: ScreenRef(
        name: 'unknown',
        route: 'unknown',
        filePath: req.filePath,
      ),
      category: ChecklistCategory.layoutAndOverflow,
      severity: Severity.medium,
      description: req.description,
      fileLine: '${req.filePath}:0',
    );
  }
}
