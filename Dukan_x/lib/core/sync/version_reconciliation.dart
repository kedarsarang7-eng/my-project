// Version-Based Sync Reconciliation (Requirement 14.4)
//
// Replaces last-write-wins with version-based conflict resolution:
//   - server.version > local.version → server wins (update local with server data)
//   - local.version > server.version → local wins (push local to server)
//   - local.version == server.version with different data → conflict (prefer server)
//
// This module provides the reconciliation logic consumed by all jewellery
// offline-first repositories during their sync operations.

/// The result of a version-based reconciliation check.
enum ReconciliationAction {
  /// Local version is newer or equal — push local data to server (current behavior).
  pushLocal,

  /// Server version is newer — update local record with server data.
  acceptServer,

  /// Same version but data differs — conflict; prefer server and mark for review.
  conflict,
}

/// Outcome of a sync reconciliation decision.
class ReconciliationResult {
  /// The action to take based on version comparison.
  final ReconciliationAction action;

  /// The server-side version number (from the API response).
  final int serverVersion;

  /// The local version number at the time of comparison.
  final int localVersion;

  /// Server-side data payload (populated when action is [acceptServer] or [conflict]).
  final Map<String, dynamic>? serverData;

  /// Human-readable reason for the decision.
  final String reason;

  const ReconciliationResult({
    required this.action,
    required this.serverVersion,
    required this.localVersion,
    this.serverData,
    required this.reason,
  });

  /// True when the local record should be updated with server data.
  bool get shouldUpdateLocal =>
      action == ReconciliationAction.acceptServer ||
      action == ReconciliationAction.conflict;
}

/// Stateless utility for version-based sync reconciliation.
///
/// Usage in sync methods:
/// ```dart
/// final result = VersionReconciliation.reconcile(
///   localVersion: product.version,
///   serverVersion: responseData['version'] as int? ?? 0,
///   serverData: responseData,
/// );
///
/// if (result.shouldUpdateLocal) {
///   // Apply server data to local Hive record
/// } else {
///   // Mark as synced (push succeeded)
/// }
/// ```
class VersionReconciliation {
  VersionReconciliation._(); // Prevent instantiation

  /// Compare local and server versions and determine the reconciliation action.
  ///
  /// [localVersion] — the `version` field on the local Hive record.
  /// [serverVersion] — the `version` field returned by the server in its response.
  /// [serverData] — the full server-side record payload (used when server wins).
  static ReconciliationResult reconcile({
    required int localVersion,
    required int serverVersion,
    Map<String, dynamic>? serverData,
  }) {
    if (serverVersion > localVersion) {
      return ReconciliationResult(
        action: ReconciliationAction.acceptServer,
        serverVersion: serverVersion,
        localVersion: localVersion,
        serverData: serverData,
        reason:
            'Server version ($serverVersion) is newer than local '
            'version ($localVersion). Accepting server data.',
      );
    }

    if (localVersion > serverVersion) {
      return ReconciliationResult(
        action: ReconciliationAction.pushLocal,
        serverVersion: serverVersion,
        localVersion: localVersion,
        reason:
            'Local version ($localVersion) is newer than server '
            'version ($serverVersion). Pushing local data.',
      );
    }

    // Same version — if server returned data, it may differ (conflict).
    // Per design: prefer server in same-version conflicts.
    if (serverData != null && serverData.isNotEmpty) {
      return ReconciliationResult(
        action: ReconciliationAction.conflict,
        serverVersion: serverVersion,
        localVersion: localVersion,
        serverData: serverData,
        reason:
            'Same version ($localVersion) but server returned data. '
            'Treating as conflict — preferring server.',
      );
    }

    // Same version, no differing data — nothing to do, mark synced.
    return ReconciliationResult(
      action: ReconciliationAction.pushLocal,
      serverVersion: serverVersion,
      localVersion: localVersion,
      reason: 'Versions equal ($localVersion). No conflict detected.',
    );
  }

  /// Extract the version from a server API response body.
  ///
  /// Falls back to 0 if the response does not contain a version field,
  /// ensuring backward compatibility with endpoints that haven't been
  /// upgraded to return version metadata.
  static int extractServerVersion(Map<String, dynamic>? responseBody) {
    if (responseBody == null) return 0;

    // Check common version field names in DukanX API responses
    return (responseBody['version'] as int?) ??
        (responseBody['_version'] as int?) ??
        (responseBody['data']?['version'] as int?) ??
        0;
  }
}
