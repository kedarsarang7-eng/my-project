// ============================================================================
// OWNER-ID RESOLVER — SINGLE, FAIL-SAFE TENANT ATTRIBUTION SOURCE
// ============================================================================
// One place that answers "which owner/clinic does this write belong to?".
//
// Used by patients, appointments, bills and sync so the whole clinic feature
// shares ONE owner-id source. That source is [SessionManager.ownerId] — the
// SAME value clinic_billing_service already uses for `doctorId` (callers such
// as visit_screen read `sl<SessionManager>().ownerId` before passing it in).
// This resolver does NOT change clinic_billing_service; it aligns everyone
// else TO it.
//
// FAIL-SAFE CONTRACT:
//   If the owner id is missing (null / blank) the resolver THROWS
//   [OwnerIdMissingException] so the caller blocks the write and surfaces an
//   error. It NEVER substitutes a `'SYSTEM'` placeholder — unattributed,
//   cross-tenant data is worse than a blocked write.
// ============================================================================

import '../di/service_locator.dart' show sl;
import 'session_manager.dart';

/// Thrown when an owner/clinic id is required for a write but none is available.
///
/// Callers MUST treat this as a hard stop: block the local write + sync enqueue
/// and surface the error to the user. Catching it and falling back to a
/// placeholder owner id would re-introduce the very tenant-isolation bug this
/// resolver exists to prevent.
class OwnerIdMissingException implements Exception {
  /// The operation that was blocked (e.g. `'create patient'`), for diagnostics.
  final String operation;

  const OwnerIdMissingException([this.operation = 'write']);

  @override
  String toString() =>
      'OwnerIdMissingException: cannot perform "$operation" — no authenticated '
      'owner/clinic id is available. The write was blocked to avoid '
      'unattributed (SYSTEM) data.';
}

/// Pure fail-safe check over a candidate [ownerId].
///
/// Returns the id unchanged when it is a non-blank string; otherwise throws
/// [OwnerIdMissingException]. This is the single chokepoint that guarantees no
/// `?? 'SYSTEM'` style fallback can ever happen. Kept pure (no GetIt / session
/// lookup) so it is trivially unit-testable.
String requireOwnerId(String? ownerId, {String operation = 'write'}) {
  if (ownerId == null || ownerId.trim().isEmpty) {
    throw OwnerIdMissingException(operation);
  }
  return ownerId;
}

/// Resolves the current authenticated owner/clinic id and applies the
/// [requireOwnerId] fail-safe check.
///
/// Sources the id from [SessionManager.ownerId] — the same source
/// clinic_billing_service uses for `doctorId`. Pass [session] to override the
/// lookup in tests; in production it falls back to the registered singleton.
///
/// Throws [OwnerIdMissingException] when no owner id is available.
String resolveOwnerId({SessionManager? session, String operation = 'write'}) {
  final manager = session ?? sl<SessionManager>();
  return requireOwnerId(manager.ownerId, operation: operation);
}
